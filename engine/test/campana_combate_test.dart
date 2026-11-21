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
        e = aplicarCombate(e, const Cargar(Bando.rival));
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
      e = aplicarCombate(e, const Cargar(Bando.jugador));
      expect(e.jugador.energia, 10);
    });

    test('cargar recupera 1 más que el fin de turno normal', () {
      final e = aplicarCombate(
        nuevo(parametros: const ParametrosCombate(energiaInicial: 4)),
        const Cargar(Bando.jugador),
      );
      expect(e.jugador.energia, 6, reason: '4 + 1 al cargar + 1 al terminar');
      expect(e.rival.energia, 4, reason: 'solo recupera quien termina turno');
      expect(e.turno, Bando.rival);
    });

    test('cargar tampoco pasa del máximo', () {
      final e = aplicarCombate(
        nuevo(parametros: const ParametrosCombate(energiaInicial: 9)),
        const Cargar(Bando.jugador),
      );
      expect(e.jugador.energia, 10);
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
      expect(() => aplicarCombate(e, const Cargar(Bando.rival)),
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
      expect(() => aplicarCombate(e, const Cargar(Bando.rival)),
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

  group('efecto: reducir el daño del rival (Gruñido)', () {
    const grunido = AtaqueCampana(
      nombre: 'Gruñido',
      tipo: TipoCampana.normal,
      coste: 1,
      dano: 0,
      efecto: ReduceDanoRival(10),
    );
    const golpe30 = AtaqueCampana(
        nombre: 'Golpe', tipo: TipoCampana.normal, coste: 1, dano: 30);

    EstadoCombate conGrunido({List<PokemonCampana>? rival}) => aplicarCombate(
          nuevo(
            jugador: [pokemon('g', ataques: const [grunido, golpe30])],
            rival: rival ??
                [
                  pokemon('r1', ataques: const [golpe30]),
                  pokemon('r2', ataques: const [golpe30]),
                ],
          ),
          const Atacar(Bando.jugador, 0),
        );

    test('no hace daño, gasta el coste y marca al activo rival', () {
      final e = conGrunido();
      expect(e.rival.pokemonActivo.ps, 100);
      expect(e.jugador.energia, 10); // 10 - 1 + 1 de fin de turno
      expect(e.rival.danoReducido, 10);
      expect(e.jugador.danoReducido, 0);
    });

    test('los ataques del rival hacen 10 menos mientras siga activo', () {
      var e = conGrunido();
      e = aplicarCombate(e, const Atacar(Bando.rival, 0));
      expect(e.jugador.pokemonActivo.ps, 80); // 30 - 10 = 20
      e = aplicarCombate(e, const Atacar(Bando.jugador, 1));
      e = aplicarCombate(e, const Atacar(Bando.rival, 0));
      expect(e.jugador.pokemonActivo.ps, 60);
    });

    test('no se acumula: usarlo otra vez no quita más', () {
      var e = conGrunido();
      e = aplicarCombate(e, const Atacar(Bando.rival, 0));
      e = aplicarCombate(e, const Atacar(Bando.jugador, 0));
      expect(e.rival.danoReducido, 10);
      e = aplicarCombate(e, const Atacar(Bando.rival, 0));
      expect(e.jugador.pokemonActivo.ps, 60);
    });

    test('se quita al cambiar el activo rival a la banca', () {
      var e = conGrunido();
      e = aplicarCombate(e, const Cambiar(Bando.rival, 1));
      expect(e.rival.danoReducido, 0);
      e = aplicarCombate(e, const Atacar(Bando.jugador, 1));
      e = aplicarCombate(e, const Atacar(Bando.rival, 0));
      expect(e.jugador.pokemonActivo.ps, 70);
    });

    test('se quita cuando el activo rival cae y entra otro', () {
      final fragil = pokemon('frágil', ps: 30, ataques: const [golpe30]);
      var e = conGrunido(rival: [fragil, pokemon('r2')]);
      e = aplicarCombate(e, const Atacar(Bando.rival, 0));
      e = aplicarCombate(e, const Atacar(Bando.jugador, 1));
      expect(e.fase, FaseCombate.eligiendoActivo);
      e = aplicarCombate(e, const ElegirSiguiente(Bando.rival, 1));
      expect(e.rival.danoReducido, 0);
    });

    test('se resta antes de la debilidad y la resistencia', () {
      const agua = AtaqueCampana(
          nombre: 'Pistola Agua', tipo: TipoCampana.agua, coste: 1, dano: 30);
      final debil = pokemon('d',
          tipo: TipoCampana.planta,
          debilidad: const Debilidad(TipoCampana.agua),
          ataques: const [grunido]);
      var e = aplicarCombate(
        nuevo(
          jugador: [debil],
          rival: [pokemon('tirador', tipo: TipoCampana.agua, ataques: const [agua])],
          empieza: Bando.jugador,
        ),
        const Atacar(Bando.jugador, 0),
      );
      e = aplicarCombate(e, const Atacar(Bando.rival, 0));
      expect(e.jugador.pokemonActivo.ps, 60); // (30 - 10) × 2 = 40
    });

    test('un ataque sin daño no hace daño aunque haya debilidad', () {
      expect(
        danoDeAtaque(grunido,
            pokemon('x', debilidad: const Debilidad(TipoCampana.normal))),
        0,
      );
    });

    test('la reducción nunca deja el daño por debajo de 0', () {
      expect(
        danoDeAtaque(
            const AtaqueCampana(
                nombre: 'a', tipo: TipoCampana.normal, coste: 1, dano: 10),
            pokemon('x'),
            reduccion: 30),
        0,
      );
    });
  });

  group('efecto: el rival pierde energía (Disparo Demora)', () {
    const demora = AtaqueCampana(
      nombre: 'Disparo Demora',
      tipo: TipoCampana.planta,
      coste: 1,
      dano: 0,
      efecto: QuitaEnergiaRival(1),
    );
    final oruga = pokemon('o', tipo: TipoCampana.planta, ataques: const [demora]);

    test('quita 1 de energía al rival y no le hace daño', () {
      final e = aplicarCombate(
          nuevo(jugador: [oruga]), const Atacar(Bando.jugador, 0));
      expect(e.rival.energia, 9);
      expect(e.rival.pokemonActivo.ps, 100);
      expect(e.jugador.energia, 10); // -1 del coste, +1 al acabar el turno
    });

    test('no baja de 0 si no le queda energía', () {
      final e = aplicarCombate(
        nuevo(
          jugador: [oruga],
          parametros: const ParametrosCombate(energiaInicial: 0),
        ).copiarCon(
            jugador: nuevo(jugador: [oruga]).jugador.copiarCon(energia: 1)),
        const Atacar(Bando.jugador, 0),
      );
      expect(e.rival.energia, 0);
    });

    test('no se acumula ni deja estado: dos usos quitan 1 cada uno', () {
      var e = aplicarCombate(nuevo(jugador: [oruga]), const Atacar(Bando.jugador, 0));
      e = aplicarCombate(e, const Cargar(Bando.rival));
      final antes = e.rival.energia;
      e = aplicarCombate(e, const Atacar(Bando.jugador, 0));
      expect(e.rival.energia, antes - 1);
      expect(e.rival.danoReducido, 0);
      expect(e.rival.danoExtra, 0);
    });
  });

  group('efecto: el rival recibe más daño (Látigo)', () {
    const latigo = AtaqueCampana(
      nombre: 'Látigo',
      tipo: TipoCampana.agua,
      coste: 1,
      dano: 0,
      efecto: AumentaDanoRecibido(10),
    );
    const golpe20 = AtaqueCampana(
        nombre: 'Golpe', tipo: TipoCampana.agua, coste: 1, dano: 20);

    EstadoCombate conLatigo({List<PokemonCampana>? rival}) => aplicarCombate(
          nuevo(
            jugador: [pokemon('s', tipo: TipoCampana.agua, ataques: const [latigo, golpe20])],
            rival: rival ?? [pokemon('r1'), pokemon('r2')],
          ),
          const Atacar(Bando.jugador, 0),
        );

    test('no hace daño y marca al activo rival', () {
      final e = conLatigo();
      expect(e.rival.pokemonActivo.ps, 100);
      expect(e.rival.danoExtra, 10);
      expect(e.jugador.danoExtra, 0);
    });

    test('los ataques contra el rival hacen 10 más mientras siga activo', () {
      var e = conLatigo();
      e = aplicarCombate(e, const Atacar(Bando.rival, 0)); // el rival ataca
      e = aplicarCombate(e, const Atacar(Bando.jugador, 1));
      expect(e.rival.pokemonActivo.ps, 70); // 20 + 10
      e = aplicarCombate(e, const Atacar(Bando.rival, 0));
      e = aplicarCombate(e, const Atacar(Bando.jugador, 1));
      expect(e.rival.pokemonActivo.ps, 40);
    });

    test('no se acumula', () {
      var e = conLatigo();
      e = aplicarCombate(e, const Atacar(Bando.rival, 0));
      e = aplicarCombate(e, const Atacar(Bando.jugador, 0));
      expect(e.rival.danoExtra, 10);
    });

    test('se quita al cambiar el activo rival a la banca', () {
      var e = conLatigo();
      e = aplicarCombate(e, const Cambiar(Bando.rival, 1));
      expect(e.rival.danoExtra, 0);
      e = aplicarCombate(e, const Atacar(Bando.jugador, 1));
      expect(e.rival.pokemonActivo.ps, 80); // 20 sin extra
    });

    test('se suma antes de la debilidad', () {
      final debil = pokemon('d',
          debilidad: const Debilidad(TipoCampana.agua),
          ataques: const [golpe20]);
      var e = conLatigo(rival: [debil]);
      e = aplicarCombate(e, const Atacar(Bando.rival, 0));
      e = aplicarCombate(e, const Atacar(Bando.jugador, 1));
      expect(e.rival.pokemonActivo.ps, 40); // (20 + 10) × 2 = 60
    });

    test('un ataque sin daño no gana el extra', () {
      expect(danoDeAtaque(latigo, pokemon('x'), extra: 10), 0);
    });

    test('Gruñido y Látigo se combinan', () {
      const grunido = AtaqueCampana(
          nombre: 'Gruñido',
          tipo: TipoCampana.normal,
          coste: 1,
          dano: 0,
          efecto: ReduceDanoRival(10));
      expect(
        danoDeAtaque(golpe20, pokemon('x'), reduccion: 10, extra: 10),
        20,
      );
      expect(grunido.efecto, isA<ReduceDanoRival>());
    });
  });
}
