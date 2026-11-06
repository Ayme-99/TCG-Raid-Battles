import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../partida/controlador_partida.dart';
import 'comun.dart';
import 'fin_partida.dart';
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
    final enJuego =
        estado.fase == Fase.turnoJugadores || estado.fase == Fase.turnoJefe;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulo(estado)),
        actions: [
          IconButton(
            key: const Key('deshacer'),
            tooltip: 'Deshacer',
            icon: const Icon(Icons.undo),
            onPressed: puedeDeshacer
                ? () => ref.read(partidaProvider.notifier).deshacer()
                : null,
          ),
          IconButton(
            key: const Key('rehacer'),
            tooltip: 'Rehacer',
            icon: const Icon(Icons.redo),
            onPressed: puedeRehacer
                ? () => ref.read(partidaProvider.notifier).rehacer()
                : null,
          ),
          if (enJuego)
            IconButton(
              key: const Key('abandonar'),
              tooltip: 'Abandonar la partida',
              icon: const Icon(Icons.flag),
              onPressed: () => _abandonar(context, ref),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: switch (estado.fase) {
            Fase.preparacion => const PantallaJugadores(),
            Fase.eleccionJefe => const PantallaEleccionJefe(),
            Fase.turnoJugadores => const PantallaTurnoJugadores(),
            Fase.turnoJefe => const PantallaTurnoJefe(),
            Fase.terminada => const PantallaFinPartida(),
          },
        ),
      ),
    );
  }

  String _titulo(EstadoPartida estado) => switch (estado.fase) {
        Fase.preparacion => 'Nueva partida',
        Fase.eleccionJefe => 'Elegir jefe',
        Fase.turnoJugadores => 'Turno de los jugadores',
        Fase.turnoJefe => 'Turno del jefe',
        Fase.terminada => 'Fin de la partida',
      };

  Future<void> _abandonar(BuildContext context, WidgetRef ref) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Abandonar la partida?'),
        content: const Text(
          'Termina en derrota con el daño hecho hasta ahora. '
          'Si te equivocas, puedes deshacerlo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir jugando'),
          ),
          FilledButton(
            key: const Key('abandonar-confirmar'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Abandonar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !context.mounted) return;
    registrar(context, ref, const Abandonar());
  }
}
