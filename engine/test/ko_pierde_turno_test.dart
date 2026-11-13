import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

/// D-13: si el ataque de entrada de un aliado deja KO al Pokémon de un jugador
/// que todavía no ha actuado, ese jugador pierde su turno.
void main() {
  /// 3 jugadores; el jugador 0 ya ha actuado, entra un aliado en el slot 2 y
  /// su ataque de entrada está registrado.
  EstadoPartida trasAtaqueDeEntrada() {
    final s0 = configurar(const [100, 100, 100]);
    var s = apply(
      s0,
      ElegirJefe(nombre: 'Jefe', nivel: s0.nivel, hp: 3000, invocacionCadaHp: 600),
    );
    s = conIntentos(apply(s, const TurnoJugador(jugador: 0, dano: 600)));
    s = apply(
      s,
      const AliadoInvocado(
        slot: 2,
        categoria: CategoriaAliado.danio,
        nombre: 'Plusle',
        hp: 80,
        ataqueNombre: 'Chispazo',
        ataqueDano: 30,
      ),
    );
    return apply(s, const AtaqueAliado(slot: 2, dano: 30));
  }

  test('también si el KO se marca antes de registrar el ataque de entrada', () {
    final s0 = configurar(const [100, 100, 100]);
    var s = apply(
      s0,
      ElegirJefe(nombre: 'Jefe', nivel: s0.nivel, hp: 3000, invocacionCadaHp: 600),
    );
    s = conIntentos(apply(s, const TurnoJugador(jugador: 0, dano: 600)));
    s = apply(
      s,
      const AliadoInvocado(
        slot: 2,
        categoria: CategoriaAliado.danio,
        nombre: 'Plusle',
        hp: 80,
        ataqueNombre: 'Chispazo',
        ataqueDano: 30,
      ),
    );
    s = apply(s, const PokemonKo(1));
    expect(s.jugadorActual, 2);
    expect(s.orden, [0, 2]);
    s = apply(s, const AtaqueAliado(slot: 2, dano: 30));
    expect(s.jugadorActual, 2);
  });

  test('el jugador al que le tocaba pierde su turno y pasa al siguiente', () {
    var s = trasAtaqueDeEntrada();
    expect(s.jugadorActual, 1);
    s = apply(s, const PokemonKo(1));
    expect(s.orden, [0, 2]);
    expect(s.jugadorActual, 2);
    expect(
      () => apply(s, const TurnoJugador(jugador: 1, dano: 10)),
      throwsA(isA<ReglaIncumplida>()),
    );
    // Ese turno perdido es el que se sienta: la ronda siguiente actúa normal.
    expect(s.prioridad, isEmpty);
    s = todosActuan(s, dano: 0);
    s = apply(s, const FinTurnoJefe());
    expect(s.orden, [0, 1, 2]);
  });

  test('un jugador que aún no ha actuado y no es el actual también lo pierde', () {
    var s = trasAtaqueDeEntrada();
    s = apply(s, const PokemonKo(2));
    expect(s.orden, [0, 1]);
    expect(s.jugadorActual, 1);
  });

  test('si ya había actuado, no cambia nada', () {
    var s = trasAtaqueDeEntrada();
    s = apply(s, const PokemonKo(0));
    expect(s.orden, [0, 1, 2]);
    expect(s.jugadorActual, 1);
  });

  test('varios KO seguidos del mismo ataque pierden el turno los dos', () {
    var s = trasAtaqueDeEntrada();
    s = aplicarTodos(s, const [PokemonKo(1), PokemonKo(2)]);
    expect(s.fase, Fase.turnoJefe);
  });

  test('un KO sin ataque de aliado antes no quita el turno', () {
    var s = apply(
      trasAtaqueDeEntrada(),
      const TurnoJugador(jugador: 1, dano: 0),
    );
    s = apply(s, const PokemonKo(2));
    expect(s.jugadorActual, 2);
    expect(s.orden, [0, 1, 2]);
  });
}
