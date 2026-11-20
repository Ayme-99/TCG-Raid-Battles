import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../partida/controlador_partida.dart';
import 'comun.dart';
import 'paneles.dart';

/// Botón «⋯» que abre el menú de acciones de una carta o de un asiento.
class BotonMenu extends StatelessWidget {
  const BotonMenu({
    super.key,
    required this.etiqueta,
    required this.onPressed,
    this.tamano = 28,
  });

  final String etiqueta;
  final VoidCallback onPressed;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: etiqueta,
      child: Material(
        color: Colors.black54,
        shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 2)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: tamano,
            height: tamano,
            child: Icon(Icons.more_horiz, color: Colors.white, size: tamano * 0.7),
          ),
        ),
      ),
    );
  }
}

class _Accion {
  const _Accion(this.clave, this.icono, this.texto, this.ejecutar,
      {this.activa = true});

  final String clave;
  final IconData icono;
  final String texto;
  final Future<void> Function() ejecutar;
  final bool activa;
}

Future<void> _mostrarMenu(
  BuildContext context,
  String titulo,
  List<_Accion> acciones,
) async {
  final elegida = await mostrarDialogo<_Accion>(
    context: context,
    builder: (dialogo) => SimpleDialog(
      title: Text(titulo),
      children: [
        for (final a in acciones)
          SimpleDialogOption(
            key: Key(a.clave),
            onPressed: a.activa ? () => Navigator.of(dialogo).pop(a) : null,
            child: Row(
              children: [
                Icon(a.icono, size: 20),
                const SizedBox(width: 12),
                Text(a.texto),
              ],
            ),
          ),
      ],
    ),
  );
  if (elegida == null || !context.mounted) return;
  await elegida.ejecutar();
}

/// Pregunta qué jugador ha aplicado el estado y lo registra en el jefe o en
/// el aliado de [slot].
Future<void> _aplicarEstado(
  BuildContext context,
  WidgetRef ref,
  EstadoDelJefe estado, {
  int? slot,
}) async {
  final actual = ref.read(estadoProvider);
  final activos = jugadoresActivos(actual);
  if (activos.isEmpty) return;
  final jugador = await elegirJugador(
    context,
    actual,
    titulo: '¿Qué jugador ha aplicado el estado?',
    asientos: activos,
  );
  if (jugador == null || !context.mounted) return;
  registrar(
    context,
    ref,
    slot == null
        ? AplicarEstadoJefe(jugador: jugador, estado: estado)
        : AplicarEstadoAliado(jugador: jugador, slot: slot, estado: estado),
  );
}

List<_Accion> _estadosYDano(
  BuildContext context,
  WidgetRef ref, {
  int? slot,
}) =>
    [
      _Accion('accion-envenenar', Icons.science, 'Envenenar',
          () => _aplicarEstado(context, ref, EstadoDelJefe.veneno, slot: slot)),
      _Accion('accion-quemar', Icons.whatshot, 'Quemar',
          () => _aplicarEstado(context, ref, EstadoDelJefe.quemadura, slot: slot)),
      _Accion(
        'accion-dano-efecto',
        Icons.flash_on,
        'Daño por efecto (rebote…)',
        () => registrarDanoDeEfecto(context, ref, slotInicial: slot),
      ),
    ];

/// Acciones sobre el jefe.
Future<void> menuJefe(BuildContext context, WidgetRef ref) => _mostrarMenu(
      context,
      'Jefe',
      _estadosYDano(context, ref),
    );

/// Acciones sobre el aliado del [slot].
Future<void> menuAliado(BuildContext context, WidgetRef ref, int slot) {
  final aliado = ref.read(estadoProvider).aliadoEn(slot);
  return _mostrarMenu(
    context,
    aliado?.nombre ?? 'Aliado',
    _estadosYDano(context, ref, slot: slot),
  );
}

/// Acciones sobre el jugador del [asiento].
Future<void> menuJugador(BuildContext context, WidgetRef ref, int asiento) {
  final j = ref.read(estadoProvider).jugadores[asiento];
  return _mostrarMenu(context, j.nombre, [
    _Accion(
      'accion-ko',
      Icons.catching_pokemon,
      'Pokémon KO (${j.pokemonVivos}/${j.pokemonTotal})',
      () async {
        registrar(context, ref, PokemonKo(asiento));
      },
      activa: !j.eliminado,
    ),
  ]);
}
