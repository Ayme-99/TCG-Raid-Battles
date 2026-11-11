import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

/// Scripts reales de los aliados de la categoría Tanque (D-13): el jefe recibe
/// una cantidad fija de daño menos por cada ataque de los jugadores.
void main() {
  AliadoInvocado tanque(int slot, String scriptId,
          {CategoriaAliado categoria = CategoriaAliado.tanque}) =>
      AliadoInvocado(
        slot: slot,
        categoria: categoria,
        nombre: 'Tanque',
        hp: 120,
        efectos: EfectosAliado.programa,
        scriptId: scriptId,
      );

  /// Jefe de 3000 HP con 3 jugadores; el jugador 0 lo baja a 2400 y se invoca
  /// un aliado en el slot 1.
  EstadoPartida conTanque(String scriptId) {
    final s0 = configurar(const [100, 100, 100]);
    var s = apply(
      s0,
      ElegirJefe(nombre: 'Jefe', nivel: s0.nivel, hp: 3000, invocacionCadaHp: 600),
    );
    s = conIntentos(apply(s, const TurnoJugador(jugador: 0, dano: 600)));
    return apply(s, tanque(1, scriptId));
  }

  test('los scripts tanque-jefe-N existen y restan N', () {
    for (final n in [10, 20, 30, 40]) {
      expect(scriptsAliado['tanque-jefe-$n']!.reduccionDano, n);
    }
  });

  test('sin aliados Tanque el daño no cambia', () {
    final s = apply(
      configurar(const [100, 100, 100]),
      const ElegirJefe(nombre: 'Jefe', nivel: 1, hp: 3000),
    );
    expect(reduccionDanoAlJefe(s), 0);
  });

  /// El siguiente jugador que no es el dueño del slot 1 hace un ataque de
  /// [dano]; si le toca antes al dueño, actúa con 0 (no puede dañar al jefe).
  (EstadoPartida, int) ataca(EstadoPartida s, int dano) {
    if (s.jugadorActual == 1) s = apply(s, const TurnoJugador(jugador: 1, dano: 0));
    final j = s.jugadorActual!;
    return (apply(s, TurnoJugador(jugador: j, dano: dano)), j);
  }

  test('cada ataque de un jugador hace N de daño menos', () {
    final s0 = conTanque('tanque-jefe-30');
    expect(reduccionDanoAlJefe(s0), 30);
    final (s, j) = ataca(s0, 200);
    expect(s.jefe!.hp, 2400 - 170);
    expect(s.danoPorJugador[j], 170);
  });

  test('un ataque no baja de 0 de daño y no cura', () {
    final (s, j) = ataca(conTanque('tanque-jefe-40'), 25);
    expect(s.jefe!.hp, 2400);
    expect(s.danoPorJugador[j], 0);
  });

  test('un ataque de 0 sigue siendo 0', () {
    final (s, _) = ataca(conTanque('tanque-jefe-10'), 0);
    expect(s.jefe!.hp, 2400);
  });

  test('un aliado Tanque deja de reducir cuando cae', () {
    var s = todosActuan(conTanque('tanque-jefe-20'), dano: 0);
    s = apply(s, const FinTurnoJefe());
    // 140 − 20 de reducción = 120: justo lo que le queda.
    s = apply(s, AtaqueAAliado(jugador: s.jugadorActual!, slot: 1, dano: 140));
    expect(s.aliados, isEmpty);
    expect(reduccionDanoAlJefe(s), 0);
  });

  test('el Tanque también reduce el daño que reciben los aliados', () {
    var s = todosActuan(conTanque('tanque-jefe-20'), dano: 0);
    s = apply(s, const FinTurnoJefe());
    // El Tanque (120 HP) es el propio aliado atacado: 50 − 20 = 30 de daño.
    s = apply(s, AtaqueAAliado(jugador: s.jugadorActual!, slot: 1, dano: 50));
    expect(s.aliadoEn(1)!.hp, 90);
  });
}
