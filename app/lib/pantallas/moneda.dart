import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cómo se ve una moneda (T-73). Todas las monedas del juego se pintan con el
/// diseño elegido, así que cambiar de moneda cambia todas a la vez. Cada
/// diseño solo tiene que saber dibujar su cara y su cruz (cuadradas, de
/// [lado] × [lado]) y el color de su canto; el giro, el grosor, el brillo y la
/// caída sobre la mesa los pone el juego.
///
/// Pensado para las monedas personalizadas de la tienda: un diseño nuevo es
/// una [DisenoMoneda.deImagenes] con dos imágenes y un color de canto.
class DisenoMoneda {
  const DisenoMoneda({
    required this.id,
    required this.nombre,
    required this.canto,
    required this.cara,
    required this.cruz,
  });

  /// Diseño con una imagen por lado (webp/png cuadrados con fondo
  /// transparente fuera del círculo, o a sangre: se recortan en círculo).
  factory DisenoMoneda.deImagenes({
    required String id,
    required String nombre,
    required ImageProvider cara,
    required ImageProvider cruz,
    Color canto = const Color(0xFF9A7B1E),
  }) {
    Widget lado(ImageProvider imagen) => ClipOval(
          child: Image(
            image: imagen,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.grey),
          ),
        );
    return DisenoMoneda(
      id: id,
      nombre: nombre,
      canto: canto,
      cara: (_) => lado(cara),
      cruz: (_) => lado(cruz),
    );
  }

  final String id;
  final String nombre;

  /// Color del canto (el grosor de la moneda cuando gira).
  final Color canto;

  /// Las dos caras, para un círculo de lado `lado`.
  final Widget Function(double lado) cara;
  final Widget Function(double lado) cruz;
}

/// La moneda de siempre: oro con una bola roja y blanca en la cara y una
/// estrella de cuatro puntas (una cruz) sobre azul noche en la cruz.
final monedaClasica = DisenoMoneda(
  id: 'clasica',
  nombre: 'Moneda clásica',
  canto: const Color(0xFFA9771A),
  cara: (lado) => SizedBox.square(
    dimension: lado,
    child: CustomPaint(painter: _PintorMoneda(cara: true)),
  ),
  cruz: (lado) => SizedBox.square(
    dimension: lado,
    child: CustomPaint(painter: _PintorMoneda(cara: false)),
  ),
);

/// Las monedas que se pueden usar. La tienda irá añadiendo las suyas.
final disenosDeMoneda = <String, DisenoMoneda>{
  monedaClasica.id: monedaClasica,
};

/// La moneda que usa el juego ahora mismo.
final disenoMonedaProvider = StateProvider<DisenoMoneda>((ref) => monedaClasica);

/// Una moneda con volumen: [angulo] es el giro sobre su eje horizontal en
/// radianes. Con 0 se ve la cara de frente; con π, la cruz; con π/2, de canto.
/// Si cambia el ángulo, cambian el alto aparente, el grosor del canto y el
/// brillo que la recorre.
class MonedaWidget extends StatelessWidget {
  const MonedaWidget({
    super.key,
    required this.diseno,
    required this.lado,
    this.angulo = 0,
  });

  final DisenoMoneda diseno;
  final double lado;
  final double angulo;

  /// Alto del widget: el círculo y el hueco del canto.
  static double altoPara(double lado) => lado * 1.1;

