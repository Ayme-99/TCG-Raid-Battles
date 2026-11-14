import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

/// Daño que un efecto hace al jefe o a un aliado (rebote, T-59).
void main() {
  /// Turno del jefe con 3 jugadores y un jefe de [hp] HP.
  EstadoPartida turnoJefe({int hp = 1000}) {
    final s = configurar([100, 100, 100]);
    return todosActuan(
      apply(s, ElegirJefe(nombre: 'Jefe', nivel: s.nivel, hp: hp, invocacionCadaHp: 300)),
    );
  }

  /// Igual, con un aliado Rattata de 60 HP en el slot 1.
  EstadoPartida conAliado() => apply(
        conIntentos(turnoJefe()),
        const AliadoInvocado(
          slot: 1,
          categoria: CategoriaAliado.danio,
          nombre: 'Rattata',
          hp: 60,
          ataqueNombre: 'Placaje',
          ataqueDano: 20,
        ),
      );

  group('rebote al jefe', () {
    test('baja su HP y se atribuye al jugador indicado', () {
      final s = turnoJefe();
      final n = apply(s, const DanoDeEfecto(puntos: 60, jugador: 2));
      expect(n.jefe!.hp, s.jefe!.hp - 60);
      expect(n.danoPorJugador[2], s.danoPorJugador[2] + 60);
      expect(n.danoPorJugador[0], s.danoPorJugador[0]);
      expect(n.danoEstados, s.danoEstados);
    });

    test('el exceso sobre los HP del jefe se pierde y gana el equipo', () {
      final s = turnoJefe(hp: 200);
      final restante = s.jefe!.hp;
      final n = apply(s, DanoDeEfecto(puntos: restante + 500, jugador: 0));
      expect(n.jefe!.hp, 0);
      expect(n.danoPorJugador[0], s.danoPorJugador[0] + restante);
      expect(n.fase, Fase.terminada);
      expect(n.resultado, Resultado.victoria);
    });

    test('también vale en el turno de los jugadores', () {
      final base = configurar([100, 100]);
      final s = apply(base, ElegirJefe(nombre: 'Jefe', nivel: base.nivel, hp: 500));
      final n = apply(s, const DanoDeEfecto(puntos: 10, jugador: 1));
      expect(n.jefe!.hp, 490);
    });
  });

  group('rebote a un aliado', () {
    test('le baja los HP sin atribuirlo a nadie', () {
      final s = conAliado();
      final n = apply(s, const DanoDeEfecto(puntos: 20, slot: 1));
      expect(n.aliadoEn(1)!.hp, 40);
      expect(n.jefe!.hp, s.jefe!.hp);
      expect(n.danoPorJugador, s.danoPorJugador);
    });

    test('a 0 HP sale de la mesa y libera el slot', () {
      final s = conAliado();
      final n = apply(s, const DanoDeEfecto(puntos: 80, slot: 1));
      expect(n.aliadoEn(1), isNull);
      expect(n.aliadosDerrotados, s.aliadosDerrotados + 1);
      expect(n.slotsLibres, contains(1));
    });
  });

  group('reglas incumplidas', () {
    void rechaza(DanoDeEfecto ev, [EstadoPartida? s]) {
      expect(() => apply(s ?? turnoJefe(), ev), throwsA(isA<ReglaIncumplida>()));
    }

    test('hay que indicar jugador o slot, pero solo uno', () {
      rechaza(const DanoDeEfecto(puntos: 10));
      rechaza(const DanoDeEfecto(puntos: 10, jugador: 0, slot: 1));
    });

    test('los puntos son como mínimo 1', () {
      rechaza(const DanoDeEfecto(puntos: 0, jugador: 0));
    });

    test('el jugador debe existir', () {
      rechaza(const DanoDeEfecto(puntos: 10, jugador: 3));
    });

    test('el aliado debe estar en la mesa', () {
      rechaza(const DanoDeEfecto(puntos: 10, slot: 1));
    });

    test('no vale antes de elegir jefe ni al terminar la partida', () {
      expect(
        () => apply(configurar([100]), const DanoDeEfecto(puntos: 1, jugador: 0)),
        throwsA(isA<ReglaIncumplida>()),
      );
      final fin = apply(turnoJefe(), const Abandonar());
      expect(
        () => apply(fin, const DanoDeEfecto(puntos: 1, jugador: 0)),
        throwsA(isA<ReglaIncumplida>()),
      );
    });
  });

  group('efecto autodanoSiKo', () {
    AtaqueJefe ataque({int? jugador = 0, int? valor = 60}) => AtaqueJefe(
          ranura: 2,
          dano: 40,
          jugador: jugador,
          efecto: EfectoAtaque(tipo: TipoEfectoAtaque.autodanoSiKo, valor: valor),
        );

    test('solo se registra: el rebote llega con PokemonKo y DanoDeEfecto', () {
      final s = turnoJefe();
      final n = apply(s, ataque());
      expect(n.jefe!.hp, s.jefe!.hp);
      expect(n.ataquesJefeEnTurno, 1);
      final c = apply(apply(n, const PokemonKo(0)),
          const DanoDeEfecto(puntos: 60, jugador: 0));
      expect(c.jefe!.hp, s.jefe!.hp - 60);
    });

    test('necesita valor y jugador', () {
      expect(() => apply(turnoJefe(), ataque(valor: null)),
          throwsA(isA<ReglaIncumplida>()));
      expect(() => apply(turnoJefe(), ataque(jugador: null)),
          throwsA(isA<ReglaIncumplida>()));
    });
  });
}
