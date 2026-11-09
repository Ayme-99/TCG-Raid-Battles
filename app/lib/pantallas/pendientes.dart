import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../catalogo/catalogo.dart';
import '../partida/controlador_partida.dart';
import 'comun.dart';
import 'dado_animado.dart';

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
                      if (evento is AliadoInvocado &&
                          evento.monedas != null &&
                          context.mounted) {
                        final m = evento.monedas!;
                        final jefe = m.take(10).where((c) => c).length;
                        final aliados =
                            m.skip(10).where((c) => c).length;
                        registrarAviso(
                          context,
                          'Deseo: $jefe de 10 monedas en cara → el jefe se cura '
                          '${100 * jefe}. $aliados de ${m.length - 10} aliados '
                          'se curan 100. Cada jugador lanza una moneda por '
                          'cada uno de sus Pokémon: con cara, cura 100.',
                        );
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

class _DialogoAliadoState extends State<_DialogoAliado>
    with SingleTickerProviderStateMixin {
  /// Duración de la animación de los dados (T-44).
  static const _duracionDados = Duration(milliseconds: 1100);

  late final AnimationController _anim =
      AnimationController(vsync: this, duration: _duracionDados);

  /// Tirada que se está enseñando (o ya enseñada), con sus caras.
  _Tirada? _enCurso;

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
    if (_anim.isAnimating) return;
    if (inv != null && !inv.segura && !widget.azar.nextBool()) {
      // Sin aliado: se enseña la moneda y al pararse se cierra el diálogo.
      setState(() => _enCurso = const _Tirada.sinAliado());
      _anim.forward(from: 0).whenComplete(() {
        if (mounted) Navigator.of(context).pop(const SinInvocacion());
      });
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
    final carasCategoria = inv?.aliados.length ?? CategoriaAliado.values.length;
    final texto = 'Dado de slot (${_dado(e.jugadores.length)}): '
        '${e.jugadores[slot].nombre} · '
        'dado de categoría (d$carasCategoria): '
        '${etiquetaCategoria(categoria)}';
    setState(() {
      _tirada = null;
      _enCurso = _Tirada(
        carasSlot: e.jugadores.length,
        valorSlot: slot + 1,
        etiquetaSlot: e.jugadores[slot].nombre,
        carasCategoria: carasCategoria,
        valorCategoria: categorias.indexOf(categoria) + 1,
        etiquetaCategoria: etiquetaCategoria(categoria),
      );
    });
    // Los campos se rellenan cuando los dados se paran, no antes.
    _anim.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _slot = slot;
        _categoria = categoria;
        _rellenar(categoria);
        _tirada = texto;
      });
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
    _habilidad.text = a.textoParaLaMesa ?? '';
  }

  @override
  void dispose() {
    _anim.dispose();
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
              onPressed: _anim.isAnimating ? null : _tirarDados,
              icon: const Icon(Icons.casino),
              label: const Text('Tirar dados'),
            ),
            if (_enCurso != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _enCurso!.sin
                    ? DadoAnimado(
                        animacion: _anim,
                        caras: 2,
                        valor: 2,
                        etiqueta: 'Sin aliado',
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          DadoAnimado(
                            animacion: _anim,
                            caras: _enCurso!.carasSlot,
                            valor: _enCurso!.valorSlot,
                            etiqueta: _enCurso!.etiquetaSlot,
                          ),
                          DadoAnimado(
                            animacion: _anim,
                            caras: _enCurso!.carasCategoria,
                            valor: _enCurso!.valorCategoria,
                            etiqueta: _enCurso!.etiquetaCategoria,
                            semilla: 1,
                          ),
                        ],
                      ),
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

/// Resultado de una tirada ya hecha, con lo que hay que enseñar en los dados.
class _Tirada {
  const _Tirada({
    required this.carasSlot,
    required this.valorSlot,
    required this.etiquetaSlot,
    required this.carasCategoria,
    required this.valorCategoria,
    required this.etiquetaCategoria,
  }) : sin = false;

  /// La moneda del jefe salió en contra: no hay aliado.
  const _Tirada.sinAliado()
      : sin = true,
        carasSlot = 0,
        valorSlot = 0,
        etiquetaSlot = '',
        carasCategoria = 0,
        valorCategoria = 0,
        etiquetaCategoria = '';

  final bool sin;
  final int carasSlot;
  final int valorSlot;
  final String etiquetaSlot;
  final int carasCategoria;
  final int valorCategoria;
  final String etiquetaCategoria;
}
