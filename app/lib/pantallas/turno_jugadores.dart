import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../catalogo/catalogo.dart';
import '../partida/ataque_mesa.dart';
import '../partida/controlador_partida.dart';
import '../sala/controlador_sala.dart';
import '../partida/recordatorios.dart';
import 'comun.dart';
import 'lanzar_monedas.dart';
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
    // En una sala solo el jugador al que le toca ve los controles del turno.
    final miAsiento = ref.watch(miAsientoProvider);
    final esMiTurno = miAsiento == null || miAsiento == actual;
    final controles = <Widget>[
        const PanelPendientes(),
        if (actual != null && !esMiTurno)
          Card(
            key: const Key('turno-ajeno'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Turno de ${estado.jugadores[actual].nombre}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        if (actual != null && esMiTurno && estado.cartasAnimoPendientes.isEmpty)
          _TurnoActual(
            key: ValueKey('turno-${estado.ronda}-${estado.turnoActual}'),
            estado: estado,
            jugador: actual,
          ),
        if (estado.cartasAnimoPendientes.isNotEmpty)
          _SentadosPorKo(estado: estado),
    ];
    // El bocadillo solo lleva lo del turno; el resto va en «Más acciones».
    final extras = <Widget>[
      const PanelEfectosActivos(),
      _Orden(estado: estado),
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
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        '${i + 1}. ${estado.jugadores[estado.orden[i]].nombre}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
  late final TextEditingController _dano;
  late bool _fijado;
  bool _doble = false;
  Timer? _repeticion;

  @override
  void initState() {
    super.initState();
    final fijo = ref.read(danoFijadoProvider)[widget.jugador];
    _fijado = fijo != null && !widget.estado.enKo(widget.jugador);
    _dano = TextEditingController(text: _fijado ? '$fijo' : '0');
  }

  @override
  void dispose() {
    _repeticion?.cancel();
    _dano.dispose();
    super.dispose();
  }

  int get _valor => int.tryParse(_dano.text) ?? 0;

  /// Daño que se registra: el del panel con las cartas de ánimo de la ronda
  /// (doble daño y +50), si salieron.
  int get _danoFinal {
    var d = _valor;
    if (d <= 0) return 0;
    if (_doble) d *= 2;
    if (widget.estado.cartaAnimoEnRonda(5)) d += bonoCartaAnimoAtaque;
    return d;
  }

  /// Daño de más que ponen las cartas de ánimo sobre el escrito, para la
  /// explosión del ataque.
  int get _extraAnimo => _valor > 0 ? _danoFinal - _valor : 0;

  void _gastarDoble() {
    if (!_doble) return;
    ref.read(dobleUsadoProvider.notifier).state = widget.estado.ronda;
  }

  void _sumar(int paso) {
    final v = (_valor + paso).clamp(0, 9999);
    setState(() => _dano.text = '$v');
  }

  void _empezarRepeticion(int paso) {
    _repeticion?.cancel();
    _repeticion =
        Timer.periodic(const Duration(milliseconds: 90), (_) => _sumar(paso));
  }

  void _pararRepeticion() {
    _repeticion?.cancel();
    _repeticion = null;
  }

  void _guardarFijado() {
    final mapa = {...ref.read(danoFijadoProvider)};
    if (_fijado) {
      mapa[widget.jugador] = _valor;
    } else {
      mapa.remove(widget.jugador);
    }
    ref.read(danoFijadoProvider.notifier).state = mapa;
  }

  Future<void> _atacarAliado() async {
    final estado = widget.estado;
    // Bloqueo (Bronzong): solo se puede atacar a ese aliado.
    final provocador = aliadoProvocador(estado);
    // Con un solo aliado en juego no hay nada que elegir. El daño es el del
    // panel: el mismo número sirve para el jefe y para el aliado.
    final slot = provocador != null
        ? provocador.slot
        : estado.aliados.length == 1
            ? estado.aliados.first.slot
            : await elegirJugador(
                context,
                estado,
                titulo: '¿Qué aliado ataca? (slot de...)',
                asientos: [for (final a in estado.aliados) a.slot],
              );
    if (slot == null || !mounted) return;
    final dano = _danoFinal;
    final extra = _extraAnimo;
    _gastarDoble();
    _guardarFijado();
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
      final nombreAliado = aliado.nombre;
      final nombreJugador = estado.jugadores[widget.jugador].nombre;
      final cara = await lanzarMonedaDeJugador(
        context,
        ref,
        asiento: widget.jugador,
        leyenda: '$nombreJugador lanza: $nombreAliado · Bote',
      );
      if (cara == null) return;
      evita = cara;
      if (!mounted) return;
    }
    ref.read(extraDanoProvider.notifier).state = evita ? 0 : extra;
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

  bool _hayDoble(EstadoPartida estado) =>
      estado.cartaAnimoEnRonda(1) &&
      (_doble || ref.watch(dobleUsadoProvider) != estado.ronda);

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
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            if (recordatorios.isNotEmpty)
              Padding(
                key: const Key('recordatorios-turno'),
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final r in recordatorios)
                      Text('• $r', style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
            if (conAliado)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Tiene un aliado en su slot: puede atacarlo o ignorarlo y '
                  'dañar al jefe (el aliado atacará igualmente).',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: KeyedSubtree(
                    key: const Key('dano-turno'),
                    child: TextField(
                      controller: _dano,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _SinCerosIzquierda(),
                      ],
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                      decoration: const InputDecoration(
                        labelText: 'Daño al jefe',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  key: const Key('fijar-dano'),
                  selected: _fijado,
                  avatar: Icon(_fijado ? Icons.lock : Icons.lock_open),
                  label: Text(_fijado ? 'Fijado' : 'Fijar'),
                  onSelected: (v) => setState(() => _fijado = v),
                ),
              ],
            ),
            if (_hayDoble(estado)) ...[
              const SizedBox(height: 8),
              FilterChip(
                key: const Key('doble-dano'),
                selected: _doble,
                avatar: const Icon(Icons.bolt),
                label: const Text('Carta de ánimo: ataque con doble daño (×2)'),
                onSelected: (v) => setState(() => _doble = v),
              ),
            ],
            if (_danoFinal != _valor)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Con las cartas de ánimo se registrarán $_danoFinal de daño.',
                  key: const Key('dano-con-animo'),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final paso in const [-10, 10, 50]) ...[
                  Expanded(
                    child: GestureDetector(
                      onLongPressStart: (_) => _empezarRepeticion(paso),
                      onLongPressEnd: (_) => _pararRepeticion(),
                      onLongPressCancel: _pararRepeticion,
                      child: OutlinedButton(
                        key: Key('dano-${paso < 0 ? 'menos' : 'mas'}-${paso.abs()}'),
                        onPressed: () => _sumar(paso),
                        child: Text(paso < 0 ? '−${-paso}' : '+$paso'),
                      ),
                    ),
                  ),
                  if (paso != 50) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: const Key('registrar-turno'),
                  onPressed: () {
                    _guardarFijado();
                    final dano = _danoFinal;
                    ref.read(extraDanoProvider.notifier).state = _extraAnimo;
                    _gastarDoble();
                    registrar(
                      context,
                      ref,
                      TurnoJugador(jugador: widget.jugador, dano: dano),
                    );
                  },
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

/// Quita los ceros de la izquierda al escribir («0100» pasa a «100»); un
/// solo «0» se queda.
class _SinCerosIzquierda extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue nuevo,
  ) {
    final t = nuevo.text;
    final limpio = t.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (limpio == t) return nuevo;
    return TextEditingValue(
      text: limpio,
      selection: TextSelection.collapsed(offset: limpio.length),
    );
  }
}

/// Quien tuvo un Pokémon KO se sienta este turno: solo roba una carta de
/// ánimo y los ataques del jefe y de sus aliados contra él fallan. La carta
/// la roba la app, al azar entre las 5, antes de que actúen los demás.
class _SentadosPorKo extends ConsumerWidget {
  const _SentadosPorKo({required this.estado});

  final EstadoPartida estado;

  Future<void> _robar(BuildContext context, WidgetRef ref, int jugador) async {
    final carta = ref.read(azarProvider).nextInt(cartasAnimoTotal) + 1;
    final nombre = estado.jugadores[jugador].nombre;
    final texto = textosCartaAnimo[carta - 1];
    if (!registrar(context, ref, CartaAnimoRobada(jugador: jugador, carta: carta))) {
      return;
    }
    if (!context.mounted) return;
    // Las curas son de los Pokémon de la mesa: se quedan en pantalla hasta
    // que alguien las hace.
    if (carta == 2 || carta == 3) {
      await avisarMesa(
        context,
        titulo: 'CARTA DE ÁNIMO · $nombre',
        lineas: [texto],
      );
    } else {
      registrarAviso(
        context,
        '$nombre: $texto',
        tipo: TipoAviso.info,
        titulo: 'CARTA DE ÁNIMO',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primero = estado.cartasAnimoPendientes.first;
    final nombre = estado.jugadores[primero].nombre;
    final otros = estado.cartasAnimoPendientes.length - 1;
    return Card(
      key: const Key('sentados-ko'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$nombre no actúa este turno por tener un Pokémon KO: solo roba '
              'una carta de ánimo. Los ataques del jefe y de sus aliados '
              'contra él fallan.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('robar-carta-animo'),
              onPressed: () => _robar(context, ref, primero),
              icon: const Icon(Icons.favorite),
              label: Text(
                otros > 0
                    ? 'Robar carta de ánimo ($nombre, +$otros)'
                    : 'Robar carta de ánimo ($nombre)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
