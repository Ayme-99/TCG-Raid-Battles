import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/pantallas/carta.dart';
import 'package:incursiones_app/pantallas/mesa.dart';
import 'package:incursiones_app/partida/controlador_partida.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import 'ayudas.dart';

Future<ProviderContainer> abrir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: sobrescribir(), child: const IncursionesApp()),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(IncursionesApp)));
}

Future<void> tocar(WidgetTester tester, String clave) async {
  await tester.tap(find.byKey(Key(clave)));
  await tester.pumpAndSettle();
}

Future<void> escribir(WidgetTester tester, String clave, String texto) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(Key(clave)),
      matching: find.byType(TextField),
    ),
    texto,
  );
}

Future<void> empezar(WidgetTester tester) async {
  await escribir(tester, 'ataque-0', '100');
  await escribir(tester, 'ataque-1', '100');
  await tocar(tester, 'configurar');
  await escribir(tester, 'jefe-hp', '1000');
  await tocar(tester, 'elegir-jefe');
}

void main() {
  group('Camara', () {
    test('la vista general no mueve ni acerca', () {
      final c = Camara.de(const FocoGeneral(), 4);
      expect((c.ax, c.ay, c.zoom), (0, 0, 1));
    });

    test('el jefe está arriba, los aliados en medio y los jugadores abajo', () {
      final jefe = Camara.de(const FocoJefe(), 4);
      final aliados = Camara.de(const FocoAliados(), 4);
      final jugador = Camara.de(const FocoJugador(0), 4);
      expect(jefe.ay, lessThan(aliados.ay));
      expect(aliados.ay, lessThan(jugador.ay));
      expect(jugador.zoom, greaterThan(aliados.zoom));
    });

    test('cada asiento mira a su sitio de la fila, de izquierda a derecha', () {
      final xs = [
        for (var i = 0; i < 4; i++) Camara.de(FocoJugador(i), 4).ax,
      ];
      expect(xs, orderedEquals([...xs]..sort()));
      expect(xs.first, lessThan(0));
      expect(xs.last, greaterThan(0));
    });

    test('la matriz lleva el punto enfocado al centro de la mesa', () {
      const c = Camara(0.5, -0.5, 2);
      final m = c.matriz(800, 600);
      final punto = MatrixUtils.transformPoint(m, const Offset(600, 150));
      expect(punto.dx, closeTo(400, 0.001));
      expect(punto.dy, closeTo(300, 0.001));
    });
  });

  testWidgets('la mesa sale en el turno de los jugadores con todos sus sitios',
      (tester) async {
    final c = await abrir(tester);
    await empezar(tester);
    expect(find.byKey(const Key('mesa')), findsOneWidget);
    expect(find.byKey(const Key('zona-jefe')), findsOneWidget);
    expect(find.byKey(const Key('asiento-0')), findsOneWidget);
    expect(find.byKey(const Key('asiento-1')), findsOneWidget);
    // El jefe sigue siendo uno solo (no se duplica entre mesa y controles).
    expect(find.byKey(const Key('hp-jefe')), findsOneWidget);
    final estado = c.read(estadoProvider);
    // En el turno de los jugadores la cámara no se acerca a nadie.
    expect(focoDe(estado), const FocoGeneral());
  });

  testWidgets('la cámara pasa al jefe en su turno y se puede dirigir a mano',
      (tester) async {
    final c = await abrir(tester);
    await empezar(tester);
    for (var i = 0; i < 2; i++) {
      await escribir(tester, 'dano-turno', '10');
      await tocar(tester, 'registrar-turno');
    }
    expect(c.read(estadoProvider).fase, Fase.turnoJefe);
    expect(focoDe(c.read(estadoProvider)), const FocoJefe());
    // Tocar un asiento mueve la cámara sin cambiar la partida.
    await tocar(tester, 'asiento-1');
    expect(c.read(estadoProvider).fase, Fase.turnoJefe);
    // Tocar el fondo vuelve a la vista general.
    await tester.tapAt(const Offset(5, 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mesa')), findsOneWidget);
  });

  testWidgets('en pantalla ancha los controles flotan sobre la mesa',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(overrides: sobrescribir(), child: const IncursionesApp()),
    );
    await tester.pumpAndSettle();
    await empezar(tester);
    expect(find.byKey(const Key('mesa')), findsOneWidget);
    expect(find.byKey(const Key('barra-turno')), findsOneWidget);
    expect(find.byKey(const Key('panel-acciones')), findsOneWidget);
    // La mesa llena la pantalla: no hay barra de título.
    expect(find.byType(AppBar), findsNothing);
    // El bocadillo sale del asiento del jugador que actúa.
    expect(find.byKey(const Key('pico-bocadillo')), findsOneWidget);
    final pico = tester.getCenter(find.byKey(const Key('pico-bocadillo'))).dx;
    final asiento = tester.getCenter(find.byKey(const Key('asiento-0'))).dx;
    expect((pico - asiento).abs(), lessThan(40));
    // El panel se pliega y se despliega.
    await tocar(tester, 'panel-acciones-toggle');
    expect(find.byKey(const Key('panel-acciones')), findsOneWidget);
    expect(find.byKey(const Key('mesa')), findsOneWidget);
  });

  group('Cartas', () {
    test('el id de la carta no lleva tildes, espacios ni «ex»', () {
      expect(idCarta('Onix'), 'onix');
      expect(idCarta('Kingdra ex'), 'kingdra');
      expect(idCarta('Mr. Mime'), 'mrmime');
      expect(idCarta('Pokémon Ñu'), 'pokemonnu');
      expect(rutaCarta('Manectric'), 'assets/cartas/manectric.webp');
    });

    testWidgets('sin imagen pinta la alternativa', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              child: CartaImagen(
                nombre: 'Pokémon que no existe',
                alternativa: Text('sin carta'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('sin carta'), findsOneWidget);
    });
  });
}
