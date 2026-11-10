import 'package:flutter/material.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

/// Colores y símbolos de la mesa (T-48): cada categoría de aliado tiene el suyo.
Color colorCategoria(CategoriaAliado c) => switch (c) {
      CategoriaAliado.danio => const Color(0xFFE53935),
      CategoriaAliado.tanque => const Color(0xFF3949AB),
      CategoriaAliado.cura => const Color(0xFF43A047),
      CategoriaAliado.control => const Color(0xFF8E24AA),
      CategoriaAliado.potenciador => const Color(0xFFFB8C00),
      CategoriaAliado.debilitador => const Color(0xFF00897B),
    };

IconData iconoCategoria(CategoriaAliado c) => switch (c) {
      CategoriaAliado.danio => Icons.local_fire_department,
      CategoriaAliado.tanque => Icons.shield,
      CategoriaAliado.cura => Icons.favorite,
      CategoriaAliado.control => Icons.bolt,
      CategoriaAliado.potenciador => Icons.arrow_circle_up,
      CategoriaAliado.debilitador => Icons.arrow_circle_down,
    };

/// Color de cada asiento de la mesa.
const coloresAsiento = [
  Color(0xFFFF5252),
  Color(0xFF448AFF),
  Color(0xFFFFC400),
  Color(0xFF69F0AE),
];

/// Color del aura del jefe según su nivel.
Color colorNivel(int nivel) => switch (nivel) {
      1 => const Color(0xFF66BB6A),
      2 => const Color(0xFF29B6F6),
      3 => const Color(0xFFAB47BC),
      _ => const Color(0xFFEF5350),
    };

/// Barra de vida de videojuego: borde grueso, relleno que cambia de color
/// según lo que queda y marcas cada 25 %.
class BarraVida extends StatelessWidget {
  const BarraVida({super.key, required this.fraccion, this.alto = 16});

  final double fraccion;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final f = fraccion.clamp(0.0, 1.0);
    final color = f > 0.5
        ? const Color(0xFF66BB6A)
        : f > 0.25
            ? const Color(0xFFFFCA28)
            : const Color(0xFFEF5350);
    return Container(
      height: alto,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(alto),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(alto),
        child: Stack(
          children: [
            // heightFactor 1: sin él, dentro del Stack el relleno medía 0 de
            // alto y la barra salía siempre negra.
            FractionallySizedBox(
              widthFactor: f,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.lerp(color, Colors.white, 0.4)!, color],
                  ),
                ),
              ),
            ),
            for (final marca in [0.25, 0.5, 0.75])
              Align(
                alignment: Alignment(marca * 2 - 1, 0),
                child: Container(width: 2, color: Colors.black26),
              ),
          ],
        ),
      ),
    );
  }
}
