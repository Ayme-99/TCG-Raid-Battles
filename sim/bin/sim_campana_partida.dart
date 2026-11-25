// Simulador del primer tramo de campaña con las reglas reales de partida
// (#409): captura por probabilidad con Pokéball, dinero y tienda, reserva
// común de XP y evolución por medalla.
//
// A diferencia de `sim_campana.dart` (que juega combates sueltos y arrastra
// PS a mano), este juega con `PartidaCampana` del motor, así que lo que mide
// es el código real: `lanzarBall`, `comprar`, `terminarCombate`, `evolucionar`,
// `descansar`, `conversar`, `retroceder`, `repetirCombate` y la regla de
// derrota. No toca el motor, la app ni el catálogo.
//
// Uso (desde la carpeta sim/):
//   dart run bin/sim_campana_partida.dart --modo=tramo --partidas=3000
//   dart run bin/sim_campana_partida.dart --modo=techo
//
// Modos:
//   tramo   un jugador de «primera vuelta» (sin entrenar salvo lo que él elija)
//           recorre Pueblo Paleta → Brock, --partidas veces por inicial. Da,
//           por combate, cuántos llegan y cuántos ganan **a la primera**, y el
//           tramo entero sin perder ningún combate.
//   equipo  un equipo concreto (--equipo=a,b,c) contra un rival (--rival=x,y,
//           o `brock`, `joven`, `pikachu` con su llamada de aliado), con los
//           PS llenos; --traza muestra el primer combate turno a turno.
//   bolas   barrido de 0 a 5 Pokéballs compradas en Ciudad Verde (tramo).
//   techo   el mejor equipo posible antes de la 1.ª medalla contra Brock (y,
//           como referencia, contra el Entrenador Joven): busca entre todos
//           los equipos de hasta 6 Pokémon que se pueden tener entonces.
//
// Opciones del modo tramo:
//   --evolucion-inicial=si|no   el inicial evoluciona a 70 XP, 0 medallas
//                               (opcional, D-20 §10.6; ver --fase1)
//   --retroceder=si|no          curar volviendo al último centro visitado
//                               antes de cada combate (las reglas lo permiten
//                               y es gratis); «no» solo cura donde pasa la ruta
//   --balls=N|auto              Pokéballs que compra en Ciudad Verde (auto =
//                               todas las que paga el dinero: 5)
//   --pociones=N                Pociones que compra en Ciudad Verde (0)
//   --ruta1=si|no               volver a la Ruta 1 con Balls para capturar
//   --ruta22=si|no              pasar por el desvío opcional de la Ruta 22
//   --prioridad=inicial|bichos  en qué gasta primero la XP
//   --rotar=si|no               tras perder, sale con otra especie (si); no:
//                               repite siempre el mismo orden (no)
//   --tope-turnos=N             corta el combate al pasar de N turnos (0 = no)
//   --al-tope=derrota|mas-ps    qué pasa al llegar al tope: cuenta como derrota
//                               o gana quien tenga más PS en pie
//   --aliado=no                 Pikachu jefe sin su llamada de aliado
//   --entrenador=N              Pokémon que saca cada Cazabichos (2, el del
//                               motor; D-20 §4 lo da como suposición)
//
// Opciones comunes:
//   --catalogo=RUTA   carpeta del catálogo (../catalog/campana)
//   --energia-inicial/-maxima/-turno/-cargar=N   parámetros del combate
//                     (10, 10, 1, 1)
//   --partidas=N      recorridos (tramo, 3000) o semillas (techo, 4000)
//   --semilla=N       semilla del generador (1)
//   --fase1=si|no     (solo modo techo) compara también el equipo con la fase 1 del
//                     inicial; las cartas son las reales del catálogo de master (#455).
//   --informe=RUTA    CSV de salida
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:incursiones_engine/campana.dart';

// ---------------------------------------------------------------------------
// Configuración

class Config {
  String modo = 'tramo';
  String catalogo = '../catalog/campana';
  int partidas = -1;
  int semilla = 1;
  bool evolucionInicial = false;
  bool retroceder = true;
  String balls = 'auto';
  int pociones = 0;
  bool ruta1 = false;
  bool ruta22 = false;
  String prioridad = 'inicial';
  int entrenador = 2;
  bool fase1 = false;
  String? informe;
  String? solo; // limitar a un inicial
  bool detalle = false;
  bool rotar = true;
  List<String> equipo = [];
  List<String> rival = [];
  bool aliado = true;
  bool traza = false;
  bool pocionesCombate = false; // Pociones en combate (#435): sin gastar turno
  int umbralPocion = 50; // la IA cura al activo mientras tenga ≤ N PS
  String pocionesEn = 'todos'; // todos | brock
  // motor = la IA real (UsarPocion, #458/#465); simulador = la política antigua
  // del simulador (curar bajo --umbral-pocion PS), solo para comparar.
  String pocionPolitica = 'motor';
  int psPocion = 20; // PS que cura una Poción
  int precioPocion = 300;
  int limitePocionCombate = 0; // 0 = sin límite por combate
  int topeTurnos = 0; // 0 = sin tope (solo corta a las 2000 acciones)
  String alTope = 'derrota'; // derrota | mas-ps
}

/// Turnos de cada combate terminado (para medir su duración) y combates
/// cortados por el tope, por casilla.
final duraciones = <int>[];
final alTopePorNodo = <String, int>{};
int combatesTotales = 0;
int combatesAlTope = 0;
int alTopeGanaJugador = 0;

const iniciales = ['bulbasaur', 'charmander', 'squirtle'];
const fase1De = {
  'bulbasaur': 'ivysaur',
  'charmander': 'charmeleon',
  'squirtle': 'wartortle',
};

String pct(double x) => '${(x * 100).toStringAsFixed(1)} %';

// ---------------------------------------------------------------------------
// Catálogo en memoria

class Datos {
  Datos(this.catalogo);
  final CatalogoCampana catalogo;
}

Map<String, dynamic> _leer(File f) =>
    jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;

List<File> _jsons(String dir) => Directory(dir)
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.json'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

/// Carga el catálogo de master tal cual: los iniciales ya traen la evolución a
/// 70 XP y las cartas reales de Ivysaur, Charmeleon y Wartortle (#455).
CatalogoCampana cargarCatalogo(Config c) {
  final pokemon = <Map<String, dynamic>>[
    for (final f in _jsons('${c.catalogo}/pokemon')) _leer(f),
  ];
  final zonas = [for (final f in _jsons('${c.catalogo}/zonas')) _leer(f)];
  final jefes = {
    for (final f in _jsons('${c.catalogo}/jefes'))
      f.uri.pathSegments.last.replaceAll('.json', ''): _leer(f),
  };
  final region = _leer(File('${c.catalogo}/regiones/kanto.json'));
  return CatalogoCampana.desdeJson(
      pokemon: pokemon, zonas: zonas, jefes: jefes, region: region);
}

// ---------------------------------------------------------------------------
// Combate con la IA en los dos bandos

EstadoCombate hastaElFinal(EstadoCombate e, [int topeTurnos = 0]) {
  for (var i = 0; i < 2000 && e.fase != FaseCombate.terminado; i++) {
    if (topeTurnos > 0 && e.numeroTurno > topeTurnos) break;
    e = aplicarCombate(e, decidirAccion(e, e.actua));
  }
  return e;
}

