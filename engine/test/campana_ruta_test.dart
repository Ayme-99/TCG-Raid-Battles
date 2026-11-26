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

  group('Kanto: de Pueblo Paleta a Ciudad Celeste', () {
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

    test('empieza con los tres iniciales y acaba en el gimnasio de Misty', () {
      expect(kanto.nodo(kanto.inicio).iniciales,
          ['bulbasaur', 'charmander', 'squirtle']);
      final brock = kanto.nodo('gimnasio-brock');
      expect(brock.tipo, TipoNodo.gimnasio);
      expect(brock.lider!.nombre, 'Brock');
      expect(brock.lider!.pokemon, ['geodude', 'onix']);
      expect(brock.medalla, 'roca');
      expect(brock.salidas, ['ruta-3']);
      final f = kanto.finales.single;
      expect(f.tipo, TipoNodo.gimnasio);
      expect(f.lider!.nombre, 'Misty');
      expect(f.lider!.pokemon, ['staryu', 'starmie']);
      expect(f.lider!.dinero, 1500);
      expect(f.medalla, 'cascada');
    });

    test('la Ruta 1 es una bifurcación entre Pidgey y Rattata', () {
      final r = kanto.nodo('ruta-1');
      expect(r.tipo, TipoNodo.bifurcacion);
      expect(r.salidas.map((id) => kanto.nodo(id).pokemon),
          [['pidgey'], ['rattata']]);
    });

    test('la escena de la Ruta 1 usa las zonas de Arte (#415)', () {
      final arte = leer(File('../docs/diseno-ui/escenas/ruta-1.zonas.json'));
      final rel = {
        for (final z in arte['zonas'] as List)
          (z as Map)['id'] as String: [
            for (final v in z['rel'] as List) (v as num).toDouble()
          ]
      };
      void igual(ZonaPulsable z, String id) =>
          expect([z.x, z.y, z.ancho, z.alto], rel[id], reason: id);
      ZonaPulsable de(String nodo, AccionZona a, [String? destino]) =>
          kanto.nodo(nodo).escena!.zonas.singleWhere(
              (z) => z.accion == a && z.destino == destino);

      for (final n in ['ruta-1', 'ruta-1-pidgey', 'ruta-1-rattata']) {
        expect(kanto.nodo(n).escena!.imagen, 'ruta-1', reason: n);
      }
      igual(de('ruta-1', AccionZona.ir, 'ruta-1-pidgey'), 'hierba-izquierda');
      igual(de('ruta-1', AccionZona.ir, 'ruta-1-rattata'), 'hierba-derecha');
      igual(de('ruta-1', AccionZona.ir, 'pueblo-paleta'), 'entrada');
      igual(de('ruta-1-pidgey', AccionZona.combate), 'hierba-izquierda');
      igual(de('ruta-1-rattata', AccionZona.combate), 'hierba-derecha');
      for (final n in ['ruta-1-pidgey', 'ruta-1-rattata']) {
        igual(de(n, AccionZona.ir, 'ruta-1'), 'entrada');
        igual(de(n, AccionZona.ir, 'ciudad-verde'), 'salida-ciudad-verde');
      }
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
      final jefes = kanto.nodos.values.where((n) => n.tipo == TipoNodo.jefe);
      expect(jefes.map((n) => n.jefe), ['pikachu-jefe', 'clefairy-jefe']);
      expect(kanto.nodo('jefe-pikachu').salidas, ['ruta-2-norte']);
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

    test('los únicos nodos opcionales son la Ruta 22, la Ruta 2 norte, la '
        'galería del Monte Moon y la Ruta 24', () {
      final opcionales = kanto.nodos.values.where((n) => n.opcional).toList();
      expect(opcionales.map((n) => n.id),
          ['ruta-22', 'ruta-2-norte-salvaje', 'monte-moon-galeria', 'ruta-24']);
    });

    // Tramo 2 (D-20 §4, «Segundo tramo»; #513).
    test('la Ruta 3 ofrece Spearow o Nidoran♂ y luego la Chica y el Joven', () {
      final r = kanto.nodo('ruta-3');
      expect(r.tipo, TipoNodo.bifurcacion);
      expect(r.salidas.map((id) => kanto.nodo(id).pokemon),
          [['spearow'], ['nidoran-m']]);
      final chica = kanto.nodo('ruta-3-chica');
      final joven = kanto.nodo('ruta-3-joven');
      expect([chica.clase, joven.clase], ['Chica', 'Joven']);
      expect(chica.pokemon, ['rattata', 'nidoran-f']);
      expect(joven.pokemon, ['spearow', 'rattata']);
      expect(joven.salidas, ['centro-monte-moon']);
      expect(kanto.nodo('centro-monte-moon').tipo, TipoNodo.descanso);
    });

    test('Monte Moon: galería opcional y el jefe Clefairy', () {
      expect(kanto.nodo('monte-moon').salidas,
          ['monte-moon-galeria', 'jefe-clefairy']);
      final galeria = kanto.nodo('monte-moon-galeria');
      expect(galeria.opcional, isTrue);
      expect(galeria.rival, RivalDeCombate.salvaje);
      expect(galeria.zona, 'monte-moon');
      expect(kanto.nodo('jefe-clefairy').jefe, 'clefairy-jefe');
      expect(kanto.nodo('jefe-clefairy').salidas, ['ruta-4']);
    });

    test('la Ruta 4 ofrece Sandshrew o Rattata y lleva a Ciudad Celeste', () {
      final r = kanto.nodo('ruta-4');
      expect(r.tipo, TipoNodo.bifurcacion);
      expect(r.salidas.map((id) => kanto.nodo(id).pokemon),
          [['sandshrew'], ['rattata']]);
      for (final id in r.salidas) {
        expect(kanto.nodo(id).salidas, ['centro-celeste']);
      }
    });

    test('Ciudad Celeste: centro con Super Ball y Cuerda Huida, desvío a la '
        'Ruta 24, Nadador Luis y Misty', () {
      final centro = kanto.nodo('centro-celeste');
      expect(centro.tipo, TipoNodo.descanso);
      expect(centro.tienda, containsAll(['superBall', 'cuerdaHuida']));
      expect(kanto.nodo('celeste-salida').salidas, ['ruta-24', 'gimnasio-luis']);
      expect(kanto.nodo('ruta-24').opcional, isTrue);
      expect(kanto.nodo('ruta-24').salidas, ['gimnasio-luis']);
      final luis = kanto.nodo('gimnasio-luis');
      expect(luis.clase, 'Nadador');
      expect(luis.pokemon, ['horsea', 'shellder']);
      expect(luis.salidas, ['gimnasio-misty']);
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
          // El tramo siguiente empieza de cero.
          nJefes = 0;
          bifurcaciones = 0;
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

  group('escenas (D-20 §4, #413)', () {
    ZonaPulsable ir(String destino, {double x = 0.9}) => ZonaPulsable(
        accion: AccionZona.ir,
        destino: destino,
        x: x,
        y: 0.1,
        ancho: 0.1,
        alto: 0.8);
    ZonaPulsable hacer(AccionZona a) =>
        ZonaPulsable(accion: a, x: 0.3, y: 0.3, ancho: 0.4, alto: 0.4);
    NodoRuta conEscena(NodoRuta n, List<ZonaPulsable> zonas,
            {String imagen = 'fondo'}) =>
        NodoRuta(
          id: n.id,
          tipo: n.tipo,
          nombre: n.nombre,
          salidas: n.salidas,
          iniciales: n.iniciales,
          zona: n.zona,
          rival: n.rival,
          lider: n.lider,
          medalla: n.medalla,
          escena: EscenaNodo(imagen: imagen, zonas: zonas),
        );
    RegionCampana valida({
      List<ZonaPulsable>? zonasA,
      List<ZonaPulsable>? zonasB,
      List<ZonaPulsable>? zonasG,
      String imagenA = 'fondo',
    }) =>
        region([
          conEscena(
              ini(['b']), zonasA ?? [hacer(AccionZona.inicial), ir('b')],
              imagen: imagenA),
          conEscena(comb('b', ['g']),
              zonasB ?? [hacer(AccionZona.combate), ir('a', x: 0), ir('g')]),
          conEscena(gim('g'), zonasG ?? [hacer(AccionZona.combate), ir('b', x: 0)]),
        ]);

    test('las escenas de Kanto son válidas', () {
      expect(kanto.problemasDeEscenas(), isEmpty);
    });

    test('cada nodo de Kanto tiene imagen y hay 15 escenas distintas', () {
      final imagenes = {
        for (final n in kanto.nodos.values) n.escena!.imagen,
      };
      expect(imagenes, hasLength(15));
      for (final centro in ['centro-plateada', 'centro-monte-moon', 'centro-celeste']) {
        expect(kanto.nodo('ciudad-verde').escena!.imagen,
            kanto.nodo(centro).escena!.imagen,
            reason: 'los centros comparten imagen');
      }
    });

    test('una región con sus escenas bien hechas no da problemas', () {
      expect(valida().problemasDeEscenas(), isEmpty);
    });

    test('un nodo sin escena o sin imagen se avisa', () {
      final sin = region([ini(['b']), comb('b', ['g']), gim('g')]);
      expect(sin.problemasDeEscenas(), contains('a: no tiene escena.'));
      expect(valida(imagenA: ' ').problemasDeEscenas(),
          contains('a: la escena no tiene imagen.'));
    });

    test('una zona fuera de 0–1 o sin tamaño se avisa', () {
      final fuera = ZonaPulsable(
          accion: AccionZona.combate, x: 0.8, y: 0.1, ancho: 0.3, alto: 0.2);
      final plana = ZonaPulsable(
          accion: AccionZona.combate, x: 0.1, y: 0.1, ancho: 0, alto: 0.2);
      for (final z in [fuera, plana]) {
        expect(
            valida(zonasB: [z, ir('a', x: 0), ir('g')]).problemasDeEscenas(),
            contains('b: la zona combate se sale de la imagen.'));
      }
    });

    test('una zona que lleva a un nodo que no existe o no está al lado', () {
      expect(
          valida(zonasA: [hacer(AccionZona.inicial), ir('b'), ir('nada')])
              .problemasDeEscenas(),
          contains('a: la zona lleva a "nada", que no existe.'));
      expect(
          valida(zonasA: [hacer(AccionZona.inicial), ir('b'), ir('g')])
              .problemasDeEscenas(),
          contains('a: la zona lleva a "g", que no está al lado.'));
    });

    test('una salida sin zona deja el nodo siguiente sin acceso', () {
      expect(valida(zonasA: [hacer(AccionZona.inicial)]).problemasDeEscenas(),
          contains('a: la salida "b" no tiene zona en la escena.'));
    });

    test('falta la acción del tipo de nodo', () {
      expect(
          valida(zonasB: [ir('a', x: 0), ir('g')]).problemasDeEscenas(),
          contains('b: la escena de un combate necesita una zona "combate".'));
    });

    test('destino solo con ir, e ir sin destino', () {
      final conDestino = ZonaPulsable(
          accion: AccionZona.combate,
          destino: 'g',
          x: 0.3,
          y: 0.3,
          ancho: 0.2,
          alto: 0.2);
      expect(
          valida(zonasB: [conDestino, ir('a', x: 0), ir('g')])
              .problemasDeEscenas(),
          contains('b: solo una zona "ir" lleva "destino".'));
      const sinDestino =
          ZonaPulsable(accion: AccionZona.ir, x: 0, y: 0, ancho: 0.1, alto: 1);
      expect(
          valida(zonasG: [hacer(AccionZona.combate), sinDestino])
              .problemasDeEscenas(),
          contains('g: una zona "ir" necesita "destino".'));
    });

    test('el centro Pokémon necesita mostrador, tienda y PC', () {
      expect(accionesDeTipo(TipoNodo.descanso),
          {AccionZona.curar, AccionZona.tienda, AccionZona.pc});
      final centro = kanto.nodo('ciudad-verde').escena!;
      expect(centro.zonas.map((z) => z.accion),
          containsAll([AccionZona.curar, AccionZona.tienda, AccionZona.pc]));
    });

    test('se lee del JSON y una acción desconocida se rechaza', () {
      final json = {
        'id': 'a',
        'tipo': 'bifurcacion',
        'nombre': 'A',
        'escena': {
          'imagen': 'ruta-1',
          'zonas': [
            {'accion': 'ir', 'destino': 'b', 'x': 0.9, 'y': 0, 'ancho': 0.1, 'alto': 1},
          ],
        },
      };
      final n = nodoRutaDesdeJson(json);
      expect(n.escena!.imagen, 'ruta-1');
      expect(n.escena!.zonas.single.destino, 'b');
      expect(n.escena!.zonas.single.x, 0.9);
      ((json['escena'] as Map)['zonas'] as List).first['accion'] = 'volar';
      expect(() => nodoRutaDesdeJson(json), throwsFormatException);
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

    test('un centro Pokémon está resuelto al llegar: se sale sin curar (#510)',
        () {
      var p = ProgresoRuta.inicial(kanto)
          .resolver(kanto, inicial: 'bulbasaur')
          .avanzar(kanto, 'ruta-1')
          .avanzar(kanto, 'ruta-1-pidgey')
          .resolver(kanto)
          .avanzar(kanto, 'ciudad-verde');
      expect(p.resuelto, isTrue);
      expect(p.superados, contains('ciudad-verde'));
      expect(p.opciones(kanto), ['ciudad-verde-salida']);
      expect(() => p.resolver(kanto), throwsA(isA<ReglaIncumplida>()));
      // Al volver atrás también está resuelto.
      p = p
          .avanzar(kanto, 'ciudad-verde-salida')
          .retroceder(kanto, 'ciudad-verde');
      expect(p.resuelto, isTrue);
    });

    test('el desvío opcional se puede hacer y vuelve al camino principal', () {
      var p = ProgresoRuta.inicial(kanto)
          .resolver(kanto, inicial: 'bulbasaur')
          .avanzar(kanto, 'ruta-1')
          .avanzar(kanto, 'ruta-1-rattata')
          .resolver(kanto)
          .avanzar(kanto, 'ciudad-verde')
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
        'ruta-3',
        'ruta-3-nidoran-m',
        'ruta-3-chica',
        'ruta-3-joven',
        'centro-monte-moon',
        'monte-moon',
        'jefe-clefairy',
        'ruta-4',
        'ruta-4-sandshrew',
        'centro-celeste',
        'celeste-salida',
        'gimnasio-luis',
        'gimnasio-misty',
      ]) {
        p = p.avanzar(kanto, destino);
        if (!p.resuelto) p = p.resolver(kanto);
      }
      expect(p.terminado(kanto), isTrue);
      expect(p.medallas, {'roca', 'cascada'});
      expect(p.jefesDerrotados, {'pikachu-jefe', 'clefairy-jefe'});
      expect(p.superados, isNot(contains('monte-moon-galeria')));
      expect(p.superados, isNot(contains('ruta-24')));
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
