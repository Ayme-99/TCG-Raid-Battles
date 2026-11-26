import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/campana.dart';

import '../almacen/almacen.dart';
import '../cuenta/cliente_api.dart';
import '../cuenta/controlador_sesion.dart';
import '../cuenta/sesion.dart';
import '../envios/cola_envios.dart' show esperaTrasFallo;
import '../envios/controlador_envios.dart' show Cancelar, programadorProvider;
import '../partida/controlador_partida.dart' show azarProvider;

/// Clave bajo la que se guarda la partida de campaña en el dispositivo.
const claveCampana = 'campana_kanto';

/// Cifras provisionales de la campaña (puntos, equipo…), en un solo sitio
/// del motor: [ParametrosCampana].
const parametrosCampana = ParametrosCampana();

/// Id de la campaña para el servidor (contrato/campana/hitos.v1.schema.json).
const idCampanaServidor = 'kanto';

/// Un id nuevo de partida de campaña (#374): 16 caracteres hexadecimales.
String nuevoIdPartida(Random azar) => [
      for (var i = 0; i < 4; i++)
        azar.nextInt(1 << 16).toRadixString(16).padLeft(4, '0'),
    ].join();

/// Lee la partida de campaña guardada. Si no hay, o no se puede leer (otra
/// versión, datos dañados), devuelve `null` y la descarta.
Future<PartidaCampana?> leerCampana(Almacen almacen) async {
  final texto = await almacen.leer(claveCampana);
  if (texto == null) return null;
  try {
    return PartidaCampana.desdeJson(jsonDecode(texto) as Map<String, dynamic>);
  } catch (_) {
    await almacen.borrar(claveCampana);
    return null;
  }
}

/// Clave del estado de la copia en la cuenta (#478): la revisión que se leyó
/// o subió por última vez y si la partida local ha cambiado desde entonces.
const claveCampanaCuenta = 'campana_kanto_cuenta';

/// La partida de este dispositivo y la de la cuenta han cambiado las dos
/// desde la última vez que se igualaron: el jugador elige con cuál quedarse.
class ConflictoCampana {
  const ConflictoCampana({
    required this.local,
    required this.cuenta,
    required this.revision,
  });

  final PartidaCampana local;
  final PartidaCampana cuenta;

  /// Revisión de la copia de la cuenta.
  final int revision;
}

/// El conflicto pendiente de elegir, o null.
final conflictoCampanaProvider =
    StateProvider<ConflictoCampana?>((ref) => null);

/// La partida guardada al abrir la app (la pone `main.dart`).
final campanaInicialProvider = Provider<PartidaCampana?>((ref) => null);

/// Lo que ve la pantalla de campaña: la partida y, si se está combatiendo, el
/// combate y lo que ha pasado en él.
class EstadoCampana {
  const EstadoCampana({this.partida, this.combate, this.registro = const []});

  final PartidaCampana? partida;

  /// El combate en curso, o null. No se guarda: si se cierra la app a mitad,
  /// el combate empieza de nuevo (contra el mismo rival).
  final EstadoCombate? combate;

  /// Lo que ha pasado en el combate, en orden.
  final List<String> registro;
}

/// Controlador de la campaña: toda regla es del motor
/// (`engine/lib/src/campana/`); aquí solo se encadenan las acciones, se juega
/// el turno de la máquina y se guarda.
class ControladorCampana extends Notifier<EstadoCampana> {
  bool _enviando = false;

  // Copia en la cuenta (#478).
  bool _sincronizando = false;
  bool _otraVez = false;
  Future<void>? _metaLeida;
  int _revision = 0;
  bool _sucia = false;

  /// Sube cada vez que cambia la partida local: si cambia mientras se sube,
  /// la copia subida ya no es la última y sigue «sucia».
  int _cambios = 0;
  bool _vivo = true;
  int _fallos = 0;
  Cancelar? _cancelarReintento;

