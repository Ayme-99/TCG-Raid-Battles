import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../partida/controlador_partida.dart';
import '../partida/tirada_mesa.dart';
import 'dados_en_mesa.dart';
import 'estilo.dart';
import 'mapa.dart';
import 'panel_acciones.dart';
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
/// lo que hay por resolver (aliados) o el turno del jefe. En el turno de los
/// jugadores la cámara se queda en la vista general; solo se mueve con los
/// eventos (dados, ataques del jefe o de los aliados).
FocoCamara focoDe(EstadoPartida estado) {
  if (estado.intentosInvocacionPendientes > 0 ||
      estado.entradasPendientes.isNotEmpty) {
    return const FocoAliados();
  }
  if (estado.fase == Fase.turnoJefe) return const FocoJefe();
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

/// La mesa a pantalla completa. En pantallas anchas el panel de acciones flota
/// sobre la mesa, a la izquierda y encima de la fila de jugadores; en las
/// estrechas va debajo de la mesa. En los dos casos se puede plegar.
class DisposicionMesa extends ConsumerStatefulWidget {
  const DisposicionMesa({super.key, required this.controles});

  /// Ancho a partir del cual el panel flota sobre la mesa.
  static const anchoMinimoFlotante = 1100.0;
  static const anchoPanel = 420.0;
  static const altoPico = 14.0;

  final List<Widget> controles;

  @override
  ConsumerState<DisposicionMesa> createState() => _DisposicionMesaState();
}

class _DisposicionMesaState extends ConsumerState<DisposicionMesa> {
  bool _abierto = true;

  void _alternar() => setState(() => _abierto = !_abierto);

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(estadoProvider);
    final activo =
        estado.fase == Fase.turnoJugadores ? estado.jugadorActual : null;
    final titulo = activo != null ? 'Tu turno' : 'Acciones';
    return LayoutBuilder(
      builder: (context, caja) {
        if (caja.maxWidth >= DisposicionMesa.anchoMinimoFlotante) {
          final ancho = caja.maxWidth;
          final alto = caja.maxHeight;
          const margen = 12.0;
          const panel = DisposicionMesa.anchoPanel;
          // El bocadillo sale del asiento del jugador que actúa; en el turno
          // del jefe se queda centrado.
          final n = estado.jugadores.length;
          final centro = activo != null
              ? ancho * (activo + 0.5) / n
              : ancho / 2;
          final izquierda = (centro - panel / 2)
              .clamp(margen, max(margen, ancho - panel - margen))
              .toDouble();
          final pico = (centro - izquierda - 14)
              .clamp(26.0, panel - 54.0)
              .toDouble();
          return Stack(
            children: [
              const Positioned.fill(child: MesaConCamara()),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                left: izquierda,
                bottom: alto * alturaJugadores + 4,
                width: panel,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: alto * 0.56),
                      child: PanelAcciones(
                        titulo: titulo,
                        controles: widget.controles,
                        abierto: _abierto,
                        onAlternar: _alternar,
                        ajustar: true,
                      ),
                    ),
                    if (activo != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(left: pico),
                          child: const CustomPaint(
                            key: Key('pico-bocadillo'),
                            size: Size(28, DisposicionMesa.altoPico),
                            painter: _PicoPainter(),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: DisposicionMesa.altoPico),
                  ],
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            const Expanded(flex: 3, child: MesaConCamara()),
            if (_abierto)
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: PanelAcciones(
                    titulo: titulo,
                    controles: widget.controles,
                    abierto: true,
                    onAlternar: _alternar,
                    ajustar: false,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: PanelAcciones(
                  titulo: titulo,
                  controles: widget.controles,
                  abierto: false,
                  onAlternar: _alternar,
                  ajustar: true,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Pico del bocadillo: un triángulo con el mismo borde blanco que el panel.
class _PicoPainter extends CustomPainter {
  const _PicoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final borde = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(borde, Paint()..color = Colors.white);
    final dentro = Path()
      ..moveTo(5, 0)
      ..lineTo(size.width - 5, 0)
      ..lineTo(size.width / 2, size.height - 6)
      ..close();
    canvas.drawPath(dentro, Paint()..color = const Color(0xFF1A1033));
  }

  @override
  bool shouldRepaint(_PicoPainter old) => false;
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
            // El jefe en el centro, con los slots de aliado a los lados.
            Expanded(
              flex: ((alturaJefe + alturaAliados) * 100).round(),
              child: GestureDetector(
                key: const Key('zona-jefe'),
                behavior: HitTestBehavior.translucent,
                onTap: () => onFoco(const FocoJefe()),
                child: _Zona(
                  ancho: 980,
                  arriba: MediaQuery.of(context).padding.top + 52,
                  hijo: _EscenaJefe(slots: estado.jugadores.length),
                ),
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

/// El jefe (carta y panel) en el centro y los slots de aliado a los lados: la
/// primera mitad a su izquierda y el resto a su derecha, uno por jugador.
class _EscenaJefe extends StatelessWidget {
  const _EscenaJefe({required this.slots});

  final int slots;

  static const _anchoSlot = 150.0;

  @override
  Widget build(BuildContext context) {
    final izquierda = (slots + 1) ~/ 2;
    Widget lado(Iterable<int> indices, MainAxisAlignment alineacion) => Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Row(
              mainAxisAlignment: alineacion,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final i in indices)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: SizedBox(
                      width: _anchoSlot,
                      child: SlotAliado(slot: i),
                    ),
                  ),
              ],
            ),
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        lado([for (var i = 0; i < izquierda; i++) i], MainAxisAlignment.end),
        const SizedBox(width: 360, child: TarjetaJefe()),
        lado(
          [for (var i = izquierda; i < slots; i++) i],
          MainAxisAlignment.start,
        ),
      ],
    );
  }
}

/// Zona de la mesa que escala su contenido para que quepa entera.
class _Zona extends StatelessWidget {
  const _Zona({required this.ancho, required this.hijo, this.arriba = 0});

  final double ancho;
  final Widget hijo;

  /// Espacio reservado arriba (la barra flotante de la partida).
  final double arriba;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 8 + arriba, 8, 8),
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
