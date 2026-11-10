import 'package:flutter/material.dart';

/// El panel de acciones del turno: cristal oscuro con borde blanco que se
/// pliega para dejar ver toda la mesa. Dentro, los controles usan el tema
/// oscuro.
class PanelAcciones extends StatelessWidget {
  const PanelAcciones({
    super.key,
    this.titulo = 'Acciones',
    required this.controles,
    required this.abierto,
    required this.onAlternar,
    required this.ajustar,
  });

  final String titulo;

  /// Los controles del turno.
  final List<Widget> controles;
  final bool abierto;
  final VoidCallback onAlternar;

  /// true: el panel mide lo que mide su contenido (flota sobre la mesa).
  /// false: rellena el hueco que le da su padre (debajo de la mesa).
  final bool ajustar;

  static final _tema = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF7E57C2),
      brightness: Brightness.dark,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final lista = ListView(
      shrinkWrap: ajustar,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: controles,
    );
    return Theme(
      data: _tema,
      child: Container(
        key: const Key('panel-acciones'),
        decoration: BoxDecoration(
          color: const Color(0xF01A1033),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 12,
              offset: Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: ajustar ? MainAxisSize.min : MainAxisSize.max,
            children: [
              InkWell(
                key: const Key('panel-acciones-toggle'),
                onTap: onAlternar,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        abierto ? Icons.expand_more : Icons.expand_less,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              if (abierto)
                if (ajustar) Flexible(child: lista) else Expanded(child: lista),
            ],
          ),
        ),
      ),
    );
  }
}
