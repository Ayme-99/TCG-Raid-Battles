import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

void main() {
  group('turno de jugadores', () {
    test('actúan por orden de asiento y luego el jefe', () {
      var s = empezar();
      for (final j in [0, 1, 2]) {
        expect(s.jugadorActual, j);
        s = apply(s, TurnoJugador(jugador: j, dano: 10));
      }
      expect(s.fase, Fase.turnoJefe);
      expect(s.jugadorActual, isNull);
    });

    test('actuar fuera de turno se rechaza', () {
      final s = empezar();
      expect(
        () => apply(s, const TurnoJugador(jugador: 2, dano: 10)),
        throwsA(isA<ReglaIncumplida>()),
      );
    });

    test('jugador inexistente se rechaza', () {
      final s = empezar();
      expect(
        () => apply(s, const TurnoJugador(jugador: 7, dano: 10)),
        throwsA(isA<ReglaIncumplida>()),
      );
    });

    test('daño negativo se rechaza y 0 es válido', () {
      final s = empezar();
      expect(
        () => apply(s, const TurnoJugador(jugador: 0, dano: -1)),
        throwsA(isA<ReglaIncumplida>()),
      );
      final t = apply(s, const TurnoJugador(jugador: 0, dano: 0));
      expect(t.jefe!.hp, 1000);
      expect(t.jugadorActual, 1);
    });

    test('el daño se acumula por jugador', () {
      final s = todosActuan(empezar(), dano: 25);
      expect(s.danoPorJugador, [25, 25, 25]);
      expect(s.jefe!.hp, 925);
    });

    test('el jefe no puede actuar en el turno de jugadores', () {
      final s = empezar();
      expect(
        () => apply(s, const AtaqueJefe(ranura: 1, dano: 10)),
        throwsA(isA<ReglaIncumplida>()),
      );
      expect(() => apply(s, const FinTurnoJefe()),
          throwsA(isA<ReglaIncumplida>()));
    });
  });

  group('turno del jefe', () {
    test('ranuras válidas son 1 a 3', () {
      final s = todosActuan(empezar());
      for (final r in [0, 4]) {
        expect(
          () => apply(s, AtaqueJefe(ranura: r, dano: 10)),
          throwsA(isA<ReglaIncumplida>()),
        );
      }
      for (final r in [1, 2, 3]) {
        expect(() => apply(s, AtaqueJefe(ranura: r, dano: 10)),
            returnsNormally);
      }
    });

    test('cuenta los ataques y los reinicia en la ronda siguiente', () {
      var s = todosActuan(empezar());
      s = apply(s, const AtaqueJefe(ranura: 1, dano: 30));
      s = apply(s, const AtaqueJefe(ranura: 2, dano: 60, alAzar: true));
      expect(s.ataquesJefeEnTurno, 2);
      s = apply(s, const FinTurnoJefe());
      expect(s.ataquesJefeEnTurno, 0);
      expect(s.ronda, 2);
      expect(s.fase, Fase.turnoJugadores);
    });

    test('puede atacar a todos (sin objetivo) o a uno vivo', () {
      final s = todosActuan(empezar());
      expect(() => apply(s, const AtaqueJefe(ranura: 1, dano: 10)),
          returnsNormally);
      expect(
        () => apply(s, const AtaqueJefe(ranura: 1, dano: 10, jugador: 1)),
        returnsNormally,
      );
    });

    test('no puede atacar a un jugador eliminado', () {
      var s = todosActuan(empezar());
      s = aplicarTodos(s, const [PokemonKo(1), PokemonKo(1)]);
      expect(
        () => apply(s, const AtaqueJefe(ranura: 1, dano: 10, jugador: 1)),
        throwsA(isA<ReglaIncumplida>()),
      );
    });

    test('daño negativo del jefe se rechaza', () {
      final s = todosActuan(empezar());
      expect(
        () => apply(s, const AtaqueJefe(ranura: 1, dano: -1)),
        throwsA(isA<ReglaIncumplida>()),
      );
    });
  });

  group('prioridad por KO y carta de ánimo', () {
    test('sin KO el orden se mantiene entre rondas', () {
      final s = apply(todosActuan(empezar()), const FinTurnoJefe());
      expect(s.orden, [0, 1, 2]);
      expect(s.cartasAnimoPendientes, isEmpty);
    });

    test('varios KO se sientan el turno siguiente', () {
      var s = todosActuan(empezar());
      s = aplicarTodos(s, const [PokemonKo(2), PokemonKo(0), FinTurnoJefe()]);
      expect(s.orden, [1]);
      expect(s.jugadorActual, 1);
      expect(s.cartasAnimoPendientes, [0, 2]);
    });

    test('el turno sentado dura una sola ronda', () {
      var s = todosActuan(empezar());
      s = aplicarTodos(s, const [PokemonKo(1), FinTurnoJefe()]);
      expect(s.orden, [0, 2]);
      s = apply(todosActuan(s), const FinTurnoJefe());
      expect(s.orden, [0, 1, 2]);
      expect(s.ronda, 3);
    });

    test('un KO durante el turno de jugadores también se sienta el siguiente',
        () {
      var s = empezar();
      s = apply(s, const TurnoJugador(jugador: 0, dano: 5));
      s = apply(s, const PokemonKo(1));
      expect(s.jugadorActual, 1);
      s = apply(todosActuan(s), const FinTurnoJefe());
      expect(s.orden, [0, 2]);
    });

    test('si todos los que siguen en juego están KO, salta al turno del jefe',
        () {
      var s = todosActuan(empezar(ataques: const [100, 100]));
      s = aplicarTodos(s, const [PokemonKo(0), PokemonKo(1), FinTurnoJefe()]);
      expect(s.ronda, 2);
      expect(s.fase, Fase.turnoJefe);
      expect(s.jugadorActual, isNull);
    });

    test('un jugador KO no puede actuar su turno sentado', () {
      var s = todosActuan(empezar());
      s = aplicarTodos(s, const [PokemonKo(1), FinTurnoJefe()]);
      expect(
        () => apply(s, const TurnoJugador(jugador: 1, dano: 10)),
        throwsA(isA<ReglaIncumplida>()),
      );
    });

    test('el ataque del jefe contra un jugador KO falla', () {
      var s = todosActuan(empezar());
      s = apply(s, const PokemonKo(1));
      // En el mismo turno del jefe y durante todo el de la ronda siguiente.
      expect(
        () => apply(s, const AtaqueJefe(ranura: 1, dano: 10, jugador: 1)),
        throwsA(isA<ReglaIncumplida>()),
      );
      s = apply(s, const FinTurnoJefe());
      s = todosActuan(s);
      expect(
        () => apply(s, const AtaqueJefe(ranura: 1, dano: 10, jugador: 1)),
        throwsA(isA<ReglaIncumplida>()),
      );
      expect(
        () => apply(s, const AtaqueJefe(ranura: 1, dano: 10, jugador: 0)),
        returnsNormally,
      );
      // Pasada esa ronda vuelve a poder recibirlo.
      s = todosActuan(apply(s, const FinTurnoJefe()));
      expect(
        () => apply(s, const AtaqueJefe(ranura: 1, dano: 10, jugador: 1)),
        returnsNormally,
      );
    });

    test('un jugador con el banquillo KO no gana dos prioridades', () {
      var s = todosActuan(empezar());
      s = apply(s, const PokemonKo(0));
      expect(s.prioridad, [0]);
    });

    test('cada jugador con prioridad roba una carta, una sola vez', () {
      var s = todosActuan(empezar());
      s = aplicarTodos(s, const [PokemonKo(0), PokemonKo(2), FinTurnoJefe()]);
      s = apply(s, const CartaAnimoRobada(jugador: 2, carta: 5));
      expect(s.cartasAnimoPendientes, [0]);
      s = apply(s, const CartaAnimoRobada(jugador: 0, carta: 1));
      expect(s.cartasAnimoPendientes, isEmpty);
      expect([for (final c in s.cartasAnimo) (c.ronda, c.jugador, c.carta)],
          [(2, 2, 5), (2, 0, 1)]);
    });

    test('carta inválida o de quien no tiene prioridad se rechaza', () {
      var s = todosActuan(empezar());
      s = aplicarTodos(s, const [PokemonKo(0), FinTurnoJefe()]);
      for (final carta in [0, 6]) {
        expect(
          () => apply(s, CartaAnimoRobada(jugador: 0, carta: carta)),
          throwsA(isA<ReglaIncumplida>()),
        );
      }
      expect(
        () => apply(s, const CartaAnimoRobada(jugador: 1, carta: 1)),
        throwsA(isA<ReglaIncumplida>()),
      );
    });

    test('no se roba carta en el turno del jefe', () {
      final s = todosActuan(empezar());
      expect(
        () => apply(s, const CartaAnimoRobada(jugador: 0, carta: 1)),
        throwsA(isA<ReglaIncumplida>()),
      );
    });

    test('las cartas robadas se acumulan entre rondas', () {
      var s = todosActuan(empezar());
      s = aplicarTodos(s, const [
        PokemonKo(1),
        FinTurnoJefe(),
        CartaAnimoRobada(jugador: 1, carta: 2),
      ]);
      s = todosActuan(s);
      s = aplicarTodos(s, const [
        PokemonKo(2),
        FinTurnoJefe(),
        CartaAnimoRobada(jugador: 2, carta: 4),
      ]);
      expect(s.cartasAnimo.length, 2);
      expect(s.cartasAnimo.map((c) => c.ronda), [2, 3]);
    });
  });

  group('ataques de aliados contra un jugador KO', () {
    EstadoPartida conAliadoEnSlotKo() {
      final s0 = configurar(const [100, 100, 100]);
      var s = apply(
        s0,
        ElegirJefe(nombre: 'Jefe', nivel: s0.nivel, hp: 3000, invocacionCadaHp: 600),
      );
      s = conIntentos(apply(s, const TurnoJugador(jugador: 0, dano: 10)));
      s = apply(s, const PokemonKo(0));
      return apply(
        s,
        const AliadoInvocado(
          slot: 0,
          categoria: CategoriaAliado.danio,
          nombre: 'Plusle',
          hp: 80,
          ataqueNombre: 'Chispazo',
          ataqueDano: 30,
        ),
      );
    }

    test('el ataque de entrada falla: se resuelve pero no cuenta como uso', () {
      var s = conAliadoEnSlotKo();
      expect(s.entradasPendientes, hasLength(1));
      s = apply(s, const AtaqueAliado(slot: 0, dano: 0));
      final a = s.aliadoEn(0)!;
      expect(s.entradasPendientes, isEmpty);
      expect(a.entradaResuelta, isTrue);
      expect(a.usos, 0);
    });

    test('contra un jugador que no está KO el ataque cuenta como uso', () {
      var s = conAliadoEnSlotKo();
      s = apply(s, const AtaqueAliado(slot: 0, dano: 30, objetivo: 1));
      expect(s.aliadoEn(0)!.usos, 1);
    });
  });

  group('KO fuera de fase', () {
    test('no hay KO antes de empezar ni después de terminar', () {
      expect(
        () => apply(configurar([100]), const PokemonKo(0)),
        throwsA(isA<ReglaIncumplida>()),
      );
      final fin = apply(
        empezar(ataques: const [100], hp: 10),
        const TurnoJugador(jugador: 0, dano: 10),
      );
      expect(fin.terminada, isTrue);
      expect(() => apply(fin, const PokemonKo(0)),
          throwsA(isA<ReglaIncumplida>()));
    });
  });
}
