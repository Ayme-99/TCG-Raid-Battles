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

  group('habilidad: moneda de daño extra al atacar (Foco Energía)', () {
  PokemonCampana mono({List<AtaqueCampana>? ataques}) => PokemonCampana(
        id: 'm',
        nombre: 'm',
        tipo: TipoCampana.lucha,
        ps: 100,
        habilidad: const MonedaDanoExtraAlAtacar('Foco Energía', 20),
        ataques: ataques ??
            const [
              AtaqueCampana(
                  nombre: 'Golpe',
                  tipo: TipoCampana.lucha,
                  coste: 2,
                  dano: 30),
            ],
      );

    test('lanza una moneda y con cara suma 20; con cruz no', () {
      final danos = <int>{};
      for (var semilla = 1; semilla < 40; semilla++) {
        final e = aplicarCombate(
            EstadoCombate.inicial(
                equipoJugador: [mono()],
                equipoRival: [pokemon('r')],
                semilla: semilla),
            const Atacar(Bando.jugador, 0));
        final dano = 100 - e.rival.pokemonActivo.ps;
        expect(dano, e.ultimaMoneda! ? 50 : 30);
        danos.add(dano);
      }
      expect(danos, {30, 50});
    });

    test('es una moneda aparte de la del ataque', () {
      final golpe = mono(ataques: const [
        AtaqueCampana(
            nombre: 'Golpe Kárate',
            tipo: TipoCampana.lucha,
            coste: 2,
            dano: 30,
            efecto: MonedaDanoExtra(20)),
      ]);
      final vistos = <int>{};
      for (var semilla = 1; semilla < 60; semilla++) {
        final e = aplicarCombate(
            EstadoCombate.inicial(
                equipoJugador: [golpe],
                equipoRival: [pokemon('r')],
                semilla: semilla),
            const Atacar(Bando.jugador, 0));
        expect(e.ultimasMonedas!.length, 2);
        final caras = e.ultimasMonedas!.where((c) => c).length;
        final dano = 100 - e.rival.pokemonActivo.ps;
        expect(dano, 30 + 20 * caras);
        vistos.add(dano);
      }
      expect(vistos, {30, 50, 70});
    });
  });

  group('efecto: repetir el daño al derribar (Doble Patada)', () {
    const patada = AtaqueCampana(
      nombre: 'Doble Patada',
      tipo: TipoCampana.oscuridad,
      coste: 3,
      dano: 30,
      efecto: RepiteDanoAlDerribar(),
    );
    final nido = pokemon('n', tipo: TipoCampana.oscuridad, ataques: const [patada]);

    EstadoCombate atacar(List<PokemonCampana> rival) => aplicarCombate(
        nuevo(jugador: [nido], rival: rival), const Atacar(Bando.jugador, 0));

    test('si derriba, el que sale recibe de nuevo el daño', () {
      var e = atacar([pokemon('r1', ps: 20), pokemon('r2')]);
      expect(e.fase, FaseCombate.eligiendoActivo);
      expect(e.repetirDano, isNotNull);
      e = aplicarCombate(e, const ElegirSiguiente(Bando.rival, 1));
      expect(e.rival.pokemonActivo.ps, 70);
      expect(e.repetirDano, isNull);
      expect(e.fase, FaseCombate.enCurso);
    });

    test('si no derriba, no se repite nada', () {
      final e = atacar([pokemon('r1', ps: 100), pokemon('r2')]);
      expect(e.repetirDano, isNull);
    });

    test('el nuevo activo aplica su propia debilidad', () {
      final debil = pokemon('r2',
          debilidad: const Debilidad(TipoCampana.oscuridad));
      var e = atacar([pokemon('r1', ps: 20), debil]);
      e = aplicarCombate(e, const ElegirSiguiente(Bando.rival, 1));
      expect(e.rival.pokemonActivo.ps, 40); // 100 - 30 x2
    });

    test('solo se repite una vez, aunque el segundo también caiga', () {
      var e = atacar([
        pokemon('r1', ps: 20),
        pokemon('r2', ps: 20),
        pokemon('r3'),
      ]);
      e = aplicarCombate(e, const ElegirSiguiente(Bando.rival, 1));
      expect(e.fase, FaseCombate.eligiendoActivo);
      e = aplicarCombate(e, const ElegirSiguiente(Bando.rival, 2));
      expect(e.rival.pokemonActivo.ps, 100);
    });

    test('si el segundo era el último, el combate termina', () {
      var e = atacar([pokemon('r1', ps: 20), pokemon('r2', ps: 20)]);
      e = aplicarCombate(e, const ElegirSiguiente(Bando.rival, 1));
      expect(e.fase, FaseCombate.terminado);
      expect(e.ganador, Bando.jugador);
    });
  });

  group('efecto: varias monedas (Ataque Furia)', () {
    const furia = AtaqueCampana(
      nombre: 'Ataque Furia',
      tipo: TipoCampana.normal,
      coste: 2,
      dano: 30,
      efecto: MonedasDano(3, [50, 20, 30, 40]),
    );
    final ave = pokemon('a', ps: 60, ataques: const [furia]);

    EstadoCombate golpe(int semilla) => aplicarCombate(
          EstadoCombate.inicial(
              equipoJugador: [ave],
              equipoRival: [pokemon('d', ps: 500)],
              semilla: semilla),
          const Atacar(Bando.jugador, 0),
        );

    test('el daño sale de la tabla según las caras y quedan las 3 monedas', () {
      const tabla = [50, 20, 30, 40];
      final vistos = <int>{};
      for (var s = 1; s <= 100; s++) {
        final e = golpe(s);
        expect(e.ultimasMonedas, hasLength(3));
        final caras = e.ultimasMonedas!.where((c) => c).length;
        final dano = 500 - e.rival.pokemonActivo.ps;
        expect(dano, tabla[caras], reason: 'semilla $s');
        vistos.add(dano);
      }
      expect(vistos, {20, 30, 40, 50});
    });

    test('el daño medio es el esperado (30)', () {
      var total = 0;
      for (var s = 1; s <= 400; s++) {
        total += 500 - golpe(s).rival.pokemonActivo.ps;
      }
      expect(total / 400, inInclusiveRange(26, 34));
    });

    test('misma semilla, mismo resultado', () {
      expect(golpe(9).rival.pokemonActivo.ps, golpe(9).rival.pokemonActivo.ps);
    });
  });

  group('efecto: daño por racha (Rodar)', () {
    const rodar = AtaqueCampana(
      nombre: 'Rodar',
      tipo: TipoCampana.lucha,
      coste: 2,
      dano: 20,
      efecto: DanoPorRacha(),
    );
    const otro = AtaqueCampana(
        nombre: 'Otro', tipo: TipoCampana.lucha, coste: 1, dano: 10);
    final rueda = pokemon('s', tipo: TipoCampana.lucha, ps: 70, ataques: const [rodar, otro]);
    final blanco = pokemon('b', ps: 500, ataques: const [
      AtaqueCampana(nombre: 'Nada', tipo: TipoCampana.normal, coste: 1, dano: 10)
    ]);

    EstadoCombate turno(EstadoCombate e, AccionCombate a) {
      e = aplicarCombate(e, a);
      return e.fase == FaseCombate.terminado
          ? e
          : aplicarCombate(e, const Cargar(Bando.rival));
    }

    EstadoCombate inicio() => nuevo(jugador: [rueda, pokemon('s2')], rival: [blanco, pokemon('b2')]);

    test('20, 40, 60… con usos seguidos', () {
      var e = inicio();
      final danos = <int>[];
      for (var i = 0; i < 3; i++) {
        final antes = e.rival.pokemonActivo.ps;
        e = turno(e, const Atacar(Bando.jugador, 0));
        danos.add(antes - e.rival.pokemonActivo.ps);
      }
      expect(danos, [20, 40, 60]);
    });

    test('usar otro ataque reinicia la racha', () {
      var e = inicio();
      e = turno(e, const Atacar(Bando.jugador, 0));
      e = turno(e, const Atacar(Bando.jugador, 0));
      e = turno(e, const Atacar(Bando.jugador, 1));
      final antes = e.rival.pokemonActivo.ps;
      e = turno(e, const Atacar(Bando.jugador, 0));
      expect(antes - e.rival.pokemonActivo.ps, 20);
    });

    test('cargar o cambiar de Pokémon reinicia la racha', () {
      var e = inicio();
      e = turno(e, const Atacar(Bando.jugador, 0));
      e = turno(e, const Cargar(Bando.jugador));
      expect(e.jugador.racha, 0);
      var antes = e.rival.pokemonActivo.ps;
      e = turno(e, const Atacar(Bando.jugador, 0));
      expect(antes - e.rival.pokemonActivo.ps, 20);
      e = turno(e, const Cambiar(Bando.jugador, 1));
      expect(e.jugador.ultimoAtaque, -1);
    });
  });

  group('efecto: moneda de fallo (Bofetón Lodo)', () {
    const bofeton = AtaqueCampana(
      nombre: 'Bofetón Lodo',
      tipo: TipoCampana.lucha,
      coste: 2,
      dano: 30,
      efecto: MonedaFalloRival(),
    );
    const golpe = AtaqueCampana(
        nombre: 'Golpe', tipo: TipoCampana.normal, coste: 1, dano: 40);
    final topo = pokemon('d', tipo: TipoCampana.lucha, ps: 100, ataques: const [bofeton]);
    final rival = pokemon('r', ps: 200, ataques: const [golpe]);

    EstadoCombate marcado([int semilla = 1]) => aplicarCombate(
          EstadoCombate.inicial(
              equipoJugador: [topo, pokemon('t2')],
              equipoRival: [rival, pokemon('r2')],
              semilla: semilla),
          const Atacar(Bando.jugador, 0),
        );

    test('hace su daño y marca al rival', () {
      final e = marcado();
      expect(e.rival.pokemonActivo.ps, 170);
      expect(e.rival.cegado, isTrue);
      expect(e.jugador.cegado, isFalse);
      expect(e.ultimaMoneda, isNull); // la moneda se lanza cuando el rival ataca
    });

    test('con cara el ataque del rival funciona y con cruz no hace nada', () {
      final resultados = <bool, EstadoCombate>{};
      for (var s = 1; s <= 40; s++) {
        final e = aplicarCombate(marcado(s), const Atacar(Bando.rival, 0));
        resultados[e.ultimaMoneda!] = e;
      }
      final cara = resultados[true]!;
      final cruz = resultados[false]!;
      expect(cara.jugador.pokemonActivo.ps, 60);
      expect(cruz.jugador.pokemonActivo.ps, 100);
      // La energía se gasta igual (10 - 1 + 1 de fin de turno).
      expect(cruz.rival.energia, cara.rival.energia);
      expect(cruz.rival.cegado, isFalse);
      expect(cara.rival.cegado, isFalse);
    });

    test('solo dura su próximo turno aunque no ataque', () {
      var e = marcado();
      e = aplicarCombate(e, const Cargar(Bando.rival));
      expect(e.rival.cegado, isFalse);
      e = aplicarCombate(e, const Cargar(Bando.jugador));
      e = aplicarCombate(e, const Atacar(Bando.rival, 0));
      expect(e.jugador.pokemonActivo.ps, 60); // sin moneda, hace su daño
    });

    test('cambiar de Pokémon también lo quita', () {
      var e = marcado();
      e = aplicarCombate(e, const Cambiar(Bando.rival, 1));
      expect(e.rival.cegado, isFalse);
    });
  });

  group('efecto: confusión (Supersónico)', () {
    const supersonico = AtaqueCampana(
      nombre: 'Supersónico',
      tipo: TipoCampana.oscuridad,
      coste: 1,
      dano: 0,
      efecto: ConfundeDefensor(),
    );
    const golpe = AtaqueCampana(
        nombre: 'Golpe', tipo: TipoCampana.normal, coste: 1, dano: 40);
    final murcielago = pokemon('z',
        tipo: TipoCampana.oscuridad, ps: 100, ataques: const [supersonico]);
    final rival = pokemon('r', ps: 200, ataques: const [golpe]);

    EstadoCombate usado(int semilla) => aplicarCombate(
          EstadoCombate.inicial(
              equipoJugador: [murcielago, pokemon('z2')],
              equipoRival: [rival, pokemon('r2')],
              semilla: semilla),
          const Atacar(Bando.jugador, 0),
        );

    // Una semilla con cara y otra con cruz en la moneda de Supersónico.
    final porMoneda = <bool, int>{};
    for (var s = 1; s <= 40 && porMoneda.length < 2; s++) {
      porMoneda.putIfAbsent(usado(s).ultimaMoneda!, () => s);
    }

    test('lanza una moneda y la deja a la vista; no hace daño', () {
      for (final s in porMoneda.values) {
        final e = usado(s);
        expect(e.ultimasMonedas, hasLength(1));
        expect(e.ultimasMonedas!.single, e.ultimaMoneda);
        expect(e.rival.pokemonActivo.ps, 200);
        expect(e.jugador.energia, 10, reason: '10 - 1 + 1 de fin de turno');
        expect(e.semilla, isNot(EstadoCombate.inicial(
                equipoJugador: [murcielago],
                equipoRival: [rival],
                semilla: s)
            .semilla));
      }
    });

    test('con cara el Defensor queda Confundido; con cruz, no', () {
      expect(usado(porMoneda[true]!).rival.cegado, isTrue);
      expect(usado(porMoneda[false]!).rival.cegado, isFalse);
      expect(usado(porMoneda[true]!).jugador.cegado, isFalse);
    });

    test('Confundido: con cruz en su ataque no hace nada y gasta la energía',
        () {
      final resultados = <bool, EstadoCombate>{};
      for (var s = 1; s <= 80; s++) {
        final e0 = usado(s);
        if (!e0.rival.cegado) continue;
        final e = aplicarCombate(e0, const Atacar(Bando.rival, 0));
        resultados[e.ultimaMoneda!] = e;
      }
      final cara = resultados[true]!;
      final cruz = resultados[false]!;
      expect(cara.jugador.pokemonActivo.ps, 60);
      expect(cruz.jugador.pokemonActivo.ps, 100);
      expect(cruz.rival.energia, cara.rival.energia);
      expect(cara.rival.cegado, isFalse);
      expect(cruz.rival.cegado, isFalse);
    });

    test('solo dura su próximo turno', () {
      var e = usado(porMoneda[true]!);
      e = aplicarCombate(e, const Cargar(Bando.rival));
      expect(e.rival.cegado, isFalse);
      e = aplicarCombate(e, const Cargar(Bando.jugador));
      e = aplicarCombate(e, const Atacar(Bando.rival, 0));
      expect(e.jugador.pokemonActivo.ps, 60, reason: 'sin moneda, hace daño');
    });
  });

  group('efecto: confusión con 2 monedas (Hidropulso)', () {
    const hidropulso = AtaqueCampana(
      nombre: 'Hidropulso',
      tipo: TipoCampana.agua,
      coste: 3,
      dano: 40,
      efecto: ConfundeDefensor(2),
    );
    final lento = pokemon('s',
        tipo: TipoCampana.agua, ps: 100, ataques: const [hidropulso]);
    final rival = pokemon('r', ps: 200);

    test('hace su daño, lanza 2 monedas y confunde solo con dos caras', () {
      final vistos = <String>{};
      for (var s = 1; s <= 80; s++) {
        final e = aplicarCombate(
            EstadoCombate.inicial(
                equipoJugador: [lento], equipoRival: [rival], semilla: s),
            const Atacar(Bando.jugador, 0));
        expect(e.rival.pokemonActivo.ps, 160);
        final m = e.ultimasMonedas!;
        expect(m, hasLength(2));
        expect(e.rival.cegado, m[0] && m[1]);
        vistos.add(m.join(','));
      }
      expect(vistos, hasLength(4), reason: 'salen las cuatro combinaciones');
    });
  });

  group('efecto: moneda de fallo mientras siga activo (Pantalla de Humo)', () {
    const humo = AtaqueCampana(
      nombre: 'Pantalla de Humo',
      tipo: TipoCampana.fuego,
      coste: 2,
      dano: 0,
      efecto: MonedaFalloRival(mientrasActivo: true),
    );
    const golpe = AtaqueCampana(
        nombre: 'Golpe', tipo: TipoCampana.normal, coste: 1, dano: 10);
    final lagarto =
        pokemon('c', tipo: TipoCampana.fuego, ps: 100, ataques: const [humo]);
    final rival = pokemon('r', ps: 200, ataques: const [golpe]);

    EstadoCombate marcado(int semilla) => aplicarCombate(
          EstadoCombate.inicial(
              equipoJugador: [lagarto, pokemon('c2')],
              equipoRival: [rival, pokemon('r2')],
              semilla: semilla),
          const Atacar(Bando.jugador, 0),
        );

    test('no hace daño y deja al rival marcado mientras siga activo', () {
      final e = marcado(1);
      expect(e.rival.pokemonActivo.ps, 200);
      expect(e.rival.cegadoMientrasActivo, isTrue);
      expect(e.rival.cegado, isFalse);
    });

    test('dura más de un turno: cada ataque lanza su moneda', () {
      var e = marcado(7);
      final monedas = <bool>[];
      for (var i = 0; i < 6; i++) {
        final antes = e.jugador.pokemonActivo.ps;
        e = aplicarCombate(e, const Atacar(Bando.rival, 0));
        expect(e.ultimasMonedas, hasLength(1));
        final m = e.ultimaMoneda!;
        monedas.add(m);
        expect(e.jugador.pokemonActivo.ps, m ? antes - 10 : antes,
            reason: 'con cruz el ataque no se lleva a cabo');
        expect(e.rival.cegadoMientrasActivo, isTrue);
        e = aplicarCombate(e, const Cargar(Bando.jugador));
      }
      expect(monedas.toSet(), {true, false},
          reason: 'en seis ataques salen cara y cruz');
    });

    test('cargar no lo quita; cambiar de Pokémon, sí', () {
      var e = marcado(1);
      e = aplicarCombate(e, const Cargar(Bando.rival));
      expect(e.rival.cegadoMientrasActivo, isTrue);
      e = aplicarCombate(e, const Cargar(Bando.jugador));
      e = aplicarCombate(e, const Cambiar(Bando.rival, 1));
      expect(e.rival.cegadoMientrasActivo, isFalse);
    });

    test('cuando cae, el que sale ya no está marcado', () {
      var e = marcado(1);
      e = e.copiarCon(
          rival: e.rival.copiarCon(
              equipo: [e.rival.equipo[0].conPs(0), e.rival.equipo[1]]),
          fase: FaseCombate.eligiendoActivo,
          turno: Bando.rival);
      e = aplicarCombate(e, const ElegirSiguiente(Bando.rival, 1));
      expect(e.rival.cegadoMientrasActivo, isFalse);
    });
  });

  group('efecto: parálisis (Dragoaliento)', () {
    const dragoaliento = AtaqueCampana(
      nombre: 'Dragoaliento',
      tipo: TipoCampana.fuego,
      coste: 3,
      dano: 50,
      efecto: ParalizaDefensor(3, 2),
    );
    const golpe = AtaqueCampana(
        nombre: 'Golpe', tipo: TipoCampana.normal, coste: 1, dano: 10);
    final lagarto = pokemon('c',
        tipo: TipoCampana.fuego, ps: 100, ataques: const [dragoaliento]);
    final rival = pokemon('r', ps: 300, ataques: const [golpe]);

    EstadoCombate usado(int semilla) => aplicarCombate(
          EstadoCombate.inicial(
              equipoJugador: [lagarto, pokemon('c2')],
              equipoRival: [rival, pokemon('r2')],
              semilla: semilla),
          const Atacar(Bando.jugador, 0),
        );

    final paraliza = <bool, int>{};
    for (var s = 1; s <= 80 && paraliza.length < 2; s++) {
      paraliza.putIfAbsent(usado(s).rival.paralizado, () => s);
    }

    test('hace su daño, lanza 3 monedas y paraliza con 2 caras o más', () {
      final vistos = <int>{};
      for (var s = 1; s <= 80; s++) {
        final e = usado(s);
        expect(e.rival.pokemonActivo.ps, 250);
        final m = e.ultimasMonedas!;
        expect(m, hasLength(3));
        final caras = m.where((c) => c).length;
        vistos.add(caras);
        expect(e.rival.paralizado, caras >= 2);
        expect(e.jugador.paralizado, isFalse);
      }
      expect(vistos, containsAll([0, 1, 2, 3]));
    });

    test('el paralizado no puede atacar ni cambiar; sí cargar', () {
      final e = usado(paraliza[true]!);
      expect(() => aplicarCombate(e, const Atacar(Bando.rival, 0)),
          throwsA(isA<ReglaIncumplida>()));
      expect(() => aplicarCombate(e, const Cambiar(Bando.rival, 1)),
          throwsA(isA<ReglaIncumplida>()));
      final cargado = aplicarCombate(e, const Cargar(Bando.rival));
      expect(cargado.rival.paralizado, isFalse,
          reason: 'se quita al acabar su turno');
    });

    test('solo dura su próximo turno y no se acumula', () {
      var e = usado(paraliza[true]!);
      e = aplicarCombate(e, const Cargar(Bando.rival));
      e = aplicarCombate(e, const Cargar(Bando.jugador));
      e = aplicarCombate(e, const Atacar(Bando.rival, 0));
      expect(e.jugador.pokemonActivo.ps, 90, reason: 'ya puede atacar');
    });

    test('la IA, paralizada, carga', () {
      final e = usado(paraliza[true]!);
      expect(decidirAccion(e, Bando.rival), isA<Cargar>());
    });

    test('si el golpe lo derriba no queda paralizado el que sale', () {
      final debil = pokemon('d', ps: 50, ataques: const [golpe]);
      for (var s = 1; s <= 40; s++) {
        var e = aplicarCombate(
            EstadoCombate.inicial(
                equipoJugador: [lagarto],
                equipoRival: [debil, pokemon('r2')],
                semilla: s),
            const Atacar(Bando.jugador, 0));
        expect(e.fase, FaseCombate.eligiendoActivo);
        e = aplicarCombate(e, const ElegirSiguiente(Bando.rival, 1));
        expect(e.rival.paralizado, isFalse);
      }
    });
  });

  group('efecto: Drenadoras (drenaDefensor)', () {
    const drenadoras = AtaqueCampana(
      nombre: 'Drenadoras',
      tipo: TipoCampana.planta,
      coste: 2,
      dano: 0,
      efecto: DrenaDefensor(),
    );
    const golpe = AtaqueCampana(
        nombre: 'Golpe', tipo: TipoCampana.normal, coste: 1, dano: 30);
    final planta = pokemon('i',
        tipo: TipoCampana.planta, ps: 110, ataques: const [drenadoras]);
    final rival = pokemon('r', ps: 100, ataques: const [golpe]);

    EstadoCombate conPs(int psPlanta) => EstadoCombate.conEquipos(
          equipoJugador: [
            PokemonEnCombate(planta, psPlanta),
            PokemonEnCombate.completo(pokemon('i2', ps: 60)),
          ],
          equipoRival: [
            PokemonEnCombate.completo(rival),
            PokemonEnCombate.completo(pokemon('r2')),
          ],
        );

    test('quita 10 por chequeo y cura 10 al activo de quien lo usó', () {
      var e = aplicarCombate(conPs(50), const Atacar(Bando.jugador, 0));
      expect(e.rival.veneno, 10);
      expect(e.rival.drenado, isTrue);
      expect(e.rival.pokemonActivo.ps, 90);
      expect(e.jugador.pokemonActivo.ps, 60);
      e = aplicarCombate(e, const Cargar(Bando.rival));
      expect(e.rival.pokemonActivo.ps, 80);
      expect(e.jugador.pokemonActivo.ps, 70);
    });

    test('la cura no pasa del máximo', () {
      final e = aplicarCombate(conPs(110), const Atacar(Bando.jugador, 0));
      expect(e.jugador.pokemonActivo.ps, 110);
      expect(e.rival.pokemonActivo.ps, 90, reason: 'el daño sí se hace');
    });

    test('cura al activo de ese momento, aunque no sea quien lo usó', () {
      var e = EstadoCombate.conEquipos(
        equipoJugador: [
          PokemonEnCombate(planta, 110),
          PokemonEnCombate(pokemon('i2', ps: 60), 30),
        ],
        equipoRival: [
          PokemonEnCombate.completo(rival),
          PokemonEnCombate.completo(pokemon('r2')),
        ],
      );
      e = aplicarCombate(e, const Atacar(Bando.jugador, 0));
      e = aplicarCombate(e, const Cargar(Bando.rival));
      e = aplicarCombate(e, const Cambiar(Bando.jugador, 1));
      expect(e.jugador.pokemonActivo.especie.id, 'i2');
      expect(e.jugador.pokemonActivo.ps, 40);
      expect(e.rival.pokemonActivo.ps, 70);
    });

    test('no se acumula y cambiar de Pokémon lo quita', () {
      var e = aplicarCombate(conPs(50), const Atacar(Bando.jugador, 0));
      e = aplicarCombate(e, const Cargar(Bando.rival));
      e = aplicarCombate(e, const Atacar(Bando.jugador, 0));
      expect(e.rival.veneno, 10);
      e = aplicarCombate(e, const Cambiar(Bando.rival, 1));
      expect(e.rival.veneno, 0);
      expect(e.rival.drenado, isFalse);
      final ps = e.jugador.pokemonActivo.ps;
      e = aplicarCombate(e, const Cargar(Bando.jugador));
      expect(e.jugador.pokemonActivo.ps, ps, reason: 'ya no cura');
    });
  });

  group('efecto: protección propia (Fortaleza)', () {
    const fortaleza = AtaqueCampana(
      nombre: 'Fortaleza',
      tipo: TipoCampana.planta,
      coste: 1,
      dano: 0,
      efecto: ReduceDanoPropio(10),
    );
    final capullo = pokemon('c', tipo: TipoCampana.planta, ps: 80, ataques: const [fortaleza]);

    EstadoCombate protegido({List<PokemonCampana>? jugador}) => aplicarCombate(
          nuevo(jugador: jugador ?? [capullo, pokemon('c2')], rival: [pokemon('r1'), pokemon('r2')]),
          const Atacar(Bando.jugador, 0),
        );

    test('marca al propio activo y no hace daño', () {
      final e = protegido();
      expect(e.jugador.proteccion, 10);
      expect(e.rival.proteccion, 0);
      expect(e.rival.pokemonActivo.ps, 100);
    });

    test('los ataques que recibe hacen 10 menos', () {
      var e = protegido();
      e = aplicarCombate(e, const Atacar(Bando.rival, 0)); // Placaje 30 → 20
      expect(e.jugador.pokemonActivo.ps, 60);
    });

    test('no se acumula', () {
      var e = protegido();
      e = aplicarCombate(e, const Cargar(Bando.rival));
      e = aplicarCombate(e, const Atacar(Bando.jugador, 0));
      expect(e.jugador.proteccion, 10);
    });

    test('cambiar de Pokémon lo quita', () {
      var e = protegido();
      e = aplicarCombate(e, const Cargar(Bando.rival));
      e = aplicarCombate(e, const Cambiar(Bando.jugador, 1));
      expect(e.jugador.proteccion, 0);
    });

    test('se combina con Látigo: +10 y -10 se compensan', () {
      var e = protegido(jugador: [
        pokemon('c', ps: 80, ataques: const [fortaleza]),
      ]);
      e = e.copiarCon(jugador: e.jugador.copiarCon(danoExtra: 10));
      expect(e.jugador.extraRecibido, 0);
      e = aplicarCombate(e, const Atacar(Bando.rival, 0));
      expect(e.jugador.pokemonActivo.ps, 50);
    });

    test('nunca deja el daño por debajo de 0', () {
      final debil = pokemon('r', ataques: const [
        AtaqueCampana(nombre: 'Flojo', tipo: TipoCampana.normal, coste: 1, dano: 10)
      ]);
      var e = aplicarCombate(
          nuevo(jugador: [capullo], rival: [debil]), const Atacar(Bando.jugador, 0));
      e = aplicarCombate(e, const Atacar(Bando.rival, 0));
      expect(e.jugador.pokemonActivo.ps, 80);
    });
  });

  group('efecto: veneno (Picotazo Veneno)', () {
    const picotazo = AtaqueCampana(
      nombre: 'Picotazo Veneno',
      tipo: TipoCampana.planta,
      coste: 2,
      dano: 10,
      efecto: EnvenenaDefensor(10),
    );
    const golpe = AtaqueCampana(
        nombre: 'Golpe', tipo: TipoCampana.normal, coste: 1, dano: 10);
    final bicho = pokemon('w', tipo: TipoCampana.planta, ps: 50, ataques: const [picotazo]);
    final sano = pokemon('r', ps: 100, ataques: const [golpe]);

    EstadoCombate envenenado() => aplicarCombate(
        nuevo(jugador: [bicho], rival: [sano, pokemon('r2')]),
        const Atacar(Bando.jugador, 0));

    test('el chequeo al acabar el turno quita 10 más al envenenado', () {
      final e = envenenado();
      expect(e.rival.veneno, 10);
      expect(e.rival.pokemonActivo.ps, 80); // 100 - 10 del golpe - 10 de veneno
    });

    test('hay chequeo en cada cambio de turno: 10 por turno de cualquiera', () {
      var e = envenenado();
      e = aplicarCombate(e, const Cargar(Bando.rival));
      expect(e.rival.pokemonActivo.ps, 70);
      e = aplicarCombate(e, const Cargar(Bando.jugador));
      expect(e.rival.pokemonActivo.ps, 60);
    });

    test('no se acumula', () {
      var e = envenenado();
      e = aplicarCombate(e, const Cargar(Bando.rival));
      e = aplicarCombate(e, const Atacar(Bando.jugador, 0));
      expect(e.rival.veneno, 10);
    });

    test('cambiar de Pokémon lo quita', () {
      var e = envenenado();
      e = aplicarCombate(e, const Cambiar(Bando.rival, 1));
      expect(e.rival.veneno, 0);
      expect(e.rival.pokemonActivo.especie.id, 'r2');
      final ps = e.rival.pokemonActivo.ps;
      e = aplicarCombate(e, const Cargar(Bando.jugador));
      expect(e.rival.pokemonActivo.ps, ps);
    });

    test('el veneno puede derribar al activo y el dueño elige relevo', () {
      var e = envenenado();
      e = e.copiarCon(
        rival: e.rival.copiarCon(equipo: [
          e.rival.equipo[0].conPs(10),
          e.rival.equipo[1],
        ]),
      );
      e = aplicarCombate(e, const Cargar(Bando.rival));
      // El chequeo tras el turno del rival envenena y derriba a su activo.
      expect(e.fase, FaseCombate.eligiendoActivo);
      expect(e.actua, Bando.rival);
      e = aplicarCombate(e, const ElegirSiguiente(Bando.rival, 1));
      expect(e.fase, FaseCombate.enCurso);
      expect(e.rival.veneno, 0);
      expect(e.turno, Bando.jugador);
    });

    test('si cae su último Pokémon por veneno, gana el otro', () {
      var e = aplicarCombate(
          nuevo(jugador: [bicho], rival: [sano]), const Atacar(Bando.jugador, 0));
      e = e.copiarCon(
          rival: e.rival.copiarCon(equipo: [e.rival.equipo[0].conPs(10)]));
      e = aplicarCombate(e, const Cargar(Bando.rival));
      expect(e.fase, FaseCombate.terminado);
      expect(e.ganador, Bando.jugador);
    });

    test('si cae quien acaba el turno por veneno, elige y luego juega el otro', () {
      // El jugador está envenenado y su último turno le deja en 10 PS.
      var e = nuevo(
          jugador: [pokemon('a', ps: 100), pokemon('a2')],
          rival: [pokemon('b')]);
      e = e.copiarCon(
          jugador: e.jugador.copiarCon(
              veneno: 10, equipo: [e.jugador.equipo[0].conPs(10), e.jugador.equipo[1]]));
      e = aplicarCombate(e, const Cargar(Bando.jugador));
      expect(e.fase, FaseCombate.eligiendoActivo);
      expect(e.turno, Bando.rival);
      expect(e.actua, Bando.jugador);
      expect(() => aplicarCombate(e, const ElegirSiguiente(Bando.rival, 0)),
          throwsA(isA<ReglaIncumplida>()));
      e = aplicarCombate(e, const ElegirSiguiente(Bando.jugador, 1));
      expect(e.fase, FaseCombate.enCurso);
      expect(e.turno, Bando.rival);
    });
  });

  group('efecto: moneda (Hiper Colmillo)', () {
    const colmillo = AtaqueCampana(
      nombre: 'Hiper Colmillo',
      tipo: TipoCampana.normal,
      coste: 1,
      dano: 20,
      efecto: MonedaDanoExtra(20),
    );
    final rata = pokemon('r', ataques: const [colmillo]);

    EstadoCombate atacarCon(int semilla) => aplicarCombate(
          EstadoCombate.inicial(
              equipoJugador: [rata],
              equipoRival: [pokemon('d', ps: 200)],
              semilla: semilla),
          const Atacar(Bando.jugador, 0),
        );

    test('cara hace 40 y cruz hace 20, y se anota la moneda', () {
      final danos = {
        for (var s = 1; s <= 40; s++)
          atacarCon(s).ultimaMoneda!: 200 - atacarCon(s).rival.pokemonActivo.ps,
      };
      expect(danos[true], 40);
      expect(danos[false], 20);
    });

    test('misma semilla, mismo resultado; la semilla avanza', () {
      final a = atacarCon(7);
      final b = atacarCon(7);
      expect(a.ultimaMoneda, b.ultimaMoneda);
      expect(a.rival.pokemonActivo.ps, b.rival.pokemonActivo.ps);
      expect(a.semilla, isNot(7));
    });

    test('sale cara y cruz con proporción razonable', () {
      var caras = 0;
      for (var s = 1; s <= 200; s++) {
        if (atacarCon(s).ultimaMoneda!) caras++;
      }
      expect(caras, inInclusiveRange(70, 130));
    });

    test('un ataque sin moneda no toca la semilla', () {
      final e = aplicarCombate(
          nuevo(jugador: [pokemon('a')]), const Atacar(Bando.jugador, 0));
      expect(e.semilla, 1);
      expect(e.ultimaMoneda, isNull);
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

  group('efecto: el propio bando gana energía (Pulimento)', () {
    const pulimento = AtaqueCampana(
      nombre: 'Pulimento',
      tipo: TipoCampana.normal,
      coste: 1,
      dano: 0,
      efecto: GanaEnergia(2),
    );
    final roca =
        pokemon('g', tipo: TipoCampana.lucha, ataques: const [pulimento]);
    EstadoCombate conEnergia(int energia) {
      final e = nuevo(jugador: [roca]);
      return e.copiarCon(jugador: e.jugador.copiarCon(energia: energia));
    }

    test('paga el coste, suma 2 y no hace daño', () {
      final e = aplicarCombate(conEnergia(4), const Atacar(Bando.jugador, 0));
      // 4 - 1 del coste + 2 del efecto + 1 al acabar el turno.
      expect(e.jugador.energia, 6);
      expect(e.rival.pokemonActivo.ps, 100);
      expect(e.rival.energia, 10);
    });

    test('no pasa del máximo de 10', () {
      final e = aplicarCombate(conEnergia(9), const Atacar(Bando.jugador, 0));
      expect(e.jugador.energia, 10);
      final lleno =
          aplicarCombate(conEnergia(10), const Atacar(Bando.jugador, 0));
      expect(lleno.jugador.energia, 10);
    });

    test('respeta un máximo distinto en los parámetros', () {
      final base = nuevo(
          jugador: [roca],
          parametros: const ParametrosCombate(energiaMaxima: 6));
      final e = aplicarCombate(
          base.copiarCon(jugador: base.jugador.copiarCon(energia: 5)),
          const Atacar(Bando.jugador, 0));
      expect(e.jugador.energia, 6);
    });

    test('sin energía para el coste no se puede usar', () {
      expect(() => aplicarCombate(conEnergia(0), const Atacar(Bando.jugador, 0)),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('no deja estado: dos usos suman 2 cada uno', () {
      var e = aplicarCombate(conEnergia(2), const Atacar(Bando.jugador, 0));
      expect(e.jugador.energia, 4); // 2 - 1 + 2 + 1
      e = aplicarCombate(e, const Cargar(Bando.rival));
      e = aplicarCombate(e, const Atacar(Bando.jugador, 0));
      expect(e.jugador.energia, 6); // 4 - 1 + 2 + 1
      expect(e.jugador.danoReducido, 0);
      expect(e.jugador.proteccion, 0);
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

  group('Poción en combate (D-20 §3.2, #458)', () {
    EstadoCombate herido({
      int pociones = 2,
      ParametrosCombate parametros = const ParametrosCombate(),
    }) =>
        EstadoCombate.conEquipos(
          equipoJugador: [
            PokemonEnCombate(pokemon('a1'), 50),
            PokemonEnCombate(pokemon('a2'), 90),
            PokemonEnCombate(pokemon('a3'), 0),
          ],
          equipoRival: [PokemonEnCombate.completo(pokemon('b1'))],
          parametros: parametros,
          pocionesJugador: pociones,
        );

    test('cura 20 PS y no gasta el turno', () {
      final e = herido();
      final d = aplicarCombate(e, const UsarPocion(Bando.jugador, 0));
      expect(d.jugador.equipo[0].ps, 70);
      expect(d.jugador.pociones, 1);
      expect(d.jugador.pocionesUsadas, 1);
      expect(d.turno, Bando.jugador);
      expect(d.numeroTurno, e.numeroTurno);
      expect(d.jugador.energia, e.jugador.energia);
      // Después puede atacar en el mismo turno.
      final t = aplicarCombate(d, const Atacar(Bando.jugador, 0));
      expect(t.turno, Bando.rival);
    });

    test('sin límite por combate: solo el inventario', () {
      var e = herido(pociones: 3);
      e = aplicarCombate(e, const UsarPocion(Bando.jugador, 0));
      e = aplicarCombate(e, const UsarPocion(Bando.jugador, 0));
      expect(e.jugador.equipo[0].ps, 90);
      e = aplicarCombate(e, const UsarPocion(Bando.jugador, 0));
      expect(e.jugador.equipo[0].ps, 100, reason: 'no pasa de los PS máximos');
      expect(e.jugador.pociones, 0);
      expect(e.jugador.pocionesUsadas, 3);
      expect(() => aplicarCombate(e, const UsarPocion(Bando.jugador, 1)),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('cura a la banca (propuesta), no revive ni cura al que está lleno',
        () {
      final e = herido();
      final d = aplicarCombate(e, const UsarPocion(Bando.jugador, 1));
      expect(d.jugador.equipo[1].ps, 100);
      expect(d.jugador.activo, 0);
      expect(() => aplicarCombate(e, const UsarPocion(Bando.jugador, 2)),
          throwsA(isA<ReglaIncumplida>()), reason: 'caído');
      expect(() => aplicarCombate(d, const UsarPocion(Bando.jugador, 1)),
          throwsA(isA<ReglaIncumplida>()), reason: 'lleno');
      expect(objetivosDePocion(e, Bando.jugador), [0, 1]);
    });

    test('con pocionCuraBanca = false solo cura al activo', () {
      final e = herido(
          parametros: const ParametrosCombate(pocionCuraBanca: false));
      expect(objetivosDePocion(e, Bando.jugador), [0]);
      expect(() => aplicarCombate(e, const UsarPocion(Bando.jugador, 1)),
          throwsA(isA<ReglaIncumplida>()));
      expect(aplicarCombate(e, const UsarPocion(Bando.jugador, 0))
          .jugador
          .equipo[0]
          .ps, 70);
    });

    test('sin Pociones, o fuera de su turno, no se puede', () {
      final sin = herido(pociones: 0);
      expect(objetivosDePocion(sin, Bando.jugador), isEmpty);
      expect(() => aplicarCombate(sin, const UsarPocion(Bando.jugador, 0)),
          throwsA(isA<ReglaIncumplida>()));
      final suyo = aplicarCombate(herido(), const Cargar(Bando.jugador));
      expect(objetivosDePocion(suyo, Bando.jugador), isEmpty);
      expect(() => aplicarCombate(suyo, const UsarPocion(Bando.jugador, 0)),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('el rival no usa objetos (propuesta), salvo con rivalUsaObjetos',
        () {
      EstadoCombate rivalHerido(ParametrosCombate p) => EstadoCombate.conEquipos(
            equipoJugador: [PokemonEnCombate.completo(pokemon('a1'))],
            equipoRival: [PokemonEnCombate(pokemon('b1'), 40)],
            empieza: Bando.rival,
            parametros: p,
            pocionesRival: 1,
          );
      final no = rivalHerido(const ParametrosCombate());
      expect(objetivosDePocion(no, Bando.rival), isEmpty);
      expect(() => aplicarCombate(no, const UsarPocion(Bando.rival, 0)),
          throwsA(isA<ReglaIncumplida>()));
      final si = rivalHerido(const ParametrosCombate(rivalUsaObjetos: true));
      expect(aplicarCombate(si, const UsarPocion(Bando.rival, 0))
          .rival
          .equipo[0]
          .ps, 60);
    });
  });
}
