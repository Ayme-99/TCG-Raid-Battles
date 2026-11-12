import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../catalogo/catalogo.dart';
import '../partida/controlador_partida.dart';
import '../partida/recordatorios.dart';
import '../partida/tirada_mesa.dart';
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
              const Text('El jefe llama a un aliado'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    key: const Key('invocar-aliado'),
                    onPressed: () async {
                      Object? resultado = await _abrirDialogoAliado(
                        context,
                        ref,
                        estado,
                      );
                      // «Tirar dados»: los dados caen sobre la mesa y, al
                      // pararse, el diálogo vuelve con el resultado puesto.
                      while (resultado is _ResultadoTirada) {
                        await _tirarEnMesa(ref, resultado.mesa);
                        if (!context.mounted) return;
                        resultado = resultado.sin
                            ? const SinInvocacion()
                            : await _abrirDialogoAliado(
                                context,
                                ref,
                                estado,
                                inicial: resultado,
                              );
                      }
                      final evento = resultado is Evento ? resultado : null;
                      if (evento == null || !context.mounted) return;
                      final aplicado = registrar(context, ref, evento);
                      if (!aplicado || !context.mounted) return;
                      if (evento is SinInvocacion) {
                        registrarAviso(context,
                            'No hay hueco libre: no se llama a ningún aliado.');
                      }
                      if (evento is AliadoInvocado) {
                        await avisarEntrada(context, ref, evento);
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
                child: Text('${a.nombre} ataca al entrar: ${textoAtaque(a)}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Nombre y daño del ataque de un aliado, para los botones: «Tóxico» si no
/// hace daño, «Chupavidas (30)» si lo hace.
String textoAtaque(AliadoEstado a) {
  final nombre = a.ataqueNombre ?? 'Ataque';
  final dano = a.ataqueDano ?? 0;
  return dano > 0 ? '$nombre ($dano)' : nombre;
}

/// Lo que la mesa tiene que hacer cuando entra un aliado: el resultado de sus
/// monedas (Deseo) y los recordatorios de su carta. Se queda en pantalla
/// hasta que alguien pulsa «Hecho».
Future<void> avisarEntrada(
  BuildContext context,
  WidgetRef ref,
  AliadoInvocado evento,
) async {
  final estado = ref.read(estadoProvider);
  final catalogo = ref.read(catalogoProvider).valueOrNull;
  final lineas = <String>[];
  final m = evento.monedas;
  if (m != null && m.length >= 10) {
    final jefe = m.take(10).where((c) => c).length;
    final aliados = m.skip(10).where((c) => c).length;
    lineas.add(
      'Deseo: $jefe de 10 monedas en cara → el jefe se cura ${100 * jefe}. '
      '$aliados de ${m.length - 10} aliados se curan 100.',
    );
    lineas.add(
      'Cada jugador lanza 1 moneda por cada uno de sus Pokémon: con cara, '
      'cura 100 puntos de daño a ese Pokémon.',
    );
    lineas.addAll(recordatoriosDeMoneda(catalogo, estado));
  }
  final aliado = estado.aliadoEn(evento.slot);
  if (aliado != null) {
    lineas.addAll(recordatoriosAlEntrar(catalogo, estado, aliado));
  }
  if (lineas.isEmpty) return;
  await avisarMesa(context, titulo: 'Entra ${evento.nombre}', lineas: lineas);
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
  // Ataque de daño por monedas («20×», D-13): la app las tira y registra el
  // daño final. El número de monedas sale de la carta del catálogo.
  final jefe = estado.jefe;
  final carta = jefe == null
      ? null
      : ref
          .read(catalogoProvider)
          .valueOrNull
          ?.aliadoDe(jefe.nombre, jefe.nivel, aliado.categoria);
  final monedas = carta != null && carta.nombre == aliado.nombre
      ? carta.ataqueMonedas
      : null;
  var caras = 0;
  var dano = aliado.ataqueDano ?? 0;
  if (monedas != null) {
    final azar = ref.read(azarProvider);
    for (var i = 0; i < monedas; i++) {
      if (azar.nextBool()) caras++;
    }
    dano = caras * dano;
  }
  // Daño extra con monedas («30+»): con las caras mínimas se suma el bonus.
  final bonusMonedas = carta != null && carta.nombre == aliado.nombre
      ? carta.ataqueBonusMonedas
      : null;
  var carasBonus = 0;
  var conBonus = false;
  if (bonusMonedas != null) {
    final azar = ref.read(azarProvider);
    for (var i = 0; i < bonusMonedas; i++) {
      if (azar.nextBool()) carasBonus++;
    }
    conBonus = carasBonus >= (carta!.ataqueBonusCaras ?? 1);
    if (conBonus) dano += carta.ataqueBonusDano ?? 0;
  }
  final esDeCarta = carta != null && carta.nombre == aliado.nombre;
  // Daño que crece con cada uso (Envite Ígneo): 10 + 10 × usos.
  final escala = esDeCarta ? carta.ataqueEscalaPorUso : null;
  if (escala != null) dano += escala * aliado.usos;
  // Daño extra si el defensor ya tenía un estado (Puño Dinámico): lo dicen
  // los jugadores.
  final extraEstado = esDeCarta ? carta.ataqueDanoExtraSiEstado : null;
  if (extraEstado != null) {
    final conEstado = await preguntarMesa(
      context,
      '${aliado.ataqueNombre}: ¿el Pokémon Defensor ya tenía una Condición '
      'Especial?',
    );
    if (conEstado == null || !context.mounted) return;
    if (conEstado) dano += extraEstado;
  }
  // Moneda del rival (Fuerza Lunar): la lanza el jugador y la app la anota.
  bool? monedaRival;
  if (esDeCarta && carta.ataqueMonedaRival) {
    final fijadas = recordatoriosDeMoneda(
      ref.read(catalogoProvider).valueOrNull,
      estado,
    );
    monedaRival = await preguntarMesa(
      context,
      [
        '${aliado.ataqueNombre}: '
            '${estado.jugadores[objetivo ?? aliado.slot].nombre} lanza una '
            'moneda. ¿Sale cara?',
        ...fijadas,
      ].join('\n'),
      si: 'Cara',
      no: 'Cruz',
    );
    if (monedaRival == null || !context.mounted) return;
  }
  final aplicado = registrar(
    context,
    ref,
    AtaqueAliado(
      slot: aliado.slot,
      dano: dano,
      objetivo: objetivo,
      moneda: monedaRival,
    ),
  );
  if (!aplicado || !context.mounted) return;
  final rival = estado.jugadores[objetivo ?? aliado.slot].nombre;
  final avisos = [
    // Lo primero, qué ataque es, contra quién y con cuánto daño; después, el
    // texto de la carta y el detalle de las tiradas.
    '${aliado.nombre} usa ${aliado.ataqueNombre ?? 'su ataque'} contra '
        '$rival${dano > 0 ? ': $dano de daño.' : '.'}',
    if (esDeCarta && carta.ataqueTexto != null) carta.ataqueTexto!,
    if (esDeCarta && carta.ataqueIgnoraEfectos)
      '${carta.habilidadNombre ?? 'Habilidad'}: el daño no se ve afectado por '
          'ningún efecto en el Pokémon Defensor.',
    if (escala != null)
      '${aliado.ataqueNombre}: ${aliado.usos} uso(s) previos → $dano de daño.',
    if (monedaRival == false)
      '${aliado.ataqueNombre}: cruz. El siguiente ataque de '
          '${estado.jugadores[objetivo ?? aliado.slot].nombre} hace '
          '30 puntos de daño menos.',
    if (monedas != null)
      '${aliado.ataqueNombre}: $caras de $monedas monedas en cara → '
          '$dano de daño.',
    if (bonusMonedas != null)
      '${aliado.ataqueNombre}: $carasBonus de $bonusMonedas monedas en cara → '
          '${conBonus ? 'bonus de ${carta!.ataqueBonusDano}, ' : 'sin bonus, '}'
          '$dano de daño.',
    if (carta?.ataqueDanoAdyacentes != null)
      () {
        final vecinos = jugadoresAdyacentes(estado, objetivo ?? aliado.slot);
        return '${aliado.ataqueNombre}: ${carta!.ataqueDanoAdyacentes} de daño '
            'a los Pokémon de los jugadores adyacentes al objetivo: '
            '${vecinos.isEmpty ? 'ninguno' : vecinos.map((i) => estado.jugadores[i].nombre).join(' y ')}.';
      }(),
  ];
  registrarAvisos(context, avisos);
}

/// Asientos adyacentes a [objetivo] en la mesa (circular), sin contar a los
/// jugadores eliminados ni al propio objetivo.
List<int> jugadoresAdyacentes(EstadoPartida estado, int objetivo) {
  final vivos = [
    for (var i = 0; i < estado.jugadores.length; i++)
      if (!estado.jugadores[i].eliminado || i == objetivo) i,
  ];
  final pos = vivos.indexOf(objetivo);
  if (pos < 0 || vivos.length < 2) return const [];
  final anterior = vivos[(pos - 1 + vivos.length) % vivos.length];
  final siguiente = vivos[(pos + 1) % vivos.length];
  return {anterior, siguiente}.toList();
}

/// Resultado de «Tirar dados» (T-44): el diálogo se cierra para que se vea la
/// mesa, los dados caen sobre ella y luego el diálogo se reabre con esto puesto.
class _ResultadoTirada {
  const _ResultadoTirada({
    required this.mesa,
    required this.slot,
    required this.categoria,
    required this.texto,
  });

  final TiradaMesa mesa;
  final int slot;
  final CategoriaAliado categoria;
  final String texto;

  bool get sin => mesa.sin;
}

Future<Object?> _abrirDialogoAliado(
  BuildContext context,
  WidgetRef ref,
  EstadoPartida estado, {
  _ResultadoTirada? inicial,
}) =>
    showDialog<Object>(
      context: context,
      builder: (_) => _DialogoAliado(
        estado: estado,
        catalogo: ref.read(catalogoProvider).valueOrNull,
        azar: ref.read(azarProvider),
        inicial: inicial,
      ),
    );

/// Enseña la tirada sobre la mesa y espera a que los dados paren. Si no
/// hubiera mesa que la anime, se da por terminada pasado un rato.
Future<void> _tirarEnMesa(WidgetRef ref, TiradaMesa tirada) async {
  ref.read(tiradaMesaProvider.notifier).state = tirada;
  final seguridad =
      Timer(duracionTirada + const Duration(seconds: 1), tirada.terminar);
  await tirada.terminada;
  seguridad.cancel();
  if (ref.read(tiradaMesaProvider) == tirada) {
    ref.read(tiradaMesaProvider.notifier).state = null;
  }
}

class _DialogoAliado extends StatefulWidget {
  const _DialogoAliado({
    required this.estado,
    required this.azar,
    this.catalogo,
    this.inicial,
  });

  final EstadoPartida estado;

  /// Tirada ya hecha con la que se abre el diálogo (tras ver caer los dados).
  final _ResultadoTirada? inicial;

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
  late int _slot = widget.inicial?.slot ??
      (widget.estado.slotsLibres.isEmpty ? 0 : widget.estado.slotsLibres.first);
  late CategoriaAliado _categoria = widget.inicial?.categoria ??
      (widget.estado.categoriasLibres.isEmpty
          ? CategoriaAliado.danio
          : widget.estado.categoriasLibres.first);

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
    _tirada = widget.inicial?.texto;
  }

  /// Resultado de la última tirada, para enseñarlo.
  String? _tirada;

  /// Nombre del dado que elige entre [n] valores (D-13): moneda con 2, d3, d4.
  static String _dado(int n) => n == 2 ? 'moneda' : 'd$n';

  /// Tira el dado de slot y el de categoría (D-13); la llamada del jefe ya no
  /// depende de una moneda (T-69). Cada dado elige con la misma probabilidad entre
  /// los valores libres, que es lo que da repetir la tirada en la mesa.
  void _tirarDados() {
    final e = widget.estado;
    final jefe = e.jefe;
    final inv = jefe == null
        ? null
        : widget.catalogo?.invocacionDe(jefe.nombre, jefe.nivel);
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
    final carasCategoria = inv?.aliados.length ?? CategoriaAliado.values.length;
    // El diálogo se cierra para que se vea la mesa mientras caen los dados.
    Navigator.of(context).pop(
      _ResultadoTirada(
        mesa: TiradaMesa(
          asiento: slot,
          carasSlot: e.jugadores.length,
          valorSlot: slot + 1,
          carasCategoria: carasCategoria,
          valorCategoria: categorias.indexOf(categoria) + 1,
        ),
        slot: slot,
        categoria: categoria,
        texto: 'Dado de slot (${_dado(e.jugadores.length)}): '
            '${e.jugadores[slot].nombre} · '
            'dado de categoría (d$carasCategoria): '
            '${etiquetaCategoria(categoria)}',
      ),
    );
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
    _habilidad.text = a.textoParaLaMesa ?? '';
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

  /// Deseo (Chingling): 10 monedas del jefe y una por aliado en juego (en
  /// orden) más la del propio aliado que entra. null si no es Deseo.
  List<bool>? _monedasDeDeseo() {
    if (_scriptId != 'deseo-100') return null;
    final n = 10 + widget.estado.aliados.length + 1;
    return [for (var i = 0; i < n; i++) widget.azar.nextBool()];
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
              monedas: _monedasDeDeseo(),
            ),
          ),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}
