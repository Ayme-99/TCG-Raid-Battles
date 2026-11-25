import 'dart:convert';
import 'dart:io';

import 'package:incursiones_engine/campana.dart';
import 'package:test/test.dart';

/// Los ejemplos válidos del guardado en la cuenta (contrato/campana, #478)
/// tienen la forma de [PartidaCampana.aJson]: el motor los lee y los vuelve a
/// escribir igual. El servidor comprueba que cumplen el esquema
/// (server/test/campana_guardado.test.js).
void main() {
  final carpeta = Directory('../contrato/campana/ejemplos/guardado/validos');
  final archivos = carpeta
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();

  test('hay ejemplos', () => expect(archivos, isNotEmpty));

  for (final f in archivos) {
    test('${f.uri.pathSegments.last}: el motor lo lee y lo escribe igual', () {
      final cuerpo = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final json = cuerpo['partida'] as Map<String, dynamic>;
      final p = PartidaCampana.desdeJson(json);
      expect(p.aJson(), json);
    });
  }
}
