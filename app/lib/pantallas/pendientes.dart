import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../catalogo/catalogo.dart';
import '../partida/controlador_partida.dart';
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
              // Los dados salen solos sobre la mesa (resolverInvocacion).
              Text(
                'Intentos de invocación: $intentos · tirando los dados…',
                key: const Key('invocacion-en-curso'),
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

/// Resuelve un intento de invocación pendiente sin que nadie pulse nada: la
/// moneda del jefe (si no es de invocación segura), el dado de slot y el de
/// categoría caen sobre la mesa y, sea cual sea el resultado, se registra. Con
/// el jefe del catálogo entra el aliado de su carta; si el jefe se escribió a
/// mano, se piden los datos del aliado que ha salido.
Future<void> resolverInvocacion(BuildContext context, WidgetRef ref) async {
  final estado = ref.read(estadoProvider);
  if (estado.intentosInvocacionPendientes == 0) return;
  final jefe = estado.jefe;
  final catalogo = ref.read(catalogoProvider).valueOrNull;
  final inv =
      jefe == null ? null : catalogo?.invocacionDe(jefe.nombre, jefe.nivel);
  final azar = ref.read(azarProvider);

  if (inv != null && !inv.segura && !azar.nextBool()) {
    await _tirarEnMesa(ref, TiradaMesa.sinAliado());
    if (!context.mounted) return;
    if (registrar(context, ref, const SinInvocacion())) {
      registrarAviso(context, 'Salió cruz: no se invoca ningún aliado.');
    }
    return;
  }

  final slots = estado.slotsLibres;
  // Si el jefe viene del catálogo, el dado solo tiene las caras de los
  // aliados que su carta define (D-16: hasta que tenga los 6).
  final categorias = [
    for (final c in estado.categoriasLibres)
      if (inv == null || inv.aliados.containsKey(c)) c,
  ];
  if (slots.isEmpty || categorias.isEmpty) {
    if (registrar(context, ref, const SinInvocacion())) {
      registrarAviso(context, 'No hay hueco libre: no se invoca ningún aliado.');
    }
    return;
  }
  final slot = slots[azar.nextInt(slots.length)];
  final categoria = categorias[azar.nextInt(categorias.length)];
  final carasCategoria = inv?.aliados.length ?? CategoriaAliado.values.length;
  final tirada = _ResultadoTirada(
    mesa: TiradaMesa(
      asiento: slot,
      carasSlot: estado.jugadores.length,
      valorSlot: slot + 1,
      carasCategoria: carasCategoria,
      valorCategoria: categorias.indexOf(categoria) + 1,
    ),
    slot: slot,
    categoria: categoria,
    texto: 'Slot de ${estado.jugadores[slot].nombre} · '
        '${etiquetaCategoria(categoria)}',
  );
  await _tirarEnMesa(ref, tirada.mesa);
  if (!context.mounted) return;

  final carta = jefe == null
      ? null
      : catalogo?.aliadoDe(jefe.nombre, jefe.nivel, categoria);
  Object? resultado;
  if (carta != null) {
    resultado = AliadoInvocado(
      slot: slot,
      categoria: categoria,
      nombre: carta.nombre,
      hp: carta.hp,
      ataqueNombre: carta.ataqueNombre,
      ataqueDano: carta.ataqueDano,
      habilidad: carta.textoParaLaMesa,
      efectos: carta.efectos,
      scriptId: carta.scriptId,
      monedas: carta.scriptId == 'deseo-100'
          ? [
              for (var i = 0; i < 10 + estado.aliados.length + 1; i++)
                azar.nextBool(),
            ]
          : null,
    );
  } else {
    resultado = await _abrirDialogoAliado(context, ref, estado, inicial: tirada);
  }
  if (resultado is! AliadoInvocado || !context.mounted) return;
  if (registrar(context, ref, resultado) && resultado.monedas != null) {
    final m = resultado.monedas!;
    final jefeCaras = m.take(10).where((c) => c).length;
    final aliados = m.skip(10).where((c) => c).length;
    registrarAviso(
      context,
      'Deseo: $jefeCaras de 10 monedas en cara → el jefe se cura '
      '${100 * jefeCaras}. $aliados de ${m.length - 10} aliados '
      'se curan 100. Cada jugador lanza una moneda por '
      'cada uno de sus Pokémon: con cara, cura 100.',
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
    final conEstado = await _preguntar(
      context,
      '${aliado.ataqueNombre}: ¿el Pokémon Defensor ya tenía un estado '
      'especial?',
    );
    if (conEstado == null || !context.mounted) return;
    if (conEstado) dano += extraEstado;
  }
  // Moneda del rival (Fuerza Lunar): la lanza el jugador y la app la anota.
  bool? monedaRival;
  if (esDeCarta && carta.ataqueMonedaRival) {
    monedaRival = await _preguntar(
      context,
      '${aliado.ataqueNombre}: ${estado.jugadores[objetivo ?? aliado.slot].nombre} '
      'lanza una moneda. ¿Sale cara?',
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
  final avisos = [
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
  if (avisos.isNotEmpty) registrarAviso(context, avisos.join('\n'));
}

/// Pregunta sí/no a la mesa. null: se cerró el diálogo sin responder.
Future<bool?> _preguntar(
  BuildContext context,
  String pregunta, {
  String si = 'Sí',
  String no = 'No',
}) =>
    showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(pregunta),
        actions: [
          TextButton(
            key: const Key('pregunta-no'),
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(no),
          ),
          FilledButton(
            key: const Key('pregunta-si'),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(si),
          ),
        ],
      ),
    );

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

}

Future<Object?> _abrirDialogoAliado(
  BuildContext context,
  WidgetRef ref,
  EstadoPartida estado, {
  required _ResultadoTirada inicial,
}) =>
    showDialog<Object>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoAliado(
        estado: estado,
        catalogo: ref.read(catalogoProvider).valueOrNull,
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
    required this.catalogo,
    required this.inicial,
  });

  final EstadoPartida estado;

  /// Tirada ya hecha con la que se abre el diálogo (tras ver caer los dados).
  final _ResultadoTirada inicial;

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
  late final int _slot = widget.inicial.slot;
  late final CategoriaAliado _categoria = widget.inicial.categoria;

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
    _tirada = widget.inicial.texto;
  }

  /// Resultado de la última tirada, para enseñarlo.
  String? _tirada;

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

  String? _opcional(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aliado invocado'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_tirada!, key: const Key('resultado-dados')),
            const SizedBox(height: 8),
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