  @override
  EstadoCampana build() {
    _vivo = true;
    ref.onDispose(() {
      _vivo = false;
      _cancelarReintento?.call();
    });
    // Al iniciar sesión (o leerla al arrancar) se envían los hitos pendientes.
    ref.listen<Sesion?>(sesionActualProvider, (_, sesion) {
      if (sesion != null) {
        unawaited(Future.microtask(enviarHitos));
        unawaited(Future.microtask(sincronizar));
      }
    });
    unawaited(Future.microtask(enviarHitos));
    unawaited(Future.microtask(sincronizar));
    var partida = ref.read(campanaInicialProvider);
    // Las partidas guardadas antes de #374 no tienen id: se les pone uno.
    if (partida != null && partida.partidaId == null) {
      partida = partida.conPartidaId(nuevoIdPartida(ref.read(azarProvider)));
      ref
          .read(almacenProvider)
          .escribir(claveCampana, jsonEncode(partida.aJson()));
      unawaited(_marcarSucia());
    }
    return EstadoCampana(partida: partida);
  }

  PartidaCampana get _partida {
    final p = state.partida;
    if (p == null) throw const ReglaIncumplida('No hay partida de campaña.');
    return p;
  }

  void _guardar(PartidaCampana p) {
    state = EstadoCampana(partida: p);
    ref.read(almacenProvider).escribir(claveCampana, jsonEncode(p.aJson()));
    unawaited(_marcarSucia());
  }

  // --- Copia en la cuenta (#478) -------------------------------------------

  Future<void> _leerMeta() => _metaLeida ??= () async {
        final texto = await ref.read(almacenProvider).leer(claveCampanaCuenta);
        if (texto == null) return;
        try {
          final json = jsonDecode(texto) as Map<String, dynamic>;
          _revision = json['revision'] as int;
          // Un cambio hecho antes de leer esto sigue contando.
          _sucia = _sucia || json['sucia'] == true;
        } catch (_) {
          // Dañado: se empieza de cero y la próxima subida lo arregla.
        }
      }();

  Future<void> _escribirMeta() => ref.read(almacenProvider).escribir(
      claveCampanaCuenta, jsonEncode({'revision': _revision, 'sucia': _sucia}));

  Future<void> _marcarSucia() async {
    _cambios++;
    _sucia = true;
    await _leerMeta();
    _sucia = true;
    await _escribirMeta();
  }

  /// Iguala la partida local con la de la cuenta (D-20 §6, #478). Si solo ha
  /// cambiado una, gana esa. Si han cambiado las dos, deja un
  /// [ConflictoCampana] para que elija el jugador. Sin sesión o sin conexión
  /// no hace nada: se sigue jugando con la local y se sube después.
  Future<void> sincronizar() async {
    if (_sincronizando) {
      _otraVez = true;
      return;
    }
    _sincronizando = true;
    try {
      do {
        _otraVez = false;
        await _sincronizarUnaVez();
      } while (_otraVez && _vivo);
    } finally {
      _sincronizando = false;
    }
  }

  Future<void> _sincronizarUnaVez() async {
    final sesion = ref.read(sesionActualProvider);
    if (sesion == null || !_vivo) return;
    if (ref.read(conflictoCampanaProvider) != null) return;
    await _leerMeta();
    final api = ref.read(clienteApiProvider);
    final GuardadoCuenta? cuenta;
    try {
      cuenta = await api.leerGuardadoCampana(sesion.token, idCampanaServidor);
    } on ErrorApi {
      return;
    }
    if (!_vivo) return;
    final local = state.partida;
    if (cuenta == null) {
      // La cuenta no tiene ninguna: se sube la local.
      if (local != null) await _subir(sesion, local, 0);
      return;
    }
    if (cuenta.revision == _revision) {
      // La de la cuenta no ha cambiado: se sube la local si cambió.
      if (_sucia && local != null) await _subir(sesion, local, _revision);
      return;
    }
    final PartidaCampana deCuenta;
    try {
      deCuenta = PartidaCampana.desdeJson(cuenta.partida);
    } catch (_) {
      return; // De otra versión de la app: no se toca nada.
    }
    if (local == null) {
      // Sin partida aquí: se trae la de la cuenta, salvo que se abandonara.
      if (!_sucia) await _adoptar(deCuenta, cuenta.revision);
    } else if (!_sucia) {
      await _adoptar(deCuenta, cuenta.revision);
    } else {
      ref.read(conflictoCampanaProvider.notifier).state = ConflictoCampana(
          local: local, cuenta: deCuenta, revision: cuenta.revision);
    }
  }

