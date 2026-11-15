import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../envios/botones_cuenta.dart';
import '../envios/controlador_envios.dart';
import '../partida/controlador_partida.dart';
import 'comun.dart';
import 'fin_partida.dart';
import 'inicio.dart';
import 'paneles.dart';
import 'setup.dart';
import 'turno_jefe.dart';
import 'turno_jugadores.dart';

/// Pantalla única de la partida: según la fase del motor muestra el setup, el
/// turno de los jugadores, el del jefe o el final. La barra superior lleva
/// deshacer y rehacer, que valen en todas las fases.
class PantallaPartida extends ConsumerWidget {
  const PantallaPartida({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoProvider);
    final puedeDeshacer = ref.watch(puedeDeshacerProvider);
    final puedeRehacer = ref.watch(puedeRehacerProvider);
    // Una vez guardados los resultados ya no se puede deshacer: el servidor
    // ya tiene esa partida.
    final bloqueada = estado.terminada &&
        ref.watch(enviosProvider.select((e) => e.partidaEncolada != null));
    final enJuego =
        estado.fase == Fase.turnoJugadores || estado.fase == Fase.turnoJefe;
    final acciones = <Widget>[
      IconButton(
        key: const Key('deshacer'),
        tooltip: 'Deshacer',
        icon: const Icon(Icons.undo),
        onPressed: puedeDeshacer && !bloqueada
            ? () => ref.read(partidaProvider.notifier).deshacer()
            : null,
      ),
      IconButton(
        key: const Key('rehacer'),
        tooltip: 'Rehacer',
        icon: const Icon(Icons.redo),
        onPressed: puedeRehacer && !bloqueada
            ? () => ref.read(partidaProvider.notifier).rehacer()
            : null,
      ),
      const BotonEnvios(),
      const BotonCuenta(),
    ];
    // La barra flotante lleva los mismos botones con su nombre debajo.
    final accionesHud = <Widget>[
      _BotonHud(
        key: const Key('deshacer'),
        icono: Icons.undo,
        etiqueta: 'Deshacer',
        onPressed: puedeDeshacer && !bloqueada
            ? () => ref.read(partidaProvider.notifier).deshacer()
            : null,
      ),
      _BotonHud(
        key: const Key('rehacer'),
        icono: Icons.redo,
        etiqueta: 'Rehacer',
        onPressed: puedeRehacer && !bloqueada
            ? () => ref.read(partidaProvider.notifier).rehacer()
            : null,
      ),
      const BotonEnvios(),
      const BotonCuenta(),
    ];
    return Scaffold(
      // En juego no hay barra: la mesa llena la pantalla y la barra flota.
      appBar: enJuego
          ? null
          : AppBar(
              // Fuera de la mesa también se puede volver al inicio: no se
              // pierde nada, la partida queda guardada (#235).
              leading: IconButton(
                key: const Key('inicio-volver'),
                tooltip: 'Inicio',
                icon: const Icon(Icons.home_outlined),
                onPressed: () => ref.read(enPartidaProvider.notifier).salir(),
              ),
              title: Text(_titulo(estado)),
              actions: acciones,
            ),
      // La mesa ocupa toda la pantalla; el resto de fases van centradas.
      body: enJuego
          ? Stack(
              children: [
                Positioned.fill(child: _fase(estado)),
                Positioned(
                  left: 8,
                  right: 8,
                  top: 0,
                  child: SafeArea(
                    child: _BarraFlotante(
                      texto: _banner(estado),
                      textoCorto: textoCortoBanner(estado),
                      acciones: accionesHud,
                      onAbandonar: () => _abandonar(context, ref),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: _fase(estado),
              ),
            ),
    );
  }

  /// Versión corta del banner para pantallas estrechas: "R1 · J1", "R3 · Jefe".
  @visibleForTesting
  static String textoCortoBanner(EstadoPartida estado) {
    final actual = estado.jugadorActual;
    final turno = estado.fase == Fase.turnoJefe
        ? 'Jefe'
        : actual == null
            ? 'Jugadores'
            : etiquetaDueno(estado.jugadores[actual].nombre, actual);
    return 'R${estado.ronda} · $turno';
  }

  String _banner(EstadoPartida estado) {
    final actual = estado.jugadorActual;
    final turno = estado.fase == Fase.turnoJefe
        ? 'Turno del jefe'
        : actual == null
            ? 'Turno de los jugadores'
            : 'Turno de ${estado.jugadores[actual].nombre}';
    return 'Ronda ${estado.ronda} · $turno';
  }

  Widget _fase(EstadoPartida estado) => switch (estado.fase) {
        Fase.preparacion => const PantallaJugadores(),
        Fase.eleccionJefe => const PantallaEleccionJefe(),
        Fase.turnoJugadores => const PantallaTurnoJugadores(),
        Fase.turnoJefe => const PantallaTurnoJefe(),
        Fase.terminada => const PantallaFinPartida(),
      };

  String _titulo(EstadoPartida estado) => switch (estado.fase) {
        Fase.preparacion => 'Nueva partida',
        Fase.eleccionJefe => 'Elegir jefe',
        Fase.turnoJugadores => 'Turno de los jugadores',
        Fase.turnoJefe => 'Turno del jefe',
        Fase.terminada => 'Fin de la partida',
      };

  /// «Abandonar» ofrece dos salidas: Salir (la partida ya está guardada y se
  /// continúa desde el inicio) o Rendirse (termina en derrota, #235).
  Future<void> _abandonar(BuildContext context, WidgetRef ref) async {
    final opcion = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Abandonar la partida?'),
        content: const Text(
          'Salir guarda la partida tal como está y podrás continuarla desde '
          'el inicio. Rendirse la termina en derrota con el daño hecho hasta '
          'ahora; si te equivocas, puedes deshacerlo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Seguir jugando'),
          ),
          OutlinedButton(
            key: const Key('abandonar-salir'),
            onPressed: () => Navigator.of(context).pop('salir'),
            child: const Text('Salir'),
          ),
          FilledButton(
            key: const Key('abandonar-confirmar'),
            onPressed: () => Navigator.of(context).pop('rendirse'),
            child: const Text('Rendirse'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    switch (opcion) {
      case 'salir':
        ref.read(enPartidaProvider.notifier).salir();
      case 'rendirse':
        registrar(context, ref, const Abandonar());
    }
  }
}

/// Barra de la partida que flota sobre la mesa: ronda y turno a la izquierda,
/// deshacer, rehacer, envíos, cuenta y abandonar a la derecha.
class _BarraFlotante extends StatelessWidget {
  const _BarraFlotante({
    required this.texto,
    required this.textoCorto,
    required this.acciones,
    required this.onAbandonar,
  });

  final String texto;

  /// Lo que se muestra cuando la barra es estrecha y el texto largo no cabe.
  final String textoCorto;
  final List<Widget> acciones;
  final VoidCallback onAbandonar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          // El chip ocupa todo el hueco libre a la izquierda. Si el texto largo
          // no cabe, va el corto; si ni ese cabe, no se muestra (la ronda y el
          // turno ya salen en el panel de acciones) (#214).
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: LayoutBuilder(
                builder: (context, caja) {
                  const estilo = TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  );
                  // Relleno (14 + 14) y borde (2 + 2) del chip.
                  const extra = 32.0;
                  final escala = MediaQuery.textScalerOf(context);
                  bool cabe(String t) {
                    final medida = TextPainter(
                      text: TextSpan(text: t, style: estilo),
                      textDirection: TextDirection.ltr,
                      textScaler: escala,
                      maxLines: 1,
                    )..layout();
                    return medida.width + extra <= caja.maxWidth;
                  }

                  final mostrado = cabe(texto)
                      ? texto
                      : cabe(textoCorto)
                          ? textoCorto
                          : null;
                  if (mostrado == null) return const SizedBox.shrink();
                  return Container(
                    key: const Key('barra-turno'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xD91A1033),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      mostrado,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: estilo,
                    ),
                  );
                },
              ),
            ),
          ),
          Theme(
            data: tema.copyWith(
              iconButtonTheme: IconButtonThemeData(
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white38,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xD91A1033),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: acciones),
            ),
          ),
          const SizedBox(width: 12),
          // Aparte del resto para no pulsarlo sin querer.
          OutlinedButton.icon(
            key: const Key('abandonar'),
            onPressed: onAbandonar,
            icon: const Icon(Icons.flag),
            label: const Text('Abandonar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF8A80),
              backgroundColor: const Color(0xD91A1033),
              side: const BorderSide(color: Color(0xFFFF8A80), width: 3),
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón de la barra flotante: icono con su nombre debajo.
class _BotonHud extends StatelessWidget {
  const _BotonHud({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.onPressed,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final activo = onPressed != null;
    final color = activo ? Colors.white : Colors.white38;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 56,
        height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: color, size: 20),
            Text(
              etiqueta,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
