import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../partida/controlador_partida.dart';
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
const alturaJefe = 0.56;
const alturaAliados = 0.24;
const alturaJugadores = 0.20;

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
        FocoJefe() => Camara(0, 2 * (alturaJefe / 2) - 1, 1.15),
        FocoAliados() =>
          Camara(0, 2 * (alturaJefe + alturaAliados / 2) - 1, 1.45),
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
  _CamaraTween({super.begin, super.end});

  @override
  Camara lerp(double t) => Camara.lerp(begin!, end!, t);
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
    final foco = _manual ?? auto;
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
  const _Mesa({required this.estado, required this.alto, required this.onFoco});

  final EstadoPartida estado;
  final double alto;
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color.lerp(tema.colorScheme.primary, Colors.green, 0.5)!
                        .withValues(alpha: 0.35),
                    tema.colorScheme.surfaceContainerHighest,
                  ],
                  radius: 0.8,
                ),
              ),
            ),
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
    final tema = Theme.of(context);
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
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: activo == i
                        ? tema.colorScheme.primaryContainer
                        : tema.colorScheme.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: activo == i
                          ? tema.colorScheme.primary
                          : tema.colorScheme.outlineVariant,
                      width: activo == i ? 3 : 1,
                    ),
                  ),
                  child: _Asiento(jugador: estado.jugadores[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Asiento extends StatelessWidget {
  const _Asiento({required this.jugador});

  final JugadorEstado jugador;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final inicial = jugador.nombre.trim().isEmpty
        ? '?'
        : jugador.nombre.trim().substring(0, 1).toUpperCase();
    return Padding(
      padding: const EdgeInsets.all(6),
      child: FittedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: jugador.eliminado
                  ? tema.colorScheme.outlineVariant
                  : tema.colorScheme.primary,
              child: Text(
                inicial,
                style: TextStyle(
                  color: tema.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(jugador.nombre, style: tema.textTheme.titleSmall),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var p = 0; p < pokemonPorJugador; p++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      Icons.circle,
                      size: 12,
                      color: p < max(0, jugador.pokemonVivos)
                          ? Colors.redAccent
                          : tema.colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
