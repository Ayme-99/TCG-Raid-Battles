import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'almacen/almacen.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registrarErrores();
  _mantenerPantallaEncendida();
  final preferencias = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        almacenProvider.overrideWithValue(AlmacenPreferencias(preferencias)),
      ],
      child: const IncursionesApp(),
    ),
  );
}

/// Recoge los errores que nadie ha capturado (de Flutter y asíncronos) para
/// que no desaparezcan sin dejar rastro. De momento solo se escriben en el
/// registro de la consola; aquí se enchufaría un servicio de informes.
void _registrarErrores() {
  final anterior = FlutterError.onError;
  FlutterError.onError = (detalles) {
    debugPrint('Error de Flutter: ${detalles.exceptionAsString()}');
    anterior?.call(detalles);
  };
  PlatformDispatcher.instance.onError = (error, pila) {
    debugPrint('Error no controlado: $error\n$pila');
    return true;
  };
}

/// La tablet está en medio de la mesa: que no se apague por inactividad.
/// Si la plataforma no lo permite, la app sigue funcionando igual.
Future<void> _mantenerPantallaEncendida() async {
  try {
    await WakelockPlus.enable();
  } catch (e) {
    debugPrint('No se pudo mantener la pantalla encendida: $e');
  }
}
