// Simulador de balance del combate de campaña (D-20).
//
// Juega combates 1 contra 1 con el motor de campaña (`engine/lib/campana.dart`)
// y la IA rival en los dos bandos, usando los Pokémon de `catalog/campana/`.
// Sirve para ver TENDENCIAS de PS, daños, costes y energía; las cifras del
// catálogo son provisionales. No usa cartas ni imágenes: solo los datos.
//
// Uso (desde la carpeta sim/):
//   dart run bin/sim_campana.dart                       # duelos 1 contra 1
//   dart run bin/sim_campana.dart --modo=equipos --tamano=3 --partidas=2000
//   dart run bin/sim_campana.dart --modo=nodos                   # #383
//   dart run bin/sim_campana.dart --modo=tramo --partidas=5000   # #383
//   dart run bin/sim_campana.dart --modo=realista --capturas=3   # #383
//
// Modos:
//   duelos    cada Pokémon contra cada Pokémon (también contra sí mismo) con
//             el jugador y con el rival empezando. La IA es determinista, así
//             que no hace falta repetir.
//   equipos   equipos aleatorios de --tamano Pokémon distintos, --partidas
//             combates (empieza siempre el jugador, como en el juego).
//   nodos     cada inicial contra cada rival posible de cada combate del
//             tramo (`regiones/kanto.json`), con los PS llenos y --partidas
//             semillas por emparejamiento. Un entrenador sin Pokémon fijos
//             se mide Pokémon a Pokémon de su clase; el jefe, con su llamada
//             de aliado (salvo --aliado=no).
//   tramo     el tramo entero de seguido, --partidas veces por inicial: el
//             daño se arrastra, la energía vuelve a 10 en cada combate, los
//             descansos y las conversaciones que curan lo hacen, las
//             bifurcaciones se eligen al azar, los desvíos opcionales se
//             saltan y el jefe llama a su aliado. Se gana si se llega al final sin
//             perder ningún combate. Dos variantes: solo el inicial y
//             capturando todos los salvajes vencidos (hasta 6, con los PS
//             llenos). Son cotas para medir, no reglas del juego.
//   realista  como tramo, pero con un equipo realista desde el principio: el
//             inicial y --capturas Pokémon distintos al azar entre los
//             salvajes de las rutas del tramo, y la IA elige quién sale en
//             cada combate. Da, por nodo, cuántos llegan y cuántos ganan.
//
// Opciones:
//   --catalogo=RUTA        carpeta con pokemon/ (defecto ../catalog/campana)
//   --tamano=N             Pokémon por equipo en el modo equipos (3)
//   --partidas=N           combates en el modo equipos (2000)
//   --semilla=N            semilla del generador aleatorio (1)
//   --energia-inicial=N    energía con la que empieza cada bando (10)
//   --energia-maxima=N     máximo de la reserva (10)
//   --energia-turno=N      energía que se recupera al terminar el turno (1)
//   --energia-cargar=N     energía extra al cargar (1)
//   --aliado=no            mide a los jefes sin su llamada de aliado (por
//                          defecto la llevan, D-20 §4, Jefes)
//   --capturas=N           capturas del equipo en el modo realista (2)
//   --entrenador=N         Pokémon de un entrenador sin Pokémon fijos en el
//                          modo tramo (1; sin decidir en D-20)
//   --informe=RUTA         CSV de salida (defecto
//                          ../balance/informes/campana_<modo>.csv)
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:incursiones_engine/campana.dart';

class Config {
  String modo = 'duelos';
  String catalogo = '../catalog/campana';
  int tamano = 3;
  int partidas = 2000;
  int semilla = 1;
  int energiaInicial = 10;
  int energiaMaxima = 10;
  int energiaTurno = 1;
  int energiaCargar = 1;
  String? informe;
  int entrenador = 1;
  int capturas = 2;
  bool aliado = true;

  ParametrosCombate get parametros => ParametrosCombate(
        energiaInicial: energiaInicial,
        energiaMaxima: energiaMaxima,
        energiaPorTurno: energiaTurno,
        energiaAlCargar: energiaCargar,
      );
}

/// Lo que pasó en un combate.
class Resultado {
  Resultado(this.ganador, this.turnos, this.atacar, this.cambiar, this.cargar,
      this.psRestantes, this.terminado);
  final Bando? ganador;
  final int turnos;
  final int atacar;
  final int cambiar;
  final int cargar;
  final int psRestantes;
  final bool terminado;
}

