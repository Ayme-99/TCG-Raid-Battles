// Modelo de cuentas de la campaña: ritmo de XP y número de cartas ex al llegar
// a la Liga (#451, D-20 §10.6 y §10.11, tarea 18).
//
// NO simula combates. Solo existe el primer tramo en el catálogo; los tramos 2
// a 8 no tienen rutas, rivales ni zonas (D-20 tarea 11), así que este modelo
// parte de supuestos EXPLÍCITOS (los de abajo, marcados con «SUPUESTO») y mide
// cuánto cambia el resultado al moverlos. Lo decidido por Ayme y por D-20 va
// citado con su sección.
//
// Uso (desde sim/):
//   dart run bin/sim_campana_ex.dart                 todas las tablas
//   dart run bin/sim_campana_ex.dart --csv=ruta.csv  además, el CSV de datos
//
// Reglas que aplica (D-20 §2.1, §10.6, §10.11):
//   · XP por rival derrotado: 10 / 20 / 30 según categoría de captura, sumada
//     por cada Pokémon del rival (el motor suma `_xpDeEquipo`). Reserva común.
//   · Evolucionar cuesta XP (Caterpie y Weedle 50, inicial 70, el resto
//     `xpEvo`: 80 u 110) y pide medallas mínimas (§10.11). Intercambio gratis.
//   · La carta ex es un paso más tras la última fase normal, sin XP, con una
//     piedra ex: una de premio por medalla o comprada a 2.000 de dinero.
//   · Medallas mínimas del ex: opción A 4/4/5, B 3/4/5, C 3/3/4 (Básico /
//     Fase 1 / Fase 2) y nunca menos que la de su última fase normal.
import 'dart:io';

// ---------------------------------------------------------------------------
// Datos

/// Categoría de captura → XP por Pokémon rival y probabilidad con Pokéball.
const xpCat = {'comun': 10, 'intermedio': 20, 'fuerte': 30};
const probBall = {'comun': 0.75, 'intermedio': 0.5, 'fuerte': 0.25};

/// Dinero ganado por tramo (D-20 §10.6, propuesta de Diseño sobre D-21 §2.5) y
/// dinero de salida.
const dineroTramo = [2060, 2210, 2360, 2510, 2660, 2810, 2960, 3110];
const dineroSalida = 1000;
const precioBall = 200;
const precioPiedraEx = 2000;

/// Una evolución por XP: coste (`-1` = el de `xpEvo`, 0 = intercambio gratis) y
/// medallas mínimas.
class Paso {
  const Paso(this.xp, this.medallas);
  final int xp;
  final int medallas;
}

class Especie {
  const Especie(this.id, this.categoria, this.tramo, this.pasos, this.tipoEx,
      {this.nota = ''});
  final String id;
  final String categoria;

  /// SUPUESTO: tramo en el que se captura por primera vez (orden de los
  /// juegos de Kanto; las zonas están por contrastar, #384). 1 a 8.
  final int tramo;
  final List<Paso> pasos;

  /// 0 = Básico ex, 1 = Fase 1 ex, 2 = Fase 2 ex.
  final int tipoEx;
  final String nota;
}

/// Medallas del ex según la opción de §10.11 (índice = tipoEx).
const opcionesMedallas = {
  'A': [4, 4, 5],
  'B': [3, 4, 5],
  'C': [3, 3, 4],
};

List<Especie> catalogo(String inicial) => [
      // Segunda evolución del inicial: Venusaur 4 medallas; Charizard y
      // Blastoise 5 (nivel 32 y 36 en los juegos, D-20 §10.11 opción A).
      Especie(inicial, 'comun', 1, [
        const Paso(70, 0),
        Paso(-1, inicial == 'bulbasaur' ? 4 : 5),
      ], 2),
      const Especie('caterpie', 'comun', 1, [Paso(50, 0), Paso(-1, 1)], 2),
      const Especie('weedle', 'comun', 1, [Paso(50, 0), Paso(-1, 1)], 2),
      const Especie('pidgey', 'comun', 1, [Paso(-1, 2), Paso(-1, 5)], 2),
      const Especie('rattata', 'comun', 1, [Paso(-1, 2)], 1),
      const Especie('pikachu', 'comun', 1, [], 0,
          nota: 'jefe del tramo 1; excepción: ex sin evolucionar (§10.11)'),
      const Especie('spearow', 'comun', 2, [Paso(-1, 2)], 1),
      const Especie('zubat', 'comun', 2, [Paso(-1, 2)], 1),
      const Especie('sandshrew', 'comun', 2, [Paso(-1, 2)], 1),
      const Especie('mankey', 'intermedio', 2, [Paso(-1, 3)], 1),
      const Especie('geodude', 'intermedio', 2, [Paso(-1, 3), Paso(0, 3)], 2,
          nota: 'Golem por intercambio, gratis'),
      const Especie('diglett', 'comun', 3, [Paso(-1, 3)], 1),
      const Especie('machop', 'comun', 3, [Paso(-1, 3), Paso(0, 3)], 2,
          nota: 'Machamp por intercambio, gratis'),
      const Especie('onix', 'fuerte', 3, [], 0,
          nota: '«evoluciona» a Onix ex, sin Steelix (§10.11)'),
      const Especie('cubone', 'comun', 4, [Paso(-1, 3)], 1),
      const Especie('slowpoke', 'comun', 5, [Paso(-1, 5)], 1),
    ];

