import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/campana/catalogo_campana.dart';
import 'package:incursiones_app/campana/escenas.dart';
import 'package:incursiones_engine/campana.dart';

/// Escenas del mapa (#413): el catálogo de la app las trae válidas y, mientras
/// Arte no entrega los fondos, se pinta el marcador.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('las escenas del catálogo de la app son válidas', () async {
    final c = await cargarCatalogoCampana(rootBundle);
    expect(c.region.problemasDeEscenas(), isEmpty);
    expect(c.problemas(), isEmpty);
    for (final n in c.region.nodos.values) {
      expect(n.escena, isNotNull, reason: n.id);
    }
  });

  test('sin el fondo de Arte se usa el marcador, que existe', () async {
    expect(File(marcadorEscena).existsSync(), isTrue);
    expect((await rootBundle.load(marcadorEscena)).lengthInBytes, greaterThan(0));
    const escena = EscenaNodo(imagen: 'ruta-1');
    expect(imagenDeEscena(escena, const {}), marcadorEscena);
    expect(
        imagenDeEscena(escena, const {'assets/campana/escenas/ruta-1.webp'}),
        'assets/campana/escenas/ruta-1.webp');
  });

  test('los fondos propios no se mezclan con los sprites ajenos', () {
    expect(carpetaEscenas, isNot(contains('sprites_ajenos')));
  });
}