Resultado jugar(
  List<PokemonCampana> jugador,
  List<PokemonCampana> rival,
  Bando empieza,
  ParametrosCombate parametros, [
  int semilla = 1,
  LlamadaEnCombate? llamada,
]) =>
    jugarDesde(EstadoCombate.inicial(
      llamadaRival: llamada,
      equipoJugador: jugador,
      equipoRival: rival,
      empieza: empieza,
      parametros: parametros,
      semilla: semilla,
    ));

/// Juega con la IA en los dos bandos hasta el final, desde [e].
Resultado jugarDesde(EstadoCombate e) {
  var atacar = 0;
  var cambiar = 0;
  var cargar = 0;
  for (var i = 0; i < 2000 && e.fase != FaseCombate.terminado; i++) {
    final accion = decidirAccion(e, e.actua);
    switch (accion) {
      case Atacar _:
        atacar++;
      case Cambiar _:
        cambiar++;
      case Cargar _:
        cargar++;
      case ElegirSiguiente _:
        break;
    }
    e = aplicarCombate(e, accion);
  }
  final terminado = e.fase == FaseCombate.terminado;
  var ps = 0;
  if (e.ganador != null) {
    for (final p in e.bando(e.ganador!).equipo) {
      ps += p.ps;
    }
  }
  return Resultado(e.ganador, e.numeroTurno, atacar, cambiar, cargar, ps, terminado);
}

class Acumulado {
  int combates = 0;
  int victorias = 0;
  int turnos = 0;
  int atacar = 0;
  int cambiar = 0;
  int cargar = 0;

  void sumar(Resultado r, bool gana) {
    combates++;
    if (gana) victorias++;
    turnos += r.turnos;
    atacar += r.atacar;
    cambiar += r.cambiar;
    cargar += r.cargar;
  }

  double get tasa => combates == 0 ? 0 : victorias / combates;
}

String pct(double x) => '${(x * 100).toStringAsFixed(1)} %';

Map<String, PokemonCampana> cargarCatalogo(String carpeta) {
  final dir = Directory('$carpeta/pokemon');
  if (!dir.existsSync()) {
    stderr.writeln('No existe ${dir.path}');
    exit(2);
  }
  final archivos = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final salida = <String, PokemonCampana>{};
  for (final f in archivos) {
    final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final p = pokemonCampanaDesdeJson(json);
    salida[p.id] = p;
  }
  return salida;
}

void escribirCsv(String ruta, List<String> lineas) {
  final f = File(ruta);
  f.parent.createSync(recursive: true);
  f.writeAsStringSync('${lineas.join('\n')}\n');
}

