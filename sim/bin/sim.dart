// Simulador Monte Carlo de balance de Incursiones (tarjeta D-03).
//
// Modelo simplificado: sirve para ver TENDENCIAS (¿el nivel N es más fácil o
// difícil que el N+1?), no para dar probabilidades exactas. Los parámetros de
// los Pokémon de los jugadores son hipótesis a medir en playtests (T-17).
//
// Uso (desde la carpeta sim/):
//   dart run bin/sim.dart
//   dart run bin/sim.dart --partidas=5000 --jugadores=3 --regla=gdd
//
// Opciones:
//   --partidas=N       partidas por nivel (defecto 2000)
//   --jugadores=N      3 o 4 (defecto 4)
//   --hp-base=N        HP base de un Pokémon de jugador (defecto 60)
//   --hp-factor=F      HP extra por punto de ataque (defecto 0.6)
//   --eficiencia=F     fracción del ataque que realmente se aplica (defecto 0.85)
//   --regla=gdd|oficial  derrota con todos eliminados (gdd, defecto del proyecto) o a los 4 KO (oficial)
//   --max-turnos=N     límite de turnos antes de dar la partida por perdida (30)
//   --semilla=N        semilla del generador aleatorio (defecto 1)
//   --tabla=RUTA       CSV de niveles (defecto ../balance/tablas/niveles.csv)
//   --informe=RUTA     CSV de salida (defecto ../balance/informes/d03_niveles.csv)
import 'dart:io';
import 'dart:math';

import 'package:incursiones_engine/incursiones_engine.dart'
    show MazoAtaquesJefe;

class Nivel {
  Nivel(this.nivel, this.xCentro, this.hp, this.ataques, this.maxAtaques);
  final int nivel;
  final int xCentro;
  final int hp;
  final List<int> ataques; // daño de los 3 ataques del jefe
  final int maxAtaques;
}

class Config {
  int partidas = 2000;
  int jugadores = 4;
  double hpBase = 60;
  double hpFactor = 0.6;
  double eficiencia = 0.85;
  String regla = 'gdd';
  int maxTurnos = 30;
  int semilla = 1;
  String tabla = '../balance/tablas/niveles.csv';
  String informe = '../balance/informes/d03_niveles.csv';
}

class Resultado {
  int victorias = 0;
  int derrotas = 0;
  int tiempoAgotado = 0;
  int turnosVictoria = 0;
  int koTotales = 0;
}

const double probSeguir = 0.65; // robar otra carta de ataque del jefe
const List<double> probSlot = [0.4, 0.4, 0.2]; // 8/8/4 de 20 cartas

Config leerArgs(List<String> args) {
  final c = Config();
  for (final a in args) {
    final i = a.indexOf('=');
    if (!a.startsWith('--') || i < 0) {
      stderr.writeln('Argumento ignorado: $a');
      continue;
    }
    final k = a.substring(2, i);
    final v = a.substring(i + 1);
    switch (k) {
      case 'partidas':
        c.partidas = int.parse(v);
      case 'jugadores':
        c.jugadores = int.parse(v);
      case 'hp-base':
        c.hpBase = double.parse(v);
      case 'hp-factor':
        c.hpFactor = double.parse(v);
      case 'eficiencia':
        c.eficiencia = double.parse(v);
      case 'regla':
        c.regla = v;
      case 'max-turnos':
        c.maxTurnos = int.parse(v);
      case 'semilla':
        c.semilla = int.parse(v);
      case 'tabla':
        c.tabla = v;
      case 'informe':
        c.informe = v;
      default:
        stderr.writeln('Opción desconocida: $k');
    }
  }
  return c;
}

List<Nivel> leerNiveles(String ruta) {
  final lineas = File(ruta).readAsLinesSync().where((l) => l.trim().isNotEmpty);
  final niveles = <Nivel>[];
  for (final l in lineas.skip(1)) {
    final c = l.split(',');
    niveles.add(Nivel(
      int.parse(c[0]),
      int.parse(c[3]),
      int.parse(c[4]),
      [int.parse(c[5]), int.parse(c[6]), int.parse(c[7])],
      int.parse(c[8]),
    ));
  }
  return niveles;
}

/// Un Pokémon de jugador.
class Poke {
  Poke(this.ataque, this.hp);
  final double ataque;
  double hp;
  bool get vivo => hp > 0;
}

/// Un jugador: dos Pokémon, el primero activo mientras viva.
class Jugador {
  Jugador(this.pokes);
  final List<Poke> pokes;
  Poke? get activo {
    for (final p in pokes) {
      if (p.vivo) return p;
    }
    return null;
  }

  bool get eliminado => activo == null;
}

Jugador crearJugador(Random rnd, double mejorAtaque, Config c) {
  final a1 = mejorAtaque;
  final a2 = mejorAtaque * 0.6;
  return Jugador([
    Poke(a1, c.hpBase + c.hpFactor * a1),
    Poke(a2, c.hpBase + c.hpFactor * a2),
  ]);
}

/// Reparte X entre los jugadores (±20 % de variación) conservando la suma.
List<double> repartirX(Random rnd, int x, int n) {
  final pesos = List.generate(n, (_) => 0.8 + rnd.nextDouble() * 0.4);
  final total = pesos.reduce((a, b) => a + b);
  return pesos.map((p) => x * p / total).toList();
}

