import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:incursiones_engine/incursiones_engine.dart';

import 'canal_sala.dart';

/// Versión del protocolo de sala que habla esta app (`contrato/sala/`).
const int versionProtocolo = 1;

/// Errores del servidor tras los cuales reintentar no sirve.
const Set<String> _erroresFatales = {
  'protocoloNoSoportado',
  'sesionNoValida',
  'salaNoExiste',
  'salaLlena',
  'salaCerrada',
  'noEresDeLaSala',
};

class JugadorSala {
  const JugadorSala({
    required this.asiento,
    required this.nombre,
    required this.conectado,
  });

  final int asiento;
  final String nombre;
  final bool conectado;
}

/// Estado de la sala tal como lo cuenta el servidor.
class InfoSala {
  const InfoSala({
    required this.estado,
    required this.host,
    required this.tuAsiento,
    required this.jugadores,
    required this.ultimoSeq,
    this.partidaId,
    this.creadaEn,
  });

  /// `abierta`, `completa`, `enCurso`, `terminada` o `cancelada`.
  final String estado;
  final int host;
  final int tuAsiento;
  final List<JugadorSala> jugadores;
  final int ultimoSeq;
  final String? partidaId;
  final String? creadaEn;

  bool get soyHost => tuAsiento == host;
  bool get enCurso => estado == 'enCurso';
}

enum EstadoConexion { conectando, conectada, reconectando, cerrada }

/// Lo que el cliente cuenta a quien lo usa (la interfaz o el controlador).
sealed class NovedadSala {
  const NovedadSala();
}

class ConexionCambiada extends NovedadSala {
  const ConexionCambiada(this.estado);
  final EstadoConexion estado;
}

class SalaActualizada extends NovedadSala {
  const SalaActualizada(this.info);
  final InfoSala info;
}

class JugadorSeCae extends NovedadSala {
  const JugadorSeCae(this.asiento, this.venceEn);
  final int asiento;
  final DateTime venceEn;
}

class JugadorVuelve extends NovedadSala {
  const JugadorVuelve(this.asiento);
  final int asiento;
}

/// Solo la recibe el host: venció la ventana de este jugador y le toca
/// registrar un `PokemonKo` por cada Pokémon que le quede (D-19 §D9).
class VentanaVencida extends NovedadSala {
  const VentanaVencida(this.asiento);
  final int asiento;
}

/// El host ha rechazado una propuesta nuestra.
class PropuestaRechazada extends NovedadSala {
  const PropuestaRechazada(this.idMensaje, this.motivo);
  final String idMensaje;
  final String motivo;
}

class PartidaCancelada extends NovedadSala {
  const PartidaCancelada(this.motivo, this.texto);
  final String motivo;
  final String? texto;
}

/// Error del servidor (con su código del protocolo) o de sincronización
/// (`desincronizada`). Los fatales cierran el cliente.
class ErrorDeSala extends NovedadSala {
  const ErrorDeSala(this.codigo, this.texto, {required this.fatal});
  final String codigo;
  final String texto;
  final bool fatal;
}

/// Aplica un evento que el host ha difundido. Devuelve `null` si se aplicó o
/// el motivo por el que las reglas lo rechazan.
typedef AplicarEventoDifundido = String? Function(int seq, Evento evento);

/// Solo el host: aplica con el motor la propuesta de un jugador. Debe llamar
/// a [ClienteSala.difundir] si la acepta (el cliente le pone el `idMensaje`).
/// Devuelve `null` si la aceptó o el motivo del rechazo.
typedef ProponerAlMotor = String? Function(int asiento, Evento evento);

/// Cliente del protocolo de sala (D-19, `contrato/sala/`).
///
/// - Autentica con `hola` (el token nunca va en la URL) y se reconecta solo,
///   con espera creciente, pidiendo lo que le falta desde su último `seq`.
/// - Aplica los eventos difundidos **en orden y una sola vez**; si falta uno,
///   se reconecta para pedir el registro. Un cliente que no es el host
///   **nunca aplica** un evento que no haya difundido el host.
/// - Las propuestas llevan `idMensaje` y se repiten tras reconectar hasta que
///   llega su respuesta (el servidor no las aplica dos veces).
class ClienteSala {
  ClienteSala({
    required this.codigo,
    required this.token,
    required Uri url,
    required FabricaCanal fabrica,
    required this.alAplicar,
    this.alProponer,
    int ultimoSeq = 0,
    Duration Function(int intento)? espera,
    String Function()? generarId,
  })  : _url = url,
        _fabrica = fabrica,
        _ultimoSeq = ultimoSeq,
        _espera = espera ?? _esperaCreciente,
        _generarId = generarId ?? _idAleatorio;

  final String codigo;
  final String token;
  final AplicarEventoDifundido alAplicar;
  final ProponerAlMotor? alProponer;

  final Uri _url;
  final FabricaCanal _fabrica;
  final Duration Function(int intento) _espera;
  final String Function() _generarId;
  final StreamController<NovedadSala> _novedades =
      StreamController<NovedadSala>.broadcast();

