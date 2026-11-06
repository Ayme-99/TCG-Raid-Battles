import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento local de texto por clave (sesión y cola de envíos).
///
/// Es una interfaz mínima para que el resto de la app no dependa de
/// `shared_preferences` y los tests usen uno en memoria.
abstract class Almacen {
  Future<String?> leer(String clave);
  Future<void> escribir(String clave, String valor);
  Future<void> borrar(String clave);
}

/// Almacén real: `shared_preferences` (Android, Windows y web).
class AlmacenPreferencias implements Almacen {
  AlmacenPreferencias(this._preferencias);

  final SharedPreferences _preferencias;

  @override
  Future<String?> leer(String clave) async => _preferencias.getString(clave);

  @override
  Future<void> escribir(String clave, String valor) async {
    await _preferencias.setString(clave, valor);
  }

  @override
  Future<void> borrar(String clave) async {
    await _preferencias.remove(clave);
  }
}

/// Almacén en memoria, para los tests.
class AlmacenMemoria implements Almacen {
  final Map<String, String> datos = {};

  @override
  Future<String?> leer(String clave) async => datos[clave];

  @override
  Future<void> escribir(String clave, String valor) async {
    datos[clave] = valor;
  }

  @override
  Future<void> borrar(String clave) async {
    datos.remove(clave);
  }
}

/// El almacén de la app. `main.dart` lo sustituye por el real; no tiene valor
/// por defecto para que ningún test guarde datos sin querer.
final almacenProvider = Provider<Almacen>(
  (ref) => throw UnimplementedError('almacenProvider debe sustituirse'),
);
