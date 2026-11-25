import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:incursiones_app/almacen/almacen.dart';
import 'package:incursiones_app/campana/controlador_campana.dart';
import 'package:incursiones_app/campana/pantalla_campana.dart';
import 'package:incursiones_engine/campana.dart';

import 'ayudas.dart';
import 'campana_test.dart' show jugarCombate, tocar;

/// Servidor de hitos que abona todo lo que llega y apunta los cuerpos.
Servidor servidorDeHitos(List<Map<String, dynamic>> cuerpos) => (p) async {
      final cuerpo = jsonDecode(p.body) as Map<String, dynamic>;
      cuerpos.add(cuerpo);
      final ids = [for (final h in cuerpo['hitos'] as List) h['id']];
      return http.Response(
          jsonEncode({
            'abonados': ids,
            'repetidos': <String>[],
            'puntosAbonados': 0,
            'puntosCampana': 0,
          }),
          200);
    };

const _nodo = ProgresoRuta(
  nodoActual: 'ruta-1',
  superados: {'pueblo-paleta'},
  inicial: 'bulbasaur',
);

/// Una partida con dos hitos sin enviar.
PartidaCampana conHitos({String? partidaId = 'abc123'}) => PartidaCampana(
      progreso: _nodo,
      equipo: const [PokemonGuardado('bulbasaur', 999)],
      puntos: 300,
      partidaId: partidaId,
      hitosPendientes: const [
        HitoCampana('ruta-1', TipoHito.salvaje, 100),
        HitoCampana('entrenador-1', TipoHito.entrenador, 200),
      ],
    );

ProviderContainer contenedor({
  required Almacen almacen,
  required Servidor servidor,
  PartidaCampana? guardada,
  List<Reintento>? reintentos,
}) {
  final c = ProviderContainer(overrides: [
    ...sobrescribir(
        almacen: almacen, servidor: servidor, reintentos: reintentos),
    campanaInicialProvider.overrideWithValue(guardada),
  ]);
  addTearDown(c.dispose);
  return c;
}

PartidaCampana guardadaEn(AlmacenMemoria a) => PartidaCampana.desdeJson(
    jsonDecode(a.datos[claveCampana]!) as Map<String, dynamic>);

