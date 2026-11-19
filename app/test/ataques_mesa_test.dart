import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/partida/ataque_mesa.dart';
import 'package:incursiones_app/partida/controlador_partida.dart';
import 'package:incursiones_app/partida/tirada_mesa.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import 'ayudas.dart';

/// Partida de dos jugadores que ya está en el turno del jefe.
Future<ProviderContainer> enTurnoDelJefe(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: sobrescribir(), child: const IncursionesApp()),
  );
  await tester.pumpAndSettle();
  final c =
      ProviderScope.containerOf(tester.element(find.byType(IncursionesApp)));
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('ataque-0')),
      matching: find.byType(TextField),
    ),
    '100',
  );
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('ataque-1')),
      matching: find.byType(TextField),
    ),
    '100',
  );
  await tester.tap(find.byKey(const Key('configurar')));
  await tester.pumpAndSettle();
  await elegirJefeDePrueba(tester, hp: 1000);
  final n = c.read(partidaProvider.notifier);
  expect(n.registrar(const TurnoJugador(jugador: 0, dano: 10)), isNull);
  expect(n.registrar(const TurnoJugador(jugador: 1, dano: 10)), isNull);
  await tester.pumpAndSettle();
  expect(c.read(estadoProvider).fase, Fase.turnoJefe);
  return c;
}

void main() {
  testWidgets('el ataque del jefe se anima en la mesa y se retira solo',
      (tester) async {
    final c = await enTurnoDelJefe(tester);
    expect(find.byKey(const Key('ataque-mesa')), findsNothing);

    c.read(partidaProvider.notifier).registrar(
          const AtaqueJefe(ranura: 1, dano: 30, jugador: 0),
        );
    final cola = c.read(colaAtaquesMesaProvider);
    expect(cola, hasLength(1));
    expect(cola.single.origen, puntoJefe);
    expect(cola.single.destinos, [puntoJugador(0)]);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const Key('ataque-mesa')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ataque-mesa')), findsNothing);
    expect(c.read(colaAtaquesMesaProvider), isEmpty);
  });

  testWidgets('varios ataques seguidos se enseñan uno detrás de otro',
      (tester) async {
    final c = await enTurnoDelJefe(tester);
    final n = c.read(partidaProvider.notifier);
    n.registrar(const AtaqueJefe(ranura: 1, dano: 30, jugador: 0));
    n.registrar(const AtaqueJefe(ranura: 2, dano: 60, jugador: 1));
    expect(c.read(colaAtaquesMesaProvider), hasLength(2));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2700));
    expect(c.read(colaAtaquesMesaProvider), hasLength(1));

    await tester.pumpAndSettle();
    expect(c.read(colaAtaquesMesaProvider), isEmpty);
  });

  testWidgets('mientras dura el ataque el panel de acciones se aparta',
      (tester) async {
    final c = await enTurnoDelJefe(tester);
    Opacity? panel() => tester
        .widgetList<AnimatedOpacity>(find.ancestor(
          of: find.text('Acciones'),
          matching: find.byType(AnimatedOpacity),
        ))
        .map((o) => Opacity(opacity: o.opacity))
        .firstOrNull;
    expect(panel()?.opacity, 1);

    c.read(partidaProvider.notifier).registrar(
          const AtaqueJefe(ranura: 1, dano: 30, jugador: 0),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(panel()?.opacity, 0);
    final bloqueo = tester.widget<IgnorePointer>(find
        .ancestor(
          of: find.text('Acciones'),
          matching: find.byType(IgnorePointer),
        )
        .first);
    expect(bloqueo.ignoring, isTrue);

    await tester.pumpAndSettle();
    expect(panel()?.opacity, 1);
  });

  testWidgets('tampoco está el panel mientras ruedan los dados o las monedas',
      (tester) async {
    final c = await enTurnoDelJefe(tester);
    double opacidad() => tester
        .widget<AnimatedOpacity>(find
            .ancestor(
              of: find.text('Acciones'),
              matching: find.byType(AnimatedOpacity),
            )
            .first)
        .opacity;
    expect(opacidad(), 1);

    c.read(tiradaMesaProvider.notifier).state = TiradaMesa.monedas([true]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(opacidad(), 0);

    c.read(tiradaMesaProvider.notifier).state = null;
    await tester.pumpAndSettle();
    expect(opacidad(), 1);
  });

  testWidgets('la cámara mira a quien ataca y luego al objetivo', (tester) async {
    final c = await enTurnoDelJefe(tester);
    expect(c.read(enfoqueAtaqueProvider), isNull);

    c.read(partidaProvider.notifier).registrar(
          const AtaqueJefe(ranura: 1, dano: 30, jugador: 1),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.read(enfoqueAtaqueProvider), puntoJefe);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(c.read(enfoqueAtaqueProvider), puntoJugador(1));

    await tester.pumpAndSettle();
    expect(c.read(enfoqueAtaqueProvider), isNull);
  });

  testWidgets('qué ataque sale de cada evento', (tester) async {
    final c = await enTurnoDelJefe(tester);
    final estado = c.read(estadoProvider);

    // Un ataque a todos va a cada jugador que sigue en pie.
    final atodos = ataqueDe(estado, const AtaqueJefe(ranura: 1, dano: 20))!;
    expect(atodos.destinos, [puntoJugador(0), puntoJugador(1)]);

    final aliado =
        ataqueDe(estado, const AtaqueAliado(slot: 1, dano: 40, objetivo: 0))!;
    expect(aliado.origen, puntoAliado(1));
    expect(aliado.destinos, [puntoJugador(0)]);
    expect(aliado.atacante, 'aliado');

    // Sin objetivo el aliado ataca al dueño de su slot.
    final aDueno = ataqueDe(estado, const AtaqueAliado(slot: 1, dano: 40))!;
    expect(aDueno.destinos, [puntoJugador(1)]);

    final aAliado =
        ataqueDe(estado, const AtaqueAAliado(jugador: 0, slot: 1, dano: 20))!;
    expect(aAliado.origen, puntoJugador(0));
    expect(aAliado.destinos, [puntoAliado(1)]);

    // El turno de un jugador que daña al jefe también se anima.
    final alJefe = ataqueDe(estado, const TurnoJugador(jugador: 0, dano: 50))!;
    expect(alJefe.origen, puntoJugador(0));
    expect(alJefe.destinos, [puntoJefe]);
    expect(alJefe.atacante, 'jugador');
    expect(ataqueDe(estado, const TurnoJugador(jugador: 0, dano: 0)), isNull);

    // Lo que no es un ataque no se anima.
    expect(ataqueDe(estado, const CuracionJefe(10)), isNull);
  });
}
