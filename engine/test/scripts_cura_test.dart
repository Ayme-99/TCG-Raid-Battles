import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

/// Scripts reales de los aliados de la categoría Cura (D-13): el jefe se cura
/// al final de su turno sin que lo anote nadie.
void main() {
  EstadoPartida jefeConAliadoCura(String scriptId, {int hp = 3000}) {
    final s0 = configurar(const [100, 100, 100]);
    var s = apply(
      s0,
      ElegirJefe(nombre: 'Jefe', nivel: s0.nivel, hp: hp, invocacionCadaHp: 600),
    );
    s = apply(s, const TurnoJugador(jugador: 0, dano: 600));
    return apply(
      s,
      AliadoInvocado(
        slot: 1,
        categoria: CategoriaAliado.cura,
        nombre: 'Curandero',
        hp: 70,
        efectos: EfectosAliado.programa,
        scriptId: scriptId,
      ),
    );
  }

  EstadoPartida alFinalDelTurnoDelJefe(EstadoPartida e) =>
      apply(todosActuan(e, dano: 0), const FinTurnoJefe());

  for (final (id, cura) in [
    ('cura-jefe-20', 20),
    ('cura-jefe-30', 30),
    ('cura-jefe-40', 40),
    ('cura-jefe-50', 50),
  ]) {
    test('$id existe y cura $cura HP al final del turno del jefe', () {
      expect(scriptsAliado.containsKey(id), isTrue);
      final antes = jefeConAliadoCura(id);
      expect(antes.jefe!.hp, 2400);
      final despues = alFinalDelTurnoDelJefe(antes);
      expect(despues.jefe!.hp, 2400 + cura);
      expect(despues.curacionJefe, cura);
    });
  }

  test('no cura por encima del HP máximo', () {
    // El jefe está a 2400 de 3000: se cura a mano hasta 2980 y el script solo
    // pone los 20 que faltan.
    var s = jefeConAliadoCura('cura-jefe-50');
    s = apply(s, const CuracionJefe(580));
    expect(s.jefe!.hp, 2980);
    s = alFinalDelTurnoDelJefe(s);
    expect(s.jefe!.hp, 3000);
    expect(s.curacionJefe, 600);
  });
}
