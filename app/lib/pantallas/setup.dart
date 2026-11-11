import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../catalogo/catalogo.dart';
import '../partida/controlador_partida.dart';
import 'comun.dart';

/// Setup, paso 1: jugadores y daño de su mejor ataque (D-02).
class PantallaJugadores extends ConsumerStatefulWidget {
  const PantallaJugadores({super.key});

  @override
  ConsumerState<PantallaJugadores> createState() => _PantallaJugadoresState();
}

class _FilaJugador {
  _FilaJugador(String nombre) : nombre = TextEditingController(text: nombre);

  final TextEditingController nombre;
  final TextEditingController ataque = TextEditingController();

  void dispose() {
    nombre.dispose();
    ataque.dispose();
  }
}

class _PantallaJugadoresState extends ConsumerState<PantallaJugadores> {
  final List<_FilaJugador> _filas = [
    _FilaJugador('Jugador 1'),
    _FilaJugador('Jugador 2'),
  ];

  @override
  void dispose() {
    for (final f in _filas) {
      f.dispose();
    }
    super.dispose();
  }

  void _anadir() {
    if (_filas.length >= maxJugadores) return;
    setState(() => _filas.add(_FilaJugador('Jugador ${_filas.length + 1}')));
  }

  void _quitar() {
    if (_filas.length <= 1) return;
    setState(() => _filas.removeLast().dispose());
  }

  void _configurar() {
    registrar(
      context,
      ref,
      ConfigurarJugadores([
        for (final f in _filas)
          ConfigJugador(
            nombre: f.nombre.text.trim().isEmpty
                ? 'Jugador'
                : f.nombre.text.trim(),
            ataqueMaximo: int.tryParse(f.ataque.text) ?? 0,
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Jugadores y su mejor ataque',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        const Text(
          'Escribe el daño del mejor ataque de cada jugador. '
          'Con eso se calcula X y el nivel del jefe.',
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < _filas.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    key: Key('nombre-$i'),
                    controller: _filas[i].nombre,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: KeyedSubtree(
                    key: Key('ataque-$i'),
                    child: CampoNumero(
                      controlador: _filas[i].ataque,
                      etiqueta: 'Mejor ataque',
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            OutlinedButton.icon(
              key: const Key('anadir-jugador'),
              onPressed: _filas.length < maxJugadores ? _anadir : null,
              icon: const Icon(Icons.person_add),
              label: const Text('Añadir jugador'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              key: const Key('quitar-jugador'),
              onPressed: _filas.length > 1 ? _quitar : null,
              icon: const Icon(Icons.person_remove),
              label: const Text('Quitar jugador'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('configurar'),
          onPressed: _configurar,
          child: const Text('Calcular nivel'),
        ),
      ],
    );
  }
}

/// Setup, paso 2: elegir el jefe del nivel calculado.
class PantallaEleccionJefe extends ConsumerStatefulWidget {
  const PantallaEleccionJefe({super.key});

  @override
  ConsumerState<PantallaEleccionJefe> createState() =>
      _PantallaEleccionJefeState();
}

class _PantallaEleccionJefeState extends ConsumerState<PantallaEleccionJefe> {
  final _nombre = TextEditingController();
  final _hp = TextEditingController();
  final _invocacion = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    _hp.dispose();
    _invocacion.dispose();
    super.dispose();
  }

  void _elegir(EstadoPartida estado) {
    final cada = int.tryParse(_invocacion.text);
    registrar(
      context,
      ref,
      ElegirJefe(
        nombre: _nombre.text.trim().isEmpty ? 'Jefe' : _nombre.text.trim(),
        nivel: estado.nivel,
        hp: int.tryParse(_hp.text) ?? 0,
        invocacionCadaHp: cada == null || cada == 0 ? null : cada,
      ),
    );
  }

  void _elegirDelCatalogo(JefeCatalogo jefe) {
    registrar(
      context,
      ref,
      ElegirJefe(
        nombre: jefe.nombre,
        nivel: jefe.nivel,
        hp: jefe.hp,
        invocacionCadaHp: jefe.invocacion?.cadaHp,
        jefeId: jefe.id,
      ),
    );
  }

  String _resumen(JefeCatalogo j) {
    final ataques = j.ataques.map((a) => a.dano).join('/');
    final n = j.intentosDeInvocacion;
    final invoca = n == 0
        ? 'no invoca'
        : 'invoca $n aliado${n == 1 ? '' : 's'}'
            '${j.invocacion!.segura ? ' (seguro)' : ''}';
    return '${j.hp} HP · ataques $ataques · $invoca';
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(estadoProvider);
    final delNivel =
        (ref.watch(catalogoProvider).valueOrNull ?? Catalogo.vacio)
            .delNivel(estado.nivel);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Nivel ${estado.nivel} (X = ${estado.x})',
          key: const Key('nivel-calculado'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        const Text('Elige un jefe del catálogo o introduce su carta a mano.'),
        const SizedBox(height: 16),
        if (delNivel.isNotEmpty) ...[
          Text(
            'Jefes del catálogo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final j in delNivel)
            Card(
              child: ListTile(
                key: Key('catalogo-${j.id}'),
                title: Text(j.nombre),
                subtitle: Text(_resumen(j)),
                trailing: const Icon(Icons.play_arrow),
                onTap: () => _elegirDelCatalogo(j),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Jefe personalizado',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          key: const Key('jefe-nombre'),
          controller: _nombre,
          decoration: const InputDecoration(
            labelText: 'Nombre del jefe',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: const Key('jefe-hp'),
          child: CampoNumero(controlador: _hp, etiqueta: 'HP del jefe'),
        ),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: const Key('jefe-invocacion'),
          child: CampoNumero(
            controlador: _invocacion,
            etiqueta: 'Llama a aliados (cualquier número; vacío o 0: nunca)',
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('elegir-jefe'),
          onPressed: () => _elegir(estado),
          child: const Text('Empezar la partida'),
        ),
      ],
    );
  }
}
