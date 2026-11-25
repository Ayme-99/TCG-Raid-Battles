import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/almacen/almacen.dart';
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/campana/catalogo_campana.dart';
import 'package:incursiones_app/campana/controlador_campana.dart';
import 'package:incursiones_app/campana/pantalla_campana.dart';
import 'package:incursiones_engine/campana.dart';

import 'ayudas.dart';

/// Abre la pantalla de campaña directamente, con el almacén [almacen].
Future<ProviderContainer> abrirCampana(
  WidgetTester tester, {
  required AlmacenMemoria almacen,
  Size tamano = const Size(1280, 800),
  PartidaCampana? guardada,
  CatalogoCampana? catalogo,
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...sobrescribir(almacen: almacen, conInicio: true),
        campanaInicialProvider.overrideWithValue(guardada),
        if (catalogo != null)
          catalogoCampanaProvider.overrideWith((ref) async => catalogo),
      ],
      child: const MaterialApp(home: PantallaCampana()),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
      tester.element(find.byType(PantallaCampana)));
}

bool hay(String clave) => find.byKey(Key(clave)).evaluate().isNotEmpty;

bool activo(WidgetTester tester, String clave) {
  final f = find.byKey(Key(clave));
  if (f.evaluate().isEmpty) return false;
  final w = tester.widget(f);
  return w is ButtonStyleButton && w.onPressed != null;
}

Future<void> tocar(WidgetTester tester, String clave) async {
  await tester.ensureVisible(find.byKey(Key(clave)));
  await tester.tap(find.byKey(Key(clave)));
  await tester.pumpAndSettle();
}

/// Cierra la hoja de abajo que esté abierta.
Future<void> cerrarHoja(WidgetTester tester) async {
  final hoja = find.byType(BottomSheet);
  Navigator.of(tester.element(hoja.last)).pop();
  await tester.pumpAndSettle();
}

/// Juega el combate que hay en pantalla tocando la mesa (D-20 §10.7,
/// propuesta I): toca a su activo y elige el ataque más caro que llegue, si no
/// carga; al caer un Pokémon saca al primero de la banca que pueda.
Future<void> jugarCombate(WidgetTester tester) async {
  for (var i = 0; i < 200; i++) {
    if (hay('combate-continuar')) {
      await tocar(tester, 'combate-continuar');
      return;
    }
    if (hay('combate-elige-relevo')) {
      final relevo = find.byWidgetPredicate((w) =>
          w is InkWell &&
          w.onTap != null &&
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('banca-jugador-'));
      await tester.tap(relevo.first);
      await tester.pumpAndSettle();
      continue;
    }
    if (!hay('hoja-acciones')) await tocar(tester, 'activo-jugador');
    if (activo(tester, 'ataque-1')) {
      await tocar(tester, 'ataque-1');
    } else if (!hay('ataque-1') && activo(tester, 'ataque-0')) {
      // Con dos ataques, si el fuerte no llega se carga (el otro es Gruñido).
      await tocar(tester, 'ataque-0');
    } else {
      await tocar(tester, 'accion-cargar');
    }
  }
  fail('El combate no termina.');
}

