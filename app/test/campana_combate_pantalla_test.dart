import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/almacen/almacen.dart';
import 'package:incursiones_app/campana/controlador_campana.dart';
import 'package:incursiones_app/campana/pantalla_combate.dart';
import 'package:incursiones_engine/campana.dart';

import 'ayudas.dart';
import 'campana_test.dart' show abrirCampana, activo, hay, tocar;

/// Pantalla de combate de la campaña (D-20 §10.7, propuesta I; #373).
void main() {
  // Squirtle y Charmander contra el Pidgey de la Ruta 1 (combate tutorial).
  const enRuta1 = PartidaCampana(
    progreso: ProgresoRuta(
        nodoActual: 'ruta-1-pidgey',
        superados: {'pueblo-paleta', 'ruta-1'},
        inicial: 'squirtle'),
    equipo: [
      PokemonGuardado('squirtle', 80),
      PokemonGuardado('charmander', 70),
      PokemonGuardado('rattata', 0),
    ],
    dinero: 1000,
  );

  Future<void> empezar(WidgetTester tester, PartidaCampana p,
      {Size tamano = const Size(1280, 800)}) async {
    final c = await abrirCampana(tester,
        almacen: AlmacenMemoria(), guardada: p, tamano: tamano);
    c.read(campanaProvider.notifier).combatir(catalogoCampanaDeDisco());
    await tester.pumpAndSettle();
  }

  testWidgets('la mesa tiene las cuatro zonas, la energía y la última jugada',
      (tester) async {
    await empezar(tester, enRuta1);
    for (final k in [
      'combate-tapete',
      'banca-rival',
      'activo-rival',
      'activo-jugador',
      'banca-jugador',
      'combate-ultima',
      'energia-jugador',
      'energia-rival',
    ]) {
      expect(hay(k), isTrue, reason: k);
    }
    // 10 fichas de energía por bando.
    expect(
        find.descendant(
            of: find.byKey(const Key('energia-jugador')),
            matching: find.byType(Image)),
        findsNWidgets(10));
    // En la banca, el caído no se puede elegir.
    final caido =
        tester.widget<InkWell>(find.byKey(const Key('banca-jugador-2')));
    expect(caido.onTap, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tocar al activo abre la hoja de ataques y cargar',
      (tester) async {
    await empezar(tester, enRuta1);
    // Combate tutorial: el primer toque va señalado.
    expect(hay('combate-tutorial'), isTrue);
    await tocar(tester, 'activo-jugador');
    expect(hay('hoja-acciones'), isTrue);
    expect(hay('ataque-0'), isTrue);
    expect(hay('accion-cargar'), isTrue);
    await tocar(tester, 'accion-cargar');
    expect(hay('hoja-acciones'), isFalse);
    expect(hay('combate-tutorial'), isFalse, reason: 'ya ha tocado');
    expect(find.byKey(const Key('combate-ultima')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tocar a uno de la banca pide confirmación y cambia',
      (tester) async {
    await empezar(tester, enRuta1);
    await tocar(tester, 'banca-jugador-1');
    expect(find.textContaining('gasta el turno'), findsOneWidget);
    await tocar(tester, 'confirmar-cambio');
    // Ahora el activo es Charmander y Squirtle pasa a la banca.
    expect(
        find.descendant(
            of: find.byKey(const Key('activo-jugador')),
            matching: find.text('Charmander')),
        findsOneWidget);
    expect(hay('banca-jugador-0'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fuera del tutorial no hay destello', (tester) async {
    const enRuta2 = PartidaCampana(
      progreso: ProgresoRuta(nodoActual: 'ruta-2-weedle', inicial: 'squirtle'),
      equipo: [PokemonGuardado('squirtle', 80)],
    );
    await empezar(tester, enRuta2);
    expect(hay('combate-tutorial'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la Poción cura sin gastar turno (#458)', (tester) async {
    const herido = PartidaCampana(
      progreso: ProgresoRuta(
          nodoActual: 'ruta-1-pidgey',
          superados: {'pueblo-paleta', 'ruta-1'},
          inicial: 'squirtle'),
      equipo: [
        PokemonGuardado('squirtle', 40),
        PokemonGuardado('charmander', 70),
      ],
      dinero: 1000,
      mochila: {ObjetoCampana.pocion: 2},
    );
    await empezar(tester, herido);
    final turno = find.text('Combate · turno 1');
    expect(turno, findsOneWidget);
    await tocar(tester, 'activo-jugador');
    expect(activo(tester, 'accion-pocion'), isTrue);
    // Solo Squirtle está herido: se cura directamente.
    await tocar(tester, 'accion-pocion');
    expect(
        tester.widget<Text>(find.byKey(const Key('ps-activo-jugador'))).data,
        '60 / 80 PS');
    expect(turno, findsOneWidget, reason: 'no gasta turno');
    await tocar(tester, 'activo-jugador');
    expect(find.textContaining('quedan 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('con varios heridos se elige a quién curar, también en la banca',
      (tester) async {
    const heridos = PartidaCampana(
      progreso: ProgresoRuta(
          nodoActual: 'ruta-1-pidgey',
          superados: {'pueblo-paleta', 'ruta-1'},
          inicial: 'squirtle'),
      equipo: [
        PokemonGuardado('squirtle', 40),
        PokemonGuardado('charmander', 30),
      ],
      dinero: 1000,
      mochila: {ObjetoCampana.pocion: 1},
    );
    await empezar(tester, heridos);
    await tocar(tester, 'activo-jugador');
    await tocar(tester, 'accion-pocion');
    expect(hay('hoja-pocion'), isTrue);
    await tocar(tester, 'pocion-1');
    expect(hay('hoja-pocion'), isFalse);
    await tocar(tester, 'activo-jugador');
    expect(activo(tester, 'accion-pocion'), isFalse, reason: 'no quedan');
    expect(find.text('Poción: no te quedan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin Pociones el botón está apagado', (tester) async {
    await empezar(tester, enRuta1);
    await tocar(tester, 'activo-jugador');
    expect(hay('accion-pocion'), isTrue);
    expect(activo(tester, 'accion-pocion'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cabe en un móvil', (tester) async {
    await empezar(tester, enRuta1, tamano: const Size(390, 844));
    await tocar(tester, 'activo-jugador');
    expect(hay('ataque-0'), isTrue);
    expect(tester.takeException(), isNull);
  });

  test('los combates del tutorial son los de la Ruta 1 y el de Pikachu', () {
    final c = catalogoCampanaDeDisco();
    final tutoriales = [
      for (final n in c.region.nodos.values)
        if (esCombateTutorial(n)) n.id,
    ];
    expect(tutoriales, containsAll(['ruta-1-pidgey', 'ruta-1-rattata']));
    expect(tutoriales.where((id) => c.region.nodo(id).tipo == TipoNodo.jefe),
        isNotEmpty);
    expect(tutoriales, isNot(contains('gimnasio-brock')));
  });
}
