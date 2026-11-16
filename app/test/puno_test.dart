import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/catalogo/catalogo.dart';
import 'package:incursiones_app/partida/controlador_partida.dart';

import 'ayudas.dart';

/// Azar con las monedas ya decididas, en orden (true = cara).
class _Azar implements Random {
  _Azar(this.monedas);

  final List<bool> monedas;
  var _i = 0;

  int get sacadas => _i;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => monedas[_i++ % monedas.length];

  @override
  double nextDouble() => 0;
}

Future<void> _asentar(WidgetTester tester) => tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Catalogo catalogo;

  setUpAll(() async {
    catalogo = await Catalogo.cargar(rootBundle);
  });

  for (final hasta in [1, 2, 3, 4, 5]) {
    testWidgets('Puño Incremento, etapa $hasta', (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final azar = _Azar([true, false]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...sobrescribir(),
            catalogoProvider.overrideWith((ref) async => catalogo),
            azarProvider.overrideWithValue(azar),
          ],
          child: const IncursionesApp(),
        ),
      );
      await _asentar(tester);
      for (final clave in ['ataque-0', 'ataque-1']) {
        await tester.enterText(
          find.descendant(
            of: find.byKey(Key(clave)),
            matching: find.byType(TextField),
          ),
          '100',
        );
      }
      await tester.tap(find.byKey(const Key('configurar')));
      await _asentar(tester);
      await tester.tap(find.byKey(const Key('catalogo-onix')));
      await _asentar(tester);
      if (hasta == 1) return;
      final c = ProviderScope.containerOf(
        tester.element(find.byType(IncursionesApp)),
      );
      llegarALaLlamadaDelJefe(c);
      if (hasta == 2) return;
      await tester.pump(const Duration(milliseconds: 500));
      if (hasta == 3) return;
      await _asentar(tester);
      if (hasta == 4) return;
      final aliado = c.read(estadoProvider).aliados.single;
      expect(aliado.nombre, 'Machop');
      expect(azar.sacadas, 0, reason: 'la llamada de Onix es segura');
      expect(find.byKey(const Key('entrada-0')), findsOneWidget);
    });
  }
}
