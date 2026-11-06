import 'errores.dart';
import 'estado.dart';
import 'eventos.dart';
import 'motor.dart';
import 'puntos.dart';

/// Versión del formato del registro de partida que escribe este motor.
///
/// Compatibilidad (ver `contrato/README.md`): cualquier cambio del formato
/// sube la versión. Este motor lee todas las versiones hasta la actual y
/// migra las antiguas; rechaza las futuras.
const int versionRegistro = 1;

/// Migraciones del registro de la versión N a la N+1 (sobre el JSON).
/// Vacío mientras solo exista la versión 1.
final Map<int, Map<String, Object?> Function(Map<String, Object?>)>
    _migraciones = {};

// ---------------------------------------------------------------------------
// Eventos <-> JSON
// ---------------------------------------------------------------------------

/// Serializa un evento. Los campos opcionales ausentes no se escriben.
Map<String, Object?> eventoAJson(Evento evento) {
  return switch (evento) {
    ConfigurarJugadores ev => {
        'tipo': 'configurarJugadores',
        'jugadores': [
          for (final j in ev.jugadores)
            {'nombre': j.nombre, 'ataqueMaximo': j.ataqueMaximo},
        ],
      },
    ElegirJefe ev => {
        'tipo': 'elegirJefe',
        if (ev.jefeId != null) 'jefeId': ev.jefeId,
        'nombre': ev.nombre,
        'nivel': ev.nivel,
        'hp': ev.hp,
        if (ev.invocacionCadaHp != null)
          'invocacionCadaHp': ev.invocacionCadaHp,
      },
    TurnoJugador ev => {
        'tipo': 'turnoJugador',
        'jugador': ev.jugador,
        'dano': ev.dano,
      },
    AtaqueJefe ev => {
        'tipo': 'ataqueJefe',
        'ranura': ev.ranura,
        'dano': ev.dano,
        if (ev.jugador != null) 'jugador': ev.jugador,
        if (ev.alAzar) 'alAzar': true,
      },
    PokemonKo ev => {'tipo': 'pokemonKo', 'jugador': ev.jugador},
    CartaAnimoRobada ev => {
        'tipo': 'cartaAnimoRobada',
        'jugador': ev.jugador,
        'carta': ev.carta,
      },
    FinTurnoJefe() => {'tipo': 'finTurnoJefe'},
    Abandonar() => {'tipo': 'abandonar'},
    CuracionJefe ev => {'tipo': 'curacionJefe', 'cantidad': ev.cantidad},
    AtaqueAAliado ev => {
        'tipo': 'ataqueAAliado',
        'jugador': ev.jugador,
        'slot': ev.slot,
        'dano': ev.dano,
      },
    SinInvocacion() => {'tipo': 'sinInvocacion'},
    AliadoInvocado ev => {
        'tipo': 'aliadoInvocado',
        'slot': ev.slot,
        'nombre': ev.nombre,
        'hp': ev.hp,
        if (ev.ataqueNombre != null) 'ataqueNombre': ev.ataqueNombre,
        if (ev.ataqueDano != null) 'ataqueDano': ev.ataqueDano,
        if (ev.habilidad != null) 'habilidad': ev.habilidad,
      },
    AtaqueAliado ev => {
        'tipo': 'ataqueAliado',
        'slot': ev.slot,
        'dano': ev.dano,
        if (ev.objetivo != null) 'objetivo': ev.objetivo,
      },
  };
}

