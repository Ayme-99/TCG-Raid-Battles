import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../partida/ataque_mesa.dart';

/// Duración de cada ataque en la mesa: la cámara llega a quien ataca, carga,
/// sale el proyectil mientras la cámara viaja al objetivo, e impacto.
const duracionAtaqueMesa = Duration(milliseconds: 2600);

/// Momento (0 a 1) en que la cámara deja a quien ataca y viaja al objetivo.
const _salidaProyectil = 0.45;

/// Enseña sobre la mesa los ataques del jefe y de los aliados: una carga en
/// quien ataca, un proyectil hasta el objetivo, el impacto y el daño que
/// sube flotando. Va por encima de todo, no recibe toques y se retira solo.
class AtaquesEnMesa extends ConsumerStatefulWidget {
  const AtaquesEnMesa({super.key});

  @override
  ConsumerState<AtaquesEnMesa> createState() => _EstadoAtaquesEnMesa();
}

class _EstadoAtaquesEnMesa extends ConsumerState<AtaquesEnMesa>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: duracionAtaqueMesa);
  AtaqueMesa? _actual;
  bool _camaraEnObjetivo = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      final ataque = _actual;
      if (ataque == null || _camaraEnObjetivo || _c.value < _salidaProyectil) {
        return;
      }
      _camaraEnObjetivo = true;
      ref.read(enfoqueAtaqueProvider.notifier).state =
          ataque.destinos.length == 1 ? ataque.destinos.first : puntoTodos;
    });
    _c.addStatusListener((estado) {
      if (estado != AnimationStatus.completed) return;
      final terminado = _actual;
      ref.read(enfoqueAtaqueProvider.notifier).state = null;
      setState(() => _actual = null);
      if (terminado != null) {
        ref.read(colaAtaquesMesaProvider.notifier).terminar(terminado.id);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(colaAtaquesMesaProvider.notifier).descartarCaducados();
      final cola = ref.read(colaAtaquesMesaProvider);
      if (cola.isEmpty) {
        // Una mesa anterior pudo irse con la cámara fijada en un ataque.
        ref.read(enfoqueAtaqueProvider.notifier).state = null;
      } else {
        _revisar(cola);
      }
    });
  }

  @override
  void dispose() {
    // No se limpia la cola: al pasar del último jugador al jefe cambia la
    // pantalla y la mesa se recrea con el ataque recién registrado, que la
    // nueva mesa tiene que recoger.
    _c.dispose();
    super.dispose();
  }

  void _revisar(List<AtaqueMesa> cola) {
    if (_actual != null || cola.isEmpty) return;
    _camaraEnObjetivo = false;
    ref.read(enfoqueAtaqueProvider.notifier).state = cola.first.origen;
    setState(() => _actual = cola.first);
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(colaAtaquesMesaProvider, (_, cola) => _revisar(cola));
    final ataque = _actual;
    if (ataque == null) return const SizedBox.shrink();
    final claves = ref.read(clavesMesaProvider);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final lienzo = context.findRenderObject();
          if (lienzo is! RenderBox || !lienzo.hasSize) {
            return const SizedBox.expand();
          }
          // Las posiciones se leen en cada imagen: la cámara de la mesa se
          // mueve mientras tanto.
          // Se mide respecto al propio lienzo, sin pasar por la pantalla: así
          // el zoom y la inclinación de la cámara no descuadran el marco.
          Rect? rectDe(PuntoMesa punto) {
            final caja = claves.caja(punto);
            if (caja == null) return null;
            return MatrixUtils.transformRect(
              caja.getTransformTo(lienzo),
              Offset.zero & caja.size,
            );
          }

          final origen = rectDe(ataque.origen);
          final destinos = [
            for (final d in ataque.destinos)
              if (rectDe(d) case final r?) r,
          ];
          if (origen == null || destinos.isEmpty) {
            return const SizedBox.expand();
          }
          return CustomPaint(
            key: const Key('ataque-mesa'),
            size: Size.infinite,
            painter: _PintorAtaque(
              t: _c.value,
              origen: origen,
              destinos: destinos,
              dano: ataque.dano,
              reducido: ataque.reducido,
              extra: ataque.extra,
              color: switch (ataque.atacante) {
                'jefe' => const Color(0xFFFF5A3C),
                'aliado' => const Color(0xFFB26BFF),
                _ => const Color(0xFF4FC3F7),
              },
            ),
          );
        },
      ),
    );
  }
}

