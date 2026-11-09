import 'dart:math';

import 'package:flutter/material.dart';

/// Tapete de la mesa dibujado como un mapa de juego (T-48): terreno, lago,
/// camino de tierra y la arena del jefe con su aura. Se pinta sobre un lienzo
/// mucho mayor que la mesa ([margen] por cada lado) para que la cámara no
/// enseñe nunca el borde al acercarse.
class MapaPainter extends CustomPainter {
  const MapaPainter({this.margen = 2000});

  final double margen;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(margen, margen);
    final w = size.width - 2 * margen;
    final h = size.height - 2 * margen;
    final mesa = Rect.fromLTWH(0, 0, w, h);

    // Terreno: del verde azulado del fondo al verde claro de primer plano.
    canvas.drawRect(
      Rect.fromLTWH(-margen, -margen, w + 2 * margen, h + 2 * margen),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E6F5C), Color(0xFF4CAF6A), Color(0xFF9CDB6B)],
        ).createShader(mesa),
    );

    final azar = Random(11);
    // Manchas de hierba clara.
    for (var i = 0; i < 40; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(azar.nextDouble() * w * 1.4 - w * 0.2,
              azar.nextDouble() * h * 1.2 - h * 0.1),
          width: w * (0.08 + azar.nextDouble() * 0.12),
          height: h * (0.03 + azar.nextDouble() * 0.05),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.08),
      );
    }

    // Lago a la izquierda.
    final lago = Rect.fromCenter(
      center: Offset(w * 0.1, h * 0.7),
      width: w * 0.26,
      height: h * 0.16,
    );
    canvas.drawOval(lago.inflate(8), Paint()..color = const Color(0xFFE0F7FA));
    canvas.drawOval(lago, Paint()..color = const Color(0xFF29B6F6));
    canvas.drawOval(
      lago.deflate(lago.height * 0.25),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );

    // Camino de tierra desde abajo hasta la arena.
    final camino = Path()
      ..moveTo(w * 0.5, h * 1.05)
      ..cubicTo(w * 0.3, h * 0.9, w * 0.72, h * 0.78, w * 0.5, h * 0.5);
    canvas.drawPath(
      camino,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w * 0.09
        ..color = const Color(0xFF8D6E4A),
    );
    canvas.drawPath(
      camino,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w * 0.07
        ..color = const Color(0xFFF0D8A0),
    );

    // Árboles a los lados, lejos del centro.
    for (var i = 0; i < 28; i++) {
      final izquierda = i.isEven;
      final x = izquierda
          ? azar.nextDouble() * w * 0.16
          : w * (0.84 + azar.nextDouble() * 0.16);
      final y = azar.nextDouble() * h;
      final r = w * (0.025 + azar.nextDouble() * 0.02);
      canvas.drawCircle(
        Offset(x + r * 0.2, y + r * 0.35),
        r,
        Paint()..color = Colors.black.withValues(alpha: 0.2),
      );
      canvas.drawCircle(Offset(x, y), r, Paint()..color = const Color(0xFF2E7D32));
      canvas.drawCircle(
        Offset(x - r * 0.3, y - r * 0.3),
        r * 0.55,
        Paint()..color = const Color(0xFF66BB6A),
      );
    }

    // Arena del jefe: aura, anillo de piedra y runas.
    final centro = Offset(w * 0.5, h * 0.27);
    final arena = Rect.fromCenter(center: centro, width: w * 0.8, height: h * 0.5);
    canvas.drawOval(
      arena.inflate(w * 0.06),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFB388FF).withValues(alpha: 0.55),
            const Color(0xFFB388FF).withValues(alpha: 0),
          ],
        ).createShader(arena.inflate(w * 0.06)),
    );
    canvas.drawOval(arena, Paint()..color = const Color(0xFF5E4B8B));
    canvas.drawOval(
      arena.deflate(w * 0.015),
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF9575CD), Color(0xFF4527A0)],
        ).createShader(arena),
    );
    canvas.drawOval(
      arena.deflate(w * 0.05),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 0.35),
    );
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * 2 * pi;
      canvas.drawCircle(
        Offset(centro.dx + cos(a) * arena.width * 0.43,
            centro.dy + sin(a) * arena.height * 0.43),
        5,
        Paint()..color = const Color(0xFFFFEB3B),
      );
    }

    // Piedras sueltas.
    for (var i = 0; i < 10; i++) {
      final p = Offset(azar.nextDouble() * w, h * (0.55 + azar.nextDouble() * 0.4));
      canvas.drawOval(
        Rect.fromCenter(center: p, width: w * 0.03, height: w * 0.02),
        Paint()..color = const Color(0xFF9E9E9E),
      );
    }
  }

  @override
  bool shouldRepaint(MapaPainter old) => old.margen != margen;
}
