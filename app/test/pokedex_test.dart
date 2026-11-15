import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/almacen/almacen.dart';
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/catalogo/catalogo.dart';
import 'package:incursiones_app/partida/controlador_partida.dart';
import 'package:incursiones_app/pokedex/pokedex.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import 'ayudas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('modelo de la Pokédex', () {
    final cuando = DateTime.utc(2026, 11, 15);

    test('suma partidas y distingue vistos de derrotados', () {
      var p = const Pokedex();
      p = p.conPartida(
        jefe: 'Onix',
        aliadosVistos: ['Machop', 'Zubat'],
        victoria: false,
        cuando: cuando,
      );
      expect(p.jefe('Onix')!.enfrentado, 1);
      expect(p.jefe('Onix')!.derrotado, isFalse);
      expect(p.aliadoVisto('Machop'), isTrue);
      expect(p.aliadoVencido('Machop'), isFalse);

      p = p.conPartida(
        jefe: 'Onix',
        aliadosVistos: ['Machop'],
        victoria: true,
        cuando: cuando,
      );
      expect(p.jefe('Onix')!.enfrentado, 2);
      expect(p.jefe('Onix')!.victorias, 1);
      expect(p.jefe('Onix')!.derrotado, isTrue);
      expect(p.aliadoVencido('Machop'), isTrue);
      expect(p.aliadoVencido('Zubat'), isFalse);
      expect(p.jefe('Kingdra'), isNull);
    });

    test('«Kingdra ex» y «Kingdra» son el mismo jefe', () {
      final p = const Pokedex().conPartida(
        jefe: 'Kingdra ex',
        aliadosVistos: const [],
        victoria: true,
        cuando: cuando,
      );
      expect(p.jefe('Kingdra'), isNotNull);
    });

    test('se guarda y se lee; lo dañado da una Pokédex vacía', () {
      final p = const Pokedex().conPartida(
        jefe: 'Onix',
        aliadosVistos: ['Geodude'],
        victoria: true,
        cuando: cuando,
      );
      final leida = Pokedex.deTexto(jsonEncode(p.toJson()));
      expect(leida.jefe('Onix')!.victorias, 1);
      expect(leida.jefe('Onix')!.ultima, cuando);
      expect(leida.aliadoVencido('Geodude'), isTrue);
      expect(Pokedex.deTexto('no es json').jefes, isEmpty);
      expect(Pokedex.deTexto(null).aliados, isEmpty);
    });
  });

  test('al terminar una partida se apunta en el dispositivo, sin sesión',
      () async {
    final almacen = AlmacenMemoria();
    final c = ProviderContainer(overrides: sobrescribir(almacen: almacen));
    addTearDown(c.dispose);
    c.read(pokedexProvider);
    await asentar();

    final p = c.read(partidaProvider.notifier);
    expect(
      p.registrar(const ConfigurarJugadores([
        ConfigJugador(nombre: 'Ana', ataqueMaximo: 100),
      ])),
      isNull,
    );
    expect(
      p.registrar(const ElegirJefe(nombre: 'Onix', nivel: 1, hp: 100)),
      isNull,
    );
    expect(c.read(pokedexProvider).jefes, isEmpty);

    expect(p.registrar(const Abandonar()), isNull);
    await asentar();

    final dex = c.read(pokedexProvider);
    expect(dex.jefe('Onix')!.enfrentado, 1);
    expect(dex.jefe('Onix')!.derrotado, isFalse);
    expect(Pokedex.deTexto(almacen.datos[clavePokedex]).jefe('Onix'), isNotNull);

    // Deshacer y volver a terminar la misma partida no cuenta dos veces.
    p.deshacer();
    expect(p.registrar(const Abandonar()), isNull);
    await asentar();
    expect(c.read(pokedexProvider).jefe('Onix')!.enfrentado, 1);
  });

  testWidgets('la Pokédex muestra silueta, gris y color según lo visto',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final catalogo =
        (await tester.runAsync(() => Catalogo.cargar(rootBundle)))!;
    final guardada = const Pokedex()
        .conPartida(
          jefe: 'Onix',
          aliadosVistos: ['Machop', 'Geodude', 'Zubat'],
          victoria: true,
          cuando: DateTime.utc(2026, 11, 14),
        )
        .conPartida(
          jefe: 'Manectric',
          aliadosVistos: ['Plusle', 'Minun'],
          victoria: false,
          cuando: DateTime.utc(2026, 11, 15),
        );
    final almacen = AlmacenMemoria()
      ..datos[clavePokedex] = jsonEncode(guardada.toJson());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...sobrescribir(almacen: almacen, conInicio: true),
          catalogoProvider.overrideWith((ref) async => catalogo),
        ],
        child: const IncursionesApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inicio-pokedex')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pokedex')), findsOneWidget);
    expect(find.text('Mis cartas · Próximamente'), findsOneWidget);
    expect(find.text('7 de 28'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('pokedex-estado-onix')),
        matching: find.text('Derrotado'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('pokedex-estado-manectric')),
        matching: find.text('Enfrentado'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('pokedex-estado-kingdra')),
        matching: find.text('Sin enfrentar'),
      ),
      findsOneWidget,
    );
    expect(find.text('???'), findsNWidgets(2));
    expect(find.text('3/6'), findsOneWidget);
    expect(find.text('2/6'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pokedex-atras')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inicio')), findsOneWidget);
  });

  testWidgets('la Pokédex cabe en móvil', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final catalogo =
        (await tester.runAsync(() => Catalogo.cargar(rootBundle)))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...sobrescribir(conInicio: true),
          catalogoProvider.overrideWith((ref) async => catalogo),
        ],
        child: const IncursionesApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inicio-pokedex')));
    await tester.pumpAndSettle();
    expect(find.text('0 de 28'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la rueda del ratón desplaza y las pestañas suben, '
      'dejando fija la barra de arriba', (tester) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final catalogo =
        (await tester.runAsync(() => Catalogo.cargar(rootBundle)))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...sobrescribir(conInicio: true),
          catalogoProvider.overrideWith((ref) async => catalogo),
        ],
        child: const IncursionesApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inicio-pokedex')));
    await tester.pumpAndSettle();

    final antes = tester.getTopLeft(find.byKey(const Key('pokedex-progreso'))).dy;
    final volverAntes = tester.getTopLeft(find.byKey(const Key('pokedex-atras'))).dy;
    final raton = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(raton.hover(const Offset(195, 400)));
    await tester.sendEventToBinding(raton.scroll(const Offset(0, 150)));
    await tester.pumpAndSettle();

    final despues =
        tester.getTopLeft(find.byKey(const Key('pokedex-progreso'))).dy;
    expect(despues, lessThan(antes));
    expect(
      tester.getTopLeft(find.byKey(const Key('pokedex-atras'))).dy,
      volverAntes,
    );
  });
}