  @override
  Widget build(BuildContext context) {
    final c = math.cos(angulo);
    final alto = math.max(0.04, c.abs());
    final grosor = lado * 0.09 * math.sin(angulo).abs();
    final cara = c >= 0;
    // El brillo recorre la moneda de lado a lado en cada vuelta.
    final f = (angulo / (2 * math.pi)) % 1.0;
    return SizedBox(
      width: lado,
      height: altoPara(lado),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: lado * 0.05 + grosor,
            width: lado,
            height: lado,
            child: Transform.scale(
              scaleY: alto,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: diseno.canto,
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 4),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: lado * 0.05,
            width: lado,
            height: lado,
            child: Transform.scale(
              scaleY: alto,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  cara ? diseno.cara(lado) : diseno.cruz(lado),
                  IgnorePointer(
                    child: ClipOval(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-1.8 + 3.6 * f, -1),
                            end: Alignment(-0.6 + 3.6 * f, 1),
                            colors: const [
                              Color(0x00FFFFFF),
                              Color(0x44FFFFFF),
                              Color(0x00FFFFFF),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinta las dos caras de la moneda clásica.
class _PintorMoneda extends CustomPainter {
  const _PintorMoneda({required this.cara});

  final bool cara;

  static const _oscuro = Color(0xFF8A5A0B);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final o = Offset(r, r);
    _aro(canvas, o, r);
    if (cara) {
      _pintarCara(canvas, o, r);
    } else {
      _pintarCruz(canvas, o, r);
    }
  }

  /// El aro dorado con el borde estriado de las monedas.
  void _aro(Canvas c, Offset o, double r) {
    c.drawCircle(
      o,
      r,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFFE08A),
            Color(0xFFE0A526),
            Color(0xFFFFF0B8),
            Color(0xFFD99A1E),
            Color(0xFFFFE08A),
          ],
        ).createShader(Rect.fromCircle(center: o, radius: r)),
    );
    c.drawCircle(
      o,
      r - r * 0.02,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..color = _oscuro,
    );
    final estria = Paint()
      ..strokeWidth = r * 0.025
      ..color = const Color(0x66784A06);
    for (var i = 0; i < 44; i++) {
      final a = i * 2 * math.pi / 44;
      c.drawLine(
        o + Offset(math.cos(a), math.sin(a)) * (r * 0.86),
        o + Offset(math.cos(a), math.sin(a)) * (r * 0.95),
        estria,
      );
    }
    c.drawCircle(
      o,
      r * 0.80,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03
        ..color = _oscuro,
    );
  }

  void _pintarCara(Canvas c, Offset o, double r) {
    c.drawCircle(
      o,
      r * 0.78,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF1B5), Color(0xFFF4BE3C)],
        ).createShader(Rect.fromCircle(center: o, radius: r * 0.78)),
    );
    // La bola: roja arriba, blanca abajo.
    final rb = r * 0.56;
    final bola = Rect.fromCircle(center: o, radius: rb);
    c.save();
    c.clipPath(Path()..addOval(bola));
    c.drawRect(
      Rect.fromLTRB(o.dx - rb, o.dy - rb, o.dx + rb, o.dy),
      Paint()..color = const Color(0xFFE53935),
    );
    c.drawRect(
      Rect.fromLTRB(o.dx - rb, o.dy, o.dx + rb, o.dy + rb),
      Paint()..color = const Color(0xFFF7F7F7),
    );
    // Brillo en la parte roja.
    c.drawOval(
      Rect.fromCenter(
        center: o + Offset(-rb * 0.42, -rb * 0.5),
        width: rb * 0.55,
        height: rb * 0.3,
      ),
      Paint()..color = const Color(0x66FFFFFF),
    );
    c.restore();
    final tinta = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.075
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF26212E);
    c.drawCircle(o, rb, tinta);
    c.drawLine(o + Offset(-rb, 0), o + Offset(rb, 0), tinta);
    // El botón del centro.
    c.drawCircle(o, r * 0.19, Paint()..color = const Color(0xFF26212E));
    c.drawCircle(o, r * 0.12, Paint()..color = const Color(0xFFFFFFFF));
    c.drawCircle(
      o,
      r * 0.12,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03
        ..color = const Color(0xFFB9B4C4),
    );
  }

  void _pintarCruz(Canvas c, Offset o, double r) {
    c.drawCircle(
      o,
      r * 0.78,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF4A47A8), Color(0xFF16133F)],
        ).createShader(Rect.fromCircle(center: o, radius: r * 0.78)),
    );
    // Puntitos de luz en las diagonales.
    final punto = Paint()..color = const Color(0xFFFFD866);
    for (final a in [math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4]) {
      c.drawCircle(o + Offset(math.cos(a), math.sin(a)) * (r * 0.5), r * 0.045, punto);
    }
    // La cruz: una estrella de cuatro puntas.
    final largo = r * 0.66;
    final cintura = r * 0.17;
    final estrella = Path();
    for (var i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * math.pi / 4;
      final radio = i.isEven ? largo : cintura;
      final p = o + Offset(math.cos(a), math.sin(a)) * radio;
      if (i == 0) {
        estrella.moveTo(p.dx, p.dy);
      } else {
        estrella.lineTo(p.dx, p.dy);
      }
    }
    estrella.close();
    c.drawPath(
      estrella,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF1B5), Color(0xFFE9A920)],
        ).createShader(Rect.fromCircle(center: o, radius: largo)),
    );
    c.drawPath(
      estrella,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03
        ..strokeJoin = StrokeJoin.round
        ..color = _oscuro,
    );
    c.drawCircle(o, r * 0.07, Paint()..color = const Color(0xFF16133F));
  }

  @override
  bool shouldRepaint(_PintorMoneda old) => old.cara != cara;
}
