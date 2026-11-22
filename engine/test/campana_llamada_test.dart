import 'dart:convert';
import 'dart:io';

import 'package:incursiones_engine/campana.dart';
import 'package:incursiones_engine/incursiones_engine.dart' show ReglaIncumplida;
import 'package:test/test.dart';

// Llamada de aliado del jefe (D-20 §4, Jefes; #372).

AtaqueCampana golpe(int dano, {int coste = 1, EfectoAtaque? efecto}) =>
    AtaqueCampana(
        nombre: 'Golpe $dano',
        tipo: TipoCampana.normal,
        coste: coste,
        dano: dano,
        efecto: efecto);

PokemonCampana bicho(String id,
        {int ps = 100, List<AtaqueCampana>? ataques, int retirada = 0}) =>
    PokemonCampana(
      id: id,
      nombre: id,
      tipo: TipoCampana.normal,
      ps: ps,
      retirada: retirada,
      ataques: ataques ?? [golpe(10)],
    );

final jefe = bicho('jefe', ps: 100, ataques: [golpe(10)]);
final aliados = [bicho('aliado-a', ps: 30), bicho('aliado-b', ps: 30)];

// Sin `alFrente` el aliado entra directamente al invocarlo (un solo umbral);
// los dos pasos de Pikachu (50 % a la banca, 40 % al frente) van en su grupo.
EstadoCombate combate(List<AtaqueCampana> ataquesJugador,
        {int semilla = 1,
        int porcentaje = 50,
        int? alFrente,
        List<PokemonCampana>? jugador}) =>
    EstadoCombate.inicial(
      equipoJugador: jugador ?? [bicho('heroe', ps: 300, ataques: ataquesJugador)],
      equipoRival: [jefe],
      semilla: semilla,
      llamadaRival: LlamadaEnCombate(porcentaje, aliados, alFrente: alFrente),
    );

EstadoCombate jugar(EstadoCombate e, List<AccionCombate> acciones) {
  for (final a in acciones) {
    e = aplicarCombate(e, a);
  }
  return e;
}

