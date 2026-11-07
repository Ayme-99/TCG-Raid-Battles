// Simulador de los jefes del catálogo CON ALIADOS (T-28).
//
// Reutiliza los equipos de cartas reales y las reglas de sim_cartas.dart
// (D-03) y añade lo que ese simulador no modela, tal como lo define el GDD §4.4
// y D-13:
//   - Invocación por umbral: cada vez que el jefe pierde `cadaHp` HP hay un
//     intento (el golpe que lo deja a 0 HP no da ninguno). Con tirada
//     `segura` no hay moneda; con `moneda` solo sigue si sale cara.
//   - Un dado elige el slot entre los libres de jugadores activos y otro la
//     categoría entre las que no están en uso. Sin slot libre no hay aliado.
//   - Al entrar, el aliado ataca (si tiene ataque); luego vuelve a atacar al
//     final del turno del jefe. Daño al Pokémon Activo del dueño de su slot
//     (si está eliminado, a un jugador activo al azar). El Pícaro ataca a la
//     Banca.
//   - Bloqueo: un jugador con un aliado vivo en su slot debe debilitarlo antes
//     de dañar al jefe. El exceso de daño al aliado se pierde.
//   - Ayuda (opcional): un jugador libre ataca al aliado de un compañero en
//     vez de al jefe, con la probabilidad --ayuda (0 = solo el dueño).
//
// NO modela (el informe lo dice): efectos de las habilidades (Tanque, Cura,
// Pícaro), veneno ni quemadura del jefe, ni el cambio de Pokémon activo por
// efectos. Hasta que existan scripts de aliados (D-13), esas habilidades las
// resuelve la mesa. Por eso las cifras son una COTA OPTIMISTA para los
// jugadores salvo en la política «solo el dueño», que es la más dura.
//
// Uso (desde sim/):
//   dart run bin/sim_jefes.dart
//   dart run bin/sim_jefes.dart --equipos=20 --partidas=20 --informe=/tmp/j.csv
//
// Opciones propias:
//   --jefes=RUTA      carpeta del catálogo (defecto ../catalog)
//   --ayuda=P         probabilidad de ayuda en la política «ayuda» (0.5)
// Y las de sim_cartas.dart: --equipos --partidas --max-turnos --semilla
//   --catalogo --ataques --tabla --informe (aquí, defecto
//   ../balance/informes/jefes_aliados.csv).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'sim_cartas.dart' hide Medida, main, medir;

const categorias = ['danio', 'tanque', 'cura', 'picaro'];

class AliadoDef {
  AliadoDef(this.nombre, this.hp, this.dano);
  final String nombre;
  final int hp;
  final int? dano;
}

class JefeDef {
  JefeDef({
    required this.id,
    required this.nombre,
    required this.nivel,
    required this.hp,
    required this.ataques,
    required this.cadaHp,
    required this.segura,
    required this.aliados,
  });
  final String id;
  final String nombre;
  final int nivel;
  final int hp;
  final List<int> ataques;
  final int? cadaHp;
  final bool segura;
  final Map<String, AliadoDef> aliados;
}

Map<String, Object?> _mapa(Object? v) => Map<String, Object?>.from(v as Map);

List<JefeDef> leerJefes(String carpeta) {
  final indice = _mapa(jsonDecode(File('$carpeta/catalogo.json').readAsStringSync()));
  final jefes = <JefeDef>[];
  for (final id in (indice['jefes'] as List).cast<String>()) {
    final j = _mapa(jsonDecode(File('$carpeta/bosses/$id.json').readAsStringSync()));
    final inv = j['invocacion'] == null ? null : _mapa(j['invocacion']);
    final aliados = <String, AliadoDef>{};
    if (inv != null) {
      final a = _mapa(inv['aliados']);
      for (final cat in categorias) {
        final d = _mapa(a[cat]);
        final ataque = d['ataque'] == null ? null : _mapa(d['ataque']);
        aliados[cat] = AliadoDef(
          d['nombre'] as String,
          d['hp'] as int,
          ataque == null ? null : ataque['dano'] as int,
        );
      }
    }
    jefes.add(JefeDef(
      id: id,
      nombre: j['nombre'] as String,
      nivel: j['nivel'] as int,
      hp: j['hp'] as int,
      ataques: [for (final a in j['ataques'] as List) _mapa(a)['dano'] as int],
      cadaHp: inv == null ? null : inv['cadaHp'] as int,
      segura: inv != null && inv['tirada'] == 'segura',
      aliados: aliados,
    ));
  }
  return jefes;
}

class Aliado {
  Aliado(this.categoria, this.def) : hp = def.hp;
  final String categoria;
  final AliadoDef def;
  int hp;
  bool get vivo => hp > 0;
  bool get ataca => def.dano != null;
  bool get atacaBanca => categoria == 'picaro';
}

class Resultado {
  Resultado(this.turnoVictoria, this.invocados);

  /// Turno de la victoria (>0) o 0 si pierden o se agota el tiempo.
  final int turnoVictoria;
  final int invocados;
}

