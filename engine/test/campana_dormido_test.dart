// Estado Dormido, efecto duermeDefensor (Canto) y curación de estados al pasar
// a la banca (D-20 §10.2, 2026-11-26; #511). Jigglypuff aún no tiene carta en
// el catálogo: se prueba con cartas de prueba.
import 'package:incursiones_engine/campana.dart';
import 'package:test/test.dart';

PokemonCampana pokemon(
  String id, {
  int ps = 100,
  int retirada = 0,
  List<AtaqueCampana>? ataques,
}) =>
    PokemonCampana(
      id: id,
      nombre: id,
      tipo: TipoCampana.normal,
      ps: ps,
      retirada: retirada,
      ataques: ataques ??
          const [
            AtaqueCampana(
                nombre: 'Placaje', tipo: TipoCampana.normal, coste: 1, dano: 30),
          ],
    );

const canto = AtaqueCampana(
  nombre: 'Canto',
  tipo: TipoCampana.normal,
  coste: 1,
  dano: 0,
  efecto: DuermeDefensor(),
);
const bofeton = AtaqueCampana(
  nombre: 'Doble Bofetón',
  tipo: TipoCampana.normal,
  coste: 2,
  dano: 20,
);

final cantante = pokemon('jiggly', ps: 70, ataques: const [canto, bofeton]);

/// El estado con el activo de [b] Dormido, sin pasar por la moneda de Canto.
EstadoCombate dormido(EstadoCombate e, Bando b) =>
    e.conBando(b, e.bando(b).copiarCon(dormido: true));

EstadoCombate inicial({
  int semilla = 1,
  int cuerdasRival = 0,
  List<PokemonCampana>? rival,
  ParametrosCombate parametros = const ParametrosCombate(),
}) =>
    EstadoCombate.inicial(
      equipoJugador: [cantante, pokemon('a2')],
      equipoRival: rival ?? [pokemon('b1', ps: 200), pokemon('b2')],
      semilla: semilla,
      cuerdasRival: cuerdasRival,
      parametros: parametros,
    );

