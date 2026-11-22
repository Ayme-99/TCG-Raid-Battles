import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/campana.dart';

import '../almacen/almacen.dart';
import '../partida/controlador_partida.dart' show azarProvider;

/// Clave bajo la que se guarda la partida de campaña en el dispositivo.
const claveCampana = 'campana_kanto';

/// Cifras provisionales de la campaña (puntos, equipo…), en un solo sitio
/// del motor: [ParametrosCampana].
const parametrosCampana = ParametrosCampana();

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
  @override
  EstadoCampana build() =>
      EstadoCampana(partida: ref.read(campanaInicialProvider));

  PartidaCampana get _partida {
    final p = state.partida;
    if (p == null) throw const ReglaIncumplida('No hay partida de campaña.');
    return p;
  }

  void _guardar(PartidaCampana p) {
    state = EstadoCampana(partida: p);
    ref.read(almacenProvider).escribir(claveCampana, jsonEncode(p.aJson()));
  }

  /// Empieza una campaña nueva (borra la anterior).
  void nueva(CatalogoCampana c) {
    final semilla = ref.read(azarProvider).nextInt(1 << 30) + 1;
    _guardar(PartidaCampana.nueva(c.region,
        semilla: semilla, parametros: parametrosCampana));
  }

  /// Borra la campaña guardada.
  void abandonar() {
    state = const EstadoCampana();
    ref.read(almacenProvider).borrar(claveCampana);
  }

  void elegirInicial(CatalogoCampana c, String id) =>
      _guardar(_partida.elegirInicial(c, id));

  void avanzar(CatalogoCampana c, String destino) =>
      _guardar(_partida.avanzar(c, destino));

  void capturar(CatalogoCampana c, {int? sustituir}) => _guardar(_partida
      .capturar(c, sustituir: sustituir, parametros: parametrosCampana));

  void noCapturar() => _guardar(_partida.noCapturar());

  void descansar(CatalogoCampana c) => _guardar(_partida.descansar(c));

  void conversar(CatalogoCampana c) => _guardar(_partida.conversar(c));

  void moverPc(CatalogoCampana c, {int? deEquipo, int? dePc}) =>
      _guardar(_partida.moverPc(c,
          deEquipo: deEquipo, dePc: dePc, parametros: parametrosCampana));

  void ponerPrimero(int indice) => _guardar(_partida.ponerPrimero(indice));

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
  if (accion is Atacar &&
      antes.bando(accion.bando.otro).pokemonActivo.ps ==
          despues.bando(accion.bando.otro).pokemonActivo.ps &&
      lineas.length == 1) {
    lineas.add('No hace daño.');
  }
  return lineas;
}
