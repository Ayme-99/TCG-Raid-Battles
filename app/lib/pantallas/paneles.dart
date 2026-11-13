import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../partida/controlador_partida.dart';
import 'carta.dart';
import 'comun.dart';
import 'estilo.dart';

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

/// El slot de aliado de un jugador: la carta del aliado si lo hay (salen como
/// Pokémon salvajes, sin decir la categoría) o un hueco punteado con el color
/// de su dueño. Los slots rodean al jefe en la mesa.
class SlotAliado extends ConsumerWidget {
  const SlotAliado({super.key, required this.slot});

  final int slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoProvider);
    final aliado = estado.aliados.where((a) => a.slot == slot).firstOrNull;
    if (aliado != null) {
      return _CartaAliado(
        aliado: aliado,
        dueno: estado.jugadores[slot].nombre,
      );
    }
    final color = coloresAsiento[slot % coloresAsiento.length];
    final dueno = estado.jugadores[slot];
    return Column(
      key: Key('slot-libre-$slot'),
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 480 / 670,
          child: CustomPaint(
            painter: _BordePunteado(color),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1033).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dueno.nombre.isEmpty ? '?' : dueno.nombre[0].toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'Slot libre',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Borde de trazos redondeado, para los huecos vacíos.
class _BordePunteado extends CustomPainter {
  const _BordePunteado(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final camino = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(12),
        ),
      );
    for (final tramo in camino.computeMetrics()) {
      var d = 0.0;
      while (d < tramo.length) {
        canvas.drawPath(tramo.extractPath(d, d + 9), trazo);
        d += 15;
      }
    }
  }

  @override
  bool shouldRepaint(_BordePunteado old) => old.color != color;
}

/// Un aliado: su carta y debajo su dueño y su vida.
class _CartaAliado extends StatelessWidget {
  const _CartaAliado({required this.aliado, required this.dueno});

  final AliadoEstado aliado;
  final String dueno;

  @override
  Widget build(BuildContext context) {
    final a = aliado;
    return Column(
      key: Key('aliado-${a.slot}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        CartaImagen(
          nombre: a.nombre,
          alternativa: _AliadoSinImagen(aliado: a),
        ),
        const SizedBox(height: 6),
        Text(
          '${a.nombre} · $dueno',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 3),
        BarraVida(
          fraccion: a.hpMaximo == 0 ? 0 : a.hp / a.hpMaximo,
          alto: 12,
        ),
        Text(
          '${a.hp}/${a.hpMaximo} HP',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

/// Lo que se ve mientras el aliado no tiene todavía su imagen: su ataque y su
/// habilidad, sin decir la categoría.
class _AliadoSinImagen extends StatelessWidget {
  const _AliadoSinImagen({required this.aliado});

  final AliadoEstado aliado;

  @override
  Widget build(BuildContext context) {
    final a = aliado;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6D5BA8), Color(0xFF2A1B52)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 2),
      ),
      padding: const EdgeInsets.all(6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 110,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.catching_pokemon, color: Colors.white, size: 30),
              const SizedBox(height: 4),
              if (a.tieneAtaque)
                Text(
                  '${a.ataqueNombre ?? 'Ataque'}: ${a.ataqueDano}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (a.habilidad != null)
                Text(
                  a.habilidad!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
            ],
          ),
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
