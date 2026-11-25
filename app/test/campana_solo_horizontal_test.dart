import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/almacen/almacen.dart';
import 'package:incursiones_app/campana/controlador_campana.dart';
import 'package:incursiones_app/campana/solo_horizontal.dart';
import 'package:incursiones_engine/campana.dart';

import 'ayudas.dart';
import 'campana_test.dart' show abrirCampana, hay, tocar;

/// La campaña solo en horizontal: aviso «Gira el móvil» (D-20 §10.7, #487).
void main() {
  const apaisado = Size(844, 390);
  const vertical = Size(390, 844);

  Future<void> girar(WidgetTester tester, Size tamano) async {
    tester.view.physicalSize = tamano;
    await tester.pumpAndSettle();
  }

  test('la regla es la relación de aspecto: más alto que ancho', () {
    expect(esVertical(vertical), isTrue);
    expect(esVertical(apaisado), isFalse);
    expect(esVertical(const Size(500, 500)), isFalse, reason: 'cuadrada');
    // Una ventana de PC muy estrecha pero aún apaisada no avisa.
    expect(esVertical(const Size(420, 400)), isFalse);
  });

  group('SoloHorizontal', () {
    Future<void> montar(WidgetTester tester, Size tamano) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SoloHorizontal(child: _Contador())),
      ));
    }

    testWidgets('en horizontal no sale el aviso y se juega', (tester) async {
      await montar(tester, apaisado);
      expect(hay('aviso-gira-el-movil'), isFalse);
      expect(find.text(textoGiraElMovil), findsNothing);
      await tester.tap(find.byKey(const Key('contador-sumar')));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('en vertical tapa la pantalla y no deja tocar debajo',
        (tester) async {
      await montar(tester, vertical);
      expect(hay('aviso-gira-el-movil'), isTrue);
      expect(find.text(textoGiraElMovil), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('aviso-gira-el-movil'))),
          vertical,
          reason: 'a pantalla completa');
      await tester.tap(find.byKey(const Key('contador-sumar')),
          warnIfMissed: false);
      await tester.pump();
      expect(find.text('0'), findsOneWidget, reason: 'no se juega debajo');
      expect(tester.takeException(), isNull);
    });

    testWidgets('al girar se quita el aviso y el estado sigue igual',
        (tester) async {
      await montar(tester, apaisado);
      await tester.tap(find.byKey(const Key('contador-sumar')));
      await tester.tap(find.byKey(const Key('contador-sumar')));
      await tester.pump();
      final antes = tester.state(find.byType(_Contador));
      expect(find.text('2'), findsOneWidget);

      await girar(tester, vertical);
      expect(hay('aviso-gira-el-movil'), isTrue);
      await girar(tester, apaisado);
      expect(hay('aviso-gira-el-movil'), isFalse);
      expect(find.text('2'), findsOneWidget);
      expect(identical(tester.state(find.byType(_Contador)), antes), isTrue,
          reason: 'el hijo no se desmonta');
    });
  });

  group('en la campaña', () {
    // Squirtle contra el Pidgey de la Ruta 1.
    const enRuta1 = PartidaCampana(
      progreso: ProgresoRuta(
          nodoActual: 'ruta-1-pidgey',
          superados: {'pueblo-paleta', 'ruta-1'},
          inicial: 'squirtle'),
      equipo: [PokemonGuardado('squirtle', 80)],
      dinero: 1000,
    );

    testWidgets('el mapa en vertical muestra el aviso; en horizontal, no',
        (tester) async {
      await abrirCampana(tester,
          almacen: AlmacenMemoria(), guardada: enRuta1, tamano: vertical);
      expect(hay('aviso-gira-el-movil'), isTrue);
      await girar(tester, apaisado);
      expect(hay('aviso-gira-el-movil'), isFalse);
      expect(hay('campana-mapa'), isTrue);
    });

    testWidgets('girar en pleno combate no pierde el combate', (tester) async {
      final c = await abrirCampana(tester,
          almacen: AlmacenMemoria(), guardada: enRuta1, tamano: apaisado);
      c.read(campanaProvider.notifier).combatir(catalogoCampanaDeDisco());
      await tester.pumpAndSettle();
      expect(hay('campana-combate'), isTrue);
      final combate = c.read(campanaProvider).combate;
      final partida = c.read(campanaProvider).partida;
      expect(combate, isNotNull);

      await girar(tester, vertical);
      expect(hay('aviso-gira-el-movil'), isTrue);
      await girar(tester, apaisado);
      expect(hay('aviso-gira-el-movil'), isFalse);
      expect(hay('campana-combate'), isTrue);
      expect(identical(c.read(campanaProvider).combate, combate), isTrue);
      expect(identical(c.read(campanaProvider).partida, partida), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la pantalla de equipo y sus hojas también avisan',
        (tester) async {
      await abrirCampana(tester,
          almacen: AlmacenMemoria(),
          guardada: const PartidaCampana(
            progreso: ProgresoRuta(
                nodoActual: 'ruta-2-norte',
                superados: {'pueblo-paleta'},
                inicial: 'squirtle'),
            equipo: [PokemonGuardado('squirtle', 30)],
            mochila: {ObjetoCampana.pocion: 1},
          ),
          tamano: apaisado);
      await tocar(tester, 'campana-ver-equipo');
      await tocar(tester, 'equipo-0');
      expect(hay('aviso-gira-el-movil'), isFalse);
      await girar(tester, vertical);
      // Tapa la pantalla de equipo y también la hoja abierta.
      expect(find.byKey(const Key('aviso-gira-el-movil')), findsNWidgets(2));
      await girar(tester, apaisado);
      expect(hay('aviso-gira-el-movil'), isFalse);
      expect(hay('pantalla-equipo'), isTrue);
      expect(hay('equipo-pocion'), isTrue, reason: 'la hoja sigue abierta');
      expect(tester.takeException(), isNull);
    });
  });
}

/// Un hijo con estado, para ver que no se desmonta.
class _Contador extends StatefulWidget {
  const _Contador();

  @override
  State<_Contador> createState() => _ContadorState();
}

class _ContadorState extends State<_Contador> {
  int _n = 0;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$_n'),
          TextButton(
            key: const Key('contador-sumar'),
            onPressed: () => setState(() => _n++),
            child: const Text('Sumar'),
          ),
        ]),
      );
}