  Future<void> _subir(Sesion sesion, PartidaCampana p, int revision) async {
    final cambios = _cambios;
    final ResultadoSubida r;
    try {
      r = await ref.read(clienteApiProvider).subirGuardadoCampana(
          sesion.token, idCampanaServidor,
          revision: revision, partida: p.aJson());
    } on ErrorApi {
      return; // Sigue «sucia»: se sube la próxima vez.
    }
    if (!_vivo) return;
    if (!r.conflicto) {
      _revision = r.revision!;
      if (_cambios == cambios) _sucia = false;
      await _escribirMeta();
      return;
    }
    // Otro dispositivo subió antes: se vuelve a mirar con su copia.
    final actual = r.actual;
    if (actual == null) {
      _revision = 0;
      _otraVez = true;
      return;
    }
    try {
      ref.read(conflictoCampanaProvider.notifier).state = ConflictoCampana(
          local: p,
          cuenta: PartidaCampana.desdeJson(actual.partida),
          revision: actual.revision);
    } catch (_) {
      // De otra versión de la app: no se toca nada.
    }
  }

  /// Usa la partida de la cuenta en este dispositivo. No interrumpe un
  /// combate en curso: espera a la próxima vez.
  Future<void> _adoptar(PartidaCampana p, int revision) async {
    if (state.combate != null) return;
    state = EstadoCampana(partida: p);
    await ref
        .read(almacenProvider)
        .escribir(claveCampana, jsonEncode(p.aJson()));
    _revision = revision;
    _sucia = false;
    await _escribirMeta();
    unawaited(enviarHitos());
  }

  /// Resuelve el conflicto con la partida de la cuenta. Los hitos sin enviar
  /// de la local se conservan si son de la misma partida, para no perder
  /// puntos (el servidor no los abona dos veces).
  Future<void> usarPartidaDeLaCuenta() async {
    final c = ref.read(conflictoCampanaProvider);
    if (c == null) return;
    ref.read(conflictoCampanaProvider.notifier).state = null;
    var p = c.cuenta;
    if (p.partidaId != null && p.partidaId == c.local.partidaId) {
      final ids = {for (final h in p.hitosPendientes) h.id};
      p = PartidaCampana.desdeJson({
        ...p.aJson(),
        'hitosPendientes': [
          for (final h in p.hitosPendientes) h.aJson(),
          for (final h in c.local.hitosPendientes)
            if (!ids.contains(h.id)) h.aJson(),
        ],
      });
    }
    await _adoptar(p, c.revision);
  }

  /// Resuelve el conflicto con la partida de este dispositivo: sustituye a la
  /// de la cuenta.
  Future<void> usarPartidaDeEsteDispositivo() async {
    final c = ref.read(conflictoCampanaProvider);
    final sesion = ref.read(sesionActualProvider);
    if (c == null) return;
    ref.read(conflictoCampanaProvider.notifier).state = null;
    if (sesion == null) return;
    final local = state.partida ?? c.local;
    await _subir(sesion, local, c.revision);
  }

  /// Empieza una campaña nueva (borra la anterior).
  void nueva(CatalogoCampana c) {
    final semilla = ref.read(azarProvider).nextInt(1 << 30) + 1;
    _guardar(PartidaCampana.nueva(c.region,
        semilla: semilla,
        partidaId: nuevoIdPartida(ref.read(azarProvider)),
        parametros: parametrosCampana));
    unawaited(sincronizar());
  }

  /// Borra la campaña guardada.
  void abandonar() {
    state = const EstadoCampana();
    ref.read(almacenProvider).borrar(claveCampana);
    // Así no se vuelve a traer la de la cuenta (que se queda allí hasta que
    // se empiece otra).
    unawaited(_marcarSucia());
  }

