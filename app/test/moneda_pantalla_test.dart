import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/pantallas/comun.dart';
import 'package:incursiones_app/partida/controlador_partida.dart';

/// Azar que siempre da el mismo resultado en las monedas.
class _Azar implements Random {
  _Azar(this.cara);

  final bool cara;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => cara;

  @override
  double nextDouble() => 0;
}

void main() {
  for (final cara in [true, false]) {
    testWidgets('la moneda cae en la pantalla y sale ${cara ? 'cara' : 'cruz'}',
        (tester) async {
      bool? resultado;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [azarProvider.overrideWithValue(_Azar(cara))],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  key: const Key('lanzar'),
                  onPressed: () async {
                    resultado = await lanzarMonedaEnPantalla(
                      context,
                      ref,
                      titulo: 'Bote',
                      detalle: 'Ana lanza 1 moneda.',
                    );
                  },
                  child: const Text('lanzar'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('lanzar')));
      await tester.pump();
      expect(find.byKey(const Key('moneda-en-pantalla')), findsOneWidget);
      // Mientras gira no se puede continuar.
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('moneda-continuar')))
            .onPressed,
        isNull,
      );
      await tester.pumpAndSettle();
      expect(find.text(cara ? 'Sale cara' : 'Sale cruz'), findsOneWidget);
      await tester.tap(find.byKey(const Key('moneda-continuar')));
      await tester.pumpAndSettle();
      expect(resultado, cara);
      expect(find.byKey(const Key('moneda-en-pantalla')), findsNothing);
    });
  }
}
