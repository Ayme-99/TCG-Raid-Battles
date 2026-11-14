// Simulador Monte Carlo de Incursiones con CARTAS REALES (tarjeta D-03).
//
// Sustituye al modelo abstracto de sim.dart: la vida y los ataques de los
// Pokémon de los jugadores salen de balance/tablas/cartas_prueba.csv y
// balance/tablas/ataques_prueba.csv, y se aplican las reglas de la hoja
// oficial de Raid Battle:
//   - Sin Energía: los ataques que escalan con Energía, contadores o Premios
//     hacen solo su daño base (columna "banderas" = dep, solo informativa).
//   - Un ataque "no puede atacar el turno siguiente" (cd) bloquea ese turno.
//   - Un ataque GX (gx) solo se usa una vez por jugador y partida.
//   - Cada jugador lleva una pareja (activo + banco); siempre hay 4 parejas.
//   - X = suma, por pareja, del mayor daño base de sus dos Pokémon.
//   - Derrota (regla GDD): todos los Pokémon de todos los jugadores KO.
//
// Uso (desde la carpeta sim/):
//   dart run bin/sim_cartas.dart
//   dart run bin/sim_cartas.dart --calibrar
//
// Opciones:
//   --equipos=N     equipos de prueba por nivel (defecto 150)
//   --partidas=N    partidas por equipo (defecto 60)
//   --max-turnos=N  límite de turnos (defecto 40)
//   --semilla=N     semilla (defecto 1)
//   --calibrar      busca el HP del jefe que da el objetivo 75/50/30/15 %
//   --catalogo=RUTA --ataques=RUTA --tabla=RUTA --informe=RUTA
import 'dart:io';
import 'dart:math';

class Ataque {
  Ataque(this.nombre, this.dano, this.banderas);
  final String nombre;
  final int dano;
  final String banderas;
  bool get cd => banderas.contains('cd');
  bool get gx => banderas.contains('gx');
}

class Carta {
  Carta(this.nombre, this.tipo, this.hp);
  final String nombre;
  final String tipo;
  final int hp;
  final List<Ataque> ataques = [];
  int get mejorBase => ataques.map((a) => a.dano).reduce(max);
  bool get sinReglaEspecial =>
      tipo == 'Básico' || tipo == 'Fase 1' || tipo == 'Fase 2';
}

class Nivel {
  Nivel(this.nivel, this.xMin, this.hp, this.ataques, this.maxAtaques);
  final int nivel;
  final int xMin;
  final int hp;
  final List<int> ataques;
  final int maxAtaques;
}

class Config {
  int equipos = 150;
  int partidas = 60;
  int maxTurnos = 40;
  int semilla = 1;
  bool calibrar = false;
  String catalogo = '../balance/tablas/cartas_prueba.csv';
  String ataques = '../balance/tablas/ataques_prueba.csv';
  String tabla = '../balance/tablas/niveles.csv';
  String informe = '../balance/informes/d03_cartas.csv';

  /// Cartas de ánimo (D-05, 1 a 5) que puede robar el jugador KO al sentarse.
  /// Vacío = no se modelan (lo que asumían las calibraciones anteriores).
  List<int> animo = const [];
}

const double probSeguir = 0.65;
const Map<int, double> objetivo = {1: 0.75, 2: 0.50, 3: 0.30, 4: 0.15};