/// Lee un evento. Lanza [RegistroInvalido] si la estructura no es válida.
Evento eventoDeJson(Object? json, [String ruta = 'evento']) {
  final c = _Campos.de(json, ruta);
  final tipo = c.texto('tipo');
  switch (tipo) {
    case 'configurarJugadores':
      c.permitir({'tipo', 'jugadores'});
      final lista = c.lista('jugadores');
      if (lista.isEmpty || lista.length > 4) {
        c.falla('«jugadores» debe tener de 1 a 4 elementos');
      }
      return ConfigurarJugadores([
        for (var i = 0; i < lista.length; i++)
          _configJugador(lista[i], '$ruta.jugadores[$i]'),
      ]);
    case 'elegirJefe':
      c.permitir({'tipo', 'jefeId', 'nombre', 'nivel', 'hp', 'invocacionCadaHp'});
      return ElegirJefe(
        jefeId: c.textoOpt('jefeId'),
        nombre: c.texto('nombre'),
        nivel: c.entero('nivel', min: 1, max: 4),
        hp: c.entero('hp', min: 1),
        invocacionCadaHp: c.enteroOpt('invocacionCadaHp', min: 1),
      );
    case 'turnoJugador':
      c.permitir({'tipo', 'jugador', 'dano'});
      return TurnoJugador(
        jugador: c.entero('jugador', min: 0, max: 3),
        dano: c.entero('dano', min: 0),
      );
    case 'ataqueJefe':
      c.permitir({'tipo', 'ranura', 'dano', 'jugador', 'alAzar'});
      return AtaqueJefe(
        ranura: c.entero('ranura', min: 1, max: 3),
        dano: c.entero('dano', min: 0),
        jugador: c.enteroOpt('jugador', min: 0, max: 3),
        alAzar: c.booleano('alAzar'),
      );
    case 'pokemonKo':
      c.permitir({'tipo', 'jugador'});
      return PokemonKo(c.entero('jugador', min: 0, max: 3));
    case 'cartaAnimoRobada':
      c.permitir({'tipo', 'jugador', 'carta'});
      return CartaAnimoRobada(
        jugador: c.entero('jugador', min: 0, max: 3),
        carta: c.entero('carta', min: 1, max: 5),
      );
    case 'finTurnoJefe':
      c.permitir({'tipo'});
      return const FinTurnoJefe();
    case 'abandonar':
      c.permitir({'tipo'});
      return const Abandonar();
    case 'curacionJefe':
      c.permitir({'tipo', 'cantidad'});
      return CuracionJefe(c.entero('cantidad', min: 0));
    case 'ataqueAAliado':
      c.permitir({'tipo', 'jugador', 'slot', 'dano'});
      return AtaqueAAliado(
        jugador: c.entero('jugador', min: 0, max: 3),
        slot: c.entero('slot', min: 0, max: 3),
        dano: c.entero('dano', min: 0),
      );
    case 'sinInvocacion':
      c.permitir({'tipo'});
      return const SinInvocacion();
    case 'aliadoInvocado':
      c.permitir({
        'tipo',
        'slot',
        'nombre',
        'hp',
        'ataqueNombre',
        'ataqueDano',
        'habilidad',
      });
      return AliadoInvocado(
        slot: c.entero('slot', min: 0, max: 3),
        nombre: c.texto('nombre'),
        hp: c.entero('hp', min: 1),
        ataqueNombre: c.textoOpt('ataqueNombre'),
        ataqueDano: c.enteroOpt('ataqueDano', min: 0),
        habilidad: c.textoOpt('habilidad'),
      );
    case 'ataqueAliado':
      c.permitir({'tipo', 'slot', 'dano', 'objetivo'});
      return AtaqueAliado(
        slot: c.entero('slot', min: 0, max: 3),
        dano: c.entero('dano', min: 0),
        objetivo: c.enteroOpt('objetivo', min: 0, max: 3),
      );
    default:
      return c.falla('tipo de evento desconocido «$tipo»');
  }
}

ConfigJugador _configJugador(Object? json, String ruta) {
  final c = _Campos.de(json, ruta);
  c.permitir({'nombre', 'ataqueMaximo'});
  return ConfigJugador(
    nombre: c.texto('nombre'),
    ataqueMaximo: c.entero('ataqueMaximo', min: 0),
  );
}

// ---------------------------------------------------------------------------
// Registro de una partida
// ---------------------------------------------------------------------------

/// Registro completo de una partida: es lo que se guarda y se envía al
/// backend. Contiene el log de eventos y, cuando la partida ha terminado, el
/// resumen de puntos calculado al cerrarla.
class RegistroPartida {
  final int version;

