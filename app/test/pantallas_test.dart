import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/partida/controlador_partida.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

/// Pantalla grande para que todo quepa sin tener que desplazar la lista.
Future<ProviderContainer> abrir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: IncursionesApp()));
  return ProviderScope.containerOf(tester.element(find.byType(IncursionesApp)));
}

Future<void> tocar(WidgetTester tester, String clave) async {
  await tester.tap(find.byKey(Key(clave)));
  await tester.pumpAndSettle();
}

Future<void> escribir(WidgetTester tester, String clave, String texto) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(Key(clave)),
      matching: find.byType(TextField),
    ),
    texto,
  );
}

/// Setup completo: dos jugadores con 100 de ataque (X = 200, nivel 1) y un
/// jefe con los HP indicados.
Future<void> prepararPartida(WidgetTester tester, {int hp = 100}) async {
  await escribir(tester, 'ataque-0', '100');
  await escribir(tester, 'ataque-1', '100');
  await tocar(tester, 'configurar');
  await escribir(tester, 'jefe-hp', '$hp');
  await tocar(tester, 'elegir-jefe');
}

Future<void> turno(WidgetTester tester, String dano) async {
  await escribir(tester, 'dano-turno', dano);
  await tocar(tester, 'registrar-turno');
}

void main() {
  testWidgets('el setup calcula X y el nivel, y luego se elige el jefe',
      (tester) async {
    final c = await abrir(tester);
    await escribir(tester, 'ataque-0', '100');
    await escribir(tester, 'ataque-1', '100');
    await tocar(tester, 'configurar');

    expect(find.text('Nivel 1 (X = 200)'), findsOneWidget);
    expect(c.read(estadoProvider).fase, Fase.eleccionJefe);

    await escribir(tester, 'jefe-nombre', 'Mewtwo');
    await escribir(tester, 'jefe-hp', '300');
    await tocar(tester, 'elegir-jefe');

    final estado = c.read(estadoProvider);
    expect(estado.fase, Fase.turnoJugadores);
    expect(estado.jefe!.nombre, 'Mewtwo');
    expect(estado.jefe!.hp, 300);
    expect(find.text('Turno de Jugador 1'), findsOneWidget);
  });

  testWidgets('se pueden añadir y quitar jugadores (de 1 a 4)', (tester) async {
    await abrir(tester);
    expect(find.byKey(const Key('nombre-2')), findsNothing);
    await tocar(tester, 'anadir-jugador');
    await tocar(tester, 'anadir-jugador');
    expect(find.byKey(const Key('nombre-3')), findsOneWidget);
    final anadir = tester.widget<OutlinedButton>(
      find.byKey(const Key('anadir-jugador')),
    );
    expect(anadir.onPressed, isNull);
    await tocar(tester, 'quitar-jugador');
    expect(find.byKey(const Key('nombre-3')), findsNothing);
  });

  testWidgets('el turno de los jugadores resta vida y pasa al jefe',
      (tester) async {
    final c = await abrir(tester);
    await prepararPartida(tester, hp: 500);

    await turno(tester, '60');
    expect(find.text('Turno de Jugador 2'), findsOneWidget);
    await turno(tester, '40');

    final estado = c.read(estadoProvider);
    expect(estado.fase, Fase.turnoJefe);
    expect(estado.jefe!.hp, 400);
    expect(find.byKey(const Key('turno-del-jefe')), findsOneWidget);
  });

  testWidgets('victoria: el fin de partida muestra los puntos', (tester) async {
    final c = await abrir(tester);
    await prepararPartida(tester, hp: 100);

    await turno(tester, '60');
    await turno(tester, '40');

    expect(c.read(estadoProvider).resultado, Resultado.victoria);
    expect(find.text('Victoria'), findsOneWidget);
    // Nivel 1: 3000 puntos para el equipo.
    expect(find.text('Puntos del equipo: 3000'), findsOneWidget);
    expect(find.byKey(const Key('puntos-0')), findsOneWidget);
    expect(find.byKey(const Key('puntos-1')), findsOneWidget);

    await tocar(tester, 'nueva-partida');
    expect(c.read(estadoProvider).fase, Fase.preparacion);
  });

  testWidgets('deshacer y rehacer funcionan desde la barra', (tester) async {
    final c = await abrir(tester);
    await prepararPartida(tester, hp: 500);
    await turno(tester, '60');
    expect(c.read(estadoProvider).jefe!.hp, 440);

    await tocar(tester, 'deshacer');
    expect(c.read(estadoProvider).jefe!.hp, 500);
    expect(find.text('Turno de Jugador 1'), findsOneWidget);

    await tocar(tester, 'rehacer');
    expect(c.read(estadoProvider).jefe!.hp, 440);
  });

  testWidgets('el turno del jefe registra un ataque y termina la ronda',
      (tester) async {
    final c = await abrir(tester);
    await prepararPartida(tester, hp: 500);
    await turno(tester, '0');
    await turno(tester, '0');

    await escribir(tester, 'dano-jefe', '80');
    await tocar(tester, 'objetivo-1');
    await tocar(tester, 'registrar-ataque-jefe');
    expect(c.read(estadoProvider).ataquesJefeEnTurno, 1);

    await tocar(tester, 'ko-0');
    expect(c.read(estadoProvider).jugadores[0].pokemonVivos, 1);

    await tocar(tester, 'fin-turno-jefe');
    final estado = c.read(estadoProvider);
    expect(estado.fase, Fase.turnoJugadores);
    expect(estado.ronda, 2);
    // El jugador con un Pokémon KO actúa primero y roba carta de ánimo.
    expect(estado.orden.first, 0);
    expect(find.text('Cartas de ánimo por robar'), findsOneWidget);

    await tocar(tester, 'animo-0-3');
    expect(c.read(estadoProvider).cartasAnimoPendientes, isEmpty);
    expect(c.read(estadoProvider).cartasAnimo.single.carta, 3);
  });

  testWidgets('la quemadura pide la moneda al terminar el turno del jefe',
      (tester) async {
    final c = await abrir(tester);
    await prepararPartida(tester, hp: 500);
    await tocar(tester, 'estado-quemadura');
    expect(c.read(estadoProvider).jefe!.quemado, isTrue);
    await turno(tester, '0');
    await turno(tester, '0');

    await tocar(tester, 'fin-turno-jefe');
    expect(find.text('Moneda de la quemadura'), findsOneWidget);
    await tocar(tester, 'moneda-cara');

    final estado = c.read(estadoProvider);
    expect(estado.jefe!.quemado, isFalse);
    expect(estado.jefe!.hp, 480);
    expect(estado.ronda, 2);
  });

  testWidgets('una regla incumplida se muestra y no cambia la partida',
      (tester) async {
    final c = await abrir(tester);
    await prepararPartida(tester, hp: 500);
    await turno(tester, '0');
    await turno(tester, '0');

    // Las cartas de ánimo solo se roban en el turno de los jugadores: el
    // controlador devuelve el motivo y la partida no cambia.
    final error = c
        .read(partidaProvider.notifier)
        .registrar(const CartaAnimoRobada(jugador: 0, carta: 1));
    expect(error, isNotNull);
    expect(c.read(estadoProvider).fase, Fase.turnoJefe);
  });

  testWidgets('invocar un aliado bloquea los turnos hasta resolverlo',
      (tester) async {
    final c = await abrir(tester);
    await escribir(tester, 'ataque-0', '100');
    await escribir(tester, 'ataque-1', '100');
    await tocar(tester, 'configurar');
    await escribir(tester, 'jefe-hp', '300');
    await escribir(tester, 'jefe-invocacion', '100');
    await tocar(tester, 'elegir-jefe');

    // 100 de daño cruza el primer umbral de invocación.
    await turno(tester, '100');
    expect(c.read(estadoProvider).intentosInvocacionPendientes, 1);

    await tocar(tester, 'invocar-aliado');
    await tester.enterText(find.byKey(const Key('aliado-nombre')), 'Pikachu');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('aliado-hp')),
        matching: find.byType(TextField),
      ),
      '50',
    );
    await tocar(tester, 'aliado-aceptar');

    final estado = c.read(estadoProvider);
    expect(estado.intentosInvocacionPendientes, 0);
    expect(estado.aliados.single.nombre, 'Pikachu');
    expect(estado.aliados.single.slot, 0);
    expect(find.text('Turno de Jugador 2'), findsOneWidget);
  });

  testWidgets('abandonar termina la partida en derrota', (tester) async {
    final c = await abrir(tester);
    await prepararPartida(tester, hp: 500);
    await tocar(tester, 'abandonar');
    await tocar(tester, 'abandonar-confirmar');

    expect(c.read(estadoProvider).resultado, Resultado.derrota);
    expect(find.text('Derrota'), findsOneWidget);
  });
}
