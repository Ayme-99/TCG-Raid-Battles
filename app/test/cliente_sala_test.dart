import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/sala/canal_sala.dart';
import 'package:incursiones_app/sala/cliente_sala.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import 'ayudas.dart';

const _turno = TurnoJugador(jugador: 1, dano: 120);
const _otro = TurnoJugador(jugador: 0, dano: 40);

/// Cliente con canales falsos. Cada reconexión abre un canal nuevo en
/// [canales]. Sin espera entre reintentos.
ClienteSala nuevo(
  List<CanalFalso> canales, {
  List<int>? aplicados,
  ProponerAlMotor? alProponer,
  int ultimoSeq = 0,
  List<NovedadSala>? novedades,
}) {
  var n = 0;
  final cliente = ClienteSala(
    codigo: 'ABCDE',
    token: 'tok',
    url: Uri.parse('ws://prueba/ws'),
    fabrica: (url) {
      final canal = CanalFalso();
      canales.add(canal);
      return canal;
    },
    alAplicar: (seq, evento) {
      aplicados?.add(seq);
      return null;
    },
    alProponer: alProponer,
    ultimoSeq: ultimoSeq,
    espera: (_) => Duration.zero,
    generarId: () => 'id-${++n}',
  );
  cliente.novedades.listen((x) => novedades?.add(x));
  addTearDown(cliente.cerrar);
  return cliente;
}

