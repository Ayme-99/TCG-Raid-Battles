import 'package:incursiones_engine/campana.dart';
import 'package:incursiones_engine/incursiones_engine.dart' show ReglaIncumplida;
import 'package:test/test.dart';

PokemonCampana pokemon(
  String id, {
  List<TipoCampana> tipos = const [TipoCampana.normal],
  int ps = 100,
  int retirada = 0,
  List<AtaqueCampana>? ataques,
}) =>
    PokemonCampana(
      id: id,
      nombre: id,
      tipos: tipos,
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
  group('tabla de tipos', () {
    test('fuerte, débil, inmune y neutro', () {
      expect(multiplicadorDeTipos(TipoCampana.agua, [TipoCampana.fuego]), 2);
      expect(multiplicadorDeTipos(TipoCampana.fuego, [TipoCampana.agua]), 0.5);
      expect(multiplicadorDeTipos(TipoCampana.normal, [TipoCampana.fantasma]),
          0);
      expect(multiplicadorDeTipos(TipoCampana.normal, [TipoCampana.fuego]), 1);
    });

    test('con dos tipos se multiplican', () {
      expect(
          multiplicadorDeTipos(
              TipoCampana.agua, [TipoCampana.tierra, TipoCampana.roca]),
          4);
      expect(
          multiplicadorDeTipos(
              TipoCampana.agua, [TipoCampana.tierra, TipoCampana.planta]),
          1);
    });
  });

  group('energía', () {
    test('cada bando empieza con la energía inicial', () {
      final e = nuevo();
      expect(e.jugador.energia, 10);
      expect(e.rival.energia, 10);
    });

    test('atacar gasta el coste y el otro bando recupera al empezar', () {
      final e = aplicarCombate(nuevo(), const Atacar(Bando.jugador, 1));
      expect(e.jugador.energia, 7);
      expect(e.rival.energia, 10, reason: 'ya estaba al máximo');
      expect(e.turno, Bando.rival);
    });

    test('la secuencia de coste 3 sigue 10, 7, 8, 5, 6, 3, 4, 1, 2', () {
      // El rival pasa en cada turno para que nada cambie salvo la energía.
      // Pasar recupera 1 extra: con 0 extra de pasar y 1 por turno la
      // secuencia del jugador es exactamente la del ejemplo de D-20.
      var e = nuevo(
        parametros: const ParametrosCombate(energiaAlPasar: 0),
        rival: [pokemon('muro', ps: 100000)],
      );
      final vistos = <int>[e.jugador.energia];
      for (var i = 0; i < 4; i++) {
        e = aplicarCombate(e, const Atacar(Bando.jugador, 1));
        vistos.add(e.jugador.energia);
        e = aplicarCombate(e, const Pasar(Bando.rival));
        vistos.add(e.jugador.energia);
      }
      expect(vistos, [10, 7, 8, 5, 6, 3, 4, 1, 2]);
    });

    test('no se puede atacar sin energía suficiente', () {
      var e = nuevo(
        parametros: const ParametrosCombate(energiaInicial: 2),
      );
      expect(() => aplicarCombate(e, const Atacar(Bando.jugador, 1)),
          throwsA(isA<ReglaIncumplida>()));
      e = aplicarCombate(e, const Atacar(Bando.jugador, 0));
      expect(e.jugador.energia, 1);
    });

    test('la reserva nunca pasa del máximo', () {
      var e = nuevo();
      e = aplicarCombate(e, const Pasar(Bando.jugador));
      expect(e.jugador.energia, 10);
      e = aplicarCombate(e, const Pasar(Bando.rival));
      expect(e.rival.energia, 10);
    });

    test('pasar recupera energía extra', () {
      var e = nuevo(parametros: const ParametrosCombate(energiaInicial: 4));
      e = aplicarCombate(e, const Pasar(Bando.jugador));
      expect(e.jugador.energia, 5);
      expect(e.rival.energia, 5, reason: '+1 del turno al empezar');
    });
  });

  group('turnos y daño', () {
    test('solo actúa el bando al que le toca', () {
      expect(() => aplicarCombate(nuevo(), const Atacar(Bando.rival, 0)),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('puede empezar el rival', () {
      final e = nuevo(empieza: Bando.rival);
      expect(e.turno, Bando.rival);
    });

    test('el daño aplica la tabla de tipos', () {
      final agua = pokemon('agua', tipos: [TipoCampana.agua], ataques: const [
        AtaqueCampana(
            nombre: 'Pistola Agua', tipo: TipoCampana.agua, coste: 1, dano: 30),
      ]);
      final fuego = pokemon('fuego', tipos: [TipoCampana.fuego]);
      final e = aplicarCombate(
        nuevo(jugador: [agua], rival: [fuego]),
        const Atacar(Bando.jugador, 0),
      );
      expect(e.rival.pokemonActivo.ps, 100 - 60);
    });

    test('un ataque inmune no hace daño', () {
      final fantasma = pokemon('fantasma', tipos: [TipoCampana.fantasma]);
      final e = aplicarCombate(
        nuevo(rival: [fantasma]),
        const Atacar(Bando.jugador, 0),
      );
      expect(e.rival.pokemonActivo.ps, 100);
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
    test('el cambio gratis no gasta turno ni energía, una vez por turno', () {
      var e = nuevo();
      e = aplicarCombate(e, const Cambiar(Bando.jugador, 1));
      expect(e.jugador.activo, 1);
      expect(e.turno, Bando.jugador);
      expect(e.jugador.energia, 10);
      expect(() => aplicarCombate(e, const Cambiar(Bando.jugador, 0)),
          throwsA(isA<ReglaIncumplida>()));
      e = aplicarCombate(e, const Atacar(Bando.jugador, 0));
      e = aplicarCombate(e, const Pasar(Bando.rival));
      e = aplicarCombate(e, const Cambiar(Bando.jugador, 0));
      expect(e.jugador.activo, 0, reason: 'se renueva con el turno');
    });

    test('una retirada con coste gasta energía y el turno', () {
      var e = nuevo(jugador: [
        pokemon('pesado', retirada: 2),
        pokemon('ligero'),
      ]);
      e = aplicarCombate(e, const Cambiar(Bando.jugador, 1));
      expect(e.jugador.activo, 1);
      expect(e.jugador.energia, 8);
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
