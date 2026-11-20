import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../almacen/almacen.dart';
import '../cuenta/controlador_sesion.dart';
import 'ataque_mesa.dart';
import 'persistencia.dart';

/// Controlador de la partida en curso.
///
/// La lógica vive en el motor (`engine/`): reductor puro, registro de eventos,
/// deshacer y reproducción determinista. El estado de la interfaz es solo el
/// [Historial] del motor; este controlador le envía eventos y expone deshacer
/// y rehacer. Las pantallas no deben duplicar ninguna regla.
class ControladorPartida extends Notifier<Historial> {
  // Id y fecha del registro. Se generan al pedir el registro y se mantienen
  // mientras la lista de eventos no cambie, para que dos registros de la misma
  // partida sean idénticos (el servidor rechaza un mismo id con otro contenido).
  String? _partidaId;
  String? _creadaEn;

  // En una sala (D-19) el host fija el id y la fecha para todos y no cambian
  // mientras dura la partida.
  bool _identidadFija = false;

  // Solo el host: avisa de cada evento que registra, para difundirlo.
  void Function(Evento)? _alRegistrar;

  // Solo un jugador que no es el host: sus eventos no se aplican aquí, se
  // proponen al host y llegan difundidos (D-19 §D1).
  String? Function(Evento)? _alProponer;

  @override
  Historial build() {
    // Si la app se cerró a mitad de partida, se retoma donde estaba.
    final guardada = ref.read(partidaInicialProvider);
    _partidaId = guardada?.partidaId;
    _creadaEn = guardada?.creadaEn;
    return guardada?.historial ?? Historial.nuevo();
  }

  /// Guarda la partida en el dispositivo para recuperarla al reabrir la app.
  /// No espera ni propaga fallos: perder el guardado no debe parar la partida.
  void _guardar() {
    unawaited(
      guardarPartidaEnCurso(
        ref.read(almacenProvider),
        eventos: state.partida.eventos,
        partidaId: _partidaId,
        creadaEn: _creadaEn,
      ).catchError((_) {}),
    );
  }

  /// Empieza una partida nueva y descarta la actual.
  void nuevaPartida() {
    ref.read(colaAtaquesMesaProvider.notifier).limpiar();
    ref.read(enfoqueAtaqueProvider.notifier).state = null;
    ref.read(danoFijadoProvider.notifier).state = const {};
    ref.read(dobleUsadoProvider.notifier).state = -1;
    salirDeSala();
    _olvidarIdentidad();
    state = Historial.nuevo();
    _guardar();
  }

  void _olvidarIdentidad() {
    if (_identidadFija) return;
    _partidaId = null;
    _creadaEn = null;
  }

  /// Pasa a jugar en una sala (T-81). El host fija [partidaId] y [creadaEn] y
  /// llegan a todos. [alRegistrar] es solo del host: se le avisa de cada
  /// evento que registra para difundirlo. En una sala no hay deshacer ni
  /// rehacer (D-19).
  void entrarEnSala({
    required String partidaId,
    required String creadaEn,
    void Function(Evento)? alRegistrar,
    String? Function(Evento)? alProponer,
  }) {
    _identidadFija = true;
    _partidaId = partidaId;
    _creadaEn = creadaEn;
    _alRegistrar = alRegistrar;
    _alProponer = alProponer;
    ref.read(enSalaProvider.notifier).state = true;
  }

  /// Vuelve al juego de un solo dispositivo.
  void salirDeSala() {
    _identidadFija = false;
    _alRegistrar = null;
    _alProponer = null;
    ref.read(enSalaProvider.notifier).state = false;
  }

  /// Aplica un evento que el host ha difundido (solo en una sala). Devuelve
  /// `null` si se aplicó o el motivo por el que las reglas lo rechazan.
  String? aplicarDeSala(Evento evento) {
    try {
      state = state.aplicar(evento);
      return null;
    } on ReglaIncumplida catch (e) {
      return e.mensaje;
    }
  }

  /// Registra un evento. Devuelve `null` si se aplicó, o el motivo por el que
  /// las reglas lo rechazan; en ese caso la partida no cambia. Un jugador de
  /// una sala que no es el host no aplica nada: el evento se propone al host y
  /// `null` quiere decir «enviado» (la respuesta llega difundida o rechazada).
  String? registrar(Evento evento) {
    final proponer = _alProponer;
    if (proponer != null) return proponer(evento);
    try {
      final antes = state.partida.estado;
      state = state.aplicar(evento);
      _olvidarIdentidad();
      _guardar();
      _alRegistrar?.call(evento);
      ref.read(colaAtaquesMesaProvider.notifier).alRegistrar(antes, evento);
      return null;
    } on ReglaIncumplida catch (e) {
      return e.mensaje;
    }
  }

