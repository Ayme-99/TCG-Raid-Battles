import 'package:flutter/material.dart';

/// Botón «atrás» de las pantallas de preparación: la misma ficha morada con
/// borde blanco y flecha que usa el asistente de «Nueva partida».
class BotonAtras extends StatelessWidget {
  const BotonAtras({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        label: 'Atrás',
        excludeSemantics: true,
        child: Tooltip(
          message: 'Atrás',
          child: Material(
            color: const Color(0xFF1B1235).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onPressed,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
