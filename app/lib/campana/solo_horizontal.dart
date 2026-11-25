import 'package:flutter/material.dart';

import 'escena_mapa.dart' show ColoresCampana;

/// Texto del aviso (D-20 §10.7, #487). No se cambia sin decisión de Ayme.
const textoGiraElMovil = 'Gira el móvil';

/// Si la pantalla está en vertical: más alta que ancha. La regla es la
/// relación de aspecto, no el sistema operativo (D-20 §10.7, #487). Una
/// pantalla cuadrada cuenta como apaisada.
bool esVertical(Size tamano) => tamano.height > tamano.width;

/// La campaña se juega solo en horizontal (D-20 §10.7, decidido por Ayme el
/// 2026-11-25). En vertical, este widget tapa a [child] con el aviso
/// «Gira el móvil»; al girar, el aviso desaparece.
///
/// [child] **no se desmonta nunca**: siempre ocupa el mismo sitio del árbol,
/// así que el combate en curso, lo comprado y la partida siguen igual al
/// girar. Mientras sale el aviso, [child] no recibe toques ni anima, y no se
/// lee en la accesibilidad.
///
/// Mira el tamaño de la pantalla entera (`MediaQuery`), no el del hueco que le
/// toca: así también vale dentro de una hoja o un diálogo.
class SoloHorizontal extends StatelessWidget {
  const SoloHorizontal({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final vertical = esVertical(MediaQuery.sizeOf(context));
    return Stack(
      fit: StackFit.passthrough,
      children: [
        TickerMode(
          enabled: !vertical,
          child: ExcludeSemantics(
            excluding: vertical,
            child: IgnorePointer(ignoring: vertical, child: child),
          ),
        ),
        if (vertical) const Positioned.fill(child: AvisoGiraElMovil()),
      ],
    );
  }
}

/// El aviso a pantalla completa: un móvil girando y «Gira el móvil». Sin
/// botones: no se juega nada debajo.
class AvisoGiraElMovil extends StatelessWidget {
  const AvisoGiraElMovil({super.key});

  @override
  Widget build(BuildContext context) {
    return const Material(
      key: Key('aviso-gira-el-movil'),
      color: ColoresCampana.crema,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.screen_rotation_rounded,
                    size: 96,
                    color: ColoresCampana.tinta,
                    semanticLabel: textoGiraElMovil,
                  ),
                  SizedBox(height: 16),
                  Text(
                    textoGiraElMovil,
                    style: TextStyle(
                      color: ColoresCampana.tinta,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [showModalBottomSheet] para la campaña: la hoja también queda tapada por el
/// aviso en vertical, para que no se pueda jugar desde ella.
Future<T?> mostrarHojaCampana<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      builder: (hoja) => SoloHorizontal(child: builder(hoja)),
    );

/// [showDialog] para la campaña, tapado por el aviso en vertical.
Future<T?> mostrarDialogoCampana<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) =>
    showDialog<T>(
      context: context,
      builder: (dialogo) => SoloHorizontal(child: builder(dialogo)),
    );
