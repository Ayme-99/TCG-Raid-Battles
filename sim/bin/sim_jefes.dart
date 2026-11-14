// Simulador de los jefes del catálogo CON ALIADOS (T-28).
//
// Reutiliza los equipos de cartas reales y las reglas de sim_cartas.dart
// (D-03) y añade lo que ese simulador no modela, tal como lo define el GDD §4.4
// y D-13:
//   - Llamada de aliados (T-69/T-71): la primera al terminar el turno del jefe
//     de la ronda 1 y las siguientes cada vez que su HP baja a un umbral
//     (cada `cadaHp` HP perdidos), hasta nivel + 1 llamadas. Sin moneda.
//   - Un dado elige el slot entre los libres de jugadores activos y otro la
//     categoría entre las que no están en uso. Sin slot libre no hay aliado.
//   - Al entrar, el aliado ataca (si tiene ataque); luego vuelve a atacar al
//     final del turno del jefe. Daño al Pokémon Activo del dueño de su slot
//     (si está eliminado, a un jugador activo al azar). El Control (antes Pícaro) ataca a la
//     Banca.
//   - Sin bloqueo de slot: el jugador puede ignorar al aliado de su slot y
//     atacar al jefe (política «solo-jefe»); en «solo-dueno» y «ayuda» ataca
//     siempre a su aliado. El exceso de daño al aliado se pierde. Un aliado
//     con Bloqueo (Bronzong) obliga a todos a atacarle y recibe 100 menos.
//   - Ayuda (opcional): un jugador libre ataca al aliado de un compañero en
//     vez de al jefe, con la probabilidad --ayuda (0 = solo el dueño).
//
// Efectos de los ataques del jefe (D-14), tal como los lee del catálogo:
//   - danoPorAtaquePrevio: +valor de daño por cada ataque anterior del turno.
//   - danoExtraSi (Castigo): +valor si el Pokémon que defiende no tiene daño.
//   - autodano: el jefe pierde valor HP tras el ataque (puede invocar o caer).
//   - contadorATodos: valor×10 de daño a cada aliado y a cada Pokémon vivo de
//     los jugadores.
//   - sinAtaque y paralizarDefensor (con moneda si la lleva): el jugador
//     que defiende no ataca en su siguiente turno.
//   - sinRetirada: ese jugador no puede cambiar de Pokémon en su turno.
//   La duración se toma siempre como 1 turno de los jugadores (la de todos los
//   jefes actuales); ignoraEfectos no se modela porque los efectos de los
//   jugadores tampoco.
//
// Modela los scripts de aliados que aplica el programa (D-13), leídos del
// `scriptId` del catálogo:
//   - tanque-jefe-N: mientras el aliado vive, cada ataque de los jugadores al
//     jefe hace N de daño menos (se suman, mínimo 0; no afecta al autodaño).
//   - cura-jefe-N: al final del turno del jefe (tras los ataques de los
//     aliados) el jefe se cura N HP sin pasar de su máximo.
//
//   - tanque-jefe-N: también reduce N el daño que los jugadores hacen a los
//     aliados (el propio Tanque incluido).
//   - chupavidas-N: cada vez que el aliado ataca (al entrar y en el turno del
//     jefe) cura N al jefe y a todos los aliados, sin pasar de su máximo.
//   - foco-energia-N: cada ataque del jefe hace N más con una moneda (cara).
//   - aullido-N: cada ataque del jefe hace N más (sin moneda).
//   - grunido-N: como el Tanque, resta N a los ataques de los jugadores.
//   - agilidad-N: el primer ataque del jefe de cada turno hace N más.
//   - Krabby («30+»): bonus con monedas; Bote: moneda que evita el daño;
//     Constricción: los jugadores no cambian de Pokémon salvo por KO.
//   - drenadoras-N: al entrar y en el chequeo Pokémon, 10 de daño al activo de
//     cada jugador y el jefe se cura N por cada uno.
// Aliados con ataque de monedas («20×» con 2 monedas): daño = caras × dano.
//
// Efectos de la carta que aplican los jugadores (el programa solo los
// recuerda), modelados como si la mesa los aplicara siempre, por nombre de
// habilidad: «Tormenta de arena» (control: 10 de daño al Pokémon activo de
// cada jugador en el chequeo Pokémon, tras el turno del jefe) y «Rencor»
// (debilitador: los jugadores no repiten ataque dos turnos seguidos).
// No se modelan (los resuelve la mesa y no hay Condiciones Especiales de los
// jugadores en el simulador): Tóxico (Gulpin, ataque sin daño que envenena),
// la Confusión de Puño Dinámico, Fijar Blanco y la parálisis de Moflete
// Estático.
//
// NO modela (el informe lo dice): veneno ni quemadura del jefe, ni el cambio de
// Pokémon activo por efectos. Por eso las cifras siguen siendo una cota
// optimista para los jugadores salvo en la política «solo el dueño», que es la
// más dura.
//
// Uso (desde sim/):
//   dart run bin/sim_jefes.dart
//   dart run bin/sim_jefes.dart --equipos=20 --partidas=20 --informe=/tmp/j.csv
//   dart run bin/sim_jefes.dart --jugadores=3   # equipos de 1 a 4 jugadores
//   dart run bin/sim_jefes.dart --jugadores=2 --mesa8   # 8 Pokémon en mesa (4 por jugador)
//   dart run bin/sim_jefes.dart --calibrar   # HP (en centenas) que da el objetivo
//   dart run bin/sim_jefes.dart --causas     # por qué no se usan todos los intentos
//   dart run bin/sim_jefes.dart --animo=no    # sin cartas de ánimo (modelo anterior)
//
// Opciones propias:
//   --jefes=RUTA      carpeta del catálogo (defecto ../catalog)
//   --ayuda=P         probabilidad de ayuda en la política «ayuda» (0.5)
//   --animo=LISTA     cartas de ánimo (D-05) que puede robar el jugador KO al
//                     sentarse: «todas» (por defecto), «no» o números 1 a 5
//                     separados por comas. Ver robarAnimo en jugarJefe.
// Y las de sim_cartas.dart: --equipos --partidas --max-turnos --semilla
//   --catalogo --ataques --tabla --informe (aquí, defecto
//   ../balance/informes/jefes_aliados.csv).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:incursiones_engine/incursiones_engine.dart'
    show MazoAtaquesJefe, pokemonPorJugadorSegun;