void main() {
  group('Canto (duermeDefensor)', () {
    test('lanza una moneda; con cara duerme al Defensor y no hace daño', () {
      final vistos = <bool>{};
      for (var s = 1; s <= 60; s++) {
        final antes = inicial(semilla: s);
        final e = aplicarCombate(antes, const Atacar(Bando.jugador, 0));
        expect(e.rival.pokemonActivo.ps, 200);
        final cara = e.ultimasMonedas!.single;
        vistos.add(cara);
        if (!cara) {
          expect(e.rival.dormido, isFalse, reason: 'semilla $s');
        }
      }
      expect(vistos, {true, false});
    });

    test('con cara se duerme y en el mismo chequeo puede despertar', () {
      // El chequeo Pokémon llega al cambiar el turno, justo tras el Canto.
      final finales = <bool>{};
      for (var s = 1; s <= 80; s++) {
        final e = aplicarCombate(inicial(semilla: s), const Atacar(Bando.jugador, 0));
        if (e.ultimasMonedas!.single) finales.add(e.rival.dormido);
      }
      expect(finales, {true, false},
          reason: 'unas veces sigue dormido y otras se despierta');
    });

    test('no duerme a un Pokémon que cae con el golpe', () {
      const cantoFuerte = AtaqueCampana(
        nombre: 'Canto fuerte',
        tipo: TipoCampana.normal,
        coste: 1,
        dano: 30,
        efecto: DuermeDefensor(),
      );
      final fuerte = pokemon('f', ataques: const [cantoFuerte]);
      for (var s = 1; s <= 20; s++) {
        final e = aplicarCombate(
            EstadoCombate.inicial(
                equipoJugador: [fuerte],
                equipoRival: [pokemon('debil', ps: 30), pokemon('b2')],
                semilla: s),
            const Atacar(Bando.jugador, 0));
        expect(e.rival.dormido, isFalse);
      }
    });

    test('con 2 monedas solo duerme con dos caras', () {
      const cantoDoble = AtaqueCampana(
        nombre: 'Canto doble',
        tipo: TipoCampana.normal,
        coste: 1,
        dano: 0,
        efecto: DuermeDefensor(2),
      );
      final p = pokemon('d', ataques: const [cantoDoble]);
      for (var s = 1; s <= 60; s++) {
        final e = aplicarCombate(
            EstadoCombate.inicial(
                equipoJugador: [p],
                equipoRival: [pokemon('b1', ps: 200)],
                semilla: s),
            const Atacar(Bando.jugador, 0));
        // Dos monedas de Canto; si las dos son cara, la del chequeo no está
        // en ultimasMonedas (solo las del ataque).
        expect(e.ultimasMonedas, hasLength(2));
        if (!(e.ultimasMonedas![0] && e.ultimasMonedas![1])) {
          expect(e.rival.dormido, isFalse);
        }
      }
    });
  });

  group('Dormido', () {
    // Le toca al rival, que está Dormido.
    EstadoCombate turnoDelDormido({int semilla = 1, int cuerdas = 0}) {
      final e = aplicarCombate(
          inicial(semilla: semilla, cuerdasRival: cuerdas),
          const Cargar(Bando.jugador));
      return dormido(e, Bando.rival);
    }

    test('no puede atacar ni cambiar; sí cargar', () {
      final e = turnoDelDormido();
      expect(() => aplicarCombate(e, const Atacar(Bando.rival, 0)),
          throwsA(isA<ReglaIncumplida>()));
      expect(() => aplicarCombate(e, const Cambiar(Bando.rival, 1)),
          throwsA(isA<ReglaIncumplida>()));
      final cargado = aplicarCombate(e, const Cargar(Bando.rival));
      expect(cargado.turno, Bando.jugador);
    });

    test('se despierta con cara en el chequeo Pokémon (con la semilla)', () {
      final resultados = <bool>{};
      for (var s = 1; s <= 60; s++) {
        final e = turnoDelDormido(semilla: s);
        final tras = aplicarCombate(e, const Cargar(Bando.rival));
        resultados.add(tras.rival.dormido);
        // El mismo estado da siempre lo mismo.
        expect(aplicarCombate(e, const Cargar(Bando.rival)).rival.dormido,
            tras.rival.dormido);
        expect(tras.semilla, isNot(e.semilla), reason: 'se lanzó la moneda');
      }
      expect(resultados, {true, false});
    });

    test('la moneda se lanza en cada cambio de turno, de los dos bandos', () {
      // Tras el turno del jugador también hay chequeo para el dormido rival.
      var e = dormido(inicial(), Bando.rival);
      final despiertos = <bool>{};
      for (var s = 1; s <= 60; s++) {
        e = dormido(inicial(semilla: s), Bando.rival);
        final tras = aplicarCombate(e, const Cargar(Bando.jugador));
        despiertos.add(tras.rival.dormido);
      }
      expect(despiertos, {true, false});
    });

    test('sale con la Cuerda Huida y queda despierto en la banca', () {
      final e = aplicarCombate(
        EstadoCombate.inicial(
            equipoJugador: [cantante, pokemon('a2')],
            equipoRival: [pokemon('b1', ps: 200), pokemon('b2')],
            cuerdasRival: 1,
            parametros: const ParametrosCombate(rivalUsaObjetos: true)),
        const Cargar(Bando.jugador),
      );
      final d = dormido(e, Bando.rival);
      expect(objetivosDeCuerda(d, Bando.rival), [1]);
      final fuera = aplicarCombate(d, const UsarCuerdaHuida(Bando.rival, 1));
      expect(fuera.rival.activo, 1);
      expect(fuera.rival.dormido, isFalse);
      expect(fuera.rival.cuerdasUsadas, 1);
    });

    test('se quita si su activo cae y sale otro', () {
      var e = dormido(inicial(rival: [pokemon('b1', ps: 20), pokemon('b2')]),
          Bando.rival);
      e = aplicarCombate(e, const Atacar(Bando.jugador, 1));
      expect(e.fase, FaseCombate.eligiendoActivo);
      e = aplicarCombate(e, const ElegirSiguiente(Bando.rival, 1));
      expect(e.rival.dormido, isFalse);
    });
  });

  group('al pasar a la banca se curan los estados (D-20 §10.2)', () {
    // El rival cambia a la banca con Cambiar (los estados que lo permiten) o
    // con la Cuerda Huida (Paralizado y Dormido).
    EstadoCombate turnoRival() => aplicarCombate(
          EstadoCombate.inicial(
              equipoJugador: [pokemon('a1'), pokemon('a2')],
              equipoRival: [pokemon('b1', ps: 200), pokemon('b2')],
              cuerdasRival: 1,
              parametros: const ParametrosCombate(rivalUsaObjetos: true)),
          const Cargar(Bando.jugador),
        );

    BandoCombate trasCuerda(BandoCombate Function(BandoCombate) estado) {
      final e = turnoRival();
      final marcado = e.conBando(Bando.rival, estado(e.rival));
      return aplicarCombate(marcado, const UsarCuerdaHuida(Bando.rival, 1))
          .rival;
    }

    BandoCombate trasCambio(BandoCombate Function(BandoCombate) estado) {
      final e = turnoRival();
      final marcado = e.conBando(Bando.rival, estado(e.rival));
      return aplicarCombate(marcado, const Cambiar(Bando.rival, 1)).rival;
    }

    test('Dormido', () {
      expect(trasCuerda((b) => b.copiarCon(dormido: true)).dormido, isFalse);
    });

    test('Paralizado', () {
      expect(trasCuerda((b) => b.copiarCon(paralizado: true)).paralizado,
          isFalse);
    });

    test('Confundido', () {
      expect(trasCambio((b) => b.copiarCon(cegado: true)).cegado, isFalse);
      expect(trasCuerda((b) => b.copiarCon(cegado: true)).cegado, isFalse);
    });

    test('Envenenado (y Drenadoras)', () {
      final b = trasCambio((b) => b.copiarCon(veneno: 10, drenado: true));
      expect(b.veneno, 0);
      expect(b.drenado, isFalse);
      expect(b.equipo[0].ps, 200, reason: 'sin chequeo de veneno tras salir');
    });
  });

  group('IA', () {
    test('Dormida y sin Cuerda Huida, carga', () {
      final e = dormido(
          aplicarCombate(inicial(), const Cargar(Bando.jugador)), Bando.rival);
      expect(decidirAccion(e, Bando.rival), isA<Cargar>());
    });

    test('Dormida y débil, sale con la Cuerda Huida si la tiene', () {
      const fuego = AtaqueCampana(
          nombre: 'Ascuas', tipo: TipoCampana.fuego, coste: 1, dano: 30);
      final e0 = aplicarCombate(
        EstadoCombate.inicial(
            equipoJugador: [pokemon('f', ataques: const [fuego])],
            equipoRival: [
              PokemonCampana(
                  id: 'planta',
                  nombre: 'planta',
                  tipo: TipoCampana.planta,
                  ps: 100,
                  retirada: 0,
                  debilidad: const Debilidad(TipoCampana.fuego),
                  ataques: const [
                    AtaqueCampana(
                        nombre: 'Látigo',
                        tipo: TipoCampana.planta,
                        coste: 1,
                        dano: 30)
                  ]),
              pokemon('b2'),
            ],
            cuerdasRival: 1,
            parametros: const ParametrosCombate(rivalUsaObjetos: true)),
        const Cargar(Bando.jugador),
      );
      final e = dormido(e0, Bando.rival);
      final a = decidirAccion(e, Bando.rival);
      expect(a, isA<UsarCuerdaHuida>());
    });

    test('canta si el rival puede derribarla en su próximo turno', () {
      const fuerte = AtaqueCampana(
          nombre: 'Golpe', tipo: TipoCampana.normal, coste: 1, dano: 80);
      final e = EstadoCombate.inicial(
        equipoJugador: [pokemon('b1', ps: 200, ataques: const [fuerte])],
        equipoRival: [cantante],
        empieza: Bando.rival,
      );
      final a = decidirAccion(e, Bando.rival);
      expect(a, isA<Atacar>());
      expect((a as Atacar).indice, 0, reason: 'Canto');
    });

    test('no canta si no hay peligro, ni si el rival ya duerme', () {
      final tranquilo = EstadoCombate.inicial(
        equipoJugador: [pokemon('b1', ps: 200)],
        equipoRival: [cantante],
        empieza: Bando.rival,
      );
      expect((decidirAccion(tranquilo, Bando.rival) as Atacar).indice, 1);
      const fuerte = AtaqueCampana(
          nombre: 'Golpe', tipo: TipoCampana.normal, coste: 1, dano: 80);
      final yaDuerme = dormido(
          EstadoCombate.inicial(
            equipoJugador: [pokemon('b1', ps: 200, ataques: const [fuerte])],
            equipoRival: [cantante],
            empieza: Bando.rival,
          ),
          Bando.jugador);
      expect((decidirAccion(yaDuerme, Bando.rival) as Atacar).indice, 1);
    });
  });

  test('el catálogo lee duermeDefensor (1 moneda por defecto, nunca 0)', () {
    Map<String, dynamic> carta(Map<String, dynamic> efecto) => {
          'id': 'prueba',
          'nombre': 'Prueba',
          'tipo': 'normal',
          'ps': 70,
          'retirada': 1,
          'ataques': [
            {
              'nombre': 'Canto',
              'tipo': 'normal',
              'coste': 1,
              'dano': 0,
              'efecto': efecto,
            },
            {'nombre': 'B', 'tipo': 'normal', 'coste': 2, 'dano': 20},
          ],
        };
    final p = pokemonCampanaDesdeJson(carta({'tipo': 'duermeDefensor'}));
    expect((p.ataques.first.efecto as DuermeDefensor).monedas, 1);
    final dos =
        pokemonCampanaDesdeJson(carta({'tipo': 'duermeDefensor', 'monedas': 2}));
    expect((dos.ataques.first.efecto as DuermeDefensor).monedas, 2);
    expect(
        () => pokemonCampanaDesdeJson(
            carta({'tipo': 'duermeDefensor', 'monedas': 0})),
        throwsFormatException);
  });
}
