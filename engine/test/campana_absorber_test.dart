// Efecto curaAlAtacar (Absorber de Paras, D-20 §3.6 y §4; #523). Paras aún
// no está en el catálogo: se prueba con cartas de prueba.
import 'package:incursiones_engine/campana.dart';
import 'package:test/test.dart';

const absorber = AtaqueCampana(
  nombre: 'Absorber',
  tipo: TipoCampana.planta,
  coste: 1,
  dano: 20,
  efecto: CuraAlAtacar(10),
);
const placaje =
    AtaqueCampana(nombre: 'Placaje', tipo: TipoCampana.normal, coste: 1, dano: 30);

PokemonCampana pokemon(String id,
        {int ps = 100, List<AtaqueCampana> ataques = const [placaje]}) =>
    PokemonCampana(
      id: id,
      nombre: id,
      tipo: TipoCampana.normal,
      ps: ps,
      retirada: 0,
      ataques: ataques,
    );

final paras = pokemon('paras', ps: 60, ataques: const [absorber]);

EstadoCombate conPs(EstadoCombate e, Bando b, int ps) => e.conBando(
    b,
    e.bando(b).copiarCon(
        equipo: [...e.bando(b).equipo]..[e.bando(b).activo] =
            e.bando(b).pokemonActivo.conPs(ps)));

void main() {
  test('hace su daño y después se cura 10', () {
    var e = EstadoCombate.inicial(
        equipoJugador: [paras], equipoRival: [pokemon('b')]);
    e = aplicarCombate(conPs(e, Bando.jugador, 30), const Atacar(Bando.jugador, 0));
    expect(e.rival.pokemonActivo.ps, 80);
    expect(e.jugador.pokemonActivo.ps, 40);
  });

  test('no pasa de sus PS máximos', () {
    var e = EstadoCombate.inicial(
        equipoJugador: [paras], equipoRival: [pokemon('b')]);
    e = aplicarCombate(conPs(e, Bando.jugador, 55), const Atacar(Bando.jugador, 0));
    expect(e.jugador.pokemonActivo.ps, 60);
    final lleno = aplicarCombate(
        EstadoCombate.inicial(equipoJugador: [paras], equipoRival: [pokemon('b')]),
        const Atacar(Bando.jugador, 0));
    expect(lleno.jugador.pokemonActivo.ps, 60);
  });

  test('cura aunque el Defensor caiga (y aunque gane el combate)', () {
    var e = EstadoCombate.inicial(
        equipoJugador: [paras], equipoRival: [pokemon('b', ps: 20), pokemon('c')]);
    e = aplicarCombate(conPs(e, Bando.jugador, 30), const Atacar(Bando.jugador, 0));
    expect(e.rival.equipo[0].ps, 0);
    expect(e.jugador.pokemonActivo.ps, 40);
    var fin = EstadoCombate.inicial(
        equipoJugador: [paras], equipoRival: [pokemon('b', ps: 20)]);
    fin = aplicarCombate(
        conPs(fin, Bando.jugador, 30), const Atacar(Bando.jugador, 0));
    expect(fin.fase, FaseCombate.terminado);
    expect(fin.jugador.pokemonActivo.ps, 40);
  });

  test('cura aunque el golpe quede en 0 (Gruñido)', () {
    var e = EstadoCombate.inicial(
        equipoJugador: [paras], equipoRival: [pokemon('b')]);
    e = conPs(e, Bando.jugador, 30);
    e = e.conBando(Bando.jugador, e.jugador.copiarCon(danoReducido: 20));
    e = aplicarCombate(e, const Atacar(Bando.jugador, 0));
    expect(e.rival.pokemonActivo.ps, 100);
    expect(e.jugador.pokemonActivo.ps, 40);
  });

  test('si falla por la moneda (Bofetón Lodo con cruz), no cura', () {
    final vistos = <bool>{};
    for (var s = 1; s <= 40; s++) {
      var e = EstadoCombate.inicial(
          equipoJugador: [paras], equipoRival: [pokemon('b')], semilla: s);
      e = conPs(e, Bando.jugador, 30);
      e = e.conBando(Bando.jugador, e.jugador.copiarCon(cegado: true));
      e = aplicarCombate(e, const Atacar(Bando.jugador, 0));
      final cara = e.ultimasMonedas!.first;
      vistos.add(cara);
      expect(e.jugador.pokemonActivo.ps, cara ? 40 : 30);
      expect(e.rival.pokemonActivo.ps, cara ? 80 : 100);
    }
    expect(vistos, {true, false});
  });

  test('IA: lo usa como cualquier ataque de daño', () {
    final e = EstadoCombate.inicial(
        equipoJugador: [paras], equipoRival: [pokemon('b')]);
    expect((decidirAccion(e, Bando.jugador) as Atacar).indice, 0);
  });

  test('el catálogo lee curaAlAtacar (valor múltiplo de 10)', () {
    Map<String, dynamic> carta(Map<String, dynamic> efecto) => {
          'id': 'prueba',
          'nombre': 'Prueba',
          'tipo': 'planta',
          'ps': 60,
          'retirada': 1,
          'ataques': [
            {
              'nombre': 'Absorber',
              'tipo': 'planta',
              'coste': 1,
              'dano': 20,
              'efecto': efecto,
            },
          ],
        };
    final p = pokemonCampanaDesdeJson(
        carta({'tipo': 'curaAlAtacar', 'valor': 10}));
    expect((p.ataques.single.efecto as CuraAlAtacar).valor, 10);
    expect(
        () => pokemonCampanaDesdeJson(
            carta({'tipo': 'curaAlAtacar', 'valor': 15})),
        throwsFormatException);
    expect(() => pokemonCampanaDesdeJson(carta({'tipo': 'curaAlAtacar'})),
        throwsFormatException);
  });
}
