import 'package:incursiones_engine/campana.dart';

/// Carpeta de los fondos de escena (arte propio, D-20 §10.1). No se mezcla con
/// `sprites_ajenos/`.
const carpetaEscenas = 'assets/campana/escenas/';

/// El fondo que se pinta mientras Arte no entrega el de una escena (#413).
const marcadorEscena = '${carpetaEscenas}marcador.svg';

/// La imagen de [escena]: `assets/campana/escenas/<imagen>.webp` si está en
/// [disponibles] (los assets de la app) y, si no, [marcadorEscena].
String imagenDeEscena(EscenaNodo escena, Set<String> disponibles) {
  final propia = '$carpetaEscenas${escena.imagen}.webp';
  return disponibles.contains(propia) ? propia : marcadorEscena;
}