/// Los Nidoran no entran: Nidorina → Nidoqueen pide Piedra Lunar, que no existe
/// en el catálogo. Eevee tampoco: no hay zona ni regalo que lo dé.
const excluidos = 'Nidoran♀, Nidoran♂ (Piedra Lunar) y Eevee (sin zona)';

// ---------------------------------------------------------------------------
// Modelo

class Escenario {
  Escenario({
    required this.nombre,
    required this.xpTramo,
    this.xpEvo = 80,
    this.opcion = 'A',
    this.inicial = 'bulbasaur',
    this.politica = 'barato',
    this.extraXpTramo = 0,
    this.pocionesTramo = 0,
  });
  final String nombre;

  /// XP de la ruta principal de cada tramo, sin repetir salvajes.
  final List<int> xpTramo;
  final int xpEvo;
  final String opcion;
  final String inicial;

  /// `barato` = el jugador completa primero las líneas que menos XP cuestan
  /// (cota superior de ex); `orden` = evoluciona en el orden en que captura,
  /// sin saltarse ninguna (más parecido a jugar sin plan).
  final String politica;

  /// XP extra por tramo, de repetir salvajes.
  final int extraXpTramo;

  /// Dinero gastado en Pociones por tramo (la IA actual no las usa).
  final int pocionesTramo;
}

class Linea {
  Linea(this.especie);
  final Especie especie;
  bool capturada = false;
  int paso = 0; // evoluciones hechas
  bool ex = false;
  int? tramoEx;

  int costeXp(int xpEvo) {
    var c = 0;
    for (var i = paso; i < especie.pasos.length; i++) {
      final p = especie.pasos[i].xp;
      c += p < 0 ? xpEvo : p;
    }
    return c;
  }

  int medallasEx(String opcion) {
    final tipo = opcionesMedallas[opcion]![especie.tipoEx];
    final ultima = especie.pasos.isEmpty ? 0 : especie.pasos.last.medallas;
    return tipo > ultima ? tipo : ultima;
  }
}

class Foto {
  Foto(this.tramo, this.ex, this.ex2, this.xpIngresada, this.xpGastada,
      this.piedrasPremio, this.piedrasCompradas, this.dinero);
  final int tramo;
  final int ex;
  final int ex2; // de ellos, de Fase 2 (los de 270 a 340 PS)
  final int xpIngresada;
  final int xpGastada;
  final int piedrasPremio;
  final int piedrasCompradas;
  final int dinero;
}

class Resultado {
  Resultado(this.fotos, this.lineas, this.capturasEsperadasCoste);
  final List<Foto> fotos;
  final List<Linea> lineas;
  final int capturasEsperadasCoste;
  Foto get fin => fotos.last;
}

