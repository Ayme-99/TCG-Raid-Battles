import 'dart:convert';
import 'dart:io';

import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

/// Las constantes del motor y las tablas de `balance/` son dos copias del
/// mismo dato (docs/DEPENDENCIAS.md §4). Estos tests fallan si se separan.
/// `dart test` se ejecuta en engine/, así que el resto del repo queda en `..`.

List<Map<String, String>> _csv(String nombre) {
  final lineas = File('../balance/tablas/$nombre')
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty)
      .toList();
  final cabecera = lineas.first.split(',');
  return [
    for (final l in lineas.skip(1))
      () {
        final celdas = l.split(',');
        return {
          for (var i = 0; i < cabecera.length; i++)
            cabecera[i]: i < celdas.length ? celdas[i] : '',
        };
      }(),
  ];
}

int _n(Map<String, String> fila, String columna) =>
    int.parse(fila[columna]!);

void main() {
  const pista = 'revisa docs/DEPENDENCIAS.md §4: hay que cambiar las dos copias';

  group('niveles.csv y reglas.dart', () {
    final niveles = _csv('niveles.csv');

    test('la tabla tiene los 4 niveles', () {
      expect(niveles.map((f) => _n(f, 'nivel')), [1, 2, 3, 4]);
    });

    test('x_min de cada nivel es el umbral del motor', () {
      final umbrales = {2: umbralNivel2, 3: umbralNivel3, 4: umbralNivel4};
      for (final f in niveles) {
        final nivel = _n(f, 'nivel');
        if (nivel == 1) continue; // un X menor de 250 también es Nv1
        expect(_n(f, 'x_min'), umbrales[nivel], reason: 'nivel $nivel: $pista');
        expect(nivelPorX(_n(f, 'x_min')), nivel, reason: pista);
        expect(nivelPorX(_n(f, 'x_min') - 1), nivel - 1, reason: pista);
      }
    });

    test('x_centro de cada nivel cae en su nivel', () {
      for (final f in niveles) {
        expect(nivelPorX(_n(f, 'x_centro')), _n(f, 'nivel'), reason: pista);
      }
    });

    test('el GDD cita los ataques por nivel de la tabla', () {
      final gdd = File('../incursiones_gdd.md').readAsStringSync();
      for (final f in niveles) {
        final esperado = 'Nv${f['nivel']} ${f['ataque1']}/${f['ataque2']}/${f['ataque3']}';
        expect(gdd, contains(esperado), reason: 'GDD §2: $pista');
      }
    });

    test('los ataques de cada jefe del catálogo son los de su nivel', () {
      final porNivel = {for (final f in niveles) _n(f, 'nivel'): f};
      final indice = jsonDecode(File('../catalog/catalogo.json').readAsStringSync())
          as Map<String, Object?>;
      for (final id in indice['jefes'] as List) {
        final jefe = jsonDecode(File('../catalog/bosses/$id.json').readAsStringSync())
            as Map<String, Object?>;
        final fila = porNivel[jefe['nivel']]!;
        final danos = [
          for (final a in jefe['ataques'] as List) (a as Map)['dano'],
        ];
        expect(
          danos,
          [_n(fila, 'ataque1'), _n(fila, 'ataque2'), _n(fila, 'ataque3')],
          reason: '$id: $pista',
        );
      }
    });
  });

  group('puntos_niveles.csv y puntos.dart', () {
    final filas = _csv('puntos_niveles.csv');

    test('puntos por victoria', () {
      expect({for (final f in filas) _n(f, 'nivel'): _n(f, 'puntos_victoria')},
          topeVictoriaPorNivel,
          reason: pista);
    });

    test('coste de desbloqueo', () {
      expect({for (final f in filas) _n(f, 'nivel'): _n(f, 'coste_desbloqueo')},
          costeDesbloqueoPorNivel,
          reason: pista);
    });
  });

  test('reparto_puntos.csv y repartoPorJugadores', () {
    final reparto = <int, List<int>>{};
    for (final f in _csv('reparto_puntos.csv')) {
      (reparto[_n(f, 'jugadores')] ??= []).add(_n(f, 'porcentaje'));
    }
    // El CSV lista los puestos en orden (1, 2, 3...), igual que el motor.
    expect(reparto, repartoPorJugadores, reason: pista);
    for (final p in reparto.values) {
      expect(p.reduce((a, b) => a + b), 100);
    }
  });
}
