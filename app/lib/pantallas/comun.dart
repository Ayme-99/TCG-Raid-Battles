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

/// Muestra un aviso breve en la parte inferior.
void registrarAviso(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}

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
