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

/// Servidor falso con la partida de campaña de la cuenta (#478) y los hitos.
class CuentaFalsa {
  CuentaFalsa({this.partida, this.revision = 0});

  Map<String, dynamic>? partida;
  int revision;
  bool sinRed = false;
  final List<Map<String, dynamic>> subidas = [];

  http.Response _json(Object cuerpo, [int estado = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(cuerpo)), estado,
          headers: {'content-type': 'application/json; charset=utf-8'});

  Future<http.Response> responder(http.Request p) async {
    if (sinRed) throw http.ClientException('sin red');
    final ruta = p.url.path;
    if (ruta.endsWith('/campana/hitos')) {
      final ids = [
        for (final h in (jsonDecode(p.body) as Map)['hitos'] as List) h['id'],
      ];
      return _json({'abonados': ids, 'repetidos': <String>[]});
    }
    if (!ruta.endsWith('/campana/partidas/kanto')) {
      return _json({'error': 'no_encontrada'}, 404);
    }
    Map<String, Object?> copia() =>
        {'campana': 'kanto', 'revision': revision, 'partida': partida};
    if (p.method == 'GET') {
      return partida == null
          ? _json({'error': 'sin_partida'}, 404)
          : _json(copia());
    }
    final cuerpo = jsonDecode(p.body) as Map<String, dynamic>;
    subidas.add(cuerpo);
    if (cuerpo['revision'] != revision) {
      return _json({
        'error': 'revision_distinta',
        'actual': partida == null ? null : copia(),
      }, 409);
    }
    revision++;
    partida = cuerpo['partida'] as Map<String, dynamic>;
    return _json(copia());
  }
}

/// La partida de este dispositivo: en la Ruta 1, sin medallas.
const enRuta1 = PartidaCampana(
  progreso: ProgresoRuta(
    nodoActual: 'ruta-1',
    superados: {'pueblo-paleta'},
    inicial: 'bulbasaur',
  ),
  equipo: [PokemonGuardado('bulbasaur', 999)],
  puntos: 100,
  partidaId: 'p1',
  hitosPendientes: [HitoCampana('ruta-1', TipoHito.salvaje, 100)],
);

/// La de otro dispositivo: en el gimnasio de Brock, con la Medalla Roca.
const enBrock = PartidaCampana(
  progreso: ProgresoRuta(
    nodoActual: 'gimnasio-brock',
    superados: {'pueblo-paleta', 'centro-plateada'},
    inicial: 'bulbasaur',
    medallas: {'roca'},
  ),
  equipo: [PokemonGuardado('bulbasaur', 999)],
  puntos: 3300,
  partidaId: 'p1',
);

ProviderContainer contenedor(
  CuentaFalsa servidor, {
  AlmacenMemoria? almacen,
  PartidaCampana? local,
  int? revision,
  bool sucia = false,
}) {
  final a = almacen ?? almacenConSesion();
  if (local != null) a.datos[claveCampana] = jsonEncode(local.aJson());
  if (revision != null) {
    a.datos[claveCampanaCuenta] =
        jsonEncode({'revision': revision, 'sucia': sucia});
  }
  final c = ProviderContainer(overrides: [
    ...sobrescribir(almacen: a, servidor: servidor.responder),
    campanaInicialProvider.overrideWithValue(local),
  ]);
  addTearDown(c.dispose);
  return c;
}

Map<String, dynamic> meta(ProviderContainer c) {
  final a = c.read(almacenProvider) as AlmacenMemoria;
  return jsonDecode(a.datos[claveCampanaCuenta]!) as Map<String, dynamic>;
}

PartidaCampana? local(ProviderContainer c) {
  final texto = (c.read(almacenProvider) as AlmacenMemoria).datos[claveCampana];
  return texto == null
      ? null
      : PartidaCampana.desdeJson(jsonDecode(texto) as Map<String, dynamic>);
}

Future<ProviderContainer> abrir(
  CuentaFalsa servidor, {
  AlmacenMemoria? almacen,
  PartidaCampana? local,
  int? revision,
  bool sucia = false,
}) async {
  final c = contenedor(servidor,
      almacen: almacen, local: local, revision: revision, sucia: sucia);
  c.read(campanaProvider);
  await asentar();
  return c;
}

