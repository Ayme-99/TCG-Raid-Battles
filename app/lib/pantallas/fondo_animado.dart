import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Si el inicio anima el fondo. Los tests lo apagan: una animación sin fin
/// impide que `pumpAndSettle` termine.
final fondoAnimadoProvider = Provider<bool>((ref) => true);

/// Qué se anima encima de la imagen.
enum EfectoFondo {
  /// Ruta 110, bajo tormenta: lluvia y relámpagos.
  tormenta,

  /// Sala Origen: partículas de luz doradas y bruma.
  luz,
}

/// Fondo de la pantalla de inicio (#239): la imagen con un movimiento lento y
/// un efecto ligero encima. Ligero a propósito: un solo controlador, un solo
/// `CustomPainter` en su propia capa, unas decenas de trazos.
///
/// - Se detiene solo cuando la pantalla queda tapada por otra (el `Ticker` va
///   atado a `TickerMode`) y cuando la app pasa a segundo plano.
/// - Con «reducir movimiento» del sistema (o `fondoAnimadoProvider` apagado) se
///   queda la imagen quieta.
class FondoAnimado extends ConsumerStatefulWidget {
  const FondoAnimado({
    super.key,
    required this.imagen,
    required this.efecto,
    this.velo = Colors.transparent,
  });

  final String imagen;
  final EfectoFondo efecto;

  /// Color que se pone encima de todo para que el texto se lea.
  final Color velo;

  @override
  ConsumerState<FondoAnimado> createState() => _EstadoFondo();
}

class _EstadoFondo extends ConsumerState<FondoAnimado>
    with SingleTickerProviderStateMixin {
  /// Segundos que dura un ciclo completo; todo lo animado se repite en él.
  static const _ciclo = 60;

  late final AnimationController _reloj = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _ciclo),
  );

  late final List<_Particula> _particulas = _Particula.generar(
    widget.efecto == EfectoFondo.tormenta ? 70 : 36,
    math.Random(widget.efecto.index + 7),
  );

  @override
  void dispose() {
    _reloj.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imagen = Image.asset(
      widget.imagen,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1B1235)),
    );
    final quieto = !ref.watch(fondoAnimadoProvider) ||
        MediaQuery.of(context).disableAnimations;
    if (quieto) {
      _reloj.stop();
      return Stack(
        key: const Key('fondo-quieto'),
        fit: StackFit.expand,
        children: [imagen, ColoredBox(color: widget.velo)],
      );
    }
    if (!_reloj.isAnimating) _reloj.repeat();
    return Stack(
      key: const Key('fondo-animado'),
      fit: StackFit.expand,
      children: [
        // Ligero vaivén de la imagen (parallax): solo cambia su transformación.
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _reloj,
            child: imagen,
            builder: (context, hijo) {
              final t = _reloj.value * 2 * math.pi;
              return Transform.translate(
                offset: Offset(math.sin(t) * 10, math.cos(t) * 5),
                child: Transform.scale(scale: 1.05, child: hijo),
              );
            },
          ),
        ),
        RepaintBoundary(
          child: CustomPaint(
            painter: _PintorEfecto(
              reloj: _reloj,
              efecto: widget.efecto,
              particulas: _particulas,
              ciclo: _ciclo,
            ),
            size: Size.infinite,
          ),
        ),
        ColoredBox(color: widget.velo),
      ],
    );
  }
}

/// Un trazo de lluvia o una mota de luz, con su posición de partida y ritmo.
class _Particula {
  const _Particula(this.x, this.fase, this.velocidad, this.tamano, this.deriva);

  /// Posición horizontal (0–1), fase vertical (0–1), vueltas por ciclo, tamaño
  /// relativo (0–1) y balanceo.
  final double x, fase, velocidad, tamano, deriva;

  static List<_Particula> generar(int n, math.Random r) => [
        for (var i = 0; i < n; i++)
          _Particula(
            r.nextDouble(),
            r.nextDouble(),
            // Enteras: así el ciclo de 60 s cierra sin salto.
            (3 + r.nextInt(4)).toDouble(),
            r.nextDouble(),
            r.nextDouble() * 2 * math.pi,
          ),
      ];
}

