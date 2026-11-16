import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../partida/tirada_mesa.dart';
import 'mesa.dart';
import 'moneda.dart';

/// Las monedas de una [TiradaMesa] cayendo sobre la mesa (T-73), igual que los
/// dados: suben lanzadas desde abajo, giran en el aire, botan y se paran en su
/// cara o su cruz. Se pintan en coordenadas de la mesa, así que la cámara las
/// sigue. Cuando paran sale el resultado y se quedan un momento a la vista.
class MonedasEnMesa extends ConsumerStatefulWidget {
  const MonedasEnMesa({super.key, required this.tirada, required this.asientos});

  final TiradaMesa tirada;

  /// Asientos en la fila de abajo.
  final int asientos;

  @override
  ConsumerState<MonedasEnMesa> createState() => _EstadoMonedas();
}

/// Fracción de la animación en la que la última moneda ya está quieta; el
/// resto es para leer el resultado.
const _finMovimiento = 0.80;

class _EstadoMonedas extends ConsumerState<MonedasEnMesa>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: widget.tirada.duracion)
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
    final diseno = ref.watch(disenoMonedaProvider);
    final resultados = t.monedas!;
    final n = resultados.length;
    return LayoutBuilder(
      builder: (context, caja) {
        final w = caja.maxWidth;
        final h = caja.maxHeight;
        final lado = max(
          34.0,
          min(w * 0.08, 64.0) * (n > 8 ? 0.78 : (n > 4 ? 0.9 : 1.0)),
        );
        final columnas = min(n, 5);
        final filas = (n / columnas).ceil();
        final espacioX = lado * 1.35;
        final espacioY = lado * 1.0;
        // Dónde caen: ante el jugador, ante los aliados o ante el jefe.
        final centro = switch (t.lugar) {
          LugarMoneda.asiento => Offset(
              (t.asiento + 0.5) / widget.asientos * w,
              (alturaJefe + alturaAliados) * h - lado * 0.5 - (filas - 1) * espacioY / 2,
            ),
          LugarMoneda.aliados => Offset(w * 0.5, (alturaJefe + alturaAliados * 0.5) * h),
          LugarMoneda.jefe => Offset(w * 0.5, (alturaJefe + alturaAliados * 0.2) * h),
        };
        final monedas = <_Posicion>[];
        for (var i = 0; i < n; i++) {
          final fila = i ~/ columnas;
          final enFila = fila == filas - 1 ? n - fila * columnas : columnas;
          final col = i % columnas;
          final dx = (col - (enFila - 1) / 2) * espacioX;
          final dy = (fila - (filas - 1) / 2) * espacioY;
          monedas.add(
            _Posicion(
              i: i,
              cara: resultados[i],
              x: (centro.dx + dx).clamp(lado, max(lado, w - lado)).toDouble(),
              suelo: centro.dy + dy,
              retraso: n == 1 ? 0 : 0.14 * i / (n - 1),
            ),
          );
        }
        final arriba = centro.dy - (filas - 1) * espacioY / 2 - lado * 0.7;
        return AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            final a = _anim.value;
            final etiqueta = ((a - _finMovimiento) / 0.08).clamp(0.0, 1.0);
            final leyenda = (a / 0.1).clamp(0.0, 1.0);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (final m in monedas)
                  ..._moneda(m, a, lado, h, diseno),
                Positioned(
                  left: centro.dx - 150,
                  width: 300,
                  top: arriba - 74,
                  child: IgnorePointer(
                    child: _Etiqueta(
                      key: const Key('moneda-resumen'),
                      leyenda: t.leyenda,
                      resumen: t.resumen,
                      verLeyenda: leyenda,
                      verResumen: etiqueta,
                      hayCara: resultados.any((c) => c),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _moneda(
    _Posicion m,
    double anim,
    double lado,
    double alto,
    DisenoMoneda diseno,
  ) {
    final tiempo =
        ((anim - m.retraso) / (_finMovimiento - m.retraso)).clamp(0.0, 1.0);
    if (anim < m.retraso) return const [];
    // Primera mitad: sube desde abajo y vuelve a caer. Segunda: botes cada vez
    // más bajos hasta quedarse quieta.
    const vuelo = 0.5;
    final u = (tiempo / vuelo).clamp(0.0, 1.0);
    final pico = alto * 0.34;
    final inicio = m.suelo + alto * 0.16;
    var y = inicio + (m.suelo - inicio) * u - pico * sin(pi * u);
    if (tiempo > vuelo) {
      final v = (tiempo - vuelo) / (1 - vuelo);
      y = m.suelo - alto * 0.06 * (1 - v) * (1 - v) * sin(pi * 3 * v).abs();
    }
    final altura = ((m.suelo - y) / pico).clamp(0.0, 1.0);
    // Cuanto más alta, más cerca de la cámara: más grande.
    final escala = 1 + 0.8 * altura;
    final desvio = m.i.isEven ? -1.0 : 1.0;
    final x = m.x + desvio * lado * 2.2 * (1 - Curves.easeOut.transform(u));
    // Gira rápido y va frenando hasta quedar plana con su lado hacia arriba.
    final p = (tiempo / 0.9).clamp(0.0, 1.0);
    final freno = 1 - pow(1 - p, 3).toDouble();
    final vueltas = 5 + m.i % 3;
    final angulo = (vueltas * 2 * pi + (m.cara ? 0 : pi)) * freno;
    final ladoActual = lado * escala;
    return [
      // Sombra en la mesa, más pequeña y suave cuanto más alta va la moneda.
      Positioned(
        left: m.x - lado * 0.5,
        top: m.suelo + lado * 0.32,
        width: lado,
        height: lado * 0.3,
        child: Opacity(
          opacity: (0.4 * (1 - altura * 0.75)).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 1 - 0.4 * altura,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.all(Radius.elliptical(60, 20)),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        left: x - ladoActual / 2,
        top: y - MonedaWidget.altoPara(ladoActual) / 2,
        child: MonedaWidget(
          key: ValueKey('moneda-mesa-${m.i}'),
          diseno: diseno,
          lado: ladoActual,
          angulo: angulo,
        ),
      ),
    ];
  }
}

class _Posicion {
  const _Posicion({
    required this.i,
    required this.cara,
    required this.x,
    required this.suelo,
    required this.retraso,
  });

  final int i;
  final bool cara;
  final double x;
  final double suelo;
  final double retraso;
}

/// Para qué es la tirada y, cuando las monedas paran, qué salió.
class _Etiqueta extends StatelessWidget {
  const _Etiqueta({
    super.key,
    required this.leyenda,
    required this.resumen,
    required this.verLeyenda,
    required this.verResumen,
    required this.hayCara,
  });

  final String? leyenda;
  final String resumen;
  final double verLeyenda;
  final double verResumen;
  final bool hayCara;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Opacity(
          opacity: max(leyenda == null ? 0.0 : verLeyenda, verResumen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xE61B1235),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: verResumen > 0.5
                    ? (hayCara ? const Color(0xFFFFC400) : const Color(0xFFB39DDB))
                    : Colors.white24,
                width: 2,
              ),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leyenda != null)
                  Text(
                    leyenda!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFE6DDF7),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (verResumen > 0)
                  Opacity(
                    opacity: verResumen,
                    child: Text(
                      resumen,
                      key: const Key('moneda-resultado'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: hayCara
                            ? const Color(0xFFFFC400)
                            : const Color(0xFFD1C4E9),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