/// Como [hastaElFinal], pero el jugador puede usar Pociones en combate (#435):
/// no gastan turno y no hay límite por combate, solo el inventario
/// ([disponibles]). La IA cura 20 PS al activo mientras le queden ≤ [umbral]
/// PS (el golpe fuerte de Brock es de 50), antes de cada acción propia.
(EstadoCombate, int) hastaElFinalConPociones(EstadoCombate e, int disponibles,
    int umbral, int psPocion, int limite, [int topeTurnos = 0]) {
  var usadas = 0;
  for (var i = 0; i < 2000 && e.fase != FaseCombate.terminado; i++) {
    if (topeTurnos > 0 && e.numeroTurno > topeTurnos) break;
    if (e.fase == FaseCombate.enCurso && e.actua == Bando.jugador) {
      while (usadas < disponibles &&
          (limite == 0 || usadas < limite)) {
        final b = e.jugador;
        final a = b.equipo[b.activo];
        if (!a.enPie || a.ps > umbral || a.ps >= a.especie.ps) break;
        final equipo = [...b.equipo];
        equipo[b.activo] = a.conPs(min(a.ps + psPocion, a.especie.ps));
        e = e.conBando(Bando.jugador, b.copiarCon(equipo: equipo));
        usadas++;
      }
    }
    e = aplicarCombate(e, decidirAccion(e, e.actua));
  }
  return (e, usadas);
}

/// Pone de activo al Pokémon que la IA sacaría contra [rival]: el mismo
/// criterio que usa al elegir relevo (no ser débil, más daño, más salud).
PartidaCampana conActivo(PartidaCampana p, CatalogoCampana c,
    ParametrosCampana pp, List<PokemonCampana> rival,
    {int variante = 0}) {
  final vivos = [
    for (var i = 0; i < p.equipo.length; i++)
      if (p.equipo[i].enPie) i
  ];
  if (vivos.isEmpty) return p;
  if (vivos.length == 1) return p.ponerPrimero(vivos.first);
  if (variante > 0) {
    // Reintento: el jugador prueba a salir con otra especie (por orden de
    // aparición en el equipo), como haría una persona tras perder.
    final vistos = <String>{};
    final distintos = [
      for (final i in vivos)
        if (vistos.add(p.equipo[i].id)) i
    ];
    return p.ponerPrimero(distintos[(variante - 1) % distintos.length]);
  }
  final lista = [
    for (final i in vivos) PokemonEnCombate(c.especie(p.equipo[i].id), p.equipo[i].ps)
  ];
  final base = EstadoCombate.inicial(
      equipoJugador: [lista.first.especie, for (final x in lista) x.especie],
      equipoRival: rival,
      parametros: const ParametrosCombate());
  final pregunta = base.copiarCon(
      jugador: base.jugador
          .copiarCon(equipo: [PokemonEnCombate(lista.first.especie, 0), ...lista]),
      fase: FaseCombate.eligiendoActivo);
  final accion = decidirAccion(pregunta, Bando.jugador) as ElegirSiguiente;
  return p.ponerPrimero(vivos[accion.indice - 1]);
}

// ---------------------------------------------------------------------------
// El jugador de «primera vuelta»

class Nodo {
  int llegan = 0; // veces que se llega al combate por primera vez
  int ganan = 0; // de esas, cuántas se ganan al primer intento
  int intentos = 0; // todos los intentos (incluidos los repetidos)
  int victorias = 0;
  int estancados = 0; // combates que no acaban (se cuentan como derrota)
}

/// El jugador se rinde en un combate (tras demasiados intentos perdidos).
class Rendido implements Exception {
  Rendido(this.nodo);
  final String nodo;
}

class Corrida {
  bool sinDerrotas = true;
  bool ganaBrock = false;
  int derrotas = 0;
  int intentosBrock = 0;
  int xpAlLlegarABrock = 0;
  int xpGastada = 0;
  int xpGanadaHastaBrock = 0;
  int xpTramoCompleto = 0;
  int ballsGastadas = 0;
  int capturas = 0;
  List<String> equipoEnBrock = [];
  bool evolucionoInicial = false;
  bool abortada = false;
  String? rendidoEn;
  int estancados = 0;
  int pocionesUsadas = 0;
  int pocionesEnBrock = 0;
}

class Jugador {
  Jugador(this.c, this.cfg, this.rnd, this.stats, this.balls);
  int usadasCombate = 0;
  final CatalogoCampana c;
  final Config cfg;
  final Random rnd;
  final Map<String, Nodo> stats;
  final int balls;
  late final ParametrosCampana params = ParametrosCampana(
      pokemonPorEntrenador: cfg.entrenador,
      psPocion: cfg.psPocion,
      precios: {
        ObjetoCampana.pokeball: 200,
        ObjetoCampana.superBall: 600,
        ObjetoCampana.ultraBall: 1200,
        ObjetoCampana.pocion: cfg.precioPocion,
        ObjetoCampana.repelente: 350,
      });
  final visto = <String>{};
  final corrida = Corrida();
  String inicial = '';

  
  // --- utilidades de equipo ------------------------------------------------

  bool hayHeridos(PartidaCampana p) => p.equipo
      .any((m) => c.especie(m.id).ps != m.ps);

  PartidaCampana usarPociones(PartidaCampana p) {
    var q = p;
    while (q.cuantos(ObjetoCampana.pocion) > 0) {
      // Poción al más herido en pie.
      var mejor = -1;
      var falta = 0;
      for (var i = 0; i < q.equipo.length; i++) {
        final m = q.equipo[i];
        final f = c.especie(m.id).ps - m.ps;
        if (m.enPie && f > falta) {
          falta = f;
          mejor = i;
        }
      }
      if (mejor < 0) break;
      q = q.usarPocion(c, mejor, parametros: params);
    }
    return q;
  }

  /// Gasta la XP de la reserva en evoluciones, por el orden de --prioridad.
  PartidaCampana evolucionar(PartidaCampana p) {
    var q = p;
    for (var vuelta = 0; vuelta < 12; vuelta++) {
      int? idx;
      String? destino;
      final orden = cfg.prioridad == 'bichos'
          ? [false, true] // primero los bichos
          : [true, false]; // primero el inicial
      for (final esInicial in orden) {
        for (var i = 0; i < q.equipo.length && idx == null; i++) {
          final id = q.equipo[i].id;
          if (iniciales.contains(id) != esInicial) continue;
          if (esInicial && !cfg.evolucionInicial) continue;
          for (final e in q.evolucionesPorXp(c, i)) {
            if (q.puedeEvolucionar(e)) {
              idx = i;
              destino = e.a;
              break;
            }
          }
        }
        if (idx != null) break;
      }
      if (idx == null) return q;
      if (iniciales.contains(q.equipo[idx].id)) corrida.evolucionoInicial = true;
      final xpAntes = q.xp;
      q = q.evolucionar(c, idx, destino!);
      corrida.xpGastada += xpAntes - q.xp;
    }
    return q;
  }

  // --- movimiento ------------------------------------------------------------