  /// Id generado por el cliente: una partida se guarda una sola vez.
  final String partidaId;

  /// Fecha de creación en ISO 8601 (opcional).
  final String? creadaEn;

  /// Id de cuenta por asiento; null = invitado. null en el conjunto: no se
  /// indica y se asume que todos cobran.
  final List<String?>? cuentas;

  final List<Evento> eventos;

  /// Resumen de puntos guardado al cerrar la partida. Se conserva tal cual
  /// para que cambios futuros de las tablas no reescriban el historial.
  final Map<String, Object?>? resumen;

  /// Estado tras reproducir todos los eventos.
  final EstadoPartida estado;

  RegistroPartida._({
    required this.version,
    required this.partidaId,
    required this.creadaEn,
    required List<String?>? cuentas,
    required List<Evento> eventos,
    required this.resumen,
    required this.estado,
  })  : cuentas = cuentas == null ? null : List.unmodifiable(cuentas),
        eventos = List.unmodifiable(eventos);

  /// Crea el registro de una partida. Si ha terminado, calcula el resumen de
  /// puntos con las tablas vigentes.
  factory RegistroPartida.crear({
    required String partidaId,
    required Iterable<Evento> eventos,
    String? creadaEn,
    List<String?>? cuentas,
  }) {
    final lista = List<Evento>.of(eventos);
    final estado = _validar(partidaId, creadaEn, cuentas, lista);
    Map<String, Object?>? resumen;
    if (estado.terminada) {
      final puntos = calcularPuntos(
        estado,
        asientosConCuenta: cuentas == null
            ? null
            : {
                for (var i = 0; i < cuentas.length; i++)
                  if (cuentas[i] != null) i,
              },
      );
      final jefeId = lista.whereType<ElegirJefe>().first.jefeId;
      resumen = {
        if (jefeId != null) 'jefeId': jefeId,
        ...puntos.toJson(),
      };
    }
    return RegistroPartida._(
      version: versionRegistro,
      partidaId: partidaId,
      creadaEn: creadaEn,
      cuentas: cuentas,
      eventos: lista,
      resumen: resumen,
      estado: estado,
    );
  }

  /// Lee un registro (ya decodificado de JSON). Migra las versiones antiguas,
  /// rechaza las futuras y comprueba que los eventos cumplen las reglas.
  /// Lanza [RegistroInvalido].
  factory RegistroPartida.deJson(Object? json) {
    var c = _Campos.de(json, 'registro');
    var version = c.entero('version', min: 1);
    if (version > versionRegistro) {
      throw RegistroInvalido(
        'versión $version no soportada: este motor lee hasta la versión '
        '$versionRegistro. Actualiza la aplicación.',
      );
    }
    var datos = Map<String, Object?>.of(c.datos);
    while (version < versionRegistro) {
      final migrar = _migraciones[version];
      if (migrar == null) {
        c.falla('no hay migración desde la versión $version');
      }
      datos = migrar(datos);
      version++;
    }
    c = _Campos.de(datos, 'registro');
    c.permitir({
      'version',
      'partidaId',
      'creadaEn',
      'cuentas',
      'eventos',
      'resumen',
    });
    final partidaId = c.texto('partidaId');
    final creadaEn = c.textoOpt('creadaEn');
    final cuentasJson = c.listaOpt('cuentas');
    final cuentas = cuentasJson == null
        ? null
        : [
            for (var i = 0; i < cuentasJson.length; i++)
              _cuenta(cuentasJson[i], 'registro.cuentas[$i]'),
          ];
    final eventosJson = c.lista('eventos');
    final eventos = [
      for (var i = 0; i < eventosJson.length; i++)
        eventoDeJson(eventosJson[i], 'registro.eventos[$i]'),
    ];
    Map<String, Object?>? resumen;
    if (datos.containsKey('resumen')) {
      final r = datos['resumen'];
      if (r is! Map) c.falla('«resumen» debe ser un objeto');
      resumen = Map<String, Object?>.from(r);
    }
    final estado = _validar(partidaId, creadaEn, cuentas, eventos);
    return RegistroPartida._(
      version: versionRegistro,
      partidaId: partidaId,
      creadaEn: creadaEn,
      cuentas: cuentas,
      eventos: eventos,
      resumen: resumen,
      estado: estado,
    );
  }