void main() {
  test('la dirección del WebSocket sale de la del API', () {
    expect(urlSalaDe('https://x.onrender.com/api'),
        'wss://x.onrender.com/api/incursiones/ws');
    expect(urlSalaDe('http://localhost:5000/api/'),
        'ws://localhost:5000/api/incursiones/ws');
  });

  test('manda hola con el token en el primer mensaje y pasa a conectada', () async {
    final canales = <CanalFalso>[];
    final novedades = <NovedadSala>[];
    final cliente = nuevo(canales, novedades: novedades);
    cliente.conectar();
    await asentar();
    expect(canales.single.enviados.single, {
      'tipo': 'hola',
      'protocolo': 1,
      'token': 'tok',
      'codigo': 'ABCDE',
      'ultimoSeq': 0,
    });
    expect(cliente.conectada, isFalse);
    canales.single.recibir(mensajeSala(estado: 'abierta', tuAsiento: 1));
    await asentar();
    expect(cliente.conectada, isTrue);
    expect(cliente.info!.tuAsiento, 1);
    expect(cliente.soyHost, isFalse);
    expect(novedades.whereType<SalaActualizada>(), hasLength(1));
  });

  test('aplica los eventos en orden y una sola vez', () async {
    final canales = <CanalFalso>[];
    final aplicados = <int>[];
    final cliente = nuevo(canales, aplicados: aplicados)..conectar();
    await asentar();
    canales.single
      ..recibir(mensajeSala())
      ..recibir(mensajeEvento(1, _turno))
      ..recibir(mensajeEvento(1, _turno))
      ..recibir(mensajeEvento(2, _otro));
    await asentar();
    expect(aplicados, [1, 2]);
    expect(cliente.ultimoSeq, 2);
  });

  test('si falta un evento se reconecta pidiendo el registro desde su último seq', () async {
    final canales = <CanalFalso>[];
    final aplicados = <int>[];
    nuevo(canales, aplicados: aplicados).conectar();
    await asentar();
    canales[0]
      ..recibir(mensajeSala())
      ..recibir(mensajeEvento(1, _turno))
      ..recibir(mensajeEvento(3, _otro)); // falta el 2
    await asentar();
    expect(aplicados, [1]);
    expect(canales[0].cerrado, isTrue);
    expect(canales, hasLength(2));
    expect(canales[1].enviados.single['ultimoSeq'], 1);
    canales[1]
      ..recibir(mensajeSala(ultimoSeq: 3))
      ..recibir({
        'tipo': 'registro',
        'desdeSeq': 2,
        'eventos': [eventoAJson(_otro), eventoAJson(_turno)],
      });
    await asentar();
    expect(aplicados, [1, 2, 3]);
  });

  test('si se corta la conexión se reabre sola y vuelve a decir hola', () async {
    final canales = <CanalFalso>[];
    final novedades = <NovedadSala>[];
    nuevo(canales, ultimoSeq: 4, novedades: novedades).conectar();
    await asentar();
    expect(canales[0].enviados.single['ultimoSeq'], 4);
    canales[0].cortar();
    await asentar();
    expect(canales, hasLength(2));
    expect(canales[1].de('hola'), hasLength(1));
    expect(
      novedades.whereType<ConexionCambiada>().map((c) => c.estado),
      contains(EstadoConexion.reconectando),
    );
  });

  test('un error fatal cierra el cliente y no se reintenta', () async {
    final canales = <CanalFalso>[];
    final novedades = <NovedadSala>[];
    final cliente = nuevo(canales, novedades: novedades)..conectar();
    await asentar();
    canales.single.recibir({'tipo': 'error', 'codigo': 'salaLlena', 'texto': 'llena'});
    await asentar();
    final error = novedades.whereType<ErrorDeSala>().single;
    expect([error.codigo, error.fatal], ['salaLlena', true]);
    expect(canales, hasLength(1));
    expect(canales.single.cerrado, isTrue);
    expect(cliente.conectada, isFalse);
  });

  test('una partida cancelada se avisa y se cierra', () async {
    final canales = <CanalFalso>[];
    final novedades = <NovedadSala>[];
    nuevo(canales, novedades: novedades).conectar();
    await asentar();
    canales.single.recibir(
        {'tipo': 'partidaCancelada', 'motivo': 'hostDesconectado'});
    await asentar();
    expect(novedades.whereType<PartidaCancelada>().single.motivo, 'hostDesconectado');
    expect(canales, hasLength(1));
  });

  test('contesta pong a los ping y cuenta las caídas y vueltas', () async {
    final canales = <CanalFalso>[];
    final novedades = <NovedadSala>[];
    nuevo(canales, novedades: novedades).conectar();
    await asentar();
    canales.single
      ..recibir(mensajeSala())
      ..recibir({'tipo': 'ping'})
      ..recibir({
        'tipo': 'jugadorDesconectado',
        'asiento': 1,
        'venceEn': '2026-11-18T22:02:00.000Z',
      })
      ..recibir({'tipo': 'jugadorVuelve', 'asiento': 1})
      ..recibir({'tipo': 'ventanaVencida', 'asiento': 1});
    await asentar();
    expect(canales.single.de('pong'), hasLength(1));
    expect(nombresDeAvisos(novedades), [
      'JugadorSeCae',
      'JugadorVuelve',
      'VentanaVencida',
    ]);
    expect(novedades.whereType<JugadorSeCae>().single.venceEn,
        DateTime.utc(2026, 11, 18, 22, 2));
  });

  group('jugador (no host)', () {
    test('la propuesta no se aplica hasta que el host la difunde', () async {
      final canales = <CanalFalso>[];
      final aplicados = <int>[];
      final cliente = nuevo(canales, aplicados: aplicados)..conectar();
      await asentar();
      canales.single.recibir(mensajeSala(tuAsiento: 1));
      await asentar();
      final id = cliente.proponer(_turno);
      await asentar();
      expect(id, 'id-1');
      expect(canales.single.de('proponer').single, {
        'tipo': 'proponer',
        'idMensaje': 'id-1',
        'evento': eventoAJson(_turno),
      });
      expect(aplicados, isEmpty);
      expect(cliente.propuestasPendientes, 1);
      canales.single.recibir(mensajeEvento(1, _turno, id: id));
      await asentar();
      expect(aplicados, [1]);
      expect(cliente.propuestasPendientes, 0);
    });

    test('la propuesta sin respuesta se repite con el mismo id tras reconectar', () async {
      final canales = <CanalFalso>[];
      final cliente = nuevo(canales)..conectar();
      await asentar();
      canales[0].recibir(mensajeSala(tuAsiento: 1));
      await asentar();
      cliente.proponer(_turno);
      canales[0].cortar();
      await asentar();
      canales[1].recibir(mensajeSala(tuAsiento: 1));
      await asentar();
      expect(canales[1].de('proponer'), hasLength(1));
      expect(canales[1].de('proponer').single['idMensaje'], 'id-1');
    });

    test('una propuesta antes de conectar se manda al conectar', () async {
      final canales = <CanalFalso>[];
      final cliente = nuevo(canales)..conectar();
      await asentar();
      cliente.proponer(_turno);
      expect(canales.single.de('proponer'), isEmpty);
      canales.single.recibir(mensajeSala(tuAsiento: 1));
      await asentar();
      expect(canales.single.de('proponer'), hasLength(1));
    });

    test('un rechazo se cuenta y quita la propuesta', () async {
      final canales = <CanalFalso>[];
      final novedades = <NovedadSala>[];
      final cliente = nuevo(canales, novedades: novedades)..conectar();
      await asentar();
      canales.single.recibir(mensajeSala(tuAsiento: 1));
      await asentar();
      final id = cliente.proponer(_turno);
      canales.single
          .recibir({'tipo': 'rechazar', 'idMensaje': id, 'motivo': 'no es tu turno'});
      await asentar();
      final r = novedades.whereType<PropuestaRechazada>().single;
      expect([r.idMensaje, r.motivo], [id, 'no es tu turno']);
      expect(cliente.propuestasPendientes, 0);
    });

    test('un jugador que no es el host no atiende propuestas ajenas', () async {
      final canales = <CanalFalso>[];
      nuevo(canales).conectar();
      await asentar();
      canales.single
        ..recibir(mensajeSala(tuAsiento: 1))
        ..recibir({
          'tipo': 'proponer',
          'idMensaje': 'x',
          'asiento': 2,
          'evento': eventoAJson(_turno),
        });
      await asentar();
      expect(canales.single.de('rechazar'), hasLength(1));
      expect(canales.single.de('aceptar'), isEmpty);
    });
  });

  group('host', () {
    late ClienteSala cliente;
    late List<CanalFalso> canales;
    late List<int> aplicados;
    var llamadas = 0;

    Future<void> arrancar() async {
      canales = <CanalFalso>[];
      aplicados = <int>[];
      llamadas = 0;
      cliente = nuevo(
        canales,
        aplicados: aplicados,
        alProponer: (asiento, evento) {
          llamadas++;
          if (evento is TurnoJugador && evento.dano > 500) return 'daño imposible';
          cliente.difundir(evento);
          return null;
        },
      )..conectar();
      await asentar();
      canales.single.recibir(mensajeSala());
      await asentar();
    }

    Map<String, Object?> propuesta(int asiento, Evento e, [String id = 'm-7']) => {
          'tipo': 'proponer',
          'idMensaje': id,
          'asiento': asiento,
          'evento': eventoAJson(e),
        };

    test('lo que acepta lleva el idMensaje de la propuesta y el siguiente seq', () async {
      await arrancar();
      canales.single.recibir(propuesta(1, _turno));
      await asentar();
      expect(canales.single.de('aceptar').single, {
        'tipo': 'aceptar',
        'seq': 1,
        'evento': eventoAJson(_turno),
        'idMensaje': 'm-7',
      });
      cliente.difundir(_otro); // un evento del propio host: sin idMensaje
      final propio = canales.single.de('aceptar').last;
      expect([propio['seq'], propio.containsKey('idMensaje')], [2, false]);
    });

    test('rechaza lo que el motor rechaza', () async {
      await arrancar();
      canales.single.recibir(propuesta(1, const TurnoJugador(jugador: 1, dano: 900)));
      await asentar();
      expect(canales.single.de('aceptar'), isEmpty);
      expect(canales.single.de('rechazar').single,
          {'tipo': 'rechazar', 'idMensaje': 'm-7', 'motivo': 'daño imposible'});
      expect(cliente.ultimoSeq, 0);
    });

    test('un jugador solo puede proponer su turno y su ataque a aliados', () async {
      await arrancar();
      canales.single
        ..recibir(propuesta(2, _turno, 'a')) // el evento es del asiento 1
        ..recibir(propuesta(1, const Abandonar(), 'b'))
        ..recibir(propuesta(1, const FinTurnoJefe(), 'c'));
      await asentar();
      expect(llamadas, 0);
      expect(canales.single.de('rechazar'), hasLength(3));
      canales.single.recibir(
        propuesta(1, const AtaqueAAliado(jugador: 1, slot: 0, dano: 30), 'd'),
      );
      await asentar();
      expect(llamadas, 1);
    });

    test('no vuelve a aplicar lo que él mismo difundió', () async {
      await arrancar();
      cliente.difundir(_turno);
      canales.single.recibir(mensajeEvento(1, _turno));
      await asentar();
      expect(aplicados, isEmpty);
      expect(cliente.ultimoSeq, 1);
    });
  });
}

List<String> nombresDeAvisos(List<NovedadSala> novedades) => [
      for (final n in novedades)
        if (n is JugadorSeCae || n is JugadorVuelve || n is VentanaVencida)
          n.runtimeType.toString(),
    ];