  /// Ir hacia delante hasta [destino] por la ruta más corta (por las salidas),
  /// resolviendo centros y conversaciones del camino.
  PartidaCampana avanzarHasta(PartidaCampana p, String destino) {
    var q = p;
    for (var paso = 0; paso < 40 && q.progreso.nodoActual != destino; paso++) {
      q = resolverNodo(q);
      // Anchura desde el nodo actual hasta destino.
      final desde = q.progreso.nodoActual;
      if (Platform.environment['TRAZA'] != null) {
        stderr.writeln('  [$desde → $destino] resuelto=${q.progreso.resuelto}');
      }
      final previo = <String, String>{};
      final cola = [desde];
      final vistos = {desde};
      while (cola.isNotEmpty && !previo.containsKey(destino)) {
        final id = cola.removeAt(0);
        for (final s in c.region.nodo(id).salidas) {
          if (vistos.add(s)) {
            previo[s] = id;
            cola.add(s);
          }
        }
      }
      if (!previo.containsKey(destino)) {
        throw StateError('No hay camino de $desde a $destino');
      }
      var siguiente = destino;
      while (previo[siguiente] != desde) {
        siguiente = previo[siguiente]!;
      }
      if (!q.progreso.resuelto) {
        throw StateError('Sin resolver en ${q.progreso.nodoActual} al ir a $destino '
            '(resuelto=${q.progreso.resuelto}, superados=${q.progreso.superados})');
      }
      q = q.avanzar(c, siguiente);
    }
    return q;
  }

  /// Si el nodo actual es un centro o una conversación sin resolver, lo
  /// resuelve (evoluciona antes para que curar deje a todos al máximo).
  PartidaCampana resolverNodo(PartidaCampana p) {
    final n = p.nodoActual(c);
    if (p.progreso.resuelto) return p;
    if (n.tipo == TipoNodo.descanso) {
      final d = p.descansar(c);
      return cfg.pocionesCombate && n.id == 'centro-plateada'
          ? comprarPocionesFaltan(d)
          : d;
    }
    if (n.tipo == TipoNodo.conversacion) {
      return p.conversar(c);
    }
    return p;
  }

  /// Compra en la tienda del centro las Pociones que faltan hasta
  /// `--pociones`, con el dinero que haya (300 cada una).
  PartidaCampana comprarPocionesFaltan(PartidaCampana q) {
    final falta = cfg.pociones - q.cuantos(ObjetoCampana.pocion);
    final n = min(falta, q.dinero ~/ cfg.precioPocion);
    return n > 0
        ? q.comprar(c, ObjetoCampana.pocion, cantidad: n, parametros: params)
        : q;
  }

  /// Último centro Pokémon visitado.
  String? ultimoCentro(PartidaCampana p) {
    String? mejor;
    for (final id in ['ciudad-verde', 'centro-plateada']) {
      if (p.progreso.visitados.contains(id)) mejor = id;
    }
    return mejor;
  }

  /// Vuelve al último centro, evoluciona, cura y regresa a [destino].
  PartidaCampana curarAndando(PartidaCampana p, String destino) {
    final centro = ultimoCentro(p);
    if (centro == null) return p;
    var q = p.progreso.nodoActual == centro ? p : p.retroceder(c, centro);
    q = evolucionar(q);
    q = q.descansar(c);
    if (cfg.pocionesCombate && centro == 'centro-plateada') {
      q = comprarPocionesFaltan(q);
    }
    if (q.progreso.nodoActual != destino) q = q.retroceder(c, destino);
    return q;
  }

  // --- combate ---------------------------------------------------------------

  /// Un intento de combate en el nodo actual. Devuelve la partida y si ganó.
  (PartidaCampana, bool) intento(PartidaCampana p, String nodo, int variante) {
    var q = p;
    if (cfg.retroceder && hayHeridos(q)) q = curarAndando(q, nodo);
    if (cfg.pociones > 0 && !cfg.pocionesCombate) q = usarPociones(q);
    final rival = q.rival(c, parametros: params).equipo;
    q = conActivo(q, c, params, rival,
        variante: cfg.rotar ? variante : 0);
    // Como `PartidaCampana.empezarCombate`, pero con los parámetros de energía
    // de las opciones --energia-* (el motor no los acepta ahí).
    final rv = q.rival(c, parametros: params);
    final inicio = EstadoCombate.conEquipos(
      equipoJugador: [
        for (final m in q.equipo) PokemonEnCombate(c.especie(m.id), m.ps),
      ],
      equipoRival: [for (final x in rv.equipo) PokemonEnCombate.completo(x)],
      parametros: parametrosCombate,
      semilla: _siguiente(_siguiente(q.semilla)),
      llamadaRival: cfg.aliado ? rv.llamada : null,
    );
    var fin;
    final conPociones = cfg.pocionesCombate &&
        (cfg.pocionesEn == 'todos' || nodo == 'gimnasio-brock');
    if (conPociones && cfg.pocionPolitica == 'motor') {
      // Motor real: la IA decide UsarPocion y el combate cuenta las gastadas.
      var disp = q.cuantos(ObjetoCampana.pocion) - usadasCombate;
      if (disp < 0) disp = 0;
      if (cfg.limitePocionCombate > 0 && disp > cfg.limitePocionCombate) {
        disp = cfg.limitePocionCombate;
      }
      fin = hastaElFinal(inicio.conBando(Bando.jugador,
          inicio.jugador.copiarCon(pociones: disp)), cfg.topeTurnos);
      final usadas = fin.jugador.pocionesUsadas as int;
      usadasCombate += usadas;
      corrida.pocionesUsadas += usadas;
      if (nodo == 'gimnasio-brock') corrida.pocionesEnBrock += usadas;
    } else if (conPociones) {
      final disp = q.cuantos(ObjetoCampana.pocion) - usadasCombate;
      final (f, usadas) = hastaElFinalConPociones(
          inicio, disp < 0 ? 0 : disp, cfg.umbralPocion, params.psPocion,
          cfg.limitePocionCombate, cfg.topeTurnos);
      fin = f;
      usadasCombate += usadas;
      corrida.pocionesUsadas += usadas;
      if (nodo == 'gimnasio-brock') corrida.pocionesEnBrock += usadas;
    } else {
      fin = hastaElFinal(inicio, cfg.topeTurnos);
    }
    combatesTotales++;
    if (fin.fase == FaseCombate.terminado) duraciones.add(fin.numeroTurno);
    if (fin.fase != FaseCombate.terminado && cfg.alTope == 'mas-ps') {
      // Regla propuesta: al llegar al tope gana quien tenga más PS en pie
      // (el rival gana los empates).
      int ps(BandoCombate b) => b.equipo.fold(0, (a, x) => a + x.ps);
      combatesAlTope++;
      alTopePorNodo.update(nodo, (v) => v + 1, ifAbsent: () => 1);
      final gj = ps(fin.jugador) > ps(fin.rival);
      if (gj) alTopeGanaJugador++;
      stats.putIfAbsent(nodo, Nodo.new).estancados++;
      fin = fin.copiarCon(
          fase: FaseCombate.terminado,
          ganador: gj ? Bando.jugador : Bando.rival);
    } else if (fin.fase != FaseCombate.terminado) {
      combatesAlTope++;
      alTopePorNodo.update(nodo, (v) => v + 1, ifAbsent: () => 1);
      // Tablas: ninguno puede hacer daño al otro (p. ej. Gruñido contra
      // Fortaleza). El motor no tiene tope de turnos; aquí cuenta como derrota
      // y se anota.
      corrida.estancados++;
      stats.putIfAbsent(nodo, Nodo.new).estancados++;
      fin = fin.copiarCon(fase: FaseCombate.terminado, ganador: Bando.rival);
    }
    final gana = fin.ganador == Bando.jugador;
    final r = q.terminarCombate(c, fin, parametros: params);
    return (r, gana);
  }

