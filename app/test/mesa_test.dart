import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/pantallas/carta.dart';
import 'package:incursiones_app/pantallas/estilo.dart';
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
  group('izquierdaBocadillo', () {
    const panel = DisposicionMesa.anchoPanel;

    test('con 2 jugadores queda centrado en su asiento', () {
      final izq = izquierdaBocadillo(
        ancho: 1915,
        alto: 910,
        jugadores: 2,
        centro: 1915 * 0.25,
      );
      expect(izq + panel / 2, closeTo(1915 * 0.25, 1));
    });

    test('con 4 jugadores el asiento 2 no tapa al jefe (#217)', () {
      const ancho = 1915.0;
      final izq = izquierdaBocadillo(
        ancho: ancho,
        alto: 910,
        jugadores: 4,
        centro: ancho * 1.5 / 4,
      );
      // El cuadro del jefe mide unos 330 px y está centrado.
      expect(izq + panel, lessThanOrEqualTo(ancho / 2 - 330 / 2));
    });

    test('el asiento de la derecha se aparta hacia la derecha', () {
      const ancho = 1915.0;
      final izq = izquierdaBocadillo(
        ancho: ancho,
        alto: 910,
        jugadores: 4,
        centro: ancho * 2.5 / 4,
      );
      expect(izq, greaterThanOrEqualTo(ancho / 2 + 330 / 2));
    });

    test('sin sitio a un lado se queda donde estaba', () {
      final izq = izquierdaBocadillo(
        ancho: 1100,
        alto: 900,
        jugadores: 3,
        centro: 550,
      );
      expect(izq, greaterThanOrEqualTo(12));
    });
  });

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
    // Un slot de aliado por jugador, vacío al empezar, a los lados del jefe.
    expect(find.byKey(const Key('slot-libre-0')), findsOneWidget);
    expect(find.byKey(const Key('slot-libre-1')), findsOneWidget);
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
    // Lo secundario no tapa la mesa: el orden de la ronda va en un cuadro y
    // las acciones, en el menú de cada carta o asiento.
    expect(find.byKey(const Key('panel-extras-interno')), findsNothing);
    expect(find.byKey(const Key('panel-info-ronda')), findsNothing);
    await tocar(tester, 'info-ronda');
    expect(find.byKey(const Key('panel-info-ronda')), findsOneWidget);
    expect(find.textContaining('Orden de la ronda'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panel-info-ronda')), findsNothing);
    await tocar(tester, 'menu-jugador-0');
    expect(find.byKey(const Key('accion-ko')), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    // El panel se pliega y se despliega.
    await tocar(tester, 'panel-acciones-toggle');
    expect(find.byKey(const Key('panel-acciones')), findsOneWidget);
    expect(find.byKey(const Key('mesa')), findsOneWidget);
  });

  testWidgets('el chip de ronda se adapta al ancho y se oculta si no cabe (#214)',
      (tester) async {
    final c = await abrir(tester);
    await empezar(tester);
    expect(find.text('Ronda 1 · Turno de Jugador 1'), findsOneWidget);
    // 2 = texto largo, 1 = corto, 0 = oculto. Al estrechar la pantalla (ya en
    // partida: el formulario de jugadores no cabe a 380 px) solo puede bajar.
    int nivel() => find.text('Ronda 1 · Turno de Jugador 1').evaluate().isNotEmpty
        ? 2
        : find.text('R1 · J1').evaluate().isNotEmpty
            ? 1
            : 0;
    var anterior = nivel();
    expect(anterior, 2);
    for (final ancho in [800.0, 650.0, 520.0, 440.0, 400.0]) {
      tester.view.physicalSize = Size(ancho, 800);
      await tester.pumpAndSettle();
      expect(c.read(estadoProvider).ronda, 1);
      expect(nivel(), lessThanOrEqualTo(anterior), reason: 'ancho $ancho');
      anterior = nivel();
      // Si no se muestra ninguno, tampoco queda el chip vacío.
      if (anterior == 0) {
        expect(find.byKey(const Key('barra-turno')), findsNothing);
      }
      expect(find.byKey(const Key('abandonar')), findsOneWidget);
    }
  });

  testWidgets('un nombre larguísimo no encoge el asiento (#224)',
      (tester) async {
    await abrir(tester);
    await escribir(tester, 'nombre-0', 'Maria Del Carmen Piñeiro Fernandez');
    await empezar(tester);
    final largo = tester.getSize(find.byKey(const Key('nombre-asiento-0')));
    final corto = tester.getSize(find.byKey(const Key('nombre-asiento-1')));
    // El nombre se recorta a un tope de ancho...
    expect(largo.width, lessThanOrEqualTo(130));
    // ...y los dos asientos miden lo mismo.
    expect(
      tester.getSize(find.byKey(const Key('menu-jugador-0'))),
      tester.getSize(find.byKey(const Key('menu-jugador-1'))),
    );
    expect(largo.height, corto.height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la barra de vida llena tiene relleno visible', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 200, child: BarraVida(fraccion: 1)),
          ),
        ),
      ),
    );
    final relleno = tester.getSize(find.byType(FractionallySizedBox).first);
    expect(relleno.height, greaterThan(10));
    expect(relleno.width, greaterThan(150));
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