void duelos(Config c, Map<String, PokemonCampana> catalogo) {
  final lista = catalogo.values.toList();
  final porPokemon = {for (final p in lista) p.id: Acumulado()};
  final empiezaJugador = Acumulado();
  final espejo = Acumulado();
  final total = Acumulado();
  final lineas = ['jugador,rival,empieza,ganador,turnos,ps_restantes'];
  var sinTerminar = 0;
  var semilla = 1;
  for (final a in lista) {
    for (final b in lista) {
      for (final empieza in Bando.values) {
        final r = jugar([a], [b], empieza, c.parametros, semilla++);
        if (!r.terminado) sinTerminar++;
        final gana = r.ganador == Bando.jugador;
        lineas.add('${a.id},${b.id},${empieza.name},${r.ganador?.name ?? "-"},'
            '${r.turnos},${r.psRestantes}');
        porPokemon[a.id]!.sumar(r, gana);
        porPokemon[b.id]!.sumar(r, r.ganador == Bando.rival);
        total.sumar(r, gana);
        if (empieza == Bando.jugador) empiezaJugador.sumar(r, gana);
        if (a.id == b.id) {
          // En un espejo la ventaja de empezar queda a la vista.
          espejo.sumar(r, r.ganador == empieza);
        }
      }
    }
  }
  stdout.writeln('Duelos 1 contra 1 (${lista.length} Pokémon, '
      '${total.combates} combates)');
  stdout.writeln('Energía: inicial ${c.energiaInicial}, máxima '
      '${c.energiaMaxima}, +${c.energiaTurno} por turno, +${c.energiaCargar} al cargar');
  stdout.writeln('');
  stdout.writeln('${"Pokémon".padRight(12)}${"victorias".padLeft(10)}'
      '${"turnos".padLeft(9)}${"atacar".padLeft(9)}${"cargar".padLeft(9)}'
      '${"cambiar".padLeft(9)}');
  final orden = lista.toList()
    ..sort((x, y) => porPokemon[y.id]!.tasa.compareTo(porPokemon[x.id]!.tasa));
  for (final p in orden) {
    final s = porPokemon[p.id]!;
    stdout.writeln('${p.nombre.padRight(12)}${pct(s.tasa).padLeft(10)}'
        '${(s.turnos / s.combates).toStringAsFixed(1).padLeft(9)}'
        '${(s.atacar / s.combates).toStringAsFixed(1).padLeft(9)}'
        '${(s.cargar / s.combates).toStringAsFixed(1).padLeft(9)}'
        '${(s.cambiar / s.combates).toStringAsFixed(1).padLeft(9)}');
  }
  stdout.writeln('');
  stdout.writeln('Gana el jugador cuando empieza él: ${pct(empiezaJugador.tasa)}');
  stdout.writeln('Ventaja de empezar en espejos: ${pct(espejo.tasa)}');
  stdout.writeln('Turnos medios por duelo: '
      '${(total.turnos / total.combates).toStringAsFixed(1)}');
  if (sinTerminar > 0) {
    stdout.writeln('ATENCIÓN: $sinTerminar duelos no terminaron.');
  }
  escribirCsv(c.informe ?? '../balance/informes/campana_duelos.csv', lineas);
}

void equipos(Config c, Map<String, PokemonCampana> catalogo) {
  final lista = catalogo.values.toList();
  final tamano = min(c.tamano, lista.length);
  final rnd = Random(c.semilla);
  List<PokemonCampana> equipo() {
    final mezcla = lista.toList()..shuffle(rnd);
    return mezcla.take(tamano).toList();
  }

  final total = Acumulado();
  final presencia = {for (final p in lista) p.id: Acumulado()};
  var sinTerminar = 0;
  final lineas = ['partida,equipo_jugador,equipo_rival,ganador,turnos'];
  for (var i = 0; i < c.partidas; i++) {
    final a = equipo();
    final b = equipo();
    final r = jugar(a, b, Bando.jugador, c.parametros, i + 1);
    if (!r.terminado) sinTerminar++;
    total.sumar(r, r.ganador == Bando.jugador);
    for (final p in a) {
      presencia[p.id]!.sumar(r, r.ganador == Bando.jugador);
    }
    for (final p in b) {
      presencia[p.id]!.sumar(r, r.ganador == Bando.rival);
    }
    if (i < 200) {
      lineas.add('$i,${a.map((p) => p.id).join("+")},'
          '${b.map((p) => p.id).join("+")},${r.ganador?.name ?? "-"},${r.turnos}');
    }
  }
  stdout.writeln('Equipos de $tamano (${c.partidas} combates, semilla ${c.semilla})');
  stdout.writeln('Gana el jugador (empieza él): ${pct(total.tasa)}');
  stdout.writeln('Turnos medios: ${(total.turnos / total.combates).toStringAsFixed(1)}');
  stdout.writeln('Acciones por combate: atacar '
      '${(total.atacar / total.combates).toStringAsFixed(1)}, cargar '
      '${(total.cargar / total.combates).toStringAsFixed(1)}, cambiar '
      '${(total.cambiar / total.combates).toStringAsFixed(1)}');
  stdout.writeln('');
  stdout.writeln('Victorias por Pokémon en el equipo:');
  final orden = lista.toList()
    ..sort((x, y) => presencia[y.id]!.tasa.compareTo(presencia[x.id]!.tasa));
  for (final p in orden) {
    stdout.writeln('  ${p.nombre.padRight(12)}${pct(presencia[p.id]!.tasa)}');
  }
  if (sinTerminar > 0) {
    stdout.writeln('ATENCIÓN: $sinTerminar combates no terminaron.');
  }
  escribirCsv(c.informe ?? '../balance/informes/campana_equipos.csv', lineas);
}