  /// Captura lo que haya pendiente: tira Pokéballs hasta cara o hasta quedar
  /// con [reserva] (las que se guardan para Pikachu).
  PartidaCampana capturar(PartidaCampana p, {int reserva = 0}) {
    var q = p;
    if (q.capturaPendiente == null) return q;
    final antes = q.cuantos(ObjetoCampana.pokeball);
    while (!q.capturaLograda &&
        q.cuantos(ObjetoCampana.pokeball) > reserva) {
      q = q.lanzarBall(c, ObjetoCampana.pokeball);
    }
    corrida.ballsGastadas += antes - q.cuantos(ObjetoCampana.pokeball);
    if (q.capturaLograda) {
      corrida.capturas++;
      return q.capturar(c, parametros: params);
    }
    return q.noCapturar();
  }

  /// Lucha en [nodo] hasta ganar (o rendirse). Registra estadísticas.
  PartidaCampana afrontar(PartidaCampana p, String nodo,
      {bool capturaSalvaje = true, bool repetir = false}) {
    var q = p;
    final primera = visto.add(nodo) && !repetir;
    final st = stats.putIfAbsent(nodo, Nodo.new);
    if (primera) st.llegan++;
    for (var k = 0; k < tope; k++) {
      if (q.progreso.nodoActual != nodo) q = q.retroceder(c, nodo);
      if (repetir && k == 0 && q.puedeRepetir(c)) q = q.repetirCombate(c);
      if (!q.hayCombate(c)) {
        // El nodo ya estaba resuelto (p. ej. tras volver): nada que pelear.
        return q;
      }
      final (r, gana) = intento(q, nodo, k);
      st.intentos++;
      if (gana) {
        st.victorias++;
        if (primera && k == 0) st.ganan++;
        return r;
      }
      corrida.sinDerrotas = false;
      corrida.derrotas++;
      q = r;
      if (nodo == 'gimnasio-brock') corrida.intentosBrock++;
    }
    corrida.abortada = true;
    corrida.rendidoEn = nodo;
    throw Rendido(nodo);
  }

  // --- el tramo ----------------------------------------------------------------

  PartidaCampana salvaje(PartidaCampana p, String nodo, {int reserva = 0}) {
    var q = avanzarHasta(p, nodo);
    q = afrontar(q, nodo);
    return capturar(q, reserva: reserva);
  }

  Corrida jugar(String ini, int semilla) {
    try {
      return _jugar(ini, semilla);
    } on Rendido {
      return corrida;
    }
  }

  Corrida _jugar(String ini, int semilla) {
    inicial = ini;
    var p = PartidaCampana.nueva(c.region, semilla: semilla, parametros: params);
    p = p.elegirInicial(c, ini);
    final ruta1 = rnd.nextBool() ? 'ruta-1-pidgey' : 'ruta-1-rattata';
    final ruta2 = rnd.nextBool() ? 'ruta-2-weedle' : 'ruta-2-caterpie';

    // Ruta 1: sin Pokéballs en la mochila de salida.
    p = avanzarHasta(p, ruta1);
    p = afrontar(p, ruta1);
    p = capturar(p); // 0 Balls: no se captura

    // Ciudad Verde: centro y primera tienda.
    p = avanzarHasta(p, 'ciudad-verde');
    p = evolucionar(p);
    p = p.descansar(c);
    final nBalls = min(balls, p.dinero ~/ 200);
    if (nBalls > 0) p = p.comprar(c, ObjetoCampana.pokeball, cantidad: nBalls, parametros: params);
    p = comprarPocionesFaltan(p);

    // Volver a la Ruta 1 a capturar (misma especie que ya se venció).
    if (cfg.ruta1 && p.cuantos(ObjetoCampana.pokeball) > 1) {
      p = p.retroceder(c, ruta1);
      p = afrontar(p, ruta1, repetir: true);
      p = capturar(p, reserva: 1);
      p = evolucionar(p);
      p = p.retroceder(c, 'ciudad-verde');
      p = p.descansar(c);
    }

    // Salida de Ciudad Verde: Ruta 22 (opcional) y Ruta 2.
    if (cfg.ruta22) {
      p = salvaje(p, 'ruta-22', reserva: 1);
    }
    p = salvaje(p, ruta2, reserva: 1);

    // Bosque Verde.
    p = avanzarHasta(p, 'cazabichos-1');
    p = afrontar(p, 'cazabichos-1');
    p = avanzarHasta(p, 'cazabichos-2');
    p = afrontar(p, 'cazabichos-2');
    p = avanzarHasta(p, 'aviso-pikachu');
    p = evolucionar(p);
    p = p.conversar(c);
    p = avanzarHasta(p, 'jefe-pikachu');
    p = afrontar(p, 'jefe-pikachu');
    p = capturar(p); // Pikachu: captura asegurada, gasta 1 Ball

    // Ciudad Plateada.
    p = avanzarHasta(p, 'centro-plateada');
    p = evolucionar(p);
    p = p.descansar(c);
    p = avanzarHasta(p, 'gimnasio-joven');
    p = afrontar(p, 'gimnasio-joven');
    p = avanzarHasta(p, 'gimnasio-brock');
    if (cfg.retroceder) p = curarAndando(p, 'gimnasio-brock');
    corrida.xpAlLlegarABrock = p.xp;
    corrida.xpGanadaHastaBrock = p.xp + corrida.xpGastada;
    corrida.equipoEnBrock = [for (final m in p.equipo) m.id];
    p = afrontar(p, 'gimnasio-brock');
    corrida.ganaBrock = p.progreso.medallas.contains('roca');
    corrida.xpTramoCompleto = p.xp + corrida.xpGastada;
    if (corrida.ganaBrock) corrida.intentosBrock++;
    return corrida;
  }
}

// ---------------------------------------------------------------------------
// Modo tramo

class ResumenTramo {
  final Map<String, Nodo> nodos = {};
  int recorridos = 0;
  int sinDerrotas = 0;
  int ganaBrock = 0;
  int abortadas = 0;
  final rendidos = <String, int>{};
  int derrotasTotal = 0;
  int intentosBrock = 0;
  int xpBrock = 0;
  int xpGanada = 0;
  int xpTramo = 0;
  int capturas = 0;
  int evolucionInicial = 0;
  int pocionesUsadas = 0;
  int pocionesEnBrock = 0;
  final composicion = <String, int>{};
}

