import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:incursiones_engine/campana.dart';

import 'escenas.dart';

/// Colores del kit de interfaz de la campaña
/// (docs/diseno-ui/campana-arte-interfaz.md).
abstract final class ColoresCampana {
  static const tinta = Color(0xFF2A1D3A);
  static const crema = Color(0xFFFFF4D6);
  static const dorado = Color(0xFFFFC83D);
  static const naranja = Color(0xFFFF7A45);
  static const azul = Color(0xFF5A8CF0);
  static const verde = Color(0xFF5BD16B);
  static const rojo = Color(0xFFE5484D);
  static const tapete = Color(0xFF1F7A52);
}

/// Carpeta del arte propio de la interfaz. No se mezcla con `sprites_ajenos/`.
const carpetaUi = 'assets/campana/ui/';

/// Carpeta del material ajeno (sprites de EP), aislada para poder retirarla.
const carpetaSpritesAjenos = 'assets/campana/sprites_ajenos/';

/// Los assets que lleva la app, para saber qué fondos de escena ya existen.
final assetsAppProvider = FutureProvider<Set<String>>((ref) async {
  final manifiesto = await AssetManifest.loadFromAssetBundle(rootBundle);
  return manifiesto.listAssets().toSet();
});

/// Qué hace una zona pulsable en el estado de la partida: si se puede tocar y
/// qué rótulo lleva mientras la escena es el marcador.
class EstadoZona {
  final bool activa;
  final String rotulo;
  final IconData icono;

  const EstadoZona(
      {required this.activa, required this.rotulo, required this.icono});
}

/// El estado de [z] en la escena del nodo actual de [p] (D-20 §4, Escenas):
/// - `ir`: se puede si el destino es una de las opciones (hacia delante) o un
///   nodo ya visitado (hacia atrás, #412), y no hay una captura a medias.
/// - `combate`: si el nodo tiene combate o un salvaje que se puede repetir.
/// - `inicial`, `hablar`, `curar`: mientras el nodo no esté resuelto (curar,
///   siempre en un centro).
/// - `tienda` y `pc`: siempre en un centro.
EstadoZona estadoZona(CatalogoCampana c, PartidaCampana p, ZonaPulsable z) {
  final libre = p.capturaPendiente == null && !p.terminada(c);
  final nodo = p.nodoActual(c);
  switch (z.accion) {
    case AccionZona.ir:
      final destino = c.region.nodo(z.destino!);
      final adelante = p.opciones(c).contains(destino.id);
      final atras = !adelante &&
          destino.id != nodo.id &&
          p.progreso.visitados.contains(destino.id);
      return EstadoZona(
        activa: libre && (adelante || atras),
        rotulo: destino.nombre,
        icono: atras
            ? Icons.arrow_back_rounded
            : adelante
                ? Icons.arrow_forward_rounded
                : Icons.lock_rounded,
      );
    case AccionZona.combate:
      final rotulo = switch (nodo.tipo) {
        TipoNodo.gimnasio => 'Líder',
        TipoNodo.jefe => 'Jefe',
        _ => nodo.rival == RivalDeCombate.entrenador
            ? 'Entrenador'
            : 'Hierba alta',
      };
      return EstadoZona(
        activa: libre && (p.hayCombate(c) || p.puedeRepetir(c)),
        rotulo: rotulo,
        icono: nodo.rival == RivalDeCombate.salvaje
            ? Icons.grass_rounded
            : Icons.sports_mma_rounded,
      );
    case AccionZona.inicial:
      return EstadoZona(
        activa: libre && !p.progreso.resuelto,
        rotulo: 'Elegir inicial',
        icono: Icons.catching_pokemon,
      );
    case AccionZona.hablar:
      return EstadoZona(
        activa: libre && !p.progreso.resuelto,
        rotulo: nodo.personaje ?? 'Hablar',
        icono: Icons.forum_rounded,
      );
    case AccionZona.curar:
      return EstadoZona(
          activa: libre, rotulo: 'Mostrador', icono: Icons.healing_rounded);
    case AccionZona.tienda:
      return EstadoZona(
          activa: libre, rotulo: 'Tienda', icono: Icons.storefront_rounded);
    case AccionZona.pc:
      return EstadoZona(
          activa: libre, rotulo: 'PC', icono: Icons.computer_rounded);
  }
}

/// La clave de una zona en pantalla: `zona-ir-<destino>` o `zona-<accion>`.
String claveZona(ZonaPulsable z) => z.accion == AccionZona.ir
    ? 'zona-ir-${z.destino}'
    : 'zona-${z.accion.name}';

/// La escena ilustrada de un nodo con sus zonas pulsables encima (propuesta D
/// de los wireframes, D-20 §10.7). Las zonas se colocan con coordenadas
/// relativas a la imagen (0 a 1). Mientras Arte no entrega el fondo se pinta
/// el marcador y cada zona lleva su rótulo.
class EscenaInteractiva extends ConsumerWidget {
  const EscenaInteractiva({
    super.key,
    required this.catalogo,
    required this.partida,
    required this.alTocar,
  });

  final CatalogoCampana catalogo;
  final PartidaCampana partida;

  /// Lo que pasa al tocar una zona activa.
  final void Function(ZonaPulsable zona) alTocar;

