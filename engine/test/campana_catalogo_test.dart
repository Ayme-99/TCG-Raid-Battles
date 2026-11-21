import 'dart:convert';
import 'dart:io';

import 'package:incursiones_engine/campana.dart';
import 'package:test/test.dart';

/// Los Pokémon y las zonas de campaña (`catalog/campana/`) son datos: este
/// test comprueba que se leen, que son coherentes y que se puede jugar con
/// ellos.
Map<String, dynamic> leer(File f) =>
    jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;

void main() {
  final carpetaPokemon = Directory('../catalog/campana/pokemon');
  final carpetaZonas = Directory('../catalog/campana/zonas');
  final archivos = carpetaPokemon
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final pokemon = <String, PokemonCampana>{};
  final numeros = <String, int>{};
  for (final f in archivos) {
    final json = leer(f);
    final p = pokemonCampanaDesdeJson(json);
    pokemon[p.id] = p;
    numeros[p.id] = json['numero'] as int;
  }

  group('Pokémon', () {
    test('hay Pokémon en el catálogo', () {
      expect(pokemon, isNotEmpty);
    });

    test('el id coincide con el nombre del archivo y el número no se repite', () {
      for (final f in archivos) {
        final id = f.uri.pathSegments.last.replaceAll('.json', '');
        expect(pokemon.containsKey(id), isTrue, reason: f.path);
      }
      expect(numeros.values.toSet().length, numeros.length);
      for (final n in numeros.values) {
        expect(n, inInclusiveRange(1, 151));
      }
    });

    test('PS, ataques y costes dentro de lo previsto', () {
      for (final p in pokemon.values) {
        expect(p.ps, greaterThan(0), reason: p.id);
        expect(p.ps % 10, 0, reason: '${p.id}: PS en decenas');
        expect(p.ataques, isNotEmpty, reason: p.id);
        expect(p.ataques.length, lessThanOrEqualTo(2), reason: p.id);
        expect(p.ps, inInclusiveRange(30, 340), reason: '${p.id}: PS de la escala real');
        for (final a in p.ataques) {
          expect(a.coste, inInclusiveRange(1, 4), reason: '${p.id}/${a.nombre}');
          expect(a.dano, greaterThan(0), reason: '${p.id}/${a.nombre}');
          expect(a.dano % 10, 0,
              reason: '${p.id}/${a.nombre}: daño en múltiplos de 10');
        }
      }
    });

    test('Onix lleva debilidad, resistencia y retirada con coste', () {
      final onix = pokemon['onix']!;
      expect(onix.tipo, TipoCampana.roca);
      expect(onix.debilidad!.tipo, TipoCampana.agua);
      expect(onix.debilidad!.multiplicador, 2);
      expect(onix.resistencia!.tipo, TipoCampana.normal);
      expect(onix.resistencia!.reduccion, 30);
      expect(onix.retirada, 1);
    });

    test('un tipo desconocido se rechaza', () {
      expect(() => tipoCampanaDeTexto('acero'), throwsFormatException);
    });
  });

  group('evolución y cartas ex', () {
    Map<String, dynamic> base(List<Map<String, dynamic>> evoluciones,
            {bool ex = false}) =>
        {
          'id': 'prueba',
          'nombre': 'Prueba',
          'tipo': 'normal',
          'ps': 60,
          'ex': ex,
          'evoluciones': evoluciones,
          'ataques': [
            {'nombre': 'Placaje', 'tipo': 'normal', 'coste': 1, 'dano': 10},
          ],
        };

    test('un Pokémon sin evoluciones ni ex es lo habitual', () {
      final p = pokemonCampanaDesdeJson(base([]));
      expect(p.evoluciones, isEmpty);
      expect(p.ex, isFalse);
    });

    test('se leen las cuatro vías de evolución', () {
      final p = pokemonCampanaDesdeJson(base([
        {'a': 'a', 'via': 'xp', 'xp': 30},
        {'a': 'b', 'via': 'objeto', 'objeto': 'piedra-trueno'},
        {'a': 'c', 'via': 'intercambio', 'puntos': 200},
        {'a': 'd', 'via': 'puntos', 'puntos': 300},
      ], ex: true));
      expect(p.ex, isTrue);
      expect(p.evoluciones.map((e) => e.via), ViaEvolucion.values);
      expect(p.evoluciones[0].xp, 30);
      expect(p.evoluciones[1].objeto, 'piedra-trueno');
      expect(p.evoluciones[2].puntos, 200);
      expect(p.evoluciones[3].puntos, 300);
    });

    test('una evolución a medias o con una vía desconocida se rechaza', () {
      expect(() => pokemonCampanaDesdeJson(base([{'a': 'a', 'via': 'xp'}])),
          throwsFormatException);
      expect(
          () => pokemonCampanaDesdeJson(base([{'a': 'a', 'via': 'objeto'}])),
          throwsFormatException);
      expect(
          () => pokemonCampanaDesdeJson(
              base([{'a': 'a', 'via': 'intercambio'}])),
          throwsFormatException);
      expect(() => pokemonCampanaDesdeJson(base([{'a': 'a', 'via': 'magia'}])),
          throwsFormatException);
    });

    test('toda evolución del catálogo apunta a un Pokémon que existe', () {
      for (final p in pokemon.values) {
        for (final e in p.evoluciones) {
          expect(pokemon.containsKey(e.a), isTrue, reason: '${p.id} → ${e.a}');
        }
      }
    });
  });

  group('zonas', () {
    final zonas = carpetaZonas
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .map((f) => zonaCampanaDesdeJson(leer(f)))
        .toList();

    test('toda zona usa solo Pokémon que existen en el catálogo', () {
      expect(zonas, isNotEmpty);
      for (final z in zonas) {
        for (final id in z.todosLosPokemon) {
          expect(pokemon.containsKey(id), isTrue, reason: '${z.id} → $id');
        }
      }
    });

    test('el Túnel Roca: Zubat, Geodude, Machop y Onix salvajes', () {
      final z = zonas.firstWhere((z) => z.id == 'tunel-roca');
      expect(z.region, 'kanto');
      expect(z.salvajes, ['zubat', 'geodude', 'machop', 'onix']);
      expect(z.entrenadores.single.clase, 'PokéManiaco');
      expect(z.entrenadores.single.pokemon, ['cubone', 'slowpoke']);
      expect(z.jefe, 'onix');
    });
  });

  group('jugar con los datos', () {
    test('todos contra todos terminan con la IA y respetan las reglas', () {
      for (final a in pokemon.values) {
        for (final b in pokemon.values) {
          var e = EstadoCombate.inicial(equipoJugador: [a], equipoRival: [b]);
          for (var i = 0; i < 1000 && e.fase != FaseCombate.terminado; i++) {
            e = aplicarCombate(e, decidirAccion(e, e.turno));
          }
          expect(e.fase, FaseCombate.terminado, reason: '${a.id} vs ${b.id}');
          expect(e.ganador, isNotNull);
        }
      }
    });
  });
}
