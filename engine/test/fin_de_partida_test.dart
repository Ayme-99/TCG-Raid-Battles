import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

void main() {
  group('eliminación de jugadores', () {
    test('un solo KO deja al jugador en juego con un Pokémon', () {
      var s = todosActuan(empezar());
      s = apply(s, const PokemonKo(1));
      expect(s.jugadores[1].pokemonVivos, 1);
      expect(s.jugadores[1].eliminado, isFalse);
    });

    test('dos KO eliminan al jugador y no vuelve a actuar', () {
      var s = todosActuan(empezar());
      s = aplicarTodos(s, const [PokemonKo(1), PokemonKo(1), FinTurnoJefe()]);
      expect(s.jugadores[1].eliminado, isTrue);
      expect(s.orden, [0, 2]);
      expect(s.prioridad, isEmpty);
      expect(s.cartasAnimoPendientes, isEmpty);
    });

    test('un jugador eliminado no puede recibir más KO', () {
      var s = todosActuan(empezar());
      s = aplicarTodos(s, const [PokemonKo(1), PokemonKo(1)]);
      expect(() => apply(s, const PokemonKo(1)),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('los Pokémon KO no reviven', () {
      var s = todosActuan(empezar());
      s = apply(s, const PokemonKo(0));
      s = apply(apply(s, const FinTurnoJefe()), const CartaAnimoRobada(jugador: 0, carta: 1));
      expect(s.jugadores[0].pokemonVivos, 1);
      expect(s.jugadores[0].pokemonPerdidos, 1);
    });

    test('si se elimina al jugador al que le toca, se salta su turno', () {
      var s = empezar();
      s = apply(s, const TurnoJugador(jugador: 0, dano: 1));
      expect(s.jugadorActual, 1);
      s = aplicarTodos(s, const [PokemonKo(1), PokemonKo(1)]);
      expect(s.fase, Fase.turnoJugadores);
      expect(s.jugadorActual, 2);
    });

    test('si se elimina al último jugador pendiente, pasa el jefe', () {
      var s = empezar(ataques: const [100, 100]);
      s = apply(s, const TurnoJugador(jugador: 0, dano: 1));
      s = aplicarTodos(s, const [PokemonKo(1), PokemonKo(1)]);
      expect(s.fase, Fase.turnoJefe);
    });

    test('eliminar a un jugador que ya actuó no altera el turno', () {
      var s = empezar();
      s = apply(s, const TurnoJugador(jugador: 0, dano: 1));
      s = aplicarTodos(s, const [PokemonKo(0), PokemonKo(0)]);
      expect(s.jugadorActual, 1);
      s = todosActuan(s);
      expect(s.fase, Fase.turnoJefe);
    });
  });

  group('victoria', () {
    test('daño exacto al HP restante', () {
      final s = apply(
        empezar(ataques: const [100], hp: 80),
        const TurnoJugador(jugador: 0, dano: 80),
      );
      expect(s.resultado, Resultado.victoria);
      expect(s.jefe!.hp, 0);
      expect(s.fase, Fase.terminada);
    });

    test('el exceso de daño no cuenta', () {
      final s = apply(
        empezar(ataques: const [100], hp: 80),
        const TurnoJugador(jugador: 0, dano: 500),
      );
      expect(s.danoPorJugador, [80]);
    });

    test('la victoria corta el resto de turnos', () {
      var s = empezar(hp: 50);
      s = apply(s, const TurnoJugador(jugador: 0, dano: 50));
      expect(s.terminada, isTrue);
      expect(() => apply(s, const TurnoJugador(jugador: 1, dano: 1)),
          throwsA(isA<ReglaIncumplida>()));
      expect(s.danoPorJugador, [50, 0, 0]);
    });

    test('puede ganar el último de la ronda tras varios KO', () {
      var s = empezar(hp: 100);
      s = apply(s, const TurnoJugador(jugador: 0, dano: 30));
      s = aplicarTodos(s, const [PokemonKo(1), PokemonKo(1)]);
      s = apply(s, const TurnoJugador(jugador: 2, dano: 70));
      expect(s.resultado, Resultado.victoria);
      expect(s.danoPorJugador, [30, 0, 70]);
    });

    test('se puede ganar en una ronda posterior', () {
      var s = todosActuan(empezar(hp: 31), dano: 10);
      s = apply(s, const FinTurnoJefe());
      s = apply(s, const TurnoJugador(jugador: 0, dano: 1));
      expect(s.resultado, Resultado.victoria);
      expect(s.ronda, 2);
    });
  });

  group('derrota', () {
    test('solo cuando todos los Pokémon de todos los jugadores caen', () {
      var s = todosActuan(empezar(ataques: const [100, 100]));
      s = aplicarTodos(s, const [PokemonKo(0), PokemonKo(0), PokemonKo(1)]);
      expect(s.terminada, isFalse);
      s = apply(s, const PokemonKo(1));
      expect(s.terminada, isTrue);
      expect(s.resultado, Resultado.derrota);
    });

    test('también puede ocurrir durante el turno de jugadores', () {
      var s = empezar(ataques: const [100]);
      s = aplicarTodos(s, const [PokemonKo(0), PokemonKo(0)]);
      expect(s.resultado, Resultado.derrota);
    });

    test('tras la derrota no se admite ningún evento', () {
      var s = empezar(ataques: const [100]);
      s = aplicarTodos(s, const [PokemonKo(0), PokemonKo(0)]);
      for (final e in const <Evento>[
        TurnoJugador(jugador: 0, dano: 1),
        AtaqueJefe(ranura: 1, dano: 1),
        FinTurnoJefe(),
        CartaAnimoRobada(jugador: 0, carta: 1),
        PokemonKo(0),
      ]) {
        expect(() => apply(s, e), throwsA(isA<ReglaIncumplida>()));
      }
    });

    test('el jefe conserva el HP que le quedaba', () {
      var s = empezar(ataques: const [100], hp: 500);
      s = apply(s, const TurnoJugador(jugador: 0, dano: 120));
      s = aplicarTodos(s, const [PokemonKo(0), PokemonKo(0)]);
      expect(s.jefe!.hp, 380);
      expect(s.resultado, Resultado.derrota);
    });
  });
}
