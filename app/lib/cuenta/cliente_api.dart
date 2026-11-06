import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'sesion.dart';

/// Dirección del servidor de Deck Tracker. Se cambia al compilar con
/// `--dart-define=API_URL=http://localhost:5000/api`.
const String urlApi = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://deck-tracker-server.onrender.com/api',
);

/// Error al hablar con el servidor, con un mensaje que se puede enseñar.
class ErrorApi implements Exception {
  const ErrorApi(this.mensaje, {this.estado});

  final String mensaje;
  final int? estado;

  @override
  String toString() => 'ErrorApi($estado): $mensaje';
}

/// Qué hacer con una partida tras intentar enviarla.
enum ResultadoEnvio {
  /// Guardada (201) o ya estaba guardada (200): se quita de la cola.
  guardada,

  /// El servidor la rechaza y reintentar no sirve (400, 403, 409, 422...).
  rechazada,

  /// El token ya no vale (401): hay que iniciar sesión otra vez.
  sesionCaducada,

  /// Sin conexión, servidor caído o saturado: se reintenta más tarde.
  reintentar,
}

class RespuestaEnvio {
  const RespuestaEnvio(this.resultado, [this.mensaje]);

  final ResultadoEnvio resultado;
  final String? mensaje;
}

/// Cliente HTTP del servidor de Deck Tracker (cuentas e Incursiones).
class ClienteApi {
  ClienteApi({
    required this.base,
    http.Client? cliente,
    // Render gratuito tarda hasta un minuto en despertar.
    this.espera = const Duration(seconds: 60),
  }) : _http = cliente ?? http.Client();

  final String base;
  final Duration espera;
  final http.Client _http;

  void cerrar() => _http.close();

  /// Inicia sesión con una cuenta de Deck Tracker.
  Future<Sesion> iniciarSesion(String usuario, String contrasena) async {
    final http.Response r;
    try {
      r = await _http
          .post(
            Uri.parse('$base/auth/login'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'username': usuario, 'password': contrasena}),
          )
          .timeout(espera);
    } catch (_) {
      throw const ErrorApi('No se pudo conectar con el servidor.');
    }
    final cuerpo = _cuerpo(r);
    if (r.statusCode == 200 &&
        cuerpo['token'] is String &&
        cuerpo['username'] is String &&
        cuerpo['userId'] != null) {
      return Sesion(
        token: cuerpo['token']! as String,
        username: cuerpo['username']! as String,
        userId: '${cuerpo['userId']}',
      );
    }
    if (r.statusCode == 401) {
      throw const ErrorApi('Usuario o contraseña incorrectos.', estado: 401);
    }
    if (r.statusCode == 429) {
      throw const ErrorApi(
        'Demasiados intentos. Espera unos minutos y vuelve a probar.',
        estado: 429,
      );
    }
    throw ErrorApi(
      '${cuerpo['error'] ?? 'El servidor respondió ${r.statusCode}.'}',
      estado: r.statusCode,
    );
  }

  /// Envía el registro de una partida terminada. Es idempotente en el
  /// servidor: repetirlo no suma los puntos dos veces.
  Future<RespuestaEnvio> enviarPartida(
    String token,
    Map<String, Object?> registro,
  ) async {
    final http.Response r;
    try {
      r = await _http
          .post(
            Uri.parse('$base/incursiones/partidas'),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode(registro),
          )
          .timeout(espera);
    } catch (_) {
      return const RespuestaEnvio(ResultadoEnvio.reintentar);
    }
    final estado = r.statusCode;
    if (estado == 200 || estado == 201) {
      return const RespuestaEnvio(ResultadoEnvio.guardada);
    }
    if (estado == 401) {
      return const RespuestaEnvio(ResultadoEnvio.sesionCaducada);
    }
    if (estado == 408 || estado == 429 || estado >= 500) {
      return const RespuestaEnvio(ResultadoEnvio.reintentar);
    }
    final cuerpo = _cuerpo(r);
    final mensaje = cuerpo['mensaje'] ?? cuerpo['error'];
    return RespuestaEnvio(
      ResultadoEnvio.rechazada,
      mensaje == null ? 'El servidor respondió $estado.' : '$mensaje',
    );
  }

  /// Cuerpo JSON de la respuesta, o vacío si no lo es (un 502 de Render, por
  /// ejemplo, responde con HTML).
  Map<String, Object?> _cuerpo(http.Response r) {
    try {
      final json = jsonDecode(utf8.decode(r.bodyBytes));
      if (json is Map) return Map<String, Object?>.from(json);
    } catch (_) {
      // No era JSON.
    }
    return const {};
  }
}

final clienteApiProvider = Provider<ClienteApi>((ref) {
  final cliente = ClienteApi(base: urlApi);
  ref.onDispose(cliente.cerrar);
  return cliente;
});
