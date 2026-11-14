import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

/// D-17: veneno y quemadura de los aliados, chequeo al cerrar el turno del
/// jefe, Velo Sagrado y bono de estados.
void main() {
  // Jefe de 3000 HP con 3 jugadores; el jugador 0 ya ha actuado y hay un
  // intento de invocación pendiente (como en scripts_kingdra_test).
  EstadoPartida conJefe() {
    final s0 = configurar(const [100, 100, 100]);
    final s = apply(
      s0,
      ElegirJefe(
          nombre: 'Kingdra', nivel: s0.nivel, hp: 3000, invocacionCadaHp: 600),
    );
    return conIntentos(apply(s, const TurnoJugador(jugador: 0, dano: 600)), 1);
  }

  AliadoInvocado rattata({int slot = 1, int hp = 60}) => AliadoInvocado(
        slot: slot,
        categoria: CategoriaAliado.danio,
        nombre: 'Rattata',
        hp: hp,
      );

  AliadoInvocado velo({int slot = 0}) => AliadoInvocado(
        slot: slot,
        categoria: CategoriaAliado.tanque,
        nombre: 'Seel',
        hp: 100,
        efectos: EfectosAliado.programa,
        scriptId: 'velo-sagrado',
      );

  EstadoPartida conAliado({int hp = 60}) => apply(conJefe(), rattata(hp: hp));

  EstadoPartida aplicar(
          EstadoPartida s, int jugador, int slot, EstadoDelJefe estado) =>
      apply(s,
          AplicarEstadoAliado(jugador: jugador, slot: slot, estado: estado));

  // Todos actúan y se cierra el turno del jefe con [fin].
  EstadoPartida cerrar(EstadoPartida s, [FinTurnoJefe fin = const FinTurnoJefe()]) =>
      apply(todosActuan(s), fin);

  const monedaCruz = FinTurnoJefe(
    monedasQuemaduraAliados: [MonedaQuemaduraAliado(slot: 1, cara: false)],
  );
  const monedaCara = FinTurnoJefe(
    monedasQuemaduraAliados: [MonedaQuemaduraAliado(slot: 1, cara: true)],
  );

  group('aplicar estados', () {
    test('el veneno y la quemadura se quedan en el aliado y cuentan', () {
      var s = aplicar(conAliado(), 1, 1, EstadoDelJefe.veneno);
      s = aplicar(s, 2, 1, EstadoDelJefe.quemadura);
      expect(s.aliadoEn(1)!.envenenado, isTrue);
      expect(s.aliadoEn(1)!.quemado, isTrue);
      expect(s.estadosAplicados, [0, 1, 1]);
      expect(s.jefe!.envenenado, isFalse);
    });

    test('aplicar un estado que el aliado ya tiene no cambia nada', () {
      final s = aplicar(conAliado(), 1, 1, EstadoDelJefe.veneno);
      final igual = aplicar(s, 2, 1, EstadoDelJefe.veneno);
      expect(igual.toJson(), equals(s.toJson()));
    });

    test('cada aliado lleva sus estados', () {
      var s = conIntentos(conAliado(), 1);
      s = apply(
        s,
        const AliadoInvocado(
          slot: 2,
          categoria: CategoriaAliado.cura,
          nombre: 'Chansey',
          hp: 80,
        ),
      );
      s = aplicar(s, 0, 1, EstadoDelJefe.veneno);
      expect(s.aliadoEn(1)!.envenenado, isTrue);
      expect(s.aliadoEn(2)!.envenenado, isFalse);
      expect(s.estadosAplicados, [1, 0, 0]);
    });

    test('es válido también en el turno del jefe', () {
      final s = aplicar(todosActuan(conAliado()), 0, 1, EstadoDelJefe.veneno);
      expect(s.fase, Fase.turnoJefe);
      expect(s.aliadoEn(1)!.envenenado, isTrue);
    });

    test('el slot debe tener un aliado y el jugador no estar eliminado', () {
      expect(() => aplicar(conAliado(), 0, 3, EstadoDelJefe.veneno),
          throwsA(isA<ReglaIncumplida>()));
      expect(() => aplicar(conAliado(), 7, 1, EstadoDelJefe.veneno),
          throwsA(isA<ReglaIncumplida>()));
      expect(() => aplicar(configurar([100]), 0, 0, EstadoDelJefe.veneno),
          throwsA(isA<ReglaIncumplida>()));
    });
  });

  group('chequeo al cerrar el turno del jefe', () {
    test('el veneno quita 10 y es permanente', () {
      var s = aplicar(conAliado(), 1, 1, EstadoDelJefe.veneno);
      s = cerrar(s);
      expect(s.aliadoEn(1)!.hp, 50);
      expect(s.aliadoEn(1)!.envenenado, isTrue);
      s = cerrar(s);
      expect(s.aliadoEn(1)!.hp, 40);
    });

    test('la quemadura quita 20 y con cruz se mantiene', () {
      var s = aplicar(conAliado(), 1, 1, EstadoDelJefe.quemadura);
      s = cerrar(s, monedaCruz);
      expect(s.aliadoEn(1)!.hp, 40);
      expect(s.aliadoEn(1)!.quemado, isTrue);
    });

    test('la quemadura con cara se quita después de aplicar su daño', () {
      var s = aplicar(conAliado(), 1, 1, EstadoDelJefe.quemadura);
      s = cerrar(s, monedaCara);
      expect(s.aliadoEn(1)!.hp, 40);
      expect(s.aliadoEn(1)!.quemado, isFalse);
    });

    test('veneno y quemadura juntos quitan 30', () {
      var s = aplicar(conAliado(), 1, 1, EstadoDelJefe.veneno);
      s = aplicar(s, 2, 1, EstadoDelJefe.quemadura);
      s = cerrar(s, monedaCruz);
      expect(s.aliadoEn(1)!.hp, 30);
    });

    test('un aliado sin estados no pierde vida y no hace falta moneda', () {
      final s = cerrar(conAliado());
      expect(s.aliadoEn(1)!.hp, 60);
    });

    test('un aliado a 0 HP sale de la mesa y su slot queda libre', () {
      var s = aplicar(conAliado(hp: 25), 1, 1, EstadoDelJefe.veneno);
      s = aplicar(s, 2, 1, EstadoDelJefe.quemadura);
      s = cerrar(s, monedaCara);
      expect(s.aliadoEn(1), isNull);
      expect(s.aliadosDerrotados, 1);
      expect(s.slotsLibres, contains(1));
    });

    test('el daño de los estados del aliado no se atribuye ni baja al jefe', () {
      final s = aplicar(conAliado(), 1, 1, EstadoDelJefe.veneno);
      final antes = todosActuan(s);
      final despues = apply(antes, const FinTurnoJefe());
      expect(despues.danoPorJugador, antes.danoPorJugador);
      expect(despues.danoEstados, antes.danoEstados);
      expect(despues.jefe!.hp, antes.jefe!.hp);
    });

    test('falta o sobra la moneda de un aliado quemado', () {
      final s = aplicar(conAliado(), 1, 1, EstadoDelJefe.quemadura);
      expect(() => cerrar(s), throwsA(isA<ReglaIncumplida>()));
      expect(() => cerrar(conAliado(), monedaCara),
          throwsA(isA<ReglaIncumplida>()));
      expect(
        () => cerrar(
          s,
          const FinTurnoJefe(monedasQuemaduraAliados: [
            MonedaQuemaduraAliado(slot: 1, cara: false),
            MonedaQuemaduraAliado(slot: 1, cara: true),
          ]),
        ),
        throwsA(isA<ReglaIncumplida>()),
      );
    });

    test('el aliado nuevo en un slot libre no hereda los estados', () {
      var s = aplicar(conAliado(hp: 5), 1, 1, EstadoDelJefe.veneno);
      s = cerrar(s);
      expect(s.aliadoEn(1), isNull);
      s = conIntentos(s, 1);
      s = apply(s, rattata());
      expect(s.aliadoEn(1)!.envenenado, isFalse);
    });
  });

  group('Velo Sagrado (D-17)', () {
    test('quita los estados de los aliados al entrar y bloquea los nuevos', () {
      var s = aplicar(conAliado(), 1, 1, EstadoDelJefe.veneno);
      s = conIntentos(s, 1);
      s = apply(s, velo());
      expect(s.aliadoEn(1)!.envenenado, isFalse);
      expect(s.aliadoEn(1)!.quemado, isFalse);
      expect(() => aplicar(s, 2, 1, EstadoDelJefe.quemadura),
          throwsA(isA<ReglaIncumplida>()));
      // La aplicación ya contada se conserva para el bono.
      expect(s.estadosAplicados[1], 1);
    });
  });

  group('bono de estados', () {
    test('las aplicaciones a aliados cuentan junto a las del jefe', () {
      var s = aplicar(conAliado(), 1, 1, EstadoDelJefe.veneno);
      s = apply(s,
          const AplicarEstadoJefe(jugador: 1, estado: EstadoDelJefe.veneno));
      expect(s.estadosAplicados[1], 2);
    });
  });
}
