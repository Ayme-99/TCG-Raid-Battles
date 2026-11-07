import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

// Aliados de prueba (propuestas de D-04 §7.5, sin definir en el catálogo).
AliadoInvocado rattata(
  int slot, {
  CategoriaAliado categoria = CategoriaAliado.danio,
}) =>
    AliadoInvocado(
      slot: slot,
      categoria: categoria,
      nombre: 'Rattata',
      hp: 60,
      ataqueNombre: 'Placaje',
      ataqueDano: 20,
    );

AliadoInvocado wobbuffet(int slot) => AliadoInvocado(
      slot: slot,
      categoria: CategoriaAliado.tanque,
      nombre: 'Wobbuffet',
      hp: 110,
      habilidad: 'Contraataque (pasiva)',
    );

AliadoInvocado cleffairy(int slot) => AliadoInvocado(
      slot: slot,
      categoria: CategoriaAliado.cura,
      nombre: 'Cleffairy',
      hp: 80,
      habilidad: 'Deseo: cura al final del turno del jefe',
    );

/// Jefe de 3000 HP con un intento cada 600 HP perdidos, 3 jugadores.
EstadoPartida palkia({int cada = 600, int hp = 3000}) {
  final s = configurar(const [100, 100, 100]);
  return apply(
    s,
    ElegirJefe(nombre: 'Palkia', nivel: s.nivel, hp: hp, invocacionCadaHp: cada),
  );
}

/// El jugador 0 baja a Palkia a 2400 y salta el primer intento.
EstadoPartida conIntento() =>
    apply(palkia(), const TurnoJugador(jugador: 0, dano: 600));

// Efectos de aliado de prueba (D-13). Son funciones de nivel superior para
// poder usarlas en un mapa `const`.

/// El jefe se cura 50 (sin pasar de su máximo).
EstadoPartida curaDe50(EstadoPartida e, AliadoEstado aliado) {
  final jefe = e.jefe!;
  final falta = jefe.hpMaximo - jefe.hp;
  final sube = falta < 50 ? falta : 50;
  return e.copiarCon(
    jefe: jefe.conHp(jefe.hp + sube),
    curacionJefe: e.curacionJefe + sube,
  );
}

/// Termina la partida: un script no puede hacerlo.
EstadoPartida mataAlJefe(EstadoPartida e, AliadoEstado aliado) =>
    e.copiarCon(fase: Fase.terminada, resultado: Resultado.victoria);

const scriptsDePrueba = {
  'cura-al-final': ScriptAliado(alFinTurnoJefe: curaDe50),
  'cura-al-entrar': ScriptAliado(alEntrar: curaDe50),
  'termina': ScriptAliado(alEntrar: mataAlJefe),
};

