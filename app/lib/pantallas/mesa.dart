import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../partida/controlador_partida.dart';
import '../partida/tirada_mesa.dart';
import 'dados_en_mesa.dart';
import 'estilo.dart';
import 'mapa.dart';
import 'paneles.dart';
import 'tarjeta_jefe.dart';

/// Hacia dónde mira la cámara de la mesa (T-47).
sealed class FocoCamara {
  const FocoCamara();
}

/// Vista de toda la mesa.
class FocoGeneral extends FocoCamara {
  const FocoGeneral();

  @override
  bool operator ==(Object other) => other is FocoGeneral;

  @override
  int get hashCode => 0;
}

/// La carta del jefe.
class FocoJefe extends FocoCamara {
  const FocoJefe();

  @override
  bool operator ==(Object other) => other is FocoJefe;

  @override
  int get hashCode => 1;
}

/// La fila de aliados.
class FocoAliados extends FocoCamara {
  const FocoAliados();

  @override
  bool operator ==(Object other) => other is FocoAliados;

  @override
  int get hashCode => 2;
}

/// El asiento de un jugador (posición en la lista de jugadores).
class FocoJugador extends FocoCamara {
  const FocoJugador(this.indice);

  final int indice;

  @override
  bool operator ==(Object other) => other is FocoJugador && other.indice == indice;

  @override
  int get hashCode => Object.hash(3, indice);
}

/// Lo que es importante mirar ahora mismo según el estado de la partida:
/// lo que hay por resolver (aliados), el turno del jefe o el del jugador
/// activo.
FocoCamara focoDe(EstadoPartida estado) {
  if (estado.intentosInvocacionPendientes > 0 ||
      estado.entradasPendientes.isNotEmpty) {
    return const FocoAliados();
  }
  if (estado.fase == Fase.turnoJefe) return const FocoJefe();
  final actual = estado.jugadorActual;
  if (estado.fase == Fase.turnoJugadores && actual != null) {
    return FocoJugador(actual);
  }
  return const FocoGeneral();
}

/// Reparto vertical de la mesa: jefe arriba, aliados en medio, jugadores
/// abajo del todo. Suman 1.
const alturaJefe = 0.50;
const alturaAliados = 0.32;
const alturaJugadores = 0.18;

/// Punto de la mesa al que apunta la cámara y cuánto se acerca. `ax` y `ay`
/// van de -1 (izquierda, arriba) a 1 (derecha, abajo).
class Camara {
  const Camara(this.ax, this.ay, this.zoom);

  final double ax;
  final double ay;
  final double zoom;

  /// Cámara que enfoca [foco] con [jugadores] asientos en la fila de abajo.
  factory Camara.de(FocoCamara foco, int jugadores) => switch (foco) {
        FocoGeneral() => const Camara(0, 0, 1),
        FocoJefe() => const Camara(0, 2 * (alturaJefe / 2) - 1, 1.15),
        FocoAliados() =>
          const Camara(0, 2 * (alturaJefe + alturaAliados / 2) - 1, 1.45),
        FocoJugador(:final indice) => Camara(
            jugadores <= 1 ? 0 : 2 * (indice + 0.5) / jugadores - 1,
            2 * (alturaJefe + alturaAliados + alturaJugadores / 2) - 1,
            1.7,
          ),
      };

  static Camara lerp(Camara a, Camara b, double t) => Camara(
        a.ax + (b.ax - a.ax) * t,
        a.ay + (b.ay - a.ay) * t,
        a.zoom + (b.zoom - a.zoom) * t,
      );

  /// Matriz que lleva el punto enfocado al centro de una mesa de [ancho] x
  /// [alto] y la acerca.
  Matrix4 matriz(double ancho, double alto) {
    final px = (1 + ax) * ancho / 2;
    final py = (1 + ay) * alto / 2;
    return Matrix4.translationValues(ancho / 2, alto / 2, 0) *
        Matrix4.diagonal3Values(zoom, zoom, 1) *
        Matrix4.translationValues(-px, -py, 0);
  }
}

