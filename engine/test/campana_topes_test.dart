import 'dart:convert';
import 'dart:io';

import 'package:incursiones_engine/campana.dart';
import 'package:test/test.dart';

/// El servidor no abona más puntos por hito que su tope
/// (catalog/campana/topes-puntos.json, #374). Si el motor diera más, la cuenta
/// perdería puntos sin avisar: este test obliga a subir el tope a la vez.
void main() {
  test('los puntos de cada hito caben en su tope del servidor', () {
    final json = jsonDecode(
            File('../catalog/campana/topes-puntos.json').readAsStringSync())
        as Map<String, dynamic>;
    final topes = (json['topes'] as Map<String, dynamic>).cast<String, int>();
    const p = ParametrosCampana();
    expect(p.puntosSalvaje, lessThanOrEqualTo(topes['salvaje']!));
    expect(p.puntosEntrenador, lessThanOrEqualTo(topes['entrenador']!));
    expect(p.puntosJefe, lessThanOrEqualTo(topes['jefe']!));
    expect(p.puntosMedalla, lessThanOrEqualTo(topes['medalla']!));
  });
}
