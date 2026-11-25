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

/// Qué ha pasado al enviar hitos de campaña: si se han guardado, [ids] son
/// los que la cuenta ya tiene.
class RespuestaHitos {
  const RespuestaHitos(this.resultado, {this.ids = const [], this.mensaje});

  final ResultadoEnvio resultado;
  final List<String> ids;
  final String? mensaje;
}

/// Un nivel de jefe y si la cuenta ya lo tiene desbloqueado (D-10, D-21 §1.2).
class NivelJefe {
  const NivelJefe({
    required this.nivel,
    required this.coste,
    required this.alcanzado,
    required this.faltan,
  });

  final int nivel;
  final int coste;
  final bool alcanzado;
  final int faltan;
}

/// Los puntos de la cuenta: un solo total que sube al ganar y baja al comprar.
/// Un jefe desbloqueado no se vuelve a bloquear (opción C de Ayme).
class PuntosCuenta {
  const PuntosCuenta({required this.puntos, this.niveles = const []});

  factory PuntosCuenta.desdeJson(Map<String, Object?> json) {
    final niveles = json['niveles'];
    return PuntosCuenta(
      puntos: (json['puntos'] as num?)?.toInt() ?? 0,
      niveles: [
        if (niveles is List)
          for (final n in niveles)
            if (n is Map)
              NivelJefe(
                nivel: (n['nivel'] as num).toInt(),
                coste: (n['coste'] as num).toInt(),
                alcanzado: n['alcanzado'] == true,
                faltan: (n['faltan'] as num?)?.toInt() ?? 0,
              ),
      ],
    );
  }

  final int puntos;
  final List<NivelJefe> niveles;

  /// El primer nivel de jefe que aún no está desbloqueado, o null.
  NivelJefe? get proximoJefe {
    for (final n in niveles) {
      if (!n.alcanzado) return n;
    }
    return null;
  }
}

/// Un producto de la tienda de puntos.
class ProductoTienda {
  const ProductoTienda({
    required this.id,
    required this.familia,
    required this.nombre,
    required this.precio,
    required this.disponible,
  });

  factory ProductoTienda.desdeJson(Map<String, Object?> json) => ProductoTienda(
        id: '${json['id']}',
        familia: '${json['familia']}',
        nombre: '${json['nombre']}',
        precio: (json['precio'] as num?)?.toInt() ?? 0,
        disponible: json['disponible'] == true,
      );

  final String id;
  final String familia;
  final String nombre;
  final int precio;
  final bool disponible;
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

