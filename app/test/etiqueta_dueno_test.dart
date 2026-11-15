import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/pantallas/paneles.dart';

void main() {
  test('etiquetaDueno: inicial del nombre y número de asiento', () {
    expect(etiquetaDueno('Jugador 1', 0), 'J1');
    expect(etiquetaDueno('Jugador 4', 3), 'J4');
    expect(etiquetaDueno('Antonio', 1), 'A2');
    expect(etiquetaDueno('  ana', 2), 'A3');
    expect(etiquetaDueno('', 0), '?1');
  });
}