void main(List<String> args) {
  final c = Config();
  for (final a in args) {
    if (a.startsWith('--modo=')) {
      c.modo = a.substring(7);
    } else if (a.startsWith('--catalogo=')) {
      c.catalogo = a.substring(11);
    } else if (a.startsWith('--tamano=')) {
      c.tamano = int.parse(a.substring(9));
    } else if (a.startsWith('--partidas=')) {
      c.partidas = int.parse(a.substring(11));
    } else if (a.startsWith('--semilla=')) {
      c.semilla = int.parse(a.substring(10));
    } else if (a.startsWith('--energia-inicial=')) {
      c.energiaInicial = int.parse(a.substring(18));
    } else if (a.startsWith('--energia-maxima=')) {
      c.energiaMaxima = int.parse(a.substring(17));
    } else if (a.startsWith('--energia-turno=')) {
      c.energiaTurno = int.parse(a.substring(16));
    } else if (a.startsWith('--energia-cargar=')) {
      c.energiaCargar = int.parse(a.substring(17));
    } else if (a.startsWith('--aliado=')) {
      c.aliado = a.substring(9) != 'no';
    } else if (a.startsWith('--capturas=')) {
      c.capturas = int.parse(a.substring(11));
    } else if (a.startsWith('--entrenador=')) {
      c.entrenador = int.parse(a.substring(13));
    } else if (a.startsWith('--informe=')) {
      c.informe = a.substring(10);
    } else {
      stderr.writeln('Opción desconocida: $a');
      exit(2);
    }
  }
  final catalogo = cargarCatalogo(c.catalogo);
  switch (c.modo) {
    case 'duelos':
      duelos(c, catalogo);
    case 'equipos':
      equipos(c, catalogo);
    case 'nodos':
      nodos(c, catalogo);
    case 'tramo':
      tramo(c, catalogo);
    case 'realista':
      realista(c, catalogo);
    default:
      stderr.writeln('--modo: usa «duelos», «equipos», «nodos», «tramo» o «realista»');
      exit(2);
  }
}

// ---------------------------------------------------------------------------
// Modos «nodos» y «tramo» (#383): miden el primer tramo de Kanto.

/// Región, zonas y jefes del catálogo de campaña.
class DatosTramo {
  DatosTramo(this.region, this.zonas, this.jefes);
  final RegionCampana region;
  final Map<String, ZonaCampana> zonas;
  final Map<String, JefeCampana> jefes;
}

DatosTramo cargarTramo(String carpeta) {
  Map<String, dynamic> leer(File f) =>
      jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  List<File> archivos(String sub) => Directory('$carpeta/$sub')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final region =
      regionCampanaDesdeJson(leer(File('$carpeta/regiones/kanto.json')));
  final zonas = <String, ZonaCampana>{};
  for (final f in archivos('zonas')) {
    final z = zonaCampanaDesdeJson(leer(f));
    zonas[z.id] = z;
  }
  final jefes = <String, JefeCampana>{};
  for (final f in archivos('jefes')) {
    final j = jefeCampanaDesdeJson(leer(f));
    jefes[j.pokemon.id] = j;
  }
  return DatosTramo(region, zonas, jefes);
}

/// Los nodos con combate, en el orden del recorrido (anchura desde el inicio).
List<NodoRuta> nodosConCombate(RegionCampana region) {
  final orden = <NodoRuta>[];
  final vistos = <String>{};
  final cola = [region.inicio];
  while (cola.isNotEmpty) {
    final id = cola.removeAt(0);
    if (!vistos.add(id)) continue;
    final n = region.nodo(id);
    if (n.tipo == TipoNodo.combate ||
        n.tipo == TipoNodo.gimnasio ||
        n.tipo == TipoNodo.jefe) {
      orden.add(n);
    }
    cola.addAll(n.salidas);
  }
  return orden;
}

/// Cada equipo rival posible en un nodo, para el modo «nodos».
List<List<String>> rivalesPosibles(NodoRuta n, DatosTramo d) {
  switch (n.tipo) {
    case TipoNodo.gimnasio:
      return [n.lider!.pokemon];
    case TipoNodo.jefe:
      return [
        [n.jefe!]
      ];
    default:
      if (n.rival == RivalDeCombate.entrenador) {
        if (n.pokemon.isNotEmpty) return [n.pokemon];
        final clase =
            d.zonas[n.zona]!.entrenadores.firstWhere((e) => e.clase == n.clase);
        return [
          for (final p in clase.pokemon) [p]
        ];
      }
      if (n.pokemon.isNotEmpty) return [n.pokemon];
      return [
        for (final p in d.zonas[n.zona]!.salvajes) [p]
      ];
  }
}

