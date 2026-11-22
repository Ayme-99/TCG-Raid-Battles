import 'dart:convert';
import 'dart:io';

import 'package:incursiones_engine/campana.dart';
import 'package:incursiones_engine/incursiones_engine.dart'
    show ReglaIncumplida;
import 'package:test/test.dart';

Map<String, dynamic> leer(File f) =>
    jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;

List<File> jsonDe(String carpeta) => Directory(carpeta)
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.json'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

String idDe(File f) => f.uri.pathSegments.last.replaceAll('.json', '');

CatalogoCampana kanto() => CatalogoCampana.desdeJson(
      pokemon: [for (final f in jsonDe('../catalog/campana/pokemon')) leer(f)],
      zonas: [for (final f in jsonDe('../catalog/campana/zonas')) leer(f)],
      jefes: {
        for (final f in jsonDe('../catalog/campana/jefes')) idDe(f): leer(f),
      },
      region: leer(File('../catalog/campana/regiones/kanto.json')),
    );

/// Juega un combate con la IA en los dos bandos.
EstadoCombate jugarSolo(EstadoCombate e) {
  var s = e;
  var pasos = 0;
  while (s.fase != FaseCombate.terminado) {
    s = aplicarCombate(s, decidirAccion(s, s.actua));
    if (++pasos > 500) fail('El combate no termina.');
  }
  return s;
}

/// Avanza hasta el combate de [nodo] por el camino principal.
PartidaCampana hasta(CatalogoCampana c, PartidaCampana p, String nodo) {
  var s = p;
  var combates = 0;
  while (s.progreso.nodoActual != nodo) {
    if (s.hayCombate(c)) {
      s = s.terminarCombate(c, jugarSolo(s.empezarCombate(c)));
      if (s.capturaPendiente != null) s = s.capturar(c);
      if (++combates > 200) fail('No llega a $nodo.');
      continue;
    }
    if (s.nodoActual(c).tipo == TipoNodo.descanso && !s.progreso.resuelto) {
      s = s.descansar(c);
      continue;
    }
    final op = s.opciones(c);
    s = s.avanzar(c, op.last);
  }
  return s;
}

