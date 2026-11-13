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
    return conIntentos(
      apply(s, TurnoJugador(jugador: 0, dano: dano)),
      dano ~/ 600,
    );
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

  test('la reducción para un jugador suma aliados y su debilitación', () {
    var s = apply(conJefe(), aliado(CategoriaAliado.debilitador, 'grunido-10'));
    expect(reduccionParaJugador(s, 1), 10);
    s = s.copiarCon(debilitados: const {1: 30});
    expect(reduccionParaJugador(s, 1), 40);
    expect(reduccionParaJugador(s, 2), 10);
  });

  group('Moflete Estático (Minun)', () {
    test('quien deja fuera de combate a Minun pierde su siguiente turno', () {
      var s = apply(conJefe(), aliado(CategoriaAliado.tanque, 'moflete-estatico'));
      s = apply(s, const AtaqueAAliado(jugador: 1, slot: 1, dano: 100));
      expect(s.aliados, isEmpty);
      final f = s.efectosActivos.single;
      expect(f.tipo, TipoEfectoAtaque.paralizarDefensor);
      expect(f.jugador, 1);
      expect(f.restantes, 2);
      // Acaba este turno de los jugadores: le queda el siguiente entero.
      s = todosActuan(s, dano: 0);
      expect(s.fase, Fase.turnoJefe);
      expect(s.efectosActivos.single.restantes, 1);
      s = apply(s, const FinTurnoJefe());
      expect(s.efectosActivos.single.jugador, 1);
      s = todosActuan(s, dano: 0);
      expect(s.efectosActivos, isEmpty);
    });

    test('también cuenta si cae otro aliado mientras Minun está en juego', () {
      var s = apply(
        conJefe(dano: 1200),
        aliado(CategoriaAliado.tanque, 'moflete-estatico'),
      );
      s = apply(s, aliado(CategoriaAliado.debilitador, 'grunido-10', slot: 2));
      s = apply(s, const AtaqueAAliado(jugador: 1, slot: 2, dano: 200));
      expect(s.aliados.single.scriptId, 'moflete-estatico');
      expect(s.efectosActivos.single.jugador, 1);
    });

    test('si el aliado sobrevive, o no hay aura, nadie queda paralizado', () {
      var s = apply(conJefe(), aliado(CategoriaAliado.tanque, 'moflete-estatico'));
      s = apply(s, const AtaqueAAliado(jugador: 1, slot: 1, dano: 50));
      expect(s.aliados.single.hp, 50);
      expect(s.efectosActivos, isEmpty);

      var sinAura =
          apply(conJefe(), aliado(CategoriaAliado.debilitador, 'grunido-10'));
      sinAura =
          apply(sinAura, const AtaqueAAliado(jugador: 1, slot: 1, dano: 200));
      expect(sinAura.aliados, isEmpty);
      expect(sinAura.efectosActivos, isEmpty);
    });
  });
}
