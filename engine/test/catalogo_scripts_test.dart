import 'dart:convert';
import 'dart:io';

import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

/// Los jefes del catálogo (`catalog/bosses/`) son datos: este test comprueba
/// que cada aliado cuyos efectos aplica el programa apunta a un script que
/// existe en el motor (D-13).
void main() {
  test('los scriptId del catálogo existen en el motor', () {
    final carpeta = Directory('../catalog/bosses');
    if (!carpeta.existsSync()) return;
    final archivos = carpeta
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'));
    for (final archivo in archivos) {
      final jefe = jsonDecode(archivo.readAsStringSync()) as Map<String, Object?>;
      final invocacion = jefe['invocacion'] as Map<String, Object?>?;
      if (invocacion == null) continue;
      final aliados = invocacion['aliados'] as Map<String, Object?>;
      for (final entrada in aliados.entries) {
        final aliado = entrada.value as Map<String, Object?>;
        if (aliado['efectos'] != 'programa') continue;
        expect(
          scriptsAliado.containsKey(aliado['scriptId']),
          isTrue,
          reason: '${archivo.path}: el aliado ${entrada.key} usa el script '
              '«${aliado['scriptId']}», que no existe en el motor',
        );
      }
    }
  });
}