class _PintorAtaque extends CustomPainter {
  _PintorAtaque({
    required this.t,
    required this.origen,
    required this.destinos,
    required this.dano,
    this.reducido = 0,
    this.extra = 0,
    required this.color,
  });

  final double t;
  final Rect origen;
  final List<Rect> destinos;
  final int dano;
  final int reducido;
  final int extra;
  final Color color;

  // Fases (0 a 1): la cámara llega, carga, vuelo del proyectil e impacto.
  static const _inicioCarga = 0.2;
  static const _finCarga = _salidaProyectil;
  static const _inicioImpacto = 0.62;

  double _tramo(double desde, double hasta) =>
      ((t - desde) / (hasta - desde)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final desde = origen.center;
    final radio = math.max(origen.shortestSide, 40.0);

    // Carga: un resplandor que crece alrededor de quien ataca.
    final carga = _tramo(_inicioCarga, _finCarga);
    final enfriar = 1 - _tramo(_finCarga, _inicioImpacto);
    if (carga > 0 && enfriar > 0) {
      final pincel = Paint()
        ..color = color.withValues(alpha: 0.55 * carga * enfriar)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
      canvas.drawCircle(desde, radio * (0.3 + 0.45 * carga), pincel);
      canvas.drawRRect(
        RRect.fromRectAndRadius(origen.inflate(6 * carga), const Radius.circular(18)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = Colors.white.withValues(alpha: 0.9 * carga * enfriar),
      );
    }

    for (var i = 0; i < destinos.length; i++) {
      final hasta = destinos[i].center;
      _proyectil(canvas, desde, hasta);
      _impacto(canvas, destinos[i], hasta);
    }
  }

  void _proyectil(Canvas canvas, Offset desde, Offset hasta) {
    final vuelo = _tramo(_finCarga, _inicioImpacto);
    if (vuelo <= 0 || vuelo >= 1) return;
    final avance = Curves.easeInCubic.transform(vuelo);
    // Estela: copias cada vez más pequeñas y tenues detrás del proyectil.
    for (var k = 5; k >= 1; k--) {
      final atras = (avance - k * 0.045).clamp(0.0, 1.0);
      final p = Offset.lerp(desde, hasta, atras)!;
      canvas.drawCircle(
        p,
        16.0 - k * 2,
        Paint()..color = color.withValues(alpha: 0.5 - k * 0.07),
      );
    }
    final p = Offset.lerp(desde, hasta, avance)!;
    canvas.drawCircle(
      p,
      30,
      Paint()
        ..color = color.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawCircle(p, 15, Paint()..color = color);
    canvas.drawCircle(p, 8, Paint()..color = Colors.white);
  }

  void _impacto(Canvas canvas, Rect objetivo, Offset centro) {
    final k = _tramo(_inicioImpacto, 1);
    if (k <= 0) return;
    final tenue = 1 - Curves.easeIn.transform(k);

    // El objetivo se enrojece un momento.
    canvas.drawRRect(
      RRect.fromRectAndRadius(objetivo, const Radius.circular(18)),
      Paint()..color = const Color(0xFFFF1744).withValues(alpha: 0.45 * tenue),
    );
    // Onda expansiva y chispas.
    final onda = Curves.easeOut.transform(k);
    canvas.drawCircle(
      centro,
      12 + 90 * onda,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8 * tenue
        ..color = Colors.white.withValues(alpha: tenue),
    );
    final chispa = Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: tenue);
    for (var i = 0; i < 10; i++) {
      final angulo = i * math.pi / 5;
      final dir = Offset(math.cos(angulo), math.sin(angulo));
      canvas.drawLine(
        centro + dir * (20 + 50 * onda),
        centro + dir * (34 + 80 * onda),
        chispa,
      );
    }
    // El daño sube y se desvanece.
    final subida = Curves.easeOut.transform(k);
    final aparece = Curves.easeOutBack.transform(_tramo(_inicioImpacto, 0.72));
    final altoNumero = centro.dy - 30 - 70 * subida;
    final visible = 1 - _tramo(0.85, 1);
    if (extra > 0) {
      _explosion(canvas, Offset(centro.dx, altoNumero), aparece, visible);
    }
    if (reducido > 0) {
      _escudo(canvas, Offset(centro.dx, altoNumero), aparece, visible);
    }
    final texto = TextPainter(
      text: TextSpan(
        text: dano > 0 ? '-$dano' : '0',
        style: TextStyle(
          fontSize: 44 * aparece.clamp(0.0, 1.3),
          fontWeight: FontWeight.w900,
          color: Colors.white.withValues(alpha: 1 - _tramo(0.85, 1)),
          shadows: const [
            Shadow(color: Color(0xFFD50000), offset: Offset(3, 3)),
            Shadow(color: Colors.black87, blurRadius: 8),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    texto.paint(
      canvas,
      Offset(centro.dx - texto.width / 2, altoNumero - texto.height / 2),
    );
    if (extra > 0 || reducido > 0) {
      final partes = [
        if (reducido > 0) '−$reducido',
        if (extra > 0) '+$extra',
      ].join('  ');
      final nota = TextPainter(
        text: TextSpan(
          text: partes,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: (extra > 0 ? const Color(0xFFFFD54F) : const Color(0xFF81D4FA))
                .withValues(alpha: visible),
            shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      nota.paint(
        canvas,
        Offset(centro.dx - nota.width / 2, altoNumero + texto.height / 2 + 2),
      );
    }
  }

  /// Estrella de picos detrás del número: el daño de más.
  void _explosion(Canvas canvas, Offset c, double escala, double visible) {
    final radio = 70.0 * escala.clamp(0.0, 1.3);
    const picos = 12;
    final camino = Path();
    for (var i = 0; i < picos * 2; i++) {
      final r = i.isEven ? radio : radio * 0.62;
      final a = i * math.pi / picos - math.pi / 2;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? camino.moveTo(p.dx, p.dy) : camino.lineTo(p.dx, p.dy);
    }
    camino.close();
    canvas.drawPath(
      camino,
      Paint()
        ..color = const Color(0xFFFF9100).withValues(alpha: 0.9 * visible)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(
      camino,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFFFFEB3B).withValues(alpha: visible),
    );
  }

  /// Escudo detrás del número: el daño que se ha quitado el objetivo.
  void _escudo(Canvas canvas, Offset c, double escala, double visible) {
    final k = escala.clamp(0.0, 1.3);
    final ancho = 64.0 * k;
    final alto = 78.0 * k;
    final camino = Path()
      ..moveTo(c.dx - ancho, c.dy - alto * 0.8)
      ..lineTo(c.dx + ancho, c.dy - alto * 0.8)
      ..lineTo(c.dx + ancho, c.dy + alto * 0.1)
      ..quadraticBezierTo(c.dx + ancho, c.dy + alto * 0.7, c.dx, c.dy + alto)
      ..quadraticBezierTo(c.dx - ancho, c.dy + alto * 0.7, c.dx - ancho, c.dy + alto * 0.1)
      ..close();
    canvas.drawPath(
      camino,
      Paint()..color = const Color(0xFF1565C0).withValues(alpha: 0.85 * visible),
    );
    canvas.drawPath(
      camino,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFFB3E5FC).withValues(alpha: visible),
    );
  }

  @override
  bool shouldRepaint(_PintorAtaque anterior) =>
      anterior.t != t || anterior.destinos != destinos || anterior.origen != origen;
}
