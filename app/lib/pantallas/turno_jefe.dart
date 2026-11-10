import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../catalogo/catalogo.dart';
import '../partida/controlador_partida.dart';
import 'comun.dart';
import 'paneles.dart';
import 'pendientes.dart';
import 'mesa.dart';

/// Turno del jefe: sus ataques, los ataques de los aliados, KO y estados.
class PantallaTurnoJefe extends ConsumerStatefulWidget {
  const PantallaTurnoJefe({super.key});

  @override
  ConsumerState<PantallaTurnoJefe> createState() => _PantallaTurnoJefeState();
}

class _PantallaTurnoJefeState extends ConsumerState<PantallaTurnoJefe> {
  /// Ronda en la que ya se ha robado la carta del jefe.
  int? _robadaRonda;

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(estadoProvider);
    final jefe = estado.jefe!;
    // Lo primero del turno es robar la carta que decide el ataque y el
    // objetivo: hasta entonces solo se muestra ese paso, pequeño.
    final robada = _robadaRonda == estado.ronda || estado.ataquesJefeEnTurno > 0;
    if (!robada) {
      return DisposicionMesa(
        controles: [
          const PanelPendientes(),
          FilledButton.icon(
            key: const Key('robar-carta-jefe'),
            onPressed: () => setState(() => _robadaRonda = estado.ronda),
            icon: const Icon(Icons.style),
            label: const Text('Robar carta del jefe'),
          ),
        ],
      );
    }
    final aliadosPorAtacar = [
      for (final a in estado.aliados)
        if (a.tieneAtaque && !a.atacoEnTurnoJefe) a,
    ];
    final controles = <Widget>[
        const PanelEfectosActivos(),
        const PanelPendientes(),
        _AtaqueJefe(
          key: ValueKey('ataque-${estado.ronda}-${estado.ataquesJefeEnTurno}'),
          estado: estado,
        ),
        if (aliadosPorAtacar.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ataques de los aliados',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final a in aliadosPorAtacar)
                        FilledButton.tonal(
                          key: Key('aliado-ataca-${a.slot}'),
                          onPressed: () =>
                              atacarConAliado(context, ref, estado, a),
                          child: Text('${a.nombre} ataca (${a.ataqueDano})'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const PanelEstados(),
        const PanelPokemon(),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('fin-turno-jefe'),
          onPressed: () async {
            bool? cara;
            if (jefe.quemado) {
              cara = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Moneda de la quemadura'),
                  content: const Text(
                    'Tira una moneda. Cara: el jefe deja de estar quemado.',
                  ),
                  actions: [
                    TextButton(
                      key: const Key('moneda-cruz'),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cruz'),
                    ),
                    FilledButton(
                      key: const Key('moneda-cara'),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Cara'),
                    ),
                  ],
                ),
              );
              if (cara == null || !context.mounted) return;
            }
            registrar(context, ref, FinTurnoJefe(monedaQuemadura: cara));
          },
          child: const Text('Terminar el turno del jefe'),
        ),
    ];
    // La mesa con cámara a pantalla completa y los controles del turno al
    // lado (o debajo en pantallas estrechas).
    return DisposicionMesa(controles: controles, lateral: true);
  }
}

class _AtaqueJefe extends ConsumerStatefulWidget {
  const _AtaqueJefe({super.key, required this.estado});

  final EstadoPartida estado;

  @override
  ConsumerState<_AtaqueJefe> createState() => _AtaqueJefeState();
}

class _AtaqueJefeState extends ConsumerState<_AtaqueJefe> {
  final _dano = TextEditingController();
  late int _ranura = widget.estado.ataquesJefeEnTurno + 1 > ranurasAtaqueJefe
      ? ranurasAtaqueJefe
      : widget.estado.ataquesJefeEnTurno + 1;

  /// null: ataca a todos los jugadores.
  int? _objetivo;
  bool _alAzar = false;

  /// Ranura para la que ya se propuso el daño del catálogo.
  int? _ranuraPropuesta;

  /// Ataque de la carta de catálogo del jefe en la ranura elegida, si el jefe
  /// viene del catálogo.
  AtaqueJefeCatalogo? _ataqueCatalogo(EstadoPartida estado) {
    final catalogo = ref.watch(catalogoProvider).maybeWhen(
          data: (c) => c,
          orElse: () => null,
        );
    final jefe = estado.jefe;
    if (catalogo == null || jefe == null) return null;
    for (final j in catalogo.jefes) {
      if (j.nombre == jefe.nombre && j.nivel == jefe.nivel) {
        return j.ataques[_ranura - 1];
      }
    }
    return null;
  }

