import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/partida/controlador_partida.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import 'ayudas.dart';

Future<ProviderContainer> abrirInicio(
  WidgetTester tester, {
  Size tamano = const Size(1024, 768),
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: sobrescribir(conInicio: true),
      child: const IncursionesApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(IncursionesApp)));
}

/// Deja una partida a medias: dos jugadores y un jefe de 100 HP.
Future<void> dejarPartidaAMedias(WidgetTester tester, ProviderContainer c) async {
  final p = c.read(partidaProvider.notifier);
  expect(
    p.registrar(const ConfigurarJugadores([
      ConfigJugador(nombre: 'Ana', ataqueMaximo: 100),
      ConfigJugador(nombre: 'Bea', ataqueMaximo: 100),
    ])),
    isNull,
  );
  expect(
    p.registrar(const ElegirJefe(nombre: 'Jefe', nivel: 1, hp: 100)),
    isNull,
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (nombre, tamano) in [
    ('tablet', const Size(1024, 768)),
    ('móvil', const Size(390, 844)),
  ]) {
    testWidgets('el inicio ofrece sus opciones en $nombre', (tester) async {
      await abrirInicio(tester, tamano: tamano);
      expect(find.byKey(const Key('inicio-nueva')), findsOneWidget);
      expect(find.byKey(const Key('inicio-pokedex')), findsOneWidget);
      expect(find.byKey(const Key('inicio-cuenta')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con una partida a medias aparece Continuar en $nombre',
        (tester) async {
      final c = await abrirInicio(tester, tamano: tamano);
      await dejarPartidaAMedias(tester, c);
      expect(find.byKey(const Key('inicio-continuar')), findsOneWidget);
      expect(find.textContaining('Ronda 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Continuar retoma la partida donde estaba', (tester) async {
    final c = await abrirInicio(tester);
    await dejarPartidaAMedias(tester, c);
    await tester.tap(find.byKey(const Key('inicio-continuar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inicio')), findsNothing);
    expect(find.byKey(const Key('mesa')), findsOneWidget);
    expect(c.read(estadoProvider).jefe, isNotNull);
  });

  testWidgets('Nueva partida con una a medias pide confirmar antes de descartarla',
      (tester) async {
    final c = await abrirInicio(tester);
    await dejarPartidaAMedias(tester, c);

    await tester.tap(find.byKey(const Key('inicio-nueva')));
    await tester.pumpAndSettle();
    expect(find.text('¿Empezar una partida nueva?'), findsOneWidget);

    // Volver no descarta nada.
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inicio')), findsOneWidget);
    expect(c.read(estadoProvider).jefe, isNotNull);

    await tester.tap(find.byKey(const Key('inicio-nueva')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('descartar-partida')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inicio')), findsNothing);
    expect(c.read(estadoProvider).jefe, isNull);
    expect(find.text('Jugadores y su mejor ataque'), findsOneWidget);
  });

  testWidgets('el Pokédex avisa de que llega pronto', (tester) async {
    await abrirInicio(tester);
    await tester.tap(find.byKey(const Key('inicio-pokedex')));
    await tester.pump();
    expect(find.text('El Pokédex llega pronto.'), findsOneWidget);
  });

  testWidgets('Cuenta abre el inicio de sesión', (tester) async {
    await abrirInicio(tester);
    await tester.tap(find.byKey(const Key('inicio-cuenta')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inicio')), findsNothing);
    expect(find.byType(TextField), findsWidgets);
  });
}
