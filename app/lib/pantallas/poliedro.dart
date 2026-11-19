import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Un punto o vector en 3D. Lo justo para girar y proyectar los dados.
class V3 {
  const V3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double k) => V3(x * k, y * k, z * k);
  V3 operator -() => V3(-x, -y, -z);

  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  V3 cross(V3 o) => V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get largo => sqrt(dot(this));
  V3 get unitario {
    final l = largo;
    return V3(x / l, y / l, z / l);
  }
}

/// Giro en 3D (matriz 3×3 por filas).
class Rot {
  Rot._(this._m);

  final List<double> _m;

  static final Rot identidad = Rot._([1, 0, 0, 0, 1, 0, 0, 0, 1]);

  /// Giro de [angulo] radianes alrededor de [eje].
  factory Rot.eje(V3 eje, double angulo) {
    final k = eje.unitario;
    final c = cos(angulo);
    final s = sin(angulo);
    final t = 1 - c;
    return Rot._([
      t * k.x * k.x + c, t * k.x * k.y - s * k.z, t * k.x * k.z + s * k.y, //
      t * k.x * k.y + s * k.z, t * k.y * k.y + c, t * k.y * k.z - s * k.x, //
      t * k.x * k.z - s * k.y, t * k.y * k.z + s * k.x, t * k.z * k.z + c,
    ]);
  }

  /// El giro más corto que lleva el vector unitario [a] sobre el [b].
  factory Rot.entre(V3 a, V3 b) {
    final d = a.dot(b).clamp(-1.0, 1.0).toDouble();
    if (d > 0.999999) return identidad;
    if (d < -0.999999) {
      // Opuestos: media vuelta sobre cualquier eje perpendicular.
      final p = a.cross(const V3(1, 0, 0));
      return Rot.eje(p.largo > 0.1 ? p : a.cross(const V3(0, 1, 0)), pi);
    }
    return Rot.eje(a.cross(b), acos(d));
  }

  /// Primero se aplica [o] y después este giro.
  Rot operator *(Rot o) {
    final r = List<double>.filled(9, 0);
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        var s = 0.0;
        for (var k = 0; k < 3; k++) {
          s += _m[i * 3 + k] * o._m[k * 3 + j];
        }
        r[i * 3 + j] = s;
      }
    }
    return Rot._(r);
  }

  V3 aplicar(V3 v) => V3(
        _m[0] * v.x + _m[1] * v.y + _m[2] * v.z,
        _m[3] * v.x + _m[4] * v.y + _m[5] * v.z,
        _m[6] * v.x + _m[7] * v.y + _m[8] * v.z,
      );
}

/// Una cara plana del dado con el valor que enseña.
class CaraPoliedro {
  CaraPoliedro({
    required this.vertices,
    required this.centro,
    required this.normal,
    required this.u,
    required this.valor,
  });

  final List<V3> vertices;
  final V3 centro;

  /// Hacia fuera del dado.
  final V3 normal;

  /// Eje horizontal de la cara (en su plano).
  final V3 u;
  final int valor;

  /// Eje vertical de la cara, hacia abajo, para que lo que se escriba en ella
  /// no salga reflejado.
  V3 get w => u.cross(normal).unitario;
}

/// Un dado: cubo (d6) o tetraedro (d4).
class Poliedro {
  Poliedro._(this.caras, {required this.esCubo});

  final List<CaraPoliedro> caras;
  final bool esCubo;

  /// Cubo. [valores] da el valor de sus 6 caras en este orden: +z, −z, +x,
  /// −x, +y, −y. Un d6 normal es `[1, 6, 2, 5, 3, 4]` (las opuestas suman 7).
  factory Poliedro.cubo(List<int> valores) {
    assert(valores.length == 6);
    const normales = [
      V3(0, 0, 1), V3(0, 0, -1), V3(1, 0, 0), V3(-1, 0, 0), //
      V3(0, 1, 0), V3(0, -1, 0),
    ];
    const ejesU = [
      V3(1, 0, 0), V3(1, 0, 0), V3(0, 1, 0), V3(0, 1, 0), //
      V3(1, 0, 0), V3(1, 0, 0),
    ];
    return Poliedro._([
      for (var i = 0; i < 6; i++)
        () {
          final n = normales[i];
          final u = ejesU[i];
          final v = n.cross(u);
          return CaraPoliedro(
            vertices: [n - u - v, n + u - v, n + u + v, n - u + v],
            centro: n,
            normal: n,
            u: u,
            valor: valores[i],
          );
        }(),
    ], esCubo: true);
  }

