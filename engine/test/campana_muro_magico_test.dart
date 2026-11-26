// Muro Mágico (habilidad sinDanoIndirecto de Clefairy jefe, D-20 §3.6 y §4;
// #512): solo le hacen daño los ataques. Clefairy jefe aún no está en el
// catálogo (#513): se prueba con cartas de prueba.
import 'package:incursiones_engine/campana.dart';
import 'package:test/test.dart';

const placaje =
    AtaqueCampana(nombre: 'Placaje', tipo: TipoCampana.normal, coste: 1, dano: 30);
const picotazo = AtaqueCampana(
  nombre: 'Picotazo Veneno',
  tipo: TipoCampana.oscuridad,
  coste: 1,
  dano: 10,
  efecto: EnvenenaDefensor(10),
);
const drenadoras = AtaqueCampana(
  nombre: 'Drenadoras',
  tipo: TipoCampana.planta,
  coste: 2,
  dano: 0,
  efecto: DrenaDefensor(),
);

PokemonCampana pokemon(String id,
        {int ps = 100,
        HabilidadCampana? habilidad,
        List<AtaqueCampana> ataques = const [placaje]}) =>
    PokemonCampana(
      id: id,
      nombre: id,
      tipo: TipoCampana.normal,
      ps: ps,
      retirada: 0,
      habilidad: habilidad,
      ataques: ataques,
    );

final clefairy =
    pokemon('clefairy', habilidad: const SinDanoIndirecto('Muro Mágico'));

void main() {
  test('envenenado: el estado se pone pero no pierde PS', () {
    var e = EstadoCombate.inicial(
      equipoJugador: [pokemon('weedle', ataques: const [picotazo])],
      equipoRival: [clefairy],
    );
    e = aplicarCombate(e, const Atacar(Bando.jugador, 0));
    expect(e.rival.veneno, 10, reason: 'sí queda Envenenado');
    expect(e.rival.pokemonActivo.ps, 90, reason: 'solo el golpe de 10');
    e = aplicarCombate(e, const Cargar(Bando.rival));
    e = aplicarCombate(e, const Cargar(Bando.jugador));
    expect(e.rival.pokemonActivo.ps, 90, reason: 'el veneno no le quita PS');
    expect(e.rival.veneno, 10);
  });

  test('Drenadoras: ni le quita PS ni cura al que la usó', () {
    var e = EstadoCombate.inicial(
      equipoJugador: [pokemon('ivysaur', ataques: const [drenadoras])],
      equipoRival: [clefairy],
    );
    // El jugador, herido, para ver si se cura.
    e = e.conBando(
        Bando.jugador,
        e.jugador.copiarCon(
            equipo: [e.jugador.pokemonActivo.conPs(50)]));
    e = aplicarCombate(e, const Atacar(Bando.jugador, 0));
    expect(e.rival.drenado, isTrue);
    e = aplicarCombate(e, const Cargar(Bando.rival));
    expect(e.rival.pokemonActivo.ps, 100);
    expect(e.jugador.pokemonActivo.ps, 50, reason: 'no se cura');
  });

  test('los ataques sí le hacen daño', () {
    final e = aplicarCombate(
        EstadoCombate.inicial(
            equipoJugador: [pokemon('a')], equipoRival: [clefairy]),
        const Atacar(Bando.jugador, 0));
    expect(e.rival.pokemonActivo.ps, 70);
  });

  test('solo cuenta para el propio activo: su compañero sí pierde PS', () {
    var e = EstadoCombate.inicial(
      equipoJugador: [pokemon('a')],
      equipoRival: [clefairy, pokemon('b')],
      empieza: Bando.rival,
    );
    // Clefairy se va a la banca y el envenenado es el que sale.
    e = aplicarCombate(e, const Cambiar(Bando.rival, 1));
    e = e.conBando(Bando.rival, e.rival.copiarCon(veneno: 10));
    e = aplicarCombate(e, const Cargar(Bando.jugador));
    expect(e.rival.pokemonActivo.especie.id, 'b');
    expect(e.rival.pokemonActivo.ps, 90);
  });

  test('no protege al rival: el veneno del otro bando sigue igual', () {
    var e = EstadoCombate.inicial(
      equipoJugador: [pokemon('a')],
      equipoRival: [clefairy],
    );
    e = e.conBando(Bando.jugador, e.jugador.copiarCon(veneno: 10));
    e = aplicarCombate(e, const Cargar(Bando.jugador));
    expect(e.jugador.pokemonActivo.ps, 90);
  });

  test('IA: no envenena a un rival con Muro Mágico', () {
    final weedle = pokemon('weedle', ataques: const [picotazo, placaje]);
    final contra = EstadoCombate.inicial(
        equipoJugador: [weedle], equipoRival: [clefairy]);
    final accion = decidirAccion(contra, Bando.jugador) as Atacar;
    expect(accion.indice, 1);
    final normal = EstadoCombate.inicial(
        equipoJugador: [weedle], equipoRival: [pokemon('b')]);
    expect((decidirAccion(normal, Bando.jugador) as Atacar).indice, 0);
  });

  test('el catálogo lee sinDanoIndirecto, sin valor', () {
    Map<String, dynamic> carta(Map<String, dynamic> h) => {
          'id': 'prueba',
          'nombre': 'Prueba',
          'tipo': 'normal',
          'ps': 100,
          'retirada': 1,
          'habilidad': h,
          'ataques': [
            {'nombre': 'A', 'tipo': 'normal', 'coste': 1, 'dano': 20},
          ],
        };
    final p = pokemonCampanaDesdeJson(
        carta({'nombre': 'Muro Mágico', 'tipo': 'sinDanoIndirecto'}));
    expect(p.habilidad, isA<SinDanoIndirecto>());
    expect(p.habilidad!.nombre, 'Muro Mágico');
    expect(sinDanoIndirecto(p), isTrue);
    expect(
        () => pokemonCampanaDesdeJson(carta(
            {'nombre': 'Muro Mágico', 'tipo': 'sinDanoIndirecto', 'valor': 10})),
        throwsFormatException);
  });
}
