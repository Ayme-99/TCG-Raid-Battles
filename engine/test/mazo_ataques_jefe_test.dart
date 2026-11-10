import 'dart:math';

import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Cartas de ataque del jefe (PDF oficial)', () {
    test('son 20, numeradas del 1 al 20', () {
      expect(cartasAtaqueJefe.map((c) => c.numero), [for (var i = 1; i <= 20; i++) i]);
    });

    test('ataque y objetivo de cada carta', () {
      final ataque = cartasAtaqueJefe.map((c) => c.ranura).toList();
      expect(ataque, [...List.filled(8, 1), ...List.filled(8, 2), ...List.filled(4, 3)]);
      final jugador = cartasAtaqueJefe.map((c) => c.jugador).toList();
      expect(jugador, [for (var i = 0; i < 20; i++) i % 4]);
    });

    test('piden robar otra las cartas 1 a 12 y la 20', () {
      final roban = [
        for (final c in cartasAtaqueJefe)
          if (c.robaOtra) c.numero,
      ];
      expect(roban, [...List.generate(12, (i) => i + 1), 20]);
    });

    test('máximo de ataques por turno según el nivel', () {
      expect([1, 2, 3, 4].map(maxAtaquesJefePorTurno), [2, 3, 4, 4]);
    });
  });

  group('MazoAtaquesJefe', () {
    test('roba las 20 cartas sin repetir antes de rebarajar', () {
      final mazo = MazoAtaquesJefe(Random(1));
      final robadas = [for (var i = 0; i < 20; i++) mazo.robar({0, 1, 2, 3})];
      expect(robadas.map((c) => c.numero).toSet().length, 20);
      expect(mazo.restantes, 0);
      // El siguiente roba del descarte rebarajado.
      expect(mazo.robar({0, 1, 2, 3}), isNotNull);
      expect(mazo.restantes, 19);
    });

    test('descarta las cartas de jugadores que no juegan o están eliminados', () {
      final mazo = MazoAtaquesJefe(Random(7));
      for (var i = 0; i < 200; i++) {
        expect({0, 2}, contains(mazo.robar({0, 2}).jugador));
      }
    });

    test('con un solo jugador activo siempre le ataca a él', () {
      final mazo = MazoAtaquesJefe(Random(3));
      for (var i = 0; i < 100; i++) {
        expect(mazo.robar({1}).jugador, 1);
      }
    });

    test('sin jugadores activos falla en vez de bloquearse', () {
      expect(() => MazoAtaquesJefe(Random(1)).robar({}), throwsStateError);
    });

    test('la misma semilla da el mismo orden', () {
      final a = MazoAtaquesJefe(Random(5));
      final b = MazoAtaquesJefe(Random(5));
      for (var i = 0; i < 20; i++) {
        expect(a.robar({0, 1, 2, 3}).numero, b.robar({0, 1, 2, 3}).numero);
      }
    });
  });
}
