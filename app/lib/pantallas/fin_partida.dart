import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../partida/controlador_partida.dart';

/// Fin de partida: resultado y puntos de cada jugador (D-10, D-12).
class PantallaFinPartida extends ConsumerWidget {
  const PantallaFinPartida({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoProvider);
    final puntos = ref.watch(puntosProvider);
    final victoria = estado.resultado == Resultado.victoria;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          victoria ? 'Victoria' : 'Derrota',
          key: const Key('resultado'),
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 8),
        if (puntos != null) ...[
          Text(
            'Jefe: nivel ${puntos.nivel} · daño neto ${puntos.danoTotal}',
          ),
          Text(
            'Puntos del equipo: ${puntos.puntosTotal}',
            key: const Key('puntos-equipo'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          for (final j in puntos.jugadores)
            Card(
              child: ListTile(
                key: Key('puntos-${j.asiento}'),
                leading: CircleAvatar(child: Text('${j.puesto}')),
                title: Text(j.nombre),
                subtitle: Text(
                  'Daño ${j.dano} · ${j.porcentaje}% · '
                  'Pokémon perdidos ${j.pokemonPerdidos} · '
                  'estados aplicados ${j.estadosAplicados}',
                ),
                trailing: Text(
                  j.bonoEstados > 0
                      ? '${j.puntos} + ${j.bonoEstados}'
                      : '${j.puntos}',
                ),
              ),
            ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('nueva-partida'),
          onPressed: () => ref.read(partidaProvider.notifier).nuevaPartida(),
          child: const Text('Nueva partida'),
        ),
      ],
    );
  }
}
