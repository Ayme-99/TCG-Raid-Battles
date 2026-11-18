import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Dirección del WebSocket de las salas a partir de la del API
/// (`https://host/api` → `wss://host/api/incursiones/ws`).
String urlSalaDe(String base) {
  final uri = Uri.parse(base);
  final limpia = uri.path.endsWith('/')
      ? uri.path.substring(0, uri.path.length - 1)
      : uri.path;
  return uri
      .replace(
        scheme: uri.scheme == 'https' ? 'wss' : 'ws',
        path: '$limpia/incursiones/ws',
      )
      .toString();
}

/// Una conexión con el servidor de salas. Existe para poder sustituirla por
/// una falsa en los tests.
abstract class CanalSala {
  /// Mensajes de texto que llegan. El flujo termina cuando se corta la
  /// conexión.
  Stream<String> get mensajes;

  void enviar(String texto);

  Future<void> cerrar();
}

/// Cómo se abre un canal hacia una dirección.
typedef FabricaCanal = CanalSala Function(Uri url);

/// Canal real, sobre `web_socket_channel` (vale en móvil, escritorio y web).
class CanalWebSocket implements CanalSala {
  CanalWebSocket(Uri url) : _canal = WebSocketChannel.connect(url);

  final WebSocketChannel _canal;

  @override
  Stream<String> get mensajes =>
      _canal.stream.where((m) => m is String).cast<String>();

  @override
  void enviar(String texto) => _canal.sink.add(texto);

  @override
  Future<void> cerrar() async {
    try {
      await _canal.sink.close();
    } catch (_) {
      // Ya estaba cerrado.
    }
  }
}

CanalSala abrirCanalWebSocket(Uri url) => CanalWebSocket(url);
