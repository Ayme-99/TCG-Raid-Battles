import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../cuenta/controlador_sesion.dart';
import '../cuenta/pantalla_login.dart';
import '../envios/controlador_envios.dart';
import '../partida/controlador_partida.dart';
import 'comun.dart';
import 'estilo.dart';
import 'setup.dart';
import 'inicio.dart';

/// Fin de partida: resultado, cómo ha ido cada jugador y guardado
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
    final tema = Theme.of(context);
    final color = victoria ? const Color(0xFFE8C05A) : const Color(0xFFFF6B6B);
    final ordenados = puntos == null
        ? const <PuntosJugador>[]
        : ([...puntos.jugadores]..sort((a, b) => a.puesto.compareTo(b.puesto)));
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              victoria ? 'Victoria' : 'Derrota',
              key: const Key('resultado'),
              textAlign: TextAlign.center,
              style: tema.textTheme.displayMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            // La partida libre no da puntos: solo se enseña cómo ha ido cada uno.
            if (puntos != null) ...[
              Text(
                'Jefe: nivel ${puntos.nivel} · daño neto ${puntos.danoTotal}',
                key: const Key('resumen-jefe'),
                textAlign: TextAlign.center,
                style: tema.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              for (final j in ordenados) _FilaJugador(j),
            ],
            const SizedBox(height: 8),
            const _GuardarResultados(),
            const SizedBox(height: 16),
            // Las tres salidas valen igual si se gana, se pierde o se rinde (#234).
            FilledButton.icon(
              key: const Key('revancha'),
              onPressed: () =>
                  _empezarOtra(context, ref, guardada, revancha: true),
              icon: const Icon(Icons.replay),
              label: const Text('Revancha'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('nueva-partida'),
              onPressed: () => _empezarOtra(context, ref, guardada),
              child: const Text('Nueva partida'),
            ),
            const SizedBox(height: 8),
            // Volver al inicio no descarta nada: la partida sigue como Continuar
            // hasta que se guarden los resultados.
            TextButton.icon(
              key: const Key('volver-inicio'),
              onPressed: () => ref.read(enPartidaProvider.notifier).salir(),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    );
  }

  /// Empieza otra partida. Si los resultados no se han guardado, antes pide
  /// confirmar que se descartan. [revancha]: mismos jugadores y equipo; solo
  /// queda elegir jefe.
  Future<void> _empezarOtra(
    BuildContext context,
    WidgetRef ref,
    bool guardada, {
    bool revancha = false,
  }) async {
    if (!guardada) {
      final descartar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Empezar sin guardar?'),
          content: const Text(
            'Los resultados de esta partida no se han guardado y '
            'los resultados se perderán.',
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
      if (descartar != true || !context.mounted) return;
    }
    // Los jugadores se leen antes de descartar la partida.
    final anterior = ref.read(estadoProvider);
    final jugadores = [
      for (final j in anterior.jugadores)
        ConfigJugador(nombre: j.nombre, ataqueMaximo: j.ataqueMaximo),
    ];
    ref.read(partidaProvider.notifier).nuevaPartida();
    // Una partida nueva o una revancha conservan el modo de preparación.
    ref.read(modoPreparacionProvider.notifier).fijar(anterior.modo);
    ref.read(jefePreelegidoProvider.notifier).fijar(null);
    if (revancha) {
      registrar(context, ref, ConfigurarJugadores(jugadores, modo: anterior.modo));
    }
  }
}

/// Una fila del resultado: el puesto, el nombre y el daño, con el color del
/// asiento del jugador, igual que en la mesa.
class _FilaJugador extends StatelessWidget {
  const _FilaJugador(this.j);

  final PuntosJugador j;

  @override
  Widget build(BuildContext context) {
    final color = coloresAsiento[j.asiento % coloresAsiento.length];
    const tinta = Color(0xFF14102B);
    final base = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          key: Key('jugador-${j.asiento}'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white70,
                foregroundColor: tinta,
                child: Text(
                  '${j.puesto}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      j.nombre,
                      style: base.titleLarge?.copyWith(
                        color: tinta,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Pokémon perdidos ${j.pokemonPerdidos} · '
                      'estados aplicados ${j.estadosAplicados}',
                      style: base.bodyMedium?.copyWith(color: tinta),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Daño ${j.dano} · ${j.porcentaje}%',
                style: base.titleMedium?.copyWith(
                  color: tinta,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
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
            'Inicia sesión con tu cuenta de Deck Tracker para guardar la '
            'partida en tu historial. Los demás jugadores cuentan como '
            'invitados.',
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
            'La partida se guardará en el historial de ${sesion.username}. '
            'Después de guardar ya no se puede deshacer.',
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('guardar-resultados'),
            onPressed: () async {
              final error =
                  await ref.read(enviosProvider.notifier).guardarPartidaActual();
              if (error != null && context.mounted) {
                registrarAviso(context, error, tipo: TipoAviso.error);
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
        texto = 'Resultados guardados en tu historial.';
      }
      contenido = Text(texto, key: const Key('estado-envio'));
    }
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: contenido),
    );
  }
}