/// Daño a un jugador: al Activo, o a la Banca si [banca] y está viva.
void golpear(Jug j, int dano, {bool banca = false}) {
  if (banca && j.pokes[1].vivo) {
    j.pokes[1].hp -= dano;
    return;
  }
  if (!j.pokes[0].vivo) j.intercambiar();
  j.pokes[0].hp -= dano;
}

/// [ayuda]: probabilidad de que un jugador libre ataque al aliado de un
/// compañero en vez de al jefe (0 = solo el dueño ataca a su aliado).
Resultado jugarJefe(
  List<Pareja> equipo,
  JefeDef jefe,
  Nivel nv,
  Config c,
  Random rnd,
  double ayuda,
) {
  final js = [for (final p in equipo) Jug(p)];
  final slots = List<Aliado?>.filled(js.length, null);
  var hp = jefe.hp;
  var cruzados = 0;
  var invocados = 0;

  // Ataque de un aliado: a su dueño, o a un jugador activo al azar si el
  // dueño está eliminado.
  void atacarAliado(int slot, Aliado a) {
    if (!a.ataca) return;
    var objetivo = slot;
    if (js[objetivo].eliminado) {
      final activos = [
        for (var i = 0; i < js.length; i++)
          if (!js[i].eliminado) i,
      ];
      if (activos.isEmpty) return;
      objetivo = activos[rnd.nextInt(activos.length)];
    }
    golpear(js[objetivo], a.def.dano!, banca: a.atacaBanca);
  }

  void invocar() {
    final libres = [
      for (var i = 0; i < js.length; i++)
        if (!js[i].eliminado && slots[i] == null) i,
    ];
    if (libres.isEmpty) return;
    if (!jefe.segura && rnd.nextBool() == false) return; // la moneda no salió
    final enUso = {
      for (final a in slots)
        if (a != null) a.categoria,
    };
    final catsLibres = [
      for (final cat in categorias)
        if (!enUso.contains(cat)) cat,
    ];
    if (catsLibres.isEmpty) return;
    final slot = libres[rnd.nextInt(libres.length)];
    final cat = catsLibres[rnd.nextInt(catsLibres.length)];
    final a = Aliado(cat, jefe.aliados[cat]!);
    slots[slot] = a;
    invocados++;
    atacarAliado(slot, a); // ataque de entrada
  }

  for (var t = 1; t <= c.maxTurnos; t++) {
    for (var i = 0; i < js.length; i++) {
      final j = js[i];
      if (j.eliminado) continue;
      if (!j.pokes[0].vivo) j.intercambiar();
      var act = j.pokes[0];
      var ch = j.elegir(act);
      if (ch == null && j.pokes[1].vivo) {
        j.intercambiar();
        act = j.pokes[0];
        ch = j.elegir(act);
      }
      if (ch == null) {
        for (final p in j.pokes) {
          if (p.cd > 0) p.cd--;
        }
        continue;
      }

      // A quién ataca: a su aliado si lo tiene delante; si no, quizá ayuda
      // a un compañero bloqueado; si no, al jefe.
      int? objetivoAliado;
      final propio = slots[i];
      if (propio != null) {
        objetivoAliado = i;
      } else if (ayuda > 0 && rnd.nextDouble() < ayuda) {
        final bloqueantes = [
          for (var k = 0; k < js.length; k++)
            if (k != i && slots[k] != null && !js[k].eliminado) k,
        ];
        if (bloqueantes.isNotEmpty) {
          objetivoAliado = bloqueantes[rnd.nextInt(bloqueantes.length)];
        }
      }

      if (objetivoAliado != null) {
        final a = slots[objetivoAliado]!;
        a.hp -= ch.dano; // el exceso se pierde
        if (!a.vivo) slots[objetivoAliado] = null;
      } else {
        hp -= ch.dano;
        if (hp <= 0) return Resultado(t, invocados);
        final cadaHp = jefe.cadaHp;
        if (cadaHp != null) {
          final ahora = (jefe.hp - hp) ~/ cadaHp;
          while (cruzados < ahora) {
            cruzados++;
            invocar();
          }
        }
      }
      if (ch.cd) act.cd = 2;
      if (ch.gx) j.gxUsado = true;
      for (final p in j.pokes) {
        if (p.cd > 0) p.cd--;
      }
    }

    // Turno del jefe: sus ataques (como en sim_cartas.dart)...
    var k = 1;
    while (k < nv.maxAtaques && rnd.nextDouble() < probSeguir) {
      k++;
    }
    for (var n = 0; n < k; n++) {
      final vivos = js.where((j) => !j.eliminado).toList();
      if (vivos.isEmpty) break;
      final j = vivos[rnd.nextInt(vivos.length)];
      final r = rnd.nextDouble();
      golpear(j, jefe.ataques[r < 0.4 ? 0 : (r < 0.8 ? 1 : 2)]);
    }
    // ...y, al final, los ataques de los aliados vivos.
    for (var i = 0; i < slots.length; i++) {
      final a = slots[i];
      if (a != null) atacarAliado(i, a);
    }
    if (js.every((j) => j.eliminado)) return Resultado(0, invocados);
  }
  return Resultado(0, invocados);
}

