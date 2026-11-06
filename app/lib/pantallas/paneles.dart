import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../partida/controlador_partida.dart';
import 'comun.dart';

/// Pokémon que le quedan a cada jugador y botón para anotar un KO.
class PanelPokemon extends ConsumerWidget {
  const PanelPokemon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pokémon de los jugadores',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final j in estado.jugadores)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        j.eliminado
                            ? '${j.nombre} · eliminado'
                            : '${j.nombre} · ${j.pokemonVivos}/$pokemonPorJugador',
                        key: Key('pokemon-${j.asiento}'),
                      ),
                    ),
                    OutlinedButton(
                      key: Key('ko-${j.asiento}'),
                      onPressed: j.eliminado
                          ? null
                          : () => registrar(context, ref, PokemonKo(j.asiento)),
                      child: const Text('Pokémon KO'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Aplicar veneno o quemadura al jefe (D-12). Solo cuenta para el bono si el
/// jefe no tenía ya el estado; eso lo decide el motor.
class PanelEstados extends ConsumerStatefulWidget {
  const PanelEstados({super.key, this.jugadorInicial});

  /// Jugador preseleccionado (el que está jugando su turno).
  final int? jugadorInicial;

  @override
  ConsumerState<PanelEstados> createState() => _PanelEstadosState();
}

class _PanelEstadosState extends ConsumerState<PanelEstados> {
  int? _jugador;

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(estadoProvider);
    final activos = jugadoresActivos(estado);
    var elegido = _jugador ?? widget.jugadorInicial;
    if (elegido == null || !activos.contains(elegido)) {
      elegido = activos.isEmpty ? null : activos.first;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estados del jefe',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('¿Qué jugador ha aplicado el estado?'),
            Wrap(
              spacing: 8,
              children: [
                for (final a in activos)
                  ChoiceChip(
                    key: Key('estado-jugador-$a'),
                    label: Text(estado.jugadores[a].nombre),
                    selected: elegido == a,
                    onSelected: (_) => setState(() => _jugador = a),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final e in EstadoDelJefe.values)
                  FilledButton.tonal(
                    key: Key('estado-${e.name}'),
                    onPressed: elegido == null
                        ? null
                        : () => registrar(
                              context,
                              ref,
                              AplicarEstadoJefe(jugador: elegido!, estado: e),
                            ),
                    child: Text(
                      e == EstadoDelJefe.veneno
                          ? 'Envenenar'
                          : 'Quemar',
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