void main() {
  test('al abrir con sesión se envían los hitos pendientes y se quitan',
      () async {
    final cuerpos = <Map<String, dynamic>>[];
    final almacen = almacenConSesion();
    final c = contenedor(
        almacen: almacen,
        servidor: servidorDeHitos(cuerpos),
        guardada: conHitos());
    c.read(campanaProvider);
    await asentar();
    expect(cuerpos, hasLength(1));
    expect(cuerpos.single, {
      'version': 1,
      'campana': 'kanto',
      'partida': 'abc123',
      'hitos': [
        {'id': 'ruta-1', 'tipo': 'salvaje', 'puntos': 100},
        {'id': 'entrenador-1', 'tipo': 'entrenador', 'puntos': 200},
      ],
    });
    expect(c.read(campanaProvider).partida!.hitosPendientes, isEmpty);
    expect(guardadaEn(almacen).hitosPendientes, isEmpty);
    // Los puntos de la partida no cambian: solo se ha vaciado la cola.
    expect(guardadaEn(almacen).puntos, 300);
  });

  test('sin sesión no se envía nada', () async {
    final cuerpos = <Map<String, dynamic>>[];
    final almacen = AlmacenMemoria();
    final c = contenedor(
        almacen: almacen,
        servidor: servidorDeHitos(cuerpos),
        guardada: conHitos());
    c.read(campanaProvider);
    await asentar();
    expect(cuerpos, isEmpty);
    expect(c.read(campanaProvider).partida!.hitosPendientes, hasLength(2));
  });

  test('solo se quitan los ids que la cuenta confirma (abonados o repetidos)',
      () async {
    final almacen = almacenConSesion();
    final c = contenedor(
      almacen: almacen,
      servidor: (p) async => http.Response(
          jsonEncode({
            'abonados': ['entrenador-1'],
            'repetidos': ['ruta-1'],
            'puntosAbonados': 200,
            'puntosCampana': 300,
          }),
          200),
      guardada: conHitos(),
    );
    c.read(campanaProvider);
    await asentar();
    expect(c.read(campanaProvider).partida!.hitosPendientes, isEmpty);
  });

  test('sin conexión los hitos se quedan y se reintenta más tarde', () async {
    var caido = true;
    final cuerpos = <Map<String, dynamic>>[];
    final reintentos = <Reintento>[];
    final ok = servidorDeHitos(cuerpos);
    final almacen = almacenConSesion();
    final c = contenedor(
      almacen: almacen,
      servidor: (p) async => caido ? http.Response('caído', 503) : await ok(p),
      guardada: conHitos(),
      reintentos: reintentos,
    );
    c.read(campanaProvider);
    await asentar();
    expect(c.read(campanaProvider).partida!.hitosPendientes, hasLength(2));
    expect(reintentos, hasLength(1));
    caido = false;
    reintentos.single.accion();
    await asentar();
    expect(cuerpos, hasLength(1));
    expect(c.read(campanaProvider).partida!.hitosPendientes, isEmpty);
  });

  test('si el servidor los rechaza se descartan (reintentar no sirve)',
      () async {
    final reintentos = <Reintento>[];
    final almacen = almacenConSesion();
    final c = contenedor(
      almacen: almacen,
      servidor: (p) async =>
          http.Response(jsonEncode({'error': 'puntos_fuera_de_tope'}), 422),
      guardada: conHitos(),
      reintentos: reintentos,
    );
    c.read(campanaProvider);
    await asentar();
    expect(c.read(campanaProvider).partida!.hitosPendientes, isEmpty);
    expect(reintentos, isEmpty);
  });

  test('una partida guardada sin id recibe uno al abrir la app', () async {
    final almacen = AlmacenMemoria();
    final c = contenedor(
        almacen: almacen,
        servidor: servidorDeHitos([]),
        guardada: conHitos(partidaId: null));
    final id = c.read(campanaProvider).partida!.partidaId;
    expect(id, matches(RegExp(r'^[0-9a-f]{16}$')));
    await asentar();
    expect(guardadaEn(almacen).partidaId, id);
  });

  test('cada campaña nueva tiene su propio id', () async {
    final almacen = AlmacenMemoria();
    final c = contenedor(almacen: almacen, servidor: servidorDeHitos([]));
    final catalogo = catalogoCampanaDeDisco();
    c.read(campanaProvider.notifier).nueva(catalogo);
    final primera = c.read(campanaProvider).partida!.partidaId;
    c.read(campanaProvider.notifier).nueva(catalogo);
    final segunda = c.read(campanaProvider).partida!.partidaId;
    expect(primera, isNotNull);
    expect(segunda, isNot(primera));
    expect(guardadaEn(almacen).partidaId, segunda);
  });

  testWidgets('al ganar la Medalla Roca se envía el hito a la cuenta',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final cuerpos = <Map<String, dynamic>>[];
    final almacen = almacenConSesion();
    const guardada = PartidaCampana(
      progreso: ProgresoRuta(
        nodoActual: 'gimnasio-brock',
        superados: {'pueblo-paleta', 'centro-plateada'},
        inicial: 'bulbasaur',
      ),
      equipo: [PokemonGuardado('bulbasaur', 999)],
      ultimaCura: 'centro-plateada',
      partidaId: 'partida-brock',
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...sobrescribir(
            almacen: almacen,
            servidor: servidorDeHitos(cuerpos),
            conInicio: true),
        campanaInicialProvider.overrideWithValue(guardada),
      ],
      child: const MaterialApp(home: PantallaCampana()),
    ));
    await tester.pumpAndSettle();
    expect(cuerpos, isEmpty, reason: 'no había hitos pendientes');
    await tocar(tester, 'campana-combatir');
    await jugarCombate(tester);
    await tester.runAsync(asentar);
    await tester.pumpAndSettle();
    expect(cuerpos, hasLength(1));
    expect(cuerpos.single['partida'], 'partida-brock');
    expect(cuerpos.single['hitos'], [
      {'id': 'gimnasio-brock', 'tipo': 'medalla', 'puntos': 1500},
    ]);
    final c =
        ProviderScope.containerOf(tester.element(find.byType(PantallaCampana)));
    expect(c.read(campanaProvider).partida!.hitosPendientes, isEmpty);
    expect(guardadaEn(almacen).hitosPendientes, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
