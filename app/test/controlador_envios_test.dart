import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:incursiones_app/almacen/almacen.dart';
import 'package:incursiones_app/cuenta/controlador_sesion.dart';
import 'package:incursiones_app/envios/cola_envios.dart';
import 'package:incursiones_app/envios/controlador_envios.dart';
import 'package:incursiones_app/partida/controlador_partida.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import 'ayudas.dart';

Future<ProviderContainer> crear({
  AlmacenMemoria? almacen,
  Servidor? servidor,
  List<Reintento>? reintentos,
}) async {
  final c = ProviderContainer(
    overrides: [
      ...sobrescribir(
        almacen: almacen ?? almacenConSesion(),
        servidor: servidor,
        reintentos: reintentos,
      ),
      generadorIdProvider.overrideWithValue(() => 'partida-1'),
      relojProvider.overrideWithValue(() => DateTime.utc(2026, 11, 6, 12)),
    ],
  );
  addTearDown(c.dispose);
  await c.read(sesionProvider.future);
  c.read(enviosProvider); // arranca el controlador, como hace la pantalla
  await asentar();
  return c;
}

/// Dos jugadores y un jefe de 100 HP que el jugador 1 derrota de un golpe.
void ganar(ProviderContainer c) {
  final p = c.read(partidaProvider.notifier);
  expect(
    p.registrar(const ConfigurarJugadores([
      ConfigJugador(nombre: 'Ana', ataqueMaximo: 100),
      ConfigJugador(nombre: 'Bea', ataqueMaximo: 100),
    ])),
    isNull,
  );
  expect(p.registrar(const ElegirJefe(nombre: 'Jefe', nivel: 1, hp: 100)), isNull);
  expect(p.registrar(const TurnoJugador(jugador: 0, dano: 100)), isNull);
  expect(c.read(estadoProvider).terminada, isTrue);
}

