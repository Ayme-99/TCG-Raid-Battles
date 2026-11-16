import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/pantallas/lanzar_monedas.dart';
import 'package:incursiones_app/pantallas/moneda.dart';
import 'package:incursiones_app/partida/controlador_partida.dart';
import 'package:incursiones_app/partida/tirada_mesa.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import 'ayudas.dart';

/// Azar con las monedas ya decididas, en orden (true = cara).
class _Azar implements Random {
  _Azar(this.monedas);

  final List<bool> monedas;
  var _i = 0;

  /// Cuántas monedas se han sacado.
  int get sacadas => _i;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => monedas[_i++ % monedas.length];

  @override
  double nextDouble() => 0;
}

/// Una moneda de prueba: dos textos distintos en vez de dibujos.
final _diseno = DisenoMoneda(
  id: 'prueba',
  nombre: 'Prueba',
  canto: Colors.red,
  cara: (_) => const Center(child: Text('LADO-CARA')),
  cruz: (_) => const Center(child: Text('LADO-CRUZ')),
);

/// Una pantalla con un botón que lanza [cuantas] monedas y guarda el resultado.
Widget _lanzador(void Function(List<bool>) alTerminar, {int cuantas = 1}) {
  return MaterialApp(
    home: Consumer(
      builder: (context, ref, _) => Scaffold(
        body: TextButton(
          key: const Key('lanzar'),
          onPressed: () async => alTerminar(
            await lanzarMonedas(ref, cuantas: cuantas, leyenda: 'Prueba'),
          ),
          child: const Text('lanzar'),
        ),
      ),
    ),
  );
}

