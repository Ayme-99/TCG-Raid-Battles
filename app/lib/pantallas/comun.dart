import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../partida/controlador_partida.dart';

/// Envía un evento al motor y, si las reglas lo rechazan, muestra el motivo.
/// Devuelve `true` si se aplicó.
bool registrar(BuildContext context, WidgetRef ref, Evento evento) {
  final error = ref.read(partidaProvider.notifier).registrar(evento);
  if (error != null) {
    registrarAviso(context, error);
    return false;
  }
  return true;
}

/// Nombre de la categoría de un aliado (D-13) tal como se muestra.
String etiquetaCategoria(CategoriaAliado c) => switch (c) {
      CategoriaAliado.danio => 'Daño',
      CategoriaAliado.tanque => 'Tanque',
      CategoriaAliado.cura => 'Curandero',
      CategoriaAliado.control => 'Control',
      CategoriaAliado.potenciador => 'Potenciador',
      CategoriaAliado.debilitador => 'Debilitador',
    };

/// Muestra un aviso breve en la parte inferior. Un aviso de varias líneas se
/// queda más tiempo para que dé tiempo a leerlo.
void registrarAviso(BuildContext context, String mensaje) {
  final lineas = '\n'.allMatches(mensaje).length + 1;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: Duration(seconds: 4 + 2 * (lineas - 1)),
      ),
    );
}

/// Varios avisos a la vez, en uno solo (un aviso nuevo tapa al anterior).
void registrarAvisos(BuildContext context, Iterable<String> mensajes) {
  final lista = mensajes.toList();
  if (lista.isNotEmpty) registrarAviso(context, lista.join('\n'));
}

/// Algo que la mesa tiene que hacer con sus cartas (poner contadores, lanzar
/// monedas...): se queda en pantalla hasta que alguien pulsa «Hecho».
Future<void> avisarMesa(
  BuildContext context, {
  required String titulo,
  required List<String> lineas,
}) {
  if (lineas.isEmpty) return Future.value();
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      key: const Key('aviso-mesa'),
      title: Text(titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lineas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(l),
            ),
        ],
      ),
      actions: [
        FilledButton(
          key: const Key('aviso-mesa-hecho'),
          onPressed: () => Navigator.of(c).pop(),
          child: const Text('Hecho'),
        ),
      ],
    ),
  );
}

/// Lanza una moneda en la pantalla (T-71): el resultado se decide al abrir el
/// diálogo, la moneda gira y se para en él, y «Continuar» lo devuelve. Es para
/// las monedas que lanzan los jugadores y que la app puede tirar por ellos.
/// `true`: cara.
Future<bool> lanzarMonedaEnPantalla(
  BuildContext context,
  WidgetRef ref, {
  required String titulo,
  String? detalle,
}) async {
  final cara = ref.read(azarProvider).nextBool();
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => _DialogoMoneda(titulo: titulo, detalle: detalle, cara: cara),
  );
  return cara;
}

class _DialogoMoneda extends StatefulWidget {
  const _DialogoMoneda({
    required this.titulo,
    required this.detalle,
    required this.cara,
  });

  final String titulo;
  final String? detalle;
  final bool cara;

  @override
  State<_DialogoMoneda> createState() => _DialogoMonedaState();
}

