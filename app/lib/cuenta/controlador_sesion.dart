import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../almacen/almacen.dart';
import 'cliente_api.dart';
import 'sesion.dart';

const String _claveSesion = 'sesion';

/// La sesión iniciada (o `null`). Se lee del dispositivo al arrancar.
class ControladorSesion extends AsyncNotifier<Sesion?> {
  @override
  Future<Sesion?> build() async {
    final texto = await ref.read(almacenProvider).leer(_claveSesion);
    if (texto == null) return null;
    try {
      return Sesion.deJson(Map<String, Object?>.from(jsonDecode(texto) as Map));
    } catch (_) {
      return null; // Datos estropeados: se pide iniciar sesión otra vez.
    }
  }

  /// Inicia sesión. Devuelve `null` si ha ido bien o el mensaje del fallo.
  Future<String?> iniciarSesion(String usuario, String contrasena) async {
    try {
      final sesion =
          await ref.read(clienteApiProvider).iniciarSesion(usuario, contrasena);
      await ref
          .read(almacenProvider)
          .escribir(_claveSesion, jsonEncode(sesion.toJson()));
      state = AsyncData(sesion);
      return null;
    } on ErrorApi catch (e) {
      return e.mensaje;
    }
  }

  Future<void> cerrarSesion() async {
    await ref.read(almacenProvider).borrar(_claveSesion);
    state = const AsyncData(null);
  }
}

final sesionProvider =
    AsyncNotifierProvider<ControladorSesion, Sesion?>(ControladorSesion.new);

/// La sesión actual, o `null` si no hay (o aún se está leyendo).
final sesionActualProvider = Provider<Sesion?>(
  (ref) => ref.watch(sesionProvider).valueOrNull,
);