class _CamaraTween extends Tween<Camara> {
  _CamaraTween({super.end});

  @override
  Camara lerp(double t) => Camara.lerp(begin!, end!, t);
}

/// La mesa a pantalla completa. En pantallas anchas los controles del turno van
/// en un panel a la derecha; en las estrechas, debajo de la mesa.
class DisposicionMesa extends StatelessWidget {
  const DisposicionMesa({super.key, required this.controles});

  /// Ancho a partir del cual los controles pasan a un lado.
  static const anchoMinimoLateral = 900.0;
  static const anchoPanel = 420.0;

  final Widget controles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, caja) {
        if (caja.maxWidth >= anchoMinimoLateral) {
          return Row(
            children: [
              const Expanded(child: MesaConCamara()),
              SizedBox(
                width: anchoPanel,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 4,
                  child: controles,
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            const Flexible(flex: 3, child: MesaConCamara()),
            Expanded(flex: 2, child: controles),
          ],
        );
      },
    );
  }
}

/// La partida vista como a través de una cámara sobre la mesa: el jefe arriba,
/// los aliados debajo y los jugadores en fila abajo del todo. La cámara se
/// mueve sola hacia lo importante en cada momento (jefe, aliados, jugador
/// activo) y también se puede dirigir tocando una zona; tocar la mesa vacía
/// vuelve a la vista general.
class MesaConCamara extends ConsumerStatefulWidget {
  const MesaConCamara({super.key});

  @override
  ConsumerState<MesaConCamara> createState() => _MesaConCamaraState();
}

