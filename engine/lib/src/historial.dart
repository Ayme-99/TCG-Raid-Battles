import 'eventos.dart';
import 'motor.dart';

/// Partida con deshacer y rehacer.
///
/// La verdad es el registro de eventos: deshacer quita el último evento y
/// reconstruye el estado reproduciendo el resto; rehacer lo vuelve a aplicar.
/// Es un valor inmutable, como [Partida].
///
/// Los eventos deshechos solo viven mientras no se aplique uno nuevo: al
/// aplicar un evento distinto se descarta lo que había por rehacer. La pila de
/// rehacer no forma parte del registro guardado (solo se guarda [partida]).
class Historial {
  final Partida partida;
  final List<Evento> _porRehacer;

  Historial._(this.partida, List<Evento> porRehacer)
      : _porRehacer = List<Evento>.unmodifiable(porRehacer);

  factory Historial.nuevo() => Historial._(Partida.nueva(), const []);

  /// Retoma una partida ya registrada (sin nada por rehacer).
  factory Historial.de(Partida partida) => Historial._(partida, const []);

  /// Eventos deshechos, del más antiguo al más reciente de los que se
  /// rehacerán (el siguiente en rehacerse es el último de la lista).
  List<Evento> get porRehacer => _porRehacer;

  bool get puedeDeshacer => partida.eventos.isNotEmpty;
  bool get puedeRehacer => _porRehacer.isNotEmpty;

  /// Aplica un evento nuevo y descarta lo que hubiera por rehacer. Si el
  /// evento incumple las reglas lanza [ReglaIncumplida] y no cambia nada.
  Historial aplicar(Evento evento) =>
      Historial._(partida.aplicar(evento), const []);

  /// Quita el último evento. Sin eventos, devuelve la misma instancia.
  Historial deshacer() {
    if (!puedeDeshacer) return this;
    final eventos = partida.eventos;
    return Historial._(
      Partida.desdeEventos(eventos.sublist(0, eventos.length - 1)),
      [..._porRehacer, eventos.last],
    );
  }

  /// Vuelve a aplicar el último evento deshecho. Sin nada por rehacer,
  /// devuelve la misma instancia.
  Historial rehacer() {
    if (!puedeRehacer) return this;
    return Historial._(
      partida.aplicar(_porRehacer.last),
      _porRehacer.sublist(0, _porRehacer.length - 1),
    );
  }
}
