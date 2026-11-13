import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:incursiones_app/almacen/almacen.dart';
import 'package:incursiones_app/cuenta/cliente_api.dart';
import 'package:incursiones_app/cuenta/sesion.dart';
import 'package:incursiones_app/envios/controlador_envios.dart';
import 'package:incursiones_app/partida/controlador_partida.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

const sesionDePrueba = Sesion(
  token: 'token-de-prueba',
  username: 'ana',
  userId: '64b000000000000000000001',
);

/// Almacén con la sesión de Ana ya iniciada.
AlmacenMemoria almacenConSesion() =>
    AlmacenMemoria()..datos['sesion'] = jsonEncode(sesionDePrueba.toJson());

/// Un reintento que la app ha programado y que el test dispara a mano.
class Reintento {
  Reintento(this.espera, this.accion);

  final Duration espera;
  final void Function() accion;
}

/// Respuesta del servidor falso: la función recibe cada petición.
typedef Servidor = Future<http.Response> Function(http.Request peticion);

/// Servidor que guarda todo (201) y apunta las peticiones.
Servidor servidorQueGuarda([List<http.Request>? peticiones]) =>
    (peticion) async {
      peticiones?.add(peticion);
      return http.Response('{"partidaId":"x"}', 201);
    };

/// Mazo del jefe que saca siempre las mismas cartas, en orden y en bucle.
/// Por defecto: ataque 1 contra el jugador 1, sin robar otra.
class MazoFijo implements MazoAtaquesJefe {
  MazoFijo([
    this.cartas = const [
      CartaAtaqueJefe(numero: 1, ranura: 1, jugador: 0, robaOtra: false),
    ],
  ]);

  final List<CartaAtaqueJefe> cartas;
  int _siguiente = 0;

  @override
  int get restantes => cartas.length;

  @override
  CartaAtaqueJefe robar(Set<int> jugadoresActivos) =>
      cartas[_siguiente++ % cartas.length];
}

/// Todo lo que cambia respecto a la app real: almacén en memoria, servidor
/// falso y reintentos que no esperan de verdad.
List<Override> sobrescribir({
  Almacen? almacen,
  Servidor? servidor,
  List<Reintento>? reintentos,
  MazoAtaquesJefe? mazo,
}) {
  return [
    mazoAtaquesJefeProvider.overrideWithValue(mazo ?? MazoFijo()),
    almacenProvider.overrideWithValue(almacen ?? AlmacenMemoria()),
    clienteApiProvider.overrideWithValue(
      ClienteApi(
        base: 'http://prueba/api',
        cliente: MockClient(servidor ?? servidorQueGuarda()),
      ),
    ),
    programadorProvider.overrideWithValue((espera, accion) {
      reintentos?.add(Reintento(espera, accion));
      return () {};
    }),
  ];
}

/// Deja correr las tareas asíncronas pendientes (red falsa y almacén).
Future<void> asentar() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Lleva una partida de 2 jugadores hasta el final del turno del jefe de la
/// ronda 1, que es cuando llama a su primer aliado (T-71): deja un intento de
/// invocación por resolver al empezar la ronda 2. El daño (50) no llega a
/// ningún umbral de HP de los jefes de los tests.
void llegarALaLlamadaDelJefe(ProviderContainer c) {
  final partida = c.read(partidaProvider.notifier);
  for (final e in const <Evento>[
    TurnoJugador(jugador: 0, dano: 50),
    TurnoJugador(jugador: 1, dano: 0),
    AtaqueJefe(ranura: 1, dano: 0),
    FinTurnoJefe(),
  ]) {
    final error = partida.registrar(e);
    if (error != null) throw StateError('$e: $error');
  }
}

/// Hace actuar, sin daño, a los jugadores que quedan en el turno de la ronda.
void jugadoresActuanSinDano(ProviderContainer c) {
  final partida = c.read(partidaProvider.notifier);
  var estado = c.read(estadoProvider);
  while (estado.fase == Fase.turnoJugadores) {
    final error =
        partida.registrar(TurnoJugador(jugador: estado.jugadorActual!, dano: 0));
    if (error != null) throw StateError('turno de jugador: $error');
    estado = c.read(estadoProvider);
  }
}
