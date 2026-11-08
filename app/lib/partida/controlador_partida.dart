import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../cuenta/controlador_sesion.dart';

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

  @override
  Historial build() => Historial.nuevo();

  /// Empieza una partida nueva y descarta la actual.
  void nuevaPartida() {
    _olvidarIdentidad();
    state = Historial.nuevo();
  }

  void _olvidarIdentidad() {
    _partidaId = null;
    _creadaEn = null;
  }

  /// Registra un evento. Devuelve `null` si se aplicó, o el motivo por el que
  /// las reglas lo rechazan; en ese caso la partida no cambia.
  String? registrar(Evento evento) {
    try {
      state = state.aplicar(evento);
      _olvidarIdentidad();
      return null;
    } on ReglaIncumplida catch (e) {
      return e.mensaje;
    }
  }

  /// Quita el último evento (no hace nada si no hay ninguno).
  void deshacer() {
    _olvidarIdentidad();
    state = state.deshacer();
  }

  /// Vuelve a aplicar el último evento deshecho.
  void rehacer() {
    _olvidarIdentidad();
    state = state.rehacer();
  }

  /// Registro de la partida según el contrato (`contrato/`), con el resumen de
  /// puntos si ha terminado. [cuentas] lleva un elemento por asiento: el id de
  /// cuenta, o `null` si es un invitado.
  RegistroPartida registro({List<String?>? cuentas}) {
    _partidaId ??= ref.read(generadorIdProvider)();
    _creadaEn ??= ref.read(relojProvider)().toUtc().toIso8601String();
    return RegistroPartida.crear(
      partidaId: _partidaId!,
      eventos: state.partida.eventos,
      creadaEn: _creadaEn,
      cuentas: cuentas,
    );
  }
}

final partidaProvider =
    NotifierProvider<ControladorPartida, Historial>(ControladorPartida.new);

/// Estado actual de la partida.
final estadoProvider = Provider<EstadoPartida>(
  (ref) => ref.watch(partidaProvider.select((h) => h.partida.estado)),
);

final puedeDeshacerProvider = Provider<bool>(
  (ref) => ref.watch(partidaProvider.select((h) => h.puedeDeshacer)),
);

final puedeRehacerProvider = Provider<bool>(
  (ref) => ref.watch(partidaProvider.select((h) => h.puedeRehacer)),
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

/// 32 caracteres hexadecimales aleatorios (16 bytes), bien por debajo de los
/// 64 que admite el contrato.
String generarIdPartida() {
  final azar = Random.secure();
  return [
    for (var i = 0; i < 16; i++) azar.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}