class MedidaJefe {
  MedidaJefe(this.victoria, this.turnosVictoria, this.invocados);
  final double victoria;
  final double turnosVictoria;
  final double invocados;
}

MedidaJefe medirJefe(
  List<List<Pareja>> equipos,
  JefeDef jefe,
  Nivel nv,
  Config c,
  int semilla,
  double ayuda,
) {
  final rnd = Random(semilla);
  var tasas = 0.0;
  var turnos = 0;
  var victorias = 0;
  var invocados = 0;
  var partidas = 0;
  for (final e in equipos) {
    var w = 0;
    for (var i = 0; i < c.partidas; i++) {
      final r = jugarJefe(e, jefe, nv, c, rnd, ayuda);
      invocados += r.invocados;
      partidas++;
      if (r.turnoVictoria > 0) {
        w++;
        turnos += r.turnoVictoria;
      }
    }
    victorias += w;
    tasas += w / c.partidas;
  }
  return MedidaJefe(
    tasas / equipos.length,
    victorias == 0 ? 0 : turnos / victorias,
    invocados / partidas,
  );
}

void main(List<String> args) {
  var carpetaJefes = '../catalog';
  var ayuda = 0.5;
  final resto = <String>[];
  var informe = '../balance/informes/jefes_aliados.csv';
  for (final a in args) {
    if (a.startsWith('--jefes=')) {
      carpetaJefes = a.substring('--jefes='.length);
    } else if (a.startsWith('--ayuda=')) {
      ayuda = double.parse(a.substring('--ayuda='.length));
    } else if (a.startsWith('--informe=')) {
      informe = a.substring('--informe='.length);
    } else {
      resto.add(a);
    }
  }
  final c = leerArgs(resto);
  final cartas = leerCatalogo(c.catalogo, c.ataques);
  final lista = cartas.values.toList();
  final normales = lista.where((x) => x.sinReglaEspecial).toList();
  final niveles = leerNiveles(c.tabla);
  final jefes = leerJefes(carpetaJefes);
  final rnd = Random(c.semilla);

  final porNivel = {for (final n in niveles) n.nivel: <List<Pareja>>[]};
  for (final n in niveles) {
    final destino = porNivel[n.nivel]!;
    for (var intento = 0; intento < 200000 && destino.length < c.equipos; intento++) {
      final e = n.nivel == 1 ? equipoNormales(rnd, normales) : equipoAzar(rnd, lista);
      if (nivelPorX(calcularX(e), niveles) == n.nivel) destino.add(e);
    }
  }

  stdout.writeln('Incursiones · simulador de jefes con aliados (T-28)');
  stdout.writeln('jefes=${jefes.length} equipos/nivel=${c.equipos} '
      'partidas/equipo=${c.partidas} ayuda=$ayuda\n');
  stdout.writeln('jefe        nivel  HP     política      victoria  objetivo  turnos  aliados');
  final filas = <String>[
    'jefe,nivel,hp,politica,equipos,partidas_por_equipo,victoria,objetivo,turnos_victoria,aliados_invocados',
  ];
  final politicas = {'solo-dueno': 0.0, 'ayuda': ayuda};
  for (final jefe in jefes) {
    final nv = niveles.firstWhere((n) => n.nivel == jefe.nivel);
    final eqs = porNivel[jefe.nivel]!;
    if (eqs.isEmpty) {
      stdout.writeln('${jefe.id}  sin equipos de este nivel');
      continue;
    }
    for (final e in politicas.entries) {
      final m = medirJefe(eqs, jefe, nv, c, c.semilla, e.value);
      stdout.writeln('${jefe.id.padRight(11)} ${jefe.nivel}      '
          '${jefe.hp.toString().padRight(6)} ${e.key.padRight(12)}  '
          '${(100 * m.victoria).toStringAsFixed(1).padLeft(5)} %    '
          '${(100 * objetivo[jefe.nivel]!).toStringAsFixed(0).padLeft(3)} %     '
          '${m.turnosVictoria.toStringAsFixed(1).padLeft(5)}  '
          '${m.invocados.toStringAsFixed(2)}');
      filas.add('${jefe.id},${jefe.nivel},${jefe.hp},${e.key},${eqs.length},'
          '${c.partidas},${m.victoria.toStringAsFixed(4)},${objetivo[jefe.nivel]},'
          '${m.turnosVictoria.toStringAsFixed(1)},${m.invocados.toStringAsFixed(2)}');
    }
  }
  File(informe)
    ..createSync(recursive: true)
    ..writeAsStringSync('${filas.join('\n')}\n');
  stdout.writeln('\nInforme guardado en $informe');
  stdout.writeln('Sin efectos de habilidades de aliados ni veneno/quemadura: '
      'las cifras son una cota optimista para los jugadores.');
}
