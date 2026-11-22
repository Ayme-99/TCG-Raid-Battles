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
    final zonas = [
      for (final f in jsonDe('../catalog/campana/zonas')) zonaCampanaDesdeJson(leer(f)),
    ];
    final salvajes = {for (final z in zonas) z.id: z.salvajes.toSet()};
    final entrenadores = {
      for (final z in zonas)
        z.id: {for (final e in z.entrenadores) e.clase: e.pokemon.toSet()},
    };

    test('la estructura es válida', () {
      expect(kanto.problemas(), isEmpty);
    });

    test('todo lo que nombra existe en el catálogo y es de su zona', () {
      expect(
          kanto.problemasDeCatalogo(
              pokemon: pokemon,
              jefes: jefes,
              salvajesPorZona: salvajes,
              entrenadoresPorZona: entrenadores),
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

    test('la Ruta 1 es una bifurcación entre Pidgey y Rattata', () {
      final r = kanto.nodo('ruta-1');
      expect(r.tipo, TipoNodo.bifurcacion);
      expect(r.salidas.map((id) => kanto.nodo(id).pokemon),
          [['pidgey'], ['rattata']]);
    });

    test('Ciudad Verde tiene centro Pokémon y la Ruta 22 es un desvío opcional',
        () {
      expect(kanto.nodo('ciudad-verde').tipo, TipoNodo.descanso);
      expect(kanto.nodo('ruta-22').opcional, isTrue);
      expect(kanto.nodo('ciudad-verde-salida').salidas, ['ruta-22', 'ruta-2']);
      expect(kanto.nodo('ruta-22').salidas, ['ruta-2']);
    });

    test('la Ruta 2 sur ofrece Weedle o Caterpie y luego van dos Cazabichos', () {
      expect(kanto.nodo('ruta-2').salidas.map((id) => kanto.nodo(id).pokemon),
          [['weedle'], ['caterpie']]);
      final c1 = kanto.nodo('cazabichos-1');
      final c2 = kanto.nodo('cazabichos-2');
      expect([c1.rival, c2.rival], everyElement(RivalDeCombate.entrenador));
      expect([c1.clase, c2.clase], everyElement('Cazabichos'));
      expect(c2.salidas, ['aviso-pikachu']);
    });

    test('antes de Pikachu, un Cazabichos avisa y cura sin combatir', () {
      final aviso = kanto.nodo('aviso-pikachu');
      expect(aviso.tipo, TipoNodo.conversacion);
      expect(aviso.cura, isTrue);
      expect(aviso.curaEquipo, isTrue);
      expect(aviso.personaje, isNotNull);
      expect(aviso.texto, isNotEmpty);
      expect(aviso.salidas, ['jefe-pikachu']);
    });

    test('el jefe es Pikachu y después hay un salvaje opcional o seguir', () {
      final jefe = kanto.nodos.values.singleWhere((n) => n.tipo == TipoNodo.jefe);
      expect(jefe.jefe, 'pikachu-jefe');
      final norte = kanto.nodo('ruta-2-norte');
      expect(norte.tipo, TipoNodo.bifurcacion);
      expect(norte.salidas, ['ruta-2-norte-salvaje', 'centro-plateada']);
      expect(kanto.nodo('ruta-2-norte-salvaje').opcional, isTrue);
    });

    test('Ciudad Plateada: centro Pokémon, Entrenador Joven y Brock', () {
      expect(kanto.nodo('centro-plateada').tipo, TipoNodo.descanso);
      final joven = kanto.nodo('gimnasio-joven');
      expect(joven.clase, 'Entrenador Joven');
      expect(joven.pokemon, ['diglett', 'sandshrew']);
      expect(joven.salidas, ['gimnasio-brock']);
    });

    test('los únicos nodos opcionales son la Ruta 22 y la Ruta 2 norte', () {
      final opcionales = kanto.nodos.values.where((n) => n.opcional).toList();
      expect(opcionales.map((n) => n.id), ['ruta-22', 'ruta-2-norte-salvaje']);
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
  });

  group('conversación', () {
    NodoRuta charla({String? personaje = 'P', List<String> texto = const ['Hola'],
            bool cura = true}) =>
        NodoRuta(
            id: 'h',
            tipo: TipoNodo.conversacion,
            nombre: 'h',
            salidas: const ['g'],
            personaje: personaje,
            texto: texto,
            cura: cura);

    test('con personaje y texto es válida, cure o no', () {
      expect(region([ini(['h']), charla(), gim('g')]).problemas(), isEmpty);
      expect(region([ini(['h']), charla(cura: false), gim('g')]).problemas(),
          isEmpty);
      expect(charla().curaEquipo, isTrue);
      expect(charla(cura: false).curaEquipo, isFalse);
    });

    test('necesita personaje y texto', () {
      expect(
          region([ini(['h']), charla(personaje: null), gim('g')])
              .problemas()
              .join(),
          contains('necesita "personaje" y "texto"'));
      expect(region([ini(['h']), charla(texto: const []), gim('g')])
          .problemas()
          .join(), contains('necesita "personaje" y "texto"'));
    });

    test('solo una conversación lleva texto, personaje o cura', () {
      final r = region([
        ini(['d']),
        const NodoRuta(
            id: 'd',
            tipo: TipoNodo.descanso,
            nombre: 'd',
            salidas: ['g'],
            texto: ['x'],
            cura: true),
        gim('g'),
      ]);
      expect(r.problemas().join(), allOf(contains('no lleva "texto"'),
          contains('no lleva "cura"')));
      expect(r.nodo('d').curaEquipo, isTrue, reason: 'un descanso siempre cura');
    });

    test('no puede ser opcional ni el final de la región', () {
      final opcional = region([
        ini(['h']),
        const NodoRuta(
            id: 'h',
            tipo: TipoNodo.conversacion,
            nombre: 'h',
            salidas: ['g'],
            opcional: true,
            personaje: 'P',
            texto: ['x']),
        gim('g'),
      ]);
      expect(opcional.problemas().join(), contains('puede ser opcional'));
      final final_ = region([
        ini(['h']),
        const NodoRuta(
            id: 'h',
            tipo: TipoNodo.conversacion,
            nombre: 'h',
            personaje: 'P',
            texto: ['x']),
      ]);
      expect(final_.problemas().join(),
          contains('solo acaba en un gimnasio o un jefe'));
    });

    test('se lee del JSON', () {
      final n = nodoRutaDesdeJson({
        'id': 'h',
        'tipo': 'conversacion',
        'nombre': 'H',
        'salidas': ['g'],
        'personaje': 'P',
        'texto': ['Uno', 'Dos'],
        'cura': true,
      });
      expect(n.tipo, TipoNodo.conversacion);
      expect(n.personaje, 'P');
      expect(n.texto, ['Uno', 'Dos']);
      expect(n.cura, isTrue);
    });
  });

  group('Pokémon fijos de un nodo', () {
    NodoRuta salvaje(List<String> pokemon) => NodoRuta(
        id: 'b',
        tipo: TipoNodo.combate,
        nombre: 'b',
        salidas: const ['g'],
        zona: 'z',
        rival: RivalDeCombate.salvaje,
        pokemon: pokemon);

    test('un salvaje lleva como mucho un Pokémon y solo un combate los lleva', () {
      expect(region([ini(['b']), salvaje(['x']), gim('g')]).problemas(), isEmpty);
      expect(region([ini(['b']), salvaje([]), gim('g')]).problemas(), isEmpty);
      expect(
          region([ini(['b']), salvaje(['x', 'y']), gim('g')]).problemas().join(),
          contains('salvaje lleva un solo Pokémon'));
      final descanso = region([
        ini(['d']),
        const NodoRuta(
            id: 'd',
            tipo: TipoNodo.descanso,
            nombre: 'd',
            salidas: ['g'],
            pokemon: ['x']),
        gim('g'),
      ]);
      expect(descanso.problemas().join(), contains('no lleva "pokemon"'));
    });

    test('un Pokémon que no es de la zona o de la clase se detecta', () {
      final r = region([
        ini(['b']),
        salvaje(['ajeno']),
        gim('g'),
      ]);
      final p = r.problemasDeCatalogo(
          pokemon: {'x', 'ajeno'},
          jefes: {},
          salvajesPorZona: {'z': {'x'}},
          entrenadoresPorZona: {});
      expect(p.join(), contains('"ajeno" no es un salvaje de "z"'));
      final falta = r.problemasDeCatalogo(
          pokemon: {'x'},
          jefes: {},
          salvajesPorZona: {'z': {'x'}},
          entrenadoresPorZona: {});
      expect(falta.join(), contains('el Pokémon "ajeno" no existe'));
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
      // la Ruta 1 es una bifurcación: ya está resuelta y hay que elegir
      expect(p.resuelto, isTrue);
      expect(p.opciones(kanto), ['ruta-1-pidgey', 'ruta-1-rattata']);
      p = p.avanzar(kanto, 'ruta-1-pidgey');
      expect(p.resuelto, isFalse);
      expect(p.opciones(kanto), isEmpty);
    });

    test('el desvío opcional se puede hacer y vuelve al camino principal', () {
      var p = ProgresoRuta.inicial(kanto)
          .resolver(kanto, inicial: 'bulbasaur')
          .avanzar(kanto, 'ruta-1')
          .avanzar(kanto, 'ruta-1-rattata')
          .resolver(kanto)
          .avanzar(kanto, 'ciudad-verde')
          .resolver(kanto)
          .avanzar(kanto, 'ciudad-verde-salida');
      expect(p.opciones(kanto), ['ruta-22', 'ruta-2']);
      p = p.avanzar(kanto, 'ruta-22').resolver(kanto).avanzar(kanto, 'ruta-2');
      expect(p.superados, contains('ruta-22'));
      expect(p.opciones(kanto), ['ruta-2-weedle', 'ruta-2-caterpie']);
    });

    test('se puede recorrer el tramo entero por el camino corto', () {
      var p = ProgresoRuta.inicial(kanto);
      p = p.resolver(kanto, inicial: 'squirtle');
      for (final destino in [
        'ruta-1',
        'ruta-1-pidgey',
        'ciudad-verde',
        'ciudad-verde-salida',
        'ruta-2',
        'ruta-2-weedle',
        'cazabichos-1',
        'cazabichos-2',
        'aviso-pikachu',
        'jefe-pikachu',
        'ruta-2-norte',
        'centro-plateada',
        'gimnasio-joven',
        'gimnasio-brock',
      ]) {
        p = p.avanzar(kanto, destino);
        if (!p.resuelto) p = p.resolver(kanto);
      }
      expect(p.terminado(kanto), isTrue);
      expect(p.medallas, {'roca'});
      expect(p.jefesDerrotados, {'pikachu-jefe'});
      expect(p.superados, isNot(contains('ruta-22')));
      expect(p.superados, isNot(contains('ruta-2-norte-salvaje')));
      expect(p.superados, isNot(contains('ruta-1-rattata')));
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