class _DialogoMonedaState extends State<_DialogoMoneda>
    with SingleTickerProviderStateMixin {
  late final AnimationController _giro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..addListener(() => setState(() {}));

  @override
  void initState() {
    super.initState();
    _giro.forward();
  }

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tres vueltas y media si sale cruz, tres si sale cara: la moneda se para
    // con la cara que toca hacia arriba.
    final vueltas = widget.cara ? 6.0 : 7.0;
    final angulo = Curves.easeOut.transform(_giro.value) * vueltas * math.pi;
    final alto = math.max(0.04, math.cos(angulo).abs());
    final muestraCara = math.cos(angulo) >= 0;
    final terminada = _giro.isCompleted;
    final tema = Theme.of(context);
    return AlertDialog(
      key: const Key('moneda-en-pantalla'),
      title: Text(widget.titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.detalle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(widget.detalle!),
            ),
          Transform.scale(
            scaleY: alto,
            child: Container(
              width: 110,
              height: 110,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: muestraCara
                    ? tema.colorScheme.primaryContainer
                    : tema.colorScheme.secondaryContainer,
                border: Border.all(color: tema.colorScheme.outline, width: 3),
              ),
              child: Text(
                muestraCara ? 'CARA' : 'CRUZ',
                style: tema.textTheme.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            terminada ? (widget.cara ? 'Sale cara' : 'Sale cruz') : '...',
            key: const Key('moneda-resultado'),
            style: tema.textTheme.titleMedium,
          ),
        ],
      ),
      actions: [
        FilledButton(
          key: const Key('moneda-continuar'),
          onPressed: terminada ? () => Navigator.of(context).pop() : null,
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}

/// Pregunta sí/no a la mesa. null: se cerró el diálogo sin responder.
Future<bool?> preguntarMesa(
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

/// Campo de texto que solo admite dígitos.
class CampoNumero extends StatelessWidget {
  const CampoNumero({
    super.key,
    required this.controlador,
    required this.etiqueta,
  });

  final TextEditingController controlador;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: etiqueta,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// Rebote del jefe (T-59): tras un ataque con el efecto `autodanoSiKo`, la
/// mesa dice si el Defensor quedó KO. Si es así se registran el KO y el daño
/// que el jefe se hace, atribuido a ese jugador. Debe llamarse justo después de
/// registrar el ataque, antes de cualquier espera, para que [context] siga
/// montado.
void preguntarRebote(
  BuildContext context,
  WidgetRef ref, {
  required int jugador,
  required int puntos,
}) {
  final nombre = ref.read(estadoProvider).jugadores[jugador].nombre;
  showDialog<void>(
    context: context,
    builder: (dialogo) => AlertDialog(
      key: const Key('dialogo-rebote'),
      title: const Text('Rebote'),
      content: Text(
        '¿El Pokémon Defensor de $nombre ha quedado Fuera de Combate? Si es '
        'así, el jefe se hace $puntos de daño (se atribuye a $nombre).',
      ),
      actions: [
        TextButton(
          key: const Key('rebote-no'),
          onPressed: () => Navigator.of(dialogo).pop(),
          child: const Text('No'),
        ),
        FilledButton(
          key: const Key('rebote-si'),
          onPressed: () {
            if (registrar(dialogo, ref, PokemonKo(jugador))) {
              registrar(dialogo, ref, DanoDeEfecto(puntos: puntos, jugador: jugador));
            }
            Navigator.of(dialogo).pop();
          },
          child: const Text('Sí, hay KO'),
        ),
      ],
    ),
  );
}

/// Pide un número entero (≥ 0) en un diálogo. Devuelve `null` si se cancela.
Future<int?> pedirNumero(
  BuildContext context, {
  required String titulo,
  required String etiqueta,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _DialogoNumero(titulo: titulo, etiqueta: etiqueta),
  );
}

class _DialogoNumero extends StatefulWidget {
  const _DialogoNumero({required this.titulo, required this.etiqueta});

  final String titulo;
  final String etiqueta;

  @override
  State<_DialogoNumero> createState() => _DialogoNumeroState();
}

class _DialogoNumeroState extends State<_DialogoNumero> {
  final _controlador = TextEditingController();

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: CampoNumero(
        controlador: _controlador,
        etiqueta: widget.etiqueta,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('dialogo-aceptar'),
          onPressed: () =>
              Navigator.of(context).pop(int.tryParse(_controlador.text) ?? 0),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}

/// Pide elegir un jugador entre [asientos]. Devuelve su asiento o `null`.
Future<int?> elegirJugador(
  BuildContext context,
  EstadoPartida estado, {
  required String titulo,
  required List<int> asientos,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(titulo),
      children: [
        for (final a in asientos)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(a),
            child: Text(estado.jugadores[a].nombre),
          ),
      ],
    ),
  );
}

/// Asientos de los jugadores que siguen en juego.
List<int> jugadoresActivos(EstadoPartida estado) => [
      for (final j in estado.jugadores)
        if (!j.eliminado) j.asiento,
    ];

/// Asientos a los que el jefe puede atacar: los que siguen en juego y no
/// están KO. Un ataque contra un jugador KO falla: se descarta la carta y se
/// roba otra.
List<int> jugadoresObjetivo(EstadoPartida estado) => [
      for (final a in jugadoresActivos(estado))
        if (!estado.enKo(a)) a,
    ];
