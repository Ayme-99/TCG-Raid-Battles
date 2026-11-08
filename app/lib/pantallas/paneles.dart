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

/// Aliados vivos del jefe: categoría (D-13), dueño del slot, HP y su carta.
class PanelAliados extends ConsumerWidget {
  const PanelAliados({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoProvider);
    if (estado.aliados.isEmpty) return const SizedBox.shrink();
    return Card(
      key: const Key('panel-aliados'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aliados del jefe',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (reduccionDanoAlJefe(estado) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Los ataques de los jugadores hacen '
                  '${reduccionDanoAlJefe(estado)} de daño menos al jefe '
                  '(lo descuenta la app).',
                  key: const Key('reduccion-dano'),
                ),
              ),
            const SizedBox(height: 8),
            for (final a in estado.aliados)
              Padding(
                key: Key('aliado-${a.slot}'),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${etiquetaCategoria(a.categoria)} · ${a.nombre} · '
                      'slot de ${estado.jugadores[a.slot].nombre} · '
                      '${a.hp}/${a.hpMaximo} HP',
                    ),
                    if (a.tieneAtaque || a.habilidad != null)
                      Text(
                        [
                          if (a.tieneAtaque)
                            '${a.ataqueNombre ?? 'Ataque'}: ${a.ataqueDano}',
                          if (a.habilidad != null) a.habilidad!,
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
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

/// Efectos de los ataques del jefe que siguen activos sobre algún jugador
/// (D-14). Los aplican los jugadores en la mesa; aquí solo se recuerdan.
class PanelEfectosActivos extends ConsumerWidget {
  const PanelEfectosActivos({super.key});

  static String _que(TipoEfectoAtaque tipo) => switch (tipo) {
        TipoEfectoAtaque.sinRetirada => 'no puede retirarse',
        TipoEfectoAtaque.sinAtaque => 'no puede atacar',
        TipoEfectoAtaque.paralizarDefensor => 'está paralizado',
        _ => tipo.name,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoProvider);
    if (estado.efectosActivos.isEmpty) return const SizedBox.shrink();
    return Card(
      key: const Key('efectos-activos'),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Efectos del jefe activos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final f in estado.efectosActivos)
              Text(
                '${estado.jugadores[f.jugador].nombre} ${_que(f.tipo)} '
                '(${f.restantes} ${f.restantes == 1 ? 'turno' : 'turnos'})',
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
