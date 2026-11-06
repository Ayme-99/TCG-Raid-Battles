import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

/// D-12: veneno y quemadura del jefe, chequeo al cerrar la ronda y bono.
void main() {
  EstadoPartida aplicar(EstadoPartida s, int jugador, EstadoDelJefe estado) =>
      apply(s, AplicarEstadoJefe(jugador: jugador, estado: estado));

  // Un jugador, jefe de [hp], ya en el turno del jefe tras hacer [dano].
  EstadoPartida enTurnoDelJefe({int hp = 1000, int dano = 100}) {
    final s = empezar(ataques: [100], hp: hp);
    return apply(s, TurnoJugador(jugador: 0, dano: dano));
  }

  group('aplicar estados', () {
    test('el veneno y la quemadura se quedan en el jefe y cuentan', () {
      var s = empezar();
      s = aplicar(s, 0, EstadoDelJefe.veneno);
      s = aplicar(s, 1, EstadoDelJefe.quemadura);
      expect(s.jefe!.envenenado, isTrue);
      expect(s.jefe!.quemado, isTrue);
      expect(s.estadosAplicados, [1, 1, 0]);
    });

    test('aplicar un estado que el jefe ya tiene no cambia nada', () {
      var s = aplicar(empezar(), 0, EstadoDelJefe.veneno);
      final igual = aplicar(s, 1, EstadoDelJefe.veneno);
      expect(igual.toJson(), equals(s.toJson()));
    });

    test('es válido también en el turno del jefe', () {
      final s = aplicar(enTurnoDelJefe(), 0, EstadoDelJefe.quemadura);
      expect(s.jefe!.quemado, isTrue);
    });

    test('no se puede antes de empezar, tras el final ni con un eliminado', () {
      expect(
        () => aplicar(configurar([100]), 0, EstadoDelJefe.veneno),
        throwsA(isA<ReglaIncumplida>()),
      );
      var s = empezar(ataques: [100, 100]);
      s = apply(s, const PokemonKo(1));
      s = apply(s, const PokemonKo(1));
      expect(
        () => aplicar(s, 1, EstadoDelJefe.veneno),
        throwsA(isA<ReglaIncumplida>()),
      );
      final fin = apply(s, const Abandonar());
      expect(
        () => aplicar(fin, 0, EstadoDelJefe.veneno),
        throwsA(isA<ReglaIncumplida>()),
      );
    });

    test('curar al jefe no le quita los estados', () {
      var s = aplicar(enTurnoDelJefe(), 0, EstadoDelJefe.veneno);
      s = apply(s, const CuracionJefe(500));
      expect(s.jefe!.envenenado, isTrue);
    });
  });

  group('chequeo al cerrar la ronda', () {
    test('el veneno hace 10 y no se atribuye a ningún jugador', () {
      var s = aplicar(enTurnoDelJefe(), 0, EstadoDelJefe.veneno);
      s = apply(s, const FinTurnoJefe());
      expect(s.jefe!.hp, 1000 - 100 - danoVeneno);
      expect(s.danoPorJugador, [100, 0, 0].sublist(0, 1));
      expect(s.fase, Fase.turnoJugadores);
      expect(s.jefe!.envenenado, isTrue); // permanente
    });

    test('el veneno se repite cada ronda', () {
      var s = aplicar(enTurnoDelJefe(), 0, EstadoDelJefe.veneno);
      s = apply(s, const FinTurnoJefe());
      s = apply(s, const TurnoJugador(jugador: 0, dano: 0));
      s = apply(s, const FinTurnoJefe());
      expect(s.jefe!.hp, 1000 - 100 - 2 * danoVeneno);
    });

    test('la quemadura hace 20 y la moneda en cruz la mantiene', () {
      var s = aplicar(enTurnoDelJefe(), 0, EstadoDelJefe.quemadura);
      s = apply(s, const FinTurnoJefe(monedaQuemadura: false));
      expect(s.jefe!.hp, 1000 - 100 - danoQuemadura);
      expect(s.jefe!.quemado, isTrue);
    });

    test('la moneda en cara quita la quemadura después de su daño', () {
      var s = aplicar(enTurnoDelJefe(), 0, EstadoDelJefe.quemadura);
      s = apply(s, const FinTurnoJefe(monedaQuemadura: true));
      expect(s.jefe!.hp, 1000 - 100 - danoQuemadura);
      expect(s.jefe!.quemado, isFalse);
      // Y no hace daño la ronda siguiente.
      s = apply(s, const TurnoJugador(jugador: 0, dano: 0));
      s = apply(s, const FinTurnoJefe());
      expect(s.jefe!.hp, 1000 - 100 - danoQuemadura);
    });

    test('una quemadura quitada puede volver a ponerse y vuelve a contar', () {
      var s = aplicar(enTurnoDelJefe(), 0, EstadoDelJefe.quemadura);
      s = apply(s, const FinTurnoJefe(monedaQuemadura: true));
      s = apply(s, const TurnoJugador(jugador: 0, dano: 0));
      s = aplicar(s, 0, EstadoDelJefe.quemadura);
      expect(s.estadosAplicados[0], 2);
    });

    test('veneno y quemadura juntos suman 30', () {
      var s = enTurnoDelJefe();
      s = aplicar(s, 0, EstadoDelJefe.veneno);
      s = aplicar(s, 0, EstadoDelJefe.quemadura);
      s = apply(s, const FinTurnoJefe(monedaQuemadura: false));
      expect(s.jefe!.hp, 1000 - 100 - danoVeneno - danoQuemadura);
    });

    test('el jefe quemado exige la moneda; sin quemadura no se admite', () {
      final quemado = aplicar(enTurnoDelJefe(), 0, EstadoDelJefe.quemadura);
      expect(() => apply(quemado, const FinTurnoJefe()),
          throwsA(isA<ReglaIncumplida>()));
      expect(() => apply(enTurnoDelJefe(), const FinTurnoJefe(monedaQuemadura: true)),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('si el chequeo deja al jefe a 0 HP, victoria', () {
      var s = aplicar(enTurnoDelJefe(hp: 115), 0, EstadoDelJefe.veneno);
      s = apply(s, const FinTurnoJefe());
      expect(s.jefe!.hp, 5);
      s = apply(s, const TurnoJugador(jugador: 0, dano: 0));
      s = apply(s, const FinTurnoJefe());
      expect(s.jefe!.hp, 0);
      expect(s.fase, Fase.terminada);
      expect(s.resultado, Resultado.victoria);
    });

    test('el daño del chequeo se topa en el HP que le queda al jefe', () {
      var s = enTurnoDelJefe(hp: 105);
      s = aplicar(s, 0, EstadoDelJefe.veneno);
      s = aplicar(s, 0, EstadoDelJefe.quemadura);
      s = apply(s, const FinTurnoJefe(monedaQuemadura: false));
      expect(s.jefe!.hp, 0);
      expect(s.resultado, Resultado.victoria);
    });

    test('el chequeo puede cruzar un umbral de invocación', () {
      var s = apply(configurar([100]), ElegirJefe(
        nombre: 'Jefe', nivel: 1, hp: 1000, invocacionCadaHp: 95,
      ));
      s = apply(s, const TurnoJugador(jugador: 0, dano: 90));
      s = aplicar(s, 0, EstadoDelJefe.veneno);
      expect(s.intentosInvocacionPendientes, 0);
      s = apply(s, const FinTurnoJefe()); // 90 + 10 = 100 perdidos
      expect(s.intentosInvocacionPendientes, 1);
      expect(() => apply(s, const TurnoJugador(jugador: 0, dano: 1)),
          throwsA(isA<ReglaIncumplida>()));
      s = apply(s, const SinInvocacion());
      expect(() => apply(s, const TurnoJugador(jugador: 0, dano: 1)),
          returnsNormally);
    });
  });

  group('bono de estados en los puntos', () {
    test('victoria: tope ÷ 100 × min(n, 3)', () {
      int b(int nivel, int n) => bonoEstados(
          nivel: nivel, aplicaciones: n, resultado: Resultado.victoria);
      expect([for (final n in [0, 1, 2, 3, 4, 9]) b(1, n)], [0, 30, 60, 90, 90, 90]);
      expect([for (final n in [1, 2, 3]) b(2, n)], [60, 120, 180]);
      expect([for (final n in [1, 2, 3]) b(3, n)], [90, 180, 270]);
      expect([for (final n in [1, 2, 3]) b(4, n)], [150, 300, 450]);
    });

    test('derrota: una cuarta parte, mitades hacia arriba', () {
      int b(int nivel, int n) => bonoEstados(
          nivel: nivel, aplicaciones: n, resultado: Resultado.derrota);
      expect([for (final n in [1, 2, 3]) b(1, n)], [8, 15, 23]);
      expect([for (final n in [1, 2, 3]) b(2, n)], [15, 30, 45]);
      expect([for (final n in [1, 2, 3]) b(3, n)], [23, 45, 68]);
      expect([for (final n in [1, 2, 3]) b(4, n)], [38, 75, 113]);
    });

    test('se suma al reparto sin tocar el total ni los puestos', () {
      var s = empezar(ataques: [100, 100], hp: 200);
      s = apply(s, const TurnoJugador(jugador: 0, dano: 60));
      s = aplicar(s, 0, EstadoDelJefe.veneno);
      s = apply(s, const TurnoJugador(jugador: 1, dano: 40));
      s = aplicar(s, 1, EstadoDelJefe.quemadura);
      s = apply(s, const FinTurnoJefe(monedaQuemadura: false)); // 30 de chequeo
      s = apply(s, const TurnoJugador(jugador: 0, dano: 70));
      s = apply(s, const TurnoJugador(jugador: 1, dano: 0));
      s = apply(s, const FinTurnoJefe(monedaQuemadura: false));
      expect(s.resultado, Resultado.victoria);
      final p = calcularPuntos(s);
      expect(p.puntosTotal, 3000);
      expect(p.jugadores.map((j) => j.asiento), [0, 1]);
      expect(p.jugadores.map((j) => j.puntos), [1650, 1350]);
      expect(p.jugadores.map((j) => j.bonoEstados), [30, 30]);
      expect(p.jugadores.map((j) => j.puntosAbonados), [1680, 1380]);
    });

    test('un invitado no cobra el bono', () {
      var s = empezar(ataques: [100, 100], hp: 40);
      s = aplicar(s, 1, EstadoDelJefe.veneno);
      s = apply(s, const TurnoJugador(jugador: 0, dano: 40));
      final p = calcularPuntos(s, asientosConCuenta: {0});
      final invitado = p.jugadores.firstWhere((j) => j.asiento == 1);
      expect(invitado.bonoEstados, 30);
      expect(invitado.puntosAbonados, 0);
    });
  });
}
