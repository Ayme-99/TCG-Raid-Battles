import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

const _config = ConfigurarJugadores([
  ConfigJugador(nombre: 'Ana', ataqueMaximo: 120),
  ConfigJugador(nombre: 'Bea', ataqueMaximo: 100),
]);

// X = 220 -> nivel 1.
List<Evento> _inicio() => [
      _config,
      const ElegirJefe(nombre: 'Jefe', nivel: 1, hp: 300),
    ];

void main() {
  group('reglas', () {
    test('niveles por X (el umbral pertenece al nivel superior)', () {
      expect(nivelPorX(0), 1);
      expect(nivelPorX(249), 1);
      expect(nivelPorX(400), 1);
      expect(nivelPorX(401), 2);
      expect(nivelPorX(600), 2);
      expect(nivelPorX(601), 3);
      expect(nivelPorX(800), 3);
      expect(nivelPorX(801), 4);
    });

    test('el ataque se limita a 200', () {
      expect(ataqueParaX(350), 350);
      expect(ataqueParaX(-5), 0);
      expect(ataqueParaX(90), 90);
    });
  });

  group('preparación', () {
    test('calcula X y nivel', () {
      final s = apply(EstadoPartida.inicial(), _config);
      expect(s.x, 220);
      expect(s.nivel, 1);
      expect(s.fase, Fase.eleccionJefe);
    });

    test('no limita el ataque de cada jugador (hay cartas de más de 200)', () {
      final s = apply(
        EstadoPartida.inicial(),
        const ConfigurarJugadores([
          ConfigJugador(nombre: 'A', ataqueMaximo: 500),
        ]),
      );
      expect(s.x, 500);
    });

    test('el jefe debe ser del nivel de la partida', () {
      final s = apply(EstadoPartida.inicial(), _config);
      expect(
        () => apply(s, const ElegirJefe(nombre: 'J', nivel: 2, hp: 100)),
        throwsA(isA<ReglaIncumplida>()),
      );
    });

    test('rechaza más de 4 jugadores', () {
      final cinco = ConfigurarJugadores([
        for (var i = 0; i < 5; i++)
          ConfigJugador(nombre: 'J$i', ataqueMaximo: 50),
      ]);
      expect(
        () => apply(EstadoPartida.inicial(), cinco),
        throwsA(isA<ReglaIncumplida>()),
      );
    });
  });

  group('partida', () {
    test('victoria: el jefe llega a 0 HP y el daño sobrante no cuenta', () {
      final s = reproducir([
        ..._inicio(),
        const TurnoJugador(jugador: 0, dano: 120),
        const TurnoJugador(jugador: 1, dano: 100),
        const AtaqueJefe(ranura: 1, dano: 30, jugador: 0),
        const FinTurnoJefe(),
        const TurnoJugador(jugador: 0, dano: 200),
      ]);
      expect(s.fase, Fase.terminada);
      expect(s.resultado, Resultado.victoria);
      expect(s.jefe!.hp, 0);
      // 120 + 100 = 220; quedaban 80, así que el último golpe cuenta 80.
      expect(s.danoPorJugador, [200, 100]);
    });

    test('solo actúa el jugador al que le toca', () {
      final s = reproducir(_inicio());
      expect(
        () => apply(s, const TurnoJugador(jugador: 1, dano: 10)),
        throwsA(isA<ReglaIncumplida>()),
      );
    });

    test('tras actuar todos, llega el turno del jefe', () {
      final s = reproducir([
        ..._inicio(),
        const TurnoJugador(jugador: 0, dano: 10),
        const TurnoJugador(jugador: 1, dano: 10),
      ]);
      expect(s.fase, Fase.turnoJefe);
    });

    test('derrota: todos los Pokémon de todos los jugadores KO', () {
      final s = reproducir([
        ..._inicio(),
        const TurnoJugador(jugador: 0, dano: 10),
        const TurnoJugador(jugador: 1, dano: 10),
        const PokemonKo(0),
        const PokemonKo(0),
        const PokemonKo(1),
        const PokemonKo(1),
      ]);
      expect(s.fase, Fase.terminada);
      expect(s.resultado, Resultado.derrota);
    });

    test('un KO se sienta el turno siguiente (solo roba carta de ánimo)', () {
      final s = reproducir([
        ..._inicio(),
        const TurnoJugador(jugador: 0, dano: 10),
        const TurnoJugador(jugador: 1, dano: 10),
        const PokemonKo(1),
        const FinTurnoJefe(),
      ]);
      expect(s.ronda, 2);
      expect(s.orden, [0]);
      expect(s.cartasAnimoPendientes, [1]);
    });

    test('dos KO del mismo jugador lo eliminan y no se sienta turno', () {
      final s = reproducir([
        ..._inicio(),
        const TurnoJugador(jugador: 0, dano: 10),
        const TurnoJugador(jugador: 1, dano: 10),
        const PokemonKo(1),
        const PokemonKo(1),
        const FinTurnoJefe(),
      ]);
      expect(s.jugadores[1].eliminado, isTrue);
      expect(s.orden, [0]);
      expect(s.cartasAnimoPendientes, isEmpty);
    });

    test('la carta de ánimo se roba una vez por prioridad', () {
      final base = reproducir([
        ..._inicio(),
        const TurnoJugador(jugador: 0, dano: 10),
        const TurnoJugador(jugador: 1, dano: 10),
        const PokemonKo(1),
        const FinTurnoJefe(),
      ]);
      final s = apply(base, const CartaAnimoRobada(jugador: 1, carta: 3));
      expect(s.cartasAnimoPendientes, isEmpty);
      expect(s.cartasAnimo.single.carta, 3);
      expect(
        () => apply(s, const CartaAnimoRobada(jugador: 1, carta: 2)),
        throwsA(isA<ReglaIncumplida>()),
      );
    });

    test('un evento inválido no cambia el estado anterior', () {
      final s = reproducir(_inicio());
      final antes = s.toJson().toString();
      expect(
        () => apply(s, const FinTurnoJefe()),
        throwsA(isA<ReglaIncumplida>()),
      );
      expect(s.toJson().toString(), antes);
    });
  });

  group('reproducción', () {
    final eventos = <Evento>[
      ..._inicio(),
      const TurnoJugador(jugador: 0, dano: 50),
      const TurnoJugador(jugador: 1, dano: 40),
      const AtaqueJefe(ranura: 2, dano: 60, jugador: 1),
      const PokemonKo(1),
      const FinTurnoJefe(),
      const CartaAnimoRobada(jugador: 1, carta: 1),
      const TurnoJugador(jugador: 0, dano: 300),
    ];

    test('la misma lista de eventos da siempre el mismo estado final', () {
      final a = reproducir(eventos);
      final b = reproducir(eventos);
      expect(a.toJson(), equals(b.toJson()));
      expect(a.resultado, Resultado.victoria);
    });

    test('Partida guarda el registro y se reconstruye igual', () {
      var p = Partida.nueva();
      for (final e in eventos) {
        p = p.aplicar(e);
      }
      expect(p.eventos.length, eventos.length);
      final q = Partida.desdeEventos(p.eventos);
      expect(q.estado.toJson(), equals(p.estado.toJson()));
    });
  });
}