  /// Envía los hitos de campaña ganados en la partida [partida] para que la
  /// cuenta abone sus puntos (#374, contrato/campana/hitos.v1.schema.json). Es
  /// idempotente: un hito ya abonado vuelve como repetido y no suma otra vez.
  /// Si va bien, [RespuestaHitos.ids] son los que ya están en la cuenta
  /// (abonados ahora o antes).
  Future<RespuestaHitos> enviarHitos(
    String token, {
    required String campana,
    required String partida,
    required List<Map<String, Object?>> hitos,
  }) async {
    final http.Response r;
    try {
      r = await _http
          .post(
            Uri.parse('$base/incursiones/campana/hitos'),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'version': 1,
              'campana': campana,
              'partida': partida,
              'hitos': hitos,
            }),
          )
          .timeout(espera);
    } catch (_) {
      return const RespuestaHitos(ResultadoEnvio.reintentar);
    }
    final estado = r.statusCode;
    final cuerpo = _cuerpo(r);
    if (estado == 200 || estado == 201) {
      List<String> lista(Object? v) =>
          v is List ? [for (final e in v) '$e'] : const [];
      return RespuestaHitos(
        ResultadoEnvio.guardada,
        ids: [...lista(cuerpo['abonados']), ...lista(cuerpo['repetidos'])],
      );
    }
    if (estado == 401) {
      return const RespuestaHitos(ResultadoEnvio.sesionCaducada);
    }
    if (estado == 408 || estado == 429 || estado >= 500) {
      return const RespuestaHitos(ResultadoEnvio.reintentar);
    }
    final mensaje = cuerpo['mensaje'] ?? cuerpo['error'];
    return RespuestaHitos(
      ResultadoEnvio.rechazada,
      mensaje: mensaje == null ? 'El servidor respondió $estado.' : '$mensaje',
    );
  }

  /// GET autenticado que devuelve el cuerpo JSON, o lanza [ErrorApi].
  Future<Map<String, Object?>> _leer(String token, String ruta) async {
    final http.Response r;
    try {
      r = await _http.get(
        Uri.parse('$base$ruta'),
        headers: {'authorization': 'Bearer $token'},
      ).timeout(espera);
    } catch (_) {
      throw const ErrorApi('No se pudo conectar con el servidor.');
    }
    final cuerpo = _cuerpo(r);
    if (r.statusCode == 200) return cuerpo;
    if (r.statusCode == 401) {
      throw const ErrorApi(
        'La sesión ha caducado. Inicia sesión otra vez.',
        estado: 401,
      );
    }
    throw ErrorApi(
      '${cuerpo['mensaje'] ?? cuerpo['error'] ?? 'El servidor respondió ${r.statusCode}.'}',
      estado: r.statusCode,
    );
  }

  /// El total de puntos de la cuenta y los niveles de jefe (D-21 §1.2).
  Future<PuntosCuenta> leerPuntos(String token) async =>
      PuntosCuenta.desdeJson(await _leer(token, '/incursiones/me/puntos'));

  /// El catálogo de la tienda (catalog/tienda/tienda.json en el servidor).
  Future<List<ProductoTienda>> leerTienda(String token) async {
    final cuerpo = await _leer(token, '/incursiones/tienda');
    final lista = cuerpo['productos'];
    return [
      if (lista is List)
        for (final p in lista)
          if (p is Map) ProductoTienda.desdeJson(Map<String, Object?>.from(p)),
    ];
  }

  /// Los productos que ya tiene la cuenta.
  Future<Set<String>> leerComprados(String token) async {
    final lista = (await _leer(token, '/incursiones/tienda/compras'))['productos'];
    return {if (lista is List) for (final p in lista) '$p'};
  }

  /// Compra [producto] con el id [compra], que genera la app: repetir la
  /// misma compra no cobra dos veces. Devuelve el total de puntos tras pagar,
  /// o lanza [ErrorApi] con un mensaje para enseñar (sin conexión, sin
  /// puntos, ya comprado...).
  Future<int> comprar(
    String token, {
    required String compra,
    required String producto,
  }) async {
    final http.Response r;
    try {
      r = await _http
          .post(
            Uri.parse('$base/incursiones/tienda/compras'),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode(
                {'version': 1, 'compra': compra, 'producto': producto}),
          )
          .timeout(espera);
    } catch (_) {
      throw const ErrorApi('No se pudo conectar con el servidor.');
    }
    final cuerpo = _cuerpo(r);
    final puntos = cuerpo['puntos'];
    if ((r.statusCode == 200 || r.statusCode == 201) && puntos is int) {
      return puntos;
    }
    final mensaje = switch (cuerpo['error']) {
      'puntos_insuficientes' => 'No tienes puntos suficientes.',
      'ya_comprado' => 'Ya lo tienes.',
      'no_disponible' => 'Todavía no se vende.',
      'producto_gratis' => 'Es gratis: ya lo tienes.',
      'producto_desconocido' => 'La tienda ya no tiene ese producto.',
      _ when r.statusCode == 401 =>
        'La sesión ha caducado. Inicia sesión otra vez.',
      _ => '${cuerpo['mensaje'] ?? 'El servidor respondió ${r.statusCode}.'}',
    };
    throw ErrorApi(mensaje, estado: r.statusCode);
  }

  /// Crea una sala (el que la crea es el host). Devuelve el código de 5
  /// caracteres que se comparte con los demás jugadores.
  Future<String> crearSala(String token) async {
    final http.Response r;
    try {
      r = await _http.post(
        Uri.parse('$base/incursiones/salas'),
        headers: {'authorization': 'Bearer $token'},
      ).timeout(espera);
    } catch (_) {
      throw const ErrorApi('No se pudo conectar con el servidor.');
    }
    final cuerpo = _cuerpo(r);
    if (r.statusCode == 201 && cuerpo['codigo'] is String) {
      return cuerpo['codigo']! as String;
    }
    if (r.statusCode == 401) {
      throw const ErrorApi(
        'La sesión ha caducado. Inicia sesión otra vez.',
        estado: 401,
      );
    }
    if (r.statusCode == 409) {
      throw ErrorApi(
        'Ya estás en una sala (${cuerpo['codigo'] ?? 'sin código'}).',
        estado: 409,
      );
    }
    throw ErrorApi(
      '${cuerpo['mensaje'] ?? cuerpo['error'] ?? 'El servidor respondió ${r.statusCode}.'}',
      estado: r.statusCode,
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
