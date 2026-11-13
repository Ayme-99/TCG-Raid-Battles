import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

/// Efectos en los ataques del jefe (D-14).
void main() {
  /// Turno del jefe con 3 jugadores y un jefe de [hp] HP.
  EstadoPartida turnoJefe({int hp = 1000, int? cadaHp}) {
    final s = configurar([100, 100, 100]);
    final conJefe = apply(
      s,
      ElegirJefe(
        nombre: 'Jefe',
        nivel: s.nivel,
        hp: hp,
        invocacionCadaHp: cadaHp,
      ),
    );
    return todosActuan(conJefe);
  }

  AtaqueJefe ataque(EfectoAtaque? efecto, {int? jugador = 0, int dano = 30}) =>
      AtaqueJefe(ranura: 1, dano: dano, jugador: jugador, efecto: efecto);

  group('autodaño', () {
    test('baja el HP del jefe sin atribuirlo a ningún jugador', () {
      final s = turnoJefe();
      final antes = s.jefe!.hp;
      final n = apply(
        s,
        ataque(const EfectoAtaque(tipo: TipoEfectoAtaque.autodano, valor: 30)),
      );
      expect(n.jefe!.hp, antes - 30);
      expect(n.danoEstados, s.danoEstados + 30);
      expect(n.danoPorJugador, s.danoPorJugador);
      expect(n.ataquesJefeEnTurno, 1);
    });

    test('a 0 HP termina la partida en victoria', () {
      final s = turnoJefe(hp: 200);
      final n = apply(
        s,
        ataque(const EfectoAtaque(tipo: TipoEfectoAtaque.autodano, valor: 500)),
      );
      expect(n.jefe!.hp, 0);
      expect(n.fase, Fase.terminada);
      expect(n.resultado, Resultado.victoria);
    });

    test('en la ronda 1 perder HP no genera intentos de invocación', () {
      final s = turnoJefe(cadaHp: 500);
      expect(s.intentosInvocacionPendientes, 0);
      final n = apply(
        s,
        ataque(const EfectoAtaque(tipo: TipoEfectoAtaque.autodano, valor: 510)),
      );
      expect(n.intentosInvocacionPendientes, 0);
    });

    test('desde la ronda 2 puede cruzar un umbral de invocación', () {
      var s = apply(turnoJefe(cadaHp: 500), const FinTurnoJefe());
      expect(s.intentosInvocacionPendientes, 1); // la primera llamada
      s = apply(s, const SinInvocacion());
      s = todosActuan(s);
      expect(s.intentosInvocacionPendientes, 0);
      final n = apply(
        s,
        ataque(const EfectoAtaque(tipo: TipoEfectoAtaque.autodano, valor: 510)),
      );
      expect(n.intentosInvocacionPendientes, 1);
    });
  });

  group('contador a todos', () {
    /// Turno del jefe con un aliado de 50 HP en el slot 0.
    EstadoPartida conAliado() {
      var s = configurar([100, 100, 100]);
      s = apply(
        s,
        ElegirJefe(nombre: 'Jefe', nivel: s.nivel, hp: 1000, invocacionCadaHp: 500),
      );
      s = conIntentos(apply(s, const TurnoJugador(jugador: 0, dano: 600)));
      s = apply(
        s,
        const AliadoInvocado(
          slot: 0,
          categoria: CategoriaAliado.danio,
          nombre: 'Aliado',
          hp: 50,
        ),
      );
      return todosActuan(s);
    }

    test('baja 10 HP por contador a cada aliado', () {
      final s = conAliado();
      expect(s.fase, Fase.turnoJefe);
      final n = apply(
        s,
        ataque(const EfectoAtaque(
            tipo: TipoEfectoAtaque.contadorATodos, valor: 3)),
      );
      expect(n.aliados.single.hp, 20);
      expect(n.jefe!.hp, s.jefe!.hp);
    });

    test('un aliado sin HP queda derrotado', () {
      final s = conAliado();
      final n = apply(
        s,
        ataque(const EfectoAtaque(
            tipo: TipoEfectoAtaque.contadorATodos, valor: 5)),
      );
      expect(n.aliados, isEmpty);
      expect(n.aliadosDerrotados, s.aliadosDerrotados + 1);
    });
  });

  group('efectos sobre el Defensor', () {
    const sinRetirada =
        EfectoAtaque(tipo: TipoEfectoAtaque.sinRetirada, duracion: 1);

    test('quedan activos durante el próximo turno de los jugadores', () {
      var s = apply(turnoJefe(), ataque(sinRetirada));
      expect(s.efectosActivos.single.tipo, TipoEfectoAtaque.sinRetirada);
      expect(s.efectosActivos.single.jugador, 0);
      expect(s.efectosActivos.single.restantes, 1);

      s = apply(s, const FinTurnoJefe());
      expect(s.fase, Fase.turnoJugadores);
      expect(s.efectosActivos, hasLength(1));

      s = todosActuan(s);
      expect(s.fase, Fase.turnoJefe);
      expect(s.efectosActivos, isEmpty);
    });

    test('con duración 2 duran un turno más', () {
      var s = apply(
        turnoJefe(),
        ataque(const EfectoAtaque(
            tipo: TipoEfectoAtaque.sinAtaque, duracion: 2)),
      );
      s = todosActuan(apply(s, const FinTurnoJefe()));
      expect(s.efectosActivos.single.restantes, 1);
    });

    test('repetir el mismo efecto sobre el mismo jugador lo renueva', () {
      var s = apply(
        turnoJefe(),
        ataque(const EfectoAtaque(
            tipo: TipoEfectoAtaque.sinAtaque, duracion: 1)),
      );
      s = apply(
        s,
        ataque(const EfectoAtaque(
            tipo: TipoEfectoAtaque.sinAtaque, duracion: 3)),
      );
      expect(s.efectosActivos, hasLength(1));
      expect(s.efectosActivos.single.restantes, 3);
    });

    test('los efectos distintos conviven', () {
      var s = apply(turnoJefe(), ataque(sinRetirada));
      s = apply(
        s,
        ataque(const EfectoAtaque(tipo: TipoEfectoAtaque.sinAtaque)),
      );
      expect(s.efectosActivos, hasLength(2));
    });

    test('el mismo efecto sobre otro jugador es otro efecto', () {
      var s = apply(turnoJefe(), ataque(sinRetirada));
      s = apply(s, ataque(sinRetirada, jugador: 1));
      expect(s.efectosActivos, hasLength(2));
    });

    test('la parálisis solo se aplica si la moneda sale cara', () {
      final turno = turnoJefe();
      final cruz = apply(
        turno,
        ataque(const EfectoAtaque(
            tipo: TipoEfectoAtaque.paralizarDefensor, moneda: false)),
      );
      expect(cruz.efectosActivos, isEmpty);
      expect(cruz.ataquesJefeEnTurno, 1);

      final cara = apply(
        turno,
        ataque(const EfectoAtaque(
            tipo: TipoEfectoAtaque.paralizarDefensor, moneda: true)),
      );
      expect(cara.efectosActivos.single.tipo,
          TipoEfectoAtaque.paralizarDefensor);
    });
  });

  group('efectos que solo se registran', () {
    for (final tipo in [
      TipoEfectoAtaque.ignoraEfectos,
      TipoEfectoAtaque.danoExtraSi,
      TipoEfectoAtaque.danoPorAtaquePrevio,
    ]) {
      test('${tipo.name} no cambia el estado salvo el contador de ataques', () {
        final s = turnoJefe();
        final n = apply(s, ataque(EfectoAtaque(tipo: tipo, valor: 30)));
        expect(n.efectosActivos, isEmpty);
        expect(n.jefe!.hp, s.jefe!.hp);
        expect(n.ataquesJefeEnTurno, 1);
      });
    }

    test('un ataque sin efecto no activa nada', () {
      expect(apply(turnoJefe(), ataque(null)).efectosActivos, isEmpty);
    });
  });

  group('reglas incumplidas', () {
    void rechaza(AtaqueJefe ev) {
      expect(() => apply(turnoJefe(), ev), throwsA(isA<ReglaIncumplida>()));
    }

    test('autodaño y contadores necesitan valor', () {
      rechaza(ataque(const EfectoAtaque(tipo: TipoEfectoAtaque.autodano)));
      rechaza(
          ataque(const EfectoAtaque(tipo: TipoEfectoAtaque.contadorATodos)));
    });

    test('los efectos sobre el Defensor necesitan jugador', () {
      for (final tipo in [
        TipoEfectoAtaque.sinRetirada,
        TipoEfectoAtaque.sinAtaque,
        TipoEfectoAtaque.paralizarDefensor,
      ]) {
        rechaza(ataque(EfectoAtaque(tipo: tipo), jugador: null));
      }
    });

    test('valor y duración deben ser positivos', () {
      rechaza(ataque(
          const EfectoAtaque(tipo: TipoEfectoAtaque.autodano, valor: 0)));
      rechaza(ataque(const EfectoAtaque(
          tipo: TipoEfectoAtaque.sinAtaque, duracion: 0)));
    });
  });
}