  /// Proporción de las escenas (la del marcador, 160×90).
  static const proporcion = 16 / 9;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodo = partida.nodoActual(catalogo);
    final escena = nodo.escena;
    final disponibles = ref.watch(assetsAppProvider).valueOrNull ?? const {};
    final imagen =
        escena == null ? marcadorEscena : imagenDeEscena(escena, disponibles);
    final esMarcador = imagen == marcadorEscena;
    return AspectRatio(
      aspectRatio: proporcion,
      child: Container(
        key: Key('escena-${nodo.id}'),
        decoration: BoxDecoration(
          border: Border.all(color: ColoresCampana.tinta, width: 3),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, caja) => Stack(
            children: [
              Positioned.fill(
                child: imagen.endsWith('.svg')
                    ? SvgPicture.asset(imagen, fit: BoxFit.cover)
                    : Image.asset(imagen, fit: BoxFit.cover),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 6,
                child: Center(child: _Cartel(texto: nodo.nombre)),
              ),
              for (final z in escena?.zonas ?? const <ZonaPulsable>[])
                Positioned(
                  left: z.x * caja.maxWidth,
                  top: z.y * caja.maxHeight,
                  width: z.ancho * caja.maxWidth,
                  height: z.alto * caja.maxHeight,
                  child: _Zona(
                    zona: z,
                    estado: estadoZona(catalogo, partida, z),
                    conRotulo: esMarcador,
                    alTocar: () => alTocar(z),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cartel extends StatelessWidget {
  const _Cartel({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: ColoresCampana.crema,
          border: Border.all(color: ColoresCampana.tinta, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(texto,
            style: const TextStyle(
                color: ColoresCampana.tinta, fontWeight: FontWeight.w700)),
      );
}

class _Zona extends StatelessWidget {
  const _Zona({
    required this.zona,
    required this.estado,
    required this.conRotulo,
    required this.alTocar,
  });

  final ZonaPulsable zona;
  final EstadoZona estado;
  final bool conRotulo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final color = estado.activa ? ColoresCampana.dorado : Colors.white;
    return Semantics(
      button: true,
      enabled: estado.activa,
      label: estado.rotulo,
      child: Material(
        key: Key(claveZona(zona)),
        color: color.withValues(alpha: estado.activa ? 0.35 : 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: estado.activa
                ? ColoresCampana.tinta
                : ColoresCampana.tinta.withValues(alpha: 0.3),
            width: estado.activa ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: estado.activa ? alTocar : null,
          child: conRotulo ? _Rotulo(estado: estado) : const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Tamaño de letra del rótulo de una zona (#495). Las puertas miden el 10 %
/// del ancho de la escena; el rótulo parte en líneas para no encogerse.
const tamanoRotuloZona = 14.0;

/// El icono y el rótulo de una zona. El texto ocupa todo el ancho de la zona y
/// parte en varias líneas (#495: antes iba en una sola línea y, en una puerta
/// estrecha, «Salida de Ciudad Verde» se encogía a la mitad). Solo se encoge
/// si no cabe de alto.
class _Rotulo extends StatelessWidget {
  const _Rotulo({required this.estado});

  final EstadoZona estado;

  @override
  Widget build(BuildContext context) {
    final color =
        ColoresCampana.tinta.withValues(alpha: estado.activa ? 1 : 0.5);
    return LayoutBuilder(
      builder: (context, caja) {
        const margen = 4.0;
        final ancho =
            caja.maxWidth > 2 * margen ? caja.maxWidth - 2 * margen : 0.0;
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(margen),
              child: SizedBox(
                width: ancho,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(estado.icono, color: color),
                    Text(
                      estado.rotulo,
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: TextStyle(
                        color: color,
                        fontSize: tamanoRotuloZona,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// La barra fija de arriba del mapa: dinero, Pokéballs, XP y medallas
/// (D-20 §10.7). Los iconos de dinero y XP son arte propio; el de la Pokéball,
/// sprite de EP.
class BarraRecursos extends StatelessWidget {
  const BarraRecursos({super.key, required this.partida});

  final PartidaCampana partida;

  @override
  Widget build(BuildContext context) {
    final p = partida;
    final balls = p.ballsEnMochila().fold<int>(0, (s, b) => s + p.cuantos(b));
    return Container(
      key: const Key('barra-recursos'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ColoresCampana.crema,
        border: Border.all(color: ColoresCampana.tinta, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Recurso(
            clave: 'barra-dinero',
            icono: SvgPicture.asset('${carpetaUi}icono_dinero.svg',
                width: 22, height: 22),
            texto: '${p.dinero} \$',
          ),
          _Recurso(
            clave: 'barra-balls',
            icono: Image.asset('${carpetaSpritesAjenos}objetos/bola_poke.png',
                width: 22, height: 22),
            texto: '$balls',
          ),
          _Recurso(
            clave: 'barra-xp',
            icono: SvgPicture.asset('${carpetaUi}icono_xp.svg',
                width: 22, height: 22),
            texto: '${p.xp} XP',
          ),
          _Recurso(
            clave: 'barra-medallas',
            icono: const Icon(Icons.military_tech_rounded,
                size: 22, color: ColoresCampana.tinta),
            texto: '${p.progreso.medallas.length}',
          ),
        ],
      ),
    );
  }
}

class _Recurso extends StatelessWidget {
  const _Recurso(
      {required this.clave, required this.icono, required this.texto});

  final String clave;
  final Widget icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icono,
          const SizedBox(width: 4),
          Text(texto,
              key: Key(clave),
              style: const TextStyle(
                  color: ColoresCampana.tinta, fontWeight: FontWeight.w700)),
        ],
      );
}
