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
          expect(a.dano > 0 || a.efecto != null, isTrue,
              reason: '${p.id}/${a.nombre}: sin daño solo con efecto');
          expect(a.dano % 10, 0,
              reason: '${p.id}/${a.nombre}: daño en múltiplos de 10');
        }
      }
    });

    test('ninguna carta queda anulada por Grunido: un ataque de 20 o mas '
        'o con veneno', () {
      for (final p in pokemon.values) {
        final valido = p.ataques
            .any((a) => a.dano >= 20 || a.efecto is EnvenenaDefensor);
        expect(valido, isTrue,
            reason: '${p.id}: ningún ataque de 20+ ni con veneno');
      }
    });

    test('Bulbasaur: Gruñido reduce 10 el daño del rival y no hace daño', () {
      final b = pokemon['bulbasaur']!;
      expect(b.ps, 90);
      expect(b.debilidad!.tipo, TipoCampana.fuego);
      expect(b.resistencia, isNull);
      final grunido = b.ataques.first;
      expect(grunido.dano, 0);
      expect(grunido.coste, 1);
      expect(grunido.efecto, isA<ReduceDanoRival>()
          .having((e) => e.valor, 'valor', 10));
    });

    test('Metapod: Fortaleza protege 10 y Placaje hace 20', () {
      final m = pokemon['metapod']!;
      expect(m.ps, 80);
      final f = m.ataques.first;
      expect(f.dano, 0);
      expect(f.coste, 1);
      expect(f.efecto, isA<ReduceDanoPropio>()
          .having((e) => e.valor, 'valor', 10));
      expect(m.ataques.last.dano, 20);
      expect(m.ataques.last.coste, 1);
    });

    test('Pikachu (025/150): Látigo y Impactrueno, 60 PS', () {
      final p = pokemon['pikachu']!;
      expect(p.ps, 60);
      expect(p.tipo, TipoCampana.electrico);
      expect(p.debilidad!.tipo, TipoCampana.lucha);
      expect(p.ataques.first.efecto, isA<AumentaDanoRecibido>());
      expect(p.ataques.last.dano, 30);
      expect(p.ataques.last.coste, 2);
    });

    test('Diglett (050/150): 50 PS, lucha y Bofetón Lodo con moneda de fallo', () {
      final d = pokemon['diglett']!;
      expect(d.ps, 50);
      expect(d.tipo, TipoCampana.lucha);
      expect(d.debilidad!.tipo, TipoCampana.planta);
      expect(d.ataques.first.dano, 10);
      expect(d.ataques.last.dano, 30);
      expect(d.ataques.last.efecto, isA<MonedaFalloRival>());
    });

    test('Sandshrew (027/150): Rizo Defensa y Rodar por racha', () {
      final s = pokemon['sandshrew']!;
      expect(s.ps, 70);
      expect(s.tipo, TipoCampana.lucha);
      expect(s.debilidad!.tipo, TipoCampana.planta);
      expect(s.ataques.first.efecto, isA<ReduceDanoPropio>());
      expect(s.ataques.last.dano, 20);
      expect(s.ataques.last.efecto, isA<DanoPorRacha>());
    });

    test('Spearow (021/150): resiste lucha y Ataque Furia lanza 3 monedas', () {
      final s = pokemon['spearow']!;
      expect(s.ps, 60);
      expect(s.tipo, TipoCampana.normal);
      expect(s.debilidad!.tipo, TipoCampana.electrico);
      expect(s.resistencia!.tipo, TipoCampana.lucha);
      final furia = s.ataques.last.efecto as MonedasDano;
      expect(furia.monedas, 3);
      expect(furia.danoPorCaras, [50, 20, 30, 40]);
      // Toda tirada hace 20 o más, así que cumple la regla del ataque de 20.
      expect(furia.danoPorCaras.every((d) => d >= 20), isTrue);
    });

    test('Nidoran♀ (029/150): oscuridad, Golpes Furia y Doble Patada', () {
      final n = pokemon['nidoran-f']!;
      expect(n.ps, 60);
      expect(n.tipo, TipoCampana.oscuridad);
      expect(n.debilidad!.tipo, TipoCampana.lucha);
      expect(n.ataques.first.efecto, isA<MonedasDano>());
      expect(n.ataques.last.coste, 3);
      expect(n.ataques.last.dano, 30);
      expect(n.ataques.last.efecto, isA<RepiteDanoAlDerribar>());
    });

    test('Nidoran♂ (032/150): oscuridad, Picotazo veneno y Ataque Furia', () {
      final n = pokemon['nidoran-m']!;
      expect(n.ps, 60);
      expect(n.tipo, TipoCampana.oscuridad);
      expect(n.ataques.first.coste, 1);
      expect(n.ataques.first.dano, 10);
      expect(n.ataques.first.efecto, isA<EnvenenaDefensor>());
      expect(n.ataques.last.efecto, isA<MonedasDano>());
    });

    test('Mankey (056/150): lucha, Foco Energía y Golpe Kárate', () {
      final m = pokemon['mankey']!;
      expect(m.ps, 70);
      expect(m.tipo, TipoCampana.lucha);
      expect(m.debilidad!.tipo, TipoCampana.psiquico);
      expect(m.retirada, 0);
      final h = m.habilidad as MonedaDanoExtraAlAtacar;
      expect(h.nombre, 'Foco Energía');
      expect(h.valor, 20);
      expect(m.ataques.single.coste, 2);
      expect(m.ataques.single.dano, 30);
      expect(m.ataques.single.efecto, isA<MonedaDanoExtra>());
    });

    test('Kakuna: Fortaleza y Picotazo Veneno', () {
      final k = pokemon['kakuna']!;
      expect(k.ps, 70);
      expect(k.ataques.first.efecto, isA<ReduceDanoPropio>());
      expect(k.ataques.last.dano, 10);
      expect(k.ataques.last.efecto, isA<EnvenenaDefensor>());
    });

    test('Weedle: Picotazo Veneno hace 10 y envenena', () {
      final w = pokemon['weedle']!;
      expect(w.ps, 50);
      expect(w.ataques, hasLength(1));
      final a = w.ataques.single;
      expect(a.coste, 2);
      expect(a.dano, 10);
      expect(a.efecto, isA<EnvenenaDefensor>()
          .having((e) => e.valor, 'valor', 10));
    });

    test('Rattata: Hiper Colmillo hace 20 y 20 más si sale cara', () {
      final r = pokemon['rattata']!;
      expect(r.ps, 60);
      expect(r.debilidad!.tipo, TipoCampana.lucha);
      final colmillo = r.ataques.last;
      expect(colmillo.dano, 20);
      expect(colmillo.efecto, isA<MonedaDanoExtra>()
          .having((e) => e.valor, 'valor', 20));
    });

    test('Caterpie: Disparo Demora quita 1 de energía y no hace daño', () {
      final c = pokemon['caterpie']!;
      expect(c.ps, 50);
      expect(c.debilidad!.tipo, TipoCampana.fuego);
      expect(c.resistencia, isNull);
      final demora = c.ataques.first;
      expect(demora.dano, 0);
      expect(demora.coste, 1);
      expect(demora.efecto, isA<QuitaEnergiaRival>()
          .having((e) => e.valor, 'valor', 1));
      expect(c.ataques.last.dano, 20);
    });

    test('Geodude: carta impresa con Pulimento (gana 2 de energía) y Lanzarrocas', () {
      final g = pokemon['geodude']!;
      expect(g.tipo, TipoCampana.lucha);
      expect(g.ps, 80);
      expect(g.debilidad!.tipo, TipoCampana.agua);
      expect(g.debilidad!.multiplicador, 2);
      expect(g.resistencia, isNull);
      expect(g.retirada, 1);
      final pulimento = g.ataques.first;
      expect(pulimento.nombre, 'Pulimento');
      expect(pulimento.tipo, TipoCampana.normal);
      expect(pulimento.coste, 1);
      expect(pulimento.dano, 0);
      expect(pulimento.efecto, isA<GanaEnergia>()
          .having((e) => e.valor, 'valor', 2));
      final lanzarrocas = g.ataques.last;
      expect(lanzarrocas.nombre, 'Lanzarrocas');
      expect(lanzarrocas.tipo, TipoCampana.lucha);
      expect(lanzarrocas.coste, 3);
      expect(lanzarrocas.dano, 50);
    });

    test('Squirtle: Látigo hace que el rival reciba 10 más y no hace daño', () {
      final s = pokemon['squirtle']!;
      expect(s.ps, 80);
      expect(s.tipo, TipoCampana.agua);
      expect(s.debilidad!.tipo, TipoCampana.electrico);
      expect(s.resistencia, isNull);
      final latigo = s.ataques.first;
      expect(latigo.dano, 0);
      expect(latigo.coste, 1);
      expect(latigo.efecto,
          isA<AumentaDanoRecibido>().having((e) => e.valor, 'valor', 10));
    });

    test('Onix lleva debilidad y retirada con coste, sin resistencia', () {
      final onix = pokemon['onix']!;
      expect(onix.tipo, TipoCampana.lucha);
      expect(onix.debilidad!.tipo, TipoCampana.agua);
      expect(onix.debilidad!.multiplicador, 2);
      expect(onix.resistencia, isNull);
      expect(onix.retirada, 1);
    });

    test('un tipo desconocido se rechaza', () {
      expect(() => tipoCampanaDeTexto('acero'), throwsFormatException);
    });

    test('los tipos son los del TCG (D-20 §10.3)', () {
      expect(TipoCampana.values.map((t) => t.name), [
        'normal', 'fuego', 'agua', 'planta', 'electrico', 'lucha', //
        'psiquico', 'oscuridad', 'dragon', 'metal',
      ]);
      expect(tipoCampanaDeTexto('metal'), TipoCampana.metal);
      for (final fuera in ['hielo', 'veneno', 'volador', 'bicho', 'fantasma']) {
        expect(() => tipoCampanaDeTexto(fuera), throwsFormatException,
            reason: fuera);
      }
    });

    test('el esquema lista los mismos tipos que el motor', () {
      final esquema =
          leer(File('../catalog/schema/pokemon-campana.schema.json'));
      final enumEsquema =
          (esquema[r'$defs'] as Map)['tipo']['enum'] as List<dynamic>;
      expect(enumEsquema, TipoCampana.values.map((t) => t.name).toList());
    });

    test('Slowpoke sigue a su carta impresa (079/150)', () {
      final s = pokemon['slowpoke']!;
      expect(s.tipo, TipoCampana.agua);
      expect(s.ps, 80);
      expect(s.debilidad?.tipo, TipoCampana.electrico);
      expect(s.debilidad?.multiplicador, 2);
      expect(s.resistencia, isNull);
      expect(s.retirada, 1);
      expect(s.ataques.map((a) => a.nombre), ['Pistola Agua', 'Hidropulso']);
      final pistola = s.ataques.first;
      expect(pistola.tipo, TipoCampana.agua);
      expect(pistola.coste, 2);
      expect(pistola.dano, 20);
      final hidro = s.ataques.last;
      expect(hidro.tipo, TipoCampana.agua);
      expect(hidro.coste, 3);
      expect(hidro.dano, 40);
      expect((hidro.efecto as ConfundeDefensor).monedas, 2);
    });

    test('confundeDefensor: monedas es 1 por defecto y no puede ser 0', () {
      Map<String, dynamic> carta(Map<String, dynamic> efecto) => {
            'id': 'prueba',
            'nombre': 'Prueba',
            'tipo': 'normal',
            'ps': 60,
            'retirada': 0,
            'ataques': [
              {
                'nombre': 'A',
                'tipo': 'normal',
                'coste': 1,
                'dano': 0,
                'efecto': efecto
              },
              {'nombre': 'B', 'tipo': 'normal', 'coste': 2, 'dano': 30},
            ],
          };
      final p = pokemonCampanaDesdeJson(carta({'tipo': 'confundeDefensor'}));
      expect((p.ataques.first.efecto as ConfundeDefensor).monedas, 1);
      expect(
          () => pokemonCampanaDesdeJson(
              carta({'tipo': 'confundeDefensor', 'monedas': 0})),
          throwsFormatException);
    });

    test('Zubat sigue a su carta impresa (041/150)', () {
      final zubat = pokemon['zubat']!;
      expect(zubat.tipo, TipoCampana.oscuridad);
      expect(zubat.ps, 60);
      expect(zubat.debilidad?.tipo, TipoCampana.electrico);
      expect(zubat.debilidad?.multiplicador, 2);
      expect(zubat.resistencia, isNull);
      expect(zubat.retirada, 0);
      expect(zubat.ataques.map((a) => a.nombre), ['Supersónico', 'Mordisco']);
      final sonico = zubat.ataques.first;
      expect(sonico.tipo, TipoCampana.oscuridad);
      expect(sonico.coste, 1);
      expect(sonico.dano, 0);
      expect((sonico.efecto as ConfundeDefensor).monedas, 1);
      final mordisco = zubat.ataques.last;
      expect(mordisco.tipo, TipoCampana.oscuridad);
      expect(mordisco.coste, 2);
      expect(mordisco.dano, 30);
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
        {'a': 'a', 'via': 'xp', 'xpEvolucion': 30},
        {'a': 'b', 'via': 'objeto', 'objeto': 'piedra-trueno'},
        {'a': 'c', 'via': 'intercambio', 'puntos': 200},
        {'a': 'd', 'via': 'puntos', 'puntos': 300},
      ], ex: true));
      expect(p.ex, isTrue);
      expect(p.evoluciones.map((e) => e.via), ViaEvolucion.values);
      expect(p.evoluciones[0].xpEvolucion, 30);
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

  group('jefes', () {
    final carpeta = Directory('../catalog/campana/jefes');
    final archivosJefes = carpeta
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final jefes = [for (final f in archivosJefes) jefeCampanaDesdeJson(leer(f))];

    test('hay jefes y su número es único y está dentro de la serie', () {
      expect(jefes, isNotEmpty);
      final numeros = jefes.map((j) => j.numero).toList();
      expect(numeros.toSet(), hasLength(numeros.length));
      for (final j in jefes) {
        expect(j.numero, inInclusiveRange(1, totalJefesCampana));
      }
    });

    test('el id del archivo coincide con el del Pokémon', () {
      for (var i = 0; i < jefes.length; i++) {
        final id = archivosJefes[i].uri.pathSegments.last.replaceAll('.json', '');
        expect(jefes[i].pokemon.id, id);
      }
    });

    test('sus aliados existen en el catálogo y no son el propio jefe', () {
      for (final j in jefes) {
        final l = j.llamaAliado;
        if (l == null) continue;
        expect(l.alBajarDePorcentaje, inInclusiveRange(1, 99));
        for (final a in l.aliados) {
          expect(pokemon.containsKey(a), isTrue, reason: '${j.pokemon.id}: $a');
        }
      }
    });

    test('Pikachu (01/20): 100 PS, Impactrueno 30 y llama a un aliado a la mitad', () {
      final p = jefes.firstWhere((j) => j.numero == 1);
      expect(p.pokemon.nombre, 'Pikachu');
      expect(p.pokemon.ps, 100);
      expect(p.pokemon.debilidad!.tipo, TipoCampana.lucha);
      expect(p.pokemon.ataques.map((a) => a.dano), [10, 30]);
      expect(p.llamaAliado!.alBajarDePorcentaje, 50);
      expect(p.llamaAliado!.aliados,
          ['weedle', 'caterpie', 'metapod', 'kakuna']);
    });

    test('el jefe tiene un ataque de 20 o más y cualquier inicial puede con él '
        'o termina el combate', () {
      for (final j in jefes) {
        expect(j.pokemon.ataques.any((a) => a.dano >= 20), isTrue,
            reason: j.pokemon.id);
      }
      final pikachu = jefes.firstWhere((j) => j.numero == 1).pokemon;
      for (final inicial in ['bulbasaur', 'charmander', 'squirtle']) {
        var e = EstadoCombate.inicial(
            equipoJugador: [pokemon[inicial]!], equipoRival: [pikachu]);
        for (var i = 0; i < 2000 && e.fase != FaseCombate.terminado; i++) {
          e = aplicarCombate(e, decidirAccion(e, e.actua));
        }
        expect(e.fase, FaseCombate.terminado, reason: inicial);
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
            e = aplicarCombate(e, decidirAccion(e, e.actua));
          }
          expect(e.fase, FaseCombate.terminado, reason: '${a.id} vs ${b.id}');
          expect(e.ganador, isNotNull);
        }
      }
    });
  });
}
