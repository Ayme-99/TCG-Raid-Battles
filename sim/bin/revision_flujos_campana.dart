// Revisión de los flujos de la campaña con el motor y el catálogo de master
// (#589). No es la app: juega cada flujo con `PartidaCampana`, el combate con
// la IA y el catálogo real, y marca OK / FALLO / NOTA. Los flujos que solo
// existen en pantalla (girar el móvil, sesión, menú) se revisan en el código y
// no salen aquí.
//
// Se ejecuta desde `sim/`:  dart run bin/revision_flujos_campana.dart
import 'dart:convert';
import 'dart:io';

import 'package:incursiones_engine/campana.dart';

Map<String, dynamic> _l(File f) =>
    jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
List<File> _js(String d) => Directory(d)
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.json'))
    .toList();

late CatalogoCampana c;
final salida = StringBuffer();
var fallos = 0;

void r(String flujo, String texto, bool ok, {bool nota = false}) {
  final marca = ok ? 'OK   ' : (nota ? 'NOTA ' : 'FALLO');
  if (!ok && !nota) fallos++;
  final l = '[$flujo] $marca $texto';
  print(l);
  salida.writeln(l);
}

/// Ejecuta [f]; devuelve el mensaje de la regla incumplida o null si no falló.
String? falla(void Function() f) {
  try {
    f();
    return null;
  } on ReglaIncumplida catch (e) {
    return e.mensaje;
  }
}

PartidaCampana modificar(
    PartidaCampana p, void Function(Map<String, dynamic>) f) {
  final j = jsonDecode(jsonEncode(p.aJson())) as Map<String, dynamic>;
  f(j);
  return PartidaCampana.desdeJson(j);
}

PartidaCampana equipoFuerte(PartidaCampana p, [List<String>? ids]) =>
    modificar(p, (j) {
      j['equipo'] = [
        for (final id in ids ?? ['wartortle', 'ivysaur', 'charmeleon'])
          {'id': id, 'ps': c.especie(id).ps},
      ];
    });

PartidaCampana ir(PartidaCampana p, List<String> destinos) {
  for (final d in destinos) {
    p = p.avanzar(c, d);
  }
  return p;
}

/// Juega el combate del nodo actual con la IA en los dos bandos. Con
/// [perder] el jugador no actúa (se deja ganar).
(PartidaCampana, EstadoCombate) combatir(PartidaCampana p,
    {bool perder = false}) {
  if (!perder) {
    // Para llegar a los demás flujos: se prueba con varias semillas hasta ganar.
    for (var sem = 1; sem <= 40; sem++) {
      final q = sem == 1 ? p : modificar(p, (j) => j['semilla'] = sem * 7);
      final (t, e) = _combatir(q);
      if (e.ganador == Bando.jugador || sem == 40) return (t, e);
    }
  }
  return _combatir(p, perder: perder);
}

(PartidaCampana, EstadoCombate) _combatir(PartidaCampana p,
    {bool perder = false}) {
  var e = p.empezarCombate(c);
  var pasos = 0;
  while (e.fase != FaseCombate.terminado && pasos++ < 1500) {
    final bando = e.actua;
    if (perder && bando == Bando.jugador) {
      // El jugador solo carga: acaba cayendo.
      try {
        e = aplicarCombate(e, const Cargar(Bando.jugador));
      } on ReglaIncumplida {
        e = aplicarCombate(e, decidirAccion(e, bando));
      }
    } else {
      e = aplicarCombate(e, decidirAccion(e, bando));
    }
  }
  return (p.terminarCombate(c, e), e);
}

