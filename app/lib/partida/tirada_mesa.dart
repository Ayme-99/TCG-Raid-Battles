import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Duración de la animación de los dados sobre la mesa.
const duracionTirada = Duration(milliseconds: 2800);

/// Duración de las monedas: se lanzan, rebotan y se quedan un momento quietas
/// enseñando el resultado.
const duracionMonedas = Duration(milliseconds: 3600);

/// Dónde cae una tirada de monedas (T-73): decide dónde se pintan y adónde
/// mira la cámara.
enum LugarMoneda {
  /// Delante de un jugador (la moneda que lanza él).
  asiento,

  /// Ante los aliados (la moneda de un aliado o de la llamada del jefe).
  aliados,

  /// Ante el jefe (su quemadura, su ataque).
  jefe,
}

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
  })  : monedas = null,
        lugar = LugarMoneda.asiento,
        leyenda = null;

  /// Una tanda de monedas (T-73): ya están lanzadas y caen sobre la mesa hasta
  /// pararse en su cara o su cruz. [resultados] va en orden (true = cara).
  /// [leyenda] dice para qué son («Quemadura del jefe»). Con [lugar] igual a
  /// [LugarMoneda.asiento], [asiento] es el jugador que las lanza.
  TiradaMesa.monedas(
    List<bool> resultados, {
    this.lugar = LugarMoneda.aliados,
    this.asiento = 0,
    this.leyenda,
  })  : monedas = List.unmodifiable(resultados),
        carasSlot = 2,
        valorSlot = 2,
        carasCategoria = 0,
        valorCategoria = 0;

  /// La moneda del jefe salió en contra: solo cae una moneda y no hay aliado.
  TiradaMesa.sinAliado()
      : this.monedas(const [false], leyenda: 'Llamada del jefe');

  /// Asiento (posición en la lista de jugadores) cuyo slot sale en el dado.
  final int asiento;
  final int carasSlot;

  /// Cara final del dado de slot, de 1 a [carasSlot].
  final int valorSlot;
  final int carasCategoria;
  final int valorCategoria;

  /// Resultado de cada moneda (true = cara) si es una tanda de monedas; null
  /// si son los dados de una invocación.
  final List<bool>? monedas;
  final LugarMoneda lugar;
  final String? leyenda;

  bool get esMoneda => monedas != null;

  /// Lo que dura la animación.
  Duration get duracion => esMoneda ? duracionMonedas : duracionTirada;

  /// «CARA», «CRUZ» o, con varias, «3 caras · 1 cruz».
  String get resumen {
    final m = monedas ?? const <bool>[];
    final caras = m.where((c) => c).length;
    final cruces = m.length - caras;
    if (m.length == 1) return caras == 1 ? 'CARA' : 'CRUZ';
    String cuenta(int n, String uno, String varios) =>
        '$n ${n == 1 ? uno : varios}';
    return '${cuenta(caras, 'cara', 'caras')} · '
        '${cuenta(cruces, 'cruz', 'cruces')}';
  }

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
