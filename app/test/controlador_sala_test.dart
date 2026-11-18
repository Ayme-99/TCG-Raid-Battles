import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:incursiones_app/almacen/almacen.dart';
import 'package:incursiones_app/cuenta/controlador_sesion.dart';
import 'package:incursiones_app/partida/controlador_partida.dart';
import 'package:incursiones_app/sala/controlador_sala.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import 'ayudas.dart';

const _config = ConfigurarJugadores([
  ConfigJugador(nombre: 'Ana', ataqueMaximo: 100),
  ConfigJugador(nombre: 'Bea', ataqueMaximo: 100),
]);
const _jefe = ElegirJefe(nombre: 'Jefe', nivel: 1, hp: 1000);

Future<(ProviderContainer, List<CanalFalso>)> preparar({
  AlmacenMemoria? almacen,
  Servidor? servidor,
}) async {
  final canales = <CanalFalso>[];
  final c = ProviderContainer(
    overrides: [
      ...sobrescribir(almacen: almacen ?? almacenConSesion(), servidor: servidor),
      fabricaCanalProvider.overrideWithValue((url) {
        final canal = CanalFalso();
        canales.add(canal);
        return canal;
      }),
      urlSalaProvider.overrideWithValue(Uri.parse('ws://prueba/ws')),
      generadorIdProvider.overrideWithValue(() => 'partida-1'),
      relojProvider.overrideWithValue(() => DateTime.utc(2026, 11, 18, 22)),
    ],
  );
  addTearDown(c.dispose);
  await c.read(sesionProvider.future);
  return (c, canales);
}

/// El host entra y la partida ya ha empezado.
Future<CanalFalso> hostEnPartida(ProviderContainer c, List<CanalFalso> canales) async {
  expect(await c.read(salaProvider.notifier).unirse('ABCDE'), isNull);
  await asentar();
  canales.single.recibir(mensajeSala());
  await asentar();
  return canales.single;
}

/// Un jugador (asiento 1) entra con la partida en curso.
Future<CanalFalso> jugadorEnPartida(ProviderContainer c, List<CanalFalso> canales) async {
  expect(await c.read(salaProvider.notifier).unirse('abcde '), isNull);
  await asentar();
  canales.single.recibir(mensajeSala(tuAsiento: 1));
  await asentar();
  return canales.single;
}

