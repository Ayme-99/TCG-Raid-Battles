import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../catalogo/catalogo.dart';
import '../partida/controlador_partida.dart';
import '../partida/recordatorios.dart';
import 'comun.dart';
import 'paneles.dart';
import 'pendientes.dart';
import 'mesa.dart';

/// Turno de los jugadores: orden de la ronda, daño al jefe, ataques a
/// aliados, cartas de ánimo, estados y KO.
class PantallaTurnoJugadores extends ConsumerWidget {
  const PantallaTurnoJugadores({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoProvider);
    final actual = estado.jugadorActual;
    final controles = <Widget>[
        const PanelPendientes(),
        if (actual != null)
          _TurnoActual(
            key: ValueKey('turno-${estado.ronda}-${estado.turnoActual}'),
            estado: estado,
            jugador: actual,
          ),
        if (estado.cartasAnimoPendientes.isNotEmpty)
          _CartasAnimo(estado: estado),
    ];
    // El bocadillo solo lleva lo del turno; el resto va en «Más acciones».
    final extras = <Widget>[
      const PanelEfectosActivos(),
      _Orden(estado: estado),
      PanelEstados(
        key: ValueKey('estados-${estado.ronda}-${estado.turnoActual}'),
        jugadorInicial: actual,
      ),
      const PanelPokemon(),
    ];
    // La mesa con cámara a pantalla completa y los controles del turno al
    // lado (o debajo en pantallas estrechas).
    return DisposicionMesa(controles: controles, extras: extras);
  }
}

class _Orden extends StatelessWidget {
  const _Orden({required this.estado});

