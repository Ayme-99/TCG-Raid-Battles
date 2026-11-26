// Indicador ignoraFallo (Rapidez de Starmie, D-20 §3.6 y §4; #524). Starmie
// aún no está en el catálogo: se prueba con cartas de prueba.
import 'package:incursiones_engine/campana.dart';
import 'package:test/test.dart';

const rapidez = AtaqueCampana(
  nombre: 'Rapidez',
  tipo: TipoCampana.normal,
  coste: 2,
  dano: 50,
  ignoraFallo: true,
);
const golpe = AtaqueCampana(
    nombre: 'Golpe', tipo: TipoCampana.normal, coste: 2, dano: 50);

PokemonCampana pokemon(String id,
        {int ps = 100, List<AtaqueCampana> ataques = const [golpe]}) =>
    PokemonCampana(
      id: id,
      nombre: id,
      tipo: TipoCampana.normal,
      ps: ps,
      retirada: 0,
      ataques: ataques,
    );

final starmie = pokemon('starmie', ataques: const [golpe, rapidez]);

/// El jugador ataca con [indice] marcado con [marca] (Bofetón Lodo, Pantalla
/// de Humo o Confusión).
EstadoCombate atacarCon(int indice, BandoCombate Function(BandoCombate) marca,
    {int semilla = 1}) {
  var e = EstadoCombate.inicial(
      equipoJugador: [starmie],
      equipoRival: [pokemon('b', ps: 200)],
      semilla: semilla);
  e = e.conBando(Bando.jugador, marca(e.jugador));
  return aplicarCombate(e, Atacar(Bando.jugador, indice));
}

void main() {
  group('con la moneda de fallo del rival', () {
    for (final (nombre, marca) in [
      ('Bofetón Lodo', (BandoCombate b) => b.copiarCon(cegado: true)),
      (
        'Pantalla de Humo',
        (BandoCombate b) => b.copiarCon(cegadoMientrasActivo: true)
      ),
    ]) {
      test('$nombre: Rapidez no lanza la moneda y siempre pega', () {
        for (var s = 1; s <= 30; s++) {
          final e = atacarCon(1, marca, semilla: s);
          expect(e.rival.pokemonActivo.ps, 150);
          expect(e.ultimasMonedas, isNull);
        }
      });

      test('$nombre: sin el indicador, lanza la moneda y a veces falla', () {
        final danos = <int>{};
        for (var s = 1; s <= 30; s++) {
          final e = atacarCon(0, marca, semilla: s);
          expect(e.ultimasMonedas, hasLength(1));
          danos.add(200 - e.rival.pokemonActivo.ps);
        }
        expect(danos, {0, 50});
      });
    }
  });

  test('sin efecto de fallo, Rapidez es un ataque normal', () {
    final e = atacarCon(1, (b) => b);
    expect(e.rival.pokemonActivo.ps, 150);
    expect(e.ultimasMonedas, isNull);
  });

  test('Confundido: Rapidez sí lanza la moneda (recomendación de Dirección)',
      () {
    final danos = <int>{};
    for (var s = 1; s <= 30; s++) {
      final e = atacarCon(1, (b) => b.copiarCon(confundido: true), semilla: s);
      expect(e.ultimasMonedas, hasLength(1));
      danos.add(200 - e.rival.pokemonActivo.ps);
    }
    expect(danos, {0, 50});
  });

  test('Pantalla de Humo sigue puesta tras Rapidez', () {
    final e = atacarCon(1, (b) => b.copiarCon(cegadoMientrasActivo: true));
    expect(e.jugador.cegadoMientrasActivo, isTrue);
  });

  group('IA', () {
    EstadoCombate marcado(BandoCombate Function(BandoCombate) marca,
        {int psRival = 200}) {
      final e = EstadoCombate.inicial(
          equipoJugador: [starmie], equipoRival: [pokemon('b', ps: psRival)]);
      return e.conBando(Bando.jugador, marca(e.jugador));
    }

    test('con Bofetón Lodo encima, elige Rapidez', () {
      final a = decidirAccion(
          marcado((b) => b.copiarCon(cegado: true)), Bando.jugador) as Atacar;
      expect(a.indice, 1);
    });

    test('para rematar con la moneda de fallo, también Rapidez', () {
      final a = decidirAccion(
          marcado((b) => b.copiarCon(cegadoMientrasActivo: true), psRival: 50),
          Bando.jugador) as Atacar;
      expect(a.indice, 1);
    });

    test('Confundido no cambia nada: el primero de los dos iguales', () {
      final a = decidirAccion(
          marcado((b) => b.copiarCon(confundido: true)), Bando.jugador) as Atacar;
      expect(a.indice, 0);
    });
  });

  test('Supersónico deja Confundido, no la moneda de Bofetón Lodo', () {
    const supersonico = AtaqueCampana(
      nombre: 'Supersónico',
      tipo: TipoCampana.oscuridad,
      coste: 1,
      dano: 0,
      efecto: ConfundeDefensor(),
    );
    for (var s = 1; s <= 30; s++) {
      final e = aplicarCombate(
          EstadoCombate.inicial(
              equipoJugador: [pokemon('z', ataques: const [supersonico])],
              equipoRival: [pokemon('b')],
              semilla: s),
          const Atacar(Bando.jugador, 0));
      expect(e.rival.cegado, isFalse);
      expect(e.rival.confundido, e.ultimaMoneda);
    }
  });

  test('el catálogo lee ignoraFallo (false si no está)', () {
    final p = pokemonCampanaDesdeJson({
      'id': 'prueba',
      'nombre': 'Prueba',
      'tipo': 'agua',
      'ps': 110,
      'retirada': 1,
      'ataques': [
        {'nombre': 'A', 'tipo': 'agua', 'coste': 1, 'dano': 20},
        {
          'nombre': 'Rapidez',
          'tipo': 'normal',
          'coste': 2,
          'dano': 50,
          'ignoraFallo': true,
        },
      ],
    });
    expect(p.ataques[0].ignoraFallo, isFalse);
    expect(p.ataques[1].ignoraFallo, isTrue);
  });
}
