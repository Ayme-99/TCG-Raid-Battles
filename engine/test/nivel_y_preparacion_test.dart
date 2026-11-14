import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

void main() {
  group('nivel por X con jugadores reales', () {
    final casos = <String, (List<int>, int, int)>{
      '1 jugador': ([150], 150, 1),
      '2 jugadores, X=400': ([200, 200], 400, 1),
      '2 jugadores, X=401': ([200, 201], 401, 2),
      '3 jugadores, X=600': ([200, 200, 200], 600, 2),
      '3 jugadores, X=601': ([200, 200, 201], 601, 3),
      '4 jugadores, X=800': ([200, 200, 200, 200], 800, 3),
      '4 jugadores, X=801': ([200, 200, 200, 201], 801, 4),
      'sin tope: un ataque de 300 cuenta 300': ([300, 300], 600, 2),
    };
    casos.forEach((nombre, caso) {
      test(nombre, () {
        final s = configurar(caso.$1);
        expect(s.x, caso.$2);
        expect(s.nivel, caso.$3);
      });
    });

    test('un ataque de 0 es válido', () {
      final s = configurar([0, 0]);
      expect(s.x, 0);
      expect(s.nivel, 1);
    });
  });

  group('configuración', () {
    test('conserva nombres y asientos por orden', () {
      final s = configurar([10, 20, 30]);
      expect([for (final j in s.jugadores) j.nombre], ['J0', 'J1', 'J2']);
      expect([for (final j in s.jugadores) j.asiento], [0, 1, 2]);
      expect(s.jugadores.every((j) => j.pokemonVivos == 3), isTrue);
    });

    test('rechaza 0 jugadores', () {
      expect(
        () => apply(EstadoPartida.inicial(), const ConfigurarJugadores([])),
        throwsA(isA<ReglaIncumplida>()),
      );
    });

    test('rechaza un ataque negativo', () {
      expect(() => configurar([50, -1]), throwsA(isA<ReglaIncumplida>()));
    });

    test('no se puede configurar dos veces', () {
      final s = configurar([50]);
      expect(() => configurar([50]).runtimeType, returnsNormally);
      expect(
        () => apply(
          s,
          const ConfigurarJugadores([
            ConfigJugador(nombre: 'X', ataqueMaximo: 1),
          ]),
        ),
        throwsA(isA<ReglaIncumplida>()),
      );
    });

    test('no se puede jugar antes de configurar', () {
      expect(
        () => apply(
          EstadoPartida.inicial(),
          const TurnoJugador(jugador: 0, dano: 10),
        ),
        throwsA(isA<ReglaIncumplida>()),
      );
    });
  });

  group('elección de jefe', () {
    test('HP 0 o negativo se rechaza', () {
      final s = configurar([100]);
      for (final hp in [0, -5]) {
        expect(
          () => apply(s, ElegirJefe(nombre: 'J', nivel: 1, hp: hp)),
          throwsA(isA<ReglaIncumplida>()),
        );
      }
    });

    test('empieza la ronda 1 con el primer jugador', () {
      final s = empezar();
      expect(s.fase, Fase.turnoJugadores);
      expect(s.ronda, 1);
      expect(s.orden, [0, 1, 2]);
      expect(s.jugadorActual, 0);
      expect(s.jefe!.hp, s.jefe!.hpMaximo);
      expect(s.cartasAnimoPendientes, isEmpty);
    });

    test('no se puede elegir jefe dos veces', () {
      final s = empezar();
      expect(
        () => apply(s, const ElegirJefe(nombre: 'J', nivel: 1, hp: 100)),
        throwsA(isA<ReglaIncumplida>()),
      );
    });
  });

  group('inmutabilidad', () {
    test('apply no modifica el estado de entrada', () {
      final antes = empezar();
      final copia = antes.toJson().toString();
      apply(antes, const TurnoJugador(jugador: 0, dano: 50));
      expect(antes.toJson().toString(), copia);
    });

    test('las listas del estado no se pueden modificar', () {
      final s = empezar();
      expect(() => s.orden.add(9), throwsUnsupportedError);
      expect(() => s.jugadores.clear(), throwsUnsupportedError);
      expect(() => s.danoPorJugador[0] = 5, throwsUnsupportedError);
    });
  });
}