  /// Tetraedro. [valores] da el valor de sus 4 caras.
  factory Poliedro.tetraedro(List<int> valores) {
    assert(valores.length == 4);
    const t = [V3(1, 1, 1), V3(1, -1, -1), V3(-1, 1, -1), V3(-1, -1, 1)];
    return Poliedro._([
      for (var i = 0; i < 4; i++)
        () {
          final otros = [for (var j = 0; j < 4; j++) if (j != i) t[j]];
          return CaraPoliedro(
            vertices: otros,
            centro: -t[i] * (1 / 3),
            normal: (-t[i]).unitario,
            u: (otros[1] - otros[0]).unitario,
            valor: valores[i],
          );
        }(),
    ], esCubo: false);
  }

  /// La cara que enseña [valor] (la primera si hay varias).
  CaraPoliedro caraCon(int valor) =>
      caras.firstWhere((c) => c.valor == valor, orElse: () => caras.first);
}

/// El giro con el que el dado se queda quieto enseñando [cara] de frente, con
/// su texto derecho y un poco inclinado para que se vea que es un volumen.
Rot orientacionFinal(CaraPoliedro cara, {double inclinacion = 0.22}) {
  final alFrente = Rot.entre(cara.normal, const V3(0, 0, 1));
  final u = alFrente.aplicar(cara.u);
  final derecha = Rot.eje(const V3(0, 0, 1), -atan2(u.y, u.x));
  final inclinar = Rot.eje(const V3(1, 1, 0), inclinacion);
  return inclinar * derecha * alFrente;
}

const _puntos = <int, List<List<double>>>{
  1: [
    [0, 0],
  ],
  2: [
    [-0.5, -0.5],
    [0.5, 0.5],
  ],
  3: [
    [-0.5, -0.5],
    [0, 0],
    [0.5, 0.5],
  ],
  4: [
    [-0.5, -0.5],
    [0.5, -0.5],
    [-0.5, 0.5],
    [0.5, 0.5],
  ],
  5: [
    [-0.5, -0.5],
    [0.5, -0.5],
    [0, 0],
    [-0.5, 0.5],
    [0.5, 0.5],
  ],
  6: [
    [-0.5, -0.5],
    [-0.5, 0],
    [-0.5, 0.5],
    [0.5, -0.5],
    [0.5, 0],
    [0.5, 0.5],
  ],
};

/// Pinta un [Poliedro] girado con [rot], con perspectiva, caras sombreadas y
/// el valor de cada cara (puntos en el cubo, número en el tetraedro).
class PoliedroPainter extends CustomPainter {
  PoliedroPainter({
    required this.forma,
    required this.rot,
    required this.color,
    required this.escala,
  });

  final Poliedro forma;
  final Rot rot;
  final Color color;

  /// Píxeles por unidad del dado (el cubo mide 2 de arista).
  final double escala;

  static const _camara = 6.0;
  static const _luz = V3(-0.4, 0.6, 0.7);

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    Offset proyectar(V3 p) {
      final f = _camara / (_camara - p.z);
      return Offset(centro.dx + p.x * f * escala, centro.dy - p.y * f * escala);
    }

    final luz = _luz.unitario;
    for (final cara in forma.caras) {
      final n = rot.aplicar(cara.normal);
      final c3 = rot.aplicar(cara.centro);
      // Solo las caras que miran a la cámara.
      if (n.dot(const V3(0, 0, _camara) - c3) <= 0) continue;

      final contorno = Path()
        ..addPolygon([
          for (final v in cara.vertices) proyectar(rot.aplicar(v)),
        ], true);
      final brillo = 0.5 + 0.5 * max(0.0, n.dot(luz));
      canvas.drawPath(
        contorno,
        Paint()..color = Color.lerp(const Color(0xFF000000), color, brillo)!,
      );
      canvas.drawPath(
        contorno,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = max(1.5, escala * 0.1)
          ..color = Colors.white,
      );

      // El valor se dibuja en el plano de la cara: sus ejes proyectados dan la
      // transformación que lo inclina como a la cara.
      final o = proyectar(c3);
      final pu = proyectar(rot.aplicar(cara.centro + cara.u)) - o;
      final pw = proyectar(rot.aplicar(cara.centro + cara.w)) - o;
      const k = 0.01; // 100 unidades locales por unidad de dado
      canvas.save();
      canvas.transform(Float64List.fromList([
        pu.dx * k, pu.dy * k, 0, 0, //
        pw.dx * k, pw.dy * k, 0, 0, //
        0, 0, 1, 0, //
        o.dx, o.dy, 0, 1,
      ]));
      if (forma.esCubo) {
        final pintura = Paint()..color = Colors.white;
        for (final p in _puntos[cara.valor.clamp(1, 6)]!) {
          canvas.drawCircle(Offset(p[0] * 100, p[1] * 100), 17, pintura);
        }
      } else {
        final texto = TextPainter(
          text: TextSpan(
            text: '${cara.valor}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 80,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        texto.paint(canvas, Offset(-texto.width / 2, -texto.height / 2));
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(PoliedroPainter old) => true;
}
