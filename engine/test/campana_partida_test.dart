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

/// La acción del jugador en los tests: ataca con lo más fuerte que le llegue y,
/// si no, carga. (Con la IA en los dos bandos hay duelos que no acaban nunca,
/// por ejemplo un Pokémon que se pasa el combate usando Gruñido.)
AccionCombate accionDelJugador(EstadoCombate e) {
  final yo = e.jugador;
  if (e.fase == FaseCombate.eligiendoActivo) {
    return ElegirSiguiente(Bando.jugador, yo.relevos.first);
  }
  final ataques = yo.pokemonActivo.especie.ataques;
  int? mejor;
  for (var i = 0; i < ataques.length; i++) {
    if (ataques[i].coste > yo.energia) continue;
    if (mejor == null || ataques[i].dano > ataques[mejor].dano) mejor = i;
  }
  return mejor == null
      ? const Cargar(Bando.jugador)
      : Atacar(Bando.jugador, mejor);
}

/// Juega un combate: la máquina decide por el rival y [accionDelJugador] por
/// el jugador.
EstadoCombate jugarSolo(EstadoCombate e) {
  var s = e;
  var pasos = 0;
  while (s.fase != FaseCombate.terminado) {
    final bando = s.actua;
    s = aplicarCombate(s,
        bando == Bando.rival ? decidirAccion(s, bando) : accionDelJugador(s));
    if (++pasos > 3000) fail('El combate no termina.');
  }
  return s;
}

/// El mismo estado con todo el equipo a 999 PS. El equilibrado de la campaña
/// es cosa del simulador (`balance/informes/campana_calibrar_*.md`): estos
/// tests solo comprueban que la ruta, las capturas y los combates encajan de
/// punta a punta, así que el equipo aguanta lo que haga falta.
PartidaCampana robusto(PartidaCampana p) => PartidaCampana(
      progreso: p.progreso,
      equipo: [for (final e in p.equipo) PokemonGuardado(e.id, 999)],
      pc: p.pc,
      puntos: p.puntos,
      semilla: p.semilla,
      capturaPendiente: p.capturaPendiente,
      derrotas: p.derrotas,
      dinero: p.dinero,
      xp: p.xp,
      mochila: p.mochila,
      ultimaCura: p.ultimaCura,
    );