/// La llamada de aliado del rival si es un jefe que la tiene y no se ha
/// pedido medir sin ella (`--aliado=no`), o null.
LlamadaEnCombate? llamadaDe(List<String> rival, Config c,
    Map<String, PokemonCampana> catalogo, DatosTramo d) {
  if (!c.aliado || rival.length != 1) return null;
  final jefe = d.jefes[rival.first];
  return jefe == null ? null : llamadaEnCombate(jefe, catalogo);
}

PokemonCampana especie(
        String id, Map<String, PokemonCampana> catalogo, DatosTramo d) =>
    catalogo[id] ?? d.jefes[id]!.pokemon;

void nodos(Config c, Map<String, PokemonCampana> catalogo) {
  final d = cargarTramo(c.catalogo);
  final iniciales = d.region.nodo(d.region.inicio).iniciales;
  final semillas = c.partidas;
  final lineas = ['nodo,rival,inicial,victorias,combates'];
  stdout.writeln('Cada inicial contra cada rival del tramo, PS llenos, '
      '$semillas semillas por emparejamiento');
  stdout.writeln('');
  stdout.writeln('${"Nodo / rival".padRight(42)}'
      '${[for (final i in iniciales) catalogo[i]!.nombre.padLeft(12)].join()}');
  final porInicial = {for (final i in iniciales) i: Acumulado()};
  for (final n in nodosConCombate(d.region)) {
    final opc = n.opcional ? ' (opcional)' : '';
    stdout.writeln('${n.nombre}$opc');
    for (final rival in rivalesPosibles(n, d)) {
      final equipoRival = [for (final id in rival) especie(id, catalogo, d)];
      final llamada = llamadaDe(rival, c, catalogo, d);
      final celdas = <String>[];
      for (final i in iniciales) {
        final acc = Acumulado();
        for (var s = 1; s <= semillas; s++) {
          final r = jugar(
              [catalogo[i]!], equipoRival, Bando.jugador, c.parametros, s,
              llamada);
          acc.sumar(r, r.ganador == Bando.jugador);
        }
        if (!n.opcional) {
          porInicial[i]!
            ..combates += acc.combates
            ..victorias += acc.victorias;
        }
        celdas.add(pct(acc.tasa).padLeft(12));
        lineas.add('${n.id},${rival.join("+")},$i,${acc.victorias},'
            '${acc.combates}');
      }
      final nombre = '  ${equipoRival.map((p) => p.nombre).join(" + ")}';
      stdout.writeln('${nombre.padRight(42)}${celdas.join()}');
    }
  }
  stdout.writeln('');
  stdout.writeln('${"Media sin opcionales".padRight(42)}'
      '${[for (final i in iniciales) pct(porInicial[i]!.tasa).padLeft(12)].join()}');
  escribirCsv(c.informe ?? '../balance/informes/campana_nodos.csv', lineas);
}

/// Juega con la IA en los dos bandos y devuelve el estado final.
EstadoCombate hastaElFinal(EstadoCombate e) {
  for (var i = 0; i < 2000 && e.fase != FaseCombate.terminado; i++) {
    e = aplicarCombate(e, decidirAccion(e, e.actua));
  }
  return e;
}

/// Un recorrido del tramo: si se completa y, si no, en qué nodo se pierde.
class Recorrido {
  Recorrido(this.completo, this.derrota, this.combates);
  final bool completo;
  final String? derrota;
  final int combates;
}

