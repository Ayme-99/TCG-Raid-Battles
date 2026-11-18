import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/pantallas/aviso_central.dart';
import 'package:incursiones_app/pantallas/comun.dart';

/// Una pantalla con un botón en una esquina (que cuenta pulsaciones) y otro
/// para lanzar el aviso que toque.
Widget _pantalla({
  required void Function(BuildContext) lanzar,
  required void Function() alPulsar,
  bool sinMovimiento = false,
}) {
  return MaterialApp(
    builder: (context, hijo) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: sinMovimiento),
      child: hijo!,
    ),
    home: Scaffold(
      body: Stack(
        children: [
          Align(
            alignment: Alignment.bottomLeft,
            child: TextButton(
              key: const Key('esquina'),
              onPressed: alPulsar,
              child: const Text('esquina'),
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (c) => TextButton(
                key: const Key('lanzar'),
                onPressed: () => lanzar(c),
                child: const Text('lanzar'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _lanzar(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('lanzar')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('aviso central', () {
    testWidgets('sale en medio de la pantalla', (tester) async {
      await tester.pumpWidget(
        _pantalla(
          lanzar: (c) => registrarAviso(c, 'Salió cruz'),
          alPulsar: () {},
        ),
      );
      await _lanzar(tester);
      expect(find.text('Salió cruz'), findsOneWidget);
      final centro = tester.getCenter(find.byKey(const Key('aviso')));
      final pantalla = tester.getCenter(find.byType(Scaffold));
      expect((centro.dx - pantalla.dx).abs(), lessThan(1));
      expect((centro.dy - pantalla.dy).abs(), lessThan(1));
      // Ya no es un SnackBar de abajo.
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('se cierra solo, y tarda más con más líneas', (tester) async {
      await tester.pumpWidget(
        _pantalla(
          lanzar: (c) => registrarAvisos(c, ['uno', 'dos', 'tres']),
          alPulsar: () {},
        ),
      );
      await _lanzar(tester);
      expect(find.byKey(const Key('aviso')), findsOneWidget);
      // Tres líneas: más de lo que dura un aviso de una.
      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const Key('aviso')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('aviso')), findsNothing);
    });

    testWidgets('un aviso de una línea dura menos', (tester) async {
      expect(duracionAviso('una'), const Duration(seconds: 3));
      expect(
        duracionAviso('a\nb\nc'),
        greaterThan(duracionAviso('a\nb')),
      );
      expect(
        duracionAviso(List.filled(30, 'x').join('\n')),
        const Duration(seconds: 10),
      );
    });

    testWidgets('se cierra al tocarlo', (tester) async {
      await tester.pumpWidget(
        _pantalla(
          lanzar: (c) => registrarAviso(c, 'Hola'),
          alPulsar: () {},
        ),
      );
      await _lanzar(tester);
      await tester.tap(find.byKey(const Key('aviso')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('aviso')), findsNothing);
    });

    testWidgets('no bloquea los controles de debajo', (tester) async {
      var pulsaciones = 0;
      await tester.pumpWidget(
        _pantalla(
          lanzar: (c) => registrarAviso(c, 'Cae un aliado'),
          alPulsar: () => pulsaciones++,
        ),
      );
      await _lanzar(tester);
      expect(find.byKey(const Key('aviso')), findsOneWidget);
      await tester.tap(find.byKey(const Key('esquina')));
      await tester.pump();
      expect(pulsaciones, 1);
      // Y el aviso sigue ahí: pulsar otra cosa no lo cierra.
      expect(find.byKey(const Key('aviso')), findsOneWidget);
    });

    testWidgets('uno nuevo sustituye al anterior', (tester) async {
      var n = 0;
      await tester.pumpWidget(
        _pantalla(
          lanzar: (c) => registrarAviso(c, 'aviso ${++n}'),
          alPulsar: () {},
        ),
      );
      await _lanzar(tester);
      await _lanzar(tester);
      expect(find.byKey(const Key('aviso')), findsOneWidget);
      expect(find.text('aviso 2'), findsOneWidget);
      expect(find.text('aviso 1'), findsNothing);
    });

    testWidgets('varios avisos a la vez salen juntos en uno', (tester) async {
      await tester.pumpWidget(
        _pantalla(
          lanzar: (c) => registrarAvisos(c, ['Primero', 'Segundo']),
          alPulsar: () {},
        ),
      );
      await _lanzar(tester);
      expect(find.byKey(const Key('aviso')), findsOneWidget);
      expect(find.text('Primero\nSegundo'), findsOneWidget);
    });

    testWidgets('sin avisos no sale nada', (tester) async {
      await tester.pumpWidget(
        _pantalla(
          lanzar: (c) => registrarAvisos(c, const []),
          alPulsar: () {},
        ),
      );
      await _lanzar(tester);
      expect(find.byKey(const Key('aviso')), findsNothing);
    });

    testWidgets('con «reducir movimiento» aparece y desaparece sin animar',
        (tester) async {
      await tester.pumpWidget(
        _pantalla(
          lanzar: (c) => registrarAviso(c, 'Sin animación'),
          alPulsar: () {},
          sinMovimiento: true,
        ),
      );
      await tester.tap(find.byKey(const Key('lanzar')));
      // Un solo fotograma y ya está entero.
      await tester.pump();
      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byKey(const Key('aviso')).hitTestable().first,
          matching: find.byType(FadeTransition),
        ).first,
      );
      expect(fade.opacity.value, 1);
      await tester.tap(find.byKey(const Key('aviso')));
      await tester.pump();
      expect(find.byKey(const Key('aviso')), findsNothing);
    });

    for (final (nombre, tam) in [
      ('móvil', const Size(360, 640)),
      ('pantalla ancha', const Size(1280, 720)),
    ]) {
      testWidgets('se ve entero en $nombre', (tester) async {
        tester.view.physicalSize = tam;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _pantalla(
            lanzar: (c) => registrarAviso(
              c,
              'Un aviso bastante largo para comprobar que el texto se parte '
              'en varias líneas y no se sale por los lados de la pantalla.',
              tipo: TipoAviso.error,
            ),
            alPulsar: () {},
          ),
        );
        await _lanzar(tester);
        final caja = tester.getRect(find.byKey(const Key('aviso')));
        expect(caja.left, greaterThanOrEqualTo(0));
        expect(caja.right, lessThanOrEqualTo(tam.width));
        expect(caja.width, lessThanOrEqualTo(440));
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });
    }

    testWidgets('un aviso de error lleva su icono', (tester) async {
      await tester.pumpWidget(
        _pantalla(
          lanzar: (c) => registrarAviso(c, 'Rechazado', tipo: TipoAviso.error),
          alPulsar: () {},
        ),
      );
      await _lanzar(tester);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsNothing);
    });
  });
}
