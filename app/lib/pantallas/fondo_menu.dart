import 'package:flutter/material.dart';

const _morado = Color(0xFF1B1235);

/// Ancho a partir del cual el fondo del menú es el de pantalla grande.
const anchoFondoMenuAncho = 700.0;

/// El fondo de los menús (inicio, nueva partida y preparación de la partida):
/// un mapa oscurecido en morado. Se mantiene hasta que empieza la partida, y
/// entonces cambia al mapa del jefe.
class FondoMenu extends StatelessWidget {
  const FondoMenu({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          ancho >= anchoFondoMenuAncho
              ? 'assets/mapas/sala-origen.webp'
              : 'assets/mapas/ruta-110.webp',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const ColoredBox(color: _morado),
        ),
        ColoredBox(color: _morado.withValues(alpha: 0.5)),
        if (child != null) child!,
      ],
    );
  }
}

/// Tema oscuro para las pantallas que van sobre [FondoMenu].
ThemeData temaSobreFondoMenu() => ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.deepPurple,
      brightness: Brightness.dark,
    );