class _MesaConCamaraState extends ConsumerState<MesaConCamara> {
  /// Foco elegido a mano. Se olvida cuando la partida pide mirar a otro sitio.
  FocoCamara? _manual;
  FocoCamara? _ultimoAuto;

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(estadoProvider);
    final auto = focoDe(estado);
    if (auto != _ultimoAuto) {
      _ultimoAuto = auto;
      _manual = null;
    }
    // Mientras ruedan los dados la cámara mira a donde caen.
    final tirada = ref.watch(tiradaMesaProvider);
    final foco = tirada != null
        ? (tirada.sin ? const FocoAliados() : FocoJugador(tirada.asiento))
        : _manual ?? auto;
    final jugadores = estado.jugadores.length;
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, caja) {
          final ancho = caja.maxWidth;
          final alto = caja.hasBoundedHeight ? caja.maxHeight : ancho * 0.9;
          return TweenAnimationBuilder<Camara>(
            tween: _CamaraTween(end: Camara.de(foco, jugadores)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOutCubic,
            builder: (context, camara, hijo) {
              // Inclina la mesa hacia atrás para dar sensación de cámara.
              final perspectiva = Matrix4.identity()
                ..setEntry(3, 2, 0.0006)
                ..rotateX(0.18);
              return Transform(
                alignment: Alignment.center,
                transform: perspectiva,
                child: Transform(
                  alignment: Alignment.topLeft,
                  transform: camara.matriz(ancho, alto),
                  child: hijo,
                ),
              );
            },
            child: SizedBox(
              key: const Key('mesa'),
              width: ancho,
              height: alto,
              child: _Mesa(
                estado: estado,
                alto: alto,
                tirada: tirada,
                onFoco: (f) => setState(() => _manual = f),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Mesa extends StatelessWidget {
  const _Mesa({
    required this.estado,
    required this.alto,
    required this.onFoco,
    this.tirada,
  });

  final EstadoPartida estado;
  final double alto;
  final TiradaMesa? tirada;
  final void Function(FocoCamara) onFoco;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // El tapete es mucho más grande que la pantalla para que la cámara no
        // enseñe nunca el borde al acercarse.
        Positioned(
          left: -2000,
          right: -2000,
          top: -2000,
          bottom: -2000,
          child: GestureDetector(
            key: const Key('mesa-fondo'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onFoco(const FocoGeneral()),
            child: const CustomPaint(painter: MapaPainter()),
          ),
        ),
        Column(
          children: [
            Expanded(
              flex: (alturaJefe * 100).round(),
              child: GestureDetector(
                key: const Key('zona-jefe'),
                behavior: HitTestBehavior.translucent,
                onTap: () => onFoco(const FocoJefe()),
                child: const _Zona(ancho: 440, hijo: TarjetaJefe()),
              ),
            ),
            Expanded(
              flex: (alturaAliados * 100).round(),
              child: GestureDetector(
                key: const Key('zona-aliados'),
                behavior: HitTestBehavior.translucent,
                onTap: () => onFoco(const FocoAliados()),
                child: estado.aliados.isEmpty
                    ? Center(
                        child: Text(
                          'Sin aliados en la mesa',
                          style: tema.textTheme.labelLarge?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : const _Zona(ancho: 520, hijo: PanelAliados()),
              ),
            ),
            Expanded(
              flex: (alturaJugadores * 100).round(),
              child: _FilaJugadores(estado: estado, onFoco: onFoco),
            ),
          ],
        ),
        if (tirada != null)
          Positioned.fill(
            child: IgnorePointer(
              child: DadosEnMesa(
                key: ObjectKey(tirada),
                tirada: tirada!,
                asientos: estado.jugadores.length,
              ),
            ),
          ),
      ],
    );
  }
}

/// Zona de la mesa que escala su contenido para que quepa entera.
class _Zona extends StatelessWidget {
  const _Zona({required this.ancho, required this.hijo});

  final double ancho;
  final Widget hijo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        child: SizedBox(width: ancho, child: hijo),
      ),
    );
  }
}

/// Los jugadores en fila: su usuario y su personaje (de momento, la inicial
/// del nombre), con los Pokémon que les quedan.
class _FilaJugadores extends StatelessWidget {
  const _FilaJugadores({required this.estado, required this.onFoco});

  final EstadoPartida estado;
  final void Function(FocoCamara) onFoco;

  @override
  Widget build(BuildContext context) {
    final activo =
        estado.fase == Fase.turnoJugadores ? estado.jugadorActual : null;
    return Row(
      children: [
        for (var i = 0; i < estado.jugadores.length; i++)
          Expanded(
            child: GestureDetector(
              key: Key('asiento-$i'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onFoco(FocoJugador(i)),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: _Asiento(
                  jugador: estado.jugadores[i],
                  color: coloresAsiento[i % coloresAsiento.length],
                  activo: activo == i,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Insignia de un jugador: avatar con su color, nombre y Pokémon vivos. El
/// jugador activo brilla y sube un poco.
class _Asiento extends StatelessWidget {
  const _Asiento({
    required this.jugador,
    required this.color,
    required this.activo,
  });

  final JugadorEstado jugador;
  final Color color;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final eliminado = jugador.eliminado;
    final base = eliminado ? Colors.grey : color;
    final inicial = jugador.nombre.trim().isEmpty
        ? '?'
        : jugador.nombre.trim().substring(0, 1).toUpperCase();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      transform: Matrix4.translationValues(0, activo ? -6 : 0, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(base, Colors.white, 0.35)!, base],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: activo ? 4 : 2),
        boxShadow: [
          BoxShadow(
            color: activo ? Colors.white.withValues(alpha: 0.9) : Colors.black45,
            blurRadius: activo ? 18 : 6,
            offset: activo ? Offset.zero : const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: FittedBox(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              child: Text(
                inicial,
                style: TextStyle(
                  color: base,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jugador.nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var p = 0; p < pokemonPorJugador; p++)
                      Padding(
                        padding: const EdgeInsets.only(right: 3, top: 2),
                        child: Icon(
                          Icons.catching_pokemon,
                          size: 16,
                          color: p < max(0, jugador.pokemonVivos)
                              ? Colors.white
                              : Colors.black38,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
