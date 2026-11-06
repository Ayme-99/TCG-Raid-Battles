import 'dart:math';

import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

/// Genera una partida legal con eventos aleatorios y comprueba invariantes
/// después de cada evento.
List<Evento> _partidaAleatoria(int semilla) {
  final azar = Random(semilla);
  final eventos = <Evento>[];
  var s = EstadoPartida.inicial();

  void aplica(Evento e) {
    s = apply(s, e);
    eventos.add(e);
    _comprobar(s, 'semilla $semilla, evento ${eventos.length}');
  }

  List<int> vivos() => [
        for (final j in s.jugadores)
          if (!j.eliminado) j.asiento,
      ];

  void koAlAzar() {
    final v = vivos();
    if (v.isNotEmpty) aplica(PokemonKo(v[azar.nextInt(v.length)]));
  }

  final n = 1 + azar.nextInt(4);
  aplica(ConfigurarJugadores([
    for (var i = 0; i < n; i++)
      ConfigJugador(nombre: 'J$i', ataqueMaximo: azar.nextInt(260)),
  ]));
  aplica(ElegirJefe(nombre: 'Jefe', nivel: s.nivel, hp: 100 + azar.nextInt(900)));

  var pasos = 0;
  while (!s.terminada && pasos++ < 400) {
    if (s.fase == Fase.turnoJugadores) {
      for (final a in List.of(s.cartasAnimoPendientes)) {
        aplica(CartaAnimoRobada(jugador: a, carta: 1 + azar.nextInt(5)));
      }
      aplica(TurnoJugador(jugador: s.jugadorActual!, dano: azar.nextInt(120)));
      if (!s.terminada && azar.nextInt(6) == 0) koAlAzar();
    } else if (s.fase == Fase.turnoJefe) {
      if (azar.nextInt(3) == 0) aplica(CuracionJefe(azar.nextInt(300)));
      for (var k = 0; k < 1 + azar.nextInt(3); k++) {
        final v = vivos();
        aplica(AtaqueJefe(
          ranura: 1 + azar.nextInt(3),
          dano: azar.nextInt(250),
          jugador: azar.nextBool() ? null : v[azar.nextInt(v.length)],
        ));
      }
      while (!s.terminada && azar.nextInt(3) == 0) {
        koAlAzar();
      }
      if (!s.terminada) aplica(const FinTurnoJefe());
    }
  }
  return eventos;
}

void _comprobar(EstadoPartida s, String donde) {
  final jefe = s.jefe;
  if (jefe != null) {
    expect(jefe.hp, inInclusiveRange(0, jefe.hpMaximo), reason: donde);
    expect(s.danoPorJugador.fold<int>(0, (a, b) => a + b) - s.curacionJefe,
        jefe.hpMaximo - jefe.hp,
        reason: '$donde: daño menos curación debe ser el HP perdido');
  }
  for (final j in s.jugadores) {
    expect(j.pokemonVivos, inInclusiveRange(0, 2), reason: donde);
  }
  for (final a in [...s.prioridad, ...s.cartasAnimoPendientes]) {
    expect(s.jugadores[a].eliminado, isFalse, reason: '$donde: asiento $a');
  }
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
      _partidaAleatoria(semilla);
    }
  });

  test('reproducir el mismo registro da siempre el mismo estado', () {
    for (var semilla = 0; semilla < 30; semilla++) {
      final eventos = _partidaAleatoria(semilla);
      final a = reproducir(eventos).toJson();
      final b = reproducir(eventos).toJson();
      final c = Partida.desdeEventos(eventos).estado.toJson();
      expect(b, equals(a), reason: 'semilla $semilla');
      expect(c, equals(a), reason: 'semilla $semilla');
    }
  });

  test('reproducir en dos tramos equivale a hacerlo de una vez', () {
    final eventos = _partidaAleatoria(7);
    final mitad = eventos.length ~/ 2;
    final primero = reproducir(eventos.sublist(0, mitad));
    final dos = reproducir(eventos.sublist(mitad), desde: primero);
    expect(dos.toJson(), equals(reproducir(eventos).toJson()));
  });
}
