import 'package:flutter/material.dart';

/// Nombre del archivo de una carta: minúsculas, sin tildes, espacios ni el
/// «ex» final. «Kingdra ex» y «Kingdra» comparten imagen.
String idCarta(String nombre) {
  const tildes = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
  };
  var s = nombre.trim().toLowerCase();
  if (s.endsWith(' ex')) s = s.substring(0, s.length - 3);
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    b.write(tildes[c] ?? c);
  }
  return b.toString().replaceAll(RegExp('[^a-z0-9]'), '');
}

/// Ruta del asset de una carta.
String rutaCarta(String nombre) => 'assets/cartas/${idCarta(nombre)}.webp';

/// La imagen de una carta con su brillo. Si el archivo todavía no existe,
/// pinta [alternativa] en su lugar (las cartas se van creando poco a poco).
class CartaImagen extends StatelessWidget {
  const CartaImagen({
    super.key,
    required this.nombre,
    required this.alternativa,
    this.brillo,
  });

  /// Proporción de las cartas (480 × 670).
  static const proporcion = 480 / 670;

  final String nombre;
  final Widget alternativa;
  final Color? brillo;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: proporcion,
      child: LayoutBuilder(
        builder: (context, caja) {
          final radio = caja.maxWidth * 0.045;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radio),
              boxShadow: [
                if (brillo != null)
                  BoxShadow(
                    color: brillo!.withValues(alpha: 0.85),
                    blurRadius: caja.maxWidth * 0.08,
                    spreadRadius: caja.maxWidth * 0.01,
                  ),
                const BoxShadow(
                  color: Colors.black54,
                  blurRadius: 8,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Image.asset(
              rutaCarta(nombre),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => alternativa,
            ),
          );
        },
      ),
    );
  }
}
