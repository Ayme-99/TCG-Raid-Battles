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
    return apply(s, const TurnoJugador(jugador: 0, dano: 1200));
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
    // Dos intentos: Zubat en el slot 1 y un aliado sin script en el slot 2.
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
        ataqueNombre: 'Puño Incremento',
        ataqueDano: 20,
      ),
    );
    // El jugador 2 hace de dueño del Machop y ataca al Zubat con 25: se queda
    // en 25 de 50.
    s = apply(s, AtaqueAAliado(jugador: s.jugadorActual!, slot: 1, dano: 25));
    expect(s.aliadoEn(1)!.hp, 25);
    final hpJefe = s.jefe!.hp;
    // Chupavidas al entrar: el jefe sube 10, Zubat pasa de 25 a 35 y el
    // Machop se queda en su máximo.
    s = apply(s, const AtaqueAliado(slot: 1, dano: 10));
    expect(s.jefe!.hp, hpJefe + 10);
    expect(s.curacionJefe, 10);
    expect(s.aliadoEn(1)!.hp, 35);
    expect(s.aliadoEn(2)!.hp, 70);
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
