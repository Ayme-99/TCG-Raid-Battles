import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

/// Scripts de los aliados de Onix (D-13, D-16): Chupavidas (Curandero) y Foco
/// Energía (Potenciador).
void main() {
  EstadoPartida conDosIntentos() {
    final s0 = configurar(const [100, 100, 100]);
    var s = apply(
      s0,
      ElegirJefe(nombre: 'Onix', nivel: s0.nivel, hp: 3000, invocacionCadaHp: 600),
    );
    return conIntentos(apply(s, const TurnoJugador(jugador: 0, dano: 1200)), 2);
  }

  AliadoInvocado zubat(int slot) => AliadoInvocado(
        slot: slot,
        categoria: CategoriaAliado.cura,
        nombre: 'Zubat',
        hp: 50,
        ataqueNombre: 'Chupavidas',
        ataqueDano: 10,
        efectos: EfectosAliado.programa,
        scriptId: 'chupavidas-10',
      );

  test('Chupavidas cura 10 al jefe y a cada aliado, sin pasar del máximo', () {
    // Dos intentos: Zubat en el slot 1 y un Machop sin ataque en el slot 2.
    var s = conDosIntentos();
    expect(s.intentosInvocacionPendientes, 2);
    s = apply(s, zubat(1));
    s = apply(
      s,
      const AliadoInvocado(
        slot: 2,
        categoria: CategoriaAliado.danio,
        nombre: 'Machop',
        hp: 70,
      ),
    );
    final hpJefe = s.jefe!.hp;
    // Al entrar, Chupavidas cura al jefe; los aliados ya están al máximo.
    s = apply(s, const AtaqueAliado(slot: 1, dano: 10));
    expect(s.jefe!.hp, hpJefe + 10);
    expect(s.curacionJefe, 10);
    expect(s.aliadoEn(1)!.hp, 50);
    expect(s.aliadoEn(2)!.hp, 70);
    // Un jugador daña al Machop (30 → le quedan 40) y, en el turno del jefe,
    // Chupavidas lo sube 10 y a Zubat no le pasa del máximo.
    s = apply(s, AtaqueAAliado(jugador: s.jugadorActual!, slot: 2, dano: 30));
    expect(s.aliadoEn(2)!.hp, 40);
    s = todosActuan(s, dano: 0);
    s = apply(s, const AtaqueJefe(ranura: 1, dano: 80));
    s = apply(s, const AtaqueAliado(slot: 1, dano: 10));
    expect(s.jefe!.hp, hpJefe + 20);
    expect(s.aliadoEn(2)!.hp, 50);
    expect(s.aliadoEn(1)!.hp, 50);
  });

  test('Foco Energía figura como bonus activo mientras Cubone vive', () {
    var s = conDosIntentos();
    expect(bonusAtaqueJefeActivos(s), isEmpty);
    s = apply(
      s,
      const AliadoInvocado(
        slot: 1,
        categoria: CategoriaAliado.potenciador,
        nombre: 'Cubone',
        hp: 60,
        efectos: EfectosAliado.programa,
        scriptId: 'foco-energia-10',
      ),
    );
    final bonus = bonusAtaqueJefeActivos(s).single;
    expect(bonus.aliado, 'Cubone');
    expect(bonus.valor, 10);
    expect(bonus.conMoneda, isTrue);
  });
}
