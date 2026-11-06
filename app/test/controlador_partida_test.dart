import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/partida/controlador_partida.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

ProviderContainer crear() {
  final c = ProviderContainer(overrides: [
    generadorIdProvider.overrideWithValue(() => 'partida-de-prueba'),
    relojProvider.overrideWithValue(() => DateTime.utc(2026, 11, 6, 12)),
  ]);
  addTearDown(c.dispose);
  return c;
}

ControladorPartida controlador(ProviderContainer c) =>
    c.read(partidaProvider.notifier);

/// Dos jugadores, jefe de 100 HP: el nivel sale de X = 200, así que es Nv1.
void preparar(ProviderContainer c) {
  final p = controlador(c);
  expect(
    p.registrar(const ConfigurarJugadores([
      ConfigJugador(nombre: 'Ana', ataqueMaximo: 100),
      ConfigJugador(nombre: 'Bea', ataqueMaximo: 100),
    ])),
    isNull,
  );
  expect(
    p.registrar(const ElegirJefe(nombre: 'Jefe', nivel: 1, hp: 100)),
    isNull,
  );
}

void main() {
  test('una partida nueva está en preparación y no se puede deshacer', () {
    final c = crear();
    expect(c.read(estadoProvider).fase, Fase.preparacion);
    expect(c.read(puedeDeshacerProvider), isFalse);
    expect(c.read(puedeRehacerProvider), isFalse);
    expect(c.read(puntosProvider), isNull);
  });

  test('registrar aplica el evento con las reglas del motor', () {
    final c = crear();
    preparar(c);
    expect(c.read(estadoProvider).fase, Fase.turnoJugadores);
    expect(controlador(c).registrar(const TurnoJugador(jugador: 0, dano: 30)), isNull);
    expect(c.read(estadoProvider).jefe!.hp, 70);
  });

  test('un evento ilegal devuelve el motivo y no cambia la partida', () {
    final c = crear();
    preparar(c);
    var cambios = 0;
    c.listen(partidaProvider, (_, __) => cambios++);

    final motivo =
        controlador(c).registrar(const TurnoJugador(jugador: 1, dano: 10));
    expect(motivo, isNotNull);
    expect(motivo, contains('no es el turno'));
    expect(cambios, 0);
    expect(c.read(estadoProvider).jefe!.hp, 100);
  });

  test('deshacer y rehacer devuelven el mismo estado', () {
    final c = crear();
    preparar(c);
    final p = controlador(c);
    p.registrar(const TurnoJugador(jugador: 0, dano: 30));
    p.registrar(const TurnoJugador(jugador: 1, dano: 20));
    final antes = jsonEncode(c.read(estadoProvider).toJson());

    p.deshacer();
    p.deshacer();
    expect(c.read(estadoProvider).jefe!.hp, 100);
    expect(c.read(puedeRehacerProvider), isTrue);
    p.rehacer();
    p.rehacer();

    expect(jsonEncode(c.read(estadoProvider).toJson()), antes);
    expect(c.read(puedeRehacerProvider), isFalse);
  });

  test('un evento nuevo tras deshacer descarta lo que había por rehacer', () {
    final c = crear();
    preparar(c);
    final p = controlador(c);
    p.registrar(const TurnoJugador(jugador: 0, dano: 30));
    p.deshacer();
    p.registrar(const TurnoJugador(jugador: 0, dano: 10));
    expect(c.read(puedeRehacerProvider), isFalse);
  });

  test('una partida jugada hasta el final da puntos y registro', () {
    final c = crear();
    preparar(c);
    final p = controlador(c);
    expect(p.registrar(const TurnoJugador(jugador: 0, dano: 60)), isNull);
    expect(c.read(puntosProvider), isNull); // aún en curso
    expect(p.registrar(const TurnoJugador(jugador: 1, dano: 40)), isNull);

    final estado = c.read(estadoProvider);
    expect(estado.fase, Fase.terminada);
    expect(estado.resultado, Resultado.victoria);

    final puntos = c.read(puntosProvider)!;
    expect(puntos.puntosTotal, 3000);
    expect(puntos.jugadores.map((j) => j.nombre), ['Ana', 'Bea']);
    expect(puntos.jugadores.map((j) => j.puntos), [1650, 1350]);

    // Ya terminada, las reglas no admiten más eventos.
    expect(p.registrar(const FinTurnoJefe()), isNotNull);
  });

  test('el registro sigue el contrato y se puede volver a leer', () {
    final c = crear();
    preparar(c);
    final p = controlador(c);
    p.registrar(const TurnoJugador(jugador: 0, dano: 60));
    p.registrar(const TurnoJugador(jugador: 1, dano: 40));

    final registro = p.registro(cuentas: ['usuario-ana', null]);
    final json = registro.toJson();
    expect(json['version'], versionRegistro);
    expect(json['partidaId'], 'partida-de-prueba');
    expect(json['creadaEn'], '2026-11-06T12:00:00.000Z');
    expect(json['resumen'], isNotNull);

    final leido = RegistroPartida.deJson(jsonDecode(jsonEncode(json)));
    expect(leido.toJson(), equals(json));
  });

  test('el registro de una partida en curso no lleva resumen', () {
    final c = crear();
    preparar(c);
    expect(controlador(c).registro().toJson().containsKey('resumen'), isFalse);
  });

  test('nuevaPartida descarta la actual', () {
    final c = crear();
    preparar(c);
    controlador(c).nuevaPartida();
    expect(c.read(estadoProvider).fase, Fase.preparacion);
    expect(c.read(puedeDeshacerProvider), isFalse);
  });

  test('los ids de partida son distintos y caben en el contrato', () {
    final ids = {for (var i = 0; i < 50; i++) generarIdPartida()};
    expect(ids.length, 50);
    expect(ids.every((id) => id.length <= 64), isTrue);
  });
}
