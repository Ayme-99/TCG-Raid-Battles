import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:incursiones_app/cuenta/cliente_api.dart';

ClienteApi cliente(Future<http.Response> Function(http.Request) servidor) =>
    ClienteApi(base: 'http://prueba/api', cliente: MockClient(servidor));

http.Response json(int estado, Object cuerpo) => http.Response(
      jsonEncode(cuerpo),
      estado,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('iniciarSesion', () {
    test('devuelve la sesión y envía usuario y contraseña', () async {
      late http.Request recibida;
      final api = cliente((p) async {
        recibida = p;
        return json(200, {'token': 't', 'username': 'ana', 'userId': 'u1'});
      });
      final sesion = await api.iniciarSesion('ana', 'secreto');
      expect(sesion.token, 't');
      expect(sesion.username, 'ana');
      expect(sesion.userId, 'u1');
      expect(recibida.url.path, '/api/auth/login');
      expect(jsonDecode(recibida.body), {'username': 'ana', 'password': 'secreto'});
    });

    test('credenciales malas: mensaje claro', () async {
      final api = cliente((_) async => json(401, {'error': 'Credenciales inválidas'}));
      expect(
        api.iniciarSesion('ana', 'mal'),
        throwsA(
          isA<ErrorApi>()
              .having((e) => e.estado, 'estado', 401)
              .having((e) => e.mensaje, 'mensaje', contains('incorrectos')),
        ),
      );
    });

    test('demasiados intentos (429)', () async {
      final api = cliente((_) async => json(429, {'error': 'Demasiados intentos.'}));
      expect(
        api.iniciarSesion('ana', 'x'),
        throwsA(isA<ErrorApi>().having((e) => e.estado, 'estado', 429)),
      );
    });

    test('una respuesta que no es JSON no rompe nada', () async {
      final api = cliente((_) async => http.Response('<html>Bad gateway</html>', 502));
      expect(
        api.iniciarSesion('ana', 'x'),
        throwsA(isA<ErrorApi>().having((e) => e.estado, 'estado', 502)),
      );
    });

    test('sin conexión', () async {
      final api = cliente((_) async => throw http.ClientException('sin red'));
      expect(
        api.iniciarSesion('ana', 'x'),
        throwsA(
          isA<ErrorApi>().having((e) => e.mensaje, 'mensaje', contains('conectar')),
        ),
      );
    });
  });

  group('enviarPartida', () {
    const registro = <String, Object?>{'version': 2, 'partidaId': 'p1'};

    test('envía el registro con el token', () async {
      late http.Request recibida;
      final api = cliente((p) async {
        recibida = p;
        return json(201, {'partidaId': 'p1'});
      });
      final r = await api.enviarPartida('mi-token', registro);
      expect(r.resultado, ResultadoEnvio.guardada);
      expect(recibida.url.path, '/api/incursiones/partidas');
      expect(recibida.headers['authorization'], 'Bearer mi-token');
      expect(jsonDecode(recibida.body), registro);
    });

    test('200 (ya estaba guardada) también es guardada', () async {
      final api = cliente((_) async => json(200, {'duplicada': true}));
      expect((await api.enviarPartida('t', registro)).resultado, ResultadoEnvio.guardada);
    });

    test('401: sesión caducada', () async {
      final api = cliente((_) async => json(401, {'error': 'Token inválido'}));
      expect(
        (await api.enviarPartida('t', registro)).resultado,
        ResultadoEnvio.sesionCaducada,
      );
    });

    test('errores del servidor, límite de peticiones y red: reintentar', () async {
      for (final estado in [408, 429, 500, 502, 503]) {
        final api = cliente((_) async => http.Response('', estado));
        expect(
          (await api.enviarPartida('t', registro)).resultado,
          ResultadoEnvio.reintentar,
          reason: 'estado $estado',
        );
      }
      final sinRed = cliente((_) async => throw http.ClientException('sin red'));
      expect(
        (await sinRed.enviarPartida('t', registro)).resultado,
        ResultadoEnvio.reintentar,
      );
    });

    test('400, 403, 409 y 422: rechazada, con el motivo del servidor', () async {
      for (final estado in [400, 403, 409, 422]) {
        final api = cliente(
          (_) async => json(estado, {'error': 'codigo', 'mensaje': 'no cuadra $estado'}),
        );
        final r = await api.enviarPartida('t', registro);
        expect(r.resultado, ResultadoEnvio.rechazada, reason: 'estado $estado');
        expect(r.mensaje, 'no cuadra $estado');
      }
    });
  });
}
