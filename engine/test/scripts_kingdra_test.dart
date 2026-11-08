import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

/// Scripts de los aliados de Kingdra (D-16): Velo Sagrado, Chupavidas 30 y
/// Agilidad.
void main() {
  EstadoPartida conJefe({int dano = 600}) {
    final s0 = configurar(const [100, 100, 100]);
    var s = apply(
      s0,
      ElegirJefe(nombre: 'Kingdra', nivel: s0.nivel, hp: 3000, invocacionCadaHp: 600),
    );
    return apply(s, TurnoJugador(jugador: 0, dano: dano));
  }

  AliadoInvocado aliado(CategoriaAliado c, String id,
          {int slot = 1, int? ataque}) =>
      AliadoInvocado(
        slot: slot,
        categoria: c,
        nombre: id,
        hp: 100,
        ataqueDano: ataque,
        efectos: EfectosAliado.programa,
        scriptId: id,
      );

  test('Velo Sagrado quita los estados del jefe al entrar y bloquea los nuevos', () {
    var s = apply(
      conJefe(),
      const AplicarEstadoJefe(jugador: 1, estado: EstadoDelJefe.veneno),
    );
    expect(s.jefe!.envenenado, isTrue);
    s = apply(s, aliado(CategoriaAliado.tanque, 'velo-sagrado'));
    expect(s.jefe!.envenenado, isFalse);
    expect(s.jefe!.quemado, isFalse);
    expect(estadosBloqueados(s), isTrue);
    expect(
      () => apply(
        s,
        const AplicarEstadoJefe(jugador: 1, estado: EstadoDelJefe.quemadura),
      ),
      throwsA(isA<ReglaIncumplida>()),
    );
    // La aplicación ya contada se conserva para el bono.
    expect(s.estadosAplicados[1], 1);
  });

  test('sin Velo Sagrado los estados se aplican', () {
    final s = apply(
      conJefe(),
      const AplicarEstadoJefe(jugador: 1, estado: EstadoDelJefe.quemadura),
    );
    expect(s.jefe!.quemado, isTrue);
    expect(estadosBloqueados(s), isFalse);
  });

  test('chupavidas-30 cura 30 al jefe y a los aliados', () {
    var s = conJefe();
    s = apply(s, aliado(CategoriaAliado.cura, 'chupavidas-30', ataque: 30));
    final hp0 = s.jefe!.hp;
    s = apply(s, const AtaqueAliado(slot: 1, dano: 30));
    expect(s.jefe!.hp, hp0 + 30);
  });

  test('Agilidad solo suma al primer ataque del jefe de cada turno', () {
    var s = apply(conJefe(), aliado(CategoriaAliado.potenciador, 'agilidad-30'));
    s = todosActuan(s, dano: 0);
    expect(s.fase, Fase.turnoJefe);
    expect(bonusAtaqueJefeActivos(s).single.valor, 30);
    s = apply(s, const AtaqueJefe(ranura: 1, dano: 90));
    expect(bonusAtaqueJefeActivos(s), isEmpty);
  });
}