  void elegirInicial(CatalogoCampana c, String id) =>
      _guardar(_partida.elegirInicial(c, id));

  /// Avanza a otro nodo y sube la partida a la cuenta (así se sube también
  /// al salir del centro Pokémon).
  void avanzar(CatalogoCampana c, String destino) {
    _guardar(_partida.avanzar(c, destino));
    unawaited(sincronizar());
  }

  void capturar(CatalogoCampana c, {int? sustituir}) => _guardar(_partida
      .capturar(c, sustituir: sustituir, parametros: parametrosCampana));

  void noCapturar() => _guardar(_partida.noCapturar());

  /// Lanza una Ball al Pokémon pendiente. Devuelve el motivo si no se puede, o
  /// «se ha escapado» si sale cruz.
  String? lanzarBall(CatalogoCampana c, ObjetoCampana ball) {
    final motivo = _intentar(() => _partida.lanzarBall(c, ball));
    if (motivo != null) return motivo;
    return _partida.capturaLograda ? null : '¡Se ha escapado de la Ball!';
  }

  void descansar(CatalogoCampana c) => _guardar(_partida.descansar(c));

  void conversar(CatalogoCampana c) => _guardar(_partida.conversar(c));

  void moverPc(CatalogoCampana c, {int? deEquipo, int? dePc}) =>
      _guardar(_partida.moverPc(c,
          deEquipo: deEquipo, dePc: dePc, parametros: parametrosCampana));

  void ponerPrimero(int indice) => _guardar(_partida.ponerPrimero(indice));

  /// Vuelve a un nodo ya visitado (D-20 §10.7).
  String? retroceder(CatalogoCampana c, String destino) =>
      _intentar(() => _partida.retroceder(c, destino));

  /// Vuelve a combatir contra el salvaje ya vencido del nodo actual.
  void repetirCombate(CatalogoCampana c) =>
      _guardar(_partida.repetirCombate(c));

  /// Devuelven el motivo si el motor no lo permite (sin dinero, sin objetos…).
  String? comprar(CatalogoCampana c, ObjetoCampana objeto) => _intentar(
      () => _partida.comprar(c, objeto, parametros: parametrosCampana));

  String? usarPocion(CatalogoCampana c, int indice) => _intentar(
      () => _partida.usarPocion(c, indice, parametros: parametrosCampana));

  /// Evoluciona al Pokémon [indice] del equipo gastando XP de la reserva.
  String? evolucionar(CatalogoCampana c, int indice, String destino) =>
      _intentar(() => _partida.evolucionar(c, indice, destino));

  String? usarRepelente(CatalogoCampana c) =>
      _intentar(() => _partida.usarRepelente(c));

  String? _intentar(PartidaCampana Function() operacion) {
    try {
      _guardar(operacion());
      return null;
    } on ReglaIncumplida catch (e) {
      return e.mensaje;
    }
  }

  /// Empieza el combate del nodo actual.
  void combatir(CatalogoCampana c) {
    final rival = _partida.rival(c, parametros: parametrosCampana);
    final combate = _partida.empezarCombate(c, parametros: parametrosCampana);
    state = EstadoCampana(
      partida: _partida,
      combate: combate,
      registro: ['¡Empieza el combate contra ${rival.nombre}!'],
    );
    _jugarMaquina();
  }

  /// Una acción del jugador. Devuelve el motivo si el motor la rechaza.
  String? actuar(AccionCombate accion) {
    final combate = state.combate;
    if (combate == null) return 'No hay combate.';
    try {
      final despues = aplicarCombate(combate, accion);
      state = EstadoCampana(
        partida: state.partida,
        combate: despues,
        registro: [
          ...state.registro,
          ...describirAccion(combate, accion, despues),
        ],
      );
    } on ReglaIncumplida catch (e) {
      return e.mensaje;
    }
    _jugarMaquina();
    return null;
  }

