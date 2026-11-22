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

/// Juega el combate que hay en pantalla tocando botones: el ataque más caro que
/// llegue, si no cargar; al caer un Pokémon saca al primero que pueda.
Future<void> jugarCombate(WidgetTester tester) async {
  for (var i = 0; i < 200; i++) {
    if (hay('combate-continuar')) {
      await tocar(tester, 'combate-continuar');
      return;
    }
    final relevo = find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('relevo-'));
    if (relevo.evaluate().isNotEmpty) {
      await tester.tap(relevo.first);
      await tester.pumpAndSettle();
      continue;
    }
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
    ('móvil', const Size(390, 844)),
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
      final p = c.read(campanaProvider).partida!;
      if (p.capturaPendiente != null) {
        await tocar(tester, 'campana-capturar');
        expect(c.read(campanaProvider).partida!.equipo.length, 2);
      }
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
        await tocar(tester, 'campana-capturar');
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
    expect(p.equipo.length, greaterThanOrEqualTo(2));
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
    expect(find.byKey(const Key('campana-capturar')), findsOneWidget);
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
    expect(find.text('Reserva de XP: 60'), findsOneWidget);
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
    final tile = tester.widget<ListTile>(
        find.byKey(const Key('equipo-evolucionar-kakuna')));
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
    final real = (await tester.runAsync(() => cargarCatalogoCampana(rootBundle)))!;
    final pidgey = jsonDecode(
            File('assets/catalogo/campana/pokemon/pidgey.json').readAsStringSync())
        as Map<String, dynamic>;
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
    await tocar(tester, 'equipo-0');
    expect(find.text('Requiere 2 medallas.'), findsOneWidget);
    final tile = tester.widget<ListTile>(
        find.byKey(const Key('equipo-evolucionar-rattata')));
    expect(tile.enabled, isFalse);
    expect(c.read(campanaProvider).partida!.equipo.single.id, 'pidgey');
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
      dinero: 300,
    );
    final almacen = AlmacenMemoria();
    final c = await abrirCampana(tester, almacen: almacen, guardada: guardada);
    expect(find.text('1200 puntos · 300 \$ · 0 medallas'), findsOneWidget);
    // Tienda: una Poción, y se usa con Charmander antes de curar.
    await tocar(tester, 'comprar-pocion');
    expect(c.read(campanaProvider).partida!.dinero, 200);
    await tocar(tester, 'equipo-0');
    await tocar(tester, 'equipo-pocion');
    expect(c.read(campanaProvider).partida!.equipo.first.ps, 30);
    await tocar(tester, 'campana-curar');
    expect(c.read(campanaProvider).partida!.equipo.map((e) => e.ps), [70, 60]);
    // PC: Rattata entra al equipo (hay hueco).
    await tocar(tester, 'pc-sacar-0');
    expect(c.read(campanaProvider).partida!.equipo.length, 3);
    expect(c.read(campanaProvider).partida!.pc, isEmpty);
    // Poner primero a Rattata.
    await tocar(tester, 'equipo-2');
    await tocar(tester, 'equipo-primero');
    expect(c.read(campanaProvider).partida!.equipo.first.id, 'rattata');
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
}