import 'sim_cartas.dart' hide Medida, main, medir;

const categorias = [
  'danio',
  'tanque',
  'cura',
  'control',
  'potenciador',
  'debilitador',
];

class AliadoDef {
  AliadoDef(this.nombre, this.hp, this.dano,
      {this.scriptId, this.monedas, this.habilidadNombre, this.danoAdyacentes, this.bonusMonedas, this.evitaConMoneda = false});
  final String nombre;
  final int hp;

  /// Daño del ataque; con [monedas], daño por cada cara.
  final int? dano;
  final int? monedas;
  final String? habilidadNombre;

  /// Bonus «30+»: (monedas, carasMinimas, dano) del ataque, o null.
  final (int, int, int)? bonusMonedas;

  /// Daño del ataque a los Pokémon de los jugadores adyacentes al objetivo.
  final int? danoAdyacentes;

  /// Script del programa de la carta (`cura-jefe-20`, `tanque-jefe-10`...).
  final String? scriptId;

  int _numero(String prefijo) {
    final id = scriptId;
    if (id == null || !id.startsWith(prefijo)) return 0;
    return int.parse(id.substring(prefijo.length));
  }

  /// Daño que el jefe recibe de menos por cada ataque de los jugadores.
  int get reduccion => _numero('tanque-jefe-') + _numero('grunido-');

  /// HP que el jefe se cura al final de su turno.
  int get cura => _numero('cura-jefe-');

  /// HP que cura a todos (jefe y aliados) cada vez que ataca.
  int get chupavidas => _numero('chupavidas-');

  /// Daño extra (con moneda) a cada ataque del jefe.
  int get focoEnergia => _numero('foco-energia-');

  /// Daño fijo al primer ataque del jefe de cada turno (Agilidad).
  int get agilidad => _numero('agilidad-');

  /// Daño fijo (sin moneda) a cada ataque del jefe.
  int get aullido => _numero('aullido-');

  /// HP que cura por cada jugador no eliminado (Drenadoras, que además pone
  /// un contador de 10 en cada Pokémon Activo), al entrar y en el chequeo.
  int get drenadoras => _numero('drenadoras-');

  /// Daño al Pokémon activo de cada jugador en el chequeo Pokémon.
  int get danoChequeo =>
      habilidadNombre?.toLowerCase() == 'tormenta de arena' ? 10 : 0;

  /// Los jugadores solo pueden atacar a este aliado (Bloqueo) y este recibe
  /// N de daño menos de cada ataque.
  int get bloqueo => _numero('bloqueo-');

  /// Cada uso del ataque, +10 de daño y +10 HP (Envite Ígneo).
  bool get envite => scriptId == 'envite-igneo-10';

  /// Al entrar: monedas de curación de 100 para el jefe y los aliados (Deseo).
  bool get deseo => scriptId == 'deseo-100';

  /// Moneda del rival: con cruz, −30 a sus ataques su siguiente turno.
  bool get fuerzaLunar => scriptId == 'fuerza-lunar-30';

  /// Los jugadores no pueden cambiar de Pokémon (Constricción).
  bool get constriccion => habilidadNombre == 'Constricción';

  /// Cada daño de los jugadores se evita con cara (Bote).
  final bool evitaConMoneda;

  /// Los jugadores no repiten ataque en turnos seguidos.
  bool get rencor => habilidadNombre == 'Rencor';
}

/// Ataque de la carta del jefe con el efecto que le interesa al simulador.
class AtaqueDef {
  AtaqueDef(this.dano, {this.tipo, this.valor, this.conMoneda = false});
  final int dano;
  final String? tipo;
  final int? valor;
  final bool conMoneda;
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
  final List<AtaqueDef> ataques;
  final int? cadaHp;
  final bool segura;
  final Map<String, AliadoDef> aliados;

  /// Llamadas de aliado posibles a lo largo de la partida (T-69): nivel + 1.
  int get intentos => cadaHp == null ? 0 : nivel + 1;

