import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../almacen/almacen.dart';
import '../cuenta/cliente_api.dart';
import '../cuenta/controlador_sesion.dart';
import '../cuenta/sesion.dart';
import '../partida/controlador_partida.dart';
import 'cola_envios.dart';

typedef Cancelar = void Function();

/// Programa una llamada dentro de [Duration] y devuelve cómo cancelarla. Se
/// sustituye en los tests para no esperar de verdad.
typedef Programador = Cancelar Function(Duration, void Function());

final programadorProvider = Provider<Programador>(
  (ref) => (espera, accion) {
    final temporizador = Timer(espera, accion);
    return temporizador.cancel;
  },
);

const Object _sin = Object();

/// Lo que la interfaz necesita saber del envío de resultados.
class EstadoEnvios {
  const EstadoEnvios({
    this.pendientes = 0,
    this.rechazadas = 0,
    this.enviando = false,
    this.partidaEncolada,
    this.mensaje,
  });

  /// Partidas guardadas en el dispositivo que aún no están en el servidor.
  final int pendientes;

  /// Partidas que el servidor ha rechazado (no se reintentan).
  final int rechazadas;
  final bool enviando;

  /// Id de la partida en juego, si ya se ha pulsado «Guardar resultados».
  /// Mientras haya valor, deshacer queda desactivado.
  final String? partidaEncolada;

  /// Último aviso para el usuario (sin conexión, sesión caducada, rechazo).
  final String? mensaje;

  EstadoEnvios copiarCon({
    int? pendientes,
    int? rechazadas,
    bool? enviando,
    Object? partidaEncolada = _sin,
    Object? mensaje = _sin,
  }) =>
      EstadoEnvios(
        pendientes: pendientes ?? this.pendientes,
        rechazadas: rechazadas ?? this.rechazadas,
        enviando: enviando ?? this.enviando,
        partidaEncolada: identical(partidaEncolada, _sin)
            ? this.partidaEncolada
            : partidaEncolada as String?,
        mensaje: identical(mensaje, _sin) ? this.mensaje : mensaje as String?,
      );
}

/// Guarda la partida terminada en la cola y la envía al servidor, con
/// reintentos. Se envía al pulsar «Guardar resultados», al volver la sesión,
/// al abrir la app y cuando vence la espera tras un fallo de red.
class ControladorEnvios extends Notifier<EstadoEnvios> {
  Cancelar? _cancelarReintento;
  bool _procesando = false;
  bool _vivo = true;

  ColaEnvios get _cola => ColaEnvios(ref.read(almacenProvider));

  @override
  EstadoEnvios build() {
    _vivo = true;
    ref.onDispose(() {
      _vivo = false;
      _cancelarReintento?.call();
    });
    // Al iniciar sesión (o leerla al arrancar) se envía lo que esté pendiente.
    ref.listen<Sesion?>(sesionActualProvider, (_, sesion) {
      if (sesion != null) unawaited(procesar());
    });
    // Al empezar otra partida vuelve a permitirse deshacer.
    ref.listen<EstadoPartida>(estadoProvider, (_, estado) {
      if (!estado.terminada && state.partidaEncolada != null) {
        state = state.copiarCon(partidaEncolada: null);
      }
    });
    unawaited(Future.microtask(_arrancar));
    return const EstadoEnvios();
  }

  /// Guarda la partida terminada y empieza a enviarla. Devuelve `null` si se
  /// ha encolado o el motivo por el que no se puede.
  Future<String?> guardarPartidaActual() async {
    final sesion = ref.read(sesionActualProvider);
    final estado = ref.read(estadoProvider);
    if (sesion == null) return 'Inicia sesión para guardar los puntos.';
    if (!estado.terminada) return 'La partida todavía no ha terminado.';
    // El host (jugador 1) es la cuenta; los demás van como invitados.
    final registro = ref.read(partidaProvider.notifier).registro(
      cuentas: [
        sesion.userId,
        for (var i = 1; i < estado.jugadores.length; i++) null,
      ],
    );
    await _cola.encolar(registro.toJson());
    if (!_vivo) return null;
    state = state.copiarCon(partidaEncolada: registro.partidaId, mensaje: null);
    await _recargar();
    unawaited(procesar());
    return null;
  }

  /// Intenta enviar todo lo pendiente, en orden. Se detiene en el primer fallo
  /// de red y programa el reintento.
  Future<void> procesar() async {
    if (_procesando) return;
    final sesion = ref.read(sesionActualProvider);
    if (sesion == null) return;
    _procesando = true;
    _cancelarReintento?.call();
    _cancelarReintento = null;
    state = state.copiarCon(enviando: true);
    String? aviso;
    try {
      final api = ref.read(clienteApiProvider);
      for (final envio in await _cola.pendientes()) {
        final respuesta = await api.enviarPartida(sesion.token, envio.registro);
        if (!_vivo) return;
        switch (respuesta.resultado) {
          case ResultadoEnvio.guardada:
            await _cola.quitar(envio.partidaId);
          case ResultadoEnvio.rechazada:
            final motivo = respuesta.mensaje ?? 'El servidor la ha rechazado.';
            await _cola.rechazar(envio.partidaId, motivo);
            aviso = 'Partida rechazada: $motivo';
            state = state.copiarCon(mensaje: aviso);
          case ResultadoEnvio.sesionCaducada:
            await ref.read(sesionProvider.notifier).cerrarSesion();
            state = state.copiarCon(
              mensaje: 'La sesión ha caducado: inicia sesión de nuevo para '
                  'enviar las partidas.',
            );
            return;
          case ResultadoEnvio.reintentar:
            final intentos = await _cola.registrarFallo(envio.partidaId);
            _cancelarReintento = ref.read(programadorProvider)(
              esperaTrasFallo(intentos),
              () => unawaited(procesar()),
            );
            state = state.copiarCon(
              mensaje: 'Sin conexión con el servidor: se reintentará solo.',
            );
            return;
        }
      }
      // Todo lo pendiente se ha enviado; solo queda el aviso de un rechazo.
      state = state.copiarCon(mensaje: aviso);
    } finally {
      _procesando = false;
      if (_vivo) {
        await _recargar();
        if (_vivo) state = state.copiarCon(enviando: false);
      }
    }
  }

  // Al crearse cuenta lo que hay en la cola y, si ya hay sesión (la leyó antes
  // el controlador de sesión), envía lo pendiente. Si la sesión llega después,
  // lo hace el listener de `build`.
  Future<void> _arrancar() async {
    await _recargar();
    if (_vivo) await procesar();
  }

  /// Olvida las partidas rechazadas.
  Future<void> descartarRechazadas() async {
    await _cola.descartarRechazadas();
    await _recargar();
  }

  Future<void> _recargar() async {
    final pendientes = (await _cola.pendientes()).length;
    final rechazadas = (await _cola.rechazadas()).length;
    if (!_vivo) return;
    state = state.copiarCon(pendientes: pendientes, rechazadas: rechazadas);
  }
}

final enviosProvider =
    NotifierProvider<ControladorEnvios, EstadoEnvios>(ControladorEnvios.new);