Config leerArgs(List<String> args) {
  final c = Config();
  for (final a in args) {
    if (a == '--calibrar') {
      c.calibrar = true;
      continue;
    }
    final i = a.indexOf('=');
    if (!a.startsWith('--') || i < 0) {
      stderr.writeln('Argumento ignorado: $a');
      continue;
    }
    final k = a.substring(2, i);
    final v = a.substring(i + 1);
    switch (k) {
      case 'equipos':
        c.equipos = int.parse(v);
      case 'partidas':
        c.partidas = int.parse(v);
      case 'max-turnos':
        c.maxTurnos = int.parse(v);
      case 'semilla':
        c.semilla = int.parse(v);
      case 'catalogo':
        c.catalogo = v;
      case 'ataques':
        c.ataques = v;
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

List<String> lineasCsv(String ruta) =>
    File(ruta).readAsLinesSync().where((l) => l.trim().isNotEmpty).skip(1).toList();

Map<String, Carta> leerCatalogo(String rutaCartas, String rutaAtaques) {
  final cartas = <String, Carta>{};
  for (final l in lineasCsv(rutaCartas)) {
    final c = l.split(',');
    // id,nombre,tipo_carta,expansion,numero,hp,...
    cartas[c[1]] = Carta(c[1], c[2], int.parse(c[5]));
  }
  for (final l in lineasCsv(rutaAtaques)) {
    final c = l.split(',');
    // carta,ataque,dano,banderas
    final carta = cartas[c[0]];
    if (carta == null) {
      stderr.writeln('Ataque de carta desconocida: ${c[0]}');
      continue;
    }
    carta.ataques.add(Ataque(c[1], int.parse(c[2]), c.length > 3 ? c[3] : ''));
  }
  for (final carta in cartas.values) {
    if (carta.ataques.isEmpty) {
      throw StateError('La carta ${carta.nombre} no tiene ataques');
    }
  }
  return cartas;
}

List<Nivel> leerNiveles(String ruta) {
  return [
    for (final l in lineasCsv(ruta))
      () {
        final c = l.split(',');
        return Nivel(
          int.parse(c[0]),
          int.parse(c[1]),
          int.parse(c[4]),
          [int.parse(c[5]), int.parse(c[6]), int.parse(c[7])],
          int.parse(c[8]),
        );
      }()
  ];
}

/// Nivel según X: el más alto cuyo x_min no supera X (mínimo Nv1).
int nivelPorX(int x, List<Nivel> niveles) {
  var n = 1;
  for (final nv in niveles) {
    if (nv.nivel > 1 && x >= nv.xMin) n = max(n, nv.nivel);
  }
  return n;
}

class Pareja {
  /// Los Pokémon de un jugador: dos, o más si hay pocos jugadores y se
  /// mantienen 8 Pokémon en mesa ([extra]).
  Pareja(this.a, this.b, [this.extra = const []]);
  final Carta a;
  final Carta b;
  final List<Carta> extra;
  List<Carta> get cartas => [a, b, ...extra];
}

int calcularX(List<Pareja> equipo) =>
    equipo.fold(0, (s, p) => s + p.cartas.map((c) => c.mejorBase).reduce(max));

List<Pareja> equipoAzar(Random rnd, List<Carta> cartas) {
  final m = List<Carta>.from(cartas)..shuffle(rnd);
  return [for (var i = 0; i < 8; i += 2) Pareja(m[i], m[i + 1])];
}

/// Equipo de Nv1: solo cartas sin regla especial, pueden repetirse.
List<Pareja> equipoNormales(Random rnd, List<Carta> normales) {
  Carta c() => normales[rnd.nextInt(normales.length)];
  return [for (var i = 0; i < 4; i++) Pareja(c(), c())];
}

class Poke {
  Poke(this.carta) : hp = carta.hp;
  final Carta carta;
  int hp;
  int cd = 0;
  bool get vivo => hp > 0;
}

class Jug {
  Jug(Pareja p) : pokes = [for (final c in p.cartas) Poke(c)];
  final List<Poke> pokes; // pokes[0] = activo
  bool gxUsado = false;
  bool get eliminado => pokes.every((p) => !p.vivo);

  /// Primer Pokémon vivo de la Banca, si lo hay.
  Poke? get banca {
    for (var i = 1; i < pokes.length; i++) {
      if (pokes[i].vivo) return pokes[i];
    }
    return null;
  }

  /// Cambia el Activo por el primer Pokémon vivo de la Banca.
  void intercambiar() {
    var i = 1;
    while (i < pokes.length && !pokes[i].vivo) {
      i++;
    }
    if (i >= pokes.length) i = 1;
    final t = pokes[0];
    pokes[0] = pokes[i];
    pokes[i] = t;
  }

  Ataque? elegir(Poke p) {
    if (p.cd > 0) return null;
    Ataque? mejor;
    for (final a in p.carta.ataques) {
      if (a.gx && gxUsado) continue;
      if (mejor == null ||
          a.dano > mejor.dano ||
          (a.dano == mejor.dano && mejor.gx && !a.gx)) {
        mejor = a;
      }
    }
    return mejor;
  }
}

/// Devuelve el turno de la victoria (>0) o 0 si pierden o se agota el tiempo.
int jugar(List<Pareja> equipo, Nivel nv, int hpJefe, Config c, Random rnd) {
  final js = [for (final p in equipo) Jug(p)];
  var hp = hpJefe;
  for (var t = 1; t <= c.maxTurnos; t++) {
    for (final j in js) {
      if (j.eliminado) continue;
      if (!j.pokes[0].vivo) j.intercambiar();
      var act = j.pokes[0];
      var ch = j.elegir(act);
      if (ch == null && j.pokes[1].vivo) {
        // Retirada: ataca el Pokémon del banco.
        j.intercambiar();
        act = j.pokes[0];
        ch = j.elegir(act);
      }
      if (ch != null) {
        hp -= ch.dano;
        if (ch.cd) act.cd = 2;
        if (ch.gx) j.gxUsado = true;
      }
      for (final p in j.pokes) {
        if (p.cd > 0) p.cd--;
      }
    }
    if (hp <= 0) return t;
    var k = 1;
    while (k < nv.maxAtaques && rnd.nextDouble() < probSeguir) {
      k++;
    }
    for (var i = 0; i < k; i++) {
      final vivos = js.where((j) => !j.eliminado).toList();
      if (vivos.isEmpty) break;
      final j = vivos[rnd.nextInt(vivos.length)];
      if (!j.pokes[0].vivo) j.intercambiar();
      final r = rnd.nextDouble();
      j.pokes[0].hp -= nv.ataques[r < 0.4 ? 0 : (r < 0.8 ? 1 : 2)];
    }
    if (js.every((j) => j.eliminado)) return 0;
  }
  return 0;
}

class Medida {
  Medida(this.victoria, this.turnosVictoria);
  final double victoria;
  final double turnosVictoria;
}

Medida medir(List<List<Pareja>> equipos, Nivel nv, int hp, Config c, int semilla) {
  final rnd = Random(semilla);
  var tasas = 0.0;
  var turnos = 0;
  var victorias = 0;
  for (final e in equipos) {
    var w = 0;
    for (var i = 0; i < c.partidas; i++) {
      final t = jugar(e, nv, hp, c, rnd);
      if (t > 0) {
        w++;
        turnos += t;
      }
    }
    victorias += w;
    tasas += w / c.partidas;
  }
  return Medida(tasas / equipos.length, victorias == 0 ? 0 : turnos / victorias);
}

int calibrarHp(List<List<Pareja>> equipos, Nivel nv, Config c) {
  var lo = 200;
  var hi = 12000;
  for (var i = 0; i < 11; i++) {
    final m = (lo + hi) ~/ 2;
    if (medir(equipos, nv, m, c, 3).victoria > objetivo[nv.nivel]!) {
      lo = m;
    } else {
      hi = m;
    }
  }
  return hi;
}

void main(List<String> args) {
  final c = leerArgs(args);
  final cartas = leerCatalogo(c.catalogo, c.ataques);
  final lista = cartas.values.toList();
  final normales = lista.where((x) => x.sinReglaEspecial).toList();
  final niveles = leerNiveles(c.tabla);
  final rnd = Random(c.semilla);

  // Equipos de prueba por nivel (por rechazo hasta llenar cada nivel).
  final porNivel = {for (final n in niveles) n.nivel: <List<Pareja>>[]};
  for (final n in niveles) {
    final destino = porNivel[n.nivel]!;
    for (var intento = 0; intento < 200000 && destino.length < c.equipos; intento++) {
      final e = n.nivel == 1 ? equipoNormales(rnd, normales) : equipoAzar(rnd, lista);
      if (nivelPorX(calcularX(e), niveles) == n.nivel) destino.add(e);
    }
  }

  stdout.writeln('Incursiones · simulador D-03 con cartas reales');
  stdout.writeln('cartas=${lista.length} equipos/nivel=${c.equipos} '
      'partidas/equipo=${c.partidas} calibrar=${c.calibrar}\n');
  stdout.writeln('nivel  equipos  X          HP jefe  victoria  objetivo  turnos(vic)');
  final filas = <String>['nivel,equipos,x_min,x_max,hp,victoria,objetivo,turnos_victoria'];
  for (final n in niveles) {
    final eqs = porNivel[n.nivel]!;
    if (eqs.isEmpty) {
      stdout.writeln('${n.nivel}      sin equipos de este nivel');
      continue;
    }
    final xs = eqs.map(calcularX).toList();
    final xMin = xs.reduce(min);
    final xMax = xs.reduce(max);
    final hp = c.calibrar ? calibrarHp(eqs, n, c) : n.hp;
    final m = medir(eqs, n, hp, c, c.semilla);
    stdout.writeln('${n.nivel}      ${eqs.length.toString().padRight(7)}  '
        '${'$xMin-$xMax'.padRight(9)}  ${hp.toString().padRight(7)}  '
        '${(100 * m.victoria).toStringAsFixed(1).padLeft(5)} %    '
        '${(100 * objetivo[n.nivel]!).toStringAsFixed(0).padLeft(3)} %     '
        '${m.turnosVictoria.toStringAsFixed(1)}');
    filas.add('${n.nivel},${eqs.length},$xMin,$xMax,$hp,'
        '${m.victoria.toStringAsFixed(4)},${objetivo[n.nivel]},'
        '${m.turnosVictoria.toStringAsFixed(1)}');
  }
  File(c.informe)
    ..createSync(recursive: true)
    ..writeAsStringSync('${filas.join('\n')}\n');
  stdout.writeln('\nInforme guardado en ${c.informe}');
  if (c.calibrar) {
    stdout.writeln('HP calibrado: copia la columna "HP jefe" a balance/tablas/niveles.csv.');
  }
}