Resultado correr(Escenario e) {
  final lineas = [for (final s in catalogo(e.inicial)) Linea(s)];
  var xp = 0, xpIng = 0, xpGas = 0;
  var dinero = dineroSalida;
  var premio = 0, compradas = 0, usadasPremio = 0;
  var costeCapturas = 0;
  final fotos = <Foto>[];

  for (var t = 1; t <= 8; t++) {
    final medallas = t; // se evalúa tras ganar al líder del tramo
    xp += e.xpTramo[t - 1] + e.extraXpTramo;
    xpIng += e.xpTramo[t - 1] + e.extraXpTramo;
    dinero += dineroTramo[t - 1] - e.pocionesTramo;
    // Capturas del tramo: coste esperado en Pokéballs (200 / probabilidad).
    for (final l in lineas) {
      if (l.especie.tramo == t) {
        l.capturada = true;
        final c = (precioBall / probBall[l.especie.categoria]!).round();
        dinero -= c;
        costeCapturas += c;
      }
    }
    premio += 1; // piedra ex de premio de la medalla t

    bool avanzar() {
      final cand = [for (final l in lineas) if (l.capturada && !l.ex) l];
      if (e.politica == 'barato') {
        cand.sort((a, b) => a
            .costeXp(e.xpEvo)
            .compareTo(b.costeXp(e.xpEvo)));
      }
      for (final l in cand) {
        // ¿Puede dar el siguiente paso de XP?
        if (l.paso < l.especie.pasos.length) {
          final p = l.especie.pasos[l.paso];
          final c = p.xp < 0 ? e.xpEvo : p.xp;
          if (medallas >= p.medallas && xp >= c) {
            xp -= c;
            xpGas += c;
            l.paso++;
            return true;
          }
          if (e.politica == 'orden') return false; // no se salta ninguna
          continue;
        }
        // Línea completa: hacerse ex (piedra y medallas).
        if (medallas >= l.medallasEx(e.opcion)) {
          if (usadasPremio < premio) {
            usadasPremio++;
          } else if (dinero >= precioPiedraEx) {
            dinero -= precioPiedraEx;
            compradas++;
          } else {
            if (e.politica == 'orden') return false;
            continue;
          }
          l.ex = true;
          l.tramoEx = t;
          return true;
        }
        if (e.politica == 'orden') return false;
      }
      return false;
    }

    while (avanzar()) {}
    fotos.add(Foto(
        t,
        lineas.where((l) => l.ex).length,
        lineas.where((l) => l.ex && l.especie.tipoEx == 2).length,
        xpIng,
        xpGas,
        premio,
        compradas,
        dinero));
  }
  return Resultado(fotos, lineas, costeCapturas);
}

/// XP extra por tramo que hace falta repetir para llegar a [objetivo] ex.
int extraParaObjetivo(Escenario base, int objetivo) {
  for (var x = 0; x <= 400; x += 5) {
    final e = Escenario(
        nombre: base.nombre,
        xpTramo: base.xpTramo,
        xpEvo: base.xpEvo,
        opcion: base.opcion,
        inicial: base.inicial,
        politica: base.politica,
        pocionesTramo: base.pocionesTramo,
        extraXpTramo: x);
    if (correr(e).fin.ex >= objetivo) return x;
  }
  return -1;
}

// ---------------------------------------------------------------------------
// Escenarios de XP de la ruta principal (sin repetir)

/// Tramo 1 medido sobre el catálogo (D-20 §4): Ruta 1 (10), Ruta 2 (10), dos
/// Cazabichos de 2 Pokémon (media 15 cada Pokémon: 60), Pikachu (30), Entrenador
/// Joven (Diglett 10 + Sandshrew 10) y Brock (Geodude 20 + Onix 30):
/// 10 + 10 + 60 + 30 + 20 + 50 = 180. Sin los desvíos opcionales (Ruta 22 y
/// Ruta 2 norte). Coincide con «unos 180 tras Brock» de D-20 §10.6.
const xpTramo1 = 180;

List<int> plano(int v) => List.filled(8, v);
List<int> creciente() => [
      for (var t = 0; t < 8; t++) (xpTramo1 * (1 + t / 7)).round()
    ];

// ---------------------------------------------------------------------------
// Salida

String pad(Object o, int n) => o.toString().padLeft(n);