  /// El mismo jefe con otro HP. Mantiene el número de llamadas por umbral
  /// (nivel, además de la primera): `cadaHp` se reparte en tramos iguales
  /// redondeando hacia abajo.
  JefeDef conHp(int nuevoHp) => JefeDef(
        id: id,
        nombre: nombre,
        nivel: nivel,
        hp: nuevoHp,
        ataques: ataques,
        cadaHp: cadaHp == null ? null : (nuevoHp + nivel) ~/ (nivel + 1),
        segura: segura,
        aliados: aliados,
      );
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
        // Provisional (D-16): un jefe puede no tener aún potenciador ni
        // debilitador.
        if (a[cat] == null) continue;
        final d = _mapa(a[cat]);
        final ataque = d['ataque'] == null ? null : _mapa(d['ataque']);
        aliados[cat] = AliadoDef(
          d['nombre'] as String,
          d['hp'] as int,
          ataque == null ? null : ataque['dano'] as int,
          scriptId: d['efectos'] == 'programa' ? d['scriptId'] as String? : null,
          monedas: ataque == null ? null : ataque['monedas'] as int?,
          habilidadNombre: d['habilidadNombre'] as String?,
          evitaConMoneda: d['evitaDanoConMoneda'] == true,
          danoAdyacentes: ataque == null ? null : ataque['danoAdyacentes'] as int?,
          bonusMonedas: ataque?['bonusConMonedas'] == null
              ? null
              : (
                  (ataque!['bonusConMonedas'] as Map)['monedas'] as int,
                  (ataque['bonusConMonedas'] as Map)['carasMinimas'] as int,
                  (ataque['bonusConMonedas'] as Map)['dano'] as int,
                ),
        );
      }
    }
    jefes.add(JefeDef(
      id: id,
      nombre: j['nombre'] as String,
      nivel: j['nivel'] as int,
      hp: j['hp'] as int,
      ataques: [
        for (final a in j['ataques'] as List)
          () {
            final m = _mapa(a);
            final e = m['efecto'] == null ? null : _mapa(m['efecto']);
            return AtaqueDef(
              m['dano'] as int,
              tipo: e == null ? null : e['tipo'] as String,
              valor: e == null ? null : e['valor'] as int?,
              conMoneda: e != null && e['conMoneda'] == true,
            );
          }(),
      ],
      cadaHp: inv == null ? null : inv['cadaHp'] as int,
      segura: inv != null && inv['tirada'] == 'segura',
      aliados: aliados,
    ));
  }
  return jefes;
}

/// Como `Jug.elegir`, pero sin repetir el ataque [prohibido] («Rencor»).
Ataque? elegirSin(Jug j, Poke p, Ataque? prohibido) {
  if (p.cd > 0) return null;
  Ataque? mejor;
  for (final a in p.carta.ataques) {
    if (a.gx && j.gxUsado) continue;
    if (identical(a, prohibido)) continue;
    if (mejor == null ||
        a.dano > mejor.dano ||
        (a.dano == mejor.dano && mejor.gx && !a.gx)) {
      mejor = a;
    }
  }
  return mejor;
}

class Aliado {
  Aliado(this.categoria, this.def)
      : hp = def.hp,
        hpMax = def.hp;
  final String categoria;
  final AliadoDef def;
  int hp;
  int hpMax;

  /// Veces que ha usado su ataque (Envite Ígneo escala con ellas).
  int usos = 0;
  bool get vivo => hp > 0;
  bool get ataca => def.dano != null;
  bool get atacaBanca => categoria == 'control';
}

class Resultado {
  Resultado(this.turnoVictoria, this.invocados,
      [this.sinSlot = 0, this.sinCategoria = 0]);

  /// Turno de la victoria (>0) o 0 si pierden o se agota el tiempo.
  final int turnoVictoria;
  final int invocados;

  /// Intentos de invocación perdidos por no haber ningún slot libre.
  final int sinSlot;

  /// Intentos perdidos por no quedar ninguna categoría libre.
  final int sinCategoria;
}

