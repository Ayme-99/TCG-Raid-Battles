import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../catalogo/catalogo.dart';
import '../partida/controlador_partida.dart';
import '../partida/recordatorios.dart';
import 'carta_ataque_jefe.dart';
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
  /// Ronda a la que pertenece lo que sigue; al cambiar de ronda se olvida.
  int? _ronda;

  /// Carta robada que aún no se ha registrado.
  CartaAtaqueJefe? _carta;

  /// La última carta registrada decía «Roba una carta más».
  bool _robaOtra = false;

  /// La mesa ya ha hecho el Chequeo Pokémon de este turno (los recordatorios
  /// de los aliados en juego).
  bool _chequeoHecho = false;

  void _robar(EstadoPartida estado) {
    final mazo = ref.read(mazoAtaquesJefeProvider);
    setState(() {
      _carta = mazo.robar(jugadoresObjetivo(estado).toSet());
    });
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(estadoProvider);
    final jefe = estado.jefe!;
    if (_ronda != estado.ronda) {
      _ronda = estado.ronda;
      _carta = null;
      _robaOtra = false;
      _chequeoHecho = false;
    }
    final registrados = estado.ataquesJefeEnTurno;
    final maximo = maxAtaquesJefePorTurno(jefe.nivel);
    final carta = _carta;
    // Con todos los jugadores KO los ataques del jefe fallan: no hay carta
    // que robar y se sigue con el resto del turno.
    final sinObjetivos = jugadoresObjetivo(estado).isEmpty;
    // Lo primero del turno es robar la carta que decide el ataque y el
    // objetivo: hasta entonces solo se muestra ese paso, pequeño.
    if (carta == null && registrados == 0 && !sinObjetivos) {
      return DisposicionMesa(
        controles: [
          const PanelPendientes(),
          FilledButton.icon(
            key: const Key('robar-carta-jefe'),
            onPressed: () => _robar(estado),
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
    final debeRobarOtra =
        carta == null && _robaOtra && registrados < maximo && !sinObjetivos;
    // Cierre del turno, paso a paso (T-70): primero atacan los aliados, luego
    // la mesa hace el Chequeo Pokémon y solo entonces se termina el turno.
    // Así los KO que salgan de esos pasos se marcan dentro del turno del jefe.
    final chequeo = recordatoriosDeChequeo(
      ref.watch(catalogoProvider).valueOrNull,
      estado,
    );
    final faltaChequeo = chequeo.isNotEmpty && !_chequeoHecho;
    final controles = <Widget>[
      const PanelPendientes(),
      if (sinObjetivos && registrados == 0 && carta == null)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          key: Key('jefe-sin-objetivos'),
          child: Text(
            'Todos los jugadores en juego están KO: los ataques del jefe '
            'fallan.',
          ),
        ),
      if (carta != null)
        _AtaqueJefe(
          key: ValueKey('ataque-${estado.ronda}-$registrados-${carta.numero}'),
          estado: estado,
          carta: carta,
          onRegistrado: () => setState(() {
            _robaOtra = carta.robaOtra;
            _carta = null;
          }),
        )
      else ...[
        if (debeRobarOtra)
          FilledButton.icon(
            key: const Key('robar-carta-jefe'),
            onPressed: () => _robar(estado),
            icon: const Icon(Icons.style),
            label: const Text('Robar otra carta'),
          ),
        const SizedBox(height: 8),
        if (aliadosPorAtacar.isNotEmpty)
          for (final a in aliadosPorAtacar)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.tonal(
                key: Key('aliado-ataca-${a.slot}'),
                onPressed: () => atacarConAliado(context, ref, estado, a),
                child: Text('${a.nombre} ataca: ${textoAtaque(a)}'),
              ),
            )
        else if (faltaChequeo)
          FilledButton.tonal(
            key: const Key('chequeo-pokemon'),
            onPressed: () async {
              await avisarMesa(
                context,
                titulo: 'Chequeo Pokémon',
                lineas: [
                  ...chequeo,
                  'Si algún Pokémon queda Fuera de Combate, márcalo antes de '
                      'terminar el turno del jefe.',
                ],
              );
              if (mounted) setState(() => _chequeoHecho = true);
            },
            child: const Text('Chequeo Pokémon'),
          )
        else
          _BotonFinTurno(jefe: jefe, destacado: !debeRobarOtra),
      ],
    ];
    // El panel del ataque solo lleva el ataque; lo demás va en «Más acciones».
    final extras = <Widget>[
      const PanelEfectosActivos(),
        const PanelEstados(),
        const PanelPokemon(),
        const PanelDanoDeEfecto(),
    ];
    // La mesa con cámara a pantalla completa y los controles del turno al
    // lado (o debajo en pantallas estrechas).
    return DisposicionMesa(controles: controles, extras: extras, lateral: true);
  }
}

/// Termina el turno del jefe (con la moneda de la quemadura si hace falta).
class _BotonFinTurno extends ConsumerWidget {
  const _BotonFinTurno({required this.jefe, required this.destacado});

  final JefeEstado jefe;
  final bool destacado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> terminar() async {
      final estado = ref.read(estadoProvider);
      // Moneda de cada aliado quemado, por orden de slot (D-17).
      final monedasAliados = <MonedaQuemaduraAliado>[];
      for (final a in estado.aliados.where((a) => a.quemado)) {
        final caraAliado = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Moneda de la quemadura: ${a.nombre}'),
            content: Text(
              'Tira una moneda. Cara: ${a.nombre} deja de estar quemado.',
            ),
            actions: [
              TextButton(
                key: Key('moneda-aliado-cruz-${a.slot}'),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cruz'),
              ),
              FilledButton(
                key: Key('moneda-aliado-cara-${a.slot}'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Cara'),
              ),
            ],
          ),
        );
        if (caraAliado == null || !context.mounted) return;
        monedasAliados.add(MonedaQuemaduraAliado(slot: a.slot, cara: caraAliado));
      }
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
      registrar(
        context,
        ref,
        FinTurnoJefe(
          monedaQuemadura: cara,
          monedasQuemaduraAliados:
              monedasAliados.isEmpty ? null : monedasAliados,
        ),
      );
    }

    const texto = Text('Terminar el turno del jefe');
    return destacado
        ? FilledButton(
            key: const Key('fin-turno-jefe'),
            onPressed: terminar,
            child: texto,
          )
        : OutlinedButton(
            key: const Key('fin-turno-jefe'),
            onPressed: terminar,
            child: texto,
          );
  }
}

