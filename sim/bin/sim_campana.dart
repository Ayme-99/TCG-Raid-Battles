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
//
// Modos:
//   duelos    cada Pokémon contra cada Pokémon (también contra sí mismo) con
//             el jugador y con el rival empezando. La IA es determinista, así
//             que no hace falta repetir.
//   equipos   equipos aleatorios de --tamano Pokémon distintos, --partidas
//             combates (empieza siempre el jugador, como en el juego).
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
]) {
  var e = EstadoCombate.inicial(
    equipoJugador: jugador,
    equipoRival: rival,
    empieza: empieza,
    parametros: parametros,
    semilla: semilla,
  );
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
    default:
      stderr.writeln('--modo: usa «duelos» o «equipos»');
      exit(2);
  }
}