ResumenTramo correr(Config cfg, CatalogoCampana c, String ini, int balls,
    int partidas, int semillaBase) {
  final rnd = Random(semillaBase);
  final r = ResumenTramo();
  for (var k = 0; k < partidas; k++) {
    final j = Jugador(c, cfg, rnd, r.nodos, balls);
    final co = j.jugar(ini, rnd.nextInt(1 << 30) + 1);
    r.recorridos++;
    if (co.sinDerrotas) r.sinDerrotas++;
    if (co.ganaBrock) r.ganaBrock++;
    if (co.abortada) {
      r.abortadas++;
      r.rendidos[co.rendidoEn!] = (r.rendidos[co.rendidoEn!] ?? 0) + 1;
    }
    r.derrotasTotal += co.derrotas;
    r.intentosBrock += co.intentosBrock;
    r.xpBrock += co.xpAlLlegarABrock;
    r.xpGanada += co.xpGanadaHastaBrock;
    r.xpTramo += co.xpTramoCompleto;
    r.capturas += co.capturas;
    r.pocionesUsadas += co.pocionesUsadas;
    r.pocionesEnBrock += co.pocionesEnBrock;
    if (co.evolucionoInicial) r.evolucionInicial++;
    final firma = (List.of(co.equipoEnBrock)..sort()).join('+');
    r.composicion[firma] = (r.composicion[firma] ?? 0) + 1;
  }
  return r;
}

const ordenNodos = [
  'ruta-1-pidgey',
  'ruta-1-rattata',
  'ruta-22',
  'ruta-2-weedle',
  'ruta-2-caterpie',
  'cazabichos-1',
  'cazabichos-2',
  'jefe-pikachu',
  'gimnasio-joven',
  'gimnasio-brock',
];

String etiqueta(String id, CatalogoCampana c) => c.region.nodo(id).nombre;

const tope = 80;

void tramo(Config cfg, CatalogoCampana c) {
  final partidas = cfg.partidas > 0 ? cfg.partidas : 3000;
  final lineas = [
    'inicial,balls,nodo,llegan,ganan_a_la_primera,intentos,victorias,recorridos,'
        'sin_derrotas,gana_brock'
  ];
  stdout.writeln('Tramo con las reglas reales de partida (#409): $partidas '
      'recorridos por inicial, semilla ${cfg.semilla}.');
  stdout.writeln('Evolución del inicial: ${cfg.evolucionInicial ? "sí (70 XP)" : "no"}'
      ''
      ' · curar volviendo al centro: ${cfg.retroceder ? "sí" : "no"}'
      ' · Ruta 1 con Balls: ${cfg.ruta1 ? "sí" : "no"}'
      ' · Ruta 22: ${cfg.ruta22 ? "sí" : "no"}'
      ' · Cazabichos con ${cfg.entrenador} · prioridad XP: ${cfg.prioridad}');
  stdout.writeln('');
  final resumen = <String, ResumenTramo>{};
  final eleccion = <String, int>{};
  for (final ini in iniciales) {
    if (cfg.solo != null && cfg.solo != ini) continue;
    // `auto`: la IA gasta todo el dinero de Ciudad Verde en Pokéballs (1.000
    // → 5). El barrido `--modo=bolas` comprueba que comprar menos no mejora.
    final balls = cfg.balls == 'auto' ? 5 : int.parse(cfg.balls);
    eleccion[ini] = balls;
    resumen[ini] = correr(cfg, c, ini, balls, partidas, cfg.semilla);
  }
  stdout.writeln('Pokéballs que compra la IA en Ciudad Verde: '
      '${[for (final e in eleccion.entries) "${e.key} ${e.value}"].join(", ")}');
  stdout.writeln('');
  stdout.writeln('Victorias a la primera por combate, entre los que llegan a él:');
  final cab = iniciales.where((i) => resumen.containsKey(i)).toList();
  stdout.writeln('${"Combate".padRight(34)}'
      '${[for (final i in cab) i.padLeft(24)].join()}');
  for (final id in ordenNodos) {
    if (!resumen.values.any((r) => r.nodos.containsKey(id))) continue;
    final celdas = <String>[];
    for (final i in cab) {
      final n = resumen[i]!.nodos[id];
      if (n == null || n.llegan == 0) {
        celdas.add('—'.padLeft(24));
        continue;
      }
      final llegan = n.llegan / resumen[i]!.recorridos;
      celdas.add('${pct(n.ganan / n.llegan)} (llegan ${(llegan * 100).toStringAsFixed(0)} %)'
          .padLeft(24));
      lineas.add('$i,${eleccion[i]},$id,${n.llegan},${n.ganan},${n.intentos},'
          '${n.victorias},${resumen[i]!.recorridos},${resumen[i]!.sinDerrotas},'
          '${resumen[i]!.ganaBrock}');
    }
    stdout.writeln('${etiqueta(id, c).padRight(34)}${celdas.join()}');
  }
  stdout.writeln('');
  stdout.writeln('${"Tramo entero".padRight(34)}');
  for (final i in cab) {
    final r = resumen[i]!;
    stdout.writeln('  ${i.padRight(11)} sin perder ningún combate: '
        '${pct(r.sinDerrotas / r.recorridos)} · acaba ganando a Brock '
        '(con reintentos): ${pct(r.ganaBrock / r.recorridos)} · derrotas por '
        'recorrido: ${(r.derrotasTotal / r.recorridos).toStringAsFixed(2)} · '
        'intentos contra Brock: ${(r.intentosBrock / r.recorridos).toStringAsFixed(2)}');
    stdout.writeln('              XP ganada hasta Brock: '
        '${(r.xpGanada / r.recorridos).toStringAsFixed(0)} (con Brock: '
        '${(r.xpTramo / r.recorridos).toStringAsFixed(0)}; sin gastar: '
        '${(r.xpBrock / r.recorridos).toStringAsFixed(0)}) · capturas: '
        '${(r.capturas / r.recorridos).toStringAsFixed(1)} · evolucionan al '
        'inicial: ${pct(r.evolucionInicial / r.recorridos)} · rendidos tras '
        '$tope intentos: ${r.abortadas}'
        '${r.rendidos.isEmpty ? "" : " (${r.rendidos.entries.map((e) => "${e.key} ${e.value}").join(", ")})"}');
    if (cfg.detalle) {
      final orden = r.composicion.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in orden.take(6)) {
        stdout.writeln('              ${pct(e.value / r.recorridos).padLeft(8)}  ${e.key}');
      }
    }
  }
  if (duraciones.isNotEmpty) {
    final d = [...duraciones]..sort();
    int q(double f) => d[((d.length - 1) * f).round()];
    stdout.writeln('');
    stdout.writeln('Duración de los combates terminados (turnos): mediana '
        '${q(0.5)} · p95 ${q(0.95)} · p99 ${q(0.99)} · máximo ${d.last}.');
    stdout.writeln('Combates jugados: $combatesTotales · cortados por el tope '
        '(${cfg.topeTurnos == 0 ? "sin tope: no acaban" : "${cfg.topeTurnos} turnos"}'
        '): $combatesAlTope (${pct(combatesAlTope / combatesTotales)})'
        '${cfg.alTope == "mas-ps" && combatesAlTope > 0 ? " · de ellos gana el jugador por PS: ${pct(alTopeGanaJugador / combatesAlTope)}" : ""}.');
    if (alTopePorNodo.isNotEmpty) {
      stdout.writeln('Por casilla: ${alTopePorNodo.entries.map((e) => "${e.key} ${e.value}").join(", ")}.');
    }
  }
  _escribir(cfg.informe ?? '../balance/informes/campana_partida_tramo.csv', lineas);
}

