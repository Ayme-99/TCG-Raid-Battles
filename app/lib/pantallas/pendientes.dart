import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../catalogo/catalogo.dart';
import '../partida/controlador_partida.dart';
import 'comun.dart';

/// Lo que hay que resolver antes de seguir: intentos de invocación y ataques
/// de entrada de los aliados (D-04).
class PanelPendientes extends ConsumerWidget {
  const PanelPendientes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoProvider);
    final intentos = estado.intentosInvocacionPendientes;
    final entradas = estado.entradasPendientes;
    if (intentos == 0 && entradas.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Por resolver',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (intentos > 0) ...[
              const SizedBox(height: 8),
              Text('Intentos de invocación: $intentos'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    key: const Key('invocar-aliado'),
                    onPressed: () async {
                      final evento = await showDialog<Evento>(
                        context: context,
                        builder: (_) => _DialogoAliado(
                          estado: estado,
                          catalogo: ref.read(catalogoProvider).valueOrNull,
                          azar: ref.read(azarProvider),
                        ),
                      );
                      if (evento == null || !context.mounted) return;
                      if (registrar(context, ref, evento) &&
                          evento is SinInvocacion) {
                        registrarAviso(
                            context, 'Salió cruz: no se invoca ningún aliado.');
                      }
                    },
                    child: const Text('Invocar aliado'),
                  ),
                  OutlinedButton(
                    key: const Key('sin-invocacion'),
                    onPressed: () =>
                        registrar(context, ref, const SinInvocacion()),
                    child: const Text('No se invoca'),
                  ),
                ],
              ),
            ],
            for (final a in entradas) ...[
              const SizedBox(height: 8),
              FilledButton.tonal(
                key: Key('entrada-${a.slot}'),
                onPressed: () => atacarConAliado(context, ref, estado, a),
                child: Text('${a.nombre} ataca al entrar (${a.ataqueDano})'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Registra el ataque de un aliado. Si el dueño de su slot está eliminado,
/// pregunta a qué jugador activo le tocó en la tirada.
Future<void> atacarConAliado(
  BuildContext context,
  WidgetRef ref,
  EstadoPartida estado,
  AliadoEstado aliado,
) async {
  int? objetivo;
  if (estado.jugadores[aliado.slot].eliminado) {
    objetivo = await elegirJugador(
      context,
      estado,
      titulo: 'El dueño del slot está eliminado: ¿a quién ataca?',
      asientos: jugadoresActivos(estado),
    );
    if (objetivo == null || !context.mounted) return;
  }
  registrar(
    context,
    ref,
    AtaqueAliado(
      slot: aliado.slot,
      dano: aliado.ataqueDano ?? 0,
      objetivo: objetivo,
    ),
  );
}

class _DialogoAliado extends StatefulWidget {
  const _DialogoAliado({
    required this.estado,
    required this.azar,
    this.catalogo,
  });

  final EstadoPartida estado;

  /// Origen de las tiradas del botón «Tirar dados».
  final Random azar;

  /// Catálogo empaquetado: si el jefe viene de él, se rellena el aliado de
  /// cada categoría con los datos de su carta.
  final Catalogo? catalogo;

  @override
  State<_DialogoAliado> createState() => _DialogoAliadoState();
}

class _DialogoAliadoState extends State<_DialogoAliado> {
  final _nombre = TextEditingController();
  final _hp = TextEditingController();
  final _ataqueNombre = TextEditingController();
  final _ataqueDano = TextEditingController();
  final _habilidad = TextEditingController();
  late int _slot = widget.estado.slotsLibres.isEmpty
      ? 0
      : widget.estado.slotsLibres.first;
  late CategoriaAliado _categoria = widget.estado.categoriasLibres.isEmpty
      ? CategoriaAliado.danio
      : widget.estado.categoriasLibres.first;

  /// El jefe tiene carta de aliado en el catálogo para la categoría elegida.
  bool _delCatalogo = false;

  /// Quién aplica los efectos de la carta del catálogo (D-13) y, si es el
  /// programa, su script. Sin carta del catálogo los aplica el jugador.
  EfectosAliado _efectos = EfectosAliado.jugador;
  String? _scriptId;

  @override
  void initState() {
    super.initState();
    _rellenar(_categoria);
  }

  /// Resultado de la última tirada, para enseñarlo.
  String? _tirada;

  /// Nombre del dado que elige entre [n] valores (D-13): moneda con 2, d3, d4.
  static String _dado(int n) => n == 2 ? 'moneda' : 'd$n';

  /// Tira la moneda del jefe (si no es de invocación segura), el dado de slot
  /// y el de categoría (D-13). Cada dado elige con la misma probabilidad entre
  /// los valores libres, que es lo que da repetir la tirada en la mesa.
  void _tirarDados() {
    final e = widget.estado;
    final jefe = e.jefe;
    final inv = jefe == null
        ? null
        : widget.catalogo?.invocacionDe(jefe.nombre, jefe.nivel);
    if (inv != null && !inv.segura && !widget.azar.nextBool()) {
      Navigator.of(context).pop(const SinInvocacion());
      return;
    }
    final slots = e.slotsLibres;
    // Si el jefe viene del catálogo, el dado solo tiene las caras de los
    // aliados que su carta define (D-16: hasta que tenga los 6).
    final categorias = [
      for (final c in e.categoriasLibres)
        if (inv == null || inv.aliados.containsKey(c)) c,
    ];
    if (slots.isEmpty || categorias.isEmpty) return;
    final slot = slots[widget.azar.nextInt(slots.length)];
    final categoria = categorias[widget.azar.nextInt(categorias.length)];
    setState(() {
      _slot = slot;
      _categoria = categoria;
      _rellenar(categoria);
      _tirada = 'Dado de slot (${_dado(e.jugadores.length)}): '
          '${e.jugadores[slot].nombre} · '
          'dado de categoría (d${inv?.aliados.length ?? CategoriaAliado.values.length}): '
          '${etiquetaCategoria(categoria)}';
    });
  }

  /// Rellena los campos con el aliado del catálogo de esa categoría, si lo hay.
  /// Se pueden editar después por si la carta física es distinta.
  void _rellenar(CategoriaAliado categoria) {
    final jefe = widget.estado.jefe;
    final a = jefe == null
        ? null
        : widget.catalogo?.aliadoDe(jefe.nombre, jefe.nivel, categoria);
    _delCatalogo = a != null;
    _efectos = a?.efectos ?? EfectosAliado.jugador;
    _scriptId = a?.scriptId;
    if (a == null) return;
    _nombre.text = a.nombre;
    _hp.text = '${a.hp}';
    _ataqueNombre.text = a.ataqueNombre ?? '';
    _ataqueDano.text = a.ataqueDano == null ? '' : '${a.ataqueDano}';
    _habilidad.text = a.habilidad ?? '';
  }

  @override
  void dispose() {
    _nombre.dispose();
    _hp.dispose();
    _ataqueNombre.dispose();
    _ataqueDano.dispose();
    _habilidad.dispose();
    super.dispose();
  }

  String? _opcional(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    final libres = widget.estado.slotsLibres;
    return AlertDialog(
      title: const Text('Aliado invocado'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.tonalIcon(
              key: const Key('tirar-dados'),
              onPressed: _tirarDados,
              icon: const Icon(Icons.casino),
              label: const Text('Tirar dados'),
            ),
            if (_tirada != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_tirada!, key: const Key('resultado-dados')),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final a in libres)
                  ChoiceChip(
                    key: Key('aliado-slot-$a'),
                    label: Text('Slot de ${widget.estado.jugadores[a].nombre}'),
                    selected: _slot == a,
                    onSelected: (_) => setState(() => _slot = a),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Categoría (D-13): solo las que no tienen aliado vivo.
            Wrap(
              spacing: 8,
              children: [
                for (final c in widget.estado.categoriasLibres)
                  ChoiceChip(
                    key: Key('aliado-categoria-${c.name}'),
                    label: Text(etiquetaCategoria(c)),
                    selected: _categoria == c,
                    onSelected: (_) => setState(() {
                      _categoria = c;
                      _rellenar(c);
                    }),
                  ),
              ],
            ),
            if (_delCatalogo)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Datos de la carta del catálogo; edítalos si la carta '
                  'física es distinta.',
                  key: const Key('aliado-del-catalogo'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('aliado-nombre'),
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            KeyedSubtree(
              key: const Key('aliado-hp'),
              child: CampoNumero(controlador: _hp, etiqueta: 'HP'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ataqueNombre,
              decoration: const InputDecoration(labelText: 'Ataque (nombre)'),
            ),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: const Key('aliado-dano'),
              child: CampoNumero(
                controlador: _ataqueDano,
                etiqueta: 'Daño del ataque (vacío: no ataca)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _habilidad,
              decoration: const InputDecoration(labelText: 'Habilidad'),
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
          key: const Key('aliado-aceptar'),
          onPressed: () => Navigator.of(context).pop(
            AliadoInvocado(
              slot: _slot,
              categoria: _categoria,
              nombre: _nombre.text.trim().isEmpty ? 'Aliado' : _nombre.text.trim(),
              hp: int.tryParse(_hp.text) ?? 0,
              ataqueNombre: _opcional(_ataqueNombre),
              ataqueDano: int.tryParse(_ataqueDano.text),
              habilidad: _opcional(_habilidad),
              efectos: _efectos,
              scriptId: _scriptId,
            ),
          ),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}