  @override
  void dispose() {
    _dano.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.estado;
    final activos = jugadoresActivos(estado);
    final ataque = _ataqueCatalogo(estado);
    final efecto = ataque?.efecto;
    if (ataque != null && _ranuraPropuesta != _ranura) {
      // Propone el daño de la carta; la mesa puede cambiarlo.
      _dano.text = ataque.danoPropuesto(estado.ataquesJefeEnTurno).toString();
      _ranuraPropuesta = _ranura;
    }
    final faltaDefensor =
        efecto != null && efecto.necesitaDefensor && _objetivo == null;
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ataque del jefe',
              key: const Key('turno-del-jefe'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('Ataques registrados: ${estado.ataquesJefeEnTurno}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (var r = 1; r <= ranurasAtaqueJefe; r++)
                  ChoiceChip(
                    key: Key('ranura-$r'),
                    label: Text('Ataque $r'),
                    selected: _ranura == r,
                    onSelected: (_) => setState(() => _ranura = r),
                  ),
              ],
            ),
            if (ataque != null) ...[
              const SizedBox(height: 8),
              Text(
                '${ataque.nombre} · ${ataque.dano}',
                key: const Key('ataque-catalogo'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (efecto != null)
                Text(efecto.texto, key: const Key('efecto-ataque')),
            ],
            for (final b in bonusAtaqueJefeActivos(estado))
              Text(
                b.conMoneda
                    ? '${b.aliado} potencia el ataque: se tira una moneda y, si '
                        'sale cara, +${b.valor} de daño.'
                    : '${b.aliado} potencia el ataque: +${b.valor} de daño.',
                key: const Key('bonus-potenciador'),
              ),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: const Key('dano-jefe'),
              child: CampoNumero(
                controlador: _dano,
                etiqueta: 'Daño por Pokémon (vacío: 0)',
              ),
            ),
            const SizedBox(height: 8),
            const Text('Objetivo'),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('objetivo-todos'),
                  label: const Text('Todos'),
                  selected: _objetivo == null,
                  onSelected: (_) => setState(() => _objetivo = null),
                ),
                for (final a in activos)
                  ChoiceChip(
                    key: Key('objetivo-$a'),
                    label: Text(estado.jugadores[a].nombre),
                    selected: _objetivo == a,
                    onSelected: (_) => setState(() => _objetivo = a),
                  ),
              ],
            ),
            CheckboxListTile(
              key: const Key('al-azar'),
              contentPadding: EdgeInsets.zero,
              title: const Text('El objetivo salió de una tirada'),
              value: _alAzar,
              onChanged: (v) => setState(() => _alAzar = v ?? false),
            ),
            if (faltaDefensor)
              const Text(
                'Este ataque afecta al Pokémon Defensor: elige el jugador.',
                key: Key('falta-defensor'),
              ),
            FilledButton(
              key: const Key('registrar-ataque-jefe'),
              onPressed: faltaDefensor
                  ? null
                  : () {
                      // La moneda del ataque la lanza la app y queda en el
                      // registro (D-14).
                      final moneda =
                          efecto != null && efecto.conMoneda ? Random().nextBool() : null;
                      // Bonus de los aliados Potenciador vivos (D-16): la app
                      // tira sus monedas y suma el bonus al daño registrado.
                      final base = int.tryParse(_dano.text) ?? 0;
                      var total = base;
                      final partesBonus = <String>[];
                      for (final b in bonusAtaqueJefeActivos(estado)) {
                        final cara =
                            !b.conMoneda || ref.read(azarProvider).nextBool();
                        if (cara) total += b.valor;
                        partesBonus.add(
                          '${b.aliado}: ${cara ? 'cara, +${b.valor}' : 'cruz, sin bonus'}',
                        );
                      }
                      final aplicado = registrar(
                        context,
                        ref,
                        AtaqueJefe(
                          ranura: _ranura,
                          dano: total,
                          jugador: _objetivo,
                          alAzar: _alAzar,
                          efecto: efecto?.comoEfecto(moneda: moneda),
                        ),
                      );
                      if (aplicado && context.mounted) {
                        final avisos = [
                          if (moneda != null)
                            moneda
                                ? 'Moneda: cara. ${efecto!.texto}'
                                : 'Moneda: cruz. No pasa nada.',
                          if (partesBonus.isNotEmpty)
                            'Potenciador (${partesBonus.join(' · ')}). '
                                'Daño total: $total.',
                        ];
                        if (avisos.isNotEmpty) {
                          registrarAviso(context, avisos.join('\n'));
                        }
                      }
                    },
              child: const Text('Registrar ataque'),
            ),
          ],
        ),
      ),
    );
  }
}