void barridoBolas(Config cfg, CatalogoCampana c) {
  final partidas = cfg.partidas > 0 ? cfg.partidas : 1000;
  stdout.writeln('Barrido de Pokéballs compradas en Ciudad Verde ($partidas '
      'recorridos por casilla; Ruta 1 con Balls: ${cfg.ruta1 ? "sí" : "no"}, '
      'Ruta 22: ${cfg.ruta22 ? "sí" : "no"}).');
  stdout.writeln('${"inicial".padRight(11)}${"Balls".padLeft(6)}${"Pikachu 1.º".padLeft(13)}'
      '${"Joven 1.º".padLeft(11)}${"Brock 1.º".padLeft(11)}${"tramo sin perder".padLeft(18)}'
      '${"gana Brock".padLeft(12)}');
  for (final ini in iniciales) {
    if (cfg.solo != null && cfg.solo != ini) continue;
    for (var b = 0; b <= 5; b++) {
      final r = correr(cfg, c, ini, b, partidas, cfg.semilla);
      String f(String id) {
        final n = r.nodos[id];
        return n == null || n.llegan == 0 ? '—' : pct(n.ganan / n.llegan);
      }
      stdout.writeln('${ini.padRight(11)}${"$b".padLeft(6)}'
          '${f("jefe-pikachu").padLeft(13)}${f("gimnasio-joven").padLeft(11)}'
          '${f("gimnasio-brock").padLeft(11)}'
          '${pct(r.sinDerrotas / r.recorridos).padLeft(18)}'
          '${pct(r.ganaBrock / r.recorridos).padLeft(12)}');
    }
  }
}

/// Park-Miller, la misma sucesión que usa `PartidaCampana` para sus semillas.
int _siguiente(int s) => (s * 16807) % 2147483647;

/// Brock con Pociones en combate (#435), repartiendo el dinero entre Pokéballs
/// y Pociones. Dinero antes de Brock: 1.000 en Ciudad Verde y 400 + 260 de los
/// Cazabichos y el Entrenador Joven (las Pociones que no caben en Ciudad Verde
/// se compran en el centro de Ciudad Plateada, antes de Brock).
void barridoPociones(Config cfg, CatalogoCampana c) {
  final partidas = cfg.partidas > 0 ? cfg.partidas : 600;
  cfg.pocionesCombate = true;
  final maxPocionesFijo = cfg.pociones;
  stdout.writeln('Brock con Pociones en combate: Poción ${cfg.umbralPocion == 50 ? "" : "(umbral ${cfg.umbralPocion}) "}'
      'cura ${const ParametrosCampana().psPocion} PS, sin gastar turno, '
      'en ${cfg.pocionesEn == "todos" ? "todos los combates" : "solo Brock"}. '
      '$partidas recorridos por casilla.');
  stdout.writeln('${"inicial".padRight(11)}${"Balls".padLeft(6)}${"Poc.".padLeft(5)}'
      '${"Pikachu 1.º".padLeft(13)}${"Joven 1.º".padLeft(11)}${"Brock 1.º".padLeft(11)}'
      '${"llegan".padLeft(8)}${"gana Brock".padLeft(12)}${"sin perder".padLeft(12)}${"Poc./partida".padLeft(14)}'
      '${"en Brock".padLeft(10)}');
  for (final ini in iniciales) {
    if (cfg.solo != null && cfg.solo != ini) continue;
    for (final b in cfg.balls == 'auto' ? [5, 4, 3, 2] : [int.parse(cfg.balls)]) {
      final maxP = maxPocionesFijo > 0
          ? maxPocionesFijo
          : (1660 - 200 * b) ~/ cfg.precioPocion;
      for (var pc = 0; pc <= maxP; pc++) {
        cfg.pociones = pc;
        final r = correr(cfg, c, ini, b, partidas, cfg.semilla);
        String f(String id) {
          final n = r.nodos[id];
          return n == null || n.llegan == 0 ? '—' : pct(n.ganan / n.llegan);
        }
        stdout.writeln('${ini.padRight(11)}${"$b".padLeft(6)}${"$pc".padLeft(5)}'
            '${f("jefe-pikachu").padLeft(13)}${f("gimnasio-joven").padLeft(11)}'
            '${f("gimnasio-brock").padLeft(11)}'
            '${pct((r.nodos["gimnasio-brock"]?.llegan ?? 0) / r.recorridos).padLeft(8)}'
            '${pct(r.ganaBrock / r.recorridos).padLeft(12)}'
            '${pct(r.sinDerrotas / r.recorridos).padLeft(12)}'
            '${(r.pocionesUsadas / r.recorridos).toStringAsFixed(2).padLeft(14)}'
            '${(r.pocionesEnBrock / r.recorridos).toStringAsFixed(2).padLeft(10)}');
      }
    }
  }
}

void _escribir(String ruta, List<String> lineas) {
  final f = File(ruta);
  f.parent.createSync(recursive: true);
  f.writeAsStringSync('${lineas.join('\n')}\n');
}

// ---------------------------------------------------------------------------
// Modo techo: el mejor equipo posible antes de la 1.ª medalla

class Candidato {
  Candidato(this.id, this.coste, [this.maxCopias = 6]);
  final String id;

  /// Pokéballs esperadas para tenerlo (1 / probabilidad de captura con
  /// Pokéball; Pikachu jefe, 1 y solo una vez; el inicial, 0; Metapod y Kakuna
  /// salen de evolucionar un Caterpie o Weedle capturado, con la XP que se
  /// quiera: la XP de los salvajes es ilimitada, D-20 §10.7).
  final double coste;
  final int maxCopias;
}

/// Dinero antes de Brock: 1.000 de salida + 400 de los Cazabichos + 260 del
/// Entrenador Joven, en Pokéballs de 200 (sin Pociones). Se puede gastar todo
/// porque se puede volver atrás a la tienda y a las rutas (D-20 §10.7).
const ballsDelTramo = 8;

LlamadaEnCombate? llamadaDe(CatalogoCampana c, String jefe) =>
    llamadaEnCombate(c.jefes[jefe]!, c.pokemon);

PokemonCampana especieDe(CatalogoCampana c, String id) =>
    c.pokemon[id] ?? c.jefes[id]!.pokemon;

/// Parámetros del combate para los modos `techo` y `equipo` (el modo `tramo`
/// usa los del motor: `PartidaCampana.empezarCombate` no los acepta).
ParametrosCombate parametrosCombate = const ParametrosCombate();

double _tasaConOrden(CatalogoCampana c, List<PokemonCampana> orden,
    List<PokemonCampana> ri, int semillas, int semilla0,
    LlamadaEnCombate? llamada) {
  var gana = 0;
  for (var s = 0; s < semillas; s++) {
    final fin = hastaElFinal(EstadoCombate.inicial(
        equipoJugador: orden,
        equipoRival: ri,
        parametros: parametrosCombate,
        semilla: semilla0 + s,
        llamadaRival: llamada));
    if (fin.ganador == Bando.jugador) gana++;
  }
  return gana / semillas;
}