void main() {
  test('la copia del catálogo de campaña coincide con catalog/campana', () {
    for (final carpeta in ['pokemon', 'zonas', 'jefes', 'regiones']) {
      final original = Directory('../catalog/campana/$carpeta')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'));
      for (final f in original) {
        final nombre = f.uri.pathSegments.last;
        final copia = File('$carpetaCampana/$carpeta/$nombre');
        expect(copia.existsSync(), isTrue,
            reason: 'falta $carpeta/$nombre: ejecuta tool/sync_catalogo.sh');
        expect(jsonDecode(copia.readAsStringSync()),
            jsonDecode(f.readAsStringSync()),
            reason: '$carpeta/$nombre está desfasado');
      }
    }
    expect(catalogoCampanaDeDisco().problemas(), isEmpty);
  });

  testWidgets('el catálogo de campaña se lee de los assets de la app',
      (tester) async {
    final c = await tester.runAsync(() => cargarCatalogoCampana(rootBundle));
    expect(c!.region.nodos, contains('gimnasio-brock'));
    expect(c.pokemon, contains('bulbasaur'));
    expect(c.jefes, contains('pikachu-jefe'));
  });

  testWidgets('el selector de modo abre la campaña', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: sobrescribir(conInicio: true),
      child: const IncursionesApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inicio-nueva')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('opcion-campana')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('campana-mapa')), findsOneWidget);
    expect(find.byKey(const Key('campana-empezar')), findsOneWidget);
  });

  for (final (nombre, tamano) in [
    ('tablet', const Size(1280, 800)),
    ('móvil', const Size(844, 390)),
  ]) {
    testWidgets('primer combate y captura en $nombre', (tester) async {
      final almacen = AlmacenMemoria();
      final c = await abrirCampana(tester, almacen: almacen, tamano: tamano);
      await tocar(tester, 'campana-empezar');
      await tocar(tester, 'inicial-bulbasaur');
      expect(c.read(campanaProvider).partida!.equipo.single.id, 'bulbasaur');
      await tocar(tester, 'ir-ruta-1');
      await tocar(tester, 'ir-ruta-1-pidgey');
      await tocar(tester, 'campana-combatir');
      expect(find.byKey(const Key('campana-combate')), findsOneWidget);
      await jugarCombate(tester);
      // La Ruta 1 deja capturar, pero aún no hay Pokéballs (hasta la
      // primera tienda): se ofrece y solo queda seguir.
      expect(c.read(campanaProvider).partida!.capturaPendiente, 'pidgey');
      expect(find.text('No te quedan Balls: este combate acaba sin captura.'),
          findsOneWidget);
      await tocar(tester, 'campana-no-capturar');
      expect(c.read(campanaProvider).partida!.capturaPendiente, isNull);
      expect(tester.takeException(), isNull);
      // Se ha guardado en el dispositivo y se recupera igual.
      final guardada = PartidaCampana.desdeJson(
          jsonDecode(almacen.datos[claveCampana]!) as Map<String, dynamic>);
      expect(guardada.aJson(), c.read(campanaProvider).partida!.aJson());
    });
  }

  testWidgets(
      'se juega de Pueblo Paleta al centro de Ciudad Verde tocando botones',
      (tester) async {
    final almacen = AlmacenMemoria();
    final c = await abrirCampana(tester, almacen: almacen);
    await tocar(tester, 'campana-empezar');
    await tocar(tester, 'inicial-squirtle');
    final catalogo = catalogoCampanaDeDisco();
    for (var paso = 0; paso < 40; paso++) {
      final p = c.read(campanaProvider).partida!;
      if (p.progreso.nodoActual == 'ciudad-verde' && p.progreso.resuelto) break;
      if (p.capturaPendiente != null) {
        await tocar(tester, 'campana-no-capturar');
      } else if (p.hayCombate(catalogo)) {
        await tocar(tester, 'campana-combatir');
        await jugarCombate(tester);
      } else if (p.nodoActual(catalogo).tipo == TipoNodo.descanso &&
          !p.progreso.resuelto) {
        await tocar(tester, 'campana-curar');
      } else {
        await tocar(tester, 'ir-${p.opciones(catalogo).first}');
      }
    }
    final p = c.read(campanaProvider).partida!;
    expect(p.progreso.nodoActual, 'ciudad-verde');
    expect(p.progreso.resuelto, isTrue);
    expect(p.ultimaCura, 'ciudad-verde');
    expect(p.equipo.every((e) => e.ps == catalogo.especie(e.id).ps), isTrue);
    expect(p.equipo.length, 1,
        reason: 'sin Pokéballs no se captura en la Ruta 1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('se gana la Medalla Roca al vencer a Brock', (tester) async {
    final almacen = AlmacenMemoria();
    // El equilibrado de la campaña es cosa del simulador: este test solo
    // comprueba la pantalla del gimnasio y el final del tramo.
    const guardada = PartidaCampana(
      progreso: ProgresoRuta(
        nodoActual: 'gimnasio-brock',
        superados: {'pueblo-paleta', 'centro-plateada'},
        inicial: 'bulbasaur',
      ),
      equipo: [PokemonGuardado('bulbasaur', 999)],
      ultimaCura: 'centro-plateada',
    );
    final c = await abrirCampana(tester, almacen: almacen, guardada: guardada);
    expect(find.textContaining('Brock'), findsWidgets);
    await tocar(tester, 'campana-combatir');
    await jugarCombate(tester);
    final catalogo = catalogoCampanaDeDisco();
    final p = c.read(campanaProvider).partida!;
    expect(p.terminada(catalogo), isTrue);
    expect(p.progreso.medallas, {'roca'});
    expect(find.textContaining('Medalla Roca'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contra el jefe, el aliado entra en la banca y la partida sigue',
      (tester) async {
    const guardada = PartidaCampana(
      progreso: ProgresoRuta(
        nodoActual: 'jefe-pikachu',
        superados: {'pueblo-paleta', 'ciudad-verde'},
        inicial: 'bulbasaur',
      ),
      equipo: [PokemonGuardado('bulbasaur', 999)],
      ultimaCura: 'ciudad-verde',
    );
    final c = await abrirCampana(tester,
        almacen: AlmacenMemoria(), guardada: guardada);
    expect(find.textContaining('Pikachu'), findsWidgets);
    await tocar(tester, 'campana-combatir');
    await jugarCombate(tester);
    final p = c.read(campanaProvider).partida!;
    expect(p.progreso.jefesDerrotados, {'pikachu-jefe'});
    expect(p.capturaPendiente, 'pikachu', reason: 'el aliado no se captura');
    // Sin Balls, el combate acaba sin captura.
    expect(find.text('No te quedan Balls: este combate acaba sin captura.'),
        findsOneWidget);
    expect(hay('campana-no-capturar'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('se lanza una Ball: gasta una y Pikachu jefe cae seguro',
      (tester) async {
    const guardada = PartidaCampana(
      progreso: ProgresoRuta(
        nodoActual: 'jefe-pikachu',
        resuelto: true,
        superados: {'pueblo-paleta', 'jefe-pikachu'},
        jefesDerrotados: {'pikachu-jefe'},
        inicial: 'bulbasaur',
      ),
      equipo: [PokemonGuardado('bulbasaur', 90)],
      capturaPendiente: 'pikachu',
      mochila: {ObjetoCampana.pokeball: 2},
    );
    final c = await abrirCampana(tester,
        almacen: AlmacenMemoria(), guardada: guardada);
    expect(find.textContaining('Pokéball (2) · 100 %'), findsOneWidget);
    await tocar(tester, 'lanzar-pokeball');
    var p = c.read(campanaProvider).partida!;
    expect(p.capturaLograda, isTrue);
    expect(p.cuantos(ObjetoCampana.pokeball), 1);
    expect(hay('campana-no-capturar'), isFalse,
        reason: 'ya capturado, solo queda colocarlo');
    await tocar(tester, 'campana-capturar');
    p = c.read(campanaProvider).partida!;
    expect(p.equipo.map((e) => e.id), ['bulbasaur', 'pikachu']);
    expect(p.capturaPendiente, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('con cruz se avisa y se puede volver a lanzar', (tester) async {
    // Onix (Fuerte) con Pokéball: 25 %. Se busca una semilla que falle.
    final catalogo = catalogoCampanaDeDisco();
    var semilla = 1;
    PartidaCampana base(int s) => PartidaCampana(
          progreso: const ProgresoRuta(
              nodoActual: 'ruta-2-weedle',
              resuelto: true,
              superados: {'pueblo-paleta', 'ruta-2-weedle'}),
          equipo: const [PokemonGuardado('squirtle', 80)],
          capturaPendiente: 'onix',
          mochila: const {ObjetoCampana.pokeball: 3},
          semilla: s,
        );
    while (base(semilla)
        .lanzarBall(catalogo, ObjetoCampana.pokeball)
        .capturaLograda) {
      semilla++;
    }
    final c = await abrirCampana(tester,
        almacen: AlmacenMemoria(), guardada: base(semilla));
    expect(find.textContaining('Pokéball (3) · 25 %'), findsOneWidget);
    await tocar(tester, 'lanzar-pokeball');
    expect(find.text('¡Se ha escapado de la Ball!'), findsOneWidget);
    final p = c.read(campanaProvider).partida!;
    expect(p.capturaLograda, isFalse);
    expect(p.cuantos(ObjetoCampana.pokeball), 2);
    expect(hay('lanzar-pokeball'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desde el equipo se evoluciona con la XP de la reserva',
      (tester) async {
    const guardada = PartidaCampana(
      progreso: ProgresoRuta(
          nodoActual: 'ruta-2-norte',
          superados: {'pueblo-paleta'},
          inicial: 'charmander'),
      equipo: [
        PokemonGuardado('charmander', 70),
        PokemonGuardado('caterpie', 0),
        PokemonGuardado('weedle', 50),
      ],
      xp: 60,
    );
    final almacen = AlmacenMemoria();
    final c = await abrirCampana(tester, almacen: almacen, guardada: guardada);
    await tocar(tester, 'campana-ver-equipo');
    expect(hay('pantalla-equipo'), isTrue);
    expect(find.text('Reserva de XP: 60'), findsOneWidget);
    // Rejilla de 2×3: tres cartas y tres huecos libres (propuesta J).
    expect(hay('equipo-hueco-3') && hay('equipo-hueco-5'), isTrue);
    expect(hay('equipo-hueco-2'), isFalse);
    // Caterpie está debilitado: evolucionar lo revive a 10 PS.
    await tocar(tester, 'equipo-1');
    expect(find.text('Evolucionar en Metapod (50 XP)'), findsOneWidget);
    await tocar(tester, 'equipo-evolucionar-metapod');
    final p = c.read(campanaProvider).partida!;
    expect(p.equipo[1].id, 'metapod');
    expect(p.equipo[1].ps, 10);
    expect(p.xp, 10);
    expect(find.text('Reserva de XP: 10'), findsOneWidget);
    // Weedle ya no llega: la opción sale pero desactivada.
    await tocar(tester, 'equipo-2');
    expect(find.text('Faltan 40 XP.'), findsOneWidget);
    final tile = tester
        .widget<ListTile>(find.byKey(const Key('equipo-evolucionar-kakuna')));
    expect(tile.enabled, isFalse);
    // Se guarda en el dispositivo.
    final json = jsonDecode(almacen.datos[claveCampana]!) as Map;
    expect(json['xp'], 10);
    expect(tester.takeException(), isNull);
  });

  testWidgets('una evolución sin las medallas que pide muestra el motivo',
      (tester) async {
    // Pidgey → Rattata de mentira con 2 medallas (Pidgeotto no tiene carta).
    final almacen = AlmacenMemoria();
    final real =
        (await tester.runAsync(() => cargarCatalogoCampana(rootBundle)))!;
    final pidgey = jsonDecode(
        File('assets/catalogo/campana/pokemon/pidgey.json')
            .readAsStringSync()) as Map<String, dynamic>;
    pidgey['evoluciones'] = [
      {'a': 'rattata', 'via': 'xp', 'xpEvolucion': 50, 'medallasMinimas': 2},
    ];
    final catalogo = CatalogoCampana(
      pokemon: {...real.pokemon, 'pidgey': pokemonCampanaDesdeJson(pidgey)},
      zonas: real.zonas,
      jefes: real.jefes,
      region: real.region,
    );
    const guardada = PartidaCampana(
      progreso: ProgresoRuta(
          nodoActual: 'ruta-2-norte', superados: {'pueblo-paleta'}),
      equipo: [PokemonGuardado('pidgey', 60)],
      xp: 200,
    );
    final c = await abrirCampana(tester,
        almacen: almacen, guardada: guardada, catalogo: catalogo);
    await tocar(tester, 'campana-ver-equipo');
    await tocar(tester, 'equipo-0');
    expect(find.text('Requiere 2 medallas.'), findsOneWidget);
    final tile = tester
        .widget<ListTile>(find.byKey(const Key('equipo-evolucionar-rattata')));
    expect(tile.enabled, isFalse);
    expect(c.read(campanaProvider).partida!.equipo.single.id, 'pidgey');
  });

  testWidgets('se vuelve a un nodo visitado y se repite el salvaje',
      (tester) async {
    const guardada = PartidaCampana(
      progreso: ProgresoRuta(
          nodoActual: 'ciudad-verde',
          resuelto: true,
          superados: {
            'pueblo-paleta',
            'ruta-1',
            'ruta-1-pidgey',
            'ciudad-verde'
          },
          visitados: {
            'pueblo-paleta',
            'ruta-1',
            'ruta-1-pidgey',
            'ciudad-verde'
          },
          inicial: 'squirtle'),
      equipo: [PokemonGuardado('squirtle', 80)],
      dinero: 1000,
    );
    final almacen = AlmacenMemoria();
    final c = await abrirCampana(tester, almacen: almacen, guardada: guardada);
    // Un borde que lleva a un nodo sin visitar no lleva a ningún sitio.
    await tester.tap(find.byKey(const Key('zona-ir-ruta-1-rattata')));
    await tester.pumpAndSettle();
    expect(
        c.read(campanaProvider).partida!.progreso.nodoActual, 'ciudad-verde');
    // El borde de un nodo visitado vuelve atrás.
    await tocar(tester, 'zona-ir-ruta-1-pidgey');
    expect(
        c.read(campanaProvider).partida!.progreso.nodoActual, 'ruta-1-pidgey');
    expect(hay('campana-combatir'), isFalse, reason: 'ya se ganó');
    await tocar(tester, 'campana-repetir');
    final p = c.read(campanaProvider).partida!;
    expect(hay('campana-combatir'), isTrue);
    expect(p.progreso.repitiendo, isTrue);
    expect(find.textContaining('Recompensa'), findsNothing,
        reason: 'repetir no da puntos');
    expect(tester.takeException(), isNull);
  });

  testWidgets('con una campaña guardada se continúa donde estaba',
      (tester) async {
    const guardada = PartidaCampana(
      progreso: ProgresoRuta(
          nodoActual: 'centro-plateada',
          superados: {'pueblo-paleta'},
          inicial: 'charmander'),
      equipo: [
        PokemonGuardado('charmander', 10),
        PokemonGuardado('pidgey', 0),
      ],
      pc: [PokemonGuardado('rattata', 60)],
      puntos: 1200,
      dinero: 500,
    );
    final almacen = AlmacenMemoria();
    final c = await abrirCampana(tester, almacen: almacen, guardada: guardada);
    expect(find.text('1200 puntos · 500 \$ · 0 medallas'), findsOneWidget);
    // Tienda del primer tramo: solo Pokéball y Poción (D-20 §10.6). Se abre
    // desde la estantería o con el botón del panel (propuesta M).
    await tocar(tester, 'centro-tienda');
    expect(hay('hoja-tienda'), isTrue);
    expect(hay('tienda-pokeball'), isTrue);
    expect(hay('tienda-pocion'), isTrue);
    expect(hay('tienda-repelente'), isFalse);
    expect(hay('tienda-superBall'), isFalse);
    // Una Poción (300), y se usa con Charmander antes de curar.
    await tocar(tester, 'comprar-pocion');
    expect(c.read(campanaProvider).partida!.dinero, 200);
    await tocar(tester, 'comprar-pokeball');
    expect(c.read(campanaProvider).partida!.dinero, 0);
    expect(c.read(campanaProvider).partida!.cuantos(ObjetoCampana.pokeball), 1);
    await cerrarHoja(tester);
    await tocar(tester, 'campana-ver-equipo');
    await tocar(tester, 'equipo-0');
    await tocar(tester, 'equipo-pocion');
    expect(c.read(campanaProvider).partida!.equipo.first.ps, 30);
    await cerrarHoja(tester);
    await tocar(tester, 'equipo-volver');
    await tocar(tester, 'campana-curar');
    expect(c.read(campanaProvider).partida!.equipo.map((e) => e.ps), [70, 60]);
    // PC, en su pantalla aparte: Rattata entra al equipo (hay hueco).
    await tocar(tester, 'centro-pc');
    expect(hay('pantalla-pc'), isTrue);
    await tocar(tester, 'pc-0');
    expect(c.read(campanaProvider).partida!.equipo.length, 3);
    expect(c.read(campanaProvider).partida!.pc, isEmpty);
    expect(hay('pc-vacio'), isTrue);
    await tocar(tester, 'pc-volver');
    // Poner primero a Rattata.
    await tocar(tester, 'campana-ver-equipo');
    await tocar(tester, 'equipo-2');
    await tocar(tester, 'equipo-primero');
    expect(c.read(campanaProvider).partida!.equipo.first.id, 'rattata');
    await tocar(tester, 'equipo-volver');
    await tocar(tester, 'ir-gimnasio-joven');
    expect(find.textContaining('Entrenador Joven'), findsWidgets);
  });

  testWidgets('antes de Pikachu, un Cazabichos avisa y cura al equipo',
      (tester) async {
    const guardada = PartidaCampana(
      progreso: ProgresoRuta(
          nodoActual: 'aviso-pikachu',
          superados: {'pueblo-paleta', 'cazabichos-2'},
          inicial: 'bulbasaur'),
      equipo: [PokemonGuardado('bulbasaur', 10)],
      ultimaCura: 'ciudad-verde',
    );
    final almacen = AlmacenMemoria();
    final c = await abrirCampana(tester, almacen: almacen, guardada: guardada);
    expect(find.textContaining('comiendo la comida'), findsOneWidget);
    expect(find.byKey(const Key('ir-jefe-pikachu')), findsNothing);
    await tocar(tester, 'campana-conversar');
    final p = c.read(campanaProvider).partida!;
    expect(p.equipo.single.ps, 90);
    expect(p.ultimaCura, 'aviso-pikachu');
    expect(find.byKey(const Key('ir-jefe-pikachu')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('una campaña guardada dañada se descarta', () async {
    final almacen = AlmacenMemoria()..datos[claveCampana] = '{"version": 99}';
    expect(await leerCampana(almacen), isNull);
    expect(almacen.datos, isNot(contains(claveCampana)));
  });

  testWidgets(
      'centro Pokémon: el PC es una pantalla aparte y, con el equipo '
      'lleno, se cambia uno por otro (propuesta M)', (tester) async {
    const guardada = PartidaCampana(
      progreso: ProgresoRuta(
          nodoActual: 'ciudad-verde',
          superados: {'pueblo-paleta'},
          inicial: 'squirtle'),
      equipo: [
        PokemonGuardado('squirtle', 80),
        PokemonGuardado('pidgey', 60),
        PokemonGuardado('rattata', 60),
        PokemonGuardado('caterpie', 50),
        PokemonGuardado('weedle', 50),
        PokemonGuardado('spearow', 60),
      ],
      pc: [PokemonGuardado('nidoran-f', 70)],
    );
    final c = await abrirCampana(tester,
        almacen: AlmacenMemoria(),
        guardada: guardada,
        tamano: const Size(844, 390));
    // La zona del PC de la escena abre la pantalla del PC.
    await tocar(tester, 'zona-pc');
    expect(hay('pantalla-pc'), isTrue);
    expect(find.text('Equipo (6/6)'), findsOneWidget);
    await tocar(tester, 'pc-0');
    expect(hay('hoja-pc-cambiar'), isTrue);
    await tocar(tester, 'pc-cambiar-0-3');
    var p = c.read(campanaProvider).partida!;
    expect(p.equipo[3].id, 'nidoran-f');
    expect(p.pc.single.id, 'caterpie');
    // Dejar uno del equipo en el PC.
    await tocar(tester, 'pc-equipo-5');
    p = c.read(campanaProvider).partida!;
    expect(p.equipo.length, 5);
    expect(p.pc.map((e) => e.id), ['caterpie', 'spearow']);
    await tocar(tester, 'pc-volver');
    expect(hay('pantalla-pc'), isFalse);
    // La estantería abre la tienda; el mostrador cura.
    await tocar(tester, 'zona-tienda');
    expect(hay('hoja-tienda'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'pantalla de equipo: caídos en gris, aviso y orden solo en el '
      'centro (propuesta J)', (tester) async {
    const guardada = PartidaCampana(
      progreso: ProgresoRuta(
          nodoActual: 'ruta-2-norte',
          superados: {'pueblo-paleta'},
          inicial: 'squirtle'),
      equipo: [
        PokemonGuardado('squirtle', 30),
        PokemonGuardado('pidgey', 0),
      ],
      mochila: {ObjetoCampana.pocion: 2, ObjetoCampana.piedraEx: 1},
    );
    // A tamaño de móvil apaisado (la campaña solo va en horizontal, §10.7).
    final c = await abrirCampana(tester,
        almacen: AlmacenMemoria(),
        guardada: guardada,
        tamano: const Size(844, 390));
    await tocar(tester, 'campana-ver-equipo');
    expect(find.text('Pociones: 2'), findsOneWidget);
    expect(find.text('Piedras ex: 1'), findsOneWidget);
    expect(find.text('Debilitado'), findsOneWidget);
    expect(find.byType(ColorFiltered), findsOneWidget,
        reason: 'el caído va en gris');
    // Un debilitado: aviso del centro y la Poción apagada.
    await tocar(tester, 'equipo-1');
    expect(hay('equipo-aviso-debilitado'), isTrue);
    expect(
        tester.widget<ListTile>(find.byKey(const Key('equipo-pocion'))).enabled,
        isFalse);
    // Fuera de un centro no se ordena ni se deja en el PC.
    expect(hay('equipo-primero'), isFalse);
    expect(hay('equipo-al-pc'), isFalse);
    expect(hay('equipo-solo-centro'), isTrue);
    await cerrarHoja(tester);
    // La Poción cura 20 y quedan las que haya.
    await tocar(tester, 'equipo-0');
    await tocar(tester, 'equipo-pocion');
    expect(c.read(campanaProvider).partida!.equipo.first.ps, 50);
    expect(find.text('Te quedan 1.'), findsOneWidget);
    await cerrarHoja(tester);
    expect(find.text('Pociones: 1'), findsOneWidget);
    await tocar(tester, 'equipo-volver');
    expect(hay('pantalla-equipo'), isFalse);
    expect(tester.takeException(), isNull);
  });
}
