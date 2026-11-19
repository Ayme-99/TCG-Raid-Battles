import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/pantallas/fondo_menu.dart';

import 'ayudas.dart';

void main() {
  testWidgets('la preparación de la partida mantiene el fondo del menú',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: sobrescribir(),
        child: const IncursionesApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FondoMenu), findsOneWidget);
    expect(find.byKey(const Key('nombre-0')), findsOneWidget);
  });
}
