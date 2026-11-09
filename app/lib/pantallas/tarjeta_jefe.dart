import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../partida/controlador_partida.dart';
import 'comun.dart';
import 'estilo.dart';

/// El jefe: vida, estados alterados y curación.
class TarjetaJefe extends ConsumerWidget {
  const TarjetaJefe({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoProvider);
    final jefe = estado.jefe;
    if (jefe == null) return const SizedBox.shrink();
    final color = colorNivel(jefe.nivel);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.black, 0.15)!, const Color(0xFF1A1033)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.85),
            blurRadius: 28,
            spreadRadius: 3,
          ),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            color: Colors.white,
            shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${jefe.nombre} · Nv. ${jefe.nivel}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Ronda ${estado.ronda}'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              BarraVida(
                fraccion: jefe.hpMaximo == 0 ? 0 : jefe.hp / jefe.hpMaximo,
                alto: 22,
              ),
              const SizedBox(height: 4),
              Text(
                'HP ${jefe.hp} / ${jefe.hpMaximo}',
                key: const Key('hp-jefe'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (jefe.envenenado)
                    const Chip(
                      avatar: Icon(Icons.science, color: Colors.purple),
                      label: Text('Envenenado'),
                    ),
                  if (jefe.quemado)
                    const Chip(
                      avatar: Icon(Icons.whatshot, color: Colors.deepOrange),
                      label: Text('Quemado'),
                    ),
                  ActionChip(
                    key: const Key('curar-jefe'),
                    avatar: const Icon(Icons.favorite, color: Colors.green),
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
      ),
    );
  }
}
