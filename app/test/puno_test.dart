import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/catalogo/catalogo.dart';
import 'package:incursiones_app/partida/tirada_mesa.dart';
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

  for (final hasta in [6, 7, 8, 9]) {
    testWidgets('Puño Incremento, etapa $hasta',
        timeout: const Timeout(Duration(seconds: 40)), (tester) async {
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
      final c = ProviderScope.containerOf(
        tester.element(find.byType(IncursionesApp)),
      );
      llegarALaLlamadaDelJefe(c);
      await tester.pump(const Duration(milliseconds: 500));
      await _asentar(tester);
      final aliado = c.read(estadoProvider).aliados.single;
      expect(aliado.nombre, 'Machop');
      expect(azar.sacadas, 0, reason: 'la llamada de Onix es segura');
      if (find.byKey(const Key('aviso-mesa-hecho')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('aviso-mesa-hecho')));
        await tester.pump(const Duration(milliseconds: 500));
      }
      if (hasta == 6) return;
      await tester.tap(find.byKey(const Key('entrada-0')));
      await tester.pump();
      if (hasta == 7) return;
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byKey(const ValueKey('moneda-mesa-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('moneda-mesa-1')), findsOneWidget);
      expect(azar.sacadas, 2);
      if (hasta == 8) return;
      await tester.pump(duracionMonedas + const Duration(seconds: 1));
      expect(c.read(tiradaMesaProvider), isNull);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('1 de 2 monedas en cara'), findsOneWidget);
    });
  }
}
