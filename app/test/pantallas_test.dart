import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:incursiones_app/almacen/almacen.dart';
import 'package:incursiones_app/cuenta/controlador_sesion.dart';
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/partida/controlador_partida.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import 'ayudas.dart';

/// Pantalla grande para que todo quepa sin tener que desplazar la lista.
Future<ProviderContainer> abrir(
  WidgetTester tester, {
  AlmacenMemoria? almacen,
  Servidor? servidor,
  MazoAtaquesJefe? mazo,
  Random? azar,
}) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...sobrescribir(almacen: almacen, servidor: servidor, mazo: mazo),
        if (azar != null) azarProvider.overrideWithValue(azar),
      ],
      child: const IncursionesApp(),
    ),
  );
  await tester.pumpAndSettle();
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

    await tester.enterText(find.byKey(const Key('jefe-nombre')), 'Mewtwo');
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
    // Primero se roba la carta; después aparece el ataque del jefe.
    expect(find.byKey(const Key('turno-del-jefe')), findsNothing);
    await tocar(tester, 'robar-carta-jefe');
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

    // Sin guardar los resultados pide confirmación antes de descartarlos.
    await tocar(tester, 'nueva-partida');
    expect(find.text('¿Empezar sin guardar?'), findsOneWidget);
    await tocar(tester, 'descartar-confirmar');
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

    await tocar(tester, 'robar-carta-jefe');
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

  testWidgets('el daño por efecto al jefe se atribuye al jugador elegido',
      (tester) async {
    final c = await abrir(tester);
    await prepararPartida(tester, hp: 500);

    // En pantalla estrecha el panel va al final de la lista de acciones.
    await tester.scrollUntilVisible(
      find.byKey(const Key('dano-efecto')),
      300,
      scrollable: find.descendant(
        of: find.byKey(const Key('panel-acciones')),
        matching: find.byType(Scrollable),
      ).first,
    );
    await tocar(tester, 'dano-efecto');
    await tocar(tester, 'dano-efecto-jugador-1');
    await escribir(tester, 'dano-efecto-puntos', '60');
    // El botón se activa al reconstruirse con el número escrito.
    await tester.pump();
    await tocar(tester, 'dano-efecto-confirmar');

    final estado = c.read(estadoProvider);
    expect(estado.jefe!.hp, 440);
    expect(estado.fase, Fase.turnoJugadores);
    expect(estado.danoPorJugador[1], 60);
    expect(estado.danoPorJugador[0], 0);
  });

  testWidgets('la carta que roba otra obliga a robar hasta el máximo del nivel',
      (tester) async {
    final c = await abrir(
      tester,
      mazo: MazoFijo(const [
        CartaAtaqueJefe(numero: 5, ranura: 1, jugador: 0, robaOtra: true),
        CartaAtaqueJefe(numero: 14, ranura: 2, jugador: 1, robaOtra: false),
      ]),
    );
    await prepararPartida(tester, hp: 500);
    await turno(tester, '0');
    await turno(tester, '0');

    // Primera carta: ataque 1 contra el jugador 1, y manda robar otra.
    await tocar(tester, 'robar-carta-jefe');
    expect(find.byKey(const Key('carta-roba-otra')), findsOneWidget);
    await tocar(tester, 'registrar-ataque-jefe');
    expect(c.read(estadoProvider).ataquesJefeEnTurno, 1);
    expect(find.text('Robar otra carta'), findsOneWidget);

    // Segunda: ataque 2 contra el jugador 2, y ya no pide más.
    await tocar(tester, 'robar-carta-jefe');
    expect(find.byKey(const Key('carta-roba-otra')), findsNothing);
    await tocar(tester, 'registrar-ataque-jefe');
    expect(c.read(estadoProvider).ataquesJefeEnTurno, 2);
    expect(find.text('Robar otra carta'), findsNothing);
    expect(find.byKey(const Key('fin-turno-jefe')), findsOneWidget);
  });

  testWidgets('la quemadura pide la moneda al terminar el turno del jefe',
      (tester) async {
    final c = await abrir(tester);
    await prepararPartida(tester, hp: 500);
    await tocar(tester, 'estado-quemadura');
    expect(c.read(estadoProvider).jefe!.quemado, isTrue);
    await turno(tester, '0');
    await turno(tester, '0');

    await tocar(tester, 'robar-carta-jefe');
    await tocar(tester, 'registrar-ataque-jefe');
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

  testWidgets('un jefe a mano: salen los dados y se piden los datos del aliado',
      (tester) async {
    final c = await abrir(tester, azar: _AzarFijo([0, 2]));
    await escribir(tester, 'ataque-0', '100');
    await escribir(tester, 'ataque-1', '100');
    await tocar(tester, 'configurar');
    await escribir(tester, 'jefe-hp', '300');
    await escribir(tester, 'jefe-invocacion', '100');
    await tocar(tester, 'elegir-jefe');

    // El jefe llama a su primer aliado al terminar su turno de la ronda 1.
    llegarALaLlamadaDelJefe(c);
    // Sin botón de invocar: los dados salen solos y, al pararse, el diálogo
    // pide los datos del aliado que ha salido (slot 0, categoría cura).
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invocar-aliado')), findsNothing);
    expect(find.byKey(const Key('resultado-dados')), findsOneWidget);
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
    expect(estado.aliados.single.categoria, CategoriaAliado.cura);
    expect(estado.fase, Fase.turnoJugadores);
    expect(estado.ronda, 2);
  });

  testWidgets('abandonar termina la partida en derrota', (tester) async {
    final c = await abrir(tester);
    await prepararPartida(tester, hp: 500);
    await tocar(tester, 'abandonar');
    await tocar(tester, 'abandonar-confirmar');

    expect(c.read(estadoProvider).resultado, Resultado.derrota);
    expect(find.text('Derrota'), findsOneWidget);
  });

  group('guardar los resultados', () {
    Future<void> ganar(WidgetTester tester) async {
      await prepararPartida(tester, hp: 100);
      await turno(tester, '100');
    }

    testWidgets('sin sesión pide iniciar sesión y no deja guardar',
        (tester) async {
      await abrir(tester);
      await ganar(tester);
      expect(find.byKey(const Key('iniciar-sesion')), findsOneWidget);
      expect(find.byKey(const Key('guardar-resultados')), findsNothing);
    });

    testWidgets('iniciar sesión desde la barra y guardar la partida',
        (tester) async {
      final peticiones = <http.Request>[];
      await abrir(
        tester,
        servidor: (p) async {
          peticiones.add(p);
          if (p.url.path.endsWith('/auth/login')) {
            return http.Response(
              '{"token":"t","username":"ana","userId":"u1"}',
              200,
            );
          }
          return http.Response('{}', 201);
        },
      );
      await ganar(tester);

      await tocar(tester, 'iniciar-sesion');
      await tester.enterText(find.byKey(const Key('login-usuario')), 'ana');
      await tester.enterText(find.byKey(const Key('login-contrasena')), 'secreto');
      await tocar(tester, 'login-entrar');

      // Vuelve a la partida, ya con la sesión.
      expect(find.byKey(const Key('guardar-resultados')), findsOneWidget);
      // Los demás jugadores cuentan como invitados.
      expect(find.textContaining('(invitado)'), findsOneWidget);

      await tocar(tester, 'guardar-resultados');
      expect(find.byKey(const Key('estado-envio')), findsOneWidget);
      expect(find.textContaining('Resultados guardados'), findsOneWidget);
      expect(peticiones.last.url.path, endsWith('/incursiones/partidas'));
    });

    testWidgets('un login incorrecto enseña el error y no inicia sesión',
        (tester) async {
      await abrir(
        tester,
        servidor: (_) async => http.Response('{"error":"Credenciales inválidas"}', 401),
      );
      await tocar(tester, 'cuenta');
      await tester.enterText(find.byKey(const Key('login-usuario')), 'ana');
      await tester.enterText(find.byKey(const Key('login-contrasena')), 'mal');
      await tocar(tester, 'login-entrar');
      expect(find.byKey(const Key('login-error')), findsOneWidget);
      expect(find.textContaining('incorrectos'), findsOneWidget);
    });

    testWidgets('después de guardar ya no se puede deshacer', (tester) async {
      await abrir(tester, almacen: almacenConSesion());
      await ganar(tester);
      IconButton deshacer() =>
          tester.widget<IconButton>(find.byKey(const Key('deshacer')));
      expect(deshacer().onPressed, isNotNull);

      await tocar(tester, 'guardar-resultados');
      expect(deshacer().onPressed, isNull);

      // Guardada: nueva partida sin confirmación.
      await tocar(tester, 'nueva-partida');
      expect(find.text('Nueva partida'), findsWidgets);
      expect(find.byKey(const Key('configurar')), findsOneWidget);
    });

    testWidgets('sin conexión queda pendiente y lo avisa en la barra',
        (tester) async {
      await abrir(
        tester,
        almacen: almacenConSesion(),
        servidor: (_) async => throw http.ClientException('sin red'),
      );
      await ganar(tester);
      await tocar(tester, 'guardar-resultados');

      expect(find.textContaining('pendiente de enviar'), findsOneWidget);
      expect(find.byKey(const Key('envios')), findsOneWidget);

      await tocar(tester, 'envios');
      expect(find.text('Pendientes de enviar: 1'), findsOneWidget);
    });

    testWidgets('cerrar sesión desde la barra', (tester) async {
      final c = await abrir(tester, almacen: almacenConSesion());
      await tocar(tester, 'cuenta');
      await tocar(tester, 'cerrar-sesion');
      expect(c.read(sesionActualProvider), isNull);
    });
  });
}

/// Azar que devuelve valores fijos (módulo el máximo), en orden.
class _AzarFijo implements Random {
  _AzarFijo(this._valores);

  final List<int> _valores;
  var _i = 0;

  @override
  int nextInt(int max) => _valores[_i++ % _valores.length] % max;

  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0;
}