void main() {
  final c = kanto();

  test('el catálogo del primer tramo está completo', () {
    expect(c.problemas(), isEmpty);
  });

  test('elegir inicial lo pone en el equipo con todos sus PS', () {
    final p = PartidaCampana.nueva(c.region).elegirInicial(c, 'charmander');
    expect(p.equipo.single.id, 'charmander');
    expect(p.equipo.single.ps, 70);
    expect(p.opciones(c), ['ruta-1']);
    expect(() => PartidaCampana.nueva(c.region).elegirInicial(c, 'pikachu'),
        throwsA(isA<ReglaIncumplida>()));
  });

  test('el rival salvaje sale de la zona y es el mismo con la misma semilla',
      () {
    final p = PartidaCampana.nueva(c.region, semilla: 7)
        .elegirInicial(c, 'squirtle')
        .avanzar(c, 'ruta-1');
    final r = p.rival(c);
    expect(['pidgey', 'rattata'], contains(r.equipo.single.id));
    expect(r.captura, r.equipo.single.id);
    expect(r.puntos, 100);
    expect(p.rival(c).equipo.single.id, r.equipo.single.id);
  });

  test('ganar resuelve el nodo, suma puntos, conserva los PS y ofrece captura',
      () {
    var p = PartidaCampana.nueva(c.region, semilla: 3)
        .elegirInicial(c, 'bulbasaur')
        .avanzar(c, 'ruta-1');
    final fin = jugarSolo(p.empezarCombate(c));
    expect(fin.ganador, Bando.jugador);
    final semilla = p.semilla;
    p = p.terminarCombate(c, fin);
    expect(p.progreso.resuelto, isTrue);
    expect(p.puntos, 100);
    expect(p.equipo.single.ps, fin.jugador.equipo.single.ps);
    expect(p.capturaPendiente, isNotNull);
    expect(p.semilla, isNot(semilla));
    expect(p.opciones(c), isEmpty, reason: 'antes hay que decidir la captura');
    expect(() => p.avanzar(c, 'ciudad-verde'), throwsA(isA<ReglaIncumplida>()));
    final capturado = p.capturaPendiente;
    p = p.capturar(c);
    expect(p.equipo.map((e) => e.id), ['bulbasaur', capturado]);
    expect(p.opciones(c), ['ciudad-verde']);
  });

  test('perder cura al equipo y le devuelve al último sitio donde se curó', () {
    var p = PartidaCampana.nueva(c.region)
        .elegirInicial(c, 'bulbasaur')
        .avanzar(c, 'ruta-1');
    expect(p.ultimaCura, 'pueblo-paleta');
    final e = p.empezarCombate(c);
    // Se rinde: el rival le deja a 0.
    final perdido = e.copiarCon(
      jugador: e.jugador.copiarCon(equipo: [e.jugador.equipo.single.conPs(0)]),
      fase: FaseCombate.terminado,
      ganador: Bando.rival,
    );
    p = p.terminarCombate(c, perdido);
    expect(p.progreso.nodoActual, 'pueblo-paleta');
    expect(p.progreso.resuelto, isTrue);
    expect(p.opciones(c), ['ruta-1']);
    expect(p.equipo.single.ps, 90);
    expect(p.puntos, 0);
    expect(p.derrotas, 1);
  });

  test('tras curarse en un centro, perder devuelve al centro', () {
    var p = PartidaCampana(
      progreso: const ProgresoRuta(
          nodoActual: 'centro-plateada',
          superados: {'pueblo-paleta', 'ruta-1'}),
      equipo: [const PokemonGuardado('bulbasaur', 5)],
      ultimaCura: 'pueblo-paleta',
    ).descansar(c);
    expect(p.ultimaCura, 'centro-plateada');
    p = p.avanzar(c, 'gimnasio-plateada');
    final e = p.empezarCombate(c);
    p = p.terminarCombate(
        c,
        e.copiarCon(
            jugador:
                e.jugador.copiarCon(equipo: [e.jugador.equipo[0].conPs(0)]),
            fase: FaseCombate.terminado,
            ganador: Bando.rival));
    expect(p.progreso.nodoActual, 'centro-plateada');
    expect(p.progreso.medallas, isEmpty);
    expect(p.opciones(c), ['gimnasio-plateada']);
  });

  test('ganar da XP a los que siguen en pie y dinero con un entrenador', () {
    var p = PartidaCampana(
      progreso: const ProgresoRuta(nodoActual: 'cazabichos'),
      equipo: [
        const PokemonGuardado('charmander', 70),
        const PokemonGuardado('pidgey', 0),
      ],
      dinero: 50,
    );
    final e = p.empezarCombate(c);
    final ganado = e.copiarCon(
      rival: e.rival
          .copiarCon(equipo: [for (final r in e.rival.equipo) r.conPs(0)]),
      fase: FaseCombate.terminado,
      ganador: Bando.jugador,
    );
    p = p.terminarCombate(c, ganado);
    expect(p.equipo[0].xp, 20, reason: '10 por cada uno de los 2 rivales');
    expect(p.equipo[1].xp, 0, reason: 'estaba fuera de combate');
    expect(p.dinero, 250);
    expect(p.puntos, 200);
  });

  test('tienda: comprar y usar Poción y Repelente', () {
    var p = PartidaCampana(
      progreso: const ProgresoRuta(nodoActual: 'centro-plateada'),
      equipo: [
        const PokemonGuardado('bulbasaur', 80),
        const PokemonGuardado('pidgey', 0),
      ],
      dinero: 400,
    );
    expect(PartidaCampana.nueva(c.region).dinero, 300);
    p = p.comprar(c, ObjetoCampana.pocion, cantidad: 2);
    p = p.comprar(c, ObjetoCampana.repelente);
    expect(p.dinero, 50);
    expect(p.cuantos(ObjetoCampana.pocion), 2);
    expect(() => p.comprar(c, ObjetoCampana.pocion),
        throwsA(isA<ReglaIncumplida>()));
    p = p.usarPocion(c, 0);
    expect(p.equipo[0].ps, 90, reason: 'no pasa de sus PS máximos');
    expect(p.cuantos(ObjetoCampana.pocion), 1);
    expect(() => p.usarPocion(c, 1), throwsA(isA<ReglaIncumplida>()),
        reason: 'no revive');
    expect(() => p.usarRepelente(c), throwsA(isA<ReglaIncumplida>()),
        reason: 'aquí no hay salvajes');
    final fuera = PartidaCampana(
        progreso: const ProgresoRuta(nodoActual: 'ruta-2'),
        equipo: p.equipo,
        mochila: p.mochila);
    expect(() => fuera.comprar(c, ObjetoCampana.pocion),
        throwsA(isA<ReglaIncumplida>()));
    final evitado = fuera.usarRepelente(c);
    expect(evitado.progreso.resuelto, isTrue);
    expect(evitado.capturaPendiente, isNull);
    expect(evitado.cuantos(ObjetoCampana.repelente), 0);
    final gimnasio = PartidaCampana(
        progreso: const ProgresoRuta(nodoActual: 'cazabichos'),
        equipo: p.equipo,
        mochila: p.mochila);
    expect(() => gimnasio.usarRepelente(c), throwsA(isA<ReglaIncumplida>()));
  });

  test('con el equipo lleno, el capturado o el sustituido van al PC', () {
    var p = PartidaCampana(
      progreso: const ProgresoRuta(nodoActual: 'ruta-1', resuelto: true),
      equipo: [
        for (final id in [
          'bulbasaur',
          'pidgey',
          'rattata',
          'caterpie',
          'weedle',
          'metapod'
        ])
          PokemonGuardado.completo(c.especie(id)),
      ],
      capturaPendiente: 'kakuna',
    );
    expect(p.equipoLleno(), isTrue);
    final alPc = p.capturar(c);
    expect(alPc.equipo.length, 6);
    expect(alPc.pc.single.id, 'kakuna');
    final cambio = p.capturar(c, sustituir: 1);
    expect(cambio.equipo[1].id, 'kakuna');
    expect(cambio.pc.single.id, 'pidgey');
    expect(p.noCapturar().capturaPendiente, isNull);
  });

  test('el jefe solo se captura la primera vez y da su carta normal', () {
    final p = PartidaCampana(
      progreso: const ProgresoRuta(nodoActual: 'jefe-pikachu'),
      equipo: [PokemonGuardado.completo(c.especie('squirtle'))],
    );
    final r = p.rival(c);
    expect(r.equipo.single.id, 'pikachu-jefe');
    expect(r.captura, 'pikachu');
    expect(r.puntos, 1000);
    final repetido = PartidaCampana(
      progreso: const ProgresoRuta(
          nodoActual: 'jefe-pikachu', jefesDerrotados: {'pikachu-jefe'}),
      equipo: p.equipo,
    );
    expect(repetido.rival(c).captura, isNull);
    expect(repetido.rival(c).puntos, 0);
  });

  test('el entrenador saca 2 Pokémon distintos de su lista y no se capturan',
      () {
    final p = PartidaCampana(
      progreso: const ProgresoRuta(nodoActual: 'cazabichos'),
      equipo: [PokemonGuardado.completo(c.especie('charmander'))],
      semilla: 11,
    );
    final r = p.rival(c);
    expect(r.equipo.length, 2);
    expect(r.equipo.map((e) => e.id).toSet().length, 2);
    expect(r.captura, isNull);
    expect(r.nombre, 'Cazabichos');
  });

  test('el combate sale con el primer Pokémon en pie y sus PS', () {
    final p = PartidaCampana(
      progreso: const ProgresoRuta(nodoActual: 'ruta-2'),
      equipo: [
        const PokemonGuardado('bulbasaur', 0),
        const PokemonGuardado('pidgey', 25),
      ],
    );
    final e = p.empezarCombate(c);
    expect(e.jugador.activo, 1);
    expect(e.jugador.pokemonActivo.ps, 25);
    expect(p.ponerPrimero(1).equipo.first.id, 'pidgey');
  });

  test('el centro Pokémon cura y deja usar el PC', () {
    var p = PartidaCampana(
      progreso: const ProgresoRuta(nodoActual: 'centro-plateada'),
      equipo: [
        const PokemonGuardado('bulbasaur', 10),
        const PokemonGuardado('pidgey', 0),
      ],
      pc: [const PokemonGuardado('rattata', 5)],
    );
    expect(() => p.moverPc(c, deEquipo: 0, dePc: 0), returnsNormally);
    p = p.descansar(c);
    expect(p.equipo.map((e) => e.ps), [90, 60]);
    expect(p.pc.single.ps, 60);
    expect(p.progreso.resuelto, isTrue);
    p = p.moverPc(c, deEquipo: 1, dePc: 0);
    expect(p.equipo[1].id, 'rattata');
    expect(p.pc.single.id, 'pidgey');
    p = p.moverPc(c, deEquipo: 1);
    expect(p.equipo.length, 1);
    expect(p.pc.length, 2);
    expect(() => p.moverPc(c, deEquipo: 0), throwsA(isA<ReglaIncumplida>()));
    p = p.moverPc(c, dePc: 0);
    expect(p.equipo.length, 2);
    final fuera = PartidaCampana(
        progreso: const ProgresoRuta(nodoActual: 'ruta-1'), equipo: p.equipo);
    expect(() => fuera.moverPc(c, dePc: 0), throwsA(isA<ReglaIncumplida>()));
  });

  test('la partida se guarda y se recupera tal cual', () {
    final p = PartidaCampana(
      progreso: const ProgresoRuta(
          nodoActual: 'ruta-2',
          superados: {'pueblo-paleta'},
          inicial: 'squirtle'),
      equipo: [const PokemonGuardado('squirtle', 42, xp: 3)],
      pc: [const PokemonGuardado('rattata', 60)],
      puntos: 300,
      semilla: 12345,
      capturaPendiente: 'pidgey',
      derrotas: 2,
      dinero: 120,
      mochila: const {ObjetoCampana.pocion: 3},
      ultimaCura: 'pueblo-paleta',
    );
    final json = jsonDecode(jsonEncode(p.aJson())) as Map<String, dynamic>;
    final q = PartidaCampana.desdeJson(json);
    expect(q.aJson(), p.aJson());
    expect(q.problemas(c), isEmpty);
    expect(() => PartidaCampana.desdeJson({...json, 'version': 99}),
        throwsA(isA<FormatException>()));
  });

  test('el tramo se puede jugar entero hasta la medalla de Brock', () {
    for (final inicial in ['bulbasaur', 'charmander', 'squirtle']) {
      var p =
          PartidaCampana.nueva(c.region, semilla: 42).elegirInicial(c, inicial);
      var combates = 0;
      while (!p.terminada(c)) {
        if (p.hayCombate(c)) {
          p = p.terminarCombate(c, jugarSolo(p.empezarCombate(c)));
          if (p.capturaPendiente != null) p = p.capturar(c);
          if (++combates > 200) fail('$inicial no acaba el tramo.');
          continue;
        }
        if (p.nodoActual(c).tipo == TipoNodo.descanso && !p.progreso.resuelto) {
          p = p.descansar(c);
          continue;
        }
        // Coge siempre los desvíos opcionales.
        p = p.avanzar(c, p.opciones(c).first);
      }
      expect(p.progreso.medallas, {'roca'}, reason: inicial);
      expect(p.progreso.jefesDerrotados, {'pikachu-jefe'}, reason: inicial);
      expect(p.puntos, greaterThan(1500 + 1000), reason: inicial);
    }
  });

  test('hasta() llega a un nodo concreto', () {
    final p = hasta(
        c,
        PartidaCampana.nueva(c.region).elegirInicial(c, 'squirtle'),
        'gimnasio-plateada');
    expect(p.hayCombate(c), isTrue);
  });
}
