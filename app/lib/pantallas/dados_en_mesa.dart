import 'dart:math';

import 'package:flutter/material.dart';

import '../partida/tirada_mesa.dart';
import 'estilo.dart';
import 'mesa.dart';

/// Los dados de una [TiradaMesa] cayendo sobre la mesa (T-44): entran desde
/// arriba, rebotan, ruedan y se paran en su cara. Se pintan en coordenadas de
/// la mesa, así que la cámara los sigue y los enfoca como a todo lo demás.
class DadosEnMesa extends StatefulWidget {
  const DadosEnMesa({super.key, required this.tirada, required this.asientos});

  final TiradaMesa tirada;

  /// Asientos en la fila de abajo.
  final int asientos;

  @override
  State<DadosEnMesa> createState() => _DadosEnMesaState();
}

class _DadosEnMesaState extends State<DadosEnMesa>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: duracionTirada)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.tirada.terminar();
        })
        ..forward();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tirada;
    return LayoutBuilder(
      builder: (context, caja) {
        final w = caja.maxWidth;
        final h = caja.maxHeight;
        final lado = min(w * 0.09, 72.0);
        // Los dados caen delante del asiento, justo encima de la fila de
        // jugadores; la moneda sin aliado cae en el centro, ante los aliados.
        final suelo = (alturaJefe + alturaAliados) * h - lado * 0.4;
        final xAsiento = (t.asiento + 0.5) / widget.asientos * w;
        final dados = t.sin
            ? [
                _Dado(
                  caras: 2,
                  valor: 2,
                  x: w * 0.5,
                  suelo: (alturaJefe + alturaAliados * 0.5) * h,
                  alto: h,
                  lado: lado,
                  retraso: 0,
                  desvio: 1,
                  color: const Color(0xFFFFC107),
                  semilla: 0,
                ),
              ]
            : [
                _Dado(
                  caras: t.carasSlot,
                  valor: t.valorSlot,
                  x: xAsiento - lado * 0.8,
                  suelo: suelo,
                  alto: h,
                  lado: lado,
                  retraso: 0,
                  desvio: -1,
                  color: coloresAsiento[t.asiento % coloresAsiento.length],
                  semilla: 0,
                ),
                _Dado(
                  caras: t.carasCategoria,
                  valor: t.valorCategoria,
                  x: xAsiento + lado * 0.8,
                  suelo: suelo - lado * 0.15,
                  alto: h,
                  lado: lado,
                  retraso: 0.12,
                  desvio: 1,
                  color: const Color(0xFF7E57C2),
                  semilla: 1,
                ),
              ];
        return AnimatedBuilder(
          animation: _anim,
          builder: (context, _) => Stack(
            clipBehavior: Clip.none,
            children: [for (final d in dados) d.pintar(_anim.value)],
          ),
        );
      },
    );
  }
}

class _Dado {
  const _Dado({
    required this.caras,
    required this.valor,
    required this.x,
    required this.suelo,
    required this.alto,
    required this.lado,
    required this.retraso,
    required this.desvio,
    required this.color,
    required this.semilla,
  });

  final int caras;
  final int valor;

  /// Donde se para (centro del dado).
  final double x;
  final double suelo;
  final double alto;
  final double lado;

  /// Fracción de la animación que espera antes de empezar a caer.
  final double retraso;

  /// -1 entra desde la izquierda, 1 desde la derecha.
  final double desvio;
  final Color color;
  final int semilla;

  Widget pintar(double animacion) {
    final t = ((animacion - retraso) / (1 - retraso)).clamp(0.0, 1.0);
    final cae = (t / 0.6).clamp(0.0, 1.0);
    final aire = Curves.bounceOut.transform(cae);
    final inicio = suelo - alto * 0.55;
    final y = inicio + (suelo - inicio) * aire;
    // Desliza hacia su sitio mientras rueda.
    final xActual = x + desvio * lado * 3 * (1 - Curves.easeOutCubic.transform(t));
    // Cuanto más lejos del suelo, más pequeña y suave la sombra.
    final altura = (suelo - y) / (suelo - inicio);
    final reposo = 1 - Curves.easeOut.transform(t);
    final cara = t >= 0.85
        ? valor
        : ((t * 18).floor() * 7 + semilla * 3) % caras + 1;
    final esMoneda = caras == 2;
    final giro = Matrix4.identity()
      ..setEntry(3, 2, 0.004)
      ..rotateX(reposo * 6 * pi)
      ..rotateY(reposo * 4 * pi * desvio)
      ..rotateZ(reposo * 2 * pi * desvio);
    return Positioned(
      left: xActual - lado / 2,
      top: y - lado / 2,
      width: lado,
      height: lado,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Sombra en el suelo, aunque el dado esté en el aire.
          Positioned(
            left: lado * 0.1,
            right: lado * 0.1,
            top: lado * 0.5 + (suelo - y) + lado * 0.3,
            height: lado * 0.25,
            child: Opacity(
              opacity: (0.35 * (1 - altura * 0.7)).clamp(0.0, 1.0),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.all(Radius.elliptical(60, 20)),
                ),
              ),
            ),
          ),
          Transform(
            alignment: Alignment.center,
            transform: giro,
            child: Container(
              key: ValueKey('dado-mesa-$semilla'),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: esMoneda ? BoxShape.circle : BoxShape.rectangle,
                borderRadius:
                    esMoneda ? null : BorderRadius.circular(lado * 0.22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.lerp(color, Colors.white, 0.55)!, color],
                ),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 6),
                ],
              ),
              child: Text(
                '$cara',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: lado * 0.5,
                  fontWeight: FontWeight.w900,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