void main() {
  test('sin sesión no se puede crear ni entrar en una sala', () async {
    final (c, canales) = await preparar(almacen: AlmacenMemoria());
    expect(await c.read(salaProvider.notifier).unirse('ABCDE'), contains('Inicia sesión'));
    expect(await c.read(salaProvider.notifier).crear(), contains('Inicia sesión'));
    expect(canales, isEmpty);
  });

  test('crear pide la sala al servidor y entra con su código', () async {
    final peticiones = <http.Request>[];
    final (c, canales) = await preparar(
      servidor: (peticion) async {
        peticiones.add(peticion);
        return http.Response('{"codigo":"K7M2Q"}', 201);
      },
    );
    expect(await c.read(salaProvider.notifier).crear(), isNull);
    await asentar();
    expect(peticiones.single.url.path, '/api/incursiones/salas');
    expect(peticiones.single.headers['authorization'], 'Bearer token-de-prueba');
    expect(canales.single.enviados.single['codigo'], 'K7M2Q');
    expect(canales.single.enviados.single['token'], 'token-de-prueba');
    expect(c.read(salaProvider).codigo, 'K7M2Q');
  });

  test('si ya estás en una sala el servidor lo dice', () async {
    final (c, canales) = await preparar(
      servidor: (_) async => http.Response('{"error":"ya_en_sala","codigo":"K7M2Q"}', 409),
    );
    expect(await c.read(salaProvider.notifier).crear(), contains('K7M2Q'));
    expect(canales, isEmpty);
  });

  test('el código se normaliza y el estado de la sala se actualiza', () async {
    final (c, canales) = await preparar();
    await jugadorEnPartida(c, canales);
    final sala = c.read(salaProvider);
    expect(canales.single.enviados.single['codigo'], 'ABCDE');
    expect(sala.codigo, 'ABCDE');
    expect(sala.info!.tuAsiento, 1);
    expect(sala.info!.jugadores, hasLength(2));
  });

  group('host', () {
    test('empezar fija el id y la fecha, que no cambian en toda la partida', () async {
      final (c, canales) = await preparar();
      final canal = await hostEnPartida(c, canales);
      // La sala aún no ha empezado para el servidor: el host pide empezar.
      expect(c.read(salaProvider.notifier).empezar(), isNull);
      expect(canal.de('empezar').single,
          {'tipo': 'empezar', 'partidaId': 'partida-1', 'creadaEn': '2026-11-18T22:00:00.000Z'});

      final partida = c.read(partidaProvider.notifier);
      expect(partida.registrar(_config), isNull);
      expect(partida.registrar(_jefe), isNull);
      expect(c.read(enSalaProvider), isTrue);
      final registro = partida.registro();
      expect(registro.partidaId, 'partida-1');
      expect(registro.creadaEn, '2026-11-18T22:00:00.000Z');
    });

    test('cada evento que registra se difunde con su seq', () async {
      final (c, canales) = await preparar();
      final canal = await hostEnPartida(c, canales);
      final partida = c.read(partidaProvider.notifier);
      partida.registrar(_config);
      partida.registrar(_jefe);
      final aceptados = canal.de('aceptar');
      expect(aceptados.map((m) => m['seq']), [1, 2]);
      expect(aceptados.first['evento'], eventoAJson(_config));
      // Un evento que el motor rechaza no se difunde.
      expect(partida.registrar(const TurnoJugador(jugador: 0, dano: -5)), isNotNull);
      expect(canal.de('aceptar'), hasLength(2));
    });

    test('en una sala no hay deshacer ni rehacer', () async {
      final (c, canales) = await preparar();
      await hostEnPartida(c, canales);
      final partida = c.read(partidaProvider.notifier);
      partida.registrar(_config);
      expect(c.read(puedeDeshacerProvider), isFalse);
      partida.deshacer();
      expect(c.read(partidaProvider).partida.eventos, hasLength(1));
    });

    test('acepta la propuesta de un jugador y la difunde con su idMensaje', () async {
      final (c, canales) = await preparar();
      final canal = await hostEnPartida(c, canales);
      final partida = c.read(partidaProvider.notifier);
      partida.registrar(_config);
      partida.registrar(_jefe);
      partida.registrar(const TurnoJugador(jugador: 0, dano: 50));
      canal.recibir({
        'tipo': 'proponer',
        'idMensaje': 'm-1',
        'asiento': 1,
        'evento': eventoAJson(const TurnoJugador(jugador: 1, dano: 70)),
      });
      await asentar();
      final aceptado = canal.de('aceptar').last;
      expect([aceptado['seq'], aceptado['idMensaje']], [4, 'm-1']);
      expect(c.read(estadoProvider).jefe!.hp, lessThan(1000));
    });

    test('rechaza la propuesta de quien no tiene el turno', () async {
      final (c, canales) = await preparar();
      final canal = await hostEnPartida(c, canales);
      final partida = c.read(partidaProvider.notifier);
      partida.registrar(_config);
      partida.registrar(_jefe);
      canal.recibir({
        'tipo': 'proponer',
        'idMensaje': 'm-1',
        'asiento': 1,
        'evento': eventoAJson(const TurnoJugador(jugador: 1, dano: 70)),
      });
      await asentar();
      expect(canal.de('aceptar'), hasLength(2)); // solo los dos de preparación
      final rechazo = canal.de('rechazar').single;
      expect(rechazo['idMensaje'], 'm-1');
      expect(rechazo['motivo'], isA<String>());
    });

    test('al vencer la ventana de un jugador registra un PokemonKo por cada Pokémon', () async {
      final (c, canales) = await preparar();
      final canal = await hostEnPartida(c, canales);
      final partida = c.read(partidaProvider.notifier);
      partida.registrar(_config);
      partida.registrar(_jefe);
      final vivos = c.read(estadoProvider).jugadores[1].pokemonVivos;
      expect(vivos, greaterThan(0));
      final antes = canal.de('aceptar').length;
      canal.recibir({'tipo': 'ventanaVencida', 'asiento': 1});
      await asentar();
      expect(canal.de('aceptar').length, antes + vivos);
      expect(c.read(estadoProvider).jugadores[1].pokemonVivos, 0);
    });
  });

  group('jugador', () {
    test('solo aplica lo que el host difunde, en orden', () async {
      final (c, canales) = await preparar();
      final canal = await jugadorEnPartida(c, canales);
      canal
        ..recibir(mensajeEvento(1, _config))
        ..recibir(mensajeEvento(2, _jefe));
      await asentar();
      expect(c.read(estadoProvider).jugadores, hasLength(2));
      expect(c.read(estadoProvider).jefe!.hp, 1000);
      expect(c.read(partidaProvider).partida.eventos, hasLength(2));
    });

    test('propone al host y no cambia nada hasta que llega difundido', () async {
      final (c, canales) = await preparar();
      final canal = await jugadorEnPartida(c, canales);
      canal
        ..recibir(mensajeEvento(1, _config))
        ..recibir(mensajeEvento(2, _jefe))
        ..recibir(mensajeEvento(3, const TurnoJugador(jugador: 0, dano: 50)));
      await asentar();
      const mio = TurnoJugador(jugador: 1, dano: 70);
      expect(c.read(salaProvider.notifier).proponer(mio), isNull);
      expect(canal.de('proponer'), hasLength(1));
      expect(c.read(partidaProvider).partida.eventos, hasLength(3));
      final id = canal.de('proponer').single['idMensaje']! as String;
      canal.recibir(mensajeEvento(4, mio, id: id));
      await asentar();
      expect(c.read(partidaProvider).partida.eventos, hasLength(4));
    });

    test('usa el id y la fecha que fijó el host y no puede deshacer', () async {
      final (c, canales) = await preparar();
      final canal = await jugadorEnPartida(c, canales);
      canal.recibir(mensajeEvento(1, _config));
      await asentar();
      final partida = c.read(partidaProvider.notifier);
      expect(partida.registro().partidaId, 'partida-1');
      expect(partida.registro().creadaEn, '2026-11-18T22:00:00.000Z');
      partida.deshacer();
      expect(c.read(partidaProvider).partida.eventos, hasLength(1));
    });

    test('el host no propone: juega directamente', () async {
      final (c, canales) = await preparar();
      await hostEnPartida(c, canales);
      expect(
        c.read(salaProvider.notifier).proponer(const TurnoJugador(jugador: 0, dano: 1)),
        contains('directamente'),
      );
    });
  });

  test('si se cae la partida se sale de la sala y se vuelve al juego normal', () async {
    final (c, canales) = await preparar();
    final canal = await jugadorEnPartida(c, canales);
    expect(c.read(enSalaProvider), isTrue);
    canal.recibir({'tipo': 'partidaCancelada', 'motivo': 'hostDesconectado'});
    await asentar();
    expect(c.read(salaProvider).cancelada, isTrue);
    expect(c.read(salaProvider).enSala, isFalse);
    expect(c.read(enSalaProvider), isFalse);
  });

  test('un error fatal del servidor se muestra y deja la sala', () async {
    final (c, canales) = await preparar();
    expect(await c.read(salaProvider.notifier).unirse('ABCDE'), isNull);
    await asentar();
    canales.single.recibir({'tipo': 'error', 'codigo': 'salaNoExiste', 'texto': 'no existe'});
    await asentar();
    expect(c.read(salaProvider).error, 'no existe');
    expect(c.read(salaProvider).enSala, isFalse);
  });

  test('salir en el lobby avisa al servidor y vuelve al estado inicial', () async {
    final (c, canales) = await preparar();
    expect(await c.read(salaProvider.notifier).unirse('ABCDE'), isNull);
    await asentar();
    canales.single.recibir(mensajeSala(estado: 'abierta', tuAsiento: 1));
    await asentar();
    await c.read(salaProvider.notifier).salir();
    expect(canales.single.de('salir'), hasLength(1));
    expect(canales.single.cerrado, isTrue);
    expect(c.read(salaProvider).enSala, isFalse);
  });
}