/// Victorias contra [rival] de un equipo con los PS llenos, empezando el
/// jugador, con la IA en los dos bandos. Con [mejorSalida] el jugador prueba
/// cada especie del equipo como primer activo y se queda con la mejor (una
/// persona puede reintentar con otro orden); si no, sale el que la IA sacaría.
double tasa(CatalogoCampana c, List<String> equipo, List<String> rival,
    int semillas, int semilla0,
    {LlamadaEnCombate? llamada, bool mejorSalida = false}) {
  final eq = [for (final id in equipo) especieDe(c, id)];
  final ri = [for (final id in rival) especieDe(c, id)];
  if (mejorSalida) {
    var mejor = 0.0;
    final vistos = <String>{};
    for (var k = 0; k < eq.length; k++) {
      if (!vistos.add(eq[k].id)) continue;
      final orden = [eq[k], for (var i = 0; i < eq.length; i++) if (i != k) eq[i]];
      final t = _tasaConOrden(c, orden, ri, semillas, semilla0, llamada);
      if (t > mejor) mejor = t;
      if (mejor >= 1.0) break;
    }
    return mejor;
  }
  // Orden de salida: el que la IA sacaría primero.
  final base = EstadoCombate.inicial(
      equipoJugador: [eq.first, ...eq],
      equipoRival: ri,
      parametros: parametrosCombate);
  final pregunta = base.copiarCon(
      jugador: base.jugador.copiarCon(equipo: [
        PokemonEnCombate(eq.first, 0),
        for (final x in eq) PokemonEnCombate.completo(x)
      ]),
      fase: FaseCombate.eligiendoActivo);
  final accion = decidirAccion(pregunta, Bando.jugador) as ElegirSiguiente;
  final k = accion.indice - 1;
  final orden = [eq[k], for (var i = 0; i < eq.length; i++) if (i != k) eq[i]];
  return _tasaConOrden(c, orden, ri, semillas, semilla0, llamada);
}

/// Todos los multiconjuntos de [n] elementos de [pool] (con repetición).
Iterable<List<int>> multiconjuntos(int pool, int n, [int desde = 0]) sync* {
  if (n == 0) {
    yield const [];
    return;
  }
  for (var i = desde; i < pool; i++) {
    for (final resto in multiconjuntos(pool, n - 1, i)) {
      yield [i, ...resto];
    }
  }
}

class EquipoTecho {
  EquipoTecho(this.ids, this.coste, this.brock);
  final List<String> ids;
  final double coste;
  final double brock;
}

/// Mejor equipo de cada tamaño (1 a 6) contra [rival], entre los equipos que
/// se pueden tener antes de la 1.ª medalla. Gana la mayor tasa y, a igualdad,
/// el que cuesta menos Pokéballs.
List<EquipoTecho> mejoresPorTamano(CatalogoCampana c, String ini, bool conEvo,
    List<String> rival, int semillas, bool mejorSalida) {
  final candidatos = <Candidato>[
    Candidato(conEvo ? fase1De[ini]! : ini, 0, 1),
    Candidato('pidgey', 1 / 0.75),
    Candidato('rattata', 1 / 0.75),
    Candidato('caterpie', 1 / 0.75),
    Candidato('weedle', 1 / 0.75),
    Candidato('metapod', 1 / 0.75),
    Candidato('kakuna', 1 / 0.75),
    Candidato('spearow', 1 / 0.75),
    Candidato('nidoran-f', 1 / 0.75),
    Candidato('nidoran-m', 1 / 0.75),
    Candidato('mankey', 1 / 0.5),
    Candidato('pikachu', 1.0, 1),
  ];
  final salida = <EquipoTecho>[];
  for (var tam = 1; tam <= 6; tam++) {
    final etapa1 = <(double, double, List<int>)>[];
    for (final m in multiconjuntos(candidatos.length, tam)) {
      var valido = true;
      final cuenta = <int, int>{};
      for (final i in m) {
        cuenta[i] = (cuenta[i] ?? 0) + 1;
        if (cuenta[i]! > candidatos[i].maxCopias) valido = false;
      }
      if (!valido) continue;
      final coste = m.fold<double>(0, (a, i) => a + candidatos[i].coste);
      final t = tasa(c, [for (final i in m) candidatos[i].id], rival, 16, 1,
          mejorSalida: mejorSalida);
      etapa1.add((t, coste, m));
    }
    etapa1.sort((a, b) {
      final d = b.$1.compareTo(a.$1);
      return d != 0 ? d : a.$2.compareTo(b.$2);
    });
    // Se afinan los mejores y, aparte, los mejores que caben en el presupuesto.
    final elegidos = [
      ...etapa1.take(25),
      ...etapa1.where((e) => e.$2 <= ballsDelTramo).take(25),
    ];
    for (final e in elegidos) {
      final ids = [for (final i in e.$3) candidatos[i].id];
      salida.add(EquipoTecho(ids, e.$2,
          tasa(c, ids, rival, semillas, 1000, mejorSalida: mejorSalida)));
    }
  }
  return salida;
}

void techo(Config cfg, CatalogoCampana c) {
  final semillas = cfg.partidas > 0 ? cfg.partidas : 3000;
  final lineas = [
    'inicial,evolucion_inicial,tamano,equipo,balls_esperadas,cabe_en_8_balls,brock'
  ];
  final brock = c.region.nodo('gimnasio-brock').lider!.pokemon;
  stdout.writeln('Techo antes de Brock: el mejor equipo posible de cada tamaño, '
      'con los PS llenos (curar es gratis). $semillas semillas por equipo. '
      '${cfg.rotar ? "El jugador elige el mejor Pokémon para salir primero (reintentos)." : "Sale el Pokémon que la IA elegiría."}');
  stdout.writeln('Brock: ${brock.join(" + ")}. Disponibles antes de la 1.ª '
      'medalla: rutas 1, 2 y 22 (varias copias de un mismo Pokémon, se puede '
      'repetir el salvaje), Pikachu jefe (una sola vez), Metapod y Kakuna '
      '(evolucionando) y el inicial. Presupuesto: $ballsDelTramo Pokéballs '
      '(1.660 de dinero antes de Brock).');
  stdout.writeln('');
  final porInicial = cfg.solo != null ? [cfg.solo!] : iniciales;
  for (final ini in porInicial) {
    for (final conEvo in cfg.fase1 ? [false, true] : [false]) {
      final todos = mejoresPorTamano(c, ini, conEvo, brock, semillas, cfg.rotar);
      stdout.writeln('${ini.padRight(11)} ${conEvo ? "CON" : "SIN"} evolución del '
          'inicial${conEvo ? " (${fase1De[ini]})" : ""}:');
      stdout.writeln('   tamaño  Brock    Balls esp.  equipo');
      for (var tam = 1; tam <= 6; tam++) {
        final deTam = todos.where((e) => e.ids.length == tam).toList()
          ..sort((a, b) {
            final d = b.brock.compareTo(a.brock);
            return d != 0 ? d : a.coste.compareTo(b.coste);
          });
        final mejor = deTam.first;
        final cabe = deTam.where((e) => e.coste <= ballsDelTramo).toList();
        final mejorCabe = cabe.isEmpty ? null : cabe.first;
        stdout.writeln('   $tam       ${pct(mejor.brock).padLeft(7)}  '
            '${mejor.coste.toStringAsFixed(1).padLeft(6)}      ${mejor.ids.join("+")}');
        lineas.add('$ini,$conEvo,$tam,${mejor.ids.join("+")},'
            '${mejor.coste.toStringAsFixed(2)},${mejor.coste <= ballsDelTramo},'
            '${mejor.brock.toStringAsFixed(4)}');
        if (mejorCabe != null && !identical(mejorCabe, mejor)) {
          stdout.writeln('           ${pct(mejorCabe.brock).padLeft(7)}  '
              '${mejorCabe.coste.toStringAsFixed(1).padLeft(6)}      '
              '${mejorCabe.ids.join("+")}  (dentro del presupuesto)');
          lineas.add('$ini,$conEvo,$tam,${mejorCabe.ids.join("+")},'
              '${mejorCabe.coste.toStringAsFixed(2)},true,'
              '${mejorCabe.brock.toStringAsFixed(4)}');
        }
      }
      stdout.writeln('');
    }
  }
  _escribir(cfg.informe ?? '../balance/informes/campana_partida_techo.csv', lineas);
}

