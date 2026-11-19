import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/pantallas/poliedro.dart';

void main() {
  test('Rot.entre lleva un vector sobre otro', () {
    final a = const V3(1, 2, 3).unitario;
    final b = const V3(-2, 0.5, 1).unitario;
    final r = Rot.entre(a, b).aplicar(a);
    expect(r.x, closeTo(b.x, 1e-9));
    expect(r.y, closeTo(b.y, 1e-9));
    expect(r.z, closeTo(b.z, 1e-9));
  });

  test('Rot.entre con vectores opuestos da la vuelta', () {
    final r = Rot.entre(const V3(0, 0, 1), const V3(0, 0, -1))
        .aplicar(const V3(0, 0, 1));
    expect(r.z, closeTo(-1, 1e-9));
  });

  test('el d6 tiene las seis caras y las opuestas suman 7', () {
    final d6 = Poliedro.cubo(const [1, 6, 2, 5, 3, 4]);
    expect(d6.caras.map((c) => c.valor).toSet(), {1, 2, 3, 4, 5, 6});
    for (var i = 0; i < 6; i += 2) {
      expect(d6.caras[i].valor + d6.caras[i + 1].valor, 7);
    }
  });

  test('el d4 es un tetraedro regular: cuatro caras de normales opuestas', () {
    final d4 = Poliedro.tetraedro(const [1, 2, 3, 4]);
    expect(d4.caras, hasLength(4));
    var x = 0.0, y = 0.0, z = 0.0;
    for (final c in d4.caras) {
      expect(c.normal.largo, closeTo(1, 1e-9));
      expect(c.vertices, hasLength(3));
      // La normal sale del centro de la cara hacia fuera.
      expect(c.normal.dot(c.centro), greaterThan(0));
      // Y el eje de la cara está en su plano.
      expect(c.u.dot(c.normal), closeTo(0, 1e-9));
      x += c.normal.x;
      y += c.normal.y;
      z += c.normal.z;
    }
    expect(x, closeTo(0, 1e-9));
    expect(y, closeTo(0, 1e-9));
    expect(z, closeTo(0, 1e-9));
  });

  test('el dado se para con la cara del resultado de frente', () {
    for (final forma in [
      Poliedro.cubo(const [1, 6, 2, 5, 3, 4]),
      Poliedro.cubo(const [1, 1, 2, 2, 3, 3]),
      Poliedro.tetraedro(const [1, 2, 3, 4]),
      Poliedro.tetraedro(const [1, 2, 1, 2]),
    ]) {
      for (final cara in forma.caras) {
        for (final inclinacion in [0.22, -0.22]) {
          final n = orientacionFinal(cara, inclinacion: inclinacion)
              .aplicar(cara.normal);
          // Mira a la cámara (+z) con una inclinación pequeña.
          expect(n.z, greaterThan(0.9));
        }
      }
    }
  });

  test('con valores repetidos se elige la primera cara con ese valor', () {
    final d3 = Poliedro.cubo(const [1, 1, 2, 2, 3, 3]);
    expect(identical(d3.caraCon(2), d3.caras[2]), isTrue);
    expect(identical(d3.caraCon(9), d3.caras.first), isTrue);
  });
}
