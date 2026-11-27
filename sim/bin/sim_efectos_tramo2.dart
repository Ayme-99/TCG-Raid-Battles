// Comprobación de los efectos del tramo 2 con las CARTAS REALES del catálogo
// (#386): Rapidez de Starmie (`ignoraFallo`), Canto de Jigglypuff (Dormido),
// Torbellino de Shellder y Constricción de Ekans (Apresado), Absorber de Paras
// (`curaAlAtacar`) y Muro Mágico de Clefairy jefe, contra lo que dice D-20 §3.6.
//
// Solo lee el catálogo y usa el motor tal cual; no cambia nada. Se ejecuta
// desde `sim/`:  dart run bin/sim_efectos_tramo2.dart [--semillas=2000]
import 'dart:convert';
import 'dart:io';

import 'package:incursiones_engine/campana.dart';

Map<String, dynamic> _leer(String ruta) =>
    jsonDecode(File(ruta).readAsStringSync()) as Map<String, dynamic>;

PokemonCampana carta(String id) =>
    pokemonCampanaDesdeJson(_leer('../catalog/campana/pokemon/$id.json'));

PokemonCampana clefairyJefe() => jefeCampanaDesdeJson(
        _leer('../catalog/campana/jefes/clefairy-jefe.json'))
    .pokemon;

/// Un maniquí de 200 PS sin ataques útiles, para medir el efecto aislado.
PokemonCampana maniqui({int ps = 200}) => PokemonCampana(
      id: 'maniqui',
      nombre: 'Maniquí',
      tipo: TipoCampana.normal,
      ps: ps,
      retirada: 0,
      ataques: const [
        AtaqueCampana(
            nombre: 'Placaje', tipo: TipoCampana.normal, coste: 1, dano: 20),
      ],
    );

String pct(int a, int b) => '${(100 * a / b).toStringAsFixed(1)} %';

bool lanza(void Function() f) {
  try {
    f();
    return false;
  } on ReglaIncumplida {
    return true;
  }
}

int ataqueDe(PokemonCampana p, String nombre) =>
    p.ataques.indexWhere((a) => a.nombre == nombre);

