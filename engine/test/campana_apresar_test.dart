// Efecto apresaDefensor (Torbellino de Shellder y Constricción de Ekans,
// D-20 §3.6 y §4; #522). Shellder y Ekans aún no están en el catálogo: se
// prueba con cartas de prueba.
import 'package:incursiones_engine/campana.dart';
import 'package:test/test.dart';

const torbellino = AtaqueCampana(
  nombre: 'Torbellino',
  tipo: TipoCampana.agua,
  coste: 2,
  dano: 10,
  efecto: ApresaDefensor(),
);
const placaje =
    AtaqueCampana(nombre: 'Placaje', tipo: TipoCampana.normal, coste: 1, dano: 30);
const mordisco = AtaqueCampana(
    nombre: 'Mordisco', tipo: TipoCampana.oscuridad, coste: 2, dano: 30);

PokemonCampana pokemon(String id,
        {int ps = 100,
        int retirada = 0,
        HabilidadCampana? habilidad,
        List<AtaqueCampana> ataques = const [placaje]}) =>
    PokemonCampana(
      id: id,
      nombre: id,
      tipo: TipoCampana.normal,
      ps: ps,
      retirada: retirada,
      habilidad: habilidad,
      ataques: ataques,
    );

final shellder = pokemon('shellder', ps: 60, ataques: const [torbellino]);

/// El estado con el activo de [b] Apresado, sin pasar por el ataque.
EstadoCombate apresado(EstadoCombate e, Bando b) =>
    e.conBando(b, e.bando(b).copiarCon(apresado: true));

