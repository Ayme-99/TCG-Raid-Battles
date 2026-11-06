import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

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
                      final evento = await showDialog<AliadoInvocado>(
                        context: context,
                        builder: (_) => _DialogoAliado(estado: estado),
                      );
                      if (evento == null || !context.mounted) return;
                      registrar(context, ref, evento);
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

String _etiquetaCategoria(CategoriaAliado c) => switch (c) {
      CategoriaAliado.danio => 'Daño',
      CategoriaAliado.barrera => 'Barrera',
      CategoriaAliado.cura => 'Cura',
      CategoriaAliado.picaro => 'Pícaro',
    };

class _DialogoAliado extends StatefulWidget {
  const _DialogoAliado({required this.estado});

  final EstadoPartida estado;

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
                    label: Text(_etiquetaCategoria(c)),
                    selected: _categoria == c,
                    onSelected: (_) => setState(() => _categoria = c),
                  ),
              ],
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
            ),
          ),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}
