import 'package:incursiones_engine/campana.dart';
import 'package:incursiones_engine/incursiones_engine.dart' show ReglaIncumplida;
import 'package:test/test.dart';

AtaqueCampana ataque(int coste, int dano,
        [TipoCampana tipo = TipoCampana.normal]) =>
    AtaqueCampana(nombre: 'A$coste-$dano', tipo: tipo, coste: coste, dano: dano);

PokemonCampana pokemon(
  String id, {
  TipoCampana tipo = TipoCampana.normal,
  Debilidad? debilidad,
  int ps = 100,
  int retirada = 0,
  List<AtaqueCampana>? ataques,
}) =>
    PokemonCampana(
      id: id,
      nombre: id,
      tipo: tipo,
      debilidad: debilidad,
      ps: ps,
      retirada: retirada,
      ataques: ataques ?? [ataque(1, 30), ataque(3, 60)],
    );

EstadoCombate combate(
  List<PokemonCampana> jugador,
  List<PokemonCampana> rival, {
  Bando empieza = Bando.jugador,
  ParametrosCombate parametros = const ParametrosCombate(),
}) =>
    EstadoCombate.inicial(
      equipoJugador: jugador,
      equipoRival: rival,
      empieza: empieza,
      parametros: parametros,
    );

void main() {
  group('ataque', () {
    test('remata con el ataque más barato que lo consigue', () {
      final yo = pokemon('yo', ataques: [
        ataque(1, 10),
        ataque(2, 100),
        ataque(4, 120),
      ]);
      final e = combate([yo], [pokemon('rival', ps: 100)]);
      final a = decidirAccion(e, Bando.jugador);
      expect(a, isA<Atacar>().having((x) => x.indice, 'indice', 1));
    });

    test('con la reserva a medias elige el mejor daño por energía', () {
      final yo = pokemon('yo', ataques: [ataque(1, 20), ataque(3, 50)]);
      final e = combate(
        [yo],
        [pokemon('rival', ps: 500)],
        parametros: const ParametrosCombate(energiaInicial: 5),
      );
      expect(decidirAccion(e, Bando.jugador),
          isA<Atacar>().having((x) => x.indice, 'indice', 0));
    });

    test('con la reserva llena elige el de más daño', () {
      final yo = pokemon('yo', ataques: [ataque(1, 20), ataque(3, 50)]);
      final e = combate([yo], [pokemon('rival', ps: 500)]);
      expect(decidirAccion(e, Bando.jugador),
          isA<Atacar>().having((x) => x.indice, 'indice', 1));
    });

    test('tiene en cuenta debilidades y resistencias del rival', () {
      final yo = pokemon('yo', ataques: [
        ataque(1, 40, TipoCampana.normal),
        ataque(1, 30, TipoCampana.agua),
      ]);
      final rival = pokemon('rival',
          ps: 500, debilidad: const Debilidad(TipoCampana.agua));
      final e = combate(
        [yo],
        [rival],
        parametros: const ParametrosCombate(energiaInicial: 5),
      );
      expect(decidirAccion(e, Bando.jugador),
          isA<Atacar>().having((x) => x.indice, 'indice', 1),
          reason: '30 × 2 = 60 supera a 40');
    });

    test('carga si no llega a ningún ataque ni a ningún relevo', () {
      final e = combate(
        [pokemon('yo')],
        [pokemon('rival')],
        parametros: const ParametrosCombate(energiaInicial: 0),
      );
      expect(decidirAccion(e, Bando.jugador), isA<Cargar>());
    });
  });

  group('carga', () {
    test('carga para rematar al turno siguiente lo que hoy no le llega', () {
      final yo = pokemon('yo', ataques: [ataque(1, 10), ataque(4, 100)]);
      final e = combate(
        [yo],
        [pokemon('rival', ps: 100)],
        parametros: const ParametrosCombate(energiaInicial: 3),
      );
      expect(decidirAccion(e, Bando.jugador), isA<Cargar>());
    });

    test('no carga si ni cargando le llega el ataque que remata', () {
      final yo = pokemon('yo', ataques: [ataque(1, 10), ataque(6, 100)]);
      final e = combate(
        [yo],
        [pokemon('rival', ps: 100)],
        parametros: const ParametrosCombate(energiaInicial: 3),
      );
      expect(decidirAccion(e, Bando.jugador), isA<Atacar>());
    });
  });

  group('cambio', () {
    test('cambia si su activo es débil a un ataque del rival', () {
      final planta = pokemon('planta',
          tipo: TipoCampana.planta,
          debilidad: const Debilidad(TipoCampana.fuego));
      final agua = pokemon('agua', tipo: TipoCampana.agua);
      final fuego = pokemon('fuego', ataques: [ataque(1, 30, TipoCampana.fuego)]);
      final e = combate([planta, agua], [fuego]);
      expect(decidirAccion(e, Bando.jugador),
          isA<Cambiar>().having((x) => x.indice, 'indice', 1));
    });

    test('no cambia a un relevo que también es débil', () {
      final planta = pokemon('planta',
          debilidad: const Debilidad(TipoCampana.fuego));
      final otra = pokemon('otra', debilidad: const Debilidad(TipoCampana.fuego));
      final fuego = pokemon('fuego', ataques: [ataque(1, 30, TipoCampana.fuego)]);
      final e = combate([planta, otra], [fuego]);
      expect(decidirAccion(e, Bando.jugador), isA<Atacar>());
    });

    test('cambia si su activo no llega a ningún ataque y un relevo sí', () {
      final caro = pokemon('caro', ataques: [ataque(5, 80)]);
      final barato = pokemon('barato', ataques: [ataque(1, 20)]);
      final e = combate(
        [caro, barato],
        [pokemon('rival')],
        parametros: const ParametrosCombate(energiaInicial: 2),
      );
      expect(decidirAccion(e, Bando.jugador),
          isA<Cambiar>().having((x) => x.indice, 'indice', 1));
    });

    test('no cambia si no le llega la energía de la retirada', () {
      final pesado = pokemon('pesado',
          retirada: 3,
          debilidad: const Debilidad(TipoCampana.fuego),
          ataques: [ataque(1, 10)]);
      final otro = pokemon('otro');
      final fuego = pokemon('fuego', ataques: [ataque(1, 30, TipoCampana.fuego)]);
      final e = combate(
        [pesado, otro],
        [fuego],
        parametros: const ParametrosCombate(energiaInicial: 2),
      );
      expect(decidirAccion(e, Bando.jugador), isA<Atacar>());
    });
  });

  group('elegir siguiente', () {
    test('saca al relevo que más daño hace al rival', () {
      final fuerte = pokemon('fuerte', ataques: [ataque(1, 100)]);
      final e0 = combate(
        [
          pokemon('a1'),
          pokemon('a2', ataques: [ataque(1, 10)]),
          pokemon('a3', ataques: [ataque(1, 50)]),
        ],
        [fuerte],
        empieza: Bando.rival,
      );
      final e = aplicarCombate(e0, const Atacar(Bando.rival, 0));
      expect(e.fase, FaseCombate.eligiendoActivo);
      expect(decidirAccion(e, Bando.jugador),
          isA<ElegirSiguiente>().having((x) => x.indice, 'indice', 2));
    });
  });

  group('reglas de uso', () {
    test('no actúa fuera de su turno ni con el combate terminado', () {
      final e = combate([pokemon('a')], [pokemon('b')]);
      expect(() => decidirAccion(e, Bando.rival),
          throwsA(isA<ReglaIncumplida>()));
      final fin = aplicarCombate(
        combate([pokemon('a', ataques: [ataque(1, 100)])], [pokemon('b')]),
        const Atacar(Bando.jugador, 0),
      );
      expect(() => decidirAccion(fin, Bando.jugador),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('es determinista', () {
      final e = combate(
          [pokemon('a'), pokemon('b')], [pokemon('c'), pokemon('d')]);
      final a1 = decidirAccion(e, Bando.jugador);
      final a2 = decidirAccion(e, Bando.jugador);
      expect(a1.runtimeType, a2.runtimeType);
    });
  });

  group('IA contra IA', () {
    EstadoCombate jugar(EstadoCombate inicial) {
      var e = inicial;
      for (var i = 0; i < 2000 && e.fase != FaseCombate.terminado; i++) {
        e = aplicarCombate(e, decidirAccion(e, e.actua));
      }
      return e;
    }

    final equipos = <List<PokemonCampana>>[
      [
        pokemon('roca',
            tipo: TipoCampana.lucha,
            ps: 120,
            debilidad: const Debilidad(TipoCampana.agua),
            ataques: [ataque(1, 20, TipoCampana.lucha), ataque(4, 80, TipoCampana.lucha)]),
        pokemon('lucha',
            tipo: TipoCampana.lucha,
            ps: 90,
            ataques: [ataque(2, 40, TipoCampana.lucha)]),
      ],
      [
        pokemon('agua',
            tipo: TipoCampana.agua,
            ps: 100,
            debilidad: const Debilidad(TipoCampana.planta),
            ataques: [ataque(1, 20, TipoCampana.agua), ataque(3, 60, TipoCampana.agua)]),
        pokemon('planta',
            tipo: TipoCampana.planta,
            ps: 110,
            debilidad: const Debilidad(TipoCampana.fuego),
            retirada: 1,
            ataques: [ataque(2, 40, TipoCampana.planta)]),
        pokemon('fuego',
            tipo: TipoCampana.fuego,
            ps: 80,
            ataques: [ataque(2, 50, TipoCampana.fuego)]),
      ],
    ];

    test('todos los emparejamientos terminan con un ganador', () {
      for (final a in equipos) {
        for (final b in equipos) {
          for (final empieza in Bando.values) {
            final e = jugar(combate(a, b, empieza: empieza));
            expect(e.fase, FaseCombate.terminado,
                reason: 'no terminó en 2000 acciones');
            expect(e.ganador, isNotNull);
          }
        }
      }
    });
  });

  group('Gruñido', () {
    const grunido = AtaqueCampana(
      nombre: 'Gruñido',
      tipo: TipoCampana.normal,
      coste: 1,
      dano: 0,
      efecto: ReduceDanoRival(10),
    );
    PokemonCampana conGrunido() => pokemon('g', ps: 90, ataques: [
          grunido,
          ataque(2, 30),
        ]);

    test('lo usa contra un rival que pega poco', () {
      final e = combate([conGrunido()], [pokemon('r', ataques: [ataque(1, 10)])]);
      expect(decidirAccion(e, Bando.jugador),
          isA<Atacar>().having((x) => x.indice, 'indice', 0));
    });

    test('no lo usa contra un rival que pega fuerte', () {
      final e = combate([conGrunido()], [pokemon('r', ataques: [ataque(2, 60)])]);
      expect(decidirAccion(e, Bando.jugador),
          isA<Atacar>().having((x) => x.indice, 'indice', 1));
    });

    test('no lo repite mientras el mismo rival siga activo', () {
      var e = combate([conGrunido()], [pokemon('r', ataques: [ataque(1, 10)])]);
      e = aplicarCombate(e, decidirAccion(e, Bando.jugador));
      e = aplicarCombate(e, decidirAccion(e, Bando.rival));
      expect(decidirAccion(e, Bando.jugador),
          isA<Atacar>().having((x) => x.indice, 'indice', 1));
    });

    test('todos los emparejamientos con Gruñido terminan', () {
      final a = [conGrunido(), pokemon('b', ps: 80, ataques: [ataque(1, 10)])];
      final b = [pokemon('c', ps: 70, ataques: [ataque(1, 10), ataque(2, 30)])];
      for (final x in [a, b]) {
        for (final y in [a, b]) {
          for (final empieza in Bando.values) {
            var e = combate(x, y, empieza: empieza);
            for (var i = 0; i < 2000 && e.fase != FaseCombate.terminado; i++) {
              e = aplicarCombate(e, decidirAccion(e, e.actua));
            }
            expect(e.fase, FaseCombate.terminado);
          }
        }
      }
    });
  });

  group('Ataque Furia', () {
    const furia = AtaqueCampana(
      nombre: 'Ataque Furia',
      tipo: TipoCampana.normal,
      coste: 2,
      dano: 30,
      efecto: MonedasDano(3, [50, 20, 30, 40]),
    );

    test('todos los emparejamientos con Ataque Furia terminan', () {
      final a = [pokemon('s', ps: 60, ataques: [ataque(1, 10), furia])];
      final b = [pokemon('c', ps: 70, ataques: [ataque(1, 10), ataque(2, 30)])];
      for (var semilla = 1; semilla <= 20; semilla++) {
        for (final x in [a, b]) {
          for (final y in [a, b]) {
            for (final empieza in Bando.values) {
              var e = EstadoCombate.inicial(
                  equipoJugador: x,
                  equipoRival: y,
                  empieza: empieza,
                  semilla: semilla);
              for (var i = 0; i < 2000 && e.fase != FaseCombate.terminado; i++) {
                e = aplicarCombate(e, decidirAccion(e, e.actua));
              }
              expect(e.fase, FaseCombate.terminado);
            }
          }
        }
      }
    });
  });

  group('Rodar', () {
    const rodar = AtaqueCampana(
      nombre: 'Rodar',
      tipo: TipoCampana.lucha,
      coste: 2,
      dano: 20,
      efecto: DanoPorRacha(),
    );

    test('aprovecha una racha empezada y no la empieza si pega más el otro', () {
      final e = combate([
        pokemon('s', ps: 70, ataques: [rodar, ataque(1, 30)])
      ], [
        pokemon('b', ps: 500, ataques: [ataque(1, 10)])
      ]);
      // Sin racha, Rodar (20) pega menos que el otro (30): no lo empieza.
      expect(decidirAccion(e, Bando.jugador),
          isA<Atacar>().having((x) => x.indice, 'indice', 1));
      // Con racha de 2, Rodar haría 60: lo encadena.
      final enRacha = e.copiarCon(
          jugador: e.jugador.copiarCon(ultimoAtaque: 0, racha: 2));
      expect(decidirAccion(enRacha, Bando.jugador),
          isA<Atacar>().having((x) => x.indice, 'indice', 0));
    });

    test('todos los emparejamientos con Rodar terminan', () {
      final a = [pokemon('s', ps: 70, ataques: [rodar])];
      final b = [pokemon('c', ps: 70, ataques: [ataque(1, 10), ataque(2, 30)])];
      for (final x in [a, b]) {
        for (final y in [a, b]) {
          for (final empieza in Bando.values) {
            var e = combate(x, y, empieza: empieza);
            for (var i = 0; i < 2000 && e.fase != FaseCombate.terminado; i++) {
              e = aplicarCombate(e, decidirAccion(e, e.actua));
            }
            expect(e.fase, FaseCombate.terminado);
          }
        }
      }
    });
  });

  group('Bofetón Lodo', () {
    const bofeton = AtaqueCampana(
      nombre: 'Bofetón Lodo',
      tipo: TipoCampana.lucha,
      coste: 2,
      dano: 30,
      efecto: MonedaFalloRival(),
    );

    test('todos los emparejamientos con Bofetón Lodo terminan', () {
      final a = [pokemon('d', ps: 50, ataques: [ataque(1, 10), bofeton])];
      final b = [pokemon('c', ps: 70, ataques: [ataque(1, 10), ataque(2, 30)])];
      for (var semilla = 1; semilla <= 20; semilla++) {
        for (final x in [a, b]) {
          for (final y in [a, b]) {
            for (final empieza in Bando.values) {
              var e = EstadoCombate.inicial(
                  equipoJugador: x,
                  equipoRival: y,
                  empieza: empieza,
                  semilla: semilla);
              for (var i = 0; i < 2000 && e.fase != FaseCombate.terminado; i++) {
                e = aplicarCombate(e, decidirAccion(e, e.actua));
              }
              expect(e.fase, FaseCombate.terminado);
            }
          }
        }
      }
    });
  });

  group('Fortaleza', () {
    const fortaleza = AtaqueCampana(
      nombre: 'Fortaleza',
      tipo: TipoCampana.planta,
      coste: 1,
      dano: 0,
      efecto: ReduceDanoPropio(10),
    );
    PokemonCampana capullo() =>
        pokemon('m', ps: 80, ataques: [fortaleza, ataque(1, 20)]);

    test('la usa contra un rival que pega poco', () {
      final e = combate([capullo()], [pokemon('r', ataques: [ataque(1, 10)])]);
      expect(decidirAccion(e, Bando.jugador),
          isA<Atacar>().having((x) => x.indice, 'indice', 0));
    });

    test('no la usa contra un rival que pega fuerte', () {
      final e = combate([capullo()], [pokemon('r', ataques: [ataque(2, 60)])]);
      expect(decidirAccion(e, Bando.jugador),
          isA<Atacar>().having((x) => x.indice, 'indice', 1));
    });

    test('no la repite mientras siga activo', () {
      var e = combate([capullo()], [pokemon('r', ataques: [ataque(1, 20)])]);
      e = aplicarCombate(e, decidirAccion(e, Bando.jugador));
      e = aplicarCombate(e, decidirAccion(e, Bando.rival));
      expect(decidirAccion(e, Bando.jugador),
          isA<Atacar>().having((x) => x.indice, 'indice', 1));
    });

    test('todos los emparejamientos con Fortaleza terminan', () {
      final a = [capullo()];
      final b = [pokemon('c', ps: 70, ataques: [ataque(1, 10), ataque(2, 30)])];
      for (final x in [a, b]) {
        for (final y in [a, b]) {
          for (final empieza in Bando.values) {
            var e = combate(x, y, empieza: empieza);
            for (var i = 0; i < 2000 && e.fase != FaseCombate.terminado; i++) {
              e = aplicarCombate(e, decidirAccion(e, e.actua));
            }
            expect(e.fase, FaseCombate.terminado);
          }
        }
      }
    });
  });

  group('Veneno', () {
    const veneno = AtaqueCampana(
      nombre: 'Picotazo Veneno',
      tipo: TipoCampana.planta,
      coste: 2,
      dano: 10,
      efecto: EnvenenaDefensor(10),
    );

    test('envenena aunque el golpe quede en 0 por Fortaleza', () {
      final e = combate([
        pokemon('w', ps: 50, ataques: [veneno])
      ], [
        pokemon('m', ps: 80, ataques: [ataque(1, 20)])
      ]);
      final protegido = e.copiarCon(
          rival: e.rival.copiarCon(proteccion: 10));
      expect(decidirAccion(protegido, Bando.jugador),
          isA<Atacar>().having((x) => x.indice, 'indice', 0));
    });

    test('no repite el veneno si el rival ya está envenenado', () {
      final e = combate([
        pokemon('w', ps: 50, ataques: [veneno, ataque(1, 20)])
      ], [
        pokemon('m', ps: 80, ataques: [ataque(1, 10)])
      ]);
      final ya = e.copiarCon(rival: e.rival.copiarCon(veneno: 10));
      expect(decidirAccion(ya, Bando.jugador),
          isA<Atacar>().having((x) => x.indice, 'indice', 1));
    });

    test('todos los emparejamientos con veneno terminan', () {
      final a = [pokemon('w', ps: 50, ataques: [veneno])];
      final b = [
        pokemon('c', ps: 70, ataques: [ataque(1, 10), ataque(3, 60)]),
        pokemon('d', ps: 60, ataques: [ataque(2, 30)]),
      ];
      for (final x in [a, b]) {
        for (final y in [a, b]) {
          for (final empieza in Bando.values) {
            var e = combate(x, y, empieza: empieza);
            for (var i = 0; i < 2000 && e.fase != FaseCombate.terminado; i++) {
              e = aplicarCombate(e, decidirAccion(e, e.actua));
            }
            expect(e.fase, FaseCombate.terminado);
          }
        }
      }
    });
  });

  group('Disparo Demora', () {
    const demora = AtaqueCampana(
      nombre: 'Disparo Demora',
      tipo: TipoCampana.normal,
      coste: 1,
      dano: 0,
      efecto: QuitaEnergiaRival(1),
    );
    PokemonCampana oruga() =>
        pokemon('o', ps: 90, ataques: [demora, ataque(2, 20)]);
    EstadoCombate conRivalJusto(int energia) {
      final e = combate([oruga()], [pokemon('r', ataques: [ataque(3, 60)])]);
      return e.copiarCon(
          rival: e.rival.copiarCon(energia: energia));
    }

    test('lo usa si con ello el rival deja de llegar a su ataque fuerte', () {
      expect(decidirAccion(conRivalJusto(3), Bando.jugador),
          isA<Atacar>().having((x) => x.indice, 'indice', 0));
    });

    test('no lo usa si el rival llega de sobra', () {
      expect(decidirAccion(conRivalJusto(10), Bando.jugador),
          isA<Atacar>().having((x) => x.indice, 'indice', 1));
    });

    test('todos los emparejamientos con Disparo Demora terminan', () {
      final a = [oruga(), pokemon('b', ps: 80, ataques: [ataque(1, 10), ataque(2, 20)])];
      final b = [pokemon('c', ps: 70, ataques: [ataque(1, 10), ataque(3, 60)])];
      for (final x in [a, b]) {
        for (final y in [a, b]) {
          for (final empieza in Bando.values) {
            var e = combate(x, y, empieza: empieza);
            for (var i = 0; i < 2000 && e.fase != FaseCombate.terminado; i++) {
              e = aplicarCombate(e, decidirAccion(e, e.actua));
            }
            expect(e.fase, FaseCombate.terminado);
          }
        }
      }
    });
  });

  group('Látigo', () {
    const latigo = AtaqueCampana(
      nombre: 'Látigo',
      tipo: TipoCampana.normal,
      coste: 1,
      dano: 0,
      efecto: AumentaDanoRecibido(10),
    );
    PokemonCampana tortuga() =>
        pokemon('t', ps: 80, ataques: [latigo, ataque(2, 20)]);

    test('lo usa en un combate largo (muchos golpes por delante)', () {
      final e = combate([tortuga()], [pokemon('duro', ps: 200)]);
      expect(decidirAccion(e, Bando.jugador),
          isA<Atacar>().having((x) => x.indice, 'indice', 0));
    });

    test('no lo usa si no ahorra golpes', () {
      final e = combate([tortuga()], [pokemon('blando', ps: 60)]);
      expect(decidirAccion(e, Bando.jugador),
          isA<Atacar>().having((x) => x.indice, 'indice', 1));
    });

    test('no lo repite mientras el mismo rival siga activo', () {
      var e = combate([tortuga()], [pokemon('duro', ps: 200)]);
      e = aplicarCombate(e, decidirAccion(e, Bando.jugador));
      e = aplicarCombate(e, decidirAccion(e, Bando.rival));
      expect(decidirAccion(e, Bando.jugador),
          isA<Atacar>().having((x) => x.indice, 'indice', 1));
    });

    test('todos los emparejamientos con Látigo terminan', () {
      final a = [tortuga(), pokemon('b', ps: 80, ataques: [ataque(2, 20)])];
      final b = [pokemon('c', ps: 150, ataques: [ataque(1, 10), ataque(2, 30)])];
      for (final x in [a, b]) {
        for (final y in [a, b]) {
          for (final empieza in Bando.values) {
            var e = combate(x, y, empieza: empieza);
            for (var i = 0; i < 2000 && e.fase != FaseCombate.terminado; i++) {
              e = aplicarCombate(e, decidirAccion(e, e.actua));
            }
            expect(e.fase, FaseCombate.terminado);
          }
        }
      }
    });
  });
}