void main(List<String> args) {
  String? csv;
  for (final a in args) {
    if (a.startsWith('--csv=')) csv = a.substring(6);
  }
  final lineasCsv = <String>[
    'tabla,xp_tramo,politica,xpEvo,opcion,inicial,medalla,ex,ex_fase2,xp_ingresada,xp_gastada,piedras_premio,piedras_compradas,dinero'
  ];

  final esc = {
    'Diseño: ~100 por tramo (700–900 en total)': plano(100),
    'Como el tramo 1: 180 por tramo': plano(xpTramo1),
    'Creciente: 180 a 360 (rivales más fuertes)': creciente(),
  };

  stdout.writeln('MODELO DE CUENTAS DE XP Y CARTAS EX (#451). No simula combates.');
  stdout.writeln('Tramo 1 medido en el catálogo: $xpTramo1 XP en la ruta principal.');
  stdout.writeln('No entran: $excluidos.');
  stdout.writeln('16 Pokémon posibles: ${[
    for (final s in catalogo("bulbasaur")) s.id
  ].join(", ")}.');
  stdout.writeln('');

  // 1) XP acumulada.
  stdout.writeln('== 1. XP de la ruta principal, sin repetir salvajes ==');
  for (final k in esc.keys) {
    final v = esc[k]!;
    stdout.writeln('${k.padRight(46)} total ${v.fold(0, (a, b) => a + b)} · '
        'por tramo ${v.join("/")}');
  }

  // 2) Ex al llegar a la Liga.
  stdout.writeln('');
  stdout.writeln('== 2. Ex al llegar a la Liga (tras la 8.ª medalla), opción A 4/4/5, inicial Bulbasaur ==');
  stdout.writeln('${"XP de la ruta".padRight(46)}${"xpEvo".padLeft(6)}${"política".padLeft(10)}${"ex".padLeft(5)}${"(Fase 2)".padLeft(9)}${"XP gastada".padLeft(12)}${"compradas".padLeft(11)}');
  for (final k in esc.keys) {
    for (final xe in [80, 110]) {
      for (final pol in ['barato', 'orden']) {
        final r = correr(Escenario(
            nombre: k, xpTramo: esc[k]!, xpEvo: xe, politica: pol));
        stdout.writeln('${k.padRight(46)}${pad(xe, 6)}${pol.padLeft(10)}'
            '${pad(r.fin.ex, 5)}${pad("(${r.fin.ex2})", 9)}'
            '${pad(r.fin.xpGastada, 12)}${pad(r.fin.piedrasCompradas, 11)}');
        for (final f in r.fotos) {
          lineasCsv.add('liga,$k,$pol,$xe,A,bulbasaur,${f.tramo},${f.ex},${f.ex2},'
              '${f.xpIngresada},${f.xpGastada},${f.piedrasPremio},${f.piedrasCompradas},${f.dinero}');
        }
      }
    }
  }

  // 3) Repetir salvajes.
  stdout.writeln('');
  stdout.writeln('== 3. XP extra por tramo (repitiendo salvajes) para llegar a 12 ex ==');
  stdout.writeln('${"XP de la ruta".padRight(46)}${"xpEvo".padLeft(6)}${"política".padLeft(10)}${"extra/tramo".padLeft(13)}${"extra total".padLeft(13)}${"combates a 10".padLeft(15)}${"a 15".padLeft(7)}${"a 20".padLeft(7)}');
  for (final k in esc.keys) {
    for (final xe in [80, 110]) {
      for (final pol in ['barato', 'orden']) {
        final b = Escenario(nombre: k, xpTramo: esc[k]!, xpEvo: xe, politica: pol);
        final x = extraParaObjetivo(b, 12);
        if (x < 0) {
          stdout.writeln('${k.padRight(46)}${pad(xe, 6)}${pol.padLeft(10)}   no llega a 12 ni con +400 por tramo');
        } else {
          final tot = x * 8;
          stdout.writeln('${k.padRight(46)}${pad(xe, 6)}${pol.padLeft(10)}'
              '${pad(x, 13)}${pad(tot, 13)}${pad((tot / 10).ceil(), 15)}'
              '${pad((tot / 15).ceil(), 7)}${pad((tot / 20).ceil(), 7)}');
        }
      }
    }
  }

  // 4) Medallas mínimas del ex.
  stdout.writeln('');
  stdout.writeln('== 4. Ex disponibles tras cada medalla, según la opción de medallas (XP como el tramo 1, xpEvo 80, política barata) ==');
  for (final op in ['A', 'B', 'C']) {
    final r = correr(Escenario(
        nombre: 'x', xpTramo: plano(xpTramo1), opcion: op, politica: 'barato'));
    stdout.writeln('opción $op ${opcionesMedallas[op]!.join("/")}:'
        '  ex por medalla ${r.fotos.map((f) => f.ex).join(" ")}'
        ' · Fase 2 ${r.fotos.map((f) => f.ex2).join(" ")}');
    for (final f in r.fotos) {
      lineasCsv.add('medallas,$xpTramo1,barato,80,$op,bulbasaur,${f.tramo},${f.ex},${f.ex2},'
          '${f.xpIngresada},${f.xpGastada},${f.piedrasPremio},${f.piedrasCompradas},${f.dinero}');
    }
  }
  stdout.writeln('');
  stdout.writeln('Con la ruta de ~100 XP por tramo:');
  for (final op in ['A', 'B', 'C']) {
    final r = correr(Escenario(
        nombre: 'x', xpTramo: plano(100), opcion: op, politica: 'barato'));
    stdout.writeln('opción $op ${opcionesMedallas[op]!.join("/")}:'
        '  ex por medalla ${r.fotos.map((f) => f.ex).join(" ")}'
        ' · Fase 2 ${r.fotos.map((f) => f.ex2).join(" ")}');
  }

  // 5) Dinero.
  stdout.writeln('');
  stdout.writeln('== 5. Dinero: piedras compradas junto a Pokéballs y Pociones (XP como el tramo 1, xpEvo 80, opción A, barato) ==');
  stdout.writeln('${"Pociones por tramo".padRight(22)}${"ex Liga".padLeft(9)}${"compradas".padLeft(11)}${"dinero final".padLeft(14)}');
  final r0 = correr(Escenario(nombre: 'x', xpTramo: plano(xpTramo1)));
  for (final gp in [0, 600, 1200, 1800]) {
    final r = correr(Escenario(
        nombre: 'x', xpTramo: plano(xpTramo1), pocionesTramo: gp));
    stdout.writeln('${"$gp (${gp ~/ 300} Pociones)".padRight(22)}'
        '${pad(r.fin.ex, 9)}${pad(r.fin.piedrasCompradas, 11)}${pad(r.fin.dinero, 14)}');
  }
  stdout.writeln('Coste esperado de capturar las 16 especies con Pokéball: '
      '${r0.capturasEsperadasCoste} (${(r0.capturasEsperadasCoste / precioBall).toStringAsFixed(1)} Pokéballs).');
  stdout.writeln('Dinero total de 8 tramos: ${dineroTramo.fold(0, (a, b) => a + b)} + $dineroSalida de salida.');

  // 6) Por inicial.
  stdout.writeln('');
  stdout.writeln('== 6. Por inicial (XP como el tramo 1 y ~100, xpEvo 80, opción A, barato) ==');
  for (final ini in ['bulbasaur', 'charmander', 'squirtle']) {
    for (final v in [100, xpTramo1]) {
      final r = correr(Escenario(
          nombre: 'x', xpTramo: plano(v), inicial: ini));
      stdout.writeln('${ini.padRight(11)} ${pad(v, 4)} XP/tramo → ${r.fin.ex} ex');
    }
  }

  // 8) Palanca: más XP en los rivales de los tramos 5 a 8.
  stdout.writeln('');
  stdout.writeln('== 8. Palanca «XP propia en los rivales de los tramos 5 a 8» (ruta de ~100) ==');
  stdout.writeln('${"xpEvo".padLeft(6)}${"política".padLeft(10)}${"extra por tramo (5 a 8)".padLeft(26)}${"extra total".padLeft(13)}');
  for (final xe in [80, 110]) {
    for (final pol in ['barato', 'orden']) {
      int? hallado;
      for (var b = 0; b <= 400; b += 5) {
        final v = [for (var t = 1; t <= 8; t++) 100 + (t >= 5 ? b : 0)];
        if (correr(Escenario(nombre: 'x', xpTramo: v, xpEvo: xe, politica: pol)).fin.ex >= 12) {
          hallado = b;
          break;
        }
      }
      stdout.writeln('${pad(xe, 6)}${pol.padLeft(10)}'
          '${pad(hallado ?? "no llega", 26)}${pad(hallado == null ? "—" : hallado * 4, 13)}');
    }
  }

  // 7) Detalle de la ruta de ~100 con xpEvo 80, qué ex salen.
  stdout.writeln('');
  stdout.writeln('== 7. Qué ex salen (≈100 XP/tramo, xpEvo 80, opción A, barato) ==');
  final rd = correr(Escenario(nombre: 'x', xpTramo: plano(100)));
  for (final l in rd.lineas) {
    stdout.writeln('${l.especie.id.padRight(11)} ${l.ex ? "ex en el tramo ${l.tramoEx}" : "sin ex (le faltan ${l.costeXp(80)} XP)"}');
  }

  if (csv != null) {
    File(csv).writeAsStringSync('${lineasCsv.join("\n")}\n');
    stdout.writeln('\nCSV: $csv');
  }
}
