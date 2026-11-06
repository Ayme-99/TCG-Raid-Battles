import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

/// D-08: orden de comprobación cuando un efecto afecta a la vez al jefe y al
/// último Pokémon de la mesa. La mesa registra primero el daño al jefe.
void main() {
  // Un jugador con un solo Pokémon vivo y el jefe a punto de caer.
  EstadoPartida alLimite() {
    var s = empezar(ataques: [100], hp: 100);
    s = apply(s, const PokemonKo(0));
    expect(s.jugadores[0].pokemonVivos, 1);
    return s;
  }

  test('daño al jefe primero: victoria y el KO posterior ya no cuenta', () {
    var s = alLimite();
    s = apply(s, const TurnoJugador(jugador: 0, dano: 100));
    expect(s.fase, Fase.terminada);
    expect(s.resultado, Resultado.victoria);
    expect(() => apply(s, const PokemonKo(0)),
        throwsA(isA<ReglaIncumplida>()));
    expect(s.resultado, Resultado.victoria);
  });

  test('KO primero: derrota y el daño posterior ya no cuenta', () {
    var s = alLimite();
    s = apply(s, const PokemonKo(0));
    expect(s.fase, Fase.terminada);
    expect(s.resultado, Resultado.derrota);
    expect(() => apply(s, const TurnoJugador(jugador: 0, dano: 100)),
        throwsA(isA<ReglaIncumplida>()));
    expect(s.resultado, Resultado.derrota);
  });

  test('ninguna partida aleatoria acepta eventos tras terminar', () {
    for (var semilla = 0; semilla < 60; semilla++) {
      final eventos = partidaAleatoria(semilla);
      var s = EstadoPartida.inicial();
      for (final e in eventos) {
        expect(s.terminada, isFalse, reason: 'semilla $semilla');
        s = apply(s, e);
      }
      if (s.terminada) {
        expect(() => apply(s, const FinTurnoJefe()),
            throwsA(isA<ReglaIncumplida>()));
        expect(() => apply(s, const PokemonKo(0)),
            throwsA(isA<ReglaIncumplida>()));
      }
    }
  });
}