  CanalSala? _canal;
  StreamSubscription<String>? _suscripcion;
  Timer? _temporizador;
  int _intentos = 0;
  int _ultimoSeq;
  bool _cerrado = false;
  bool _conectada = false;
  InfoSala? _info;
  String? _idEnCurso;
  final Map<String, Evento> _pendientes = <String, Evento>{};

  Stream<NovedadSala> get novedades => _novedades.stream;

  /// Último evento aplicado en este dispositivo.
  int get ultimoSeq => _ultimoSeq;

  InfoSala? get info => _info;
  bool get conectada => _conectada;
  bool get soyHost => _info?.soyHost ?? false;

  /// Propuestas enviadas que aún no han recibido respuesta.
  int get propuestasPendientes => _pendientes.length;

  /// Abre la conexión y manda el `hola`. Sigue sola desde aquí.
  void conectar() {
    if (_cerrado) return;
    _abrir();
  }

  // ----------------------------------------------------------- conexión

  void _abrir() {
    if (_cerrado) return;
    _avisar(ConexionCambiada(
      _intentos == 0 ? EstadoConexion.conectando : EstadoConexion.reconectando,
    ));
    final CanalSala canal;
    try {
      canal = _fabrica(_url);
    } catch (_) {
      _programarReconexion();
      return;
    }
    _canal = canal;
    _suscripcion = canal.mensajes.listen(
      (texto) => _alRecibir(canal, texto),
      onError: (Object _) {},
      onDone: () => _alCortarse(canal),
    );
    _enviar({
      'tipo': 'hola',
      'protocolo': versionProtocolo,
      'token': token,
      'codigo': codigo,
      'ultimoSeq': _ultimoSeq,
    });
  }

  void _alCortarse(CanalSala canal) {
    if (!identical(canal, _canal)) return; // ya se había sustituido
    _canal = null;
    _conectada = false;
    _suscripcion = null;
    _programarReconexion();
  }

  void _programarReconexion() {
    if (_cerrado) return;
    _intentos++;
    _avisar(const ConexionCambiada(EstadoConexion.reconectando));
    _temporizador?.cancel();
    _temporizador = Timer(_espera(_intentos), _abrir);
  }

  /// Corta la conexión y la reabre pidiendo el registro desde [_ultimoSeq].
  void _resincronizar() {
    final canal = _canal;
    if (canal == null) return;
    _conectada = false;
    unawaited(canal.cerrar());
  }

  /// Cierra para siempre (salir de la sala).
  Future<void> cerrar() async {
    if (_cerrado) return;
    _cerrado = true;
    _conectada = false;
    _temporizador?.cancel();
    await _suscripcion?.cancel();
    final canal = _canal;
    _canal = null;
    await canal?.cerrar();
    _avisar(const ConexionCambiada(EstadoConexion.cerrada));
    await _novedades.close();
  }

  // ------------------------------------------------------------ recibir

  void _alRecibir(CanalSala canal, String texto) {
    if (_cerrado || !identical(canal, _canal)) return;
    try {
      final json = jsonDecode(texto);
      if (json is! Map) return;
      _tratar(Map<String, Object?>.from(json));
    } catch (_) {
      // Mensaje mal formado: se ignora. Si era un evento, el hueco hará que
      // se vuelva a pedir el registro con el siguiente.
    }
  }

  void _tratar(Map<String, Object?> m) {
    switch (m['tipo']) {
      case 'sala':
        _alSala(m);
      case 'evento':
        final idMensaje = m['idMensaje'];
        if (idMensaje is String) _pendientes.remove(idMensaje);
        _entregar(m['seq']! as int, eventoDeJson(m['evento']));
      case 'registro':
        final desde = m['desdeSeq']! as int;
        final eventos = m['eventos']! as List<Object?>;
        for (var i = 0; i < eventos.length; i++) {
          _entregar(desde + i, eventoDeJson(eventos[i]));
        }
      case 'proponer':
        _alProponer(m);
      case 'rechazar':
        final id = m['idMensaje']! as String;
        if (_pendientes.remove(id) != null) {
          _avisar(PropuestaRechazada(id, m['motivo']! as String));
        }
      case 'jugadorDesconectado':
        _avisar(JugadorSeCae(
          m['asiento']! as int,
          DateTime.parse(m['venceEn']! as String),
        ));
      case 'jugadorVuelve':
        _avisar(JugadorVuelve(m['asiento']! as int));
      case 'ventanaVencida':
        _avisar(VentanaVencida(m['asiento']! as int));
      case 'partidaCancelada':
        _avisar(PartidaCancelada(
          m['motivo']! as String,
          m['texto'] as String?,
        ));
        unawaited(cerrar());
      case 'error':
        _alError(m);
      case 'ping':
        _enviar({'tipo': 'pong'});
    }
  }

