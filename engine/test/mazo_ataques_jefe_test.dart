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
      expect([1, 2, 3, 4].map(maxAtaquesJefePorTurno), [2, 3, 4, 5]);
    });
  });

  group('Cartas según los jugadores', () {
    List<int> objetivos(int n) =>
        cartasAtaqueJefePara(n).map((c) => c.jugador).toList();

    test('4 jugadores: las 20 oficiales', () {
      expect(cartasAtaqueJefePara(4).map((c) => c.numero),
          cartasAtaqueJefe.map((c) => c.numero));
      expect(objetivos(4), [for (var i = 0; i < 20; i++) i % 4]);
    });

    test('3 jugadores: desaparecen las 5 del Jugador 4', () {
      final cartas = cartasAtaqueJefePara(3);
      expect(cartas.length, 15);
      expect(cartas.map((c) => c.jugador).toSet(), {0, 1, 2});
      expect(
        cartas.map((c) => c.numero).toSet().intersection({4, 8, 12, 16, 20}),
        isEmpty,
      );
    });

    test('2 jugadores: 20 cartas; las del 3 van al 1 y las del 4 al 2', () {
      final cartas = cartasAtaqueJefePara(2);
      expect(cartas.length, 20);
      expect(objetivos(2), [for (var i = 0; i < 20; i++) i % 2]);
      // La carta 20 (ataque 3, Jugador 4) pasa a ser contra el Jugador 2 y
      // sigue pidiendo robar otra.
      final c20 = cartas.last;
      expect((c20.ranura, c20.jugador, c20.robaOtra), (3, 1, true));
    });

    test('1 jugador: las 20 cartas, todas contra él', () {
      expect(objetivos(1), List.filled(20, 0));
    });

    test('el ataque y el robar otra no cambian con los jugadores', () {
      for (final n in [1, 2, 3, 4]) {
        for (final c in cartasAtaqueJefePara(n)) {
          final original = cartasAtaqueJefe[c.numero - 1];
          expect((c.ranura, c.robaOtra), (original.ranura, original.robaOtra));
        }
      }
    });

    test('número de jugadores fuera de rango', () {
      expect(() => cartasAtaqueJefePara(0), throwsArgumentError);
      expect(() => cartasAtaqueJefePara(5), throwsArgumentError);
    });

    test('el mazo de 3 jugadores tiene 15 cartas y de 2, 20', () {
      final tres = MazoAtaquesJefe(Random(1), jugadores: 3);
      for (var i = 0; i < 15; i++) {
        tres.robar({0, 1, 2});
      }
      expect(tres.restantes, 0);
      final dos = MazoAtaquesJefe(Random(1), jugadores: 2);
      for (var i = 0; i < 20; i++) {
        dos.robar({0, 1});
      }
      expect(dos.restantes, 0);
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
      // Con 3 jugadores no hay cartas contra el asiento 4.
      expect(
        () => MazoAtaquesJefe(Random(1), jugadores: 3).robar({3}),
        throwsStateError,
      );
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
