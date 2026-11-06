import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../partida/controlador_partida.dart';
import 'comun.dart';

/// El jefe: vida, estados alterados y curación.
class TarjetaJefe extends ConsumerWidget {
  const TarjetaJefe({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoProvider);
    final jefe = estado.jefe;
    if (jefe == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${jefe.nombre} · Nv. ${jefe.nivel}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text('Ronda ${estado.ronda}'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: jefe.hpMaximo == 0 ? 0 : jefe.hp / jefe.hpMaximo,
              minHeight: 12,
            ),
            const SizedBox(height: 4),
            Text(
              'HP ${jefe.hp} / ${jefe.hpMaximo}',
              key: const Key('hp-jefe'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (jefe.envenenado) const Chip(label: Text('Envenenado')),
                if (jefe.quemado) const Chip(label: Text('Quemado')),
                ActionChip(
                  key: const Key('curar-jefe'),
                  label: const Text('Curar al jefe'),
                  onPressed: () async {
                    final cantidad = await pedirNumero(
                      context,
                      titulo: 'Curar al jefe',
                      etiqueta: 'HP que recupera',
                    );
                    if (cantidad == null || !context.mounted) return;
                    registrar(context, ref, CuracionJefe(cantidad));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