void main() {
  test('Torbellino hace su daño y apresa al Defensor', () {
    final e = aplicarCombate(
        EstadoCombate.inicial(
            equipoJugador: [shellder], equipoRival: [pokemon('b')], semilla: 3),
        const Atacar(Bando.jugador, 0));
    // 10 del golpe y 10 del primer chequeo, que llega al cambiar el turno.
    expect(e.rival.pokemonActivo.ps, 80);
  });

  test('el primer chequeo quita 10 y lanza la moneda (con la semilla)', () {
    final vistos = <bool>{};
    for (var s = 1; s <= 60; s++) {
      final e = aplicarCombate(
          EstadoCombate.inicial(
              equipoJugador: [shellder], equipoRival: [pokemon('b')], semilla: s),
          const Atacar(Bando.jugador, 0));
      expect(e.rival.pokemonActivo.ps, 80);
      vistos.add(e.rival.apresado);
    }
    expect(vistos, {true, false}, reason: 'unas veces se libera y otras no');
  });

  test('cada chequeo quita 10 mientras siga apresado', () {
    var e = apresado(
        EstadoCombate.inicial(
            equipoJugador: [pokemon('a')], equipoRival: [pokemon('b')]),
        Bando.rival);
    var ps = 100;
    for (var i = 0; i < 20 && e.rival.apresado; i++) {
      final antes = e;
      e = aplicarCombate(e, Cargar(e.turno));
      ps -= 10;
      expect(e.rival.pokemonActivo.ps, ps);
      expect(e.semilla, isNot(antes.semilla));
    }
    expect(e.rival.apresado, isFalse, reason: 'acaba liberándose');
    final tras = aplicarCombate(e, Cargar(e.turno));
    expect(tras.rival.pokemonActivo.ps, ps, reason: 'libre, ya no pierde PS');
  });

  test('no puede retirarse; con la Cuerda Huida sí, y sale curado', () {
    var e = EstadoCombate.inicial(
      equipoJugador: [pokemon('a')],
      equipoRival: [pokemon('b1'), pokemon('b2')],
      cuerdasRival: 1,
      parametros: const ParametrosCombate(rivalUsaObjetos: true),
    );
    e = apresado(aplicarCombate(e, const Cargar(Bando.jugador)), Bando.rival);
    expect(() => aplicarCombate(e, const Cambiar(Bando.rival, 1)),
        throwsA(isA<ReglaIncumplida>()));
    // Puede atacar y cargar.
    aplicarCombate(e, const Atacar(Bando.rival, 0));
    final fuera = aplicarCombate(e, const UsarCuerdaHuida(Bando.rival, 1));
    expect(fuera.rival.activo, 1);
    expect(fuera.rival.apresado, isFalse);
    expect(fuera.rival.equipo[1].ps, 100, reason: 'el que sale no pierde PS');
  });

  test('el chequeo puede derribarlo y entonces hay que elegir relevo', () {
    var e = apresado(
        EstadoCombate.inicial(
            equipoJugador: [pokemon('a')],
            equipoRival: [pokemon('b1', ps: 10), pokemon('b2')]),
        Bando.rival);
    e = aplicarCombate(e, const Cargar(Bando.jugador));
    expect(e.rival.equipo[0].ps, 0);
    expect(e.fase, FaseCombate.eligiendoActivo);
    e = aplicarCombate(e, const ElegirSiguiente(Bando.rival, 1));
    expect(e.rival.apresado, isFalse);
  });

  test('con el último Pokémon, el chequeo termina el combate', () {
    final e = aplicarCombate(
        apresado(
            EstadoCombate.inicial(
                equipoJugador: [pokemon('a')],
                equipoRival: [pokemon('b1', ps: 10)]),
            Bando.rival),
        const Cargar(Bando.jugador));
    expect(e.fase, FaseCombate.terminado);
    expect(e.ganador, Bando.jugador);
  });

  test('Muro Mágico: no pierde PS, pero sigue apresado y puede liberarse', () {
    final clefairy =
        pokemon('clefairy', habilidad: const SinDanoIndirecto('Muro Mágico'));
    final vistos = <bool>{};
    for (var s = 1; s <= 40; s++) {
      var e = EstadoCombate.inicial(
          equipoJugador: [pokemon('a')],
          equipoRival: [clefairy, pokemon('b2')],
          semilla: s);
      e = apresado(aplicarCombate(e, const Cargar(Bando.jugador)), Bando.rival);
      expect(() => aplicarCombate(e, const Cambiar(Bando.rival, 1)),
          throwsA(isA<ReglaIncumplida>()));
      final tras = aplicarCombate(e, const Cargar(Bando.rival));
      expect(tras.rival.pokemonActivo.ps, 100);
      expect(tras.semilla, isNot(e.semilla), reason: 'la moneda se lanza');
      vistos.add(tras.rival.apresado);
    }
    expect(vistos, {true, false});
  });

  group('IA', () {
    test('apresa solo si el golpe más 20 supera a su mejor ataque', () {
      const constriccion = AtaqueCampana(
        nombre: 'Constricción',
        tipo: TipoCampana.oscuridad,
        coste: 2,
        dano: 10,
        efecto: ApresaDefensor(),
      );
      final ekans = pokemon('ekans', ataques: const [constriccion, mordisco]);
      final e = EstadoCombate.inicial(
          equipoJugador: [ekans], equipoRival: [pokemon('b', ps: 200)]);
      // Ekans: 10 + 20 iguala a Mordisco (30), así que muerde.
      expect((decidirAccion(e, Bando.jugador) as Atacar).indice, 1);
      // Shellder: Torbellino es su único golpe, así que apresa.
      final s = EstadoCombate.inicial(
          equipoJugador: [shellder], equipoRival: [pokemon('b', ps: 200)]);
      expect((decidirAccion(s, Bando.jugador) as Atacar).indice, 0);
      // Ekans con el rival ya apresado sigue mordiendo.
      final ya = apresado(e, Bando.rival);
      expect((decidirAccion(ya, Bando.jugador) as Atacar).indice, 1);
      // Contra Muro Mágico, tampoco apresa.
      final muro = EstadoCombate.inicial(equipoJugador: [
        ekans
      ], equipoRival: [
        pokemon('c', ps: 200, habilidad: const SinDanoIndirecto('Muro Mágico'))
      ]);
      expect((decidirAccion(muro, Bando.jugador) as Atacar).indice, 1);
    });

    test('apresada y débil no intenta cambiar: usa la Cuerda si la tiene', () {
      const fuego = AtaqueCampana(
          nombre: 'Ascuas', tipo: TipoCampana.fuego, coste: 1, dano: 30);
      final planta = PokemonCampana(
        id: 'planta',
        nombre: 'planta',
        tipo: TipoCampana.planta,
        ps: 100,
        retirada: 0,
        debilidad: const Debilidad(TipoCampana.fuego),
        ataques: const [placaje],
      );
      EstadoCombate con(int cuerdas) => apresado(
          aplicarCombate(
              EstadoCombate.inicial(
                  equipoJugador: [pokemon('f', ataques: const [fuego])],
                  equipoRival: [planta, pokemon('b2')],
                  cuerdasRival: cuerdas,
                  parametros: const ParametrosCombate(rivalUsaObjetos: true)),
              const Cargar(Bando.jugador)),
          Bando.rival);
      expect(decidirAccion(con(1), Bando.rival), isA<UsarCuerdaHuida>());
      final sin = decidirAccion(con(0), Bando.rival);
      expect(sin, isNot(isA<Cambiar>()));
      aplicarCombate(con(0), sin); // es una acción válida
    });
  });

  test('el catálogo lee apresaDefensor', () {
    final p = pokemonCampanaDesdeJson({
      'id': 'prueba',
      'nombre': 'Prueba',
      'tipo': 'agua',
      'ps': 60,
      'retirada': 0,
      'ataques': [
        {
          'nombre': 'Torbellino',
          'tipo': 'agua',
          'coste': 2,
          'dano': 10,
          'efecto': {'tipo': 'apresaDefensor'},
        },
        {'nombre': 'B', 'tipo': 'agua', 'coste': 2, 'dano': 20},
      ],
    });
    expect(p.ataques.first.efecto, isA<ApresaDefensor>());
  });
}