// ---------------------------------------------------------------------------
// Modo equipo: un equipo concreto contra un rival

void equipoContra(Config cfg, CatalogoCampana c) {
  final semillas = cfg.partidas > 0 ? cfg.partidas : 2000;
  var rival = cfg.rival;
  LlamadaEnCombate? llamada;
  if (rival.length == 1 && rival.first == 'brock') {
    rival = c.region.nodo('gimnasio-brock').lider!.pokemon;
  } else if (rival.length == 1 && rival.first == 'joven') {
    rival = c.region.nodo('gimnasio-joven').pokemon;
  } else if (rival.length == 1 && rival.first == 'pikachu') {
    final j = c.jefes['pikachu-jefe']!;
    rival = [j.pokemon.id];
    if (cfg.aliado) llamada = llamadaEnCombate(j, c.pokemon);
  }
  PokemonCampana esp(String id) =>
      c.pokemon[id] ?? c.jefes[id]!.pokemon;
  final eq = [for (final id in cfg.equipo) esp(id)];
  final ri = [for (final id in rival) esp(id)];
  var gana = 0;
  for (var s = 0; s < semillas; s++) {
    var e = EstadoCombate.inicial(
        equipoJugador: eq,
        equipoRival: ri,
        parametros: parametrosCombate,
        semilla: s + 1,
        llamadaRival: llamada);
    final traza = cfg.traza && s == 0;
    for (var i = 0; i < 2000 && e.fase != FaseCombate.terminado; i++) {
      final a = decidirAccion(e, e.actua);
      if (traza) {
        final b = e.bando(e.actua);
        final nombre = b.pokemonActivo.especie.nombre;
        final txt = switch (a) {
          Atacar x => 'ataca con ${b.pokemonActivo.especie.ataques[x.indice].nombre}',
          Cambiar x => 'cambia a ${b.equipo[x.indice].especie.nombre}',
          Cargar _ => 'carga',
          UsarPocion x => 'usa una Poción con ${b.equipo[x.indice].especie.nombre}',
          ElegirSiguiente x => 'saca a ${b.equipo[x.indice].especie.nombre}',
        };
        stdout.writeln('  t${e.numeroTurno} ${e.actua.name} $nombre '
            '(${b.pokemonActivo.ps} PS, energía ${b.energia}) $txt');
      }
      e = aplicarCombate(e, a);
    }
    if (e.ganador == Bando.jugador) gana++;
  }
  stdout.writeln('${cfg.equipo.join("+")} contra ${rival.join("+")}'
      '${llamada != null ? " (con aliado)" : ""}: '
      '${pct(gana / semillas)} ($semillas semillas, PS llenos)');
}

// ---------------------------------------------------------------------------

void main(List<String> args) {
  final cfg = Config();
  final energia = [10, 10, 1, 1];
  bool si(String v) => v == 'si' || v == 'sí' || v == 'true';
  for (final a in args) {
    final i = a.indexOf('=');
    final k = i < 0 ? a : a.substring(0, i);
    final v = i < 0 ? '' : a.substring(i + 1);
    switch (k) {
      case '--modo':
        cfg.modo = v;
      case '--catalogo':
        cfg.catalogo = v;
      case '--partidas':
        cfg.partidas = int.parse(v);
      case '--semilla':
        cfg.semilla = int.parse(v);
      case '--evolucion-inicial':
        cfg.evolucionInicial = si(v);
      case '--retroceder':
        cfg.retroceder = si(v);
      case '--balls':
        cfg.balls = v;
      case '--pociones':
        cfg.pociones = int.parse(v);
      case '--ruta1':
        cfg.ruta1 = si(v);
      case '--ruta22':
        cfg.ruta22 = si(v);
      case '--prioridad':
        cfg.prioridad = v;
      case '--entrenador':
        cfg.entrenador = int.parse(v);
      case '--fase1':
        cfg.fase1 = si(v);
      case '--informe':
        cfg.informe = v;
      case '--solo':
        cfg.solo = v;
      case '--detalle':
        cfg.detalle = true;
      case '--equipo':
        cfg.equipo = v.split(',');
      case '--rival':
        cfg.rival = v.split(',');
      case '--pociones-combate':
        cfg.pocionesCombate = v == 'si';
      case '--pocion-politica':
        cfg.pocionPolitica = v;
      case '--umbral-pocion':
        cfg.umbralPocion = int.parse(v);
      case '--pociones-en':
        cfg.pocionesEn = v;
      case '--ps-pocion':
        cfg.psPocion = int.parse(v);
      case '--precio-pocion':
        cfg.precioPocion = int.parse(v);
      case '--limite-pocion':
        cfg.limitePocionCombate = int.parse(v);
      case '--aliado':
        cfg.aliado = v != 'no';
      case '--tope-turnos':
        cfg.topeTurnos = int.parse(v);
      case '--al-tope':
        cfg.alTope = v;
      case '--traza':
        cfg.traza = true;
      case '--rotar':
        cfg.rotar = si(v);
      case '--energia-inicial':
        energia[0] = int.parse(v);
      case '--energia-maxima':
        energia[1] = int.parse(v);
      case '--energia-turno':
        energia[2] = int.parse(v);
      case '--energia-cargar':
        energia[3] = int.parse(v);
      default:
        stderr.writeln('Opción desconocida: $a');
        exit(2);
    }
  }
  if (cfg.evolucionInicial) cfg.fase1 = true;
  parametrosCombate = ParametrosCombate(
      energiaInicial: energia[0],
      energiaMaxima: energia[1],
      energiaPorTurno: energia[2],
      energiaAlCargar: energia[3],
      psPocion: cfg.psPocion);
  final c = cargarCatalogo(cfg);
  switch (cfg.modo) {
    case 'tramo':
      tramo(cfg, c);
    case 'techo':
      techo(cfg, c);
    case 'equipo':
      equipoContra(cfg, c);
    case 'bolas':
      barridoBolas(cfg, c);
    case 'pociones':
      barridoPociones(cfg, c);
    default:
      stderr.writeln('--modo: usa «tramo», «techo» o «equipo»');
      exit(2);
  }
}
