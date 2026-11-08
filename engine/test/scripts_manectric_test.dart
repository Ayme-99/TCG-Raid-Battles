import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

/// Scripts de los aliados de Manectric (D-16): Drenadoras, Aullido y Gruñido.
void main() {
  EstadoPartida conJefe({int dano = 600}) {
    final s0 = configurar(const [100, 100, 100]);
    var s = apply(
      s0,
      ElegirJefe(nombre: 'Manectric', nivel: s0.nivel, hp: 3000, invocacionCadaHp: 600),
    );
    return apply(s, const TurnoJugador(jugador: 0, dano: dano));
  }

  AliadoInvocado aliado(CategoriaAliado c, String id, {int slot = 1}) =>
      AliadoInvocado(
        slot: slot,
        categoria: c,
        nombre: id,
        hp: 100,
        efectos: EfectosAliado.programa,
        scriptId: id,
      );

  test('Drenadoras cura 10 por jugador no eliminado al entrar y al final del turno', () {
    var s = conJefe();
    final hp0 = s.jefe!.hp;
    s = apply(s, aliado(CategoriaAliado.cura, 'drenadoras-10'));
    expect(s.jefe!.hp, hp0 + 30);
    s = todosActuan(s, dano: 0);
    final antes = s.jefe!.hp;
    s = apply(s, const FinTurnoJefe());
    expect(s.jefe!.hp, antes + 30);
  });

  test('Aullido es un bonus fijo de 20 sin moneda', () {
    final s = apply(conJefe(), aliado(CategoriaAliado.potenciador, 'aullido-20'));
    final b = bonusAtaqueJefeActivos(s).single;
    expect(b.valor, 20);
    expect(b.conMoneda, isFalse);
  });

  test('Gruñido resta 10 a los ataques contra el jefe y se suma al Tanque', () {
    var s = apply(conJefe(dano: 1200), aliado(CategoriaAliado.debilitador, 'grunido-10'));
    expect(reduccionDanoAlJefe(s), 10);
    s = apply(s, aliado(CategoriaAliado.tanque, 'tanque-jefe-20', slot: 2));
    expect(reduccionDanoAlJefe(s), 30);
  });
}