void main() {
  group('cuándo llama', () {
    test('al llegar justo al 50 % llama (100 PS, queda en 50)', () {
      final e = jugar(combate([golpe(50)]), [const Atacar(Bando.jugador, 0)]);
      expect(e.llamadaHecha, isTrue);
      expect(e.rival.activo, e.aliado);
      expect(aliados.map((a) => a.id),
          contains(e.rival.pokemonActivo.especie.id));
      expect(e.rival.equipo[0].ps, 50, reason: 'el jefe guarda sus PS');
      expect(e.rival.enEspera, 0);
    });

    test('por encima del umbral no llama (queda en 60)', () {
      final e = jugar(combate([golpe(40)]), [const Atacar(Bando.jugador, 0)]);
      expect(e.llamadaHecha, isFalse);
      expect(e.rival.activo, 0);
    });

    test('si el golpe lo deja a 0 no llama: está derrotado y se gana', () {
      final e = jugar(combate([golpe(100)]), [const Atacar(Bando.jugador, 0)]);
      expect(e.llamadaHecha, isFalse);
      expect(e.fase, FaseCombate.terminado);
      expect(e.ganador, Bando.jugador);
    });

    test('el veneno también cuenta', () {
      // 40 de golpe y 10 de veneno en el chequeo: 50 PS justos.
      final e = jugar(combate([golpe(40, efecto: const EnvenenaDefensor(10))]),
          [const Atacar(Bando.jugador, 0)]);
      expect(e.llamadaHecha, isTrue);
      expect(e.rival.equipo[0].ps, 50);
    });

    test('sin llamada de aliado el combate es un 1 contra 1 normal', () {
      var e = EstadoCombate.inicial(
          equipoJugador: [bicho('heroe', ps: 300, ataques: [golpe(50)])],
          equipoRival: [jefe]);
      e = aplicarCombate(e, const Atacar(Bando.jugador, 0));
      expect(e.llamadaHecha, isFalse);
      expect(e.rival.activo, 0);
    });

    test('el aliado sale con la semilla: misma semilla, mismo aliado', () {
      final vistos = <String>{};
      for (var s = 1; s <= 40; s++) {
        final a = jugar(combate([golpe(50)], semilla: s),
            [const Atacar(Bando.jugador, 0)]);
        final b = jugar(combate([golpe(50)], semilla: s),
            [const Atacar(Bando.jugador, 0)]);
        expect(a.rival.pokemonActivo.especie.id,
            b.rival.pokemonActivo.especie.id);
        expect(a.semilla, b.semilla);
        vistos.add(a.rival.pokemonActivo.especie.id);
      }
      expect(vistos, hasLength(2), reason: 'salen los dos aliados');
    });
  });

  group('mientras está el aliado', () {
    test('el aliado juega el turno del rival con su misma energía', () {
      final e = jugar(combate([golpe(50)]), [const Atacar(Bando.jugador, 0)]);
      expect(e.turno, Bando.rival);
      final energia = e.rival.energia;
      final tras = aplicarCombate(e, const Atacar(Bando.rival, 0));
      expect(tras.rival.energia, energia - 1 + 1);
      expect(tras.jugador.pokemonActivo.ps, 290);
    });

    test('el jefe pierde los estados negativos al retirarse', () {
      // Gruñido (reduce el daño del rival) y veneno sobre el jefe; luego un
      // golpe que lo deja en el umbral.
      var e = combate([
        golpe(0, efecto: const ReduceDanoRival(10)),
        golpe(40, efecto: const EnvenenaDefensor(10)),
      ]);
      e = jugar(e, [
        const Atacar(Bando.jugador, 0),
        const Atacar(Bando.rival, 0),
        const Atacar(Bando.jugador, 1),
      ]);
      expect(e.llamadaHecha, isTrue);
      expect(e.rival.danoReducido, 0);
      expect(e.rival.veneno, 0);
      expect(e.rival.cegado, isFalse);
    });

    test('el rival no puede cambiar al jefe mientras el aliado sigue en pie', () {
      final e = jugar(combate([golpe(50)]), [const Atacar(Bando.jugador, 0)]);
      expect(e.rival.cambiables, isEmpty);
      expect(() => aplicarCombate(e, const Cambiar(Bando.rival, 0)),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('la IA no intenta devolver al jefe', () {
      // El aliado no llega a ningún ataque, que es cuando la IA busca relevo:
      // aun así no puede sacar al jefe.
      final caro = bicho('caro', ps: 30, ataques: [golpe(30, coste: 11)]);
      var e = EstadoCombate.inicial(
        equipoJugador: [bicho('heroe', ps: 300, ataques: [golpe(50)])],
        equipoRival: [jefe],
        llamadaRival: LlamadaEnCombate(50, [caro]),
      );
      e = aplicarCombate(e, const Atacar(Bando.jugador, 0));
      final accion = decidirAccion(e, Bando.rival);
      expect(accion, isNot(isA<Cambiar>()));
    });

    test('cuando cae el aliado vuelve el jefe con los PS que tenía', () {
      var e = jugar(combate([golpe(50), golpe(30)]),
          [const Atacar(Bando.jugador, 0), const Atacar(Bando.rival, 0)]);
      e = aplicarCombate(e, const Atacar(Bando.jugador, 1));
      expect(e.fase, FaseCombate.eligiendoActivo,
          reason: 'cae el aliado pero no se gana');
      expect(e.ganador, isNull);
      expect(e.debenElegir, [Bando.rival]);
      final accion = decidirAccion(e, e.actua);
      expect(accion, isA<ElegirSiguiente>());
      e = aplicarCombate(e, accion);
      expect(e.rival.activo, 0);
      expect(e.rival.pokemonActivo.ps, 50);
      expect(e.rival.enEspera, -1);
    });

    test('llama una sola vez por combate', () {
      var e = jugar(combate([golpe(50), golpe(30), golpe(10)]), [
        const Atacar(Bando.jugador, 0),
        const Atacar(Bando.rival, 0),
        const Atacar(Bando.jugador, 1),
      ]);
      e = aplicarCombate(e, const ElegirSiguiente(Bando.rival, 0));
      final aliadosEnEquipo = e.rival.equipo.length;
      e = jugar(e, [
        const Atacar(Bando.rival, 0),
        const Atacar(Bando.jugador, 2),
      ]);
      expect(e.rival.activo, 0, reason: 'el jefe sigue: no vuelve a llamar');
      expect(e.rival.equipo, hasLength(aliadosEnEquipo));
    });

    test('solo se gana cuando cae el jefe', () {
      var e = jugar(combate([golpe(50), golpe(30)]), [
        const Atacar(Bando.jugador, 0),
        const Atacar(Bando.rival, 0),
        const Atacar(Bando.jugador, 1),
      ]);
      e = aplicarCombate(e, const ElegirSiguiente(Bando.rival, 0));
      e = jugar(e, [
        const Atacar(Bando.rival, 0),
        const Atacar(Bando.jugador, 0),
      ]);
      expect(e.fase, FaseCombate.terminado);
      expect(e.ganador, Bando.jugador);
    });

    test('una llamada que no apunta a un Pokémon del rival no vale', () {
      expect(
          () => EstadoCombate.inicial(
                equipoJugador: [jefe],
                equipoRival: [jefe],
                llamadaRival: LlamadaEnCombate(50, aliados, jefe: 3),
              ),
          throwsA(isA<ReglaIncumplida>()));
      expect(
          () => EstadoCombate.inicial(
                equipoJugador: [jefe],
                equipoRival: [jefe],
                llamadaRival: const LlamadaEnCombate(50, []),
              ),
          throwsA(isA<ReglaIncumplida>()));
    });
  });

  group('en dos pasos: 50 % a la banca, 40 % al frente', () {
    EstadoCombate dosPasos(List<AtaqueCampana> ataques) =>
        combate(ataques, alFrente: 40);

    test('al 50 % invoca al aliado, que aparece en la banca', () {
      final e = jugar(dosPasos([golpe(50)]), [const Atacar(Bando.jugador, 0)]);
      expect(e.llamadaHecha, isTrue);
      expect(e.aliadoAlFrente, isFalse);
      expect(e.rival.activo, 0, reason: 'el jefe sigue delante');
      expect(e.rival.equipo, hasLength(2));
      expect(e.rival.enEspera, e.aliado);
    });

    test('el aliado no sale con Cambiar mientras espera en la banca', () {
      final e = jugar(dosPasos([golpe(50)]), [const Atacar(Bando.jugador, 0)]);
      expect(e.rival.cambiables, isEmpty);
      expect(() => aplicarCombate(e, Cambiar(Bando.rival, e.aliado!)),
          throwsA(isA<ReglaIncumplida>()));
      expect(decidirAccion(e, Bando.rival), isNot(isA<Cambiar>()));
    });

    test('el jefe conserva sus efectos mientras el aliado está en la banca', () {
      var e = dosPasos([golpe(0, efecto: const ReduceDanoRival(10)), golpe(50)]);
      e = jugar(e, [
        const Atacar(Bando.jugador, 0),
        const Atacar(Bando.rival, 0),
        const Atacar(Bando.jugador, 1),
      ]);
      expect(e.llamadaHecha, isTrue);
      expect(e.rival.danoReducido, 10);
    });

    test('al 40 % el jefe se retira (sin efectos) y el aliado pasa al frente',
        () {
      var e = dosPasos([golpe(50), golpe(10, efecto: const ReduceDanoRival(10))]);
      e = jugar(e, [
        const Atacar(Bando.jugador, 0),
        const Atacar(Bando.rival, 0),
        const Atacar(Bando.jugador, 1),
      ]);
      expect(e.aliadoAlFrente, isTrue);
      expect(e.rival.activo, e.aliado);
      expect(e.rival.equipo[0].ps, 40);
      expect(e.rival.enEspera, 0);
      expect(e.rival.danoReducido, 0, reason: 'pierde todos los efectos');
    });

    test('un golpe que cruza los dos umbrales lo pone delante directamente',
        () {
      final e = jugar(dosPasos([golpe(60)]), [const Atacar(Bando.jugador, 0)]);
      expect(e.llamadaHecha, isTrue);
      expect(e.aliadoAlFrente, isTrue);
      expect(e.rival.activo, e.aliado);
      expect(e.rival.equipo[0].ps, 40);
    });

    test('si el jefe cae con el aliado en la banca, se gana', () {
      final e = jugar(dosPasos([golpe(50)]), [
        const Atacar(Bando.jugador, 0),
        const Atacar(Bando.rival, 0),
        const Atacar(Bando.jugador, 0),
      ]);
      expect(e.fase, FaseCombate.terminado);
      expect(e.ganador, Bando.jugador);
      expect(e.rival.equipo[e.aliado!].enPie, isTrue);
    });

    test('el jefe vuelve con sus PS y no vuelve a cambiarse', () {
      var e = dosPasos([golpe(60), golpe(30), golpe(10)]);
      e = jugar(e, [
        const Atacar(Bando.jugador, 0),
        const Atacar(Bando.rival, 0),
        const Atacar(Bando.jugador, 1),
      ]);
      expect(e.debenElegir, [Bando.rival]);
      e = aplicarCombate(e, decidirAccion(e, e.actua));
      expect(e.rival.activo, 0);
      expect(e.rival.pokemonActivo.ps, 40);
      e = jugar(e, [
        const Atacar(Bando.rival, 0),
        const Atacar(Bando.jugador, 2),
      ]);
      expect(e.rival.activo, 0);
      expect(e.rival.equipo, hasLength(2));
    });

    test('un segundo umbral mayor que el primero no vale', () {
      expect(
          () => EstadoCombate.inicial(
                equipoJugador: [jefe],
                equipoRival: [jefe],
                llamadaRival: LlamadaEnCombate(40, aliados, alFrente: 50),
              ),
          throwsA(isA<ReglaIncumplida>()));
    });
  });

  group('Pikachu del catálogo', () {
    Map<String, dynamic> leer(String ruta) =>
        jsonDecode(File(ruta).readAsStringSync()) as Map<String, dynamic>;
    final pokemon = <String, PokemonCampana>{
      for (final f in Directory('../catalog/campana/pokemon')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json')))
        pokemonCampanaDesdeJson(leer(f.path)).id:
            pokemonCampanaDesdeJson(leer(f.path)),
    };
    final pikachu =
        jefeCampanaDesdeJson(leer('../catalog/campana/jefes/pikachu-jefe.json'));

    test('su llamada sale del catálogo con sus cuatro aliados', () {
      final l = llamadaEnCombate(pikachu, pokemon)!;
      expect(l.porcentaje, 50);
      expect(l.alFrente, 40);
      expect(l.aliados.map((a) => a.id),
          ['weedle', 'caterpie', 'metapod', 'kakuna']);
    });

    test('un aliado que no está en el catálogo es un error', () {
      expect(() => llamadaEnCombate(pikachu, const {}),
          throwsA(isA<FormatException>()));
    });

    test('los combates con la IA en los dos bandos terminan', () {
      final l = llamadaEnCombate(pikachu, pokemon)!;
      for (final inicial in ['bulbasaur', 'charmander', 'squirtle']) {
        for (var s = 1; s <= 30; s++) {
          var e = EstadoCombate.inicial(
            equipoJugador: [pokemon[inicial]!, pokemon['mankey']!],
            equipoRival: [pikachu.pokemon],
            semilla: s,
            llamadaRival: l,
          );
          for (var i = 0; i < 500 && e.fase != FaseCombate.terminado; i++) {
            e = aplicarCombate(e, decidirAccion(e, e.actua));
          }
          expect(e.fase, FaseCombate.terminado, reason: '$inicial, semilla $s');
          if (e.ganador == Bando.jugador) {
            expect(e.rival.equipo[0].enPie, isFalse,
                reason: 'se gana derrotando al jefe');
          }
        }
      }
    });
  });
}
