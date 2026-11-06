import 'dart:convert';

import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

String _firma(Historial h) => jsonEncode(h.partida.estado.toJson());

void main() {
  final inicio = [
    ConfigurarJugadores([
      ConfigJugador(nombre: 'Ana', ataqueMaximo: 100),
      ConfigJugador(nombre: 'Bea', ataqueMaximo: 100),
    ]),
    ElegirJefe(nombre: 'Jefe', nivel: 1, hp: 1000),
    TurnoJugador(jugador: 0, dano: 100),
    TurnoJugador(jugador: 1, dano: 50),
  ];

  Historial armado() => inicio.fold(Historial.nuevo(), (h, e) => h.aplicar(e));

  test('una partida nueva no se puede deshacer ni rehacer', () {
    final h = Historial.nuevo();
    expect(h.puedeDeshacer, isFalse);
    expect(h.puedeRehacer, isFalse);
    expect(identical(h.deshacer(), h), isTrue);
    expect(identical(h.rehacer(), h), isTrue);
  });

  test('deshacer quita el último evento y deja el estado anterior', () {
    final h = armado();
    final antes = inicio
        .take(3)
        .fold(Historial.nuevo(), (x, e) => x.aplicar(e));
    final d = h.deshacer();
    expect(_firma(d), _firma(antes));
    expect(d.partida.eventos.length, 3);
    expect(d.puedeRehacer, isTrue);
  });

  test('deshacer todo y rehacer todo devuelve exactamente el mismo estado', () {
    final h = armado();
    var x = h;
    while (x.puedeDeshacer) {
      x = x.deshacer();
    }
    expect(_firma(x), _firma(Historial.nuevo()));
    expect(x.porRehacer.length, inicio.length);
    while (x.puedeRehacer) {
      x = x.rehacer();
    }
    expect(_firma(x), _firma(h));
    expect(x.partida.eventos.length, h.partida.eventos.length);
    expect(x.puedeRehacer, isFalse);
  });

  test('un evento nuevo descarta lo que había por rehacer', () {
    final h = armado().deshacer().deshacer();
    expect(h.puedeRehacer, isTrue);
    final n = h.aplicar(TurnoJugador(jugador: 0, dano: 10));
    expect(n.puedeRehacer, isFalse);
    expect(n.partida.eventos.length, 3);
  });

  test('un evento ilegal lanza y no cambia el historial', () {
    final h = armado().deshacer();
    expect(() => h.aplicar(const FinTurnoJefe()), throwsA(isA<ReglaIncumplida>()));
    expect(h.puedeRehacer, isTrue);
    expect(h.partida.eventos.length, 3);
  });

  test('se puede deshacer el final de la partida y seguir jugando', () {
    var h = armado().aplicar(const Abandonar());
    expect(h.partida.estado.fase, Fase.terminada);
    h = h.deshacer();
    expect(h.partida.estado.fase, isNot(Fase.terminada));
    expect(h.partida.estado.fase, Fase.turnoJefe);
    h = h.aplicar(const FinTurnoJefe());
    expect(h.partida.estado.fase, Fase.turnoJugadores);
  });

  test('en 60 partidas aleatorias deshacer y rehacer es la identidad', () {
    for (var semilla = 0; semilla < 60; semilla++) {
      final eventos = partidaAleatoria(semilla);
      final completa = eventos.fold(Historial.nuevo(), (h, e) => h.aplicar(e));
      var h = completa;
      final k = 1 + semilla % eventos.length;
      for (var i = 0; i < k; i++) {
        h = h.deshacer();
      }
      expect(h.partida.eventos.length, eventos.length - k);
      expect(_firma(h),
          _firma(Historial.de(Partida.desdeEventos(eventos.take(eventos.length - k)))),
          reason: 'semilla $semilla');
      for (var i = 0; i < k; i++) {
        h = h.rehacer();
      }
      expect(_firma(h), _firma(completa), reason: 'semilla $semilla');
    }
  });
}
