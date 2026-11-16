import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../partida/controlador_partida.dart';
import '../partida/tirada_mesa.dart';

/// Una sola forma de lanzar monedas en toda la app (T-73): se echan a suerte
/// con el azar de la partida y caen sobre la mesa, como los dados. Devuelve el
/// resultado de cada una en orden (true = cara) cuando ya han parado; quien
/// llama lo registra en el evento, que es lo que reproduce el historial.
///
/// El azar se saca en orden, una vez por moneda, así que las partidas con azar
/// fijo (los tests) son reproducibles.
Future<List<bool>> lanzarMonedas(
  WidgetRef ref, {
  int cuantas = 1,
  LugarMoneda lugar = LugarMoneda.aliados,
  int asiento = 0,
  String? leyenda,
}) async {
  final azar = ref.read(azarProvider);
  final resultados = [for (var i = 0; i < cuantas; i++) azar.nextBool()];
  await tirarEnMesa(
    ref,
    TiradaMesa.monedas(
      resultados,
      lugar: lugar,
      asiento: asiento,
      leyenda: leyenda,
    ),
  );
  return resultados;
}

/// Si ya hay unos dados o unas monedas cayendo sobre la mesa. Los botones que
/// lanzan monedas se ignoran mientras tanto, para no lanzar dos veces.
bool hayTiradaEnMesa(WidgetRef ref) {
  final t = ref.read(tiradaMesaProvider);
  return t != null && !t.finalizada;
}

/// Enseña la tirada sobre la mesa y espera a que pare. Si no hubiera mesa que
/// la anime, se da por terminada pasado un rato.
Future<void> tirarEnMesa(WidgetRef ref, TiradaMesa tirada) async {
  // El controlador se toma antes de esperar: la pantalla que lanzó la tirada
  // puede desmontarse mientras ruedan los dados (p. ej. al pasar al turno del
  // jefe) y entonces su `ref` ya no se puede usar.
  final controlador = ref.read(tiradaMesaProvider.notifier);
  // Si ya hay otra cayendo, se espera a que acabe: nunca se pisan.
  while (true) {
    final previa = controlador.state;
    if (previa == null || previa.finalizada) break;
    await previa.terminada;
  }
  controlador.state = tirada;
  // Una pregunta espera a que alguien conteste, sin tiempo límite.
  final seguridad = tirada.esPregunta
      ? null
      : Timer(tirada.duracion + const Duration(seconds: 1), tirada.terminar);
  await tirada.terminada;
  seguridad?.cancel();
  if (controlador.state == tirada) {
    controlador.state = null;
  }
}

/// Cuando la moneda no la lanza la app sino la mesa (con Fijar Blanco la
/// primera moneda de cada jugador es cruz y la lleva la mesa a mano), la app
/// pregunta qué salió, sobre la mesa y con la misma moneda: cae, se queda de
/// canto y se elige cara o cruz junto a ella. `true`: cara; null: la mesa se
/// cerró sin responder.
Future<bool?> preguntarMoneda(
  WidgetRef ref, {
  required String titulo,
  String? detalle,
  List<String> recordatorios = const [],
  LugarMoneda lugar = LugarMoneda.asiento,
  int asiento = 0,
}) async {
  final t = TiradaMesa.pregunta(
    lugar: lugar,
    asiento: asiento,
    leyenda: titulo,
    detalle: detalle,
    recordatorios: recordatorios,
  );
  await tirarEnMesa(ref, t);
  return t.respuesta;
}
