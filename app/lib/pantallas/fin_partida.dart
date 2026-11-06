import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../cuenta/controlador_sesion.dart';
import '../cuenta/pantalla_login.dart';
import '../envios/controlador_envios.dart';
import '../partida/controlador_partida.dart';
import 'comun.dart';

/// Fin de partida: resultado, puntos de cada jugador (D-10, D-12) y guardado
/// de los resultados en el servidor.
class PantallaFinPartida extends ConsumerWidget {
  const PantallaFinPartida({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoProvider);
    final puntos = ref.watch(puntosProvider);
    final victoria = estado.resultado == Resultado.victoria;
    final guardada =
        ref.watch(enviosProvider.select((e) => e.partidaEncolada != null));
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
                  !j.abonado
                      ? '${j.puntos} (invitado)'
                      : j.bonoEstados > 0
                          ? '${j.puntos} + ${j.bonoEstados}'
                          : '${j.puntos}',
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        const _GuardarResultados(),
        const SizedBox(height: 16),
        OutlinedButton(
          key: const Key('nueva-partida'),
          onPressed: () async {
            if (!guardada) {
              final descartar = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('¿Empezar sin guardar?'),
                  content: const Text(
                    'Los resultados de esta partida no se han guardado y '
                    'los puntos se perderán.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Volver'),
                    ),
                    FilledButton(
                      key: const Key('descartar-confirmar'),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Descartar'),
                    ),
                  ],
                ),
              );
              if (descartar != true) return;
            }
            ref.read(partidaProvider.notifier).nuevaPartida();
          },
          child: const Text('Nueva partida'),
        ),
      ],
    );
  }
}

/// Estado del guardado: pedir sesión, botón de guardar o cómo va el envío.
class _GuardarResultados extends ConsumerWidget {
  const _GuardarResultados();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionActualProvider);
    final envios = ref.watch(enviosProvider);
    final guardada = envios.partidaEncolada != null;

    final Widget contenido;
    if (sesion == null) {
      contenido = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inicia sesión con tu cuenta de Deck Tracker para guardar los '
            'puntos. Los demás jugadores cuentan como invitados.',
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('iniciar-sesion'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PantallaLogin()),
            ),
            child: const Text('Iniciar sesión'),
          ),
        ],
      );
    } else if (!guardada) {
      contenido = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Los puntos del jugador 1 se abonarán a ${sesion.username}. '
            'Después de guardar ya no se puede deshacer.',
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('guardar-resultados'),
            onPressed: () async {
              final error =
                  await ref.read(enviosProvider.notifier).guardarPartidaActual();
              if (error != null && context.mounted) {
                registrarAviso(context, error);
              }
            },
            child: const Text('Guardar resultados'),
          ),
        ],
      );
    } else {
      final String texto;
      if (envios.rechazadas > 0 && envios.pendientes == 0) {
        texto = envios.mensaje ?? 'El servidor ha rechazado la partida.';
      } else if (envios.pendientes > 0) {
        texto = 'Guardada en este dispositivo y pendiente de enviar. '
            '${envios.mensaje ?? 'Enviando...'}';
      } else {
        texto = 'Resultados guardados. Los puntos ya cuentan en tu cuenta.';
      }
      contenido = Text(texto, key: const Key('estado-envio'));
    }
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: contenido),
    );
  }
}
