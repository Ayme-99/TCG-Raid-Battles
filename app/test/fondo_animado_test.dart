import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/pantallas/fondo_animado.dart';

import 'ayudas.dart';

Future<void> abrirInicio(
  WidgetTester tester, {
  required Size tamano,
  bool animado = true,
  bool reducirMovimiento = false,
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reducirMovimiento);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: sobrescribir(conInicio: true, fondoAnimado: animado),
      child: const IncursionesApp(),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('en móvil el fondo se anima (tormenta) y se puede pintar',
      (tester) async {
    await abrirInicio(tester, tamano: const Size(390, 844));
    expect(find.byKey(const Key('fondo-animado')), findsOneWidget);
    // Recorre un ciclo entero: lluvia y el relámpago (a los 9 s) sin fallos.
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('inicio-nueva')), findsOneWidget);
  });

  testWidgets('en pantalla ancha el fondo se anima (luz dorada y bruma)',
      (tester) async {
    await abrirInicio(tester, tamano: const Size(1024, 768));
    expect(find.byKey(const Key('fondo-animado')), findsOneWidget);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(seconds: 3));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('con «reducir movimiento» el fondo se queda quieto',
      (tester) async {
    await abrirInicio(
      tester,
      tamano: const Size(390, 844),
      reducirMovimiento: true,
    );
    expect(find.byKey(const Key('fondo-quieto')), findsOneWidget);
    expect(find.byKey(const Key('fondo-animado')), findsNothing);
    // Sin animación, el árbol se asienta: no hay nada corriendo.
    await tester.pumpAndSettle();
  });

  testWidgets('se detiene al abrir otra pantalla encima', (tester) async {
    await abrirInicio(tester, tamano: const Size(390, 844));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.tap(find.byKey(const Key('inicio-nueva')));
    await tester.pump(const Duration(milliseconds: 600));
    // El fondo del inicio queda tapado: su reloj deja de contar.
    expect(find.byKey(const Key('nueva-partida')), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