void main(List<String> args) {
  var n = 2000;
  for (final a in args) {
    if (a.startsWith('--semillas=')) n = int.parse(a.substring(11));
  }
  final starmie = carta('starmie');
  final jiggly = carta('jigglypuff');
  final shellder = carta('shellder');
  final ekans = carta('ekans');
  final paras = carta('paras');
  final clefairy = clefairyJefe();
  final salida = StringBuffer();
  void p(String s) {
    print(s);
    salida.writeln(s);
  }

  p('Efectos del tramo 2 con las cartas reales · $n semillas por prueba\n');

  // ---------------------------------------------------------------- Rapidez
  p('## 1. Rapidez de Starmie (`ignoraFallo`, #524/#535)');
  final rapidez = ataqueDe(starmie, 'Rapidez');
  p('Rapidez en la carta: índice $rapidez, ignoraFallo='
      '${starmie.ataques[rapidez].ignoraFallo}, daño ${starmie.ataques[rapidez].dano}.');
  for (final (nombre, marca) in <(String, BandoCombate Function(BandoCombate))>[
    ('Bofetón Lodo (cegado)', (b) => b.copiarCon(cegado: true)),
    ('Pantalla de Humo (cegadoMientrasActivo)',
        (b) => b.copiarCon(cegadoMientrasActivo: true)),
    ('Confundido', (b) => b.copiarCon(confundido: true)),
  ]) {
    var pega = 0;
    for (var s = 1; s <= n; s++) {
      var e = EstadoCombate.inicial(
          equipoJugador: [starmie],
          equipoRival: [maniqui()],
          semilla: s,
          parametros: const ParametrosCombate());
      e = e.conBando(Bando.jugador, marca(e.jugador));
      final antes = e.rival.pokemonActivo.ps;
      e = aplicarCombate(e, Atacar(Bando.jugador, rapidez));
      if (e.rival.pokemonActivo.ps < antes) pega++;
    }
    p('- Starmie marcado con $nombre usa Rapidez: pega ${pct(pega, n)}');
  }
  // La IA: ¿elige Rapidez con Bofetón Lodo encima y con Rayo Confuso?
  var usaRapidez = 0, usaRayo = 0, otro = 0;
  for (var s = 1; s <= 200; s++) {
    var e = EstadoCombate.inicial(
        equipoJugador: [starmie], equipoRival: [maniqui()], semilla: s);
    e = e.conBando(Bando.jugador, e.jugador.copiarCon(cegado: true));
    final a = decidirAccion(e, Bando.jugador);
    if (a is Atacar && a.indice == rapidez) {
      usaRapidez++;
    } else if (a is Atacar) {
      usaRayo++;
    } else {
      otro++;
    }
  }
  p('- La IA de Starmie con Bofetón Lodo encima (energía inicial): '
      'Rapidez $usaRapidez/200, Rayo Confuso $usaRayo/200, otra acción $otro/200');
  // Con Rapidez y sin marca, la moneda no se lanza: la semilla no avanza.
  var e0 = EstadoCombate.inicial(
      equipoJugador: [starmie], equipoRival: [maniqui()], semilla: 7);
  e0 = e0.conBando(Bando.jugador, e0.jugador.copiarCon(cegado: true));
  final e1 = aplicarCombate(e0, Atacar(Bando.jugador, rapidez));
  p('- Con Rapidez la moneda de Bofetón Lodo no se lanza: '
      'semilla ${e0.semilla} → ${e1.semilla} (ultimaMoneda: ${e1.ultimaMoneda}).');
  p('');

  // ---------------------------------------------------------------- Dormido
  p('## 2. Dormido (Canto de Jigglypuff, #511/#530)');
  final canto = ataqueDe(jiggly, 'Canto');
  var duerme = 0, duermeEnSuTurno = 0;
  for (var s = 1; s <= n; s++) {
    var e = EstadoCombate.inicial(
        equipoJugador: [jiggly],
        equipoRival: [maniqui(), maniqui()],
        semilla: s);
    e = aplicarCombate(e, Atacar(Bando.jugador, canto));
    // Tras el Canto y su chequeo, ya es el turno del rival.
    if (e.rival.dormido) duermeEnSuTurno++;
    duerme++;
  }
  p('- Tras Canto (1 moneda) y el primer chequeo, el Defensor llega dormido a '
      'su turno: ${pct(duermeEnSuTurno, duerme)} (D-20 dice 1 de cada 4 = 25 %).');

  // Reglas del Dormido (buscar una semilla en la que se quede dormido).
  EstadoCombate? dormido;
  for (var s = 1; s <= 500 && dormido == null; s++) {
    var e = EstadoCombate.inicial(
        equipoJugador: [jiggly],
        equipoRival: [maniqui(), maniqui()],
        semilla: s,
        cuerdasRival: 1,
        pocionesRival: 1,
        parametros: const ParametrosCombate(rivalUsaObjetos: true));
    e = aplicarCombate(e, Atacar(Bando.jugador, canto));
    if (e.rival.dormido && e.actua == Bando.rival) dormido = e;
  }
  if (dormido == null) {
    p('- No se ha encontrado una semilla con el rival dormido en su turno.');
  } else {
    final d = dormido;
    p('- No puede atacar: ${lanza(() => aplicarCombate(d, const Atacar(Bando.rival, 0))) ? "correcto (error de regla)" : "FALLO: ataca"}');
    p('- No puede cambiar con Cambiar: ${lanza(() => aplicarCombate(d, const Cambiar(Bando.rival, 1))) ? "correcto" : "FALLO: cambia"}');
    p('- Puede cargar: ${lanza(() => aplicarCombate(d, const Cargar(Bando.rival))) ? "FALLO: no puede" : "correcto"}');
    // La Poción exige PS por curar: se le baja el activo a 100 antes de probar.
    final herido = d.conBando(
        Bando.rival,
        d.rival.copiarCon(equipo: [
          PokemonEnCombate(d.rival.pokemonActivo.especie, 100),
          ...d.rival.equipo.skip(1),
        ]));
    p('- Puede usar Poción: ${lanza(() => aplicarCombate(herido, const UsarPocion(Bando.rival, 0))) ? "FALLO: no puede" : "correcto"}');
    final c = aplicarCombate(d, const UsarCuerdaHuida(Bando.rival, 1));
    p('- Cuerda Huida: sale el relevo y queda despierto: '
        '${!c.rival.dormido ? "correcto" : "FALLO: sigue dormido"}');
  }
  // Se despierta: duración media en chequeos.
  var despiertaAlTurno = 0, vistos = 0;
  for (var s = 1; s <= n; s++) {
    var e = EstadoCombate.inicial(
        equipoJugador: [jiggly],
        equipoRival: [maniqui()],
        semilla: s);
    e = e.conBando(Bando.rival, e.rival.copiarCon(dormido: true));
    // El jugador carga; el rival (dormido) carga; se mide cuándo despierta.
    var turnos = 0;
    while (e.rival.dormido && turnos < 30 && e.fase == FaseCombate.enCurso) {
      e = aplicarCombate(e, Cargar(e.actua));
      turnos++;
    }
    vistos++;
    if (turnos <= 2) despiertaAlTurno++;
  }
  p('- Un Dormido despierta en 2 chequeos o menos (uno por cambio de turno): '
      '${pct(despiertaAlTurno, vistos)} (esperado 75 %).');
  p('');

  // --------------------------------------------------------------- Apresado
  p('## 3. Apresado (Torbellino de Shellder, Constricción de Ekans, #522/#532)');
  for (final (nombre, carta_, idx) in [
    ('Shellder · Torbellino', shellder, ataqueDe(shellder, 'Torbellino')),
    ('Ekans · Constricción', ekans, ataqueDe(ekans, 'Constricción')),
  ]) {
    var apresados = 0, psSuma = 0;
    for (var s = 1; s <= n; s++) {
      var e = EstadoCombate.inicial(
          equipoJugador: [carta_], equipoRival: [maniqui(), maniqui()], semilla: s);
      final antes = e.rival.pokemonActivo.ps;
      e = aplicarCombate(e, Atacar(Bando.jugador, idx));
      if (e.rival.apresado) apresados++;
      psSuma += antes - e.rival.pokemonActivo.ps;
    }
    p('- $nombre: PS quitados tras el ataque y su primer chequeo: '
        '${(psSuma / n).toStringAsFixed(1)} de media (D-20: 20 seguro); '
        'sigue apresado ${pct(apresados, n)} (esperado 50 %).');
  }
  EstadoCombate? ap;
  for (var s = 1; s <= 500 && ap == null; s++) {
    var e = EstadoCombate.inicial(
        equipoJugador: [shellder],
        equipoRival: [maniqui(), maniqui()],
        semilla: s,
        cuerdasRival: 1,
        parametros: const ParametrosCombate(rivalUsaObjetos: true));
    e = aplicarCombate(e, Atacar(Bando.jugador, ataqueDe(shellder, 'Torbellino')));
    if (e.rival.apresado && e.actua == Bando.rival) ap = e;
  }
  if (ap != null) {
    final a = ap;
    p('- Apresado no puede cambiar con Cambiar: ${lanza(() => aplicarCombate(a, const Cambiar(Bando.rival, 1))) ? "correcto" : "FALLO"}');
    p('- Apresado puede atacar y cargar: ${!lanza(() => aplicarCombate(a, const Atacar(Bando.rival, 0))) && !lanza(() => aplicarCombate(a, const Cargar(Bando.rival))) ? "correcto" : "FALLO"}');
    final c = aplicarCombate(a, const UsarCuerdaHuida(Bando.rival, 1));
    p('- Cuerda Huida: sale y el relevo no está apresado: ${!c.rival.apresado ? "correcto" : "FALLO"}');
  }
  // Muro Mágico de Clefairy jefe
  var sigue = 0, sinPerder = 0, total = 0;
  for (var s = 1; s <= n; s++) {
    var e = EstadoCombate.inicial(
        equipoJugador: [shellder], equipoRival: [clefairy], semilla: s);
    final antes = e.rival.pokemonActivo.ps;
    e = aplicarCombate(e, Atacar(Bando.jugador, ataqueDe(shellder, 'Torbellino')));
    total++;
    // El único daño que debe recibir es el del golpe (10, ×1 sin debilidad).
    if (antes - e.rival.pokemonActivo.ps <= 10) sinPerder++;
    if (e.rival.apresado) sigue++;
  }
  p('- Clefairy jefe (Muro Mágico) contra Torbellino: solo recibe el golpe '
      '(≤10 PS en total) ${pct(sinPerder, total)}; sigue apresado tras el primer '
      'chequeo ${pct(sigue, total)} (esperado 50 %, y sin perder PS por apresar).');
  p('');

  // ----------------------------------------------------------- curaAlAtacar
  p('## 4. Absorber de Paras (`curaAlAtacar`, #523/#533)');
  final absorber = ataqueDe(paras, 'Absorber');
  EstadoCombate conParas(int ps, PokemonCampana rival, {int semilla = 1}) {
    var e = EstadoCombate.inicial(
        equipoJugador: [paras], equipoRival: [rival], semilla: semilla);
    final eq = [PokemonEnCombate(paras, ps)];
    return e.conBando(
        Bando.jugador,
        BandoCombate(
          equipo: eq,
          activo: 0,
          energia: e.jugador.energia,
        ));
  }

  {
    final e = aplicarCombate(conParas(30, maniqui()), Atacar(Bando.jugador, absorber));
    p('- Paras 30/${paras.ps} PS usa Absorber: ${e.jugador.pokemonActivo.ps} PS '
        '(esperado 40); el Defensor pierde ${200 - e.rival.pokemonActivo.ps} (esperado 20).');
  }
  {
    final e = aplicarCombate(conParas(paras.ps, maniqui()), Atacar(Bando.jugador, absorber));
    p('- Paras con PS al máximo (${paras.ps}): se queda en ${e.jugador.pokemonActivo.ps} (no pasa del máximo).');
  }
  {
    final e = aplicarCombate(conParas(35, maniqui(ps: 20)), Atacar(Bando.jugador, absorber));
    p('- Paras 35 PS remata a un Defensor de 20 PS: combate ${e.fase.name}, '
        'Paras ${e.jugador.pokemonActivo.ps} PS (D-20: cura igual, esperado 45).');
  }
  {
    final e = aplicarCombate(conParas(30, clefairy), Atacar(Bando.jugador, absorber));
    p('- Contra Clefairy jefe (Muro Mágico): Paras ${e.jugador.pokemonActivo.ps} PS '
        '(D-20: cura igual, esperado 40); Clefairy pierde ${clefairy.ps - e.rival.pokemonActivo.ps} '
        '(Paras es planta; Clefairy es psíquico sin resistencia → 20).');
  }
  {
    var e = conParas(30, maniqui());
    e = e.conBando(Bando.jugador, e.jugador.copiarCon(cegado: true));
    var cura = 0, falla = 0;
    for (var s = 1; s <= n; s++) {
      var x = EstadoCombate.inicial(
          equipoJugador: [paras], equipoRival: [maniqui()], semilla: s);
      x = x.conBando(
          Bando.jugador,
          x.jugador.copiarCon(
              equipo: [PokemonEnCombate(paras, 30)], cegado: true));
      x = aplicarCombate(x, Atacar(Bando.jugador, absorber));
      if (x.jugador.pokemonActivo.ps == 40) {
        cura++;
      } else {
        falla++;
      }
    }
    p('- Paras marcada con Bofetón Lodo: cura en ${pct(cura, n)} de las tiradas '
        '(cara) y no cura cuando el ataque falla (${pct(falla, n)}) (esperado 50 % / 50 %).');
  }
  p('');

  // ------------------------------------------------- Doble Bofetón (Clefairy)
  p('## 5. Doble Bofetón de Clefairy jefe (monedasDano)');
  final bofeton = clefairy.ataques.first;
  final tabla = <int, int>{};
  var suma = 0;
  for (var s = 1; s <= n * 5; s++) {
    var e = EstadoCombate.inicial(
        equipoJugador: [clefairy], equipoRival: [maniqui(ps: 500)], semilla: s);
    e = aplicarCombate(e, Atacar(Bando.jugador, 0));
    final d = 500 - e.rival.pokemonActivo.ps;
    tabla[d] = (tabla[d] ?? 0) + 1;
    suma += d;
  }
  final claves = tabla.keys.toList()..sort();
  p('- Daño por tirada: ${[for (final k in claves) "$k → ${pct(tabla[k]!, n * 5)}"].join(" · ")}');
  p('- Daño medio real ${(suma / (n * 5)).toStringAsFixed(1)}; `dano` del JSON '
      '${bofeton.dano} (con 3 monedas y 20/30/40/50 la media teórica es 35).');
  p('');

  File('/tmp/efectos_tramo2.txt').writeAsStringSync(salida.toString());
}
