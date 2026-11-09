import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

/// Scripts de los aliados de Arceus (D-16): Bloqueo, Deseo, Envite Ígneo y
/// Fuerza Lunar. Sin bloqueo de slot: el dueño puede ignorar a su aliado.
void main() {
  /// Con 1300 de daño se cruzan dos umbrales (3000 y 2400): dos intentos.
  EstadoPartida conJefe({int dano = 1300}) {
    final s0 = configurar(const [100, 100, 100]);
    var s = apply(
      s0,
      ElegirJefe(nombre: 'Arceus', nivel: s0.nivel, hp: 3600, invocacionCadaHp: 600),
    );
    return apply(s, TurnoJugador(jugador: 0, dano: dano));
  }

  /// Descarta los intentos de invocación que quedan (no se invoca nada) para
  /// poder seguir con los turnos.
  EstadoPartida limpia(EstadoPartida s) {
    while (s.intentosInvocacionPendientes > 0) {
      s = apply(s, const SinInvocacion());
    }
    return s;
  }

  EstadoPartida act(EstadoPartida s, Evento ev) => apply(limpia(s), ev);

  AliadoInvocado aliado(
    CategoriaAliado c,
    String id, {
    int slot = 1,
    int hp = 100,
    int? ataque,
    List<bool>? monedas,
  }) =>
      AliadoInvocado(
        slot: slot,
        categoria: c,
        nombre: id,
        hp: hp,
        ataqueDano: ataque,
        efectos: EfectosAliado.programa,
        scriptId: id,
        monedas: monedas,
      );

  test('el dueño puede ignorar a su aliado y dañar al jefe', () {
    var s = apply(conJefe(), aliado(CategoriaAliado.cura, 'chupavidas-10'));
    final hp0 = s.jefe!.hp;
    s = act(s, const TurnoJugador(jugador: 1, dano: 100));
    expect(s.jefe!.hp, hp0 - 100);
    expect(s.aliadoEn(1), isNotNull);
  });

  group('Bloqueo (Bronzong)', () {
    EstadoPartida conBronzong() =>
        apply(conJefe(), aliado(CategoriaAliado.tanque, 'bloqueo-100', slot: 2));

    test('obliga a atacarle: dañar al jefe se rechaza, pasar el turno no', () {
      final s = conBronzong();
      expect(() => act(s, const TurnoJugador(jugador: 1, dano: 50)),
          throwsA(isA<ReglaIncumplida>()));
      final pasa = act(s, const TurnoJugador(jugador: 1, dano: 0));
      expect(pasa.jugadorActual, 2);
    });

    test('solo se puede atacar a Bronzong mientras viva', () {
      var s = conBronzong();
      s = apply(s, aliado(CategoriaAliado.cura, 'chupavidas-10', slot: 1));
      expect(
        () => act(s, const AtaqueAAliado(jugador: 1, slot: 1, dano: 50)),
        throwsA(isA<ReglaIncumplida>()),
      );
    });

    test('recibe 100 de daño menos de cada ataque', () {
      var s = conBronzong();
      s = act(s, const AtaqueAAliado(jugador: 1, slot: 2, dano: 150));
      expect(s.aliadoEn(2)!.hp, 50);
      s = act(s, const AtaqueAAliado(jugador: 2, slot: 2, dano: 90));
      expect(s.aliadoEn(2)!.hp, 50);
    });

    test('al caer, vuelve a poderse dañar al jefe', () {
      var s = conBronzong();
      s = act(s, const AtaqueAAliado(jugador: 1, slot: 2, dano: 300));
      expect(s.aliadoEn(2), isNull);
      final hp0 = s.jefe!.hp;
      s = act(s, const TurnoJugador(jugador: 2, dano: 60));
      expect(s.jefe!.hp, hp0 - 60);
    });
  });

  group('Deseo (Chingling)', () {
    List<bool> monedas(int caras, int aliados) => [
          for (var i = 0; i < 10; i++) i < caras,
          for (var i = 0; i < aliados; i++) i.isEven,
        ];

    test('el jefe se cura 100 por cada cara de las 10 primeras', () {
      var s = conJefe();
      final hp0 = s.jefe!.hp;
      s = apply(
        s,
        aliado(CategoriaAliado.cura, 'deseo-100', monedas: monedas(4, 1)),
      );
      expect(s.jefe!.hp, hp0 + 400);
    });

    test('no pasa del máximo del jefe', () {
      var s = conJefe(dano: 700);
      s = apply(
        s,
        aliado(CategoriaAliado.cura, 'deseo-100', monedas: monedas(10, 1)),
      );
      expect(s.jefe!.hp, 3600);
    });

    test('cada aliado con cara se cura 100 sin pasar de su máximo', () {
      var s = conJefe(dano: 700);
      // Un aliado sin script, para que no haya reducciones de daño.
      s = apply(
        s,
        const AliadoInvocado(
          slot: 2,
          categoria: CategoriaAliado.control,
          nombre: 'Control',
          hp: 300,
        ),
      );
      s = act(s, const AtaqueAAliado(jugador: 1, slot: 2, dano: 200));
      expect(s.aliadoEn(2)!.hp, 100);
      // Otro golpe del jefe cruza el siguiente umbral: nuevo intento.
      s = apply(s, const TurnoJugador(jugador: 2, dano: 700));
      // Aliados en orden: Control (cara) y Chingling (cruz).
      s = apply(
        s,
        aliado(
          CategoriaAliado.cura,
          'deseo-100',
          slot: 1,
          hp: 50,
          monedas: [...List.filled(10, false), true, false],
        ),
      );
      expect(s.aliadoEn(2)!.hp, 200);
      expect(s.aliadoEn(1)!.hp, 50);
    });

    test('exige 10 monedas más una por aliado, incluido el que entra', () {
      expect(
        () => apply(conJefe(), aliado(CategoriaAliado.cura, 'deseo-100')),
        throwsA(isA<ReglaIncumplida>()),
      );
      expect(
        () => apply(
          conJefe(),
          aliado(CategoriaAliado.cura, 'deseo-100', monedas: monedas(3, 0)),
        ),
        throwsA(isA<ReglaIncumplida>()),
      );
    });
  });

  test('Envite Ígneo suma 10 HP máximos y actuales en cada uso', () {
    var s = apply(
      conJefe(),
      aliado(CategoriaAliado.potenciador, 'envite-igneo-10', hp: 70, ataque: 10),
    );
    expect(s.aliadoEn(1)!.hpMaximo, 70);
    s = apply(s, const AtaqueAliado(slot: 1, dano: 10));
    expect(s.aliadoEn(1)!.usos, 1);
    expect(s.aliadoEn(1)!.hpMaximo, 80);
    expect(s.aliadoEn(1)!.hp, 80);
    s = todosActuan(limpia(s), dano: 0);
    s = apply(s, const AtaqueAliado(slot: 1, dano: 20));
    expect(s.aliadoEn(1)!.usos, 2);
    expect(s.aliadoEn(1)!.hpMaximo, 90);
    expect(s.aliadoEn(1)!.hp, 90);
  });

  group('Fuerza Lunar (Lunatone)', () {
    EstadoPartida lunatone() => apply(
          conJefe(),
          aliado(CategoriaAliado.debilitador, 'fuerza-lunar-30', ataque: 10),
        );

    test('exige el resultado de la moneda', () {
      expect(() => apply(lunatone(), const AtaqueAliado(slot: 1, dano: 10)),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('con cruz, el siguiente ataque del rival hace 30 menos y se consume', () {
      var s = lunatone();
      s = apply(s, const AtaqueAliado(slot: 1, dano: 10, moneda: false));
      expect(s.debilitados[1], 30);
      final hp0 = s.jefe!.hp;
      s = act(s, const TurnoJugador(jugador: 1, dano: 100));
      expect(s.jefe!.hp, hp0 - 70);
      expect(s.debilitados, isEmpty);
    });

    test('con cara no pasa nada', () {
      var s = lunatone();
      s = apply(s, const AtaqueAliado(slot: 1, dano: 10, moneda: true));
      expect(s.debilitados, isEmpty);
    });
  });
}