Recorrido recorrer(String inicial, bool capturar, Random rnd, Config c,
    Map<String, PokemonCampana> catalogo, DatosTramo d,
    {List<PokemonCampana> capturas = const [],
    bool elegirActivo = false,
    Map<String, Acumulado>? porNodo}) {
  final region = d.region;
  var equipo = [
    PokemonEnCombate.completo(catalogo[inicial]!),
    for (final p in capturas) PokemonEnCombate.completo(p),
  ];
  var id = region.nodo(region.inicio).salidas.first;
  var combates = 0;
  while (true) {
    final n = region.nodo(id);
    List<String>? rival;
    switch (n.tipo) {
      case TipoNodo.descanso:
        equipo = [for (final p in equipo) PokemonEnCombate.completo(p.especie)];
      case TipoNodo.conversacion:
        if (n.cura) {
          equipo = [
            for (final p in equipo) PokemonEnCombate.completo(p.especie)
          ];
        }
      case TipoNodo.gimnasio:
        rival = n.lider!.pokemon;
      case TipoNodo.jefe:
        rival = [n.jefe!];
      case TipoNodo.combate:
        if (n.pokemon.isNotEmpty) {
          rival = n.pokemon;
        } else if (n.rival == RivalDeCombate.entrenador) {
          final lista = d.zonas[n.zona]!.entrenadores
              .firstWhere((e) => e.clase == n.clase)
              .pokemon
              .toList()
            ..shuffle(rnd);
          rival = lista.take(min(c.entrenador, lista.length)).toList();
        } else {
          final s = d.zonas[n.zona]!.salvajes;
          rival = [s[rnd.nextInt(s.length)]];
        }
      case TipoNodo.inicio:
      case TipoNodo.bifurcacion:
        break;
    }
    if (rival != null) {
      combates++;
      // Los que han caído no salen; el primero en pie es el activo.
      var enPie = [for (final p in equipo) if (p.enPie) p];
      final caidos = [for (final p in equipo) if (!p.enPie) p];
      final equipoRival = [for (final r in rival) especie(r, catalogo, d)];
      final semilla = rnd.nextInt(1 << 30) + 1;
      if (elegirActivo && enPie.length > 1) {
        enPie = ordenarConActivo(enPie, equipoRival, c.parametros);
      }
      final inicialRival = EstadoCombate.inicial(
        equipoJugador: [for (final p in enPie) p.especie],
        equipoRival: equipoRival,
        parametros: c.parametros,
        semilla: semilla,
        llamadaRival: llamadaDe(rival, c, catalogo, d),
      );
      final arranque = inicialRival.copiarCon(
          jugador: inicialRival.jugador.copiarCon(equipo: enPie));
      final fin = hastaElFinal(arranque);
      final gana = fin.ganador == Bando.jugador;
      porNodo?.putIfAbsent(n.id, Acumulado.new)
        ?..combates += 1
        ..victorias += gana ? 1 : 0;
      if (!gana) {
        return Recorrido(false, n.id, combates);
      }
      equipo = [...fin.jugador.equipo, ...caidos];
      if (capturar &&
          n.tipo == TipoNodo.combate &&
          n.rival == RivalDeCombate.salvaje &&
          equipo.length < 6) {
        equipo.add(PokemonEnCombate.completo(catalogo[rival.first]!));
      }
    }
    final salidas = [
      for (final s in n.salidas)
        if (!region.nodo(s).opcional) s
    ];
    if (salidas.isEmpty) {
      if (n.salidas.isEmpty) return Recorrido(true, null, combates);
      salidas.addAll(n.salidas);
    }
    id = salidas[rnd.nextInt(salidas.length)];
  }
}

void tramo(Config c, Map<String, PokemonCampana> catalogo) {
  final d = cargarTramo(c.catalogo);
  final iniciales = d.region.nodo(d.region.inicio).iniciales;
  final lineas = ['inicial,variante,completos,recorridos,derrotas_por_nodo'];
  stdout.writeln('Tramo entero de seguido (${c.partidas} recorridos por inicial,'
      ' semilla ${c.semilla}, entrenador sin fijos con ${c.entrenador} Pokémon)');
  stdout.writeln('Daño arrastrado, energía a 10 en cada combate, curar en los '
      'descansos, sin opcionales, jefe ${c.aliado ? "con" : "sin"} llamada de aliado');
  for (final capturar in [false, true]) {
    final variante = capturar ? 'capturando' : 'solo-inicial';
    stdout.writeln('');
    stdout.writeln(capturar
        ? 'Capturando todos los salvajes vencidos (hasta 6, PS llenos):'
        : 'Solo con el inicial:');
    for (final i in iniciales) {
      final rnd = Random(c.semilla);
      var completos = 0;
      final derrotas = <String, int>{};
      for (var k = 0; k < c.partidas; k++) {
        final r = recorrer(i, capturar, rnd, c, catalogo, d);
        if (r.completo) {
          completos++;
        } else {
          derrotas[r.derrota!] = (derrotas[r.derrota!] ?? 0) + 1;
        }
      }
      final orden = derrotas.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final donde = [
        for (final e in orden.take(3))
          '${d.region.nodo(e.key).nombre} ${pct(e.value / c.partidas)}'
      ].join(', ');
      stdout.writeln('  ${catalogo[i]!.nombre.padRight(12)}'
          '${pct(completos / c.partidas).padLeft(8)}'
          '${donde.isEmpty ? "" : "   pierde en: $donde"}');
      lineas.add('$i,$variante,$completos,${c.partidas},'
          '${[for (final e in orden) "${e.key}:${e.value}"].join(";")}');
    }
  }
  escribirCsv(c.informe ?? '../balance/informes/campana_tramo.csv', lineas);
}

