import 'dart:math';

import 'package:flutter/material.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import 'estilo.dart';

/// La carta de ataque del jefe recién robada: sale del mazo girando y deja
/// ver qué ataque usa, contra quién y si hay que robar otra.
class CartaAtaqueRobada extends StatelessWidget {
  const CartaAtaqueRobada({
    super.key,
    required this.carta,
    required this.jugador,
  });

  final CartaAtaqueJefe carta;

  /// Nombre del jugador atacado.
  final String jugador;

  static const _colorRanura = [
    Color(0xFFFFE082),
    Color(0xFFFFB74D),
    Color(0xFFEF9A9A),
  ];

  Widget _frente() {
    final colorJugador = coloresAsiento[carta.jugador % coloresAsiento.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black45)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Column(
          children: [
            Container(
              color: _colorRanura[carta.ranura - 1],
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Usa el ataque',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    key: const Key('carta-ranura'),
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: Text(
                      '${carta.ranura}',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Column(
                children: [
                  const Text(
                    'contra',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  Text(
                    jugador.toUpperCase(),
                    key: const Key('carta-objetivo'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorJugador,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${carta.numero}/20',
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      if (carta.robaOtra)
                        const Text(
                          'Roba una carta más ➜',
                          key: Key('carta-roba-otra'),
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dorso() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF5E35B1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: const Center(
        child: Text(
          'ATAQUE\nDEL JEFE',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 230,
        height: 132,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) {
            // Entra desde arriba, boca abajo, y se gira hasta enseñar la cara.
            final angulo = pi * (1 - t);
            final deCara = angulo < pi / 2;
            return Transform.translate(
              offset: Offset(0, -40 * (1 - t)),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angulo),
                child: deCara
                    ? _frente()
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(pi),
                        child: _dorso(),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}