/// Daño a un jugador: al Activo, o a la Banca si [banca] y está viva.
void golpear(Jug j, int dano, {bool banca = false}) {
  final suplente = j.banca;
  if (banca && suplente != null) {
    suplente.hp -= dano;
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
  double ayuda, [
  double propio = 1.0,
]) {
  final js = [for (final p in equipo) Jug(p)];
  final mazo = MazoAtaquesJefe(rnd, jugadores: js.length);
  final slots = List<Aliado?>.filled(js.length, null);
  var hp = jefe.hp;
  var llamadas = 0;
  // Ronda de la partida (para las llamadas: nada cuenta antes de que acabe el
  // primer turno del jefe).
  var ronda = 1;
  var invocados = 0;
  var sinSlot = 0;
  var sinCategoria = 0;
  Resultado res(int turno) =>
      Resultado(turno, invocados, sinSlot, sinCategoria);
  // Efectos del jefe sobre los jugadores durante su próximo turno (D-14).
  final noAtacan = <int>{};
  final sinRetirada = <int>{};
  // Jugador que está actuando y los que han perdido su turno esta ronda.
  var actual = -1;
  final perdidos = <int>{};
  // Jugadores que se sientan esta ronda por un KO: solo roban carta de ánimo
  // (fuera de la app). Hasta que acaba la ronda, los ataques del jefe y de
  // sus aliados contra ellos fallan, igual que contra quien acaba de caer KO.
  final sentados = <int>{};
  bool enKo(int i) => !js[i].pokes[0].vivo || sentados.contains(i);
  // Cartas de ánimo (D-05): el jugador que se sienta roba una de las de
  // [Config.animo] (máximo 3 distintas por partida) en su posición del orden y
  // su efecto «este turno» alcanza a quien actúa después en la ronda.
  final animoVistas = <int>{};
  var animoMas = 0; // +N al daño de los ataques de los jugadores (carta 5)
  var animoDoble = false; // el siguiente ataque hace doble daño (carta 1)
  var jefeUnaCarta = false; // el jefe juega una sola carta (carta 4)
  // Reducción pendiente por jugador (Fuerza Lunar).
  final debilitados = <int, int>{};
  // Último ataque de cada jugador (para «Rencor»).
  final ultimo = <int, Ataque?>{};

  // El jugador KO que se sienta roba su carta de ánimo (D-05 §1).
  void robarAnimo() {
    if (c.animo.isEmpty) return;
    var carta = c.animo[rnd.nextInt(c.animo.length)];
    if (animoVistas.length >= 3 && !animoVistas.contains(carta)) {
      final vistas = c.animo.where(animoVistas.contains).toList();
      carta = vistas[rnd.nextInt(vistas.length)];
    }
    animoVistas.add(carta);
    switch (carta) {
      case 1:
        animoDoble = true;
      case 2:
        for (final x in js) {
          for (final p in x.pokes) {
            if (p.vivo) p.hp = min(p.carta.hp, p.hp + 80);
          }
        }
      case 3:
        {
          // Cura todo el daño del Pokémon más dañado.
          Poke? peor;
          for (final x in js) {
            for (final p in x.pokes) {
              if (p.vivo &&
                  (peor == null || p.carta.hp - p.hp > peor.carta.hp - peor.hp)) {
                peor = p;
              }
            }
          }
          if (peor != null) peor.hp = peor.carta.hp;
        }
      case 4:
        jefeUnaCarta = true;
      case 5:
        animoMas = 50;
    }
  }

  // Reducción de daño de los aliados Tanque vivos.
  int reduccionTanques() {
    var r = 0;
    for (final a in slots) {
      if (a != null) r += a.def.reduccion;
    }
    return r;
  }

  // Drenadoras: un contador de 10 en el activo de cada jugador y el jefe se
  // cura 10 por cada uno.
  void drenar(Aliado a) {
    final d = a.def.drenadoras;
    if (d == 0) return;
    for (final x in js) {
      if (x.eliminado) continue;
      if (!x.pokes[0].vivo) x.intercambiar();
      x.pokes[0].hp -= 10;
      hp = min(jefe.hp, hp + d);
    }
  }

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
    // Contra un jugador KO el ataque falla: se omite.
    if (enKo(objetivo)) return;
    var dano = a.def.dano!;
    if (a.def.envite) {
      dano += 10 * a.usos;
      a.usos++;
      a.hpMax += 10;
      a.hp += 10;
    }
    final m = a.def.monedas;
    if (m != null) {
      var caras = 0;
      for (var i = 0; i < m; i++) {
        if (rnd.nextBool()) caras++;
      }
      dano *= caras;
    }
    final bm = a.def.bonusMonedas;
    if (bm != null) {
      var caras = 0;
      for (var i = 0; i < bm.$1; i++) {
        if (rnd.nextBool()) caras++;
      }
      if (caras >= bm.$2) dano += bm.$3;
    }
    golpear(js[objetivo], dano, banca: a.atacaBanca);
    // Fuerza Lunar: el rival tira una moneda; con cruz, −30 a su próximo ataque.
    if (a.def.fuerzaLunar && !rnd.nextBool()) debilitados[objetivo] = 30;
    // Daño a los jugadores adyacentes (circular, sin eliminados).
    final adj = a.def.danoAdyacentes;
    if (adj != null) {
      final vivos = [
        for (var i = 0; i < js.length; i++)
          if (!js[i].eliminado || i == objetivo) i,
      ];
      final pos = vivos.indexOf(objetivo);
      if (vivos.length > 1) {
        final vecinos = {
          vivos[(pos - 1 + vivos.length) % vivos.length],
          vivos[(pos + 1) % vivos.length],
        };
        for (final v in vecinos) {
          if (!js[v].eliminado) golpear(js[v], adj);
        }
      }
    }
    // Chupavidas: cura al jefe y a todos los aliados vivos.
    final vida = a.def.chupavidas;
    if (vida > 0) {
      hp = min(jefe.hp, hp + vida);
      for (final x in slots) {
        if (x != null && x.vivo) x.hp = min(x.hpMax, x.hp + vida);
      }
    }
  }

  void invocar() {
    final libres = [
      for (var i = 0; i < js.length; i++)
        if (!js[i].eliminado && slots[i] == null) i,
    ];
    if (libres.isEmpty) {
      sinSlot++;
      return;
    }
    final enUso = {
      for (final a in slots)
        if (a != null) a.categoria,
    };
    final catsLibres = [
      for (final cat in categorias)
        if (jefe.aliados.containsKey(cat) && !enUso.contains(cat)) cat,
    ];
    if (catsLibres.isEmpty) {
      sinCategoria++;
      return;
    }
    final slot = libres[rnd.nextInt(libres.length)];
    final cat = catsLibres[rnd.nextInt(catsLibres.length)];
    final a = Aliado(cat, jefe.aliados[cat]!);
    slots[slot] = a;
    invocados++;
    // Si el ataque de entrada deja KO al Pokémon de un jugador que aún no ha
    // actuado esta ronda, ese jugador pierde su turno (D-13).
    final vivosAntes = [for (final j in js) j.pokes[0].vivo];
    atacarAliado(slot, a); // ataque de entrada
    drenar(a);
    if (a.def.deseo) {
      // Deseo: el jefe lanza 10 monedas (100 HP por cara), cada aliado una y
      // cada Pokémon de los jugadores una (los de la mesa).
      var caras = 0;
      for (var i = 0; i < 10; i++) {
        if (rnd.nextBool()) caras++;
      }
      hp = min(jefe.hp, hp + 100 * caras);
      for (final x in slots) {
        if (x != null && x.vivo && rnd.nextBool()) {
          x.hp = min(x.hpMax, x.hp + 100);
        }
      }
      for (final j in js) {
        for (final p in j.pokes) {
          if (p.vivo && rnd.nextBool()) p.hp = min(p.carta.hp, p.hp + 100);
        }
      }
    }
    for (var k = actual + 1; k < js.length; k++) {
      if (vivosAntes[k] && !js[k].pokes[0].vivo && !js[k].eliminado) {
        perdidos.add(k);
      }
    }
  }

  // Llamadas de aliado debidas (T-71): la primera al acabar el turno del jefe
  // de la ronda 1 y una por umbral de HP cruzado, hasta nivel + 1 en total.
  void llamar() {
    final cada = jefe.cadaHp;
    if (cada == null || ronda < 2) return;
    final maxUmbrales = (jefe.hp - 1) ~/ cada;
    var cruzados = (jefe.hp - hp) ~/ cada;
    if (cruzados > maxUmbrales) cruzados = maxUmbrales;
    if (cruzados < 0) cruzados = 0;
    final debidas = min(1 + cruzados, jefe.intentos);
    while (llamadas < debidas) {
      llamadas++;
      invocar();
    }
  }

  // El jefe pierde [dano] HP. Devuelve true si cae; si no, puede llamar a un
  // aliado al cruzar un umbral de HP.
  bool bajarJefe(int dano) {
    hp -= dano;
    if (hp <= 0) return true;
    llamar();
    return false;
  }

  for (var t = 1; t <= c.maxTurnos; t++) {
    ronda = t;
    actual = -1;
    sentados.clear();
    animoMas = 0;
    animoDoble = false;
    jefeUnaCarta = false;
    for (var i = 0; i < js.length; i++) {
      final j = js[i];
      if (j.eliminado) continue;
      actual = i;
      // Con un Pokémon KO se sienta el turno (los KO del ataque de entrada de
      // un aliado antes de actuar pierden ese mismo turno).
      if (perdidos.remove(i) || !j.pokes[0].vivo) {
        sentados.add(i);
        if (!j.pokes[0].vivo) j.intercambiar();
        robarAnimo();
        for (final p in j.pokes) {
          if (p.cd > 0) p.cd--;
        }
        continue;
      }
      if (!j.pokes[0].vivo) j.intercambiar();
      if (noAtacan.contains(i)) {
        for (final p in j.pokes) {
          if (p.cd > 0) p.cd--;
        }
        continue;
      }
      final rencor = slots.any((a) => a != null && a.def.rencor);
      Ataque? elegir(Poke p) => rencor ? elegirSin(j, p, ultimo[i]) : j.elegir(p);
      var act = j.pokes[0];
      var ch = elegir(act);
      final constriccion = slots.any((a) => a != null && a.def.constriccion);
      if (ch == null &&
          j.banca != null &&
          !sinRetirada.contains(i) &&
          !constriccion) {
        j.intercambiar();
        act = j.pokes[0];
        ch = elegir(act);
      }
      ultimo[i] = ch;
      if (ch == null) {
        for (final p in j.pokes) {
          if (p.cd > 0) p.cd--;
        }
        continue;
      }

      // A quién ataca: si hay un aliado con Bloqueo, a él; si no, a su propio
      // aliado con probabilidad [propio] (el bloqueo de slot ya no existe: el
      // jugador puede ignorarlo y atacar al jefe); si no tiene aliado, quizá
      // ayuda a un compañero; si no, al jefe.
      int? objetivoAliado;
      final propioAliado = slots[i];
      final bloqueador = slots.indexWhere((x) => x != null && x.def.bloqueo > 0);
      if (bloqueador != -1) {
        objetivoAliado = bloqueador;
      } else if (propioAliado != null) {
        if (propio >= 1 || (propio > 0 && rnd.nextDouble() < propio)) {
          objetivoAliado = i;
        }
      } else if (ayuda > 0 && rnd.nextDouble() < ayuda) {
        final otros = [
          for (var k = 0; k < js.length; k++)
            if (k != i && slots[k] != null && !js[k].eliminado) k,
        ];
        if (otros.isNotEmpty) {
          objetivoAliado = otros[rnd.nextInt(otros.length)];
        }
      }
      // Debilitación pendiente (Fuerza Lunar): −N a este ataque.
      final debil = debilitados.remove(i) ?? 0;
      // Cartas de ánimo: doble daño (carta 1) y luego +50 (carta 5), solo a los
      // ataques que hacen daño.
      var danoAtaque = ch.dano;
      if (danoAtaque > 0) {
        if (animoDoble) {
          danoAtaque *= 2;
          animoDoble = false;
        }
        danoAtaque += animoMas;
      }

      if (objetivoAliado != null) {
        final a = slots[objetivoAliado]!;
        // Bote: con cara en la moneda se evita el daño.
        final evita = a.def.evitaConMoneda && rnd.nextBool();
        if (!evita) {
          a.hp -= max(
            0,
            danoAtaque - reduccionTanques() - a.def.bloqueo - debil,
          ); // el exceso se pierde
        }
        if (!a.vivo) slots[objetivoAliado] = null;
      } else {
        // Los aliados Tanque vivos restan una cantidad fija a cada ataque.
        final dano = max(0, danoAtaque - reduccionTanques() - debil);
        if (bajarJefe(dano)) return res(t);
      }
      if (ch.cd) act.cd = 2;
      if (ch.gx) j.gxUsado = true;
      for (final p in j.pokes) {
        if (p.cd > 0) p.cd--;
      }
    }

    actual = js.length; // fuera del turno de los jugadores
    perdidos.clear();
    // Los efectos del jefe duran hasta aquí: un turno de los jugadores.
    noAtacan.clear();
    sinRetirada.clear();

    // Turno del jefe: roba cartas del mazo real (20 cartas oficiales; según
    // los jugadores se quitan o se redirigen), cada una con su ataque y su
    // objetivo, y sigue mientras diga «roba otra» hasta el máximo del nivel.
    for (var n = 0; n < (jefeUnaCarta ? 1 : nv.maxAtaques); n++) {
      final activos = {
        for (var i = 0; i < js.length; i++)
          if (!js[i].eliminado && !enKo(i)) i,
      };
      // Sin nadie a quien atacar (todos KO), los ataques del jefe fallan.
      if (activos.isEmpty) break;
      final carta = mazo.robar(activos);
      final j = js[carta.jugador];
      final a = jefe.ataques[carta.ranura - 1];
      var dano = a.dano;
      if (a.tipo == 'danoPorAtaquePrevio') dano += (a.valor ?? 0) * n;
      if (a.tipo == 'danoExtraSi') {
        final defensor = j.pokes[0].vivo ? j.pokes[0] : (j.banca ?? j.pokes[1]);
        if (defensor.hp == defensor.carta.hp) dano += a.valor ?? 0;
      }
      // Potenciadores vivos: moneda y, con cara, más daño.
      for (final al in slots) {
        final f = al?.def.focoEnergia ?? 0;
        if (f > 0 && rnd.nextBool()) dano += f;
        dano += al?.def.aullido ?? 0;
        if (n == 0) dano += al?.def.agilidad ?? 0;
      }
      golpear(j, dano);
      // Efectos del ataque, después del daño al jugador (D-14).
      if (a.tipo == 'autodano') {
        if (bajarJefe(a.valor ?? 0)) return res(t);
      } else if (a.tipo == 'contadorATodos') {
        final d = (a.valor ?? 1) * 10;
        for (var s = 0; s < slots.length; s++) {
          final al = slots[s];
          if (al == null) continue;
          al.hp -= d;
          if (!al.vivo) slots[s] = null;
        }
        for (final x in js) {
          for (final p in x.pokes) {
            if (p.vivo) p.hp -= d;
          }
        }
      } else if (a.tipo == 'sinAtaque' || a.tipo == 'paralizarDefensor') {
        if (!a.conMoneda || rnd.nextBool()) noAtacan.add(js.indexOf(j));
      } else if (a.tipo == 'sinRetirada') {
        sinRetirada.add(js.indexOf(j));
      }
      if (!carta.robaOtra) break;
    }
    // ...y, al final, los ataques de los aliados vivos.
    for (var i = 0; i < slots.length; i++) {
      final a = slots[i];
      if (a != null) atacarAliado(i, a);
    }
    // Chequeo Pokémon: «Tormenta de arena» daña al activo de cada jugador.
    for (final al in slots) {
      if (al != null) drenar(al);
      final d = al?.def.danoChequeo ?? 0;
      if (d == 0) continue;
      for (final x in js) {
        if (x.eliminado) continue;
        if (!x.pokes[0].vivo) x.intercambiar();
        x.pokes[0].hp -= d;
      }
    }
    // Fin del turno del jefe: los aliados Cura vivos lo curan (D-13).
    for (final a in slots) {
      if (a != null && a.vivo && a.def.cura > 0) {
        hp = min(jefe.hp, hp + a.def.cura);
      }
    }
    if (js.every((j) => j.eliminado)) return res(0);
    // Termina el turno del jefe: primera llamada y umbrales ya cruzados. El
    // aliado entra y ataca al entrar (la ronda siguiente, antes de actuar).
    ronda = t + 1;
    llamar();
  }
  return res(0);
}