/// Pone primero el Pokémon que la IA sacaría contra el primer rival: el mismo
/// criterio que al elegir relevo (no ser débil, más daño, más salud). Se le
/// pregunta a la IA con un activo ficticio ya caído delante del equipo.
List<PokemonEnCombate> ordenarConActivo(List<PokemonEnCombate> enPie,
    List<PokemonCampana> rival, ParametrosCombate parametros) {
  final base = EstadoCombate.inicial(
      equipoJugador: [enPie.first.especie, for (final p in enPie) p.especie],
      equipoRival: rival,
      parametros: parametros);
  final pregunta = base.copiarCon(
      jugador: base.jugador.copiarCon(
          equipo: [PokemonEnCombate(enPie.first.especie, 0), ...enPie]),
      fase: FaseCombate.eligiendoActivo);
  final accion = decidirAccion(pregunta, Bando.jugador) as ElegirSiguiente;
  final i = accion.indice - 1;
  return [enPie[i], for (var k = 0; k < enPie.length; k++) if (k != i) enPie[k]];
}

/// Modo «realista» (#383, tercer modo): el inicial más --capturas Pokémon
/// distintos de los salvajes de las rutas del tramo, con los PS llenos desde
/// el principio, y la IA eligiendo quién sale en cada combate.
void realista(Config c, Map<String, PokemonCampana> catalogo) {
  final d = cargarTramo(c.catalogo);
  final iniciales = d.region.nodo(d.region.inicio).iniciales;
  final salvajes = <String>{
    for (final n in d.region.nodos.values)
      if (n.tipo == TipoNodo.combate && n.rival == RivalDeCombate.salvaje)
        ...d.zonas[n.zona]!.salvajes,
  }.toList()
    ..sort();
  final lineas = ['inicial,capturas,completos,recorridos,nodo,llegan,ganan'];
  stdout.writeln('Tramo con equipo realista: inicial + ${c.capturas} capturas '
      'al azar entre ${salvajes.join(", ")}');
  stdout.writeln('${c.partidas} recorridos por inicial, semilla ${c.semilla}, '
      'Cazabichos con ${c.entrenador} Pokémon; la IA elige el activo de cada '
      'combate; daño arrastrado, curar en los descansos, sin opcionales, jefe '
      '${c.aliado ? "con" : "sin"} llamada de aliado');
  for (final i in iniciales) {
    final rnd = Random(c.semilla);
    var completos = 0;
    final porNodo = <String, Acumulado>{};
    for (var k = 0; k < c.partidas; k++) {
      final lista = salvajes.toList()..shuffle(rnd);
      final capturas = [
        for (final id in lista.take(c.capturas)) catalogo[id]!
      ];
      final r = recorrer(i, false, rnd, c, catalogo, d,
          capturas: capturas, elegirActivo: true, porNodo: porNodo);
      if (r.completo) completos++;
    }
    stdout.writeln('');
    stdout.writeln('${catalogo[i]!.nombre}: completa el tramo '
        '${pct(completos / c.partidas)}');
    for (final n in nodosConCombate(d.region)) {
      final a = porNodo[n.id];
      if (a == null) continue;
      stdout.writeln('  ${n.nombre.padRight(36)} llegan '
          '${pct(a.combates / c.partidas).padLeft(8)}   ganan '
          '${pct(a.tasa).padLeft(8)}');
      lineas.add('$i,${c.capturas},$completos,${c.partidas},${n.id},'
          '${a.combates},${a.victorias}');
    }
  }
  escribirCsv(c.informe ?? '../balance/informes/campana_realista.csv', lineas);
}
