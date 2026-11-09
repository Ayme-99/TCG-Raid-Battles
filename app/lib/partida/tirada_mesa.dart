import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Duración de la animación de los dados sobre la mesa.
const duracionTirada = Duration(milliseconds: 2800);

/// Una tirada de invocación que se enseña sobre la mesa (T-44): el resultado
/// ya está decidido y los dados caen y ruedan hasta pararse en él, mientras la
/// cámara mira al lado de la mesa donde aparecen.
class TiradaMesa {
  TiradaMesa({
    required this.asiento,
    required this.carasSlot,
    required this.valorSlot,
    required this.carasCategoria,
    required this.valorCategoria,
  }) : sin = false;

  /// La moneda del jefe salió en contra: solo cae una moneda y no hay aliado.
  TiradaMesa.sinAliado()
      : sin = true,
        asiento = 0,
        carasSlot = 2,
        valorSlot = 2,
        carasCategoria = 0,
        valorCategoria = 0;

  /// Asiento (posición en la lista de jugadores) cuyo slot sale en el dado.
  final int asiento;
  final int carasSlot;

  /// Cara final del dado de slot, de 1 a [carasSlot].
  final int valorSlot;
  final int carasCategoria;
  final int valorCategoria;
  final bool sin;

  final _fin = Completer<void>();

  /// Se completa cuando los dados han parado.
  Future<void> get terminada => _fin.future;

  /// Los dados han parado (lo avisa la mesa). Se puede llamar varias veces.
  void terminar() {
    if (!_fin.isCompleted) _fin.complete();
  }
}

/// Tirada que se está enseñando ahora mismo sobre la mesa, si la hay.
final tiradaMesaProvider = StateProvider<TiradaMesa?>((ref) => null);
