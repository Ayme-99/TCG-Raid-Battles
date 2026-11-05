import 'package:incursiones_engine/incursiones_engine.dart';

/// Estado tras configurar jugadores con el daño de su mejor ataque.
EstadoPartida configurar(List<int> ataques) => apply(
      EstadoPartida.inicial(),
      ConfigurarJugadores([
        for (var i = 0; i < ataques.length; i++)
          ConfigJugador(nombre: 'J$i', ataqueMaximo: ataques[i]),
      ]),
    );

/// Partida lista para el turno de jugadores de la ronda 1.
/// Por defecto X = 300 (nivel 1) y un jefe de 1000 HP.
EstadoPartida empezar({
  List<int> ataques = const [100, 100, 100],
  int hp = 1000,
}) {
  final s = configurar(ataques);
  return apply(s, ElegirJefe(nombre: 'Jefe', nivel: s.nivel, hp: hp));
}

/// Hace actuar a todos los jugadores que quedan en la ronda, sin tocar al
/// jefe más de lo que indique [dano]. Termina en el turno del jefe.
EstadoPartida todosActuan(EstadoPartida s, {int dano = 1}) {
  while (s.fase == Fase.turnoJugadores) {
    s = apply(s, TurnoJugador(jugador: s.jugadorActual!, dano: dano));
  }
  return s;
}

EstadoPartida aplicarTodos(EstadoPartida s, Iterable<Evento> eventos) {
  for (final e in eventos) {
    s = apply(s, e);
  }
  return s;
}