  /// La máquina juega hasta que le toca al jugador o se acaba el combate.
  void _jugarMaquina() {
    var combate = state.combate!;
    final registro = [...state.registro];
    var pasos = 0;
    while (combate.fase != FaseCombate.terminado &&
        combate.actua == Bando.rival &&
        pasos++ < 50) {
      final accion = decidirAccion(combate, Bando.rival);
      final despues = aplicarCombate(combate, accion);
      registro.addAll(describirAccion(combate, accion, despues));
      combate = despues;
    }
    if (combate.fase == FaseCombate.terminado) {
      registro.add(combate.ganador == Bando.jugador
          ? '¡Has ganado el combate!'
          : 'Has perdido el combate.');
    }
    state = EstadoCampana(
        partida: state.partida, combate: combate, registro: registro);
  }

  /// Cierra el combate terminado y aplica el resultado a la partida.
  void cerrarCombate(CatalogoCampana c) {
    final combate = state.combate;
    if (combate == null || combate.fase != FaseCombate.terminado) return;
    _guardar(
        _partida.terminarCombate(c, combate, parametros: parametrosCampana));
    // La partida se sube a la cuenta al terminar cada combate (#478).
    unawaited(sincronizar());
    // Un jefe o una medalla se envían a la cuenta en cuanto se ganan; los
    // salvajes y entrenadores van con ellos o al iniciar sesión (#374).
    if (_partida.hitosPendientes
        .any((h) => h.tipo == TipoHito.jefe || h.tipo == TipoHito.medalla)) {
      unawaited(enviarHitos());
    }
  }

  /// Envía a la cuenta los hitos pendientes de la partida (#374). Si van bien
  /// (abonados o ya abonados) se quitan de la partida. Si el servidor los
  /// rechaza, reintentar no sirve y también se quitan. Sin conexión se quedan
  /// y se reintenta más tarde.
  Future<void> enviarHitos() async {
    if (_enviando) return;
    _enviando = true;
    try {
      await _enviarHitos();
    } finally {
      _enviando = false;
    }
  }

  Future<void> _enviarHitos() async {
    final sesion = ref.read(sesionActualProvider);
    final partida = state.partida;
    final id = partida?.partidaId;
    if (sesion == null ||
        partida == null ||
        id == null ||
        partida.hitosPendientes.isEmpty) {
      return;
    }
    _cancelarReintento?.call();
    _cancelarReintento = null;
    final enviados = partida.hitosPendientes.take(100).toList();
    final r = await ref.read(clienteApiProvider).enviarHitos(
      sesion.token,
      campana: idCampanaServidor,
      partida: id,
      hitos: [for (final h in enviados) h.aJson()],
    );
    if (!_vivo) return;
    switch (r.resultado) {
      case ResultadoEnvio.guardada:
        _fallos = 0;
        _quitarHitos(id, r.ids);
      case ResultadoEnvio.rechazada:
        _fallos = 0;
        _quitarHitos(id, [for (final h in enviados) h.id]);
      case ResultadoEnvio.sesionCaducada:
        // Se reenvían al volver a iniciar sesión.
        break;
      case ResultadoEnvio.reintentar:
        _fallos++;
        _cancelarReintento = ref.read(programadorProvider)(
          esperaTrasFallo(_fallos),
          () => unawaited(enviarHitos()),
        );
    }
  }

  /// Quita los hitos [ids] de la partida en curso si sigue siendo la [id]
  /// (mientras se enviaban se ha podido empezar otra). Conserva el combate.
  void _quitarHitos(String id, List<String> ids) {
    final p = state.partida;
    if (p == null || p.partidaId != id || ids.isEmpty) return;
    final sin = p.quitarHitos(ids);
    state = EstadoCampana(
        partida: sin, combate: state.combate, registro: state.registro);
    ref.read(almacenProvider).escribir(claveCampana, jsonEncode(sin.aJson()));
  }
}

final campanaProvider =
    NotifierProvider<ControladorCampana, EstadoCampana>(ControladorCampana.new);

