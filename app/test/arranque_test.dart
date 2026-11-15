import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/app.dart';

import 'ayudas.dart';

void main() {
  testWidgets('la app arranca en la pantalla de inicio (#232)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: sobrescribir(conInicio: true),
        child: const IncursionesApp(),
      ),
    );
    expect(find.byKey(const Key('inicio')), findsOneWidget);
    expect(find.byKey(const Key('inicio-nueva')), findsOneWidget);
    // Sin partida guardada no hay nada que continuar.
    expect(find.byKey(const Key('inicio-continuar')), findsNothing);
    expect(find.text('Jugadores y su mejor ataque'), findsNothing);
  });

  testWidgets('Nueva partida lleva al setup de la partida', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: sobrescribir(conInicio: true),
        child: const IncursionesApp(),
      ),
    );
    await tester.tap(find.byKey(const Key('inicio-nueva')));
    await tester.pumpAndSettle();
    for (final k in ['nueva-siguiente', 'nueva-siguiente', 'nueva-empezar']) {
      await tester.tap(find.byKey(Key(k)));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const Key('inicio')), findsNothing);
    expect(find.text('Jugadores y su mejor ataque'), findsOneWidget);
  });
}
