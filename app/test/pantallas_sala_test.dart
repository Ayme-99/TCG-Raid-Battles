import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/partida/controlador_partida.dart';
import 'package:incursiones_app/sala/controlador_sala.dart';

import 'ayudas.dart';

Future<(ProviderContainer, List<CanalFalso>)> abrirInicio(
  WidgetTester tester, {
  bool conSesion = true,
}) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final canales = <CanalFalso>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...sobrescribir(
          almacen: conSesion ? almacenConSesion() : null,
          servidor: (p) async => http.Response('{"codigo":"K7M2Q"}', 201),
          conInicio: true,
        ),
        fabricaCanalProvider.overrideWithValue((url) {
          final canal = CanalFalso();
          canales.add(canal);
          return canal;
        }),
        urlSalaProvider.overrideWithValue(Uri.parse('ws://prueba/ws')),
        generadorIdProvider.overrideWithValue(() => 'partida-1'),
        relojProvider.overrideWithValue(() => DateTime.utc(2026, 11, 18, 22)),
      ],
      child: const IncursionesApp(),
    ),
  );
  await tester.pumpAndSettle();
  final c = ProviderScope.containerOf(tester.element(find.byType(IncursionesApp)));
  return (c, canales);
}

/// Unos fotogramas: la sala conectando lleva una barra que no termina.
Future<void> avanzar(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('crear sala enseña el código y deja empezar con 2 jugadores',
      (tester) async {
    final (c, canales) = await abrirInicio(tester);
    await tester.tap(find.byKey(const Key('inicio-sala')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sala-crear')));
    await avanzar(tester); // la barra «conectando» no deja asentar
    expect(canales.single.enviados.single['codigo'], 'K7M2Q');

    canales.single.recibir(mensajeSala(estado: 'abierta', jugadores: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sala')), findsOneWidget);
    expect(find.text('K7M2Q'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('sala-empezar'))).onPressed,
      isNull,
    );
    expect(find.byKey(const Key('sala-faltan')), findsOneWidget);

    canales.single.recibir(mensajeSala(estado: 'abierta', jugadores: 2));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('sala-empezar'))).onPressed,
      isNotNull,
    );
    expect(find.byKey(const Key('echar-1')), findsOneWidget);
    expect(c.read(salaProvider).codigo, 'K7M2Q');
  });

  testWidgets('sin sesión no se puede unir a una sala', (tester) async {
    await abrirInicio(tester, conSesion: false);
    await tester.tap(find.byKey(const Key('inicio-sala')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sala-unirse')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Inicia sesión para jugar en una sala'), findsOneWidget);
    expect(find.byKey(const Key('unirse')), findsNothing);
  });

  testWidgets('unirse valida el código y pasa a la sala de espera', (tester) async {
    final (_, canales) = await abrirInicio(tester);
    await tester.tap(find.byKey(const Key('inicio-sala')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sala-unirse')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('unirse-codigo')), 'ab');
    await tester.tap(find.byKey(const Key('unirse-entrar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unirse-error')), findsOneWidget);
    expect(canales, isEmpty);

    await tester.enterText(find.byKey(const Key('unirse-codigo')), 'k7m2q');
    await tester.tap(find.byKey(const Key('unirse-entrar')));
    await tester.pumpAndSettle();
    expect(canales.single.enviados.single['codigo'], 'K7M2Q');

    canales.single.recibir(mensajeSala(estado: 'abierta', tuAsiento: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unirse')), findsNothing);
    expect(find.byKey(const Key('sala-esperando')), findsOneWidget);
    expect(find.byKey(const Key('sala-empezar')), findsNothing);
  });

  testWidgets('el jugador ve la cuenta atrás de quien se cae', (tester) async {
    final (_, canales) = await abrirInicio(tester);
    await tester.tap(find.byKey(const Key('inicio-sala')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sala-crear')));
    await avanzar(tester); // la barra «conectando» no deja asentar
    canales.single.recibir(mensajeSala(estado: 'abierta'));
    await tester.pumpAndSettle();
    canales.single.recibir({
      'tipo': 'jugadorDesconectado',
      'asiento': 1,
      'venceEn': '2026-11-18T22:02:00.000Z',
    });
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('aviso-desconexion')), findsOneWidget);
    expect(find.textContaining('2:00'), findsOneWidget);
    // Quita el temporizador antes de cerrar el test.
    canales.single.recibir({'tipo': 'jugadorVuelve', 'asiento': 1});
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('aviso-desconexion')), findsNothing);
  });

  testWidgets('partida cancelada enseña el aviso y vuelve al inicio',
      (tester) async {
    final (_, canales) = await abrirInicio(tester);
    await tester.tap(find.byKey(const Key('inicio-sala')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sala-crear')));
    await avanzar(tester); // la barra «conectando» no deja asentar
    canales.single.recibir(mensajeSala());
    await tester.pumpAndSettle();
    canales.single.recibir({'tipo': 'partidaCancelada', 'motivo': 'hostDesconectado'});
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sala-cancelada')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sala-cancelada-volver')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inicio-nueva')), findsOneWidget);
  });

  testWidgets('en una sala no hay deshacer y el jugador espera al host',
      (tester) async {
    final (c, canales) = await abrirInicio(tester);
    await tester.tap(find.byKey(const Key('inicio-sala')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sala-unirse')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('unirse-codigo')), 'K7M2Q');
    await tester.tap(find.byKey(const Key('unirse-entrar')));
    await tester.pumpAndSettle();
    canales.single.recibir(mensajeSala(tuAsiento: 1));
    await tester.pumpAndSettle();
    expect(c.read(enSalaProvider), isTrue);
    expect(find.byKey(const Key('esperando-host')), findsOneWidget);
    expect(find.byKey(const Key('deshacer')), findsNothing);
    expect(find.byKey(const Key('rehacer')), findsNothing);
  });

  testWidgets('el host ve el setup con los jugadores de la sala y sin añadir',
      (tester) async {
    final (_, canales) = await abrirInicio(tester);
    await tester.tap(find.byKey(const Key('inicio-sala')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sala-crear')));
    await avanzar(tester); // la barra «conectando» no deja asentar
    canales.single.recibir(mensajeSala());
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(const Key('nombre-1'))).controller!.text,
      'J1',
    );
    expect(find.byKey(const Key('anadir-jugador')), findsNothing);
    expect(find.byKey(const Key('deshacer')), findsNothing);
  });
}
