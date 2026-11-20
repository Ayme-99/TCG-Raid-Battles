import 'package:incursiones_engine/campana.dart';
import 'package:incursiones_engine/incursiones_engine.dart' show ReglaIncumplida;
import 'package:test/test.dart';

PokemonCampana pokemon(
  String id, {
  TipoCampana tipo = TipoCampana.normal,
  Debilidad? debilidad,
  Resistencia? resistencia,
  int ps = 100,
  int retirada = 0,
  List<AtaqueCampana>? ataques,
}) =>
    PokemonCampana(
      id: id,
      nombre: id,
      tipo: tipo,
      debilidad: debilidad,
      resistencia: resistencia,
      ps: ps,
      retirada: retirada,
      ataques: ataques ??
          const [
            AtaqueCampana(
                nombre: 'Placaje', tipo: TipoCampana.normal, coste: 1, dano: 30),
            AtaqueCampana(
                nombre: 'Golpe', tipo: TipoCampana.normal, coste: 3, dano: 60),
          ],
    );

EstadoCombate nuevo({
  List<PokemonCampana>? jugador,
  List<PokemonCampana>? rival,
  Bando empieza = Bando.jugador,
  ParametrosCombate parametros = const ParametrosCombate(),
}) =>
    EstadoCombate.inicial(
      equipoJugador: jugador ?? [pokemon('a1'), pokemon('a2')],
      equipoRival: rival ?? [pokemon('b1'), pokemon('b2')],
      empieza: empieza,
      parametros: parametros,
    );