  void _alSala(Map<String, Object?> m) {
    final jugadores = <JugadorSala>[
      for (final j in m['jugadores']! as List<Object?>)
        _jugadorDe(Map<String, Object?>.from(j! as Map)),
    ];
    final info = InfoSala(
      estado: m['estado']! as String,
      host: m['host']! as int,
      tuAsiento: m['tuAsiento']! as int,
      jugadores: jugadores,
      ultimoSeq: m['ultimoSeq']! as int,
      partidaId: m['partidaId'] as String?,
      creadaEn: m['creadaEn'] as String?,
    );
    _info = info;
    final primera = !_conectada;
    _conectada = true;
    _intentos = 0;
    if (primera) {
      _avisar(const ConexionCambiada(EstadoConexion.conectada));
      // Tras reconectar se repiten las propuestas sin respuesta, con el mismo
      // idMensaje: el servidor no las aplica dos veces.
      _pendientes.forEach(_enviarPropuesta);
    }
    _avisar(SalaActualizada(info));
  }

  static JugadorSala _jugadorDe(Map<String, Object?> j) => JugadorSala(
        asiento: j['asiento']! as int,
        nombre: j['nombre']! as String,
        conectado: j['conectado']! as bool,
      );

  void _alError(Map<String, Object?> m) {
    final codigoError = m['codigo']! as String;
    final fatal = _erroresFatales.contains(codigoError);
    _avisar(ErrorDeSala(codigoError, m['texto']! as String, fatal: fatal));
    if (fatal) unawaited(cerrar());
  }

  /// Aplica un evento difundido, en orden y una sola vez.
  void _entregar(int seq, Evento evento) {
    if (seq <= _ultimoSeq) return; // ya lo teníamos
    if (seq != _ultimoSeq + 1) {
      _resincronizar(); // falta alguno: se pide el registro
      return;
    }
    final error = alAplicar(seq, evento);
    if (error != null) {
      _avisar(ErrorDeSala('desincronizada', error, fatal: false));
      return;
    }
    _ultimoSeq = seq;
  }

  // --------------------------------------------------------------- host

  /// Reglas D-19 §D2: un jugador solo propone su turno y su ataque a aliados.
  static bool _puedeProponer(int asiento, Evento e) => switch (e) {
        TurnoJugador(:final jugador) => jugador == asiento,
        AtaqueAAliado(:final jugador) => jugador == asiento,
        _ => false,
      };

  void _alProponer(Map<String, Object?> m) {
    final propone = alProponer;
    final id = m['idMensaje']! as String;
    if (propone == null || !soyHost) {
      _enviar({'tipo': 'rechazar', 'idMensaje': id, 'motivo': 'no soy el host'});
      return;
    }
    final asiento = m['asiento']! as int;
    final Evento evento;
    try {
      evento = eventoDeJson(m['evento']);
    } catch (_) {
      _enviar({'tipo': 'rechazar', 'idMensaje': id, 'motivo': 'evento no válido'});
      return;
    }
    if (!_puedeProponer(asiento, evento)) {
      _enviar({
        'tipo': 'rechazar',
        'idMensaje': id,
        'motivo': 'ese jugador no puede proponer ese evento',
      });
      return;
    }
    _idEnCurso = id;
    String? error;
    try {
      error = propone(asiento, evento);
    } finally {
      _idEnCurso = null;
    }
    if (error != null) {
      _enviar({'tipo': 'rechazar', 'idMensaje': id, 'motivo': error});
    }
  }

  /// Solo el host: difunde un evento que ya ha aplicado en su dispositivo. Si
  /// responde a una propuesta lleva su `idMensaje`.
  void difundir(Evento evento) {
    final seq = ++_ultimoSeq;
    _enviar({
      'tipo': 'aceptar',
      'seq': seq,
      'evento': eventoAJson(evento),
      if (_idEnCurso != null) 'idMensaje': _idEnCurso,
    });
  }

  void empezar(String partidaId, String creadaEn) =>
      _enviar({'tipo': 'empezar', 'partidaId': partidaId, 'creadaEn': creadaEn});

  void echar(int asiento) => _enviar({'tipo': 'echar', 'asiento': asiento});

  // ------------------------------------------------------------ jugador

  /// Propone un evento al host. No se aplica aquí: llegará difundido si el
  /// host lo acepta. Devuelve el `idMensaje`.
  String proponer(Evento evento) {
    final id = _generarId();
    _pendientes[id] = evento;
    if (_conectada) _enviarPropuesta(id, evento);
    return id;
  }

  void _enviarPropuesta(String id, Evento evento) => _enviar({
        'tipo': 'proponer',
        'idMensaje': id,
        'evento': eventoAJson(evento),
      });

  void salir() => _enviar({'tipo': 'salir'});

  // ------------------------------------------------------------ interno

  void _enviar(Map<String, Object?> mensaje) {
    try {
      _canal?.enviar(jsonEncode(mensaje));
    } catch (_) {
      // El canal se estaba cortando: onDone se encarga.
    }
  }

  void _avisar(NovedadSala n) {
    if (!_novedades.isClosed) _novedades.add(n);
  }

  static Duration _esperaCreciente(int intento) {
    final segundos = min(15, 1 << min(intento - 1, 4)); // 1, 2, 4, 8, 15…
    return Duration(seconds: segundos);
  }

  static final Random _azar = Random();
  static int _contador = 0;

  static String _idAleatorio() =>
      'm${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '${_azar.nextInt(1 << 20).toRadixString(36)}-${_contador++}';
}
