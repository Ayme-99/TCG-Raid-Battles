import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:incursiones_app/almacen/almacen.dart';
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/campana/controlador_campana.dart';
import 'package:incursiones_app/cuenta/controlador_sesion.dart';
import 'package:incursiones_engine/campana.dart';

import 'ayudas.dart';

/// Inicio con dos bloques, partida rápida y campaña (#585, decidido por Ayme
/// el 2026-11-28).

/// Servidor falso: el login de Ana sale bien y la cuenta no tiene campaña.
Future<http.Response> servidor(http.Request p) async {
  if (p.url.path.endsWith('/auth/login')) {
    return http.Response(
        '{"token":"t","username":"ana","userId":"u1"}', 200);
  }
  if (p.method == 'GET' && p.url.path.contains('/campana/partidas/')) {
    return http.Response('{}', 404);
  }
  return http.Response('{"partidaId":"x"}', 201);
}

const guardada = PartidaCampana(
  progreso: ProgresoRuta(
      nodoActual: 'ruta-2-norte',
      superados: {'pueblo-paleta'},
      medallas: {'roca'},
      inicial: 'charmander'),
  equipo: [PokemonGuardado('charmander', 70), PokemonGuardado('weedle', 50)],
  partidaId: 'p1',
);

Future<ProviderContainer> abrir(
  WidgetTester tester, {
  bool conSesion = true,
  PartidaCampana? campana,
  Size tamano = const Size(1024, 768),
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...sobrescribir(
          conInicio: true,
          almacen: conSesion ? almacenConSesion() : AlmacenMemoria(),
          servidor: servidor,
        ),
        campanaInicialProvider.overrideWithValue(campana),
      ],
      child: const IncursionesApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(IncursionesApp)));
}

bool apagado(WidgetTester tester, String clave) =>
    tester.widget<InkWell>(find.byKey(Key(clave))).onTap == null;

Future<void> tocar(WidgetTester tester, String clave) async {
  await tester.ensureVisible(find.byKey(Key(clave)));
  await tester.tap(find.byKey(Key(clave)));
  await tester.pumpAndSettle();
}

String linea(WidgetTester tester, String bloque) =>
    tester.widget<Text>(find.byKey(Key('$bloque-linea'))).data!;

void main() {
  for (final (nombre, tamano) in [
    ('tablet', const Size(1024, 768)),
    ('móvil', const Size(390, 844)),
  ]) {
    testWidgets('el inicio separa partida rápida y campaña en $nombre',
        (tester) async {
      await abrir(tester, tamano: tamano);
      expect(find.text('PARTIDA RÁPIDA'), findsOneWidget);
      expect(find.text('CAMPAÑA'), findsOneWidget);
      for (final k in [
        'inicio-continuar',
        'inicio-nueva',
        'inicio-continuar-campana',
        'inicio-nueva-campana',
      ]) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }
      // Sin nada guardado, los dos «Continuar» salen apagados y dicen por qué.
      expect(apagado(tester, 'inicio-continuar'), isTrue);
      expect(apagado(tester, 'inicio-continuar-campana'), isTrue);
      expect(linea(tester, 'inicio-bloque-rapida'),
          'No hay ninguna partida a medias');
      expect(linea(tester, 'inicio-bloque-campana'),
          'Aún no has empezado una campaña');
      expect(find.text('Partida libre'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('con una campaña guardada, Continuar abre el mapa',
      (tester) async {
    final c = await abrir(tester, campana: guardada);
    expect(apagado(tester, 'inicio-continuar-campana'), isFalse);
    expect(linea(tester, 'inicio-bloque-campana'),
        '1 medalla · 2 Pokémon en el equipo');
    await tocar(tester, 'inicio-continuar-campana');
    expect(find.byKey(const Key('campana-mapa')), findsOneWidget);
    expect(c.read(campanaProvider).partida!.progreso.nodoActual,
        'ruta-2-norte');
  });

  testWidgets('Nueva campaña sin guardada empieza directamente',
      (tester) async {
    final c = await abrir(tester);
    await tocar(tester, 'inicio-nueva-campana');
    expect(find.text('¿Empezar una campaña nueva?'), findsNothing);
    expect(find.byKey(const Key('campana-mapa')), findsOneWidget);
    final p = c.read(campanaProvider).partida!;
    expect(p.equipo, isEmpty, reason: 'a elegir el inicial');
  });

  testWidgets('Nueva campaña con una guardada pide confirmar antes de pisarla',
      (tester) async {
    final c = await abrir(tester, campana: guardada);
    await tocar(tester, 'inicio-nueva-campana');
    expect(find.text('¿Empezar una campaña nueva?'), findsOneWidget);
    expect(find.text('Se perderá tu progreso actual.'), findsOneWidget);
    // Volver no pisa nada.
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inicio')), findsOneWidget);
    expect(c.read(campanaProvider).partida!.partidaId, 'p1');
    // Confirmar la sustituye por una nueva (solo una campaña guardada).
    await tocar(tester, 'inicio-nueva-campana');
    await tocar(tester, 'inicio-confirmar-nueva-campana');
    expect(find.byKey(const Key('campana-mapa')), findsOneWidget);
    final p = c.read(campanaProvider).partida!;
    expect(p.partidaId, isNot('p1'));
    expect(p.equipo, isEmpty);
    expect(p.progreso.medallas, isEmpty);
  });

  for (final boton in ['inicio-nueva-campana', 'inicio-continuar-campana']) {
    testWidgets('sin sesión, $boton lleva al login y sigue después',
        (tester) async {
      final c = await abrir(tester,
          conSesion: false,
          campana: boton == 'inicio-continuar-campana' ? guardada : null);
      expect(linea(tester, 'inicio-bloque-campana'),
          boton == 'inicio-continuar-campana'
              ? '1 medalla · 2 Pokémon en el equipo'
              : 'Inicia sesión para jugar la campaña');
      await tocar(tester, boton);
      expect(find.byKey(const Key('login-usuario')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('login-usuario')), 'ana');
      await tester.enterText(
          find.byKey(const Key('login-contrasena')), 'secreto');
      await tocar(tester, 'login-entrar');
      expect(c.read(sesionActualProvider), isNotNull);
      // No se pierde la elección: sigue con lo que se había pulsado.
      expect(find.byKey(const Key('campana-mapa')), findsOneWidget);
      expect(c.read(campanaProvider).partida, isNotNull);
    });
  }

  testWidgets('sin sesión, volver del login no abre la campaña',
      (tester) async {
    final c = await abrir(tester, conSesion: false);
    expect(apagado(tester, 'inicio-continuar-campana'), isFalse,
        reason: 'sin sesión lleva al login');
    await tocar(tester, 'inicio-nueva-campana');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inicio')), findsOneWidget);
    expect(find.byKey(const Key('campana-mapa')), findsNothing);
    expect(c.read(campanaProvider).partida, isNull);
  });
}