  final EstadoPartida estado;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Orden de la ronda ${estado.ronda}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < estado.orden.length; i++)
                  Chip(
                    label: Text(
                      '${i + 1}. ${estado.jugadores[estado.orden[i]].nombre}',
                    ),
                    backgroundColor: i == estado.turnoActual
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TurnoActual extends ConsumerStatefulWidget {
  const _TurnoActual({super.key, required this.estado, required this.jugador});

  final EstadoPartida estado;
  final int jugador;

  @override
  ConsumerState<_TurnoActual> createState() => _TurnoActualState();
}

class _TurnoActualState extends ConsumerState<_TurnoActual> {
  final _dano = TextEditingController();

  @override
  void dispose() {
    _dano.dispose();
    super.dispose();
  }

  Future<void> _atacarAliado() async {
    final estado = widget.estado;
    // Bloqueo (Bronzong): solo se puede atacar a ese aliado.
    final provocador = aliadoProvocador(estado);
    final slot = provocador != null
        ? provocador.slot
        : await elegirJugador(
            context,
            estado,
            titulo: '¿Qué aliado ataca? (slot de...)',
            asientos: [for (final a in estado.aliados) a.slot],
          );
    if (slot == null || !mounted) return;
    final dano = await pedirNumero(
      context,
      titulo: 'Daño al aliado',
      etiqueta: 'Daño',
    );
    if (dano == null || !mounted) return;
    final aliado = estado.aliadoEn(slot);
    final jefeCarta = estado.jefe;
    final cartaAliado = jefeCarta == null || aliado == null
        ? null
        : ref
            .read(catalogoProvider)
            .valueOrNull
            ?.aliadoDe(jefeCarta.nombre, jefeCarta.nivel, aliado.categoria);
    // Bote (Magikarp): el jugador atacante lanza 1 moneda y, con cara, se evita
    // todo el daño. La moneda cae en la pantalla; si Fijar Blanco está en
    // juego, la primera moneda de cada jugador es cruz y la lleva la mesa. El
    // ataque gasta el turno igualmente.
    final conBote = cartaAliado != null &&
        cartaAliado.nombre == aliado!.nombre &&
        cartaAliado.evitaDanoConMoneda;
    var evita = false;
    if (conBote) {
      final nombreAliado = aliado!.nombre;
      final nombreJugador = estado.jugadores[widget.jugador].nombre;
      final fijadas =
          recordatoriosDeMoneda(ref.read(catalogoProvider).valueOrNull, estado);
      if (fijadas.isEmpty) {
        evita = await lanzarMonedaEnPantalla(
          context,
          ref,
          titulo: '$nombreAliado: Bote',
          detalle: '$nombreJugador lanza 1 moneda. Con cara, se evita todo el '
              'daño a $nombreAliado.',
        );
      } else {
        final cara = await preguntarMesa(
          context,
          [
            '$nombreAliado: Bote. $nombreJugador lanza 1 moneda. ¿Sale cara?',
            ...fijadas,
          ].join('\n'),
          si: 'Cara',
          no: 'Cruz',
        );
        if (cara == null) return;
        evita = cara;
      }
      if (!mounted) return;
    }
    final aplicado = registrar(
      context,
      ref,
      AtaqueAAliado(
        jugador: widget.jugador,
        slot: slot,
        dano: evita ? 0 : dano,
      ),
    );
    if (!aplicado || aliado == null || !context.mounted) return;
    final catalogo = ref.read(catalogoProvider).valueOrNull;
    final avisos = <String>[
      if (conBote && evita)
        '${aliado.nombre}: moneda en cara, se evita todo el daño.'
      else if (conBote)
        '${aliado.nombre}: moneda en cruz, recibe el daño.',
      // Derrotado: recordatorios de la carta caída y auras de los aliados
      // que estaban en juego, él incluido (Moflete Estático).
      if (ref.read(estadoProvider).aliadoEn(slot) == null) ...[
        if (cartaDeAliado(catalogo, estado, aliado)?.avisoAlCaer case final a?)
          a,
        for (final enJuego in estado.aliados)
          if (cartaDeAliado(catalogo, estado, enJuego)?.avisoAliadoCaido
              case final a?)
            a,
      ],
    ];
    registrarAvisos(context, avisos);
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.estado;
    final nombre = estado.jugadores[widget.jugador].nombre;
    final conAliado = estado.aliadoEn(widget.jugador) != null;
    final provocador = aliadoProvocador(estado);
    final recordatorios = recordatoriosDeTurno(
      ref.watch(catalogoProvider).valueOrNull,
      estado,
      widget.jugador,
    );
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Turno de $nombre',
              key: const Key('turno-de'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (provocador != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${provocador.nombre} obliga a atacarle: ataca a ese '
                  'aliado o pasa el turno sin dañar al jefe.',
                  key: const Key('aviso-bloqueo'),
                ),
              ),
            if (recordatorios.isNotEmpty)
              Padding(
                key: const Key('recordatorios-turno'),
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final r in recordatorios) Text('• $r')],
                ),
              ),
            if (conAliado)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Tiene un aliado en su slot: puede atacarlo o ignorarlo y '
                  'dañar al jefe (el aliado atacará igualmente).',
                ),
              ),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: const Key('dano-turno'),
              child: CampoNumero(
                controlador: _dano,
                etiqueta: 'Daño al jefe (vacío: 0)',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: const Key('registrar-turno'),
                  onPressed: () => registrar(
                    context,
                    ref,
                    TurnoJugador(
                      jugador: widget.jugador,
                      dano: int.tryParse(_dano.text) ?? 0,
                    ),
                  ),
                  child: const Text('Registrar turno'),
                ),
                if (estado.aliados.isNotEmpty)
                  OutlinedButton(
                    key: const Key('atacar-aliado'),
                    onPressed: _atacarAliado,
                    child: const Text('Ataca a un aliado'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartasAnimo extends ConsumerWidget {
  const _CartasAnimo({required this.estado});

  final EstadoPartida estado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cartas de ánimo por robar',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'Quien tuvo un Pokémon KO roba una carta; el efecto se '
              'resuelve en la mesa. Indica el número que ha salido.',
            ),
            for (final a in estado.cartasAnimoPendientes)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(estado.jugadores[a].nombre)),
                    for (var c = 1; c <= cartasAnimoTotal; c++)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: OutlinedButton(
                          key: Key('animo-$a-$c'),
                          onPressed: () => registrar(
                            context,
                            ref,
                            CartaAnimoRobada(jugador: a, carta: c),
                          ),
                          child: Text('$c'),
                        ),
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