class MedidaJefe {
  MedidaJefe(this.victoria, this.turnosVictoria, this.invocados,
      [this.sinSlot = 0, this.sinCategoria = 0]);
  final double victoria;

  /// Turno medio de la victoria, contando solo las partidas ganadas.
  final double turnosVictoria;
  final double invocados;

  /// Por partida: intentos perdidos por falta de slot / de categoría.
  final double sinSlot;
  final double sinCategoria;
}

MedidaJefe medirJefe(
  List<List<Pareja>> equipos,
  JefeDef jefe,
  Nivel nv,
  Config c,
  int semilla,
  double ayuda, [
  double propio = 1.0,
]) {
  final rnd = Random(semilla);
  var tasas = 0.0;
  var turnos = 0;
  var victorias = 0;
  var invocados = 0;
  var sinSlot = 0;
  var sinCategoria = 0;
  var partidas = 0;
  for (final e in equipos) {
    var w = 0;
    for (var i = 0; i < c.partidas; i++) {
      final r = jugarJefe(e, jefe, nv, c, rnd, ayuda, propio);
      invocados += r.invocados;
      sinSlot += r.sinSlot;
      sinCategoria += r.sinCategoria;
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
    sinSlot / partidas,
    sinCategoria / partidas,
  );
}

/// Busca el mayor HP (en centenas) con el que la victoria, con la política
/// más dura (solo el dueño ataca a su aliado), llega al objetivo del nivel.
int calibrarJefe(List<List<Pareja>> equipos, JefeDef jefe, Nivel nv, Config c) {
  var lo = 2; // centenas: 200 HP
  var hi = 120; // 12000 HP
  while (lo < hi) {
    final m = (lo + hi + 1) ~/ 2;
    final v = medirJefe(equipos, jefe.conHp(m * 100), nv, c, 3, 0).victoria;
    if (v >= objetivo[jefe.nivel]!) {
      lo = m;
    } else {
      hi = m - 1;
    }
  }
  return lo * 100;
}

/// Reparte 8 Pokémon entre [n] jugadores lo más igual posible.
List<int> _reparto8(int n) =>
    [for (var i = 0; i < n; i++) 8 ~/ n + (i < 8 % n ? 1 : 0)];

/// «todas» o una lista de cartas de ánimo (1 a 5) separadas por comas.
List<int> _leerAnimo(String texto) {
  if (texto == 'todas') return [1, 2, 3, 4, 5];
  if (texto == 'no') return [];
  final cartas = [for (final t in texto.split(',')) int.parse(t.trim())];
  if (cartas.isEmpty || cartas.any((k) => k < 1 || k > 5)) {
    throw FormatException(
        '--animo: usa «todas», «no» o números de 1 a 5', texto);
  }
  return cartas.toSet().toList()..sort();
}

void main(List<String> args) {
  var carpetaJefes = '../catalog';
  var ayuda = 0.5;
  final resto = <String>[];
  String? informeArg;
  var causas = false;
  var jugadores = 4;
  var menosAtaques = 0;
  var mesa8 = false;
  int? pokemon;
  var mejorPrimero = false;
  var animo = <int>[1, 2, 3, 4, 5];
  for (final a in args) {
    if (a == '--causas') {
      causas = true;
    } else if (a.startsWith('--jefes=')) {
      carpetaJefes = a.substring('--jefes='.length);
    } else if (a.startsWith('--jugadores=')) {
      jugadores = int.parse(a.substring('--jugadores='.length));
    } else if (a == '--mejor-primero') {
      mejorPrimero = true;
    } else if (a.startsWith('--pokemon=')) {
      pokemon = int.parse(a.substring('--pokemon='.length));
    } else if (a == '--mesa8') {
      mesa8 = true;
    } else if (a.startsWith('--menos-ataques=')) {
      menosAtaques = int.parse(a.substring('--menos-ataques='.length));
    } else if (a.startsWith('--animo=')) {
      animo = _leerAnimo(a.substring('--animo='.length));
    } else if (a.startsWith('--ayuda=')) {
      ayuda = double.parse(a.substring('--ayuda='.length));
    } else if (a.startsWith('--informe=')) {
      informeArg = a.substring('--informe='.length);
    } else {
      resto.add(a);
    }
  }
  final c = leerArgs(resto)..animo = animo;
  final informe = informeArg ??
      (c.calibrar
          ? '../balance/informes/jefes_aliados_calibrado.csv'
          : '../balance/informes/jefes_aliados.csv');
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
      // Pokémon de cada jugador: 2, o con --mesa8 los 8 de la mesa repartidos
      // (4 jugadores 2+2+2+2, 3 jugadores 3+3+2, 2 jugadores 4+4).
      final tam = pokemon != null
          ? List.filled(jugadores, pokemon)
          : (mesa8
              ? _reparto8(jugadores)
              : List.filled(jugadores, pokemonPorJugadorSegun(jugadores)));
      final total = tam.fold(0, (x, y) => x + y);
      final elegidas = n.nivel == 1
          ? [for (var i = 0; i < total; i++) normales[rnd.nextInt(normales.length)]]
          : (List<Carta>.from(lista)..shuffle(rnd)).sublist(0, total);
      var pos = 0;
      final e = <Pareja>[];
      for (final t in tam) {
        final grupo = elegidas.sublist(pos, pos + t);
        // Con --mejor-primero el jugador saca de Activo su mejor Pokémon y
        // deja en la Banca los demás, de más a menos daño.
        if (mejorPrimero) grupo.sort((x, y) => y.mejorBase.compareTo(x.mejorBase));
        pos += t;
        e.add(Pareja(grupo[0], grupo[1], grupo.sublist(2)));
      }
      if (nivelPorX(calcularX(e), niveles) == n.nivel) destino.add(e);
    }
  }

  stdout.writeln('Incursiones · simulador de jefes con aliados (T-28)');
  stdout.writeln('jefes=${jefes.length} equipos/nivel=${c.equipos} '
      'partidas/equipo=${c.partidas} ayuda=$ayuda jugadores=$jugadores menos-ataques=$menosAtaques mesa8=$mesa8 pokemon=$pokemon mejor-primero=$mejorPrimero animo=${animo.isEmpty ? 'no' : animo.join(',')}\n');
  stdout.writeln('jefe        nivel  HP     política      victoria  objetivo  turnos  aliados');
  final filas = <String>[
    'jefe,nivel,hp,politica,equipos,partidas_por_equipo,victoria,objetivo,turnos_victoria,aliados_invocados',
  ];
  // (ayuda, propio): propio = probabilidad de atacar al aliado de su slot.
  final politicas = {
    'solo-dueno': (0.0, 1.0),
    'ayuda': (ayuda, 1.0),
    'solo-jefe': (0.0, 0.0),
  };
  final filasCausas = <String>[];
  for (final jefe in jefes) {
    final base = niveles.firstWhere((n) => n.nivel == jefe.nivel);
    // Experimento: quitar ataques por turno al jefe (--menos-ataques=K).
    final nv = Nivel(base.nivel, base.xMin, base.hp, base.ataques,
        max(1, base.maxAtaques - menosAtaques));
    final eqs = porNivel[jefe.nivel]!;
    if (eqs.isEmpty) {
      stdout.writeln('${jefe.id}  sin equipos de este nivel');
      continue;
    }
    final medido = c.calibrar ? jefe.conHp(calibrarJefe(eqs, jefe, nv, c)) : jefe;
    for (final e in politicas.entries) {
      final m = medirJefe(eqs, medido, nv, c, c.semilla, e.value.$1, e.value.$2);
      stdout.writeln('${jefe.id.padRight(11)} ${jefe.nivel}      '
          '${medido.hp.toString().padRight(6)} ${e.key.padRight(12)}  '
          '${(100 * m.victoria).toStringAsFixed(1).padLeft(5)} %    '
          '${(100 * objetivo[jefe.nivel]!).toStringAsFixed(0).padLeft(3)} %     '
          '${m.turnosVictoria.toStringAsFixed(1).padLeft(5)}  '
          '${m.invocados.toStringAsFixed(2)}');
      // Llamadas posibles; las que faltan hasta el total no llegaron a
      // hacerse porque la partida terminó antes.
      final sinCruzar =
          medido.intentos - m.invocados - m.sinSlot - m.sinCategoria;
      filasCausas.add('${jefe.id.padRight(11)} ${e.key.padRight(12)} '
          '${medido.intentos.toString().padLeft(8)} '
          '${m.invocados.toStringAsFixed(2).padLeft(9)} '
          '${m.sinSlot.toStringAsFixed(2).padLeft(8)} '
          '${m.sinCategoria.toStringAsFixed(2).padLeft(10)} '
          '${sinCruzar.toStringAsFixed(2).padLeft(10)}');
      filas.add('${jefe.id},${jefe.nivel},${medido.hp},${e.key},${eqs.length},'
          '${c.partidas},${m.victoria.toStringAsFixed(4)},${objetivo[jefe.nivel]},'
          '${m.turnosVictoria.toStringAsFixed(1)},${m.invocados.toStringAsFixed(2)}');
    }
  }
  if (causas) {
    stdout.writeln('\nCausas de las llamadas de aliado (media por partida)');
    stdout.writeln('jefe        política      intentos  invocados  sinSlot  '
        'sinCategoría  sinCruzar');
    filasCausas.forEach(stdout.writeln);
    stdout.writeln('sinCruzar: llamadas que no llegaron a hacerse porque la '
        'partida terminó antes (victoria o derrota).');
  }
  File(informe)
    ..createSync(recursive: true)
    ..writeAsStringSync('${filas.join('\n')}\n');
  stdout.writeln('\nInforme guardado en $informe');
  if (c.calibrar) {
    stdout.writeln('HP calibrado (columna "HP"): llévalo a catalog/bosses/*.json '
        'con su cadaHp; ver docs/DEPENDENCIAS.md.');
  }
  stdout.writeln('Modela los aliados de Onix (Tanque, Cura, Chupavidas, Foco '
      'Energía, monedas, Tormenta de arena, Rencor); sin veneno/quemadura: las '
      'cifras son una cota optimista para los jugadores.');
}
