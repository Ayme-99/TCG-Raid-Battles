import 'dart:math';

import 'package:flutter/material.dart';

/// Dado que gira y cambia de cara mientras dura [animacion] y se queda en
/// [valor] cuando termina (T-44). No decide nada: el resultado ya viene tirado,
/// esto solo lo enseña con algo de suspense.
class DadoAnimado extends StatelessWidget {
  const DadoAnimado({
    super.key,
    required this.animacion,
    required this.caras,
    required this.valor,
    required this.etiqueta,
    this.semilla = 0,
  });

  /// De 0 a 1: 1 es el dado ya parado en [valor].
  final Animation<double> animacion;

  /// Número de caras (2 se dibuja como moneda).
  final int caras;

  /// Cara final, de 1 a [caras].
  final int valor;

  /// Texto bajo el dado, que se enseña al pararse.
  final String etiqueta;

  /// Desfasa las caras intermedias para que dos dados no vayan a la par.
  final int semilla;

  /// Cara que se enseña en el instante [t]: va saltando y acaba en [valor].
  int _cara(double t) {
    if (t >= 1) return valor;
    // Cambia de cara unas 14 veces; el cambio se hace más lento al final.
    final paso = (Curves.easeOut.transform(t) * 14).floor();
    return (paso * 7 + semilla * 3) % caras + 1;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return AnimatedBuilder(
      animation: animacion,
      builder: (context, _) {
        final t = animacion.value;
        final parado = t >= 1;
        // Gira dos vueltas y media frenando, y rebota un poco al pararse.
        final giro = (1 - Curves.easeOut.transform(t)) * 5 * pi;
        final escala = 1 + 0.25 * sin(t * pi);
        final esMoneda = caras == 2;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: giro,
              child: Transform.scale(
                scale: escala,
                child: Container(
                  key: ValueKey('dado-$caras-$semilla'),
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: parado
                        ? tema.colorScheme.primaryContainer
                        : tema.colorScheme.surfaceContainerHighest,
                    shape: esMoneda ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: esMoneda ? null : BorderRadius.circular(14),
                    border: Border.all(
                      color: tema.colorScheme.primary,
                      width: parado ? 3 : 2,
                    ),
                  ),
                  child: Text(
                    '${_cara(t)}',
                    style: tema.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              esMoneda ? 'moneda' : 'd$caras',
              style: tema.textTheme.labelSmall,
            ),
            SizedBox(
              height: 20,
              child: parado ? Text(etiqueta) : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}
