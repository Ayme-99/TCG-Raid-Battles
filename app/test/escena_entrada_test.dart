import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/pantallas/escena_entrada.dart';
import 'package:incursiones_app/partida/controlador_partida.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import 'ayudas.dart';

Future<ProviderContainer> abrir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1024, 768);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: sobrescribir(escenaEntrada: true),
      child: const IncursionesApp(),
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(IncursionesApp)));
}

void main() {
  test('cada mapa tiene su escena', () {
    expect(escenaDeMapa('Túnel Roca'), EscenaJefe.roca);
    expect(escenaDeMapa('Ruta 110'), EscenaJefe.tormenta);
    expect(escenaDeMapa('Islas Remolino'), EscenaJefe.agua);
    expect(escenaDeMapa('Sala Origen'), EscenaJefe.luz);
    expect(escenaDeMapa('Otro sitio'), EscenaJefe.generica);
    expect(escenaDeMapa(null), EscenaJefe.generica);
  });

  testWidgets('sale al elegir jefe, un toque la salta y dura unos segundos',
      (tester) async {
    final c = await abrir(tester);
    expect(find.byKey(const Key('escena-entrada')), findsNothing);

    final p = c.read(partidaProvider.notifier);
    p.registrar(const ConfigurarJugadores([
      ConfigJugador(nombre: 'Ana', ataqueMaximo: 100),
    ]));
    p.registrar(const ElegirJefe(nombre: 'Onix', nivel: 1, hp: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('escena-entrada')), findsOneWidget);

    await tester.tap(find.byKey(const Key('escena-entrada')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('escena-entrada')), findsNothing);
  });

  testWidgets('termina sola', (tester) async {
    final c = await abrir(tester);
    final p = c.read(partidaProvider.notifier);
    p.registrar(const ConfigurarJugadores([
      ConfigJugador(nombre: 'Ana', ataqueMaximo: 100),
    ]));
    p.registrar(const ElegirJefe(nombre: 'Onix', nivel: 1, hp: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4600));
    expect(find.byKey(const Key('escena-entrada')), findsNothing);
  });

  testWidgets('no sale mientras se juega: un golpe no la repite',
      (tester) async {
    final c = await abrir(tester);
    final p = c.read(partidaProvider.notifier);
    p.registrar(const ConfigurarJugadores([
      ConfigJugador(nombre: 'Ana', ataqueMaximo: 100),
    ]));
    p.registrar(const ElegirJefe(nombre: 'Onix', nivel: 1, hp: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4600));
    p.registrar(const TurnoJugador(jugador: 0, dano: 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('escena-entrada')), findsNothing);
  });
}