  /// Juega el turno del jefe entero (T-77): el motor compone los eventos con
  /// el mazo y el azar de la app y se registran en orden. Pensado para el
  /// formato digital, donde nadie escribe los ataques a mano. Devuelve `null`
  /// si se registró todo, o el motivo del primer rechazo (los eventos
  /// anteriores ya se aplicaron).
  String? turnoDelJefeAutomatico(DatosJefe datos, {PreguntaMesa? alPreguntarMesa}) {
    final eventos = turnoJefeAutomatico(
      state.partida.estado,
      ref.read(mazoAtaquesJefeProvider),
      ref.read(azarProvider),
      datos,
      alPreguntarMesa: alPreguntarMesa ?? (_) => false,
    );
    for (final evento in eventos) {
      final error = registrar(evento);
      if (error != null) return error;
    }
    return null;
  }

  /// Quita el último evento (no hace nada si no hay ninguno).
  void deshacer() {
    if (ref.read(enSalaProvider)) return;
    _olvidarIdentidad();
    state = state.deshacer();
    _guardar();
  }

  /// Vuelve a aplicar el último evento deshecho.
  void rehacer() {
    if (ref.read(enSalaProvider)) return;
    _olvidarIdentidad();
    state = state.rehacer();
    _guardar();
  }

  /// Registro de la partida según el contrato (`contrato/`), con el resumen de
  /// puntos si ha terminado. [cuentas] lleva un elemento por asiento: el id de
  /// cuenta, o `null` si es un invitado.
  RegistroPartida registro({List<String?>? cuentas}) {
    _partidaId ??= ref.read(generadorIdProvider)();
    _creadaEn ??= ref.read(relojProvider)().toUtc().toIso8601String();
    // La identidad se guarda con la partida: tras reabrir la app, volver a
    // enviarla lleva el mismo id y el servidor no la cuenta dos veces.
    _guardar();
    return RegistroPartida.crear(
      partidaId: _partidaId!,
      eventos: state.partida.eventos,
      creadaEn: _creadaEn,
      cuentas: cuentas,
    );
  }
}

/// Partida que había en curso al abrir la app (la lee `main.dart` del
/// almacén antes de arrancar). Sin valor, se empieza una nueva.
/// Daño fijado por jugador (asiento → daño): se rellena solo en sus turnos
/// siguientes, para repetir el mismo ataque varias rondas.
final danoFijadoProvider = StateProvider<Map<int, int>>((ref) => const {});

/// Ronda en la que ya se usó el «doble daño» de la carta de ánimo 1 (una sola
/// vez por carta); -1 si no se ha usado.
final dobleUsadoProvider = StateProvider<int>((ref) => -1);

final partidaInicialProvider = Provider<PartidaGuardada?>((ref) => null);

final partidaProvider =
    NotifierProvider<ControladorPartida, Historial>(ControladorPartida.new);

/// Estado actual de la partida.
final estadoProvider = Provider<EstadoPartida>(
  (ref) => ref.watch(partidaProvider.select((h) => h.partida.estado)),
);

/// Si la partida es de una sala (varios dispositivos). Mientras lo es, no hay
/// deshacer ni rehacer.
final enSalaProvider = StateProvider<bool>((ref) => false);

final puedeDeshacerProvider = Provider<bool>(
  (ref) =>
      !ref.watch(enSalaProvider) &&
      ref.watch(partidaProvider.select((h) => h.puedeDeshacer)),
);

final puedeRehacerProvider = Provider<bool>(
  (ref) =>
      !ref.watch(enSalaProvider) &&
      ref.watch(partidaProvider.select((h) => h.puedeRehacer)),
);

/// Puntos de la partida, o `null` mientras no ha terminado. Con la sesión
/// iniciada solo cobra el jugador 1 (el host) y los demás son invitados; sin
/// ella se enseñan los puntos como si cobraran todos.
final puntosProvider = Provider<PuntosPartida?>((ref) {
  final estado = ref.watch(estadoProvider);
  if (!estado.terminada) return null;
  final conSesion = ref.watch(sesionActualProvider) != null;
  return calcularPuntos(estado, asientosConCuenta: conSesion ? {0} : null);
});

/// Generador del id de partida (lo crea el cliente; el servidor lo usa para
/// no guardar dos veces la misma partida). Se sustituye en los tests.
final generadorIdProvider = Provider<String Function()>((ref) => generarIdPartida);

/// Reloj de la app, para poder fijarlo en los tests.
final relojProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Azar de la app (dados de invocación y monedas), para fijarlo en los tests.
final azarProvider = Provider<Random>((ref) => Random.secure());

/// Mazo de ataques del jefe (20 cartas). Se sustituye en los tests para
/// fijar qué carta sale.
///
/// Las cartas dependen de cuántos jugadores hay (3 jugadores: sin las del
/// Jugador 4; 2: las del 3 y el 4 pasan al 1 y al 2), así que el mazo se
/// rehace cuando cambia ese número.
final mazoAtaquesJefeProvider = Provider<MazoAtaquesJefe>((ref) {
  final jugadores = ref.watch(estadoProvider.select((e) => e.jugadores.length));
  return MazoAtaquesJefe(
    ref.watch(azarProvider),
    jugadores: jugadores.clamp(1, 4),
  );
});

/// 32 caracteres hexadecimales aleatorios (16 bytes), bien por debajo de los
/// 64 que admite el contrato.
String generarIdPartida() {
  final azar = Random.secure();
  return [
    for (var i = 0; i < 16; i++) azar.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}
