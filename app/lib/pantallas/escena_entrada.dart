import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../catalogo/catalogo.dart';
import '../partida/controlador_partida.dart';
import 'carta.dart';
import 'mapa.dart';

/// Si la partida estrena una escena al empezar. Los tests la apagan.
final escenaEntradaProvider = Provider<bool>((ref) => true);

/// Cada jefe tiene su escena, según el mapa donde se juega.
enum EscenaJefe {
  /// Onix, Túnel Roca: el suelo tiembla, se agrieta y cae polvo.
  roca,

  /// Manectric, Ruta 110: oscuridad, un rayo y lluvia.
  tormenta,

  /// Kingdra, Islas Remolino: todo bajo el agua, que baja con burbujas.
  agua,

  /// Arceus, Sala Origen: un anillo de luz dorada que se abre.
  luz,

  /// Jefe sin mapa propio: solo un fundido con la carta.
  generica,
}

EscenaJefe escenaDeMapa(String? mapa) {
  final id = mapa == null ? null : idMapa(mapa);
  return switch (id) {
    'tunel-roca' => EscenaJefe.roca,
    'ruta-110' => EscenaJefe.tormenta,
    'islas-remolino' => EscenaJefe.agua,
    'sala-origen' => EscenaJefe.luz,
    _ => EscenaJefe.generica,
  };
}

double _tramo(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
double _suave(double x) => x * x * (3 - 2 * x);

class _Datos {
  const _Datos(this.nombre, this.nivel, this.mapaId, this.escena);

  final String nombre;
  final int nivel;
  final String? mapaId;
  final EscenaJefe escena;
}

/// Escena de entrada al empezar la partida: al llegar a la mesa del jefe, su
/// escena (según el mapa) y su carta, y después se descubre la mesa. Dura unos
/// 4,5 s y un toque la salta. No sale al retomar una partida a medias ni con
/// «reducir movimiento» del sistema.
class EscenaEntrada extends ConsumerStatefulWidget {
  const EscenaEntrada({super.key});

  @override
  ConsumerState<EscenaEntrada> createState() => _EstadoEscena();
}

class _EstadoEscena extends ConsumerState<EscenaEntrada>
    with TickerProviderStateMixin {
  late final AnimationController _linea = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4500),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) _terminar();
    });

  late final AnimationController _salida = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: 1,
  );

  _Datos? _datos;

  @override
  void dispose() {
    _linea.dispose();
    _salida.dispose();
    super.dispose();
  }

  void _empezar(String nombre, int nivel) {
    if (!ref.read(escenaEntradaProvider)) return;
    if (MediaQuery.of(context).disableAnimations) return;
    final mapa = ref.read(catalogoProvider).asData?.value.jefeDe(nombre, nivel)?.mapa;
    final id = mapa == null ? null : idMapa(mapa);
    setState(() {
      _datos = _Datos(
        nombre,
        nivel,
        id != null && fondosDeMapa.containsKey(id) ? id : null,
        escenaDeMapa(mapa),
      );
    });
    _salida.value = 1;
    _linea.forward(from: 0);
  }

  void _terminar() {
    if (!mounted) return;
    _linea.stop();
    setState(() => _datos = null);
  }

  void _saltar() {
    _linea.stop();
    _salida.reverse().then((_) => _terminar());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<EstadoPartida>(estadoProvider, (antes, ahora) {
      final jefe = ahora.jefe;
      if (jefe == null || ahora.terminada) return;
      // Solo al empezar: cuando antes no había jefe o la partida anterior
      // había terminado (revancha).
      if (antes != null && antes.jefe != null && !antes.terminada) return;
      _empezar(jefe.nombre, jefe.nivel);
    });
    final d = _datos;
    if (d == null) return const IgnorePointer(child: SizedBox.shrink());
    // Material transparente: fuera de un Scaffold el texto saldría con el
    // subrayado amarillo de «sin Material».
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
      key: const Key('escena-entrada'),
      behavior: HitTestBehavior.opaque,
      onTap: _saltar,
      child: FadeTransition(
        opacity: _salida,
        child: AnimatedBuilder(
          animation: _linea,
          builder: (context, _) => CuadroEscena(
            escena: d.escena,
            t: _linea.value,
            nombre: d.nombre,
            nivel: d.nivel,
            mapaId: d.mapaId,
          ),
        ),
      ),
      ),
    );
  }
}