class _AtaqueJefe extends ConsumerStatefulWidget {
  const _AtaqueJefe({
    super.key,
    required this.estado,
    required this.carta,
    required this.onRegistrado,
  });

  final EstadoPartida estado;

  /// Carta robada: dice el ataque y el objetivo.
  final CartaAtaqueJefe carta;

  /// Se llama cuando el ataque queda registrado.
  final VoidCallback onRegistrado;

  @override
  ConsumerState<_AtaqueJefe> createState() => _AtaqueJefeState();
}

class _AtaqueJefeState extends ConsumerState<_AtaqueJefe> {
  final _dano = TextEditingController();
  /// Ataque y objetivo salen de la carta robada.
  late int _ranura = widget.carta.ranura;
  late int? _objetivo = widget.carta.jugador;
  bool _alAzar = true;

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
    final activos = jugadoresObjetivo(estado);
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
            CartaAtaqueRobada(
              key: const Key('carta-ataque-jefe'),
              carta: widget.carta,
              jugador: estado.jugadores[widget.carta.jugador].nombre,
            ),
            const SizedBox(height: 8),
            Text(
              'Ataque del jefe',
              key: const Key('turno-del-jefe'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (ataque == null) ...[
              // Jefe sin carta de catálogo: el ataque y el objetivo salen de la
              // carta robada, pero se pueden corregir y falta el daño.
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
            ] else ...[
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
            if (ataque == null) ...[
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
            ],
            if (faltaDefensor)
              const Text(
                'Este ataque afecta al Pokémon Defensor: elige el jugador.',
                key: Key('falta-defensor'),
              ),
            FilledButton(
              key: const Key('registrar-ataque-jefe'),
              onPressed: faltaDefensor
                  ? null
                  : () async {
                      // Daño extra condicionado a la mesa (Castigo): la app
                      // pregunta si se cumple y lo suma.
                      var extra = 0;
                      if (efecto != null &&
                          efecto.tipo == TipoEfectoAtaque.danoExtraSi &&
                          efecto.valor != null) {
                        final cumple = await preguntarMesa(
                          context,
                          '${ataque!.nombre}: ${efecto.texto}\n¿Se cumple?',
                        );
                        if (cumple == null || !context.mounted) return;
                        if (cumple) extra = efecto.valor!;
                      }
                      // La moneda del ataque la lanza la app y queda en el
                      // registro (D-14).
                      final moneda =
                          efecto != null && efecto.conMoneda ? Random().nextBool() : null;
                      // Bonus de los aliados Potenciador vivos (D-16): la app
                      // tira sus monedas y suma el bonus al daño registrado.
                      final base = (int.tryParse(_dano.text) ?? 0) + extra;
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
                      if (aplicado) widget.onRegistrado();
                      if (aplicado && context.mounted) {
                        final avisos = [
                          if (moneda != null)
                            moneda
                                ? 'Moneda: cara. ${efecto!.texto}'
                                : 'Moneda: cruz. No pasa nada.',
                          if (extra > 0) 'Se cumple: +$extra de daño.',
                          if (partesBonus.isNotEmpty)
                            'Potenciador (${partesBonus.join(' · ')}). '
                                'Daño total: $total.',
                          if (extra > 0 && partesBonus.isEmpty)
                            'Daño total: $total.',
                        ];
                        if (avisos.isNotEmpty) {
                          registrarAviso(context, avisos.join('\n'));
                        }
                        final defensor = _objetivo;
                        if (efecto != null &&
                            efecto.tipo == TipoEfectoAtaque.autodanoSiKo &&
                            defensor != null) {
                          preguntarRebote(
                            context,
                            ref,
                            jugador: defensor,
                            puntos: efecto.valor ?? 0,
                          );
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
