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
              reposo: resultados[i] ? 0 : pi,
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
                  ..._monedaCayendo(m, a, lado, h, diseno),
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
}

List<Widget> _monedaCayendo(
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
  final angulo = (vueltas * 2 * pi + m.reposo) * freno;
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

class _Posicion {
  const _Posicion({
    required this.i,
    required this.reposo,
    required this.x,
    required this.suelo,
    required this.retraso,
  });

  final int i;
  /// Giro final de la moneda: 0 enseña la cara, π la cruz, π/2 de canto.
  final double reposo;
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

/// La pregunta «¿qué ha salido?» de una moneda que lleva la mesa a mano
/// (T-73), sobre la propia mesa: la moneda cae, se queda de canto y junto a
/// ella se elige cara o cruz. Al elegir, gira hasta ese lado, enseña el
/// resultado y entonces se da por contestada.
class PreguntaMonedaEnMesa extends ConsumerStatefulWidget {
  const PreguntaMonedaEnMesa({
    super.key,
    required this.tirada,
    required this.asientos,
  });

  final TiradaMesa tirada;
  final int asientos;

  @override
  ConsumerState<PreguntaMonedaEnMesa> createState() => _EstadoPregunta();
}

class _EstadoPregunta extends ConsumerState<PreguntaMonedaEnMesa>
    with TickerProviderStateMixin {
  late final AnimationController _caida = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  late final AnimationController _giro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        widget.tirada.responder(_eleccion!);
        widget.tirada.terminar();
      }
    });

  bool? _eleccion;

  void _elegir(bool cara) {
    if (_eleccion != null) return;
    setState(() => _eleccion = cara);
    _giro.forward();
  }

  @override
  void dispose() {
    _caida.dispose();
    _giro.dispose();
    // Si la mesa se va sin contestar, quien esperaba la respuesta sigue.
    widget.tirada.terminar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tirada;
    final diseno = ref.watch(disenoMonedaProvider);
    return LayoutBuilder(
      builder: (context, caja) {
        final w = caja.maxWidth;
        final h = caja.maxHeight;
        final lado = max(34.0, min(w * 0.08, 64.0));
        final centro = switch (t.lugar) {
          LugarMoneda.asiento => Offset(
              (t.asiento + 0.5) / widget.asientos * w,
              (alturaJefe + alturaAliados) * h - lado * 0.5,
            ),
          LugarMoneda.aliados =>
            Offset(w * 0.5, (alturaJefe + alturaAliados * 0.5) * h),
          LugarMoneda.jefe =>
            Offset(w * 0.5, (alturaJefe + alturaAliados * 0.2) * h),
        };
        final x = centro.dx.clamp(lado, max(lado, w - lado)).toDouble();
        return AnimatedBuilder(
          animation: Listenable.merge([_caida, _giro]),
          builder: (context, _) {
            final g = _giro.value;
            final elegida = _eleccion;
            final lista = _caida.value >= 1;
            final List<Widget> moneda;
            if (elegida == null) {
              // Cae y se queda de pie sobre su canto, esperando.
              moneda = _monedaCayendo(
                _Posicion(
                  i: 0,
                  reposo: pi / 2,
                  x: x,
                  suelo: centro.dy,
                  retraso: 0,
                ),
                _caida.value * _finMovimiento,
                lado,
                h,
                diseno,
              );
            } else {
              // Salta, da varias vueltas y cae en el lado elegido.
              final v = (g / 0.6).clamp(0.0, 1.0);
              final freno = 1 - pow(1 - v, 3).toDouble();
              final destino = 4 * pi + (elegida ? 0 : pi);
              final angulo = pi / 2 + (destino - pi / 2) * freno;
              final salto = h * 0.12 * sin(pi * v);
              final ladoActual = lado * (1 + 0.6 * sin(pi * v));
              moneda = [
                Positioned(
                  left: x - lado * 0.5,
                  top: centro.dy + lado * 0.32,
                  width: lado,
                  height: lado * 0.3,
                  child: Opacity(
                    opacity: 0.4 * (1 - 0.6 * sin(pi * v)),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius:
                            BorderRadius.all(Radius.elliptical(60, 20)),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: x - ladoActual / 2,
                  top: centro.dy - salto - MonedaWidget.altoPara(ladoActual) / 2,
                  child: MonedaWidget(
                    key: const ValueKey('moneda-mesa-0'),
                    diseno: diseno,
                    lado: ladoActual,
                    angulo: angulo,
                  ),
                ),
              ];
            }
            final panelX = (x - 170).clamp(8.0, max(8.0, w - 348)).toDouble();
            return Stack(
              clipBehavior: Clip.none,
              children: [
                ...moneda,
                if (elegida == null && lista)
                  Positioned(
                    left: panelX,
                    width: 340,
                    bottom: h - (centro.dy - lado * 0.9),
                    child: _PanelPregunta(
                      key: const Key('pregunta-moneda'),
                      tirada: t,
                      alElegir: _elegir,
                    ),
                  ),
                if (elegida != null)
                  Positioned(
                    left: x - 150,
                    width: 300,
                    top: centro.dy - lado * 0.9 - 74,
                    child: IgnorePointer(
                      child: _Etiqueta(
                        key: const Key('moneda-resumen'),
                        leyenda: t.leyenda,
                        resumen: elegida ? 'CARA' : 'CRUZ',
                        verLeyenda: 1,
                        verResumen: ((g - 0.5) / 0.15).clamp(0.0, 1.0),
                        hayCara: elegida,
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
}

/// El texto de la pregunta con sus avisos y los dos botones, junto a la moneda.
class _PanelPregunta extends StatelessWidget {
  const _PanelPregunta({super.key, required this.tirada, required this.alElegir});

  final TiradaMesa tirada;
  final void Function(bool cara) alElegir;

  @override
  Widget build(BuildContext context) {
    const claro = Color(0xFFE6DDF7);
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xE61B1235),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tirada.leyenda != null)
              Text(
                tirada.leyenda!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: claro,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (tirada.detalle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  tirada.detalle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: claro, fontSize: 12),
                ),
              ),
            for (final r in tirada.recordatorios)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  r,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFE082),
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              '¿Qué ha salido?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  key: const Key('pregunta-moneda-cruz'),
                  onPressed: () => alElegir(false),
                  child: const Text('Cruz'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  key: const Key('pregunta-moneda-cara'),
                  onPressed: () => alElegir(true),
                  child: const Text('Cara'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
