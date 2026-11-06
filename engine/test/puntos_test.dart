import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

/// Partida terminada con el reparto de daño indicado, por asiento.
/// El jefe es de nivel 1 con [hp]; las bajas se aplican antes del golpe final.
EstadoPartida _victoria(
  List<int> danos, {
  List<int> bajas = const [],
  int hp = 2382,
}) {
  assert(danos.fold<int>(0, (a, b) => a + b) == hp);
  var s = empezar(ataques: [for (final _ in danos) 100], hp: hp);
  for (final a in bajas) {
    s = apply(s, PokemonKo(a));
  }
  // Cada jugador pega su parte en su turno; el último remata.
  while (!s.terminada) {
    final a = s.jugadorActual!;
    s = apply(s, TurnoJugador(jugador: a, dano: danos[a]));
  }
  return s;
}

void main() {
  group('totales', () {
    test('victoria: el tope del nivel', () {
      for (final e in topeVictoriaPorNivel.entries) {
        expect(
          puntosTotales(
            nivel: e.key,
            hpJefe: 2382,
            danoTotal: 2382,
            resultado: Resultado.victoria,
          ),
          e.value,
        );
      }
    });

    test('derrota: round(daño × Y ÷ 4) + 1', () {
      // 1000 × (3000 ÷ 2382) ÷ 4 = 314,86 → 315, más 1.
      expect(
        puntosTotales(
          nivel: 1,
          hpJefe: 2382,
          danoTotal: 1000,
          resultado: Resultado.derrota,
        ),
        316,
      );
    });

    test('perder sin hacer daño da 1 punto', () {
      expect(
        puntosTotales(
          nivel: 4,
          hpJefe: 5205,
          danoTotal: 0,
          resultado: Resultado.derrota,
        ),
        1,
      );
    });

    test('perder habiendo bajado casi toda la vida se acerca a un cuarto', () {
      final p = puntosTotales(
        nivel: 2,
        hpJefe: 4313,
        danoTotal: 4312,
        resultado: Resultado.derrota,
      );
      expect(p, inInclusiveRange(1499, 1502));
    });

    test('coeficiente Y con los jefes de referencia', () {
      expect(coeficienteY(1, 2382), closeTo(1.2594, 0.0001));
      expect(coeficienteY(2, 4313), closeTo(1.3911, 0.0001));
      expect(coeficienteY(3, 4411), closeTo(2.0403, 0.0001));
      expect(coeficienteY(4, 5205), closeTo(2.8818, 0.0001));
    });

    test('rechaza nivel o HP inválidos', () {
      expect(() => coeficienteY(5, 100), throwsA(isA<ReglaIncumplida>()));
      expect(() => coeficienteY(1, 0), throwsA(isA<ReglaIncumplida>()));
    });
  });

  group('desbloqueos', () {
    test('el coste es por nivel y se compara con el acumulado', () {
      expect(jefeDesbloqueado(9999, 1), isFalse);
      expect(jefeDesbloqueado(10000, 1), isTrue);
      expect(jefeDesbloqueado(39999, 4), isFalse);
      expect(jefeDesbloqueado(40000, 4), isTrue);
    });
  });

  group('reparto', () {
    test('la tabla de porcentajes suma 100 con cada número de jugadores', () {
      repartoPorJugadores.forEach((n, tabla) {
        expect(tabla.length, n);
        expect(tabla.fold<int>(0, (a, b) => a + b), 100);
      });
    });

    test('ejemplo de D-10 con 4 jugadores (sobre el total del nivel 1)', () {
      // A 40 %, B 30 % (perdió un Pokémon), C 20 %, D 10 %: C y D, sin
      // pérdidas, ocupan los puestos intermedios y B queda último.
      var s = _victoria([958, 715, 477, 232], bajas: const [1]);
      final p = calcularPuntos(s);
      expect(p.puntosTotal, 3000);
      final porAsiento = {for (final j in p.jugadores) j.asiento: j};
      expect(porAsiento[0]!.puesto, 1);
      expect(porAsiento[2]!.puesto, 2);
      expect(porAsiento[3]!.puesto, 3);
      expect(porAsiento[1]!.puesto, 4);
      expect([for (final j in p.jugadores) j.porcentaje], [27, 25, 25, 23]);
      expect([for (final j in p.jugadores) j.puntos], [810, 750, 750, 690]);
    });

    test('con 1 jugador se lleva todo', () {
      final p = calcularPuntos(_victoria([2382]));
      expect(p.jugadores.single.puntos, 3000);
      expect(p.jugadores.single.puesto, 1);
    });

    test('con 2 jugadores, 55 y 45', () {
      final p = calcularPuntos(_victoria([1500, 882]));
      expect([for (final j in p.jugadores) j.asiento], [0, 1]);
      expect([for (final j in p.jugadores) j.puntos], [1650, 1350]);
    });

    test('con 3 jugadores, 40 / 33 / 27', () {
      final p = calcularPuntos(_victoria([300, 1500, 582]));
      expect([for (final j in p.jugadores) j.asiento], [1, 2, 0]);
      expect([for (final j in p.jugadores) j.puntos], [1200, 990, 810]);
    });

    test('el resto del redondeo va al puesto 1 y todo suma el total', () {
      // Derrota con 666 de daño para tener un total que no es múltiplo de 100.
      var d = empezar(ataques: const [100, 100, 100], hp: 2382);
      d = apply(d, const TurnoJugador(jugador: 0, dano: 333));
      d = apply(d, const TurnoJugador(jugador: 1, dano: 222));
      d = apply(d, const TurnoJugador(jugador: 2, dano: 111));
      d = aplicarTodos(d, const [
        PokemonKo(0),
        PokemonKo(0),
        PokemonKo(1),
        PokemonKo(1),
        PokemonKo(2),
        PokemonKo(2),
      ]);
      expect(d.resultado, Resultado.derrota);
      final p = calcularPuntos(d);
      expect(p.puntosTotal, 211);
      expect(p.jugadores.fold<int>(0, (a, j) => a + j.puntos), 211);
      // 40 % = 84, 33 % = 69, 27 % = 56; sobran 2 y van al puesto 1.
      expect([for (final j in p.jugadores) j.puntos], [86, 69, 56]);
    });

    test('empate de daño: menos Pokémon perdidos, luego asiento', () {
      final s = _victoria([1191, 1191], bajas: const [0]);
      final p = calcularPuntos(s);
      expect(p.jugadores.first.asiento, 1);
    });

    test('con empate total gana el asiento menor', () {
      final p = calcularPuntos(_victoria([1191, 1191]));
      expect(p.jugadores.first.asiento, 0);
    });
  });

  group('cuentas e invitados', () {
    test('el invitado ocupa su puesto pero no se le abona', () {
      final p = calcularPuntos(
        _victoria([1500, 882]),
        asientosConCuenta: {0},
      );
      expect(p.jugadores[0].puntosAbonados, 1650);
      expect(p.jugadores[1].puntos, 1350);
      expect(p.jugadores[1].puntosAbonados, 0);
    });

    test('por defecto cobran todos', () {
      final p = calcularPuntos(_victoria([1500, 882]));
      expect(p.jugadores.every((j) => j.abonado), isTrue);
    });
  });

  group('partida no terminada', () {
    test('no se calculan puntos', () {
      expect(() => calcularPuntos(empezar()),
          throwsA(isA<ReglaIncumplida>()));
    });
  });

  group('integración con una partida completa', () {
    test('derrota con daño previo y todos eliminados', () {
      var s = empezar(ataques: const [100, 100], hp: 2382);
      s = apply(s, const TurnoJugador(jugador: 0, dano: 600));
      s = apply(s, const TurnoJugador(jugador: 1, dano: 400));
      s = aplicarTodos(s, const [
        PokemonKo(0),
        PokemonKo(0),
        PokemonKo(1),
        PokemonKo(1),
      ]);
      final p = calcularPuntos(s);
      expect(p.resultado, Resultado.derrota);
      expect(p.danoTotal, 1000);
      expect(p.puntosTotal, 316);
      expect([for (final j in p.jugadores) j.puntos], [174, 142]);
      expect(p.toJson()['puntos_total'], 316);
    });
  });
}
