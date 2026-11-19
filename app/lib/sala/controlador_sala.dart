import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../cuenta/cliente_api.dart';
import '../cuenta/controlador_sesion.dart';
import '../partida/controlador_partida.dart';
import 'canal_sala.dart';
import 'cliente_sala.dart';

/// Lo que la interfaz necesita saber de la sala.
class EstadoSala {
  const EstadoSala({
    this.conexion = EstadoConexion.cerrada,
    this.codigo,
    this.info,
    this.caidos = const {},
    this.error,
    this.cancelada = false,
  });

  final EstadoConexion conexion;

  /// Código de la sala, o `null` si no estamos en ninguna.
  final String? codigo;
  final InfoSala? info;

  /// Jugadores caídos con la hora en que vence su ventana de 2 minutos.
  final Map<int, DateTime> caidos;

  /// Último error que se puede enseñar (el servidor o la red).
  final String? error;

  /// El servidor ha cancelado la partida (se cayó el host).
  final bool cancelada;

  bool get enSala => codigo != null;

  EstadoSala copiar({
    EstadoConexion? conexion,
    InfoSala? info,
    Map<int, DateTime>? caidos,
    String? error,
    bool? cancelada,
  }) =>
      EstadoSala(
        conexion: conexion ?? this.conexion,
        codigo: codigo,
        info: info ?? this.info,
        caidos: caidos ?? this.caidos,
        error: error ?? this.error,
        cancelada: cancelada ?? this.cancelada,
      );
}

/// Cómo abre la app el canal con el servidor. Se sustituye en los tests.
final fabricaCanalProvider = Provider<FabricaCanal>((ref) => abrirCanalWebSocket);

/// Dirección del WebSocket de las salas.
final urlSalaProvider = Provider<Uri>((ref) => Uri.parse(urlSalaDe(urlApi)));

/// Sala de la partida multi-dispositivo (D-19). Une el cliente del protocolo
/// con la partida: el host aplica con el motor lo que proponen los demás y lo
/// difunde; el resto solo aplica lo que el host difunde.
class ControladorSala extends Notifier<EstadoSala> {
  ClienteSala? _cliente;
  StreamSubscription<NovedadSala>? _novedades;

  @override
  EstadoSala build() {
    ref.onDispose(_liberarCliente);
    return const EstadoSala();
  }

  /// Crea una sala y entra en ella como host. Devuelve `null` si fue bien o
  /// el mensaje del fallo.
  Future<String?> crear() async {
    final sesion = ref.read(sesionActualProvider);
    if (sesion == null) return 'Inicia sesión para jugar en una sala.';
    final String codigo;
    try {
      codigo = await ref.read(clienteApiProvider).crearSala(sesion.token);
    } on ErrorApi catch (e) {
      return e.mensaje;
    }
    return unirse(codigo);
  }

  /// Entra en una sala con su código. Devuelve `null` si se empezó a
  /// conectar o el motivo por el que no se puede. El resultado (sala llena,
  /// no existe...) llega después en [EstadoSala.error].
  Future<String?> unirse(String codigo) async {
    final sesion = ref.read(sesionActualProvider);
    if (sesion == null) return 'Inicia sesión para jugar en una sala.';
    if (_cliente != null) return 'Ya estás en una sala.';
    final partida = ref.read(partidaProvider.notifier);
    final cliente = ClienteSala(
      codigo: codigo.trim().toUpperCase(),
      token: sesion.token,
      url: ref.read(urlSalaProvider),
      fabrica: ref.read(fabricaCanalProvider),
      alAplicar: (seq, evento) => partida.aplicarDeSala(evento),
      alProponer: (asiento, evento) => partida.registrar(evento),
    );
    _cliente = cliente;
    state = EstadoSala(codigo: cliente.codigo);
    _novedades = cliente.novedades.listen(_alNovedad);
    cliente.conectar();
    return null;
  }

  /// Solo el host: cierra la sala a nuevas entradas y empieza la partida. El
  /// id y la fecha los fija él y llegan a todos (D-19 §D8).
  String? empezar() {
    final cliente = _cliente;
    if (cliente == null || !cliente.soyHost) return 'Solo el host puede empezar.';
    final jugadores = cliente.info?.jugadores.length ?? 0;
    if (jugadores < 2) return 'Hacen falta al menos 2 jugadores.';
    final id = ref.read(generadorIdProvider)();
    final creadaEn = ref.read(relojProvider)().toUtc().toIso8601String();
    cliente.empezar(id, creadaEn);
    return null;
  }

  /// Solo el host: echa a un jugador antes de empezar.
  void echar(int asiento) => _cliente?.echar(asiento);

  /// Propone un evento al host (no se aplica hasta que llegue difundido).
  /// Devuelve `null` si se envió o el motivo por el que no se puede.
  String? proponer(Evento evento) {
    final cliente = _cliente;
    if (cliente == null || cliente.info?.enCurso != true) {
      return 'La partida no está en curso.';
    }
    if (cliente.soyHost) return 'El host juega directamente.';
    cliente.proponer(evento);
    return null;
  }