void main() {
  group('umbrales de invocación', () {
    test('sin cruzar el umbral no hay intento', () {
      final s = apply(palkia(), const TurnoJugador(jugador: 0, dano: 599));
      expect(s.intentosInvocacionPendientes, 0);
      expect(s.umbralesCruzados, 0);
    });

    test('llegar justo al umbral cuenta como cruzarlo', () {
      final s = conIntento();
      expect(s.jefe!.hp, 2400);
      expect(s.intentosInvocacionPendientes, 1);
      expect(s.umbralesCruzados, 1);
    });

    test('un golpe de 1200 cruza dos umbrales: dos intentos', () {
      final s = apply(palkia(), const TurnoJugador(jugador: 0, dano: 1200));
      expect(s.intentosInvocacionPendientes, 2);
    });

    test('como mucho cuatro intentos con 3000 HP y umbral de 600', () {
      final s = apply(palkia(), const TurnoJugador(jugador: 0, dano: 2900));
      expect(s.intentosInvocacionPendientes, 4);
    });

    test('un jefe sin umbral nunca invoca', () {
      final s = apply(empezar(hp: 3000), const TurnoJugador(jugador: 0, dano: 2000));
      expect(s.intentosInvocacionPendientes, 0);
    });

    test('cada umbral cuenta una sola vez aunque el jefe se cure', () {
      var s = conIntento();
      s = apply(s, const SinInvocacion());
      s = apply(s, const CuracionJefe(600));
      expect(s.jefe!.hp, 3000);
      s = apply(s, const TurnoJugador(jugador: 1, dano: 600));
      expect(s.intentosInvocacionPendientes, 0);
      expect(s.umbralesCruzados, 1);
    });

    test('el golpe que mata al jefe no genera intentos', () {
      final s = apply(
        apply(
          configurar(const [100]),
          const ElegirJefe(nombre: 'J', nivel: 1, hp: 100, invocacionCadaHp: 50),
        ),
        const TurnoJugador(jugador: 0, dano: 100),
      );
      expect(s.resultado, Resultado.victoria);
      expect(s.intentosInvocacionPendientes, 0);
    });

    test('los HP entre intentos deben ser mayores que 0', () {
      final s = configurar(const [100]);
      expect(
        () => apply(s, ElegirJefe(nombre: 'J', nivel: s.nivel, hp: 100, invocacionCadaHp: 0)),
        throwsA(isA<ReglaIncumplida>()),
      );
    });

    test('hay que resolver los intentos antes de seguir', () {
      final s = conIntento();
      expect(() => apply(s, const TurnoJugador(jugador: 1, dano: 10)),
          throwsA(isA<ReglaIncumplida>()));
      expect(
          () => apply(s, const AtaqueAAliado(jugador: 1, slot: 0, dano: 1)),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('SinInvocacion consume un intento y sigue la partida', () {
      var s = conIntento();
      s = apply(s, const SinInvocacion());
      expect(s.intentosInvocacionPendientes, 0);
      expect(s.jugadorActual, 1);
      expect(s.aliados, isEmpty);
    });

    test('sin intentos pendientes no se puede resolver nada', () {
      final s = palkia();
      expect(() => apply(s, const SinInvocacion()),
          throwsA(isA<ReglaIncumplida>()));
      expect(() => apply(s, rattata(1)), throwsA(isA<ReglaIncumplida>()));
    });
  });

  group('invocar', () {
    test('el aliado entra en el slot de un jugador que aún no ha actuado', () {
      var s = apply(conIntento(), rattata(1));
      expect(s.intentosInvocacionPendientes, 0);
      expect(s.aliadoEn(1)!.nombre, 'Rattata');
      expect(s.aliadoEn(1)!.hp, 60);
      expect(s.estaBloqueado(1), isTrue);
      expect(s.slotsLibres, [0, 2]);
      expect(s.aliadoEn(0), isNull);
    });

    test('el slot debe existir, estar libre y ser de un jugador activo', () {
      var s = conIntento();
      expect(() => apply(s, rattata(7)), throwsA(isA<ReglaIncumplida>()));
      s = apply(s, wobbuffet(0));
      s = apply(
        palkia(),
        const TurnoJugador(jugador: 0, dano: 1200),
      );
      s = apply(s, rattata(2));
      expect(() => apply(s, cleffairy(2)), throwsA(isA<ReglaIncumplida>()));

      var e = conIntento();
      e = aplicarTodos(e, const [PokemonKo(2), PokemonKo(2)]);
      expect(() => apply(e, rattata(2)), throwsA(isA<ReglaIncumplida>()));
    });

    test('el aliado necesita vida', () {
      expect(
        () => apply(
          conIntento(),
          const AliadoInvocado(
            slot: 1,
            categoria: CategoriaAliado.danio,
            nombre: 'X',
            hp: 0,
          ),
        ),
        throwsA(isA<ReglaIncumplida>()),
      );
    });

    test('dos intentos seguidos pueden dar dos aliados distintos', () {
      var s = apply(palkia(), const TurnoJugador(jugador: 0, dano: 1200));
      s = apply(s, rattata(1));
      s = apply(s, wobbuffet(2));
      expect(s.aliados.map((a) => a.slot), [1, 2]);
      expect(s.slotsLibres, [0]);
    });

    test('con los slots ocupados los intentos se pierden', () {
      var s = apply(palkia(), const TurnoJugador(jugador: 0, dano: 1800));
      s = apply(s, rattata(0));
      s = apply(s, rattata(1, categoria: CategoriaAliado.tanque));
      s = apply(s, rattata(2, categoria: CategoriaAliado.cura));
      expect(s.slotsLibres, isEmpty);
      expect(s.intentosInvocacionPendientes, 0);
    });
  });

  group('entrada del aliado', () {
    test('un aliado con ataque debe usarlo al entrar antes de seguir', () {
      var s = apply(conIntento(), rattata(1));
      expect(() => apply(s, const TurnoJugador(jugador: 1, dano: 0)),
          throwsA(isA<ReglaIncumplida>()));
      s = apply(s, const AtaqueAliado(slot: 1, dano: 20));
      expect(s.aliadoEn(1)!.entradaResuelta, isTrue);
      expect(() => apply(s, const TurnoJugador(jugador: 1, dano: 0)),
          returnsNormally);
    });

    test('un aliado sin ataque no tiene ataque de entrada', () {
      final s = apply(conIntento(), wobbuffet(1));
      expect(s.entradasPendientes, isEmpty);
      expect(() => apply(s, const AtaqueAliado(slot: 1, dano: 5)),
          throwsA(isA<ReglaIncumplida>()));
      expect(() => apply(apply(conIntento(), cleffairy(2)), const TurnoJugador(jugador: 1, dano: 5)),
          returnsNormally);
    });

    test('ataca al dueño del slot salvo que se indique otro jugador', () {
      final s = apply(conIntento(), rattata(1));
      expect(() => apply(s, const AtaqueAliado(slot: 1, dano: 20, objetivo: 2)),
          returnsNormally);
      expect(() => apply(s, const AtaqueAliado(slot: 1, dano: 20, objetivo: 9)),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('no ataca más durante el turno de jugadores', () {
      var s = apply(conIntento(), rattata(1));
      s = apply(s, const AtaqueAliado(slot: 1, dano: 20));
      expect(() => apply(s, const AtaqueAliado(slot: 1, dano: 20)),
          throwsA(isA<ReglaIncumplida>()));
    });
  });

  group('bloqueo y ataques a aliados', () {
    EstadoPartida conRattataEnJ1() {
      var s = apply(conIntento(), rattata(1));
      return apply(s, const AtaqueAliado(slot: 1, dano: 20));
    }

    test('el dueño no puede dañar al jefe hasta debilitar a su aliado', () {
      final s = conRattataEnJ1();
      expect(() => apply(s, const TurnoJugador(jugador: 1, dano: 100)),
          throwsA(isA<ReglaIncumplida>()));
      final pasa = apply(s, const TurnoJugador(jugador: 1, dano: 0));
      expect(pasa.jefe!.hp, 2400);
      expect(pasa.jugadorActual, 2);
    });

    test('el resto de jugadores sigue dañando al jefe', () {
      var s = conRattataEnJ1();
      s = apply(s, const TurnoJugador(jugador: 1, dano: 0));
      s = apply(s, const TurnoJugador(jugador: 2, dano: 100));
      expect(s.jefe!.hp, 2300);
    });

    test('atacar al aliado gasta el turno y no daña al jefe', () {
      var s = conRattataEnJ1();
      s = apply(s, const AtaqueAAliado(jugador: 1, slot: 1, dano: 40));
      expect(s.aliadoEn(1)!.hp, 20);
      expect(s.jefe!.hp, 2400);
      expect(s.danoPorJugador, [600, 0, 0]);
      expect(s.jugadorActual, 2);
    });

    test('al derrotarlo el slot queda libre y el exceso se pierde', () {
      var s = conRattataEnJ1();
      s = apply(s, const AtaqueAAliado(jugador: 1, slot: 1, dano: 500));
      expect(s.aliadoEn(1), isNull);
      expect(s.aliadosDerrotados, 1);
      expect(s.jefe!.hp, 2400);
      expect(s.estaBloqueado(1), isFalse);
      expect(s.slotsLibres, [0, 1, 2]);
    });

    test('cualquier jugador puede atacar al aliado de otro', () {
      var s = conRattataEnJ1();
      s = apply(s, const TurnoJugador(jugador: 1, dano: 0));
      s = apply(s, const AtaqueAAliado(jugador: 2, slot: 1, dano: 60));
      expect(s.aliados, isEmpty);
    });

    test('un compañero puede liberar al bloqueado antes de que actúe', () {
      // Palkia cae a 1200 y entra un aliado en el slot 2, que aún no ha actuado.
      var s = apply(palkia(), const TurnoJugador(jugador: 0, dano: 1200));
      s = apply(s, const SinInvocacion());
      s = apply(s, rattata(2));
      s = apply(s, const AtaqueAliado(slot: 2, dano: 20));
      s = apply(s, const AtaqueAAliado(jugador: 1, slot: 2, dano: 60));
      expect(s.aliados, isEmpty);
      s = apply(s, const TurnoJugador(jugador: 2, dano: 50));
      expect(s.jefe!.hp, 1750);
    });

    test('fuera de turno, sin aliado o con daño negativo se rechaza', () {
      final s = conRattataEnJ1();
      expect(() => apply(s, const AtaqueAAliado(jugador: 2, slot: 1, dano: 5)),
          throwsA(isA<ReglaIncumplida>()));
      expect(() => apply(s, const AtaqueAAliado(jugador: 1, slot: 0, dano: 5)),
          throwsA(isA<ReglaIncumplida>()));
      expect(() => apply(s, const AtaqueAAliado(jugador: 1, slot: 1, dano: -1)),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('el daño a aliados no cuenta para los puntos', () {
      var s = conRattataEnJ1();
      s = apply(s, const AtaqueAAliado(jugador: 1, slot: 1, dano: 60));
      s = apply(s, const Abandonar());
      final p = calcularPuntos(s);
      expect(p.danoTotal, 600);
      expect(p.jugadores.firstWhere((j) => j.asiento == 1).dano, 0);
    });
  });

  group('turno del jefe', () {
    EstadoPartida hastaTurnoDelJefe() {
      var s = apply(conIntento(), rattata(2));
      s = apply(s, const AtaqueAliado(slot: 2, dano: 20));
      s = apply(s, const TurnoJugador(jugador: 1, dano: 10));
      return apply(s, const AtaqueAAliado(jugador: 2, slot: 2, dano: 10));
    }

    test('cada aliado ataca una vez al final del turno del jefe', () {
      var s = hastaTurnoDelJefe();
      expect(s.fase, Fase.turnoJefe);
      s = apply(s, const AtaqueJefe(ranura: 1, dano: 80));
      s = apply(s, const AtaqueAliado(slot: 2, dano: 20));
      expect(() => apply(s, const AtaqueAliado(slot: 2, dano: 20)),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('en la ronda siguiente vuelve a poder atacar', () {
      var s = hastaTurnoDelJefe();
      s = apply(s, const AtaqueAliado(slot: 2, dano: 20));
      s = apply(s, const FinTurnoJefe());
      expect(s.ronda, 2);
      s = todosActuan(s, dano: 0);
      expect(() => apply(s, const AtaqueAliado(slot: 2, dano: 20)),
          returnsNormally);
    });

    test('un aliado vivo puede quedar sin atacar si la mesa no lo registra', () {
      final s = hastaTurnoDelJefe();
      expect(() => apply(s, const FinTurnoJefe()), returnsNormally);
    });
  });

  group('dueño eliminado', () {
    EstadoPartida conRattataEnJ1Eliminado() {
      var s = apply(conIntento(), rattata(1));
      s = apply(s, const AtaqueAliado(slot: 1, dano: 20));
      s = aplicarTodos(s, const [PokemonKo(1), PokemonKo(1)]);
      return s;
    }

    test('el aliado sigue vivo y su slot no admite aliados nuevos', () {
      final s = conRattataEnJ1Eliminado();
      expect(s.aliadoEn(1), isNotNull);
      expect(s.slotsLibres, [0, 2]);
      expect(s.jugadorActual, 2);
    });

    test('sigue atacando contra un jugador activo elegido por la tirada', () {
      var s = todosActuan(conRattataEnJ1Eliminado(), dano: 0);
      expect(() => apply(s, const AtaqueAliado(slot: 1, dano: 20)),
          throwsA(isA<ReglaIncumplida>()));
      expect(() => apply(s, const AtaqueAliado(slot: 1, dano: 20, objetivo: 1)),
          throwsA(isA<ReglaIncumplida>()));
      s = apply(s, const AtaqueAliado(slot: 1, dano: 20, objetivo: 0));
      expect(s.aliadoEn(1)!.atacoEnTurnoJefe, isTrue);
    });

    test('cualquier jugador activo puede atacarlo', () {
      var s = conRattataEnJ1Eliminado();
      s = apply(s, const AtaqueAAliado(jugador: 2, slot: 1, dano: 60));
      expect(s.aliados, isEmpty);
    });
  });

  group('curanderos', () {
    test('un aliado curandero se combina con la curación del jefe', () {
      var s = apply(conIntento(), cleffairy(1));
      s = todosActuan(s, dano: 0);
      s = apply(s, const CuracionJefe(100));
      expect(s.jefe!.hp, 2500);
      expect(s.curacionJefe, 100);
      expect(s.aliadoEn(1)!.nombre, 'Cleffairy');
    });
  });

  group('categorías de aliado (D-13)', () {
    // Dos intentos de golpe: Palkia baja a 1800.
    EstadoPartida dosIntentos() =>
        apply(palkia(), const TurnoJugador(jugador: 0, dano: 1200));

    test('al principio están libres las cuatro categorías', () {
      expect(conIntento().categoriasLibres, CategoriaAliado.values);
    });

    test('no puede haber dos aliados de la misma categoría', () {
      var s = apply(dosIntentos(), rattata(1));
      expect(s.categoriasLibres, [
        CategoriaAliado.tanque,
        CategoriaAliado.cura,
        CategoriaAliado.picaro,
      ]);
      expect(() => apply(s, rattata(2)), throwsA(isA<ReglaIncumplida>()));
      s = apply(s, wobbuffet(2));
      expect(s.aliados.map((a) => a.categoria),
          [CategoriaAliado.danio, CategoriaAliado.tanque]);
    });

    test('al caer un aliado su categoría vuelve a estar libre', () {
      var s = apply(dosIntentos(), rattata(1));
      s = apply(s, const SinInvocacion());
      s = apply(s, const AtaqueAliado(slot: 1, dano: 20));
      s = apply(s, const AtaqueAAliado(jugador: 1, slot: 1, dano: 60));
      expect(s.aliados, isEmpty);
      expect(s.categoriasLibres, CategoriaAliado.values);
    });

    test('el aliado guarda su categoría', () {
      final s = apply(conIntento(), cleffairy(1));
      expect(s.aliadoEn(1)!.categoria, CategoriaAliado.cura);
    });
  });

  group('efectos de aliados (D-13)', () {
    AliadoInvocado chansey(int slot, {String? scriptId, EfectosAliado? efectos}) =>
        AliadoInvocado(
          slot: slot,
          categoria: CategoriaAliado.cura,
          nombre: 'Chansey',
          hp: 120,
          efectos: efectos ?? EfectosAliado.programa,
          scriptId: scriptId,
        );

    test('el programa ejecuta el efecto al final del turno del jefe', () {
      var s = apply(conIntento(), chansey(1, scriptId: 'cura-al-final'),
          scripts: scriptsDePrueba);
      expect(s.jefe!.hp, 2400);
      s = todosActuan(s, dano: 0);
      s = apply(s, const FinTurnoJefe(), scripts: scriptsDePrueba);
      expect(s.jefe!.hp, 2450);
      expect(s.curacionJefe, 50);
    });

    test('el programa ejecuta el efecto al entrar', () {
      final s = apply(conIntento(), chansey(1, scriptId: 'cura-al-entrar'),
          scripts: scriptsDePrueba);
      expect(s.jefe!.hp, 2450);
    });

    test('con efectos del jugador el programa no hace nada', () {
      var s = apply(conIntento(), chansey(1, efectos: EfectosAliado.jugador));
      s = todosActuan(s, dano: 0);
      s = apply(s, const FinTurnoJefe(), scripts: scriptsDePrueba);
      expect(s.jefe!.hp, 2400);
    });

    test('un script que no existe se rechaza', () {
      expect(
        () => apply(conIntento(), chansey(1, scriptId: 'no-existe'),
            scripts: scriptsDePrueba),
        throwsA(isA<ReglaIncumplida>()),
      );
      // El catálogo de scripts de verdad está vacío por ahora.
      expect(
        () => apply(conIntento(), chansey(1, scriptId: 'cura-al-final')),
        throwsA(isA<ReglaIncumplida>()),
      );
    });

    test('efectos del programa sin scriptId se rechazan', () {
      expect(
        () => apply(conIntento(), chansey(1), scripts: scriptsDePrueba),
        throwsA(isA<ReglaIncumplida>()),
      );
    });

    test('efectos del jugador con scriptId se rechazan', () {
      expect(
        () => apply(
          conIntento(),
          chansey(1, scriptId: 'cura-al-final', efectos: EfectosAliado.jugador),
          scripts: scriptsDePrueba,
        ),
        throwsA(isA<ReglaIncumplida>()),
      );
    });

    test('un script no puede terminar la partida', () {
      expect(
        () => apply(conIntento(), chansey(1, scriptId: 'termina'),
            scripts: scriptsDePrueba),
        throwsA(isA<ReglaIncumplida>()),
      );
    });
  });
}
