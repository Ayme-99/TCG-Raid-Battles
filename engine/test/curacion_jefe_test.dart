import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

void main() {
  group('curación del jefe', () {
    test('sube la vida sin pasar del máximo', () {
      var s = empezar(hp: 1000);
      s = apply(s, const TurnoJugador(jugador: 0, dano: 300));
      s = apply(s, const CuracionJefe(100));
      expect(s.jefe!.hp, 800);
      expect(s.curacionJefe, 100);
      s = apply(s, const CuracionJefe(5000));
      expect(s.jefe!.hp, 1000);
      expect(s.curacionJefe, 300);
    });

    test('curar a vida completa registra 0', () {
      final s = apply(empezar(), const CuracionJefe(50));
      expect(s.jefe!.hp, 1000);
      expect(s.curacionJefe, 0);
    });

    test('se puede curar en el turno del jefe y sin límite de veces', () {
      var s = todosActuan(empezar(), dano: 100);
      for (var i = 0; i < 20; i++) {
        s = apply(s, const CuracionJefe(10));
      }
      expect(s.jefe!.hp, 1000 - 300 + 200);
      expect(s.curacionJefe, 200);
    });

    test('cantidad negativa o fuera de fase se rechaza', () {
      expect(() => apply(empezar(), const CuracionJefe(-1)),
          throwsA(isA<ReglaIncumplida>()));
      expect(() => apply(configurar([100]), const CuracionJefe(10)),
          throwsA(isA<ReglaIncumplida>()));
      final fin = apply(empezar(), const Abandonar());
      expect(() => apply(fin, const CuracionJefe(10)),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('al curarse no se pierde el daño ya contado por jugador', () {
      var s = empezar(hp: 1000);
      s = apply(s, const TurnoJugador(jugador: 0, dano: 400));
      s = apply(s, const CuracionJefe(400));
      expect(s.danoPorJugador, [400, 0, 0]);
      s = apply(s, const TurnoJugador(jugador: 1, dano: 400));
      expect(s.danoPorJugador, [400, 400, 0]);
    });
  });

  group('puntos de derrota con curación', () {
    test('usa la vida perdida (neto), no el daño bruto', () {
      var s = empezar(ataques: const [100, 100], hp: 2382);
      s = apply(s, const TurnoJugador(jugador: 0, dano: 1000));
      s = apply(s, const CuracionJefe(600));
      s = apply(s, const TurnoJugador(jugador: 1, dano: 500));
      s = apply(s, const Abandonar());
      final p = calcularPuntos(s);
      // Daño bruto 1500, curación 600: el jefe perdió 900 de vida.
      expect(p.danoTotal, 900);
      // (900 × 3000 + 2 × 2382) ÷ (4 × 2382) = 283 → 283, y 284 con el +1.
      expect(p.puntosTotal, 284);
      // El reparto ordena por daño bruto de cada jugador.
      expect(p.jugadores.first.asiento, 0);
      expect(p.jugadores.first.dano, 1000);
    });

    test('con el jefe curado del todo, la derrota da 1 punto', () {
      var s = empezar(ataques: const [100], hp: 2382);
      s = apply(s, const TurnoJugador(jugador: 0, dano: 500));
      s = apply(s, const CuracionJefe(500));
      s = apply(s, const Abandonar());
      expect(calcularPuntos(s).puntosTotal, 1);
    });

    test('una victoria sigue dando el tope aunque el jefe se haya curado', () {
      var s = empezar(ataques: const [100], hp: 2382);
      s = apply(s, const TurnoJugador(jugador: 0, dano: 1000));
      s = apply(s, const CuracionJefe(1000));
      s = apply(s, const FinTurnoJefe());
      s = apply(s, const TurnoJugador(jugador: 0, dano: 2382));
      expect(s.resultado, Resultado.victoria);
      expect(calcularPuntos(s).puntosTotal, 3000);
    });
  });
}