/// Avanza hasta el combate de [nodo] por el camino principal.
PartidaCampana hasta(CatalogoCampana c, PartidaCampana p, String nodo) {
  var s = robusto(p);
  var combates = 0;
  while (s.progreso.nodoActual != nodo) {
    if (s.hayCombate(c)) {
      s = robusto(s.terminarCombate(c, jugarSolo(s.empezarCombate(c))));
      if (s.capturaPendiente != null) s = robusto(s.capturar(c));
      if (++combates > 300) fail('No llega a $nodo.');
      continue;
    }
    if (s.nodoActual(c).tipo == TipoNodo.descanso && !s.progreso.resuelto) {
      s = robusto(s.descansar(c));
      continue;
    }
    if (s.nodoActual(c).tipo == TipoNodo.conversacion && !s.progreso.resuelto) {
      s = robusto(s.conversar(c));
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

  test('el rival salvaje es el que fija el nodo', () {
    final p = PartidaCampana.nueva(c.region, semilla: 7)
        .elegirInicial(c, 'squirtle')
        .avanzar(c, 'ruta-1')
        .avanzar(c, 'ruta-1-pidgey');
    final r = p.rival(c);
    expect(r.equipo.single.id, 'pidgey');
    expect(r.captura, 'pidgey');
    expect(r.puntos, 100);
    expect(p.rival(c).equipo.single.id, r.equipo.single.id);
  });

  test('ganar resuelve el nodo, suma puntos, conserva los PS y ofrece captura',
      () {
    var p = PartidaCampana.nueva(c.region, semilla: 3)
        .elegirInicial(c, 'bulbasaur')
        .avanzar(c, 'ruta-1')
        .avanzar(c, 'ruta-1-pidgey');
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
    expect(p.capturaPendiente, 'pidgey');
    p = p.capturar(c);
    expect(p.equipo.map((e) => e.id), ['bulbasaur', 'pidgey']);
    expect(p.opciones(c), ['ciudad-verde']);
  });

  test('perder cura al equipo y le devuelve al último sitio donde se curó', () {
    var p = PartidaCampana.nueva(c.region)
        .elegirInicial(c, 'bulbasaur')
        .avanzar(c, 'ruta-1')
        .avanzar(c, 'ruta-1-pidgey');
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
    p = p.avanzar(c, 'gimnasio-joven');
    p = PartidaCampana(
        progreso: const ProgresoRuta(
            nodoActual: 'gimnasio-brock',
            superados: {'pueblo-paleta', 'centro-plateada'}),
        equipo: p.equipo,
        ultimaCura: 'centro-plateada');
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
    expect(p.opciones(c), ['gimnasio-joven']);
  });

  group('conversación (aviso de Pikachu)', () {
    PartidaCampana enAviso() => PartidaCampana(
          progreso: const ProgresoRuta(
              nodoActual: 'aviso-pikachu',
              superados: {'pueblo-paleta', 'cazabichos-2'}),
          equipo: [const PokemonGuardado('bulbasaur', 10)],
          pc: [const PokemonGuardado('pidgey', 5)],
          ultimaCura: 'ciudad-verde',
        );

    test('no hay combate y hasta hablar no se puede seguir', () {
      final p = enAviso();
      expect(p.hayCombate(c), isFalse);
      expect(p.opciones(c), isEmpty);
      expect(() => p.rival(c), throwsA(isA<ReglaIncumplida>()));
    });

    test('hablar cura al equipo, resuelve el nodo y pasa a ser donde se vuelve',
        () {
      final p = enAviso().conversar(c);
      expect(p.equipo.single.ps, 90);
      expect(p.pc.single.ps, 5, reason: 'el PC solo se cura en un centro');
      expect(p.progreso.resuelto, isTrue);
      expect(p.ultimaCura, 'aviso-pikachu');
      expect(p.opciones(c), ['jefe-pikachu']);
      expect(() => p.conversar(c), throwsA(isA<ReglaIncumplida>()));
    });

    test('perder contra Pikachu devuelve al Cazabichos que avisa', () {
      var p = enAviso().conversar(c).avanzar(c, 'jefe-pikachu');
      final e = p.empezarCombate(c);
      p = p.terminarCombate(
          c,
          e.copiarCon(
              jugador:
                  e.jugador.copiarCon(equipo: [e.jugador.equipo[0].conPs(0)]),
              fase: FaseCombate.terminado,
              ganador: Bando.rival));
      expect(p.progreso.nodoActual, 'aviso-pikachu');
      expect(p.equipo.single.ps, 90);
      expect(p.opciones(c), ['jefe-pikachu']);
    });

    test('conversar fuera de una conversación no vale', () {
      final p = PartidaCampana.nueva(c.region).elegirInicial(c, 'bulbasaur');
      expect(() => p.conversar(c), throwsA(isA<ReglaIncumplida>()));
    });
  });

  test('ganar suma la XP del rival a la reserva y dinero con un entrenador',
      () {
    var p = PartidaCampana(
      progreso: const ProgresoRuta(nodoActual: 'cazabichos-1'),
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
    final r = p.rival(c);
    p = p.terminarCombate(c, ganado);
    // Los Cazabichos sacan dos de Weedle, Caterpie (Común, 10), Kakuna y
    // Metapod (Intermedio, 20).
    final esperada =
        r.equipo.fold<int>(0, (t, e) => t + xpDeCategoria(e.categoriaCaptura!));
    expect(p.xp, esperada);
    expect(r.xp, esperada);
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
        progreso: const ProgresoRuta(nodoActual: 'ruta-2-weedle'),
        equipo: p.equipo,
        mochila: p.mochila);
    expect(() => fuera.comprar(c, ObjetoCampana.pocion),
        throwsA(isA<ReglaIncumplida>()));
    final evitado = fuera.usarRepelente(c);
    expect(evitado.progreso.resuelto, isTrue);
    expect(evitado.capturaPendiente, isNull);
    expect(evitado.cuantos(ObjetoCampana.repelente), 0);
    final gimnasio = PartidaCampana(
        progreso: const ProgresoRuta(nodoActual: 'cazabichos-1'),
        equipo: p.equipo,
        mochila: p.mochila);
    expect(() => gimnasio.usarRepelente(c), throwsA(isA<ReglaIncumplida>()));
  });

  test('con el equipo lleno, el capturado o el sustituido van al PC', () {
    var p = PartidaCampana(
      progreso: const ProgresoRuta(nodoActual: 'ruta-1-pidgey', resuelto: true),
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
    expect(r.llamada, isNotNull);
    expect(r.llamada!.porcentaje, 50);
    expect(r.llamada!.alFrente, 40);
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
      progreso: const ProgresoRuta(nodoActual: 'cazabichos-1'),
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
      progreso: const ProgresoRuta(nodoActual: 'ruta-2-weedle'),
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
        progreso: const ProgresoRuta(nodoActual: 'ruta-1-pidgey'),
        equipo: p.equipo);
    expect(() => fuera.moverPc(c, dePc: 0), throwsA(isA<ReglaIncumplida>()));
  });

  test('la partida se guarda y se recupera tal cual', () {
    final p = PartidaCampana(
      progreso: const ProgresoRuta(
          nodoActual: 'ruta-2-weedle',
          superados: {'pueblo-paleta'},
          inicial: 'squirtle'),
      equipo: [const PokemonGuardado('squirtle', 42)],
      xp: 30,
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
      var p = robusto(PartidaCampana.nueva(c.region, semilla: 42)
          .elegirInicial(c, inicial));
      var combates = 0;
      while (!p.terminada(c)) {
        if (p.hayCombate(c)) {
          p = robusto(p.terminarCombate(c, jugarSolo(p.empezarCombate(c))));
          if (p.capturaPendiente != null) p = robusto(p.capturar(c));
          if (++combates > 300) fail('$inicial no acaba el tramo.');
          continue;
        }
        if (p.nodoActual(c).tipo == TipoNodo.descanso && !p.progreso.resuelto) {
          p = robusto(p.descansar(c));
          continue;
        }
        if (p.nodoActual(c).tipo == TipoNodo.conversacion &&
            !p.progreso.resuelto) {
          p = robusto(p.conversar(c));
          continue;
        }
        // Coge siempre los desvíos opcionales.
        p = p.avanzar(c, p.opciones(c).first);
      }
      expect(p.progreso.medallas, {'roca'}, reason: inicial);
      expect(p.progreso.jefesDerrotados, {'pikachu-jefe'}, reason: inicial);
      expect(p.puntos, greaterThan(1500 + 1000), reason: inicial);
      expect(p.derrotas, 0, reason: inicial);
    }
  });

  test('contra el jefe, la llamada de aliado entra y el aliado no se captura',
      () {
    var p = PartidaCampana(
      progreso: const ProgresoRuta(nodoActual: 'jefe-pikachu'),
      equipo: [
        PokemonGuardado.completo(c.especie('squirtle')),
        PokemonGuardado.completo(c.especie('bulbasaur')),
      ],
    );
    var e = p.empezarCombate(c);
    expect(e.llamada, isNotNull);
    var llamado = false;
    var pasos = 0;
    while (e.fase != FaseCombate.terminado && pasos++ < 500) {
      e = aplicarCombate(e, decidirAccion(e, e.actua));
      if (e.llamadaHecha) llamado = true;
    }
    expect(llamado, isTrue,
        reason: 'Pikachu llama a su aliado al bajar de 50 %');
    if (e.ganador == Bando.jugador) {
      p = p.terminarCombate(c, e);
      expect(p.capturaPendiente, 'pikachu', reason: 'el aliado no se captura');
      expect(p.progreso.jefesDerrotados, {'pikachu-jefe'});
    }
  });

  group('reserva de XP y evolución (D-20 §10.6)', () {
    PartidaCampana enNodo(String nodo, List<PokemonGuardado> equipo,
            {int xp = 0}) =>
        PartidaCampana(
            progreso: ProgresoRuta(nodoActual: nodo), equipo: equipo, xp: xp);

    EstadoCombate ganar(EstadoCombate e) => e.copiarCon(
          rival: e.rival
              .copiarCon(equipo: [for (final r in e.rival.equipo) r.conPs(0)]),
          fase: FaseCombate.terminado,
          ganador: Bando.jugador,
        );

    test('cada categoría da su XP: Común 10, Intermedio 20, Fuerte y Jefe 30',
        () {
      expect(xpDeCategoria(CategoriaCaptura.comun), 10);
      expect(xpDeCategoria(CategoriaCaptura.intermedio), 20);
      expect(xpDeCategoria(CategoriaCaptura.fuerte), 30);
      expect(xpDeCategoria(CategoriaCaptura.jefe), 30);
    });

    test('las categorías del catálogo son las que fijó Ayme', () {
      CategoriaCaptura? cat(String id) => c.pokemon[id]!.categoriaCaptura;
      for (final id in [
        'pidgey', 'rattata', 'spearow', 'nidoran-f', 'nidoran-m', //
        'caterpie', 'weedle', 'diglett', 'sandshrew', 'zubat', 'cubone',
        'machop', 'slowpoke', 'pikachu',
      ]) {
        expect(cat(id), CategoriaCaptura.comun, reason: id);
      }
      for (final id in ['metapod', 'kakuna', 'mankey', 'geodude']) {
        expect(cat(id), CategoriaCaptura.intermedio, reason: id);
      }
      expect(cat('onix'), CategoriaCaptura.fuerte);
      for (final id in ['bulbasaur', 'charmander', 'squirtle']) {
        expect(cat(id), isNull, reason: 'los iniciales no aplican');
      }
    });

    test('un salvaje Común da 10 a la reserva, no a cada Pokémon', () {
      var p = enNodo(
          'ruta-1-pidgey',
          [
            const PokemonGuardado('charmander', 70),
            const PokemonGuardado('squirtle', 80),
          ],
          xp: 5);
      p = p.terminarCombate(c, ganar(p.empezarCombate(c)));
      expect(p.xp, 15);
      expect(p.aJson()['equipo'], [
        {'id': 'charmander', 'ps': 70},
        {'id': 'squirtle', 'ps': 80},
      ]);
    });

    test('Brock da 50: Geodude (Intermedio) y Onix (Fuerte)', () {
      var p = enNodo('gimnasio-brock', [const PokemonGuardado('squirtle', 80)]);
      p = p.terminarCombate(c, ganar(p.empezarCombate(c)));
      expect(p.xp, 50);
    });

    test('Pikachu jefe da los 30 de su JSON', () {
      expect(c.jefes['pikachu-jefe']!.xpPropia, 30);
      var p = enNodo('jefe-pikachu', [const PokemonGuardado('charmander', 70)]);
      expect(p.rival(c).xp, 30);
      p = p.terminarCombate(c, ganar(p.empezarCombate(c)));
      expect(p.xp, 30);
    });

    test('un aliado del jefe que cae suma su XP; uno en pie, no', () {
      final p = enNodo('jefe-pikachu', [const PokemonGuardado('charmander', 70)]);
      final e = p.empezarCombate(c);
      EstadoCombate conAliado(int psAliado) => e.copiarCon(
            rival: e.rival.copiarCon(equipo: [
              e.rival.equipo.first.conPs(0),
              PokemonEnCombate(c.especie('metapod'), psAliado),
            ]),
            fase: FaseCombate.terminado,
            ganador: Bando.jugador,
          );
      expect(p.terminarCombate(c, conAliado(0)).xp, 30 + 20,
          reason: 'Pikachu 30 y Metapod (Intermedio) 20');
      expect(p.terminarCombate(c, conAliado(40)).xp, 30);
    });

    test('un jefe sin xp propia da la de su categoría (30)', () {
      final j = jefeCampanaDesdeJson({
        'numero': 2,
        'pokemon': {
          'id': 'x',
          'nombre': 'X',
          'tipo': 'normal',
          'ps': 60,
          'ataques': [
            {'nombre': 'Placaje', 'tipo': 'normal', 'coste': 1, 'dano': 10},
          ],
        },
      });
      expect(j.xpPropia, isNull);
      expect(j.xp, 30);
    });

    test('perder no da XP', () {
      const p0 = PartidaCampana(
          progreso: ProgresoRuta(
              nodoActual: 'ruta-1-pidgey', superados: {'pueblo-paleta'}),
          equipo: [PokemonGuardado('charmander', 70)],
          xp: 40);
      final e = p0.empezarCombate(c);
      final p = p0.terminarCombate(
          c,
          e.copiarCon(
              jugador:
                  e.jugador.copiarCon(equipo: [e.jugador.equipo[0].conPs(0)]),
              fase: FaseCombate.terminado,
              ganador: Bando.rival));
      expect(p.xp, 40);
    });

    test('Caterpie → Metapod y Weedle → Kakuna cuestan 50 XP', () {
      for (final (de, a) in [('caterpie', 'metapod'), ('weedle', 'kakuna')]) {
        final evo = c.pokemon[de]!.evoluciones.single;
        expect(evo.a, a);
        expect(evo.via, ViaEvolucion.xp);
        expect(evo.xpEvolucion, 50);
      }
    });

    test('evolucionar gasta la XP de la reserva y deja el Pokémon a 10 PS', () {
      var p = enNodo(
          'ruta-2-norte',
          [
            const PokemonGuardado('charmander', 70),
            const PokemonGuardado('caterpie', 50),
          ],
          xp: 120);
      expect(p.evolucionesPorXp(c, 1).map((e) => e.a), ['metapod']);
      p = p.evolucionar(c, 1, 'metapod');
      expect(p.equipo[1].id, 'metapod');
      expect(p.equipo[1].ps, 10, reason: 'aunque tuviera todos sus PS');
      expect(p.xp, 70);
      expect(p.equipo[0].id, 'charmander');
    });

    test('evolucionar revive a 10 PS a un debilitado', () {
      final p = enNodo(
              'ruta-2-norte',
              [
                const PokemonGuardado('charmander', 70),
                const PokemonGuardado('weedle', 0),
              ],
              xp: 50)
          .evolucionar(c, 1, 'kakuna');
      expect(p.equipo[1].id, 'kakuna');
      expect(p.equipo[1].ps, 10);
      expect(p.xp, 0);
    });

    test('sin XP suficiente no se evoluciona', () {
      final p = enNodo('ruta-2-norte', [const PokemonGuardado('caterpie', 50)],
          xp: 40);
      expect(p.puedeEvolucionar(p.evolucionesPorXp(c, 0).single), isFalse);
      expect(() => p.evolucionar(c, 0, 'metapod'),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('un Pokémon sin evolución por XP no evoluciona', () {
      final p = enNodo('ruta-2-norte', [const PokemonGuardado('pidgey', 60)],
          xp: 500);
      expect(p.evolucionesPorXp(c, 0), isEmpty);
      expect(() => p.evolucionar(c, 0, 'pidgeotto'),
          throwsA(isA<ReglaIncumplida>()));
    });

    test('se puede evolucionar varias veces seguidas mientras dé la reserva',
        () {
      var p = enNodo(
          'ciudad-verde',
          [
            const PokemonGuardado('caterpie', 50),
            const PokemonGuardado('weedle', 50),
          ],
          xp: 100);
      p = p.evolucionar(c, 0, 'metapod').evolucionar(c, 1, 'kakuna');
      expect(p.equipo.map((e) => e.id), ['metapod', 'kakuna']);
      expect(p.xp, 0);
    });

    test('la reserva se guarda; una partida de la versión 1 suma la XP antigua',
        () {
      final p = enNodo('ciudad-verde', [const PokemonGuardado('caterpie', 50)],
          xp: 70);
      final json = p.aJson();
      expect(json['version'], 2);
      expect(json['xp'], 70);
      expect(PartidaCampana.desdeJson(json).xp, 70);
      final antigua = {
        ...json,
        'version': 1,
        'equipo': [
          {'id': 'caterpie', 'ps': 50, 'xp': 30},
          {'id': 'pidgey', 'ps': 60, 'xp': 20},
        ],
        'pc': [
          {'id': 'rattata', 'ps': 60, 'xp': 10},
        ],
      }..remove('xp');
      final leida = PartidaCampana.desdeJson(antigua);
      expect(leida.xp, 60);
      expect(leida.equipo.map((e) => e.id), ['caterpie', 'pidgey']);
    });
  });

  group('evolución limitada por medalla (D-20 §10.11, #414)', () {
    // Pidgey → Rattata de mentira, con 2 medallas, porque Pidgeotto aún no
    // tiene carta (en la tabla, Pidgey → Pidgeotto pide 2 medallas).
    CatalogoCampana conPidgeyDeDosMedallas() {
      final json = leer(File('../catalog/campana/pokemon/pidgey.json'));
      json['evoluciones'] = [
        {'a': 'rattata', 'via': 'xp', 'xpEvolucion': 50, 'medallasMinimas': 2},
      ];
      return CatalogoCampana(
        pokemon: {...c.pokemon, 'pidgey': pokemonCampanaDesdeJson(json)},
        zonas: c.zonas,
        jefes: c.jefes,
        region: c.region,
      );
    }

    PartidaCampana conMedallas(Set<String> medallas) => PartidaCampana(
          progreso:
              ProgresoRuta(nodoActual: 'centro-plateada', medallas: medallas),
          equipo: const [PokemonGuardado('pidgey', 60)],
          xp: 200,
        );

    test('con 0 medallas no se evoluciona uno que pide 2, aunque haya XP', () {
      final c2 = conPidgeyDeDosMedallas();
      final p = conMedallas({});
      final e = p.evolucionesPorXp(c2, 0).single;
      expect(e.medallasMinimas, 2);
      expect(p.puedeEvolucionar(e), isFalse);
      expect(p.motivoSinEvolucion(e), 'Requiere 2 medallas.');
      expect(() => p.evolucionar(c2, 0, 'rattata'),
          throwsA(isA<ReglaIncumplida>()));
      expect(p.motivoSinEvolucion(e),
          isNot(contains('XP')), reason: 'el motivo son las medallas');
    });

    test('con una sola medalla tampoco', () {
      final c2 = conPidgeyDeDosMedallas();
      final p = conMedallas({'roca'});
      expect(p.puedeEvolucionar(p.evolucionesPorXp(c2, 0).single), isFalse);
    });

    test('con las medallas, sí', () {
      final c2 = conPidgeyDeDosMedallas();
      final p = conMedallas({'roca', 'cascada'}).evolucionar(c2, 0, 'rattata');
      expect(p.equipo.single.id, 'rattata');
      expect(p.xp, 150);
    });

    test('con medallas pero sin XP, el motivo es la XP', () {
      final c2 = conPidgeyDeDosMedallas();
      final p = PartidaCampana(
        progreso: const ProgresoRuta(
            nodoActual: 'centro-plateada', medallas: {'roca', 'cascada'}),
        equipo: const [PokemonGuardado('pidgey', 60)],
        xp: 20,
      );
      expect(p.motivoSinEvolucion(p.evolucionesPorXp(c2, 0).single),
          'Faltan 30 XP.');
    });

    test('Caterpie y Weedle evolucionan con 0 medallas', () {
      for (final id in ['caterpie', 'weedle']) {
        expect(c.pokemon[id]!.evoluciones.single.medallasMinimas, 0,
            reason: id);
      }
    });

    test('toda evolución por XP del catálogo lleva medallasMinimas', () {
      for (final p in c.pokemon.values) {
        for (final e in p.evoluciones) {
          if (e.via == ViaEvolucion.xp) {
            expect(e.medallasMinimas, isNotNull, reason: '${p.id} → ${e.a}');
          }
        }
      }
    });

    test('medallasMinimas negativo se rechaza', () {
      final json = leer(File('../catalog/campana/pokemon/pidgey.json'));
      json['evoluciones'] = [
        {'a': 'x', 'via': 'xp', 'xpEvolucion': 50, 'medallasMinimas': -1},
      ];
      expect(() => pokemonCampanaDesdeJson(json), throwsFormatException);
    });
  });

  test('hasta() llega a un nodo concreto', () {
    final p = hasta(
        c,
        PartidaCampana.nueva(c.region).elegirInicial(c, 'squirtle'),
        'gimnasio-brock');
    expect(p.hayCombate(c), isTrue);
  });
}
