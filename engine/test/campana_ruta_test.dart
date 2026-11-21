import 'dart:convert';
import 'dart:io';

import 'package:incursiones_engine/campana.dart';
import 'package:incursiones_engine/incursiones_engine.dart' show ReglaIncumplida;
import 'package:test/test.dart';

Map<String, dynamic> leer(File f) =>
    jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;

List<File> jsonDe(String carpeta) => Directory(carpeta)
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.json'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

String idDe(File f) => f.uri.pathSegments.last.replaceAll('.json', '');

/// Una región mínima válida: inicio → combate → gimnasio.
RegionCampana region(List<NodoRuta> nodos, {String inicio = 'a'}) =>
    RegionCampana(
        id: 'r', nombre: 'R', inicio: inicio, nodos: {for (final n in nodos) n.id: n});

NodoRuta ini(List<String> salidas) => NodoRuta(
    id: 'a',
    tipo: TipoNodo.inicio,
    nombre: 'A',
    salidas: salidas,
    iniciales: const ['x']);

NodoRuta comb(String id, List<String> salidas, {bool opcional = false}) =>
    NodoRuta(
        id: id,
        tipo: TipoNodo.combate,
        nombre: id,
        salidas: salidas,
        opcional: opcional,
        zona: 'z',
        rival: RivalDeCombate.salvaje);

NodoRuta bif(String id, List<String> salidas) =>
    NodoRuta(id: id, tipo: TipoNodo.bifurcacion, nombre: id, salidas: salidas);

NodoRuta gim(String id) => NodoRuta(
    id: id,
    tipo: TipoNodo.gimnasio,
    nombre: id,
    lider: const LiderDeGimnasio('L', ['x']),
    medalla: 'm');

