import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

List<Evento> _partidaAleatoriaComprobada(int semilla) =>
    partidaAleatoria(semilla, alAplicar: _comprobar);

void _comprobar(EstadoPartida s, String donde) {
  final jefe = s.jefe;
  if (jefe != null) {
    expect(jefe.hp, inInclusiveRange(0, jefe.hpMaximo), reason: donde);
    expect(
        s.danoPorJugador.fold<int>(0, (a, b) => a + b) +
            s.danoEstados -
            s.curacionJefe,
        jefe.hpMaximo - jefe.hp,
        reason: '$donde: daño (jugadores y estados) menos curación debe ser '
            'el HP perdido');
  }
  for (final j in s.jugadores) {
    expect(j.pokemonVivos, inInclusiveRange(0, 2), reason: donde);
  }
  for (final a in [...s.prioridad, ...s.cartasAnimoPendientes]) {
    expect(s.jugadores[a].eliminado, isFalse, reason: '$donde: asiento $a');
  }
  final slots = [for (final a in s.aliados) a.slot];
  expect(slots.toSet().length, slots.length,
      reason: '$donde: un aliado como máximo por slot');
  final categorias = [for (final a in s.aliados) a.categoria];
  expect(categorias.toSet().length, categorias.length,
      reason: '$donde: un aliado como máximo por categoría');
  for (final a in s.aliados) {
    expect(a.hp, inInclusiveRange(1, a.hpMaximo), reason: donde);
  }
  expect(s.intentosInvocacionPendientes, greaterThanOrEqualTo(0),
      reason: donde);
  if (s.terminada) {
    expect(s.resultado, isNotNull, reason: donde);
    if (s.resultado == Resultado.victoria) {
      expect(jefe!.hp, 0, reason: donde);
    } else {
      expect(s.jugadores.every((j) => j.eliminado), isTrue, reason: donde);
    }
  } else {
    expect(s.resultado, isNull, reason: donde);
  }
}

void main() {
  test('60 partidas aleatorias mantienen los invariantes', () {
    for (var semilla = 0; semilla < 60; semilla++) {
      _partidaAleatoriaComprobada(semilla);
    }
  });

  test('reproducir el mismo registro da siempre el mismo estado', () {
    for (var semilla = 0; semilla < 30; semilla++) {
      final eventos = _partidaAleatoriaComprobada(semilla);
      final a = reproducir(eventos).toJson();
      final b = reproducir(eventos).toJson();
      final c = Partida.desdeEventos(eventos).estado.toJson();
      expect(b, equals(a), reason: 'semilla $semilla');
      expect(c, equals(a), reason: 'semilla $semilla');
    }
  });

  test('reproducir en dos tramos equivale a hacerlo de una vez', () {
    final eventos = _partidaAleatoriaComprobada(7);
    final mitad = eventos.length ~/ 2;
    final primero = reproducir(eventos.sublist(0, mitad));
    final dos = reproducir(eventos.sublist(mitad), desde: primero);
    expect(dos.toJson(), equals(reproducir(eventos).toJson()));
  });
}