/// Un fotograma de la escena: [t] va de 0 a 1 a lo largo de toda la entrada.
class CuadroEscena extends StatelessWidget {
  const CuadroEscena({
    super.key,
    required this.escena,
    required this.t,
    required this.nombre,
    required this.nivel,
    this.mapaId,
  });

  final EscenaJefe escena;
  final double t;
  final String nombre;
  final int nivel;
  final String? mapaId;

  @override
  Widget build(BuildContext context) {
    // El efecto del fondo ocupa el primer tramo; luego entra la carta y, al
    // final, se descubre la mesa.
    final te = _tramo(t, 0, 0.72);
    final opacidad = 1 - _tramo(t, 0.86, 1);
    final carta = Curves.easeOutBack.transform(_tramo(t, 0.30, 0.60));
    final cartaOp = _tramo(t, 0.30, 0.50);
    final nombreOp = _tramo(t, 0.50, 0.70);
    var temblor = Offset.zero;
    if (escena == EscenaJefe.roca && te < 0.7) {
      final k = 1 - te / 0.7;
      temblor = Offset(math.sin(te * 90) * 6 * k, math.cos(te * 70) * 4 * k);
    }
    return Opacity(
      opacity: opacidad,
      child: LayoutBuilder(
        builder: (context, caja) {
          final altoCarta = math.min(caja.maxHeight * 0.52, 380.0);
          final base = mapaId == null ? const Color(0xFF1B1235) : fondosDeMapa[mapaId]!;
          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: base),
              if (mapaId != null)
                Transform.translate(
                  offset: temblor,
                  child: Transform.scale(
                    scale: 1.14 - 0.09 * Curves.easeOut.transform(te),
                    child: Image.asset(
                      'assets/mapas/$mapaId.webp',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              CustomPaint(painter: _PintorEscena(escena, te)),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: cartaOp,
                      child: Transform.rotate(
                        angle: 0.07 * (1 - carta),
                        child: Transform.scale(
                          scale: 0.6 + 0.4 * carta,
                          child: SizedBox(
                            width: altoCarta * 480 / 670,
                            height: altoCarta,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white, width: 4),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black54, blurRadius: 24),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  rutaCarta(nombre),
                                  fit: BoxFit.cover,
                                  excludeFromSemantics: true,
                                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Opacity(
                      opacity: nombreOp,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            nombre,
                            key: const Key('escena-nombre'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                            ),
                          ),
                          Text(
                            'Nivel $nivel',
                            style: const TextStyle(
                              color: Color(0xFFE6DDF7),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PintorEscena extends CustomPainter {
  _PintorEscena(this.escena, this.t);

  final EscenaJefe escena;

  /// Avance del efecto, de 0 a 1.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    switch (escena) {
      case EscenaJefe.roca:
        _roca(canvas, size);
      case EscenaJefe.tormenta:
        _tormenta(canvas, size);
      case EscenaJefe.agua:
        _agua(canvas, size);
      case EscenaJefe.luz:
        _luz(canvas, size);
      case EscenaJefe.generica:
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = Color.fromRGBO(13, 8, 32, 0.85 * (1 - _suave(_tramo(t, 0, 0.7)))),
        );
    }
  }

  void _roca(Canvas c, Size s) {
    c.drawRect(
      Offset.zero & s,
      Paint()..color = Color.fromRGBO(13, 8, 32, 0.9 - 0.75 * _suave(_tramo(t, 0, 0.7))),
    );
    // Grietas doradas que se abren y se apagan.
    final avance = _tramo(t, 0.12, 0.45);
    final brillo = 1 - _tramo(t, 0.55, 0.85);
    if (avance > 0 && brillo > 0) {
      const grietas = [
        [0.50, 0.30, 0.38, 0.45, 0.46, 0.58, 0.30, 0.72],
        [0.50, 0.30, 0.62, 0.44, 0.58, 0.60, 0.72, 0.74],
        [0.46, 0.58, 0.30, 0.52, 0.14, 0.60],
      ];
      final pincel = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = Color.fromRGBO(255, 196, 0, brillo)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      for (final g in grietas) {
        final camino = Path()..moveTo(g[0] * s.width, g[1] * s.height);
        for (var i = 2; i < g.length; i += 2) {
          camino.lineTo(g[i] * s.width, g[i + 1] * s.height);
        }
        final medida = camino.computeMetrics().first;
        c.drawPath(medida.extractPath(0, medida.length * avance), pincel);
      }
    }
    // Polvo que cae.
    final polvo = Paint()..color = Color.fromRGBO(220, 200, 170, 0.4 * (1 - _tramo(t, 0.6, 1)));
    for (var i = 0; i < 16; i++) {
      final x = ((i * 0.137) % 1) * s.width;
      final y = (((i * 0.311) + t * (0.6 + (i % 3) * 0.2)) % 1) * s.height;
      c.drawCircle(Offset(x, y), 3.0 + (i % 4) * 2, polvo);
    }
    // Onda del golpe cuando cae la carta.
    final golpe = _tramo(t, 0.5, 0.95);
    if (golpe > 0 && golpe < 1) {
      c.drawCircle(
        Offset(s.width / 2, s.height * 0.62),
        20 + (s.width * 0.6 - 20) * golpe,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = Color.fromRGBO(220, 200, 170, 0.35 * (1 - golpe)),
      );
    }
  }

  void _tormenta(Canvas c, Size s) {
    final oscuro = t < 0.2 ? 0.92 : 0.35 * (1 - _tramo(t, 0.25, 0.8));
    c.drawRect(Offset.zero & s, Paint()..color = Color.fromRGBO(5, 8, 20, oscuro));
    // Lluvia.
    final lluvia = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = Color.fromRGBO(221, 232, 255, 0.3 * _tramo(t, 0.1, 0.3));
    for (var i = 0; i < 40; i++) {
      final x = ((i * 0.0713 + 0.03) % 1) * s.width;
      final y = (((i * 0.173) + t * 2.5) % 1) * (s.height + 40) - 20;
      c.drawLine(Offset(x, y), Offset(x - 3, y + 18), lluvia);
    }
    // Rayo.
    if (t >= 0.2 && t < 0.34) {
      final fuerza = 1 - _tramo(t, 0.26, 0.34);
      final rayo = Path()
        ..moveTo(0.62 * s.width, 0)
        ..lineTo(0.55 * s.width, 0.15 * s.height)
        ..lineTo(0.66 * s.width, 0.28 * s.height)
        ..lineTo(0.50 * s.width, 0.42 * s.height)
        ..lineTo(0.58 * s.width, 0.55 * s.height);
      c.drawPath(
        rayo,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeJoin = StrokeJoin.round
          ..color = Color.fromRGBO(255, 228, 92, 0.7 * fuerza)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      c.drawPath(
        rayo,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round
          ..color = Color.fromRGBO(255, 255, 255, fuerza),
      );
      c.drawRect(
        Offset.zero & s,
        Paint()..color = Color.fromRGBO(235, 240, 255, 0.85 * (1 - _tramo(t, 0.2, 0.34))),
      );
    }
    // Segundo destello, más débil.
    if (t >= 0.42 && t < 0.5) {
      c.drawRect(
        Offset.zero & s,
        Paint()..color = Color.fromRGBO(235, 240, 255, 0.3 * (1 - _tramo(t, 0.42, 0.5))),
      );
    }
  }

  void _agua(Canvas c, Size s) {
    final nivel = 1 - 0.9 * _suave(_tramo(t, 0.05, 0.8));
    final techo = s.height * nivel;
    final ola = Path()..moveTo(0, techo);
    for (var x = 0.0; x <= s.width; x += 8) {
      ola.lineTo(x, techo + math.sin(x / 30 + t * 14) * 7);
    }
    ola
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    c.drawPath(
      ola,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xC83C8CD2), Color(0xEB0A326E)],
        ).createShader(Offset.zero & s),
    );
    // Espuma en el borde.
    final espuma = Path()..moveTo(0, techo);
    for (var x = 0.0; x <= s.width; x += 8) {
      espuma.lineTo(x, techo + math.sin(x / 30 + t * 14) * 7);
    }
    c.drawPath(
      espuma,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0x88FFFFFF),
    );
    // Burbujas que suben.
    final burbuja = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Color.fromRGBO(220, 245, 255, 0.5 * (1 - _tramo(t, 0.8, 1)));
    for (var i = 0; i < 14; i++) {
      final x = ((i * 0.211) % 1) * s.width + math.sin(t * 8 + i) * 6;
      final y = s.height - (((i * 0.19) + t * 1.4) % 1) * s.height;
      c.drawCircle(Offset(x, y), 3.0 + (i % 4) * 2, burbuja);
    }
  }

  void _luz(Canvas c, Size s) {
    final centro = Offset(s.width / 2, s.height * 0.47);
    final maximo = math.sqrt(s.width * s.width + s.height * s.height) / 2 * 1.05;
    final radio = 8 + (maximo - 8) * Curves.easeIn.transform(_tramo(t, 0.05, 0.65));
    // Negro con un agujero que crece: por él se ve la sala.
    final negro = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & s)
      ..addOval(Rect.fromCircle(center: centro, radius: radio));
    c.drawPath(
      negro,
      Paint()..color = Color.fromRGBO(5, 3, 15, 0.96 * (1 - _tramo(t, 0.6, 0.7))),
    );
    // Anillos dorados.
    final anillo = 1 - _tramo(t, 0.55, 0.9);
    if (anillo > 0) {
      c.drawCircle(
        centro,
        radio,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Color.fromRGBO(255, 214, 90, anillo)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      c.drawCircle(
        centro,
        radio * 0.82,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Color.fromRGBO(255, 214, 90, 0.5 * anillo),
      );
    }
    // Estallido de luz y rayos.
    final estallido = math.sin(math.pi * _tramo(t, 0.45, 0.9));
    if (estallido > 0) {
      c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.fromRGBO(255, 235, 160, 0.55 * estallido),
              const Color(0x00FFEBA0),
            ],
          ).createShader(Rect.fromCircle(center: centro, radius: maximo)),
      );
      final rayo = Paint()..color = Color.fromRGBO(255, 235, 160, 0.16 * estallido);
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6;
        final p = Path()
          ..moveTo(centro.dx, centro.dy)
          ..lineTo(centro.dx + math.cos(a - 0.05) * maximo, centro.dy + math.sin(a - 0.05) * maximo)
          ..lineTo(centro.dx + math.cos(a + 0.05) * maximo, centro.dy + math.sin(a + 0.05) * maximo)
          ..close();
        c.drawPath(p, rayo);
      }
    }
    // Motas de luz.
    final mota = Paint()
      ..color = Color.fromRGBO(255, 214, 90, 0.7 * _tramo(t, 0.4, 0.7) * (1 - _tramo(t, 0.85, 1)));
    for (var i = 0; i < 14; i++) {
      final x = ((i * 0.173) % 1) * s.width;
      final y = s.height - (((i * 0.29) + t * 0.5) % 1) * s.height;
      c.drawCircle(Offset(x, y), 2.0 + (i % 3), mota);
    }
  }

  @override
  bool shouldRepaint(_PintorEscena old) => old.t != t || old.escena != escena;
}