void main() {
  final kanto = regionCampanaDesdeJson(leer(File('../catalog/campana/regiones/kanto.json')));

  group('estructura de la región', () {
    test('una región sencilla es válida', () {
      final r = region([ini(['b']), comb('b', ['g']), gim('g')]);
      expect(r.problemas(), isEmpty);
      expect(r.finales.map((n) => n.id), ['g']);
      expect(r.entradas('g'), ['b']);
    });

    test('con una bifurcación y un combate opcional que se salta', () {
      final r = region([
        ini(['v']),
        bif('v', ['o', 'b']),
        comb('o', ['b'], opcional: true),
        comb('b', ['g']),
        gim('g'),
      ]);
      expect(r.problemas(), isEmpty);
    });

    test('un nodo opcional que obliga a pasar por él es un error', () {
      final r = region([
        ini(['o']),
        comb('o', ['g'], opcional: true),
        gim('g'),
      ]);
      expect(r.problemas().join(), contains('obliga a pasar por un nodo opcional'));
    });

    test('una bifurcación necesita dos salidas y solo ella puede tener varias', () {
      expect(
          region([ini(['v']), bif('v', ['g']), gim('g')]).problemas().join(),
          contains('dos salidas o más'));
      expect(
          region([ini(['b', 'g']), comb('b', ['g']), gim('g')]).problemas().join(),
          contains('solo una bifurcación puede tener varias salidas'));
    });

    test('las salidas tienen que existir', () {
      final r = region([ini(['nada'])]);
      expect(r.problemas().join(), contains('"nada" no existe'));
    });

    test('un nodo al que no se llega es un error', () {
      final r = region([ini(['g']), gim('g'), comb('suelto', ['g'])]);
      expect(r.problemas().join(), contains('suelto: no se llega a él'));
    });

    test('un ciclo es un error', () {
      final r = region([
        ini(['v']),
        bif('v', ['b', 'g']),
        comb('b', ['v']),
        gim('g'),
      ]);
      expect(r.problemas().join(), contains('ciclo'));
    });

    test('hay un solo inicio y no tiene entradas', () {
      final dos = region([
        ini(['g']),
        NodoRuta(
            id: 'b',
            tipo: TipoNodo.inicio,
            nombre: 'B',
            salidas: const ['g'],
            iniciales: const ['x']),
        gim('g'),
      ]);
      expect(dos.problemas().join(), contains('un solo nodo de inicio'));
    });

    test('la región solo acaba en un gimnasio o un jefe', () {
      final r = region([ini(['b']), comb('b', [])]);
      expect(r.problemas().join(), contains('solo acaba en un gimnasio o un jefe'));
    });

    test('cada tipo lleva sus datos y no los de otro', () {
      final sinZona = region([
        ini(['b']),
        const NodoRuta(id: 'b', tipo: TipoNodo.combate, nombre: 'b', salidas: ['g']),
        gim('g'),
      ]);
      expect(sinZona.problemas().join(), contains('necesita "zona" y "rival"'));
      final sinClase = region([
        ini(['b']),
        const NodoRuta(
            id: 'b',
            tipo: TipoNodo.combate,
            nombre: 'b',
            salidas: ['g'],
            zona: 'z',
            rival: RivalDeCombate.entrenador),
        gim('g'),
      ]);
      expect(sinClase.problemas().join(), contains('necesita "clase"'));
      final sobra = region([
        ini(['b']),
        const NodoRuta(
            id: 'b',
            tipo: TipoNodo.descanso,
            nombre: 'b',
            salidas: ['g'],
            medalla: 'm'),
        gim('g'),
      ]);
      expect(sobra.problemas().join(), contains('no lleva "medalla"'));
    });

    test('solo un combate o un descanso puede ser opcional', () {
      final r = region([
        ini(['g', 'b']),
        gim('g'),
        comb('b', ['g']),
      ]);
      expect(r.problemas(), isNotEmpty);
      final opc = region([
        NodoRuta(
            id: 'a',
            tipo: TipoNodo.inicio,
            nombre: 'A',
            salidas: const ['g'],
            iniciales: const ['x'],
            opcional: true),
        gim('g'),
      ]);
      expect(opc.problemas().join(), contains('solo un combate o un descanso puede ser opcional'));
    });
  });

  group('el JSON', () {
    test('un nodo con un tipo desconocido o repetido se rechaza', () {
      expect(
          () => nodoRutaDesdeJson({'id': 'a', 'tipo': 'tienda', 'nombre': 'A'}),
          throwsFormatException);
      final n = {'id': 'a', 'tipo': 'descanso', 'nombre': 'A'};
      expect(
          () => regionCampanaDesdeJson({
                'id': 'r',
                'nombre': 'R',
                'inicio': 'a',
                'nodos': [n, n],
              }),
          throwsFormatException);
    });

    test('el archivo tiene el nombre de su región', () {
      expect(idDe(jsonDe('../catalog/campana/regiones').single), kanto.id);
    });
  });

  group('Kanto: de Pueblo Paleta a Ciudad Plateada', () {
    final pokemon = {for (final f in jsonDe('../catalog/campana/pokemon')) idDe(f)};
    final jefes = {for (final f in jsonDe('../catalog/campana/jefes')) idDe(f)};
    final clases = {
      for (final f in jsonDe('../catalog/campana/zonas'))
        idDe(f): {
          for (final e in (leer(f)['entrenadores'] as List<dynamic>? ?? const []))
            (e as Map<String, dynamic>)['clase'] as String,
        },
    };

    test('la estructura es válida', () {
      expect(kanto.problemas(), isEmpty);
    });

    test('todo lo que nombra existe en el catálogo', () {
      expect(
          kanto.problemasDeCatalogo(
              pokemon: pokemon, jefes: jefes, clasesPorZona: clases),
          isEmpty);
    });

    test('empieza con los tres iniciales y acaba en el gimnasio de Brock', () {
      expect(kanto.nodo(kanto.inicio).iniciales,
          ['bulbasaur', 'charmander', 'squirtle']);
      final f = kanto.finales.single;
      expect(f.tipo, TipoNodo.gimnasio);
      expect(f.lider!.nombre, 'Brock');
      expect(f.lider!.pokemon, ['geodude', 'onix']);
      expect(f.medalla, 'roca');
    });

    // Reglas de diseño (D-20 §4): entre una medalla y la siguiente hay un
    // jefe, y en cada tramo hay al menos una bifurcación.
    test('cada tramo hasta un gimnasio tiene un jefe y una bifurcación', () {
      void recorre(String id, int nJefes, int bifurcaciones) {
        final n = kanto.nodo(id);
        if (n.tipo == TipoNodo.jefe) nJefes++;
        if (n.tipo == TipoNodo.bifurcacion) bifurcaciones++;
        if (n.tipo == TipoNodo.gimnasio) {
          expect(nJefes, 1, reason: 'jefes hasta ${n.id}');
          expect(bifurcaciones, greaterThanOrEqualTo(1),
              reason: 'bifurcaciones hasta ${n.id}');
          return;
        }
        for (final s in n.salidas) {
          recorre(s, nJefes, bifurcaciones);
        }
      }

      recorre(kanto.inicio, 0, 0);
    });

    test('el jefe es Pikachu y los combates opcionales son salvajes', () {
      final jefe = kanto.nodos.values.singleWhere((n) => n.tipo == TipoNodo.jefe);
      expect(jefe.jefe, 'pikachu-jefe');
      final opcionales = kanto.nodos.values.where((n) => n.opcional).toList();
      expect(opcionales.map((n) => n.id), ['ruta-22', 'cueva-diglett']);
    });
  });

  group('progreso por el mapa', () {
    test('al empezar hay que elegir inicial antes de avanzar', () {
      var p = ProgresoRuta.inicial(kanto);
      expect(p.nodoActual, 'pueblo-paleta');
      expect(p.opciones(kanto), isEmpty);
      expect(() => p.avanzar(kanto, 'ruta-1'), throwsA(isA<ReglaIncumplida>()));
      expect(() => p.resolver(kanto), throwsA(isA<ReglaIncumplida>()));
      expect(() => p.resolver(kanto, inicial: 'mewtwo'),
          throwsA(isA<ReglaIncumplida>()));
      p = p.resolver(kanto, inicial: 'charmander');
      expect(p.inicial, 'charmander');
      expect(p.opciones(kanto), ['ruta-1']);
    });

    test('no se puede resolver dos veces ni saltarse nodos', () {
      var p = ProgresoRuta.inicial(kanto).resolver(kanto, inicial: 'squirtle');
      expect(() => p.resolver(kanto), throwsA(isA<ReglaIncumplida>()));
      expect(() => p.avanzar(kanto, 'ruta-2'), throwsA(isA<ReglaIncumplida>()));
      p = p.avanzar(kanto, 'ruta-1');
      expect(p.resuelto, isFalse);
      expect(p.opciones(kanto), isEmpty);
    });

    test('una bifurcación se da por resuelta al llegar y se elige camino', () {
      var p = ProgresoRuta.inicial(kanto)
          .resolver(kanto, inicial: 'bulbasaur')
          .avanzar(kanto, 'ruta-1')
          .resolver(kanto)
          .avanzar(kanto, 'ciudad-verde');
      expect(p.resuelto, isTrue);
      expect(p.superados, contains('ciudad-verde'));
      expect(p.opciones(kanto), ['ruta-22', 'ruta-2']);
      // el camino opcional vuelve a la Ruta 2
      p = p.avanzar(kanto, 'ruta-22').resolver(kanto).avanzar(kanto, 'ruta-2');
      expect(p.superados, containsAll(['ruta-22']));
    });

    test('se puede recorrer el tramo entero por el camino corto', () {
      var p = ProgresoRuta.inicial(kanto);
      p = p.resolver(kanto, inicial: 'squirtle');
      for (final destino in [
        'ruta-1',
        'ciudad-verde',
        'ruta-2',
        'bosque-verde',
        'cazabichos',
        'jefe-pikachu',
        'salida-bosque',
        'centro-plateada',
        'gimnasio-plateada',
      ]) {
        p = p.avanzar(kanto, destino);
        if (!p.resuelto) p = p.resolver(kanto);
      }
      expect(p.terminado(kanto), isTrue);
      expect(p.medallas, {'roca'});
      expect(p.jefesDerrotados, {'pikachu-jefe'});
      expect(p.superados, isNot(contains('ruta-22')));
      expect(p.superados, isNot(contains('cueva-diglett')));
    });

    test('un jefe solo se captura la primera vez', () {
      var p = ProgresoRuta.inicial(kanto);
      expect(p.puedeCapturarJefe('pikachu-jefe'), isTrue);
      p = ProgresoRuta(nodoActual: 'jefe-pikachu').resolver(kanto);
      expect(p.puedeCapturarJefe('pikachu-jefe'), isFalse);
    });

    test('se guarda y se recupera tal cual', () {
      final p = ProgresoRuta.inicial(kanto)
          .resolver(kanto, inicial: 'charmander')
          .avanzar(kanto, 'ruta-1');
      final vuelta = ProgresoRuta.desdeJson(
          jsonDecode(jsonEncode(p.aJson())) as Map<String, dynamic>);
      expect(vuelta.aJson(), p.aJson());
      expect(vuelta.nodoActual, 'ruta-1');
      expect(vuelta.inicial, 'charmander');
    });
  });
}
