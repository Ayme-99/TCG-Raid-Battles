import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

/// Un sitio de la mesa donde puede empezar o acabar un ataque: `jefe`,
/// `aliado-N` (slot N) o `jugador-N` (asiento N).
typedef PuntoMesa = String;

const PuntoMesa puntoJefe = 'jefe';

/// Varios sitios a la vez (un ataque que va a todos los jugadores).
const PuntoMesa puntoTodos = 'todos';
PuntoMesa puntoAliado(int slot) => 'aliado-$slot';
PuntoMesa puntoJugador(int asiento) => 'jugador-$asiento';

/// Un ataque que la mesa enseña: de [origen] a cada uno de [destinos], con el
/// [dano] que hace. Es solo visual: el motor ya lo ha aplicado.
class AtaqueMesa {
  AtaqueMesa({
    required this.id,
    required this.origen,
    required this.destinos,
    required this.dano,
  }) : creado = DateTime.now();

  /// Cuándo se registró, para descartar los que se quedaron sin enseñar.
  final DateTime creado;

  final int id;
  final PuntoMesa origen;
  final List<PuntoMesa> destinos;
  final int dano;

  /// Quién ataca, para elegir el color: `jefe`, `aliado` o `jugador`.
  String get atacante => origen.split('-').first;
}

/// Qué ataque hay que enseñar para [evento], dado el estado de [antes] de
/// aplicarlo, o null si el evento no es un ataque o no llega a nada (por
/// ejemplo, un aliado que ataca a un jugador que ya está KO).
AtaqueMesa? ataqueDe(EstadoPartida antes, Evento evento, {int id = 0}) {
  switch (evento) {
    case AtaqueJefe(:final dano, :final jugador):
      final destinos = jugador != null
          ? [puntoJugador(jugador)]
          : [
              for (final j in antes.jugadores)
                if (!j.eliminado) puntoJugador(j.asiento),
            ];
      if (destinos.isEmpty) return null;
      return AtaqueMesa(
        id: id,
        origen: puntoJefe,
        destinos: destinos,
        dano: dano,
      );
    case AtaqueAliado(:final slot, :final dano, :final objetivo):
      final destino = objetivo ?? slot;
      if (destino < 0 ||
          destino >= antes.jugadores.length ||
          antes.jugadores[destino].eliminado) {
        return null;
      }
      return AtaqueMesa(
        id: id,
        origen: puntoAliado(slot),
        destinos: [puntoJugador(destino)],
        dano: dano,
      );
    case TurnoJugador(:final jugador, :final dano):
      // Sin daño al jefe (ataca a un aliado o no hace nada) no hay nada que
      // enseñar contra el jefe.
      if (dano <= 0) return null;
      return AtaqueMesa(
        id: id,
        origen: puntoJugador(jugador),
        destinos: const [puntoJefe],
        dano: dano,
      );
    case AtaqueAAliado(:final jugador, :final slot, :final dano):
      return AtaqueMesa(
        id: id,
        origen: puntoJugador(jugador),
        destinos: [puntoAliado(slot)],
        dano: dano,
      );
    default:
      return null;
  }
}

/// Ataques pendientes de enseñar, en orden. Un turno del jefe automático
/// registra varios seguidos: se ven uno detrás de otro.
class ColaAtaquesMesa extends Notifier<List<AtaqueMesa>> {
  int _siguiente = 1;

  @override
  List<AtaqueMesa> build() => const [];

  /// Añade el ataque de [evento] si lo hay. [antes] es el estado previo.
  void alRegistrar(EstadoPartida antes, Evento evento) {
    final ataque = ataqueDe(antes, evento, id: _siguiente);
    if (ataque == null) return;
    _siguiente++;
    state = [...state, ataque];
  }

  /// Olvida lo pendiente.
  void limpiar() => state = const [];

  /// Quita los ataques que llevan demasiado esperando: la mesa se fue antes
  /// de enseñarlos y ya no tiene sentido enseñarlos tarde.
  void descartarCaducados() {
    final limite = DateTime.now().subtract(const Duration(seconds: 8));
    final vigentes = [
      for (final a in state)
        if (a.creado.isAfter(limite)) a,
    ];
    if (vigentes.length != state.length) state = vigentes;
  }

  /// La mesa ha terminado de enseñar el ataque [id].
  void terminar(int id) => state = [
        for (final a in state)
          if (a.id != id) a,
      ];
}

final colaAtaquesMesaProvider =
    NotifierProvider<ColaAtaquesMesa, List<AtaqueMesa>>(ColaAtaquesMesa.new);

/// Sitio al que debe mirar la cámara mientras se enseña un ataque: primero a
/// quien ataca y, cuando sale el proyectil, al objetivo. null: no hay ataque.
final enfoqueAtaqueProvider = StateProvider<PuntoMesa?>((ref) => null);

/// Las claves con las que la mesa localiza cada sitio para dibujar el ataque
/// de uno a otro.
class ClavesMesa {
  final _claves = <PuntoMesa, GlobalKey>{};

  GlobalKey clave(PuntoMesa punto) =>
      _claves.putIfAbsent(punto, () => GlobalKey(debugLabel: punto));

  /// Caja de [punto] en pantalla, o null si ahora no está en la mesa.
  RenderBox? caja(PuntoMesa punto) {
    final objeto = _claves[punto]?.currentContext?.findRenderObject();
    if (objeto is RenderBox && objeto.attached && objeto.hasSize) return objeto;
    return null;
  }
}

final clavesMesaProvider = Provider<ClavesMesa>((ref) => ClavesMesa());
