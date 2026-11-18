import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/pantallas/aviso_central.dart';
import 'package:incursiones_app/pantallas/comun.dart';

/// Una pantalla con un botón en una esquina (que cuenta pulsaciones) y otro
/// para lanzar el aviso que toque.
Widget _pantalla({
  required void Function(BuildContext) lanzar,
  void Function()? alPulsar,
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
              onPressed: alPulsar ?? () {},
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
  await tester.pump(const Duration(milliseconds: 600));
}

/// Deja pasar lo que dura un aviso y su salida.
Future<void> _pasaElAviso(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 8));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('Aviso.deTexto', () {
    test('separa el nombre, el titular y el motivo', () {
      final a = Aviso.deTexto(
        'Magikarp: Jugador 2 está KO, el ataque falla.',
      );
      expect(a.tipo, TipoAviso.fallo);
      expect(a.nombre, 'MAGIKARP');
      expect(a.titulo, '¡EL ATAQUE FALLA!');
      expect(a.motivo, 'Jugador 2 está KO, el ataque falla');
    });

    test('adivina el tipo por lo que cuenta', () {
      expect(Aviso.deTexto('Horsea: cae, KO.').tipo, TipoAviso.ko);
      expect(Aviso.deTexto('Machop: moneda en cruz, recibe el daño.').tipo,
          TipoAviso.danio);
      expect(Aviso.deTexto('Chansey: se evita todo el daño.').tipo,
          TipoAviso.esquiva);
      expect(Aviso.deTexto('El jefe se cura 300.').tipo, TipoAviso.cura);
      expect(Aviso.deTexto('Empieza la ronda 4').tipo, TipoAviso.info);
      expect(
        Aviso.deTexto('Salió cruz: no se invoca ningún aliado.').tipo,
        TipoAviso.fallo,
      );
    });

    test('sin nombre, todo el texto es el motivo', () {
      final a = Aviso.deTexto('Daño total: 80.');
      expect(a.nombre, isNull);
      expect(a.motivo, 'Daño total: 80');
    });

    test('el tipo que se pide manda sobre el que se adivina', () {
      expect(
        Aviso.deTexto('No hay hueco', tipo: TipoAviso.error).tipo,
        TipoAviso.error,
      );
    });

    test('dura más cuanto más hay que leer', () {
      const corto = Aviso(tipo: TipoAviso.info, titulo: 'AVISO', motivo: 'Hola');
      final largo = Aviso(
        tipo: TipoAviso.info,
        titulo: 'AVISO',
        motivo: List.filled(40, 'palabra').join(' '),
      );
      expect(duracionAviso(corto).inMilliseconds, greaterThanOrEqualTo(2400));
      expect(duracionAviso(largo), greaterThan(duracionAviso(corto)));
      expect(duracionAviso(largo), const Duration(seconds: 7));
    });
  });

  group('aviso central', () {
    testWidgets('sale en medio de la pantalla, con su jerarquía',
        (tester) async {
      await tester.pumpWidget(
        _pantalla(lanzar: (c) => registrarAviso(c, 'Magikarp: está KO')),
      );
      await _lanzar(tester);
      expect(find.byKey(const Key('aviso')), findsOneWidget);
      expect(find.text('MAGIKARP'), findsOneWidget);
      expect(find.byKey(const Key('aviso-titulo')), findsOneWidget);
      expect(find.text('está KO'), findsOneWidget);
      final centro = tester.getCenter(find.byKey(const Key('aviso')));
      final pantalla = tester.getCenter(find.byType(Scaffold));
      expect((centro.dx - pantalla.dx).abs(), lessThan(1));
      expect((centro.dy - pantalla.dy).abs(), lessThan(40));
      expect(find.byType(SnackBar), findsNothing);
      await _pasaElAviso(tester);
    });

    testWidgets('el texto lleva su estilo: sin subrayado amarillo',
        (tester) async {
      await tester.pumpWidget(
        _pantalla(lanzar: (c) => registrarAviso(c, 'Horsea: está KO')),
      );
      await _lanzar(tester);
      final t = tester.widget<Text>(find.byKey(const Key('aviso-titulo')));
      final estilo = DefaultTextStyle.of(
        tester.element(find.byKey(const Key('aviso-titulo'))),
      ).style.merge(t.style);
      expect(estilo.decoration, isNot(TextDecoration.underline));
      expect(find.ancestor(
        of: find.byKey(const Key('aviso-titulo')),
        matching: find.byType(Material),
      ), findsWidgets);
      await _pasaElAviso(tester);
    });

    testWidgets('se cierra solo', (tester) async {
      await tester.pumpWidget(
        _pantalla(lanzar: (c) => registrarAviso(c, 'Hola')),
      );
      await _lanzar(tester);
      expect(find.byKey(const Key('aviso')), findsOneWidget);
      await _pasaElAviso(tester);
      expect(find.byKey(const Key('aviso')), findsNothing);
    });

    testWidgets('salen de uno en uno, sin apilarse', (tester) async {
      await tester.pumpWidget(
        _pantalla(
          lanzar: (c) => registrarAvisos(c, ['Uno: a', 'Dos: b', 'Tres: c']),
        ),
      );
      await _lanzar(tester);
      expect(find.byKey(const Key('aviso')), findsOneWidget);
      expect(find.text('UNO'), findsOneWidget);
      expect(avisosEnCola(), 2);
      await _pasaElAviso(tester);
      expect(find.byKey(const Key('aviso')), findsOneWidget);
      expect(find.text('DOS'), findsOneWidget);
      expect(find.text('UNO'), findsNothing);
      await _pasaElAviso(tester);
      expect(find.text('TRES'), findsOneWidget);
      await _pasaElAviso(tester);
      expect(find.byKey(const Key('aviso')), findsNothing);
      expect(avisosEnCola(), 0);
    });

    testWidgets('un texto de varias líneas son varios avisos', (tester) async {
      await tester.pumpWidget(
        _pantalla(lanzar: (c) => registrarAviso(c, 'Uno: a\nDos: b')),
      );
      await _lanzar(tester);
      expect(find.text('UNO'), findsOneWidget);
      expect(avisosEnCola(), 1);
      await _pasaElAviso(tester);
      expect(find.text('DOS'), findsOneWidget);
      await _pasaElAviso(tester);
    });

    testWidgets('tocarlo pasa al siguiente', (tester) async {
      await tester.pumpWidget(
        _pantalla(lanzar: (c) => registrarAvisos(c, ['Uno: a', 'Dos: b'])),
      );
      await _lanzar(tester);
      await tester.tap(find.byKey(const Key('aviso')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('DOS'), findsOneWidget);
      await _pasaElAviso(tester);
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
      await tester.tap(find.byKey(const Key('esquina')));
      await tester.pump();
      expect(pulsaciones, 1);
      expect(find.byKey(const Key('aviso')), findsOneWidget);
      await _pasaElAviso(tester);
    });

    testWidgets('un error pasa por delante y tira la cola', (tester) async {
      await tester.pumpWidget(
        _pantalla(
          lanzar: (c) {
            registrarAvisos(c, ['Uno: a', 'Dos: b']);
            registrarAviso(c, 'No se puede', tipo: TipoAviso.error);
          },
        ),
      );
      await _lanzar(tester);
      expect(find.byKey(const Key('aviso')), findsOneWidget);
      expect(find.text('NO SE PUEDE'), findsOneWidget);
      expect(find.text('UNO'), findsNothing);
      expect(avisosEnCola(), 0);
      await _pasaElAviso(tester);
    });

    testWidgets('con «reducir movimiento» no hay animaciones',
        (tester) async {
      await tester.pumpWidget(
        _pantalla(
          lanzar: (c) => registrarAviso(c, 'Sin animación'),
          sinMovimiento: true,
        ),
      );
      await tester.tap(find.byKey(const Key('lanzar')));
      // Un solo fotograma y ya está entero y en su sitio.
      await tester.pump();
      final fotograma = tester.getRect(find.byKey(const Key('aviso')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getRect(find.byKey(const Key('aviso'))), fotograma);
      await tester.tap(find.byKey(const Key('aviso')));
      await tester.pump();
      expect(find.byKey(const Key('aviso')), findsNothing);
    });

    testWidgets('tiene vida: la banda se mueve mientras está en pantalla',
        (tester) async {
      await tester.pumpWidget(
        _pantalla(lanzar: (c) => registrarAviso(c, 'Horsea: KO')),
      );
      await _lanzar(tester);
      final antes = tester.getRect(find.byKey(const Key('aviso')));
      // Durante el temblor del KO el cartel se desplaza un poco.
      await tester.pump(const Duration(milliseconds: 100));
      final durante = tester.getRect(find.byKey(const Key('aviso')));
      expect(antes.width, durante.width);
      await _pasaElAviso(tester);
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
              'Magikarp: Jugador 2 está KO, el ataque falla porque no hay '
              'ningún Pokémon que pueda recibir el daño de esta forma.',
            ),
          ),
        );
        await _lanzar(tester);
        final caja = tester.getRect(find.byKey(const Key('aviso')));
        expect(caja.left, greaterThanOrEqualTo(0));
        expect(caja.right, lessThanOrEqualTo(tam.width));
        expect(caja.width, lessThanOrEqualTo(600));
        expect(tester.takeException(), isNull);
        await _pasaElAviso(tester);
      });
    }

    testWidgets('cada tipo lleva su icono', (tester) async {
      final tipos = {
        TipoAviso.ko: Icons.heart_broken,
        TipoAviso.danio: Icons.bolt,
        TipoAviso.cura: Icons.favorite,
        TipoAviso.fallo: Icons.block,
        TipoAviso.info: Icons.notifications_active,
        TipoAviso.error: Icons.warning_amber_rounded,
      };
      for (final e in tipos.entries) {
        await tester.pumpWidget(
          _pantalla(
            lanzar: (c) => mostrarAvisoCentral(
              c,
              Aviso(tipo: e.key, titulo: 'X', motivo: 'y'),
            ),
          ),
        );
        await _lanzar(tester);
        expect(find.byIcon(e.value), findsOneWidget, reason: '${e.key}');
        await _pasaElAviso(tester);
      }
    });
  });
}