  /// Mi asiento en la sala, o `null` si no estoy en ninguna.
  int? get miAsiento => _cliente?.info?.tuAsiento;

  /// Quita el aviso de «partida cancelada» una vez visto.
  void descartarCancelada() => state = const EstadoSala();

  /// Sale de la sala. En el lobby avisa al servidor; en partida equivale a
  /// desconectarse (y empieza la ventana de 2 minutos para los demás).
  Future<void> salir() async {
    final cliente = _cliente;
    if (cliente == null) return;
    if (cliente.info?.enCurso != true) cliente.salir();
    await _soltar();
    state = const EstadoSala();
  }

  /// Cierra el cliente y deja la partida otra vez en modo un dispositivo. Si
  /// la partida de la sala estaba a medias se descarta (sin el host no hay
  /// forma de seguirla); si ya había terminado se conserva para guardar los
  /// resultados.
  Future<void> _soltar() async {
    final partida = ref.read(partidaProvider.notifier);
    if (ref.read(enSalaProvider) && !ref.read(estadoProvider).terminada) {
      partida.nuevaPartida();
    } else {
      partida.salirDeSala();
    }
    await _liberarCliente();
  }

  Future<void> _liberarCliente() async {
    final cliente = _cliente;
    _cliente = null;
    await _novedades?.cancel();
    _novedades = null;
    await cliente?.cerrar();
  }

  void _alNovedad(NovedadSala n) {
    final cliente = _cliente;
    if (cliente == null) return;
    switch (n) {
      case ConexionCambiada(:final estado):
        state = state.copiar(conexion: estado);
      case SalaActualizada(:final info):
        final caidos = {
          for (final e in state.caidos.entries)
            if (info.jugadores.any((j) => j.asiento == e.key && !j.conectado))
              e.key: e.value,
        };
        state = state.copiar(info: info, caidos: caidos);
        _prepararPartida(cliente, info);
      case JugadorSeCae(:final asiento, :final venceEn):
        state = state.copiar(caidos: {...state.caidos, asiento: venceEn});
      case JugadorVuelve(:final asiento):
        state = state.copiar(caidos: {...state.caidos}..remove(asiento));
      case VentanaVencida(:final asiento):
        _darPorEliminado(asiento);
        state = state.copiar(caidos: {...state.caidos}..remove(asiento));
      case PropuestaRechazada(:final motivo):
        state = state.copiar(error: motivo);
      case PartidaCancelada():
        // Si la partida ya había terminado, el host solo cerró la sala: no es
        // una cancelación y hay que dejar guardar los resultados.
        final terminada = ref.read(estadoProvider).terminada;
        unawaited(_soltar());
        state = terminada ? const EstadoSala() : const EstadoSala(cancelada: true);
      case ErrorDeSala(:final texto, :final fatal):
        if (fatal) {
          unawaited(_soltar());
          state = EstadoSala(error: texto);
        } else {
          state = state.copiar(error: texto);
        }
    }
  }

  /// Al empezar la partida la sala pasa a modo partida: el host fija la
  /// identidad y difunde lo que registra.
  void _prepararPartida(ClienteSala cliente, InfoSala info) {
    final partida = ref.read(partidaProvider.notifier);
    if (!info.enCurso || info.partidaId == null || info.creadaEn == null) return;
    if (ref.read(enSalaProvider)) return; // ya preparada (reconexión)
    partida.entrarEnSala(
      partidaId: info.partidaId!,
      creadaEn: info.creadaEn!,
      alRegistrar: info.soyHost ? cliente.difundir : null,
      alProponer: info.soyHost ? null : (evento) => proponer(evento),
    );
  }

  /// El host registra un `PokemonKo` por cada Pokémon que le quede al jugador
  /// cuya ventana venció (D-19 §D9).
  void _darPorEliminado(int asiento) {
    final partida = ref.read(partidaProvider.notifier);
    final jugador = ref
        .read(estadoProvider)
        .jugadores
        .where((j) => j.asiento == asiento)
        .firstOrNull;
    if (jugador == null) return;
    for (var i = 0; i < jugador.pokemonVivos; i++) {
      if (partida.registrar(PokemonKo(asiento)) != null) break;
    }
  }
}

final salaProvider =
    NotifierProvider<ControladorSala, EstadoSala>(ControladorSala.new);

/// Mi asiento en la sala, o `null` si no estoy en ninguna.
final miAsientoProvider = Provider<int?>(
  (ref) => ref.watch(salaProvider.select((s) => s.info?.tuAsiento)),
);

/// Si soy el host de la sala en la que estoy.
final soyHostProvider = Provider<bool>(
  (ref) => ref.watch(salaProvider.select((s) => s.info?.soyHost ?? false)),
);