class _PintorEfecto extends CustomPainter {
  _PintorEfecto({
    required this.reloj,
    required this.efecto,
    required this.particulas,
    required this.ciclo,
  }) : super(repaint: reloj);

  final Animation<double> reloj;
  final EfectoFondo efecto;
  final List<_Particula> particulas;
  final int ciclo;

  @override
  void paint(Canvas canvas, Size size) {
    final v = reloj.value; // 0–1 a lo largo del ciclo
    final segundos = v * ciclo;
    if (efecto == EfectoFondo.tormenta) {
      _lluvia(canvas, size, v);
      _relampago(canvas, size, segundos);
    } else {
      _bruma(canvas, size, v);
      _motas(canvas, size, v);
    }
  }

  void _lluvia(Canvas canvas, Size size, double v) {
    final pincel = Paint()
      ..color = const Color(0x66DDE8FF)
      ..strokeCap = StrokeCap.round;
    for (final p in particulas) {
      final y = ((v * p.velocidad * 4 + p.fase) % 1) * (size.height + 60) - 30;
      final x = (p.x * size.width + y * 0.18) % size.width;
      final largo = 12 + 16 * p.tamano;
      pincel.strokeWidth = 1 + p.tamano;
      canvas.drawLine(Offset(x, y), Offset(x - largo * 0.18, y + largo), pincel);
    }
  }

  /// Un relámpago cada 9 s: dos destellos seguidos que se apagan.
  void _relampago(Canvas canvas, Size size, double segundos) {
    final s = segundos % 9;
    double fuerza = 0;
    if (s < 0.12) {
      fuerza = 0.55;
    } else if (s >= 0.22 && s < 0.6) {
      fuerza = 0.8 * (1 - (s - 0.22) / 0.38);
    }
    if (fuerza <= 0) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(220, 230, 255, fuerza * 0.55),
    );
  }

  /// Bruma: dos manchas anchas y suaves que cruzan despacio.
  void _bruma(Canvas canvas, Size size, double v) {
    for (var i = 0; i < 2; i++) {
      final fase = (v + i * 0.5) % 1;
      final cx = size.width * (-0.2 + 1.4 * fase);
      final cy = size.height * (0.62 + 0.12 * i);
      final radio = size.shortestSide * 0.7;
      final borde = math.min(fase, 1 - fase) * 2; // aparece y se desvanece
      canvas.drawCircle(
        Offset(cx, cy),
        radio,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.fromRGBO(230, 221, 247, 0.16 * borde),
              const Color(0x00E6DDF7),
            ],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radio)),
      );
    }
  }

  /// Motas de luz doradas que suben despacio y titilan.
  void _motas(Canvas canvas, Size size, double v) {
    final pincel = Paint();
    for (final p in particulas) {
      final subida = (p.fase - v * p.velocidad) % 1; // 1 abajo → 0 arriba
      final y = subida * size.height;
      final x = p.x * size.width +
          math.sin(v * 2 * math.pi * p.velocidad + p.deriva) * 14;
      final titileo =
          0.5 + 0.5 * math.sin(v * 2 * math.pi * (p.velocidad + 2) + p.deriva);
      final borde = math.min(subida, 1 - subida) * 4;
      final alfa = (0.15 + 0.6 * titileo) * borde.clamp(0.0, 1.0);
      final radio = 1.5 + 2.5 * p.tamano;
      pincel.color = Color.fromRGBO(255, 214, 90, alfa);
      canvas.drawCircle(Offset(x, y), radio, pincel);
      pincel.color = Color.fromRGBO(255, 196, 0, alfa * 0.25);
      canvas.drawCircle(Offset(x, y), radio * 3, pincel);
    }
  }

  @override
  bool shouldRepaint(_PintorEfecto old) =>
      old.efecto != efecto || old.particulas != particulas;
}