/// Como `pumpAndSettle`, pero si algo no deja de animarse falla a los 20 s de
/// tiempo de pantalla en vez de esperar diez minutos.
Future<void> _asentar(WidgetTester tester) => tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('la moneda', () {
    test('resume lo que salió', () {
      String r(List<bool> m) => TiradaMesa.monedas(m).resumen;
      expect(r([true]), 'CARA');
      expect(r([false]), 'CRUZ');
      expect(r([true, false]), '1 cara · 1 cruz');
      expect(r([true, true, true, false]), '3 caras · 1 cruz');
      expect(r([false, false]), '0 caras · 2 cruces');
      expect(TiradaMesa.sinAliado().monedas, [false]);
    });

    test('la tirada de monedas no se puede modificar', () {
      final t = TiradaMesa.monedas([true, false]);
      expect(() => t.monedas!.add(true), throwsUnsupportedError);
      expect(t.esMoneda, isTrue);
      expect(t.duracion, duracionMonedas);
    });

    testWidgets('el diseño decide cada lado; con π se ve la cruz',
        (tester) async {
      Future<void> poner(double angulo) => tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: MonedaWidget(diseno: _diseno, lado: 100, angulo: angulo),
              ),
            ),
          );
      await poner(0);
      expect(find.text('LADO-CARA'), findsOneWidget);
      expect(find.text('LADO-CRUZ'), findsNothing);
      await poner(pi);
      expect(find.text('LADO-CRUZ'), findsOneWidget);
      expect(find.text('LADO-CARA'), findsNothing);
      // Tres vueltas y media: también cruz. Dos vueltas: cara.
      await poner(7 * pi);
      expect(find.text('LADO-CRUZ'), findsOneWidget);
      await poner(4 * pi);
      expect(find.text('LADO-CARA'), findsOneWidget);
    });

    testWidgets('de canto se ve mucho más baja que de frente', (tester) async {
      final d = DisenoMoneda(
        id: 'medida',
        nombre: 'Medida',
        canto: Colors.red,
        cara: (_) => const SizedBox.expand(key: Key('lado')),
        cruz: (_) => const SizedBox.expand(key: Key('lado')),
      );
      Future<double> alto(double angulo) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: MonedaWidget(diseno: d, lado: 100, angulo: angulo),
            ),
          ),
        );
        final f = find.byKey(const Key('lado'));
        return (tester.getBottomRight(f).dy - tester.getTopLeft(f).dy).abs();
      }

      final frente = await alto(0);
      final canto = await alto(pi / 2);
      expect(frente, closeTo(100, 0.5));
      expect(canto, lessThan(frente * 0.2));
    });

    test('la moneda clásica está entre las disponibles', () {
      expect(disenosDeMoneda[monedaClasica.id], same(monedaClasica));
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(disenoMonedaProvider), same(monedaClasica));
    });

    testWidgets('una moneda de imágenes se crea con dos lados', (tester) async {
      final d = DisenoMoneda.deImagenes(
        id: 'tienda-1',
        nombre: 'De tienda',
        cara: const AssetImage('assets/monedas/tienda-1-cara.webp'),
        cruz: const AssetImage('assets/monedas/tienda-1-cruz.webp'),
      );
      expect(d.id, 'tienda-1');
      expect(d.cara(50), isA<Widget>());
      expect(d.cruz(50), isA<Widget>());
    });
  });

  group('lanzar monedas', () {
    testWidgets('saca el azar en orden y devuelve cada moneda', (tester) async {
      final azar = _Azar([true, false, true]);
      List<bool>? r;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [azarProvider.overrideWithValue(azar)],
          child: _lanzador((x) => r = x, cuantas: 3),
        ),
      );
      await tester.tap(find.byKey(const Key('lanzar')));
      await tester.pump();
      expect(azar.sacadas, 3);
      // Sin mesa que las anime, la tirada se da por terminada sola.
      expect(r, isNull);
      await tester.pump(duracionMonedas + const Duration(seconds: 2));
      expect(r, [true, false, true]);
    });

    testWidgets('mientras caen, hay una tirada en la mesa; al parar, ninguna',
        (tester) async {
      late ProviderContainer c;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [azarProvider.overrideWithValue(_Azar([false]))],
          child: Builder(
            builder: (context) {
              c = ProviderScope.containerOf(context);
              return _lanzador((_) {});
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('lanzar')));
      await tester.pump();
      final t = c.read(tiradaMesaProvider)!;
      expect(t.monedas, [false]);
      expect(t.leyenda, 'Prueba');
      await tester.pump(duracionMonedas + const Duration(seconds: 2));
      expect(c.read(tiradaMesaProvider), isNull);
    });

    testWidgets('dos lanzamientos seguidos no se pisan', (tester) async {
      final fin = <List<bool>>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [azarProvider.overrideWithValue(_Azar([true, false]))],
          child: _lanzador(fin.add),
        ),
      );
      await tester.tap(find.byKey(const Key('lanzar')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('lanzar')));
      await tester.pump();
      // La segunda espera a que acabe la primera.
      expect(fin, isEmpty);
      await tester.pump(duracionMonedas + const Duration(seconds: 2));
      expect(fin, [
        [true],
      ]);
      await tester.pump(duracionMonedas + const Duration(seconds: 2));
      expect(fin, [
        [true],
        [false],
      ]);
    });
  });

  group('preguntar la moneda de la mesa', () {
    for (final cara in [true, false]) {
      testWidgets('con Fijar Blanco la mesa dice ${cara ? 'cara' : 'cruz'}',
          (tester) async {
        bool? r;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    key: const Key('preguntar'),
                    onPressed: () async => r = await preguntarMoneda(
                      context,
                      titulo: 'Bote',
                      detalle: 'Ana lanza 1 moneda.',
                      recordatorios: const ['Fijar Blanco: la primera es cruz.'],
                    ),
                    child: const Text('preguntar'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('preguntar')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('pregunta-moneda')), findsOneWidget);
        expect(find.text('Fijar Blanco: la primera es cruz.'), findsOneWidget);
        await tester.tap(
          find.byKey(Key(cara ? 'pregunta-moneda-cara' : 'pregunta-moneda-cruz')),
        );
        await tester.pumpAndSettle();
        expect(r, cara);
        expect(find.byKey(const Key('pregunta-moneda')), findsNothing);
      });
    }
  });

  group('en la mesa', () {
    /// Dos jugadores y un jefe de 500 HP, ya en juego.
    Future<ProviderContainer> abrirMesa(
      WidgetTester tester, {
      Random? azar,
      DisenoMoneda? diseno,
    }) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...sobrescribir(),
            if (azar != null) azarProvider.overrideWithValue(azar),
            if (diseno != null)
              disenoMonedaProvider.overrideWith((ref) => diseno),
          ],
          child: const IncursionesApp(),
        ),
      );
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(
        tester.element(find.byType(IncursionesApp)),
      );
      final p = c.read(partidaProvider.notifier);
      expect(
        p.registrar(const ConfigurarJugadores([
          ConfigJugador(nombre: 'Ana', ataqueMaximo: 100),
          ConfigJugador(nombre: 'Beto', ataqueMaximo: 100),
        ])),
        isNull,
      );
      expect(
        p.registrar(const ElegirJefe(nombre: 'Jefe', nivel: 1, hp: 500)),
        isNull,
      );
      await tester.pumpAndSettle();
      return c;
    }

    for (final lugar in LugarMoneda.values) {
      testWidgets('las monedas caen ${lugar.name} y enseñan el resultado',
          (tester) async {
        final c = await abrirMesa(tester);
        final resultados = [true, false, true, true, false, false, true];
        c.read(tiradaMesaProvider.notifier).state = TiradaMesa.monedas(
          resultados,
          lugar: lugar,
          asiento: 1,
          leyenda: 'Prueba',
        );
        await tester.pump();
        // Al principio todavía no se sabe lo que sale.
        expect(find.byKey(const Key('moneda-resultado')), findsNothing);
        await tester.pump(const Duration(milliseconds: 900));
        for (var i = 0; i < resultados.length; i++) {
          expect(find.byKey(ValueKey('moneda-mesa-$i')), findsOneWidget);
        }
        await tester.pumpAndSettle();
        expect(find.text('4 caras · 3 cruces'), findsOneWidget);
        expect(find.text('Prueba'), findsOneWidget);
      });
    }

    testWidgets('la moneda de la mesa usa el diseño elegido', (tester) async {
      final c = await abrirMesa(tester, diseno: _diseno);
      c.read(tiradaMesaProvider.notifier).state =
          TiradaMesa.monedas([true], lugar: LugarMoneda.jefe);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data == 'LADO-CARA' || w.data == 'LADO-CRUZ'),
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(find.text('LADO-CARA'), findsOneWidget);
      expect(find.text('CARA'), findsOneWidget);
    });

    testWidgets('una moneda que sale cruz se queda con la cruz hacia arriba',
        (tester) async {
      final c = await abrirMesa(tester, diseno: _diseno);
      c.read(tiradaMesaProvider.notifier).state =
          TiradaMesa.monedas([false], lugar: LugarMoneda.aliados);
      await tester.pumpAndSettle();
      expect(find.text('LADO-CRUZ'), findsOneWidget);
      expect(find.text('CRUZ'), findsOneWidget);
    });

    testWidgets('la quemadura del jefe la lanza la app y cae en la mesa',
        (tester) async {
      // Cara: la quemadura se quita.
      final azar = _Azar([true]);
      final c = await abrirMesa(tester, azar: azar);
      final p = c.read(partidaProvider.notifier);
      for (final e in const <Evento>[
        AplicarEstadoJefe(jugador: 0, estado: EstadoDelJefe.quemadura),
        TurnoJugador(jugador: 0, dano: 0),
        TurnoJugador(jugador: 1, dano: 0),
        AtaqueJefe(ranura: 1, dano: 0),
      ]) {
        expect(p.registrar(e), isNull, reason: '$e');
      }
      await tester.pumpAndSettle();
      expect(c.read(estadoProvider).jefe!.quemado, isTrue);

      await tester.tap(find.byKey(const Key('fin-turno-jefe')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      // Ya cae la moneda; hasta que pare no se registra nada.
      expect(find.byKey(const ValueKey('moneda-mesa-0')), findsOneWidget);
      expect(c.read(estadoProvider).jefe!.quemado, isTrue);
      expect(azar.sacadas, 1);
      // Con la tirada en marcha, otro toque no lanza otra moneda.
      await tester.tap(find.byKey(const Key('fin-turno-jefe')), warnIfMissed: false);
      await tester.pump();
      expect(azar.sacadas, 1);

      await tester.pumpAndSettle();
      final estado = c.read(estadoProvider);
      expect(estado.jefe!.quemado, isFalse);
      expect(estado.ronda, 2);
      expect(azar.sacadas, 1);
      expect(c.read(tiradaMesaProvider), isNull);
    });

    testWidgets('con cruz la quemadura sigue y el resultado queda registrado',
        (tester) async {
      final c = await abrirMesa(tester, azar: _Azar([false]));
      final p = c.read(partidaProvider.notifier);
      for (final e in const <Evento>[
        AplicarEstadoJefe(jugador: 0, estado: EstadoDelJefe.quemadura),
        TurnoJugador(jugador: 0, dano: 0),
        TurnoJugador(jugador: 1, dano: 0),
        AtaqueJefe(ranura: 1, dano: 0),
      ]) {
        expect(p.registrar(e), isNull, reason: '$e');
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fin-turno-jefe')));
      await tester.pumpAndSettle();
      expect(c.read(estadoProvider).jefe!.quemado, isTrue);
      // El registro lleva la moneda: reproducirlo da lo mismo.
      final fin = c
          .read(partidaProvider)
          .partida
          .eventos
          .whereType<FinTurnoJefe>()
          .last;
      expect(fin.monedaQuemadura, isFalse);
    });
  });
}