int numAtaquesJefe(Random rnd, int maxAtaques) {
  var n = 1;
  while (n < maxAtaques && rnd.nextDouble() < probSeguir) {
    n++;
  }
  return n;
}

int slotAleatorio(Random rnd) {
  final r = rnd.nextDouble();
  if (r < probSlot[0]) return 0;
  if (r < probSlot[0] + probSlot[1]) return 1;
  return 2;
}

/// Devuelve 1 victoria, 0 derrota, -1 tiempo agotado. Escribe KO en [ko].
int jugarPartida(Nivel nv, Config c, Random rnd, List<int> turnosYKo) {
  final ataquesJ = repartirX(rnd, nv.xCentro, c.jugadores);
  final jugadores = [for (final a in ataquesJ) crearJugador(rnd, a, c)];
  final mazo = MazoAtaquesJefe(rnd, jugadores: jugadores.length);
  var hpJefe = nv.hp.toDouble();
  var ko = 0;

  for (var turno = 1; turno <= c.maxTurnos; turno++) {
    // Turno de los jugadores: cada uno ataca con su Pokémon activo.
    for (final j in jugadores) {
      final p = j.activo;
      if (p == null) continue;
      hpJefe -= p.ataque * c.eficiencia;
    }
    if (hpJefe <= 0) {
      turnosYKo[0] = turno;
      turnosYKo[1] = ko;
      return 1;
    }
    // Turno del jefe: roba cartas del mazo real (20 oficiales; según los
    // jugadores se quitan o se redirigen) hasta que una no diga «roba otra» o
    // llegue al máximo del nivel.
    for (var i = 0; i < nv.maxAtaques; i++) {
      final activos = {
        for (var k = 0; k < jugadores.length; k++)
          if (!jugadores[k].eliminado) k,
      };
      if (activos.isEmpty) break;
      final carta = mazo.robar(activos);
      final p = jugadores[carta.jugador].activo!;
      p.hp -= nv.ataques[carta.ranura - 1];
      if (!p.vivo) ko++;
      if (!carta.robaOtra) break;
    }
    final derrota = c.regla == 'oficial'
        ? ko >= 4
        : jugadores.every((j) => j.eliminado);
    if (derrota) {
      turnosYKo[0] = turno;
      turnosYKo[1] = ko;
      return 0;
    }
  }
  turnosYKo[0] = c.maxTurnos;
  turnosYKo[1] = ko;
  return -1;
}

void main(List<String> args) {
  final c = leerArgs(args);
  if (c.jugadores < 1 || c.partidas < 1) {
    stderr.writeln('--jugadores y --partidas deben ser positivos.');
    exit(1);
  }
  final niveles = leerNiveles(c.tabla);
  final rnd = Random(c.semilla);

  stdout.writeln('Incursiones · simulador D-03');
  stdout.writeln('partidas/nivel=${c.partidas} jugadores=${c.jugadores} '
      'regla=${c.regla} hp=${c.hpBase}+${c.hpFactor}*ataque '
      'eficiencia=${c.eficiencia} semilla=${c.semilla}');
  stdout.writeln('');
  stdout.writeln('nivel  X     HP jefe  victoria  turnos(vic)  KO/partida');

  final filas = <String>[
    'nivel,x,hp_jefe,jugadores,regla,partidas,victoria_pct,derrota_pct,'
        'agotado_pct,turnos_medios_victoria,ko_medios'
  ];

  for (final nv in niveles) {
    final r = Resultado();
    final buf = [0, 0];
    for (var i = 0; i < c.partidas; i++) {
      final res = jugarPartida(nv, c, rnd, buf);
      r.koTotales += buf[1];
      if (res == 1) {
        r.victorias++;
        r.turnosVictoria += buf[0];
      } else if (res == 0) {
        r.derrotas++;
      } else {
        r.tiempoAgotado++;
      }
    }
    final pct = (int v) => 100.0 * v / c.partidas;
    final turnos = r.victorias == 0 ? 0.0 : r.turnosVictoria / r.victorias;
    final ko = r.koTotales / c.partidas;
    stdout.writeln('${nv.nivel}      ${nv.xCentro.toString().padRight(5)} '
        '${nv.hp.toString().padRight(8)} '
        '${pct(r.victorias).toStringAsFixed(1).padLeft(5)} %   '
        '${turnos.toStringAsFixed(1).padLeft(6)}       '
        '${ko.toStringAsFixed(2)}');
    filas.add('${nv.nivel},${nv.xCentro},${nv.hp},${c.jugadores},${c.regla},'
        '${c.partidas},${pct(r.victorias).toStringAsFixed(1)},'
        '${pct(r.derrotas).toStringAsFixed(1)},'
        '${pct(r.tiempoAgotado).toStringAsFixed(1)},'
        '${turnos.toStringAsFixed(2)},${ko.toStringAsFixed(2)}');
  }

  final f = File(c.informe);
  f.parent.createSync(recursive: true);
  f.writeAsStringSync('${filas.join('\n')}\n');
  stdout.writeln('');
  stdout.writeln('Informe guardado en ${c.informe}');
}