/// Qué ha pasado al aplicar [accion]: la acción y los PS que ha perdido cada
/// Pokémon (por el ataque, una moneda o el veneno).
List<String> describirAccion(
    EstadoCombate antes, AccionCombate accion, EstadoCombate despues) {
  final quien = antes.bando(accion.bando);
  final propio = accion.bando == Bando.jugador ? 'Tu' : 'El rival:';
  final activo = quien.pokemonActivo.especie.nombre;
  final lineas = <String>[
    switch (accion) {
      Atacar a =>
        '$propio $activo usa ${quien.pokemonActivo.especie.ataques[a.indice].nombre}.',
      Cambiar a =>
        '$propio $activo vuelve; sale ${quien.equipo[a.indice].especie.nombre}.',
      Cargar _ => '$propio $activo carga energía.',
      UsarPocion a => '$propio ${quien.equipo[a.indice].especie.nombre} '
          'recupera ${_curado(antes, despues, a)} PS con una Poción.',
      UsarCuerdaHuida a => '$propio $activo huye con una Cuerda Huida; '
          'sale ${quien.equipo[a.indice].especie.nombre}.',
      ElegirSiguiente a =>
        '$propio sale ${quien.equipo[a.indice].especie.nombre}.',
    },
  ];
  if (accion is Atacar &&
      despues.ultimasMonedas != null &&
      !identical(despues.ultimasMonedas, antes.ultimasMonedas)) {
    final m = despues.ultimasMonedas!.map((c) => c ? 'cara' : 'cruz');
    lineas.add('Moneda: ${m.join(', ')}.');
  }
  // Dormido (Canto, D-20 §10.2): se duerme con el ataque y se despierta con
  // la moneda del chequeo Pokémon, en el mismo activo.
  for (final b in [accion.bando.otro, accion.bando]) {
    final a = antes.bando(b);
    final d = despues.bando(b);
    if (a.activo != d.activo) continue;
    final nombre = d.pokemonActivo.especie.nombre;
    final de = b == Bando.jugador ? 'Tu $nombre' : '$nombre rival';
    if (!a.dormido && d.dormido) lineas.add('$de se ha dormido.');
    if (a.dormido && !d.dormido && d.pokemonActivo.enPie) {
      lineas.add('$de se despierta.');
    }
    if (!a.apresado && d.apresado) lineas.add('$de queda apresado.');
    if (a.apresado && !d.apresado && d.pokemonActivo.enPie) {
      lineas.add('$de se libera.');
    }
  }
  for (final b in [accion.bando.otro, accion.bando]) {
    final a = antes.bando(b).equipo;
    final d = despues.bando(b).equipo;
    for (var i = 0; i < a.length; i++) {
      final perdido = a[i].ps - d[i].ps;
      if (perdido <= 0) continue;
      final nombre = a[i].especie.nombre;
      final de = b == Bando.jugador ? 'Tu $nombre' : '$nombre rival';
      lineas.add(d[i].enPie
          ? '$de pierde $perdido PS.'
          : '$de pierde $perdido PS y queda fuera de combate.');
    }
  }
  // Absorber (curaAlAtacar, D-20 §3.6): el atacante se cura tras el daño.
  if (accion is Atacar) {
    final a = antes.bando(accion.bando);
    final d = despues.bando(accion.bando);
    final curado = d.equipo[a.activo].ps - a.equipo[a.activo].ps;
    if (curado > 0) {
      final nombre = a.pokemonActivo.especie.nombre;
      lineas.add(accion.bando == Bando.jugador
          ? 'Tu $nombre recupera $curado PS.'
          : '$nombre rival recupera $curado PS.');
    }
  }
  if (accion is Atacar &&
      antes.bando(accion.bando.otro).pokemonActivo.ps ==
          despues.bando(accion.bando.otro).pokemonActivo.ps &&
      lineas.length == 1) {
    lineas.add('No hace daño.');
  }
  return lineas;
}

/// PS que ha curado la Poción [a].
int _curado(EstadoCombate antes, EstadoCombate despues, UsarPocion a) =>
    despues.bando(a.bando).equipo[a.indice].ps -
    antes.bando(a.bando).equipo[a.indice].ps;