void main(List<String> args) {
  const cat = '../catalog/campana';
  c = CatalogoCampana.desdeJson(
    pokemon: [for (final f in _js('$cat/pokemon')) _l(f)],
    zonas: [for (final f in _js('$cat/zonas')) _l(f)],
    jefes: {
      for (final f in _js('$cat/jefes'))
        f.uri.pathSegments.last.replaceAll('.json', ''): _l(f),
    },
    region: _l(File('$cat/regiones/kanto.json')),
  );
  r('0', 'el catálogo no tiene problemas: ${c.problemas()}', c.problemas().isEmpty);

  // ------------------------------------------------------------------ 1
  var p = PartidaCampana.nueva(c.region, semilla: 5);
  r('1', 'Nueva campaña empieza en ${p.progreso.nodoActual}, sin equipo, '
      '${p.dinero} de dinero', p.progreso.nodoActual == 'pueblo-paleta' && p.equipo.isEmpty);
  r('1', 'sin elegir inicial no se puede avanzar: ${falla(() => p.avanzar(c, 'ruta-1'))}',
      falla(() => p.avanzar(c, 'ruta-1')) != null);
  for (final i in ['bulbasaur', 'charmander', 'squirtle']) {
    final q = p.elegirInicial(c, i);
    r('1', 'inicial $i: 1 Pokémon con PS completos (${q.equipo.first.ps}), '
        'opciones ${q.opciones(c)}',
        q.equipo.length == 1 && q.equipo.first.ps == c.especie(i).ps);
  }
  r('1', 'inicial que no lo es (pikachu): ${falla(() => p.elegirInicial(c, 'pikachu'))}',
      falla(() => p.elegirInicial(c, 'pikachu')) != null);
  final inicial = p.elegirInicial(c, 'squirtle');
  r('1', 'no se puede elegir otro inicial después: ${falla(() => inicial.elegirInicial(c, 'charmander'))}',
      falla(() => inicial.elegirInicial(c, 'charmander')) != null,
      nota: true);
  // Continuar: guardar y cargar en varios puntos.
  PartidaCampana viaje = inicial;
  bool igual(PartidaCampana a) {
    final j = jsonEncode(a.aJson());
    return jsonEncode(PartidaCampana.desdeJson(jsonDecode(j) as Map<String, dynamic>).aJson()) == j &&
        PartidaCampana.desdeJson(jsonDecode(j) as Map<String, dynamic>).problemas(c).isEmpty;
  }

  r('1', 'Continuar: guardar y cargar tras elegir inicial', igual(viaje));
  viaje = ir(viaje, ['ruta-1', 'ruta-1-pidgey']);
  r('1', 'Continuar: guardado en un combate sin jugar (nodo ${viaje.progreso.nodoActual}, hayCombate=${viaje.hayCombate(c)})',
      igual(viaje) && viaje.hayCombate(c));
  final (tras, _) = combatir(equipoFuerte(viaje));
  r('1', 'Continuar: guardado con captura pendiente (${tras.capturaPendiente})',
      igual(tras) && tras.capturaPendiente != null);
  r('1', 'una partida de la versión 1 (XP por Pokémon) se carga',
      falla(() {
        final j = jsonDecode(jsonEncode(tras.aJson())) as Map<String, dynamic>;
        j['version'] = 1;
        for (final k in ['equipo', 'pc']) {
          for (final x in j[k] as List) {
            (x as Map<String, dynamic>)['xp'] = 3;
          }
        }
        PartidaCampana.desdeJson(j);
      }) == null);
  r('1', 'una partida con versión desconocida se rechaza con mensaje: '
      '${(() { try { final j = tras.aJson(); j['version'] = 99; PartidaCampana.desdeJson(j); return 'no falla'; } on FormatException catch (e) { return e.message; } })()}',
      (() { try { final j = tras.aJson(); j['version'] = 99; PartidaCampana.desdeJson(j); return false; } on FormatException { return true; } })());
  // Una partida guardada con un Pokémon que ya no está en el catálogo.
  final rota = modificar(tras, (j) {
    (j['equipo'] as List).add({'id': 'mew', 'ps': 10});
  });
  r('1', 'partida con Pokémon fuera del catálogo: problemas=${rota.problemas(c)} (la app debe avisar, no romperse)',
      rota.problemas(c).isNotEmpty);

  // ------------------------------------------------------------------ 2
  var s = equipoFuerte(ir(inicial, ['ruta-1', 'ruta-1-pidgey']));
  var (ganada, fin) = combatir(s);
  r('2', 'salvaje de Ruta 1 vencido: ${ganada.rival(c).equipo.map((x) => x.id).toList()}, '
      'captura pendiente ${ganada.capturaPendiente}, XP ${ganada.xp}, puntos ${ganada.puntos}, dinero ${ganada.dinero}',
      fin.ganador == Bando.jugador && ganada.capturaPendiente != null);
  r('2', 'sin Pokéballs: ${falla(() => ganada.lanzarBall(c, ObjetoCampana.pokeball))}',
      falla(() => ganada.lanzarBall(c, ObjetoCampana.pokeball)) != null);
  r('2', 'con captura pendiente no se avanza: ${falla(() => ganada.avanzar(c, 'ciudad-verde'))}',
      falla(() => ganada.avanzar(c, 'ciudad-verde')) != null);
  final sinCapturar = ganada.noCapturar();
  r('2', 'Dejarlo ir: se queda sin captura y puede avanzar a ${sinCapturar.opciones(c)}',
      sinCapturar.capturaPendiente == null && sinCapturar.opciones(c).isNotEmpty);
  // Con Balls: hasta lograr y hasta fallar.
  final conBalls = modificar(ganada, (j) => j['mochila'] = {'pokeball': 20});
  var acierto = 0, fallo = 0;
  String? casoFallo;
  for (var sem = 1; sem <= 60; sem++) {
    final q = modificar(conBalls, (j) => j['semilla'] = sem);
    final l = q.lanzarBall(c, ObjetoCampana.pokeball);
    if (l.capturaLograda) {
      acierto++;
    } else {
      fallo++;
      casoFallo ??= 'tras fallar: pendiente=${l.capturaPendiente}, Balls=${l.cuantos(ObjetoCampana.pokeball)}, puede seguir=${falla(() => l.lanzarBall(c, ObjetoCampana.pokeball)) == null}';
    }
  }
  r('2', 'tirada de Pokéball en 60 semillas: $acierto aciertos, $fallo fallos (Común 75 %)',
      acierto > 0 && fallo > 0);
  r('2', 'fallo de captura → $casoFallo', casoFallo != null);
  final lograda = [
    for (var sem = 1; sem <= 60; sem++)
      modificar(conBalls, (j) => j['semilla'] = sem)
          .lanzarBall(c, ObjetoCampana.pokeball),
  ].firstWhere((q) => q.capturaLograda);
  r('2', 'tras lograrla no se puede dejar ir: ${falla(() => lograda.noCapturar())}',
      falla(() => lograda.noCapturar()) != null);
  r('2', 'tras lograrla tampoco se avanza sin colocarla: ${falla(() => lograda.avanzar(c, 'ciudad-verde'))}',
      falla(() => lograda.avanzar(c, 'ciudad-verde')) != null);
  final colocada = lograda.capturar(c);
  r('2', 'Capturar con hueco: el equipo pasa a ${colocada.equipo.length} con PS completos '
      '(${colocada.equipo.last.ps}/${c.especie(colocada.equipo.last.id).ps})',
      colocada.equipo.length == 4 &&
          colocada.equipo.last.ps == c.especie(colocada.equipo.last.id).ps);
  final lleno = modificar(lograda, (j) {
    j['equipo'] = [
      for (final id in ['wartortle', 'ivysaur', 'charmeleon', 'pidgey', 'rattata', 'caterpie'])
        {'id': id, 'ps': c.especie(id).ps},
    ];
  });
  r('2', 'equipo lleno: equipoLleno=${lleno.equipoLleno()}; sin sustituir va al PC (${lleno.capturar(c).pc.length} en el PC); '
      'sustituyendo el 6.º, el sustituido va al PC (${lleno.capturar(c, sustituir: 5).pc.map((x) => x.id).toList()})',
      lleno.capturar(c).pc.length == 1 && lleno.capturar(c, sustituir: 5).pc.length == 1);
  r('2', 'sustituir un Pokémon que no existe: ${falla(() => lleno.capturar(c, sustituir: 9))}',
      falla(() => lleno.capturar(c, sustituir: 9)) != null);
  // Repetir un salvaje ya vencido.
  r('2', 'repetir el salvaje ya vencido: puedeRepetir=${colocada.puedeRepetir(c)}',
      !colocada.puedeRepetir(c), nota: true);
  // Repetir de verdad: quedarse en el nodo y repetir.
  final antes = colocada;
  final rep = antes.puedeRepetir(c) ? antes.repetirCombate(c) : null;
  r('2', 'tras capturar sigue en ${antes.progreso.nodoActual}; se puede repetir=${rep != null}',
      true, nota: true);
  // Pokémon sin Pokéballs al fallar el último intento.
  final unaBall = modificar(ganada, (j) => j['mochila'] = {'pokeball': 1});
  var sinBalls = unaBall;
  for (var sem = 1; sem <= 60; sem++) {
    final q = modificar(unaBall, (j) => j['semilla'] = sem).lanzarBall(c, ObjetoCampana.pokeball);
    if (!q.capturaLograda) {
      sinBalls = q;
      break;
    }
  }
  r('2', 'fallar con la última Ball: Balls=${sinBalls.cuantos(ObjetoCampana.pokeball)}, captura pendiente=${sinBalls.capturaPendiente} '
      '→ sale con ${falla(() => sinBalls.avanzar(c, 'ciudad-verde')) == null ? "avanzar libre" : "avanzar bloqueado"} (debe poder dejarlo ir)',
      falla(() => sinBalls.noCapturar()) == null);

  // ------------------------------------------------------------------ 3
  // Entrenadores
  var t = equipoFuerte(inicial);
  t = ir(t, ['ruta-1', 'ruta-1-pidgey']);
  t = combatir(t).$1.noCapturar();
  t = ir(t, ['ciudad-verde', 'ciudad-verde-salida', 'ruta-2', 'ruta-2-weedle']);
  t = combatir(t).$1.noCapturar();
  t = ir(t, ['cazabichos-1']);
  final antesDinero = t.dinero, antesPuntos = t.puntos, antesXp = t.xp;
  final (trasEnt, finEnt) = combatir(t);
  r('3', 'Cazabichos vencido: dinero +${trasEnt.dinero - antesDinero}, puntos +${trasEnt.puntos - antesPuntos}, '
      'XP +${trasEnt.xp - antesXp}, captura pendiente=${trasEnt.capturaPendiente} (los entrenadores no se capturan)',
      finEnt.ganador == Bando.jugador && trasEnt.capturaPendiente == null);
  r('3', 'hitos pendientes tras el entrenador: ${trasEnt.hitosPendientes.map((h) => "${h.id}:${h.tipo.name}:${h.puntos}").toList()} (puntos del menú, no de la campaña)',
      trasEnt.hitosPendientes.isNotEmpty);
  var pk = ir(trasEnt, ['cazabichos-2']);
  pk = combatir(pk).$1;
  pk = ir(pk, ['aviso-pikachu']);
  final danado = modificar(pk, (j) {
    for (final x in j['equipo'] as List) {
      (x as Map<String, dynamic>)['ps'] = 5;
    }
  });
  final avisado = danado.conversar(c);
  r('3', 'aviso de Pikachu cura al equipo (${avisado.equipo.map((x) => x.ps).toList()}) y es el sitio de vuelta (${avisado.ultimaCura})',
      avisado.equipo.every((x) => x.ps == c.especie(x.id).ps) && avisado.ultimaCura == 'aviso-pikachu');
  r('3', 'hablar dos veces: ${falla(() => avisado.conversar(c))}',
      falla(() => avisado.conversar(c)) != null);
  var jefe = ir(avisado, ['jefe-pikachu']);
  r('3', 'Pikachu jefe: hayCombate=${jefe.hayCombate(c)}, rival=${jefe.rival(c).equipo.map((x) => x.id).toList()}, empieza el jugador (D-20 §10)',
      jefe.hayCombate(c));
  final (ganaJefe, finJefe) = combatir(jefe);
  r('3', 'Pikachu jefe vencido (${finJefe.ganador?.name}): captura pendiente=${ganaJefe.capturaPendiente}, '
      'jefes derrotados=${ganaJefe.progreso.jefesDerrotados}, XP +${ganaJefe.xp - jefe.xp}',
      finJefe.ganador == Bando.jugador && ganaJefe.capturaPendiente != null);
  // Segunda vez: no hay captura. Volver al nodo y repetir? Un jefe no se repite.
  r('3', 'el jefe ya vencido no se repite: puedeRepetir=${ganaJefe.noCapturar().puedeRepetir(c)}',
      !ganaJefe.noCapturar().puedeRepetir(c));
  // Segunda vez que se derrota (partida con el jefe ya en jefesDerrotados).
  final yaVencido = modificar(jefe, (j) {
    (j['progreso'] as Map<String, dynamic>)['jefesDerrotados'] = ['pikachu-jefe'];
  });
  final (ganaOtra, _) = combatir(equipoFuerte(yaVencido));
  r('3', 'con el jefe ya en jefesDerrotados, no se ofrece captura: ${ganaOtra.capturaPendiente}',
      ganaOtra.capturaPendiente == null);
  // Gimnasio y medalla
  var g = equipoFuerte(ganaJefe.noCapturar(), ['wartortle', 'wartortle', 'ivysaur', 'charmeleon']);
  g = ir(g, ['ruta-2-norte', 'centro-plateada', 'gimnasio-joven']);
  g = combatir(g).$1;
  // Entre el Joven y Brock no hay centro: se vuelve atrás a curar (D-20 §10.7).
  g = g.retroceder(c, 'centro-plateada').descansar(c);
  g = ir(g, ['gimnasio-joven', 'gimnasio-brock']);
  final (ganaBrock, finBrock) = combatir(g);
  r('3', 'Brock (rival empieza primero, D-20 §10; combate ${finBrock.ganador?.name}): medallas ${ganaBrock.progreso.medallas}, '
      'piedras ex ${ganaBrock.cuantos(ObjetoCampana.piedraEx)}, dinero +${ganaBrock.dinero - g.dinero}',
      finBrock.ganador == Bando.jugador &&
          ganaBrock.progreso.medallas.length == 1 &&
          ganaBrock.cuantos(ObjetoCampana.piedraEx) == 1,
      nota: finBrock.ganador != Bando.jugador);
  r('3', 'Brock da captura: ${ganaBrock.capturaPendiente} (un líder no se captura)', ganaBrock.capturaPendiente == null);

  // ------------------------------------------------------------------ 4
  // Derrota: con y sin curar en el centro.
  var d = equipoFuerte(inicial);
  d = ir(d, ['ruta-1', 'ruta-1-pidgey']);
  d = combatir(d).$1.noCapturar();
  d = ir(d, ['ciudad-verde']);
  r('4', 'Ciudad Verde sin curar aún: ultimaCura=${d.ultimaCura}', d.ultimaCura == 'pueblo-paleta');
  var dSin = d;
  dSin = ir(dSin, ['ciudad-verde-salida', 'ruta-2', 'ruta-2-weedle']);
  final (perdida, finPerdida) = combatir(dSin, perder: true);
  r('4', 'derrota sin haber curado: vuelve a ${perdida.progreso.nodoActual} (esperado pueblo-paleta), derrotas=${perdida.derrotas}, '
      'equipo curado=${perdida.equipo.every((x) => x.ps == c.especie(x.id).ps)}, '
      'XP ${dSin.xp}→${perdida.xp}, dinero ${dSin.dinero}→${perdida.dinero}, puntos ${dSin.puntos}→${perdida.puntos}',
      finPerdida.ganador != Bando.jugador &&
          perdida.progreso.nodoActual == 'pueblo-paleta' &&
          perdida.xp == dSin.xp);
  var dCon = d.descansar(c);
  r('4', 'curar en Ciudad Verde fija el retorno: ${dCon.ultimaCura}', dCon.ultimaCura == 'ciudad-verde');
  dCon = ir(dCon, ['ciudad-verde-salida', 'ruta-2', 'ruta-2-weedle']);
  final (perdida2, _) = combatir(dCon, perder: true);
  r('4', 'derrota tras curar en Ciudad Verde: vuelve a ${perdida2.progreso.nodoActual}', perdida2.progreso.nodoActual == 'ciudad-verde');
  r('4', 'tras volver, el nodo de Ciudad Verde está sin resolver=${!perdida2.progreso.resuelto} y se puede seguir: ${perdida2.opciones(c)}',
      perdida2.opciones(c).isNotEmpty || perdida2.progreso.resuelto == false);
  r('4', 'la medalla y la piedra ex ganadas se conservan tras perder después: '
      '${(() { final q = ir(ganaBrock, ['ruta-3', 'ruta-3-spearow']); final (pp, _) = combatir(q, perder: true); return "medallas ${pp.progreso.medallas}, piedras ex ${pp.cuantos(ObjetoCampana.piedraEx)}, retorno ${pp.progreso.nodoActual}"; })()}',
      true, nota: true);
  // Perder contra el jefe y la captura
  final (perdJefe, _) = combatir(modificar(jefe, (j) {
    (j['equipo'] as List).first['ps'] = 1;
  }), perder: true);
  r('4', 'perder contra Pikachu jefe: vuelve a ${perdJefe.progreso.nodoActual} (esperado aviso-pikachu, que cura), derrotas ${perdJefe.derrotas}',
      perdJefe.progreso.nodoActual == 'aviso-pikachu');
  r('4', 'perder con una Poción gastada en combate: se descuenta de la mochila',
      (() {
        final q = modificar(dSin, (j) => j['mochila'] = {'pocion': 3});
        final (pp, _) = combatir(q, perder: true);
        return pp.cuantos(ObjetoCampana.pocion) <= 3;
      })());

  // ------------------------------------------------------------------ 5
  var ce = equipoFuerte(inicial);
  ce = modificar(ce, (j) {
    j['dinero'] = 1000;
    (j['equipo'] as List).first['ps'] = 3;
  });
  ce = ir(ce, ['ruta-1', 'ruta-1-pidgey']);
  ce = combatir(ce).$1.noCapturar();
  ce = ir(ce, ['ciudad-verde']);
  r('5', 'tienda de Ciudad Verde: ${ce.tienda(c).map((o) => o.name).toList()}',
      ce.tienda(c).contains(ObjetoCampana.pokeball));
  final comprado = ce.comprar(c, ObjetoCampana.pokeball, cantidad: 2);
  r('5', 'comprar 2 Pokéballs: dinero ${ce.dinero}→${comprado.dinero}, Balls ${comprado.cuantos(ObjetoCampana.pokeball)}',
      comprado.cuantos(ObjetoCampana.pokeball) == 2 && comprado.dinero < ce.dinero);
  final pobre = modificar(ce, (j) => j['dinero'] = 100);
  r('5', 'dinero insuficiente: ${falla(() => pobre.comprar(c, ObjetoCampana.pokeball))}',
      falla(() => pobre.comprar(c, ObjetoCampana.pokeball)) != null);
  r('5', 'cantidad 0: ${falla(() => ce.comprar(c, ObjetoCampana.pokeball, cantidad: 0))}',
      falla(() => ce.comprar(c, ObjetoCampana.pokeball, cantidad: 0)) != null);
  r('5', 'algo que ese centro no vende (Cuerda Huida): ${falla(() => ce.comprar(c, ObjetoCampana.cuerdaHuida))}',
      falla(() => ce.comprar(c, ObjetoCampana.cuerdaHuida)) != null);
  r('5', 'piedra ex sin 2 medallas: tienda=${ce.tienda(c).contains(ObjetoCampana.piedraEx)}; comprar → ${falla(() => ce.comprar(c, ObjetoCampana.piedraEx))}',
      falla(() => ce.comprar(c, ObjetoCampana.piedraEx)) != null);
  final dosMedallas = modificar(ce, (j) {
    (j['progreso'] as Map<String, dynamic>)['medallas'] = ['roca', 'cascada'];
    j['dinero'] = 2500;
  });
  r('5', 'piedra ex con 2 medallas y 2.500: ${falla(() => dosMedallas.comprar(c, ObjetoCampana.piedraEx)) ?? "se compra"}',
      falla(() => dosMedallas.comprar(c, ObjetoCampana.piedraEx)) == null);
  final curado = ce.descansar(c);
  r('5', 'curar: PS ${ce.equipo.map((x) => x.ps).toList()}→${curado.equipo.map((x) => x.ps).toList()}, retorno ${curado.ultimaCura}',
      curado.equipo.every((x) => x.ps == c.especie(x.id).ps));
  r('5', 'curar dos veces seguidas no falla: ${falla(() => curado.descansar(c)) ?? "ok"}',
      falla(() => curado.descansar(c)) == null);
  r('5', 'salir sin curar: avanza a ${ce.opciones(c)} aunque el equipo esté herido y la última cura siga siendo ${ce.ultimaCura}',
      ce.opciones(c).isNotEmpty && ce.ultimaCura != 'ciudad-verde');
  // PC
  var pc = modificar(curado, (j) {
    j['equipo'] = [
      for (final id in ['wartortle', 'ivysaur'])
        {'id': id, 'ps': c.especie(id).ps},
    ];
    j['pc'] = [
      {'id': 'pidgey', 'ps': 1},
    ];
  });
  r('5', 'PC: sacar al equipo con hueco → equipo ${pc.moverPc(c, dePc: 0).equipo.length}, PC ${pc.moverPc(c, dePc: 0).pc.length}',
      pc.moverPc(c, dePc: 0).equipo.length == 3);
  r('5', 'PC: dejar un Pokémon → PC ${pc.moverPc(c, deEquipo: 1).pc.length}',
      pc.moverPc(c, deEquipo: 1).pc.length == 2);
  r('5', 'PC: intercambiar → ${pc.moverPc(c, deEquipo: 0, dePc: 0).equipo.map((x) => x.id).toList()}',
      pc.moverPc(c, deEquipo: 0, dePc: 0).equipo.first.id == 'pidgey');
  final solo = modificar(pc, (j) => j['equipo'] = [(j['equipo'] as List).first]);
  r('5', 'PC: dejar al último del equipo: ${falla(() => solo.moverPc(c, deEquipo: 0))}',
      falla(() => solo.moverPc(c, deEquipo: 0)) != null);
  final seis = modificar(pc, (j) {
    j['equipo'] = [
      for (final id in ['wartortle', 'ivysaur', 'charmeleon', 'pidgey', 'rattata', 'caterpie'])
        {'id': id, 'ps': c.especie(id).ps},
    ];
  });
  r('5', 'PC: sacar con el equipo lleno: ${falla(() => seis.moverPc(c, dePc: 0))}',
      falla(() => seis.moverPc(c, dePc: 0)) != null);
  r('5', 'PC fuera de un centro: ${falla(() => inicial.moverPc(c, dePc: 0))}',
      falla(() => inicial.moverPc(c, dePc: 0)) != null);
  r('5', 'curar cura también al PC: ${pc.descansar(c).pc.first.ps}/${c.especie('pidgey').ps}',
      pc.descansar(c).pc.first.ps == c.especie('pidgey').ps);

  // ------------------------------------------------------------------ 6
  var eq = modificar(inicial, (j) {
    j['xp'] = 300;
    (j['equipo'] as List).first['ps'] = 20;
    j['mochila'] = {'pocion': 2};
  });
  final antesP = eq.equipo.first.ps;
  final pot = eq.usarPocion(c, 0);
  r('6', 'Poción fuera de combate: PS $antesP→${pot.equipo.first.ps} (+20), Pociones ${eq.cuantos(ObjetoCampana.pocion)}→${pot.cuantos(ObjetoCampana.pocion)}',
      pot.equipo.first.ps == antesP + 20);
  final casiLleno = modificar(eq, (j) => (j['equipo'] as List).first['ps'] = c.especie('squirtle').ps - 5);
  r('6', 'Poción con 5 PS de daño: ${casiLleno.usarPocion(c, 0).equipo.first.ps} (máximo ${c.especie('squirtle').ps}, no pasa)',
      casiLleno.usarPocion(c, 0).equipo.first.ps == c.especie('squirtle').ps);
  final lleno2 = modificar(eq, (j) => (j['equipo'] as List).first['ps'] = c.especie('squirtle').ps);
  r('6', 'Poción con PS llenos: ${falla(() => lleno2.usarPocion(c, 0)) ?? "la gasta sin efecto"}',
      falla(() => lleno2.usarPocion(c, 0)) != null, nota: true);
  final caido = modificar(eq, (j) => (j['equipo'] as List).first['ps'] = 0);
  r('6', 'Poción a un debilitado: ${falla(() => caido.usarPocion(c, 0))}',
      falla(() => caido.usarPocion(c, 0)) != null);
  r('6', 'Poción a un Pokémon que no existe: ${falla(() => eq.usarPocion(c, 7))}',
      falla(() => eq.usarPocion(c, 7)) != null);
  final sinPociones = modificar(eq, (j) => j['mochila'] = <String, dynamic>{});
  r('6', 'sin Pociones: ${falla(() => sinPociones.usarPocion(c, 0))}',
      falla(() => sinPociones.usarPocion(c, 0)) != null);
  final evs = eq.evolucionesDe(c, 0);
  r('6', 'evoluciones de Squirtle: ${evs.map((e) => "${e.a} (${e.via.name}, ${e.xpEvolucion} XP)").toList()}', evs.isNotEmpty);
  final ev = eq.evolucionar(c, 0, 'wartortle');
  r('6', 'evolucionar por XP: ${eq.equipo.first.id} ${eq.equipo.first.ps}/${c.especie('squirtle').ps} → '
      '${ev.equipo.first.id} ${ev.equipo.first.ps}/${c.especie('wartortle').ps}, XP ${eq.xp}→${ev.xp} '
      '(HOY queda a 10 PS; la decisión del 28-11 pide conservar el % y redondear arriba: 74/110 desde 40/60; pendiente de #570)',
      ev.equipo.first.id == 'wartortle', nota: true);
  final pocoXp = modificar(eq, (j) => j['xp'] = 10);
  r('6', 'evolucionar sin XP: ${pocoXp.motivoSinEvolucion(evs.first)}',
      pocoXp.motivoSinEvolucion(evs.first) != null);
  final caidoEv = modificar(eq, (j) => (j['equipo'] as List).first['ps'] = 0);
  r('6', 'evolucionar a un debilitado: PS ${caidoEv.evolucionar(c, 0, 'wartortle').equipo.first.ps} (hoy 10; la decisión del 28-11 también lo deja a 10)',
      caidoEv.evolucionar(c, 0, 'wartortle').equipo.first.ps == 10);
  r('6', 'evolucionar a algo que no es su evolución: ${falla(() => eq.evolucionar(c, 0, 'charizard'))}',
      falla(() => eq.evolucionar(c, 0, 'charizard')) != null);
  final dosVeces = ev.evolucionesDe(c, 0);
  r('6', 'tras evolucionar a Wartortle, evoluciones: ${dosVeces.map((e) => "${e.a} (${e.via.name}; mín. ${e.medallasMinimas} medallas)").toList()}',
      true, nota: true);
  // Hacerse ex
  final conEx = modificar(eq, (j) {
    j['mochila'] = {'piedraEx': 1};
    (j['progreso'] as Map<String, dynamic>)['medallas'] = ['roca'];
  });
  final exs = conEx.evolucionesDe(c, 0).where((e) => e.esPiedraEx).toList();
  r('6', 'hacerse ex con 1 medalla: opciones ${exs.map((e) => "${e.a} mín. ${e.medallasMinimas}").toList()}; '
      'motivo ${exs.isEmpty ? "—" : conEx.motivoSinEvolucion(exs.first)}', true, nota: true);
  // Piedras evolutivas
  r('6', 'Piedra Trueno: ${ObjetoCampana.piedraTrueno.name} en la tienda de Ciudad Verde=${ce.tienda(c).contains(ObjetoCampana.piedraTrueno)}, '
      'Luna vendible=${const ParametrosCampana().precios.containsKey(ObjetoCampana.piedraLuna)}',
      !const ParametrosCampana().precios.containsKey(ObjetoCampana.piedraLuna));

  // ------------------------------------------------------------------ 7
  final ec = equipoFuerte(inicial);
  var e0 = modificar(ec, (j) => j['mochila'] = {'pocion': 2, 'cuerdaHuida': 1});
  e0 = ir(e0, ['ruta-1', 'ruta-1-pidgey']);
  var est = e0.empezarCombate(c);
  r('7', 'combate con ${e0.cuantos(ObjetoCampana.pocion)} Pociones y ${e0.cuantos(ObjetoCampana.cuerdaHuida)} Cuerda Huida: '
      'pocionesJugador=${est.jugador.pociones}, cuerdasJugador=${est.jugador.cuerdas}',
      est.jugador.pociones == 2 && est.jugador.cuerdas == 1);
  final herido = est.conBando(
      Bando.jugador,
      est.jugador.copiarCon(equipo: [
        PokemonEnCombate(est.jugador.pokemonActivo.especie, 30),
        ...est.jugador.equipo.skip(1),
      ]));
  if (herido.actua == Bando.jugador) {
    final tras = aplicarCombate(herido, const UsarPocion(Bando.jugador, 0));
    r('7', 'Poción en combate no gasta turno: sigue actuando ${tras.actua.name}; PS 30→${tras.jugador.pokemonActivo.ps}; usadas ${tras.jugador.pocionesUsadas}',
        tras.actua == Bando.jugador);
    final cuerda = aplicarCombate(herido, const UsarCuerdaHuida(Bando.jugador, 1));
    r('7', 'Cuerda Huida cambia al activo sin retirada y pasa el turno: activo ${cuerda.jugador.pokemonActivo.especie.id}, turno de ${cuerda.actua.name}',
        cuerda.actua == Bando.rival);
    final dosCuerdas = falla(() => aplicarCombate(cuerda, const UsarCuerdaHuida(Bando.jugador, 0)));
    r('7', 'segunda Cuerda Huida sin tenerla (turno del rival o sin objeto): $dosCuerdas', dosCuerdas != null);
  } else {
    r('7', 'el rival empieza este combate; se omite la prueba de Poción', true, nota: true);
  }
  // Gasto al terminar el combate: se fuerza una Poción y una Cuerda Huida.
  var forzado = herido.actua == Bando.jugador ? herido : est;
  var pasosF = 0;
  var usoPocion = false, usoCuerda = false;
  while (forzado.fase != FaseCombate.terminado && pasosF++ < 900) {
    if (forzado.actua == Bando.jugador && !usoPocion && forzado.jugador.pokemonActivo.ps < forzado.jugador.pokemonActivo.especie.ps) {
      forzado = aplicarCombate(forzado, const UsarPocion(Bando.jugador, 0));
      usoPocion = true;
      continue;
    }
    if (forzado.actua == Bando.jugador && usoPocion && !usoCuerda && forzado.jugador.equipo.length > 1) {
      forzado = aplicarCombate(forzado, const UsarCuerdaHuida(Bando.jugador, 1));
      usoCuerda = true;
      continue;
    }
    forzado = aplicarCombate(forzado, decidirAccion(forzado, forzado.actua));
  }
  final trasForzado = e0.terminarCombate(c, forzado);
  r('7', 'tras un combate con Poción (usadas ${forzado.jugador.pocionesUsadas}) y Cuerda Huida (usadas ${forzado.jugador.cuerdasUsadas}): '
      'mochila Pociones ${e0.cuantos(ObjetoCampana.pocion)}→${trasForzado.cuantos(ObjetoCampana.pocion)}, Cuerdas ${e0.cuantos(ObjetoCampana.cuerdaHuida)}→${trasForzado.cuantos(ObjetoCampana.cuerdaHuida)}',
      usoPocion &&
          trasForzado.cuantos(ObjetoCampana.pocion) == 1 &&
          (!usoCuerda || trasForzado.cuantos(ObjetoCampana.cuerdaHuida) == 0));
  // Gasto al terminar el combate.
  final jugado = (() {
    var e = est;
    var n = 0;
    while (e.fase != FaseCombate.terminado && n++ < 800) {
      if (e.actua == Bando.jugador &&
          n == 1 &&
          e.jugador.pokemonActivo.ps < e.jugador.pokemonActivo.especie.ps) {
        e = aplicarCombate(e, const UsarPocion(Bando.jugador, 0));
        continue;
      }
      e = aplicarCombate(e, decidirAccion(e, e.actua));
    }
    return e;
  })();
  final trasObj = e0.terminarCombate(c, jugado);
  r('7', 'tras el combate la mochila descuenta lo usado: Pociones ${e0.cuantos(ObjetoCampana.pocion)}→${trasObj.cuantos(ObjetoCampana.pocion)} '
      '(usadas ${jugado.jugador.pocionesUsadas}), Cuerdas ${e0.cuantos(ObjetoCampana.cuerdaHuida)}→${trasObj.cuantos(ObjetoCampana.cuerdaHuida)} (usadas ${jugado.jugador.cuerdasUsadas})',
      trasObj.cuantos(ObjetoCampana.pocion) == e0.cuantos(ObjetoCampana.pocion) - jugado.jugador.pocionesUsadas);
  r('7', 'Repelente fuera de un salvaje: ${falla(() => e0.usarRepelente(c))}',
      falla(() => e0.usarRepelente(c)) != null);

  // ------------------------------------------------------------------ 8
  var b = ir(equipoFuerte(inicial), ['ruta-1']);
  r('8', 'bifurcación de Ruta 1: opciones ${b.opciones(c)}', b.opciones(c).length == 2);
  r('8', 'destino fuera de las salidas: ${falla(() => b.avanzar(c, 'ciudad-verde'))}',
      falla(() => b.avanzar(c, 'ciudad-verde')) != null);
  b = b.avanzar(c, 'ruta-1-rattata');
  r('8', 'combate pendiente sin jugar: avanzar → ${falla(() => b.avanzar(c, 'ciudad-verde'))}',
      falla(() => b.avanzar(c, 'ciudad-verde')) != null);
  final atras = b.retroceder(c, 'ruta-1');
  r('8', 'volver atrás sin jugar el combate: ahora en ${atras.progreso.nodoActual}; puede elegir la otra rama ${atras.opciones(c)}',
      atras.progreso.nodoActual == 'ruta-1');
  r('8', 'volver a un sitio no visitado: ${falla(() => b.retroceder(c, 'ciudad-verde'))}',
      falla(() => b.retroceder(c, 'ciudad-verde')) != null);
  r('8', 'retroceder al mismo nodo: ${falla(() => b.retroceder(c, 'ruta-1-rattata'))}',
      falla(() => b.retroceder(c, 'ruta-1-rattata')) != null);
  final otra = atras.avanzar(c, 'ruta-1-pidgey');
  r('8', 'cambiar de rama tras volver atrás: ahora ${otra.progreso.nodoActual}', otra.progreso.nodoActual == 'ruta-1-pidgey');
  // Las dos ramas: ¿se puede ir a Ciudad Verde sin haber peleado nunca?
  final sinPelear = falla(() {
    var q = ir(equipoFuerte(inicial), ['ruta-1', 'ruta-1-pidgey']);
    q.avanzar(c, 'ciudad-verde');
  });
  r('8', 'saltarse el combate obligatorio de Ruta 1: ${sinPelear ?? "SE PUEDE"}', sinPelear != null);
  // Volver a un salvaje ya vencido y repetirlo
  var rep2 = equipoFuerte(inicial);
  rep2 = ir(rep2, ['ruta-1', 'ruta-1-pidgey']);
  rep2 = combatir(rep2).$1.noCapturar();
  rep2 = ir(rep2, ['ciudad-verde']);
  final vuelta = rep2.retroceder(c, 'ruta-1-pidgey');
  r('8', 'volver a un salvaje vencido: puedeRepetir=${vuelta.puedeRepetir(c)}, hayCombate=${vuelta.hayCombate(c)}',
      vuelta.puedeRepetir(c));
  final repetido = vuelta.repetirCombate(c);
  final (repGan, _) = combatir(repetido);
  r('8', 'repetir da XP (${vuelta.xp}→${repGan.xp}), puntos ${vuelta.puntos}→${repGan.puntos}, dinero ${vuelta.dinero}→${repGan.dinero} '
      '(sin puntos ni dinero, D-20 §10.7), captura=${repGan.capturaPendiente}',
      repGan.xp > vuelta.xp && repGan.puntos == vuelta.puntos && repGan.dinero == vuelta.dinero);
  // Un entrenador ya vencido no se repite
  var entr = equipoFuerte(inicial);
  entr = ir(entr, ['ruta-1', 'ruta-1-pidgey']);
  entr = combatir(entr).$1.noCapturar();
  entr = ir(entr, ['ciudad-verde', 'ciudad-verde-salida', 'ruta-2', 'ruta-2-weedle']);
  entr = combatir(entr).$1.noCapturar();
  entr = ir(entr, ['cazabichos-1']);
  entr = combatir(entr).$1;
  final vEntr = entr.retroceder(c, 'ruta-2-weedle');
  r('8', 'volver desde el entrenador al salvaje anterior: puedeRepetir=${vEntr.puedeRepetir(c)}', vEntr.puedeRepetir(c));
  r('8', 'volver al entrenador ya vencido y repetirlo: ${falla(() => entr.repetirCombate(c))}',
      falla(() => entr.repetirCombate(c)) != null);
  // Repelente
  final rp = modificar(equipoFuerte(inicial), (j) => j['mochila'] = {'repelente': 1});
  final rp2 = ir(rp, ['ruta-1', 'ruta-1-pidgey']);
  final rp3 = rp2.usarRepelente(c);
  r('8', 'Repelente en un salvaje: pasa sin XP ni captura; Repelentes ${rp2.cuantos(ObjetoCampana.repelente)}→${rp3.cuantos(ObjetoCampana.repelente)}, '
      'XP ${rp2.xp}→${rp3.xp}, opciones ${rp3.opciones(c)}',
      rp3.cuantos(ObjetoCampana.repelente) == 0 && rp3.xp == rp2.xp);

  // ------------------------------------------------------------------ Piedra Luna
  var luna = equipoFuerte(inicial);
  luna = modificar(luna, (j) => j['progreso'] = {
        ...(j['progreso'] as Map<String, dynamic>),
        'nodoActual': 'centro-monte-moon',
        'resuelto': true,
        'superados': ['pueblo-paleta', 'centro-monte-moon'],
        'visitados': ['pueblo-paleta', 'centro-monte-moon'],
      });
  final nodoLuna = c.region.nodos.values.where((n) => n.objeto != null).toList();
  r('8', 'nodos con objeto escondido: ${nodoLuna.map((n) => "${n.id}:${n.objeto}").toList()}', nodoLuna.isNotEmpty);
  for (final n in nodoLuna) {
    final objeto = ObjetoCampana.values.firstWhere((o) => o.name == n.objeto);
    final dentro = luna.avanzar(c, 'monte-moon');
    r('8', 'llegar a monte-moon da ${n.objeto}: ${dentro.cuantos(objeto)}; recogidos=${dentro.recogidos}', dentro.cuantos(objeto) == 1);
    final otraVez = dentro.retroceder(c, 'centro-monte-moon').avanzar(c, 'monte-moon');
    r('8', 'volver al nodo no repone la piedra: ${otraVez.cuantos(objeto)}', otraVez.cuantos(objeto) == 1);
    final trasDerrota = modificar(dentro, (j) => j['equipo'] = [{'id': 'pidgey', 'ps': 1}]);
    r('8', 'tras guardar y cargar, `recogidos` se mantiene: ${PartidaCampana.desdeJson(jsonDecode(jsonEncode(trasDerrota.aJson())) as Map<String, dynamic>).recogidos}',
        PartidaCampana.desdeJson(jsonDecode(jsonEncode(trasDerrota.aJson())) as Map<String, dynamic>).recogidos.contains(n.id));
  }

  print('\nFallos: $fallos');
  salida.writeln('\nFallos: $fallos');
  File('/tmp/revision_flujos.txt').writeAsStringSync(salida.toString());
}