void main() {
  test('si la cuenta no tiene partida se sube la de este dispositivo',
      () async {
    final servidor = CuentaFalsa();
    final c = await abrir(servidor, local: enRuta1);
    expect(servidor.subidas.single['revision'], 0);
    expect(servidor.subidas.single['version'], 1);
    expect(servidor.revision, 1);
    expect(PartidaCampana.desdeJson(servidor.partida!).progreso.nodoActual,
        'ruta-1');
    expect(meta(c), {'revision': 1, 'sucia': false});
  });

  test('en un dispositivo sin partida se trae la de la cuenta', () async {
    final servidor = CuentaFalsa(partida: enBrock.aJson(), revision: 4);
    final c = await abrir(servidor);
    expect(
        c.read(campanaProvider).partida!.progreso.nodoActual, 'gimnasio-brock');
    expect(local(c)!.progreso.medallas, {'roca'});
    expect(meta(c), {'revision': 4, 'sucia': false});
    expect(servidor.subidas, isEmpty);
  });

  test('si aquí no cambió nada, gana la de la cuenta', () async {
    final servidor = CuentaFalsa(partida: enBrock.aJson(), revision: 5);
    final c = await abrir(servidor, local: enRuta1, revision: 3);
    expect(
        c.read(campanaProvider).partida!.progreso.nodoActual, 'gimnasio-brock');
    expect(servidor.subidas, isEmpty);
  });

  test('si solo cambió la de aquí, se sube con la revisión leída', () async {
    final servidor = CuentaFalsa(partida: enBrock.aJson(), revision: 3);
    final c = await abrir(servidor, local: enRuta1, revision: 3, sucia: true);
    expect(servidor.subidas.single['revision'], 3);
    expect(servidor.revision, 4);
    expect(c.read(campanaProvider).partida!.progreso.nodoActual, 'ruta-1');
    expect(meta(c), {'revision': 4, 'sucia': false});
  });

  test(
      'si cambiaron las dos, se pregunta; elegir la de la cuenta la trae '
      'sin perder los hitos de aquí', () async {
    final servidor = CuentaFalsa(partida: enBrock.aJson(), revision: 5);
    final c = await abrir(servidor, local: enRuta1, revision: 3, sucia: true);
    final conflicto = c.read(conflictoCampanaProvider)!;
    expect(conflicto.local.progreso.nodoActual, 'ruta-1');
    expect(conflicto.cuenta.progreso.nodoActual, 'gimnasio-brock');
    expect(servidor.subidas, isEmpty);

    await c.read(campanaProvider.notifier).usarPartidaDeLaCuenta();
    await asentar();
    expect(c.read(conflictoCampanaProvider), isNull);
    final p = c.read(campanaProvider).partida!;
    expect(p.progreso.nodoActual, 'gimnasio-brock');
    expect(local(c)!.progreso.medallas, {'roca'});
    expect(meta(c), {'revision': 5, 'sucia': false});
    expect(servidor.subidas, isEmpty);
  });

  test(
      'si cambiaron las dos y se elige la de aquí, sustituye a la de la '
      'cuenta', () async {
    final servidor = CuentaFalsa(partida: enBrock.aJson(), revision: 5);
    final c = await abrir(servidor, local: enRuta1, revision: 3, sucia: true);
    await c.read(campanaProvider.notifier).usarPartidaDeEsteDispositivo();
    await asentar();
    expect(servidor.subidas.single['revision'], 5);
    expect(PartidaCampana.desdeJson(servidor.partida!).progreso.nodoActual,
        'ruta-1');
    expect(meta(c), {'revision': 6, 'sucia': false});
  });

  test('sin conexión se sigue con la de aquí y se sube después', () async {
    final servidor = CuentaFalsa()..sinRed = true;
    final c = await abrir(servidor, local: enRuta1, revision: 2, sucia: true);
    expect(c.read(campanaProvider).partida!.progreso.nodoActual, 'ruta-1');
    expect(meta(c)['sucia'], isTrue);
    servidor
      ..sinRed = false
      ..partida = enRuta1.aJson()
      ..revision = 2;
    await c.read(campanaProvider.notifier).sincronizar();
    expect(servidor.subidas.single['revision'], 2);
    expect(meta(c), {'revision': 3, 'sucia': false});
  });

  test('empezar una campaña nueva la sube a la cuenta', () async {
    final servidor = CuentaFalsa(partida: enBrock.aJson(), revision: 1);
    final c = await abrir(servidor, local: enBrock, revision: 1);
    c.read(campanaProvider.notifier).nueva(catalogoCampanaDeDisco());
    await asentar();
    expect(servidor.subidas.single['revision'], 1);
    expect(
        PartidaCampana.desdeJson(servidor.partida!).progreso.medallas, isEmpty);
    expect(meta(c), {'revision': 2, 'sucia': false});
  });

  test('tras abandonar no se vuelve a traer la de la cuenta', () async {
    final servidor = CuentaFalsa(partida: enBrock.aJson(), revision: 1);
    final c = await abrir(servidor, local: enBrock, revision: 1);
    c.read(campanaProvider.notifier).abandonar();
    await asentar();
    servidor.revision = 2; // otro dispositivo la cambia
    await c.read(campanaProvider.notifier).sincronizar();
    expect(c.read(campanaProvider).partida, isNull);
    expect(local(c), isNull);
  });

  test('sin sesión no se habla con la cuenta', () async {
    final servidor = CuentaFalsa(partida: enBrock.aJson(), revision: 1);
    final c = await abrir(servidor, almacen: AlmacenMemoria(), local: enRuta1);
    expect(c.read(campanaProvider).partida!.progreso.nodoActual, 'ruta-1');
    expect(servidor.subidas, isEmpty);
  });

  testWidgets('el mapa pregunta con cuál seguir y enseña las dos',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final servidor = CuentaFalsa(partida: enBrock.aJson(), revision: 5);
    final almacen = almacenConSesion()
      ..datos[claveCampana] = jsonEncode(enRuta1.aJson())
      ..datos[claveCampanaCuenta] = jsonEncode({'revision': 3, 'sucia': true});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...sobrescribir(
            almacen: almacen, servidor: servidor.responder, conInicio: true),
        campanaInicialProvider.overrideWithValue(enRuta1),
      ],
      child: const MaterialApp(home: PantallaCampana()),
    ));
    await tester.pumpAndSettle();
    await tester.runAsync(asentar);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('campana-elegir-partida')), findsOneWidget);
    final dispositivo = tester
        .widget<Text>(find.byKey(const Key('partida-dispositivo-resumen')))
        .data!;
    final cuenta = tester
        .widget<Text>(find.byKey(const Key('partida-cuenta-resumen')))
        .data!;
    expect(dispositivo, contains('0 medallas'));
    expect(cuenta, contains('1 medalla '));
    expect(cuenta, contains('3300 puntos'));

    await tester.tap(find.byKey(const Key('partida-cuenta')));
    await tester.runAsync(asentar);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('campana-elegir-partida')), findsNothing);
    expect(find.byKey(const Key('campana-mapa')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
