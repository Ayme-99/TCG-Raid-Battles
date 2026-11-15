import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../partida/controlador_partida.dart';
import 'acciones_objetivo.dart';
import 'carta.dart';
import 'comun.dart';
import 'estilo.dart';

/// Daño que un efecto hace al jefe o a un aliado (rebote, T-59). Al jefe se
/// atribuye al jugador que recibió el ataque; a un aliado, a nadie. Si se
/// abre desde un aliado, viene ya elegido ([slotInicial]).
Future<void> registrarDanoDeEfecto(
  BuildContext context,
  WidgetRef ref, {
  int? slotInicial,
}) async {
  final evento = await showDialog<DanoDeEfecto>(
    context: context,
    builder: (_) => _DialogoDanoDeEfecto(slotInicial: slotInicial),
  );
  if (evento == null || !context.mounted) return;
  registrar(context, ref, evento);
}

class _DialogoDanoDeEfecto extends ConsumerStatefulWidget {
  const _DialogoDanoDeEfecto({this.slotInicial});

  final int? slotInicial;

  @override
  ConsumerState<_DialogoDanoDeEfecto> createState() =>
      _DialogoDanoDeEfectoState();
}

class _DialogoDanoDeEfectoState extends ConsumerState<_DialogoDanoDeEfecto> {
  final _puntos = TextEditingController();

  /// Slot del aliado dañado; `null` si el daño va al jefe.
  late int? _slot = widget.slotInicial;

  /// Jugador al que se atribuye el daño al jefe.
  int? _jugador;

  @override
  void initState() {
    super.initState();
    _puntos.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _puntos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(estadoProvider);
    final puntos = int.tryParse(_puntos.text) ?? 0;
    final alJefe = _slot == null;
    final listo = puntos > 0 && (!alJefe || _jugador != null);
    return AlertDialog(
      title: const Text('Daño por efecto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿A quién daña?'),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('dano-efecto-jefe'),
                  label: const Text('Al jefe'),
                  selected: alJefe,
                  onSelected: (_) => setState(() => _slot = null),
                ),
                for (final a in estado.aliados)
                  ChoiceChip(
                    key: Key('dano-efecto-aliado-${a.slot}'),
                    label: Text(a.nombre),
                    selected: _slot == a.slot,
                    onSelected: (_) => setState(() => _slot = a.slot),
                  ),
              ],
            ),
            if (alJefe) ...[
              const SizedBox(height: 12),
              const Text('Se atribuye al jugador que recibió el ataque:'),
              Wrap(
                spacing: 8,
                children: [
                  for (final j in estado.jugadores)
                    if (!j.eliminado)
                      ChoiceChip(
                        key: Key('dano-efecto-jugador-${j.asiento}'),
                        label: Text(j.nombre),
                        selected: _jugador == j.asiento,
                        onSelected: (_) =>
                            setState(() => _jugador = j.asiento),
                      ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            CampoNumero(
              key: const Key('dano-efecto-puntos'),
              controlador: _puntos,
              etiqueta: 'Puntos de daño',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('dano-efecto-confirmar'),
          onPressed: !listo
              ? null
              : () => Navigator.of(context).pop(
                    DanoDeEfecto(
                      puntos: puntos,
                      jugador: alJefe ? _jugador : null,
                      slot: _slot,
                    ),
                  ),
          child: const Text('Registrar'),
        ),
      ],
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
        dueno: etiquetaDueno(estado.jugadores[slot].nombre, slot),
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

/// Etiqueta corta del dueño de un aliado: la inicial de su nombre y su asiento
/// ("Jugador 1" → "J1", "Antonio" en el asiento 2 → "A2"). El número evita que
/// dos jugadores con la misma inicial se confundan.
String etiquetaDueno(String nombre, int slot) {
  final limpio = nombre.trim();
  final inicial = limpio.isEmpty ? '?' : limpio.substring(0, 1).toUpperCase();
  return '$inicial${slot + 1}';
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
        // Pastilla oscura: cada mapa tiene un fondo distinto y el texto suelto
        // no se lee sobre todos (#216).
        Container(
          key: Key('etiqueta-aliado-${a.slot}'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1235).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${a.nombre} · $dueno',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              BarraVida(
                fraccion: a.hpMaximo == 0 ? 0 : a.hp / a.hpMaximo,
                alto: 12,
              ),
              Text(
                '${a.hp}/${a.hpMaximo} HP',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (a.envenenado || a.quemado)
                Text(
                  [if (a.envenenado) 'Envenenado', if (a.quemado) 'Quemado']
                      .join(' · '),
                  key: Key('estados-aliado-${a.slot}'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Consumer(
          builder: (context, ref, _) => BotonMenu(
            key: Key('menu-aliado-${a.slot}'),
            etiqueta: 'Acciones de ${a.nombre}',
            tamano: 32,
            onPressed: () => menuAliado(context, ref, a.slot),
          ),
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
