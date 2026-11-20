import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:incursiones_app/almacen/almacen.dart';
import 'package:incursiones_app/cuenta/controlador_sesion.dart';
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/pantallas/aviso_central.dart';
import 'package:incursiones_app/pantallas/comun.dart';
import 'package:incursiones_app/pantallas/pantalla_partida.dart';
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
  await elegirJefeDePrueba(tester, hp: hp);
}

String danoEscrito(WidgetTester tester) => tester
    .widget<TextField>(find.descendant(
      of: find.byKey(const Key('dano-turno')),
      matching: find.byType(TextField),
    ))
    .controller!
    .text;

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

    await elegirJefeDePrueba(tester, nombre: 'Mewtwo', hp: 300);

    final estado = c.read(estadoProvider);
    expect(estado.fase, Fase.turnoJugadores);
    expect(estado.jefe!.nombre, 'Mewtwo');
    expect(estado.jefe!.hp, 300);
    expect(find.text('Turno de Jugador 1'), findsOneWidget);
  });

  testWidgets('sin sesión el jugador 1 se llama Jugador 1', (tester) async {
    await abrir(tester);
    final campo = tester.widget<TextField>(find.byKey(const Key('nombre-0')));
    expect(campo.controller!.text, 'Jugador 1');
  });

  testWidgets('con sesión el jugador 1 empieza con su nickname y se puede cambiar',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: sobrescribir(almacen: almacenConSesion()),
        child: const IncursionesApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(const Key('nombre-0'))).controller!.text,
      'ana',
    );
    expect(
      tester.widget<TextField>(find.byKey(const Key('nombre-1'))).controller!.text,
      'Jugador 2',
    );
    await tester.enterText(find.byKey(const Key('nombre-0')), 'Ash');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(const Key('nombre-0'))).controller!.text,
      'Ash',
    );
  });

  testWidgets('se pueden añadir y quitar jugadores (de 2 a 4)', (tester) async {
    await abrir(tester);
    expect(find.byKey(const Key('nombre-2')), findsNothing);
    // Con 2 jugadores no se puede quitar ninguno: el mínimo es 2 (GDD v1.19).
    final quitar = tester.widget<OutlinedButton>(
      find.byKey(const Key('quitar-jugador')),
    );
    expect(quitar.onPressed, isNull);
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

  testWidgets('el daño del turno se ajusta con pasos y el número es editable',
      (tester) async {
    final c = await abrir(tester);
    await prepararPartida(tester, hp: 500);
    await tocar(tester, 'dano-mas-50');
    await tocar(tester, 'dano-mas-10');
    await tocar(tester, 'dano-mas-10');
    await tocar(tester, 'dano-menos-10');
    expect(danoEscrito(tester), '60');
    // Nunca baja de 0.
    await tocar(tester, 'dano-menos-10');
    await tocar(tester, 'dano-menos-10');
    await tocar(tester, 'dano-menos-10');
    await tocar(tester, 'dano-menos-10');
    await tocar(tester, 'dano-menos-10');
    await tocar(tester, 'dano-menos-10');
    await tocar(tester, 'dano-menos-10');
    expect(danoEscrito(tester), '0');
    await tocar(tester, 'dano-mas-50');
    await tocar(tester, 'registrar-turno');
    expect(c.read(estadoProvider).jefe!.hp, 450);
  });

  testWidgets('fijar daño: se repite en los turnos del jugador y se quita',
      (tester) async {
    final c = await abrir(tester);
    await prepararPartida(tester, hp: 1000);
    await tocar(tester, 'dano-mas-50');
    await tocar(tester, 'dano-mas-10');
    await tocar(tester, 'fijar-dano');
    await tocar(tester, 'registrar-turno');
    // El otro jugador empieza de cero.
    expect(danoEscrito(tester), '0');
    await tocar(tester, 'registrar-turno');
    await tocar(tester, 'robar-carta-jefe');
    await escribir(tester, 'dano-jefe', '10');
    await tocar(tester, 'objetivo-1');
    await tocar(tester, 'registrar-ataque-jefe');
    await tocar(tester, 'fin-turno-jefe');
    expect(c.read(estadoProvider).fase, Fase.turnoJugadores);
    // Vuelve el primero con su daño de 60 ya puesto.
    expect(danoEscrito(tester), '60');
    expect(c.read(danoFijadoProvider), {c.read(estadoProvider).jugadorActual!: 60});
    await tocar(tester, 'fijar-dano');
    await tocar(tester, 'registrar-turno');
    expect(c.read(danoFijadoProvider), isEmpty);
  });

  testWidgets('victoria: el fin de partida muestra el resultado sin puntos', (tester) async {
    final c = await abrir(tester);
    await prepararPartida(tester, hp: 100);

    await turno(tester, '60');
    await turno(tester, '40');

    expect(c.read(estadoProvider).resultado, Resultado.victoria);
    expect(find.text('Victoria'), findsOneWidget);
    // La partida libre no da puntos.
    expect(find.textContaining('Puntos'), findsNothing);
    expect(find.byKey(const Key('puntos-equipo')), findsNothing);
    expect(find.byKey(const Key('jugador-0')), findsOneWidget);
    expect(find.byKey(const Key('jugador-1')), findsOneWidget);

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
    expect(c.read(estadoProvider).jugadores[0].pokemonVivos, 3);

    await tocar(tester, 'fin-turno-jefe');
    final estado = c.read(estadoProvider);
    expect(estado.fase, Fase.turnoJugadores);
    expect(estado.ronda, 2);
    // El jugador con un Pokémon KO se sienta el turno (solo roba carta de
    // ánimo, fuera de la app) y los ataques contra él fallan.
    expect(estado.orden, [1]);
    expect(find.byKey(const Key('sentados-ko')), findsOneWidget);
    expect(estado.enKo(0), isTrue);
    expect(estado.enKo(1), isFalse);
  });

  testWidgets('el daño por efecto al jefe se atribuye al jugador elegido',
      (tester) async {
    final c = await abrir(tester);
    await prepararPartida(tester, hp: 500);

    await tocar(tester, 'menu-jefe');
    await tocar(tester, 'accion-dano-efecto');
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

  testWidgets('la quemadura lanza la moneda sobre la mesa al terminar el turno',
      (tester) async {
    // Moneda en cara: la quemadura se quita.
    final c = await abrir(tester, azar: _AzarFijo([0]));
    await prepararPartida(tester, hp: 500);
    await tocar(tester, 'menu-jefe');
    await tocar(tester, 'accion-quemar');
    await tester.tap(find.descendant(
      of: find.byType(SimpleDialog),
      matching: find.text('Jugador 1'),
    ));
    await tester.pumpAndSettle();
    expect(c.read(estadoProvider).jefe!.quemado, isTrue);
    expect(c.read(estadoProvider).estadosAplicados[0], 1);
    await turno(tester, '0');
    await turno(tester, '0');

    await tocar(tester, 'robar-carta-jefe');
    await tocar(tester, 'registrar-ataque-jefe');
    await tocar(tester, 'fin-turno-jefe');
    expect(find.byKey(const Key('moneda-resultado')), findsNothing);

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

  testWidgets('un jefe que invoca: salen los dados y se piden los datos del aliado',
      (tester) async {
    final c = await abrir(tester, azar: _AzarFijo([0, 2]));
    await escribir(tester, 'ataque-0', '100');
    await escribir(tester, 'ataque-1', '100');
    await tocar(tester, 'configurar');
    await elegirJefeDePrueba(tester, hp: 300, invocacionCadaHp: 100);

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

    // Atacar al aliado usa el daño del panel y, con un solo aliado, no
    // pregunta nada más.
    await tocar(tester, 'dano-mas-10');
    await tocar(tester, 'dano-mas-10');
    await tester.tap(find.byKey(const Key('atacar-aliado')));
    await tester.pump();
    expect(c.read(estadoProvider).aliados.single.hp, 30);
  });

  testWidgets('rendirse termina la partida en derrota', (tester) async {
    final c = await abrir(tester);
    await prepararPartida(tester, hp: 500);
    await tocar(tester, 'abandonar');
    await tocar(tester, 'abandonar-confirmar');

    expect(c.read(estadoProvider).resultado, Resultado.derrota);
    expect(find.text('Derrota'), findsOneWidget);
  });

  testWidgets('salir vuelve al inicio y la partida se puede continuar (#235)',
      (tester) async {
    final c = await abrir(tester);
    await prepararPartida(tester, hp: 500);
    final eventos = c.read(partidaProvider).partida.eventos.length;

    await tocar(tester, 'abandonar');
    await tocar(tester, 'abandonar-salir');

    // Se ve el inicio y la partida sigue como estaba, sin terminar.
    expect(find.byKey(const Key('inicio')), findsOneWidget);
    expect(c.read(estadoProvider).terminada, isFalse);
    expect(c.read(partidaProvider).partida.eventos.length, eventos);

    await tocar(tester, 'inicio-continuar');
    expect(find.byKey(const Key('inicio')), findsNothing);
    expect(find.byKey(const Key('mesa')), findsOneWidget);
  });

  testWidgets('seguir jugando no cambia nada', (tester) async {
    final c = await abrir(tester);
    await prepararPartida(tester, hp: 500);
    await tocar(tester, 'abandonar');
    await tester.tap(find.text('Seguir jugando'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('inicio')), findsNothing);
    expect(c.read(estadoProvider).terminada, isFalse);
  });

  testWidgets('al volver al inicio se retiran las alertas que había',
      (tester) async {
    await abrir(tester);
    registrarAviso(
      tester.element(find.byType(PantallaPartida)),
      'Magikarp: está KO',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('aviso')), findsOneWidget);

    await tester.tap(find.byKey(const Key('preparacion-atras')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('inicio')), findsOneWidget);
    expect(find.byKey(const Key('aviso')), findsNothing);
    expect(avisosEnCola(), 0);
    await tester.pumpAndSettle();
  });

  testWidgets('en el setup se puede volver al inicio', (tester) async {
    await abrir(tester);
    await tocar(tester, 'preparacion-atras');
    expect(find.byKey(const Key('inicio')), findsOneWidget);
    // Sin eventos no hay nada que continuar.
    expect(find.byKey(const Key('inicio-continuar')), findsNothing);
  });

  testWidgets(
      'en la preparación «atrás» sustituye a deshacer y rehacer y retrocede '
      'un paso', (tester) async {
    final c = await abrir(tester);
    expect(find.byKey(const Key('deshacer')), findsNothing);
    expect(find.byKey(const Key('rehacer')), findsNothing);

    await escribir(tester, 'ataque-0', '100');
    await escribir(tester, 'ataque-1', '100');
    await tocar(tester, 'configurar');
    expect(c.read(estadoProvider).fase, Fase.eleccionJefe);
    expect(find.byKey(const Key('deshacer')), findsNothing);

    // De la elección de jefe se vuelve al paso de los jugadores.
    await tocar(tester, 'preparacion-atras');
    expect(c.read(estadoProvider).fase, Fase.preparacion);
    expect(find.byKey(const Key('configurar')), findsOneWidget);
  });

  group('salidas del fin de partida (#234)', () {
    testWidgets('revancha tras ganar: mismos jugadores, queda elegir jefe',
        (tester) async {
      final c = await abrir(tester);
      await prepararPartida(tester, hp: 100);
      await turno(tester, '100');
      expect(c.read(estadoProvider).resultado, Resultado.victoria);
      final antes = [
        for (final j in c.read(estadoProvider).jugadores)
          (j.nombre, j.ataqueMaximo),
      ];

      await tocar(tester, 'revancha');
      // Sin guardar, pide confirmar antes de descartar los resultados.
      expect(find.text('¿Empezar sin guardar?'), findsOneWidget);
      await tocar(tester, 'descartar-confirmar');

      final estado = c.read(estadoProvider);
      expect(estado.fase, Fase.eleccionJefe);
      expect(
        [for (final j in estado.jugadores) (j.nombre, j.ataqueMaximo)],
        antes,
      );
    });

    testWidgets('revancha también sale si te rindes', (tester) async {
      final c = await abrir(tester);
      await prepararPartida(tester, hp: 500);
      await tocar(tester, 'abandonar');
      await tocar(tester, 'abandonar-confirmar');
      expect(c.read(estadoProvider).resultado, Resultado.derrota);

      expect(find.byKey(const Key('revancha')), findsOneWidget);
      await tocar(tester, 'revancha');
      await tocar(tester, 'descartar-confirmar');
      expect(c.read(estadoProvider).fase, Fase.eleccionJefe);
      expect(c.read(estadoProvider).jugadores, hasLength(2));
    });

    testWidgets('volver al inicio no descarta la partida terminada',
        (tester) async {
      final c = await abrir(tester);
      await prepararPartida(tester, hp: 100);
      await turno(tester, '100');

      await tocar(tester, 'volver-inicio');
      expect(find.byKey(const Key('inicio')), findsOneWidget);
      expect(c.read(estadoProvider).terminada, isTrue);

      // Sin guardar sigue ahí para continuar y guardar los resultados.
      await tocar(tester, 'inicio-continuar');
      expect(find.text('Victoria'), findsOneWidget);
    });
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

    testWidgets('con los resultados guardados, la revancha no pide confirmar',
        (tester) async {
      final c = await abrir(tester, almacen: almacenConSesion());
      await ganar(tester);
      await tocar(tester, 'guardar-resultados');

      await tocar(tester, 'revancha');
      expect(find.text('¿Empezar sin guardar?'), findsNothing);
      expect(c.read(estadoProvider).fase, Fase.eleccionJefe);
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
