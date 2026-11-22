import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/campana/widgets_campana.dart';
import 'package:incursiones_engine/campana.dart';

/// Tipos del TCG (D-20 §10.3, #404): la app pinta y nombra todos los tipos
/// del motor, metal incluido, y ninguno de los cinco que salieron.
void main() {
  test('cada tipo tiene color y nombre propios', () {
    final colores = TipoCampana.values.map(colorTipo).toSet();
    expect(colores.length, TipoCampana.values.length);
    expect(nombreTipo(TipoCampana.metal), 'metal');
    expect(nombreTipo(TipoCampana.oscuridad), 'oscuridad');
  });

  test('no quedan hielo, veneno, volador, bicho ni fantasma', () {
    final nombres = TipoCampana.values.map((t) => t.name).toSet();
    for (final fuera in ['hielo', 'veneno', 'volador', 'bicho', 'fantasma']) {
      expect(nombres.contains(fuera), isFalse, reason: fuera);
    }
  });
}