void main() {
  group('debilidad y resistencia', () {
    const agua = AtaqueCampana(
        nombre: 'Pistola Agua', tipo: TipoCampana.agua, coste: 1, dano: 50);
    final tirador = pokemon('agua', tipo: TipoCampana.agua, ataques: const [agua]);

    int danoA(PokemonCampana defensor) {
      final e = aplicarCombate(
        nuevo(jugador: [tirador], rival: [defensor]),
        const Atacar(Bando.jugador, 0),
      );
      return 100 - e.rival.pokemonActivo.ps;
    }

    test('sin debilidad ni resistencia el daño es el de la carta', () {
      expect(danoA(pokemon('b')), 50);
    });

    test('una debilidad multiplica el daño (×2)', () {
      expect(
          danoA(pokemon('b', debilidad: const Debilidad(TipoCampana.agua))), 100);
    });

    test('una resistencia resta 30 y nunca baja de 0', () {
      expect(
          danoA(pokemon('b', resistencia: const Resistencia(TipoCampana.agua))),
          20);
      final debil = pokemon('c',
          resistencia: const Resistencia(TipoCampana.agua, reduccion: 80));
      expect(danoA(debil), 0);
    });

    test('con las dos, primero se multiplica y luego se resta', () {
      expect(
          danoA(pokemon('b',
              debilidad: const Debilidad(TipoCampana.agua),
              resistencia: const Resistencia(TipoCampana.agua))),
          70);
    });

    test('solo cuentan si el tipo del ataque coincide', () {
      expect(
          danoA(pokemon('b',
              debilidad: const Debilidad(TipoCampana.fuego),
              resistencia: const Resistencia(TipoCampana.planta))),
          50);
    });
  });

  group('energía', () {
    test('cada bando empieza con la energía inicial', () {
      final e = nuevo();
      expect(e.jugador.energia, 10);
      expect(e.rival.energia, 10);
    });

    test('atacar gasta el coste y al terminar el turno se recupera 1', () {
      final e = aplicarCombate(nuevo(), const Atacar(Bando.jugador, 1));
      expect(e.jugador.energia, 8);
      expect(e.rival.energia, 10);
      expect(e.turno, Bando.rival);
    });

    test('con coste 3 se encadenan 4 ataques: 10, 8, 6, 4 y luego 2', () {
      var e = nuevo(rival: [pokemon('muro', ps: 100000)]);
      final antes = <int>[];
      for (var i = 0; i < 4; i++) {
        antes.add(e.jugador.energia);
        e = aplicarCombate(e, const Atacar(Bando.jugador, 1));
        e = aplicarCombate(e, const Pasar(Bando.rival));
      }
      expect(antes, [10, 8, 6, 4]);
      expect(e.jugador.energia, 2);
      expect(() => aplicarCombate(e, const Atacar(Bando.jugador, 1)),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('no se puede atacar sin energía suficiente', () {
      var e = nuevo(parametros: const ParametrosCombate(energiaInicial: 2));
      expect(() => aplicarCombate(e, const Atacar(Bando.jugador, 1)),
          throwsA(isA<ReglaIncumplida>()));
      e = aplicarCombate(e, const Atacar(Bando.jugador, 0));
      expect(e.jugador.energia, 2, reason: '2 - 1 + 1 al terminar el turno');
    });

    test('la reserva nunca pasa del máximo', () {
      var e = nuevo();
      e = aplicarCombate(e, const Pasar(Bando.jugador));
      expect(e.jugador.energia, 10);
    });

    test('pasar recupera la energía de fin de turno', () {
      final e = aplicarCombate(
        nuevo(parametros: const ParametrosCombate(energiaInicial: 4)),
        const Pasar(Bando.jugador),
      );
      expect(e.jugador.energia, 5);
      expect(e.rival.energia, 4, reason: 'solo recupera quien termina turno');
    });
  });

  group('turnos y daño', () {
    test('solo actúa el bando al que le toca', () {
      expect(() => aplicarCombate(nuevo(), const Atacar(Bando.rival, 0)),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('el jugador empieza por defecto y puede empezar el rival', () {
      expect(nuevo().turno, Bando.jugador);
      final e = nuevo(empieza: Bando.rival);
      expect(e.turno, Bando.rival);
    });

    test('un ataque inexistente se rechaza', () {
      expect(() => aplicarCombate(nuevo(), const Atacar(Bando.jugador, 5)),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('el estado recibido no se modifica', () {
      final antes = nuevo();
      aplicarCombate(antes, const Atacar(Bando.jugador, 0));
      expect(antes.rival.pokemonActivo.ps, 100);
      expect(antes.turno, Bando.jugador);
    });
  });

  group('cambio de Pokémon', () {
    test('cambiar gasta el turno y no gasta energía si la retirada es 0', () {
      var e = nuevo();
      e = aplicarCombate(e, const Cambiar(Bando.jugador, 1));
      expect(e.jugador.activo, 1);
      expect(e.turno, Bando.rival);
      expect(e.jugador.energia, 10);
    });

    test('una retirada con coste gasta energía además del turno', () {
      var e = nuevo(
        jugador: [pokemon('pesado', retirada: 2), pokemon('ligero')],
        parametros: const ParametrosCombate(energiaInicial: 5),
      );
      e = aplicarCombate(e, const Cambiar(Bando.jugador, 1));
      expect(e.jugador.activo, 1);
      expect(e.jugador.energia, 4, reason: '5 - 2 + 1 al terminar el turno');
      expect(e.turno, Bando.rival);
    });

    test('no se puede retirar sin energía', () {
      final e = nuevo(
        parametros: const ParametrosCombate(energiaInicial: 1),
        jugador: [pokemon('pesado', retirada: 2), pokemon('ligero')],
      );
      expect(() => aplicarCombate(e, const Cambiar(Bando.jugador, 1)),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('no se cambia al activo ni a un Pokémon caído', () {
      final e = nuevo();
      expect(() => aplicarCombate(e, const Cambiar(Bando.jugador, 0)),
          throwsA(isA<ReglaIncumplida>()));
    });
  });

  group('Pokémon caído y fin del combate', () {
    final fuerte = pokemon('fuerte', ataques: const [
      AtaqueCampana(
          nombre: 'Golpe fatal', tipo: TipoCampana.normal, coste: 1, dano: 100),
    ]);

    test('al caer el activo, su dueño elige el siguiente sin gastar turno', () {
      var e = nuevo(jugador: [fuerte], rival: [pokemon('b1'), pokemon('b2')]);
      e = aplicarCombate(e, const Atacar(Bando.jugador, 0));
      expect(e.fase, FaseCombate.eligiendoActivo);
      expect(e.turno, Bando.rival);
      expect(() => aplicarCombate(e, const Pasar(Bando.rival)),
          throwsA(isA<ReglaIncumplida>()));
      expect(() => aplicarCombate(e, const ElegirSiguiente(Bando.rival, 0)),
          throwsA(isA<ReglaIncumplida>()),
          reason: 'el caído no puede volver a salir');
      e = aplicarCombate(e, const ElegirSiguiente(Bando.rival, 1));
      expect(e.rival.activo, 1);
      expect(e.fase, FaseCombate.enCurso);
      expect(e.turno, Bando.rival);
    });

    test('gana quien deja sin Pokémon en pie al otro', () {
      var e = nuevo(jugador: [fuerte], rival: [pokemon('b1')]);
      e = aplicarCombate(e, const Atacar(Bando.jugador, 0));
      expect(e.fase, FaseCombate.terminado);
      expect(e.ganador, Bando.jugador);
      expect(() => aplicarCombate(e, const Pasar(Bando.rival)),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('puede ganar el rival', () {
      var e = nuevo(
        jugador: [pokemon('a1')],
        rival: [fuerte],
        empieza: Bando.rival,
      );
      e = aplicarCombate(e, const Atacar(Bando.rival, 0));
      expect(e.ganador, Bando.rival);
    });

    test('un combate sin Pokémon no se puede crear', () {
      expect(
        () => EstadoCombate.inicial(equipoJugador: [], equipoRival: [fuerte]),
        throwsA(isA<ReglaIncumplida>()),
      );
    });
  });
}