void main() {
  test('sin sesión no se puede guardar y no queda nada en la cola', () async {
    final almacen = AlmacenMemoria();
    final c = await crear(almacen: almacen);
    ganar(c);
    final error = await c.read(enviosProvider.notifier).guardarPartidaActual();
    expect(error, contains('Inicia sesión'));
    expect(await ColaEnvios(almacen).pendientes(), isEmpty);
  });

  test('no se guarda una partida sin terminar', () async {
    final c = await crear();
    final error = await c.read(enviosProvider.notifier).guardarPartidaActual();
    expect(error, contains('no ha terminado'));
  });

  test('guardar envía el registro con la cuenta del host y deja la cola vacía',
      () async {
    final peticiones = <http.Request>[];
    final c = await crear(servidor: servidorQueGuarda(peticiones));
    ganar(c);

    expect(await c.read(enviosProvider.notifier).guardarPartidaActual(), isNull);
    await asentar();

    expect(peticiones, hasLength(1));
    expect(peticiones.single.headers['authorization'], 'Bearer token-de-prueba');
    final cuerpo = jsonDecode(peticiones.single.body) as Map<String, Object?>;
    expect(cuerpo['partidaId'], 'partida-1');
    expect(cuerpo['cuentas'], [sesionDePrueba.userId, null]);
    expect(cuerpo['resumen'], isNotNull);
    final estado = c.read(enviosProvider);
    expect(estado.pendientes, 0);
    expect(estado.rechazadas, 0);
    expect(estado.partidaEncolada, 'partida-1');
    expect(estado.enviando, isFalse);
  });

  test('sin red la partida queda pendiente y se reintenta con espera creciente',
      () async {
    var hayRed = false;
    final peticiones = <http.Request>[];
    final reintentos = <Reintento>[];
    final c = await crear(
      reintentos: reintentos,
      servidor: (p) async {
        peticiones.add(p);
        if (!hayRed) throw http.ClientException('sin red');
        return http.Response('{}', 201);
      },
    );
    ganar(c);
    final envios = c.read(enviosProvider.notifier);
    await envios.guardarPartidaActual();
    await asentar();

    expect(c.read(enviosProvider).pendientes, 1);
    expect(c.read(enviosProvider).mensaje, contains('Sin conexión'));
    expect(reintentos.single.espera, const Duration(seconds: 30));

    // Vence la espera y sigue sin red: la siguiente espera es mayor.
    reintentos.removeLast().accion();
    await asentar();
    expect(c.read(enviosProvider).pendientes, 1);
    expect(reintentos.single.espera, const Duration(minutes: 1));

    // Vuelve la red.
    hayRed = true;
    reintentos.removeLast().accion();
    await asentar();
    expect(c.read(enviosProvider).pendientes, 0);
    expect(reintentos, isEmpty);
    // Siempre se reenvió el mismo registro.
    expect(peticiones.map((p) => p.body).toSet(), hasLength(1));
  });

  test('guardar dos veces la misma partida no la duplica en la cola', () async {
    final reintentos = <Reintento>[];
    final c = await crear(
      reintentos: reintentos,
      servidor: (_) async => throw http.ClientException('sin red'),
    );
    ganar(c);
    final envios = c.read(enviosProvider.notifier);
    await envios.guardarPartidaActual();
    await envios.guardarPartidaActual();
    await asentar();
    expect(c.read(enviosProvider).pendientes, 1);
  });

  test('si el servidor rechaza la partida se aparta y no se reintenta', () async {
    final reintentos = <Reintento>[];
    final c = await crear(
      reintentos: reintentos,
      servidor: (_) async => http.Response(
        jsonEncode({'error': 'resumen_incoherente', 'mensaje': 'el resumen no cuadra'}),
        422,
      ),
    );
    ganar(c);
    await c.read(enviosProvider.notifier).guardarPartidaActual();
    await asentar();

    final estado = c.read(enviosProvider);
    expect(estado.pendientes, 0);
    expect(estado.rechazadas, 1);
    expect(estado.mensaje, contains('el resumen no cuadra'));
    expect(reintentos, isEmpty);

    await c.read(enviosProvider.notifier).descartarRechazadas();
    expect(c.read(enviosProvider).rechazadas, 0);
  });

  test('con la sesión caducada se cierra la sesión y la partida se conserva',
      () async {
    final almacen = almacenConSesion();
    final c = await crear(
      almacen: almacen,
      servidor: (_) async => http.Response('{"error":"Token inválido"}', 401),
    );
    ganar(c);
    await c.read(enviosProvider.notifier).guardarPartidaActual();
    await asentar();

    expect(c.read(sesionActualProvider), isNull);
    expect(almacen.datos.containsKey('sesion'), isFalse);
    expect(c.read(enviosProvider).pendientes, 1);
    expect(c.read(enviosProvider).mensaje, contains('caducado'));
  });

  test('al abrir la app con partidas pendientes y sesión, se envían solas',
      () async {
    final almacen = almacenConSesion();
    await ColaEnvios(almacen).encolar({
      'version': 2,
      'partidaId': 'de-ayer',
      'eventos': <Object?>[],
    });
    final peticiones = <http.Request>[];
    final c = await crear(
      almacen: almacen,
      servidor: servidorQueGuarda(peticiones),
    );
    await asentar();
    expect(peticiones, hasLength(1));
    expect(c.read(enviosProvider).pendientes, 0);
  });

  test('al iniciar sesión se envía lo que estaba pendiente', () async {
    final almacen = AlmacenMemoria();
    await ColaEnvios(almacen).encolar({
      'version': 2,
      'partidaId': 'de-ayer',
      'eventos': <Object?>[],
    });
    final peticiones = <http.Request>[];
    final c = await crear(
      almacen: almacen,
      servidor: (p) async {
        peticiones.add(p);
        if (p.url.path.endsWith('/auth/login')) {
          return http.Response(
            jsonEncode({'token': 't2', 'username': 'ana', 'userId': 'u1'}),
            200,
          );
        }
        return http.Response('{}', 201);
      },
    );
    expect(peticiones, isEmpty);
    expect(c.read(enviosProvider).pendientes, 1);

    expect(await c.read(sesionProvider.notifier).iniciarSesion('ana', 'x'), isNull);
    await asentar();

    expect(c.read(enviosProvider).pendientes, 0);
    expect(peticiones.last.headers['authorization'], 'Bearer t2');
  });

  test('tras guardar no se puede deshacer; al empezar otra partida sí', () async {
    final c = await crear();
    ganar(c);
    await c.read(enviosProvider.notifier).guardarPartidaActual();
    await asentar();
    expect(c.read(enviosProvider).partidaEncolada, isNotNull);

    c.read(partidaProvider.notifier).nuevaPartida();
    await asentar();
    expect(c.read(enviosProvider).partidaEncolada, isNull);
  });
}