  /// La partida (estado + registro de eventos).
  Partida get partida => Partida.desdeEventos(eventos);

  Map<String, Object?> toJson() => {
        'version': version,
        'partidaId': partidaId,
        if (creadaEn != null) 'creadaEn': creadaEn,
        if (cuentas != null) 'cuentas': cuentas,
        'eventos': [for (final e in eventos) eventoAJson(e)],
        if (resumen != null) 'resumen': resumen,
      };
}

String? _cuenta(Object? v, String ruta) {
  if (v == null) return null;
  if (v is String && v.isNotEmpty) return v;
  throw RegistroInvalido('$ruta: debe ser un texto no vacío o null (invitado)');
}

/// Comprueba el registro y devuelve el estado final.
EstadoPartida _validar(
  String partidaId,
  String? creadaEn,
  List<String?>? cuentas,
  List<Evento> eventos,
) {
  if (partidaId.isEmpty || partidaId.length > 64) {
    throw const RegistroInvalido('partidaId debe tener de 1 a 64 caracteres');
  }
  if (creadaEn != null && DateTime.tryParse(creadaEn) == null) {
    throw const RegistroInvalido('creadaEn debe ser una fecha ISO 8601');
  }
  if (eventos.isEmpty) {
    throw const RegistroInvalido('el registro necesita al menos un evento');
  }
  var estado = EstadoPartida.inicial();
  for (var i = 0; i < eventos.length; i++) {
    try {
      estado = apply(estado, eventos[i]);
    } on ReglaIncumplida catch (e) {
      throw RegistroInvalido('eventos[$i]: ${e.mensaje}');
    }
  }
  if (cuentas != null && cuentas.length != estado.jugadores.length) {
    throw RegistroInvalido(
      'cuentas debe tener un elemento por jugador '
      '(${estado.jugadores.length}), no ${cuentas.length}',
    );
  }
  return estado;
}

/// Lector de campos de un objeto JSON con mensajes de error útiles.
class _Campos {
  final Map<String, Object?> datos;
  final String ruta;

  _Campos._(this.datos, this.ruta);

  factory _Campos.de(Object? json, String ruta) {
    if (json is! Map) {
      throw RegistroInvalido('$ruta: debe ser un objeto');
    }
    return _Campos._(Map<String, Object?>.from(json), ruta);
  }

  Never falla(String mensaje) => throw RegistroInvalido('$ruta: $mensaje');

  void permitir(Set<String> claves) {
    for (final k in datos.keys) {
      if (!claves.contains(k)) falla('campo desconocido «$k»');
    }
  }

  int entero(String clave, {int? min, int? max}) {
    final v = datos[clave];
    if (v is! int) falla('«$clave» debe ser un entero');
    if (min != null && v < min) falla('«$clave» debe ser como mínimo $min');
    if (max != null && v > max) falla('«$clave» debe ser como máximo $max');
    return v;
  }

  int? enteroOpt(String clave, {int? min, int? max}) {
    if (!datos.containsKey(clave)) return null;
    return entero(clave, min: min, max: max);
  }

  String texto(String clave) {
    final v = datos[clave];
    if (v is! String || v.isEmpty) falla('«$clave» debe ser un texto no vacío');
    return v;
  }

  String? textoOpt(String clave) {
    if (!datos.containsKey(clave)) return null;
    return texto(clave);
  }

  bool booleano(String clave) {
    if (!datos.containsKey(clave)) return false;
    final v = datos[clave];
    if (v is! bool) falla('«$clave» debe ser verdadero o falso');
    return v;
  }

  List<Object?> lista(String clave) {
    final v = datos[clave];
    if (v is! List) falla('«$clave» debe ser una lista');
    return List<Object?>.of(v);
  }

  List<Object?>? listaOpt(String clave) {
    if (!datos.containsKey(clave)) return null;
    return lista(clave);
  }
}
