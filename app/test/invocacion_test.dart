import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/catalogo/catalogo.dart';
import 'package:incursiones_app/partida/controlador_partida.dart';

import 'ayudas.dart';

/// Azar que cuenta cuántas veces se tiran los dados (nextInt).
class _Azar implements Random {
  var dados = 0;

  @override
  int nextInt(int max) {
    dados++;
    return 0;
  }

  @override
  bool nextBool() => true;

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

  testWidgets(
    'la primera llamada del jefe tira los dados una sola vez (dos dados), '
    'aunque cambie la pantalla de turno',
    timeout: const Timeout(Duration(seconds: 40)),
    (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final azar = _Azar();
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
      // Un intento: un dado de slot y uno de categoría, y un solo aliado.
      expect(azar.dados, 2);
      expect(c.read(estadoProvider).aliados, hasLength(1));
      expect(c.read(estadoProvider).intentosInvocacionPendientes, 0);
    },
  );
}
