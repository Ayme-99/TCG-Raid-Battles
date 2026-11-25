import '../errores.dart';
import 'catalogo.dart';
import 'combate.dart';
import 'pokemon.dart';
import 'ruta.dart';

/// Cifras de la partida de campaña que todavía no están cerradas (D-20 §5 y
/// §8). Están todas aquí para cambiarlas en un solo sitio.
///
/// Decidido por Ayme el 2026-11-22: la XP se gana al derrotar Pokémon
/// (salvajes o de entrenador) y el dinero, al derrotar entrenadores. El dinero
/// de salida y los precios están decididos (D-20 §10.6); lo que paga cada
/// entrenador y cada líder está en el catálogo (`dinero`). **Los puntos son
/// provisionales.** La XP de cada rival no está aquí: la fija su categoría de
/// captura ([xpDeCategoria]) o el `xp` del jefe (D-20 §10.6).
class ParametrosCampana {
  /// Puntos (de la cuenta) por vencer a un Pokémon salvaje.
  final int puntosSalvaje;

  /// Puntos por vencer a un entrenador.
  final int puntosEntrenador;

  /// Puntos por derrotar a un jefe (solo la primera vez, D-20 §4).
  final int puntosJefe;

  /// Puntos por ganar una medalla.
  final int puntosMedalla;

  /// Dinero con el que se empieza la campaña: 1.000 (D-20 §10.6).
  final int dineroInicial;

  /// Precio de cada objeto de la tienda (D-20 §10.6, los de los juegos).
  final Map<ObjetoCampana, int> precios;

  /// Medallas que hacen falta para que la tienda venda un objeto: Super Ball
  /// con la 1.ª, Cuerda Huida con la 1.ª (tramo 2) y Ultra Ball con 5 (D-20
  /// §10.6). Los que no están, ninguna.
  final Map<ObjetoCampana, int> medallasParaComprar;

  /// PS que cura una Poción.
  final int psPocion;

  /// Piedras ex que da cada medalla nueva (D-20 §2.1, decidido el 2026-11-24:
  /// una por medalla, se entrega con ella y no caduca).
  final int piedrasExPorMedalla;

  /// Pokémon del equipo: 1 activo y 5 en la banca (D-20 §2).
  final int tamanoEquipo;

  /// Cuántos Pokémon de su lista saca un entrenador de zona. Suposición: D-20
  /// no lo dice.
  final int pokemonPorEntrenador;

  const ParametrosCampana({
    this.puntosSalvaje = 100,
    this.puntosEntrenador = 200,
    this.puntosJefe = 1000,
    this.puntosMedalla = 1500,
    this.dineroInicial = 1000,
    this.precios = const {
      ObjetoCampana.pokeball: 200,
      ObjetoCampana.superBall: 600,
      ObjetoCampana.ultraBall: 1200,
      ObjetoCampana.pocion: 300,
      ObjetoCampana.repelente: 350,
      // Decidido por Ayme el 2026-11-23 (D-20 §10.6, #437).
      ObjetoCampana.cuerdaHuida: 550,
      // Decidido por Ayme el 2026-11-24 (D-21 §2.5).
      ObjetoCampana.piedraEx: 2000,
    },
    this.medallasParaComprar = const {
      ObjetoCampana.superBall: 1,
      ObjetoCampana.ultraBall: 5,
      // Desde el tramo 2, junto a la Super Ball (Ayme, 2026-11-24).
      ObjetoCampana.cuerdaHuida: 1,
      // Desde la medalla del ex más barato (Básico ex, 2; Ayme, 2026-11-24).
      ObjetoCampana.piedraEx: 2,
    },
    this.psPocion = 20,
    this.piedrasExPorMedalla = 1,
    this.tamanoEquipo = 6,
    this.pokemonPorEntrenador = 2,
  });
}

/// Objetos de la tienda del centro Pokémon (D-20 §10.6). Lo que vende cada
/// centro está en su nodo (`tienda`). Las Balls se compran ya, pero capturar
/// con ellas llega con #368: hoy capturar siempre funciona.
enum ObjetoCampana {
  /// Pokéball, Super Ball y Ultra Ball: cada tirada de captura gasta una
  /// (#368).
  pokeball,
  superBall,
  ultraBall,

  /// Cura [ParametrosCampana.psPocion] PS a un Pokémon en pie, fuera de
  /// combate ([PartidaCampana.usarPocion]) o en combate ([UsarPocion], sin
  /// gastar turno; D-20 §3.2). No cuenta como «sitio donde te curaste».
  pocion,

  /// Evita un combate contra un Pokémon salvaje: el nodo se da por pasado sin
  /// puntos, XP ni captura.
  repelente,

  /// Cuerda Huida (D-20 §10.6, #437 y #468): solo en combate
  /// ([UsarCuerdaHuida]). Cambia el activo sin pagar la retirada, aunque esté
  /// Paralizado, y gasta el turno.
  cuerdaHuida,

  /// Piedra ex (D-20 §2.1, decidido el 2026-11-24): hace ex a un Pokémon en su
  /// última fase normal. Se apila y se gasta una por ex. En el catálogo, el
  /// objeto de evolución [idPiedraEx].
  piedraEx,
}

/// El objeto de la mochila que corresponde a un objeto de evolución del
/// catálogo (`"objeto"` de una evolución), o null si no se puede tener (la
/// Piedra Trueno aún no se obtiene, D-20 §10.11).
ObjetoCampana? objetoDeEvolucion(String id) =>
    id == idPiedraEx ? ObjetoCampana.piedraEx : null;

/// Todo lo que una partida de campaña necesita del catálogo: los Pokémon, las
/// zonas, los jefes y la región.
class CatalogoCampana {
  final Map<String, PokemonCampana> pokemon;
  final Map<String, ZonaCampana> zonas;
  final Map<String, JefeCampana> jefes;
  final RegionCampana region;

  const CatalogoCampana({
    required this.pokemon,
    required this.zonas,
    required this.jefes,
    required this.region,
  });

  /// A partir de los JSON del catálogo (`catalog/campana/`). [jefes] va por
  /// id, que es el nombre del archivo sin `.json`.
  factory CatalogoCampana.desdeJson({
    required List<Map<String, dynamic>> pokemon,
    required List<Map<String, dynamic>> zonas,
    required Map<String, Map<String, dynamic>> jefes,
    required Map<String, dynamic> region,
  }) {
    final p = {
      for (final j in pokemon) (j['id'] as String): pokemonCampanaDesdeJson(j),
    };
    final z = {
      for (final j in zonas) (j['id'] as String): zonaCampanaDesdeJson(j),
    };
    return CatalogoCampana(
      pokemon: p,
      zonas: z,
      jefes: {
        for (final e in jefes.entries) e.key: jefeCampanaDesdeJson(e.value),
      },
      region: regionCampanaDesdeJson(region),
    );
  }

  PokemonCampana especie(String id) {
    final p = pokemon[id];
    if (p == null) throw ReglaIncumplida('El Pokémon "$id" no existe.');
    return p;
  }

  /// Fase de [id] en su línea: 0 si es Básico, 1 si es Fase 1, 2 si es
  /// Fase 2. Se cuenta cuántos Pokémon del catálogo evolucionan en él por XP
  /// u objeto normal, sin contar la piedra ex.
  int fase(String id) {
    for (final p in pokemon.values) {
      for (final e in p.evoluciones) {
        if (e.a == id && !e.esPiedraEx && p.id != id) return fase(p.id) + 1;
      }
    }
    return 0;
  }

  /// Medallas mínimas para que [desde] se haga ex con [evolucion] (D-20
  /// §10.11): la mayor entre la de su ficha y la de [medallasMinimasEx] para
  /// su fase (propuesta A, por confirmar).
  int medallasParaEx(String desde, EvolucionCampana evolucion) {
    final f = fase(desde);
    final tabla = medallasMinimasEx[f.clamp(0, medallasMinimasEx.length - 1)];
    final ficha = evolucion.medallasMinimas ?? 0;
    return ficha > tabla ? ficha : tabla;
  }

  /// Lo que falta en el catálogo para jugar la región (vacía si está bien).
  List<String> problemas() => [
        ...region.problemas(),
        ...region.problemasDeCatalogo(
          pokemon: pokemon.keys.toSet(),
          jefes: jefes.keys.toSet(),
          salvajesPorZona: {
            for (final z in zonas.values) z.id: z.salvajes.toSet(),
          },
          entrenadoresPorZona: {
            for (final z in zonas.values)
              z.id: {
                for (final e in z.entrenadores) e.clase: e.pokemon.toSet()
              },
          },
        ),
        for (final z in zonas.values)
          for (final id in z.todosLosPokemon)
            if (!pokemon.containsKey(id)) 'zona ${z.id}: falta "$id".',
        for (final n in region.nodos.values) ...[
          for (final id in n.tienda)
            if (!ObjetoCampana.values.any((o) => o.name == id))
              '${n.id}: la tienda vende "$id", que no es un objeto.',
          // Lo que paga cada entrenador y cada líder (D-20 §10.6).
          if (n.lider != null && n.lider!.dinero == null)
            '${n.id}: el líder no tiene "dinero".',
          if (n.clase != null &&
              zonas[n.zona]
                      ?.entrenadores
                      .where((e) => e.clase == n.clase)
                      .firstOrNull
                      ?.dinero ==
                  null)
            '${n.id}: la clase "${n.clase}" no tiene "dinero" en su zona.',
        ],
        // Todo rival necesita categoría de captura: fija su XP (D-20 §10.6).
        for (final id in {
          for (final z in zonas.values) ...z.todosLosPokemon,
          for (final n in region.nodos.values) ...[
            ...n.pokemon,
            ...?n.lider?.pokemon,
          ],
        })
          if (pokemon[id] != null && pokemon[id]!.categoriaCaptura == null)
            'Pokémon "$id": es rival y no tiene categoriaCaptura.',
      ];
}

/// Un Pokémon del jugador: su especie y sus PS actuales (se conservan entre
/// combates hasta descansar). La XP no es de cada Pokémon: está en la reserva
/// común de la partida ([PartidaCampana.xp], D-20 §10.6).
class PokemonGuardado {
  final String id;
  final int ps;

  const PokemonGuardado(this.id, this.ps);

  factory PokemonGuardado.completo(PokemonCampana especie) =>
      PokemonGuardado(especie.id, especie.ps);

  bool get enPie => ps > 0;

  PokemonGuardado conPs(int nuevos) =>
      PokemonGuardado(id, nuevos < 0 ? 0 : nuevos);

  Map<String, dynamic> aJson() => {'id': id, 'ps': ps};

  factory PokemonGuardado.desdeJson(Map<String, dynamic> json) =>
      PokemonGuardado(json['id'] as String, json['ps'] as int);
}

/// Contra quién se combate en el nodo actual.
class RivalDelNodo {
  /// Los Pokémon del rival, en el orden en que salen.
  final List<PokemonCampana> equipo;

  /// Quién es, para mostrarlo: «Pidgey salvaje», «Cazabichos», «Brock»…
  final String nombre;

  /// Id del Pokémon que se puede capturar al ganar, o null (entrenadores,
  /// gimnasios y jefes ya capturados).
  final String? captura;

  /// Puntos que da ganar.
  final int puntos;

  /// Dinero que da ganar (solo entrenadores y líderes).
  final int dinero;

  /// Piedras ex que da ganar: las de la medalla de un gimnasio que aún no se
  /// tiene ([ParametrosCampana.piedrasExPorMedalla]).
  final int piedrasEx;

  /// XP que suma a la reserva ganar: la de cada Pokémon del [equipo] según su
  /// categoría de captura, o la del jefe. Un aliado del jefe que cae suma
  /// además la de su categoría ([terminarCombate]).
  final int xp;

  /// La llamada de aliado del jefe (D-20 §4, Jefes), o null.
  final LlamadaEnCombate? llamada;

  const RivalDelNodo({
    required this.equipo,
    required this.nombre,
    required this.captura,
    required this.puntos,
    this.dinero = 0,
    this.piedrasEx = 0,
    this.xp = 0,
    this.llamada,
  });
}

/// XP de derrotar a [equipo] (D-20 §10.6): la de la categoría de captura de
/// cada uno. Un Pokémon sin categoría no da XP (el catálogo lo avisa en
/// [CatalogoCampana.problemas]).
int _xpDeEquipo(List<PokemonCampana> equipo) => equipo.fold(
    0,
    (t, p) =>
        t +
        (p.categoriaCaptura == null ? 0 : xpDeCategoria(p.categoriaCaptura!)));

/// Una partida de la campaña de un jugador: dónde está, su equipo, su PC y sus
/// puntos. Es lo que se guarda en el dispositivo (D-20 §6). Inmutable: cada
/// operación devuelve una partida nueva.
class PartidaCampana {
  /// Versión del formato guardado. La 2 (#403) pasa la XP de cada Pokémon a
  /// la reserva común; una partida de la versión 1 se sigue leyendo y su
  /// reserva es la suma de la XP que llevaba cada Pokémon.
  static const version = 2;

  final ProgresoRuta progreso;

  /// Hasta [ParametrosCampana.tamanoEquipo] Pokémon; el primero sale activo.
  final List<PokemonGuardado> equipo;

  /// Los Pokémon que no caben en el equipo. Sin límite (D-20 §8, pregunta 7).
  final List<PokemonGuardado> pc;

  /// Puntos ganados en la campaña. Todavía no se envían al servidor.
  final int puntos;

  /// Semilla de la partida: elige el rival de cada combate y siembra las
  /// monedas. Avanza al terminar cada combate.
  final int semilla;

  /// Pokémon que se ofrece capturar tras ganar el combate, o null. Hasta
  /// capturarlo o dejarlo no se avanza.
  final String? capturaPendiente;

  /// Si ya ha salido cara con una Ball ([lanzarBall]) y solo falta decidir
  /// dónde va el capturado ([capturar]).
  final bool capturaLograda;

  /// Dinero, que se gana a entrenadores y se gasta en la tienda.
  final int dinero;

  /// Reserva común de XP (D-20 §10.6): la suman los rivales derrotados y se
  /// gasta al evolucionar. Sin tope.
  final int xp;

  /// Objetos de la mochila y cuántos hay de cada uno.
  final Map<ObjetoCampana, int> mochila;

  /// Último nodo donde se curó el equipo (el inicio o un centro Pokémon): al
  /// perder se vuelve aquí.
  final String? ultimaCura;

  /// Combates perdidos (solo informativo).
  final int derrotas;

  const PartidaCampana({
    required this.progreso,
    this.equipo = const [],
    this.pc = const [],
    this.puntos = 0,
    this.semilla = 1,
    this.capturaPendiente,
    this.capturaLograda = false,
    this.derrotas = 0,
    this.dinero = 0,
    this.xp = 0,
    this.mochila = const {},
    this.ultimaCura,
  });

  factory PartidaCampana.nueva(RegionCampana region,
          {int semilla = 1,
          ParametrosCampana parametros = const ParametrosCampana()}) =>
      PartidaCampana(
        progreso: ProgresoRuta.inicial(region),
        semilla: _normalizar(semilla),
        dinero: parametros.dineroInicial,
      );

  int cuantos(ObjetoCampana o) => mochila[o] ?? 0;

  PartidaCampana _copiar({
    ProgresoRuta? progreso,
    List<PokemonGuardado>? equipo,
    List<PokemonGuardado>? pc,
    int? puntos,
    int? semilla,
    String? capturaPendiente,
    bool limpiarCaptura = false,
    bool? capturaLograda,
    int? derrotas,
    int? dinero,
    int? xp,
    Map<ObjetoCampana, int>? mochila,
    String? ultimaCura,
  }) =>
      PartidaCampana(
        progreso: progreso ?? this.progreso,
        equipo: equipo ?? this.equipo,
        pc: pc ?? this.pc,
        puntos: puntos ?? this.puntos,
        semilla: semilla ?? this.semilla,
        capturaPendiente:
            limpiarCaptura ? null : (capturaPendiente ?? this.capturaPendiente),
        capturaLograda:
            limpiarCaptura ? false : (capturaLograda ?? this.capturaLograda),
        derrotas: derrotas ?? this.derrotas,
        dinero: dinero ?? this.dinero,
        xp: xp ?? this.xp,
        mochila: mochila ?? this.mochila,
        ultimaCura: ultimaCura ?? this.ultimaCura,
      );

  NodoRuta nodoActual(CatalogoCampana c) => c.region.nodo(progreso.nodoActual);

  bool terminada(CatalogoCampana c) =>
      progreso.terminado(c.region) && capturaPendiente == null;

  /// A dónde se puede ir: nada mientras haya una captura pendiente.
  List<String> opciones(CatalogoCampana c) =>
      capturaPendiente == null ? progreso.opciones(c.region) : const [];

  /// Si el nodo actual es un combate (de zona, gimnasio o jefe) sin resolver.
  bool hayCombate(CatalogoCampana c) {
    if (progreso.resuelto) return false;
    final t = nodoActual(c).tipo;
    return t == TipoNodo.combate ||
        t == TipoNodo.gimnasio ||
        t == TipoNodo.jefe;
  }

  /// En el inicio: elige el Pokémon inicial, que entra al equipo.
  PartidaCampana elegirInicial(CatalogoCampana c, String id) {
    final progreso = this.progreso.resolver(c.region, inicial: id);
    return _copiar(
        progreso: progreso,
        equipo: [PokemonGuardado.completo(c.especie(id))],
        ultimaCura: c.region.inicio);
  }

  /// Ir a [destino], una salida del nodo actual.
  PartidaCampana avanzar(CatalogoCampana c, String destino) {
    if (capturaPendiente != null) {
      throw const ReglaIncumplida('Antes hay que decidir la captura.');
    }
    return _copiar(progreso: progreso.avanzar(c.region, destino));
  }

  /// Vuelve a [destino], un nodo en el que ya se ha estado (D-20 §10.7).
  PartidaCampana retroceder(CatalogoCampana c, String destino) {
    if (capturaPendiente != null) {
      throw const ReglaIncumplida('Antes hay que decidir la captura.');
    }
    return _copiar(progreso: progreso.retroceder(c.region, destino));
  }

  /// Si se puede repetir el combate del nodo actual: un salvaje ya vencido.
  bool puedeRepetir(CatalogoCampana c) =>
      capturaPendiente == null && progreso.puedeRepetir(c.region);

  /// Vuelve a combatir contra un salvaje ya vencido (D-20 §10.7): da XP a la
  /// reserva y se puede capturar, pero no da puntos ni dinero. El rival sale
  /// de nuevo de la zona con la semilla, que ya ha avanzado.
  PartidaCampana repetirCombate(CatalogoCampana c) {
    if (capturaPendiente != null) {
      throw const ReglaIncumplida('Antes hay que decidir la captura.');
    }
    return _copiar(progreso: progreso.repetir(c.region));
  }

  /// El rival del nodo actual. Con la misma partida sale siempre el mismo.
  ///
  /// - Salvaje: el que fija el nodo o, si no, uno al azar de los salvajes de la
  ///   zona; se puede capturar.
  /// - Entrenador: el equipo que fija el nodo o, si no,
  ///   [ParametrosCampana.pokemonPorEntrenador] de su lista, al azar y sin
  ///   repetir; no se capturan.
  /// - Gimnasio: los Pokémon del líder, en orden.
  /// - Jefe: su carta NN/20 con su llamada de aliado, si la tiene. Al derrotarlo
  ///   la primera vez se ofrece su carta normal (los aliados no se capturan).
  RivalDelNodo rival(CatalogoCampana c,
      {ParametrosCampana parametros = const ParametrosCampana()}) {
    final nodo = nodoActual(c);
    switch (nodo.tipo) {
      case TipoNodo.combate:
        final zona = c.zonas[nodo.zona];
        if (zona == null)
          throw ReglaIncumplida('La zona "${nodo.zona}" no existe.');
        var s = semilla;
        int azar(int n) {
          s = _siguiente(s);
          return s % n;
        }

        if (nodo.rival == RivalDeCombate.salvaje) {
          final especie = c.especie(nodo.pokemon.isNotEmpty
              ? nodo.pokemon.first
              : zona.salvajes[azar(zona.salvajes.length)]);
          return RivalDelNodo(
            equipo: [especie],
            nombre: '${especie.nombre} salvaje',
            captura: zona.permiteCaptura ? especie.id : null,
            // Repetir un salvaje no da puntos (se dan una vez por combate).
            puntos: progreso.repitiendo ? 0 : parametros.puntosSalvaje,
            xp: _xpDeEquipo([especie]),
          );
        }
        final grupo = zona.entrenadores.firstWhere((e) => e.clase == nodo.clase,
            orElse: () => throw ReglaIncumplida(
                'La zona "${zona.id}" no tiene "${nodo.clase}".'));
        // El nodo puede fijar el equipo; si no, salen de la lista de su clase.
        final lista = [...grupo.pokemon];
        final elegidos = <String>[...nodo.pokemon];
        while (nodo.pokemon.isEmpty &&
            elegidos.length < parametros.pokemonPorEntrenador &&
            lista.isNotEmpty) {
          elegidos.add(lista.removeAt(azar(lista.length)));
        }
        final equipoRival = [for (final id in elegidos) c.especie(id)];
        return RivalDelNodo(
          equipo: equipoRival,
          nombre: grupo.clase,
          captura: null,
          puntos: parametros.puntosEntrenador,
          dinero: grupo.dinero ?? 0,
          xp: _xpDeEquipo(equipoRival),
        );
      case TipoNodo.gimnasio:
        final lider = nodo.lider!;
        final equipoLider = [for (final id in lider.pokemon) c.especie(id)];
        return RivalDelNodo(
          equipo: equipoLider,
          nombre: lider.nombre,
          captura: null,
          puntos: parametros.puntosMedalla,
          dinero: lider.dinero ?? 0,
          piedrasEx: progreso.medallas.contains(nodo.medalla)
              ? 0
              : parametros.piedrasExPorMedalla,
          xp: _xpDeEquipo(equipoLider),
        );
      case TipoNodo.jefe:
        final jefe = c.jefes[nodo.jefe];
        if (jefe == null)
          throw ReglaIncumplida('El jefe "${nodo.jefe}" no existe.');
        final primera = progreso.puedeCapturarJefe(nodo.jefe!);
        return RivalDelNodo(
          equipo: [jefe.pokemon],
          nombre: '${jefe.pokemon.nombre} (jefe '
              '${jefe.numero.toString().padLeft(2, '0')}/$totalJefesCampana)',
          captura: primera ? cartaNormalDeJefe(c, nodo.jefe!) : null,
          puntos: primera ? parametros.puntosJefe : 0,
          xp: jefe.xp,
          llamada: llamadaEnCombate(jefe, c.pokemon),
        );
      case TipoNodo.inicio:
      case TipoNodo.bifurcacion:
      case TipoNodo.descanso:
      case TipoNodo.conversacion:
        throw const ReglaIncumplida('En este nodo no hay combate.');
    }
  }

  /// La carta normal que se captura al derrotar a un jefe: la del catálogo con
  /// el mismo id sin «-jefe» (`pikachu-jefe` → `pikachu`), o null si no hay.
  static String? cartaNormalDeJefe(CatalogoCampana c, String jefe) {
    final id = jefe.endsWith('-jefe')
        ? jefe.substring(0, jefe.length - '-jefe'.length)
        : jefe;
    return c.pokemon.containsKey(id) ? id : null;
  }

  /// El combate del nodo actual, con los PS que trae el equipo y las
  /// Pociones de la mochila (se usan en combate sin gastar turno, D-20 §3.2).
  EstadoCombate empezarCombate(CatalogoCampana c,
      {ParametrosCampana parametros = const ParametrosCampana()}) {
    if (!hayCombate(c)) {
      throw const ReglaIncumplida('Aquí no hay ningún combate pendiente.');
    }
    final r = rival(c, parametros: parametros);
    return EstadoCombate.conEquipos(
      equipoJugador: [
        for (final p in equipo) PokemonEnCombate(c.especie(p.id), p.ps),
      ],
      equipoRival: [for (final p in r.equipo) PokemonEnCombate.completo(p)],
      semilla: _siguiente(_siguiente(semilla)),
      llamadaRival: r.llamada,
      parametros: ParametrosCombate(psPocion: parametros.psPocion),
      pocionesJugador: cuantos(ObjetoCampana.pocion),
      cuerdasJugador: cuantos(ObjetoCampana.cuerdaHuida),
    );
  }

  /// Aplica el final de un combate empezado con [empezarCombate].
  ///
  /// - Victoria: el equipo se queda con los PS del combate, el nodo se
  ///   resuelve (un gimnasio da su medalla), se suman puntos y dinero, la XP
  ///   del rival ([RivalDelNodo.xp], más la de los aliados del jefe que hayan
  ///   caído) va a la reserva común y, si el rival se puede capturar, queda
  ///   como [capturaPendiente].
  /// - Derrota (decidido el 2026-11-22, D-20 §8 pregunta 1): se vuelve al
  ///   último sitio donde se curó el equipo ([ultimaCura]) con el equipo
  ///   curado. Se conserva lo ganado (capturas, puntos, dinero, XP, medallas);
  ///   el combate perdido no da XP.
  ///
  /// En los dos casos avanza la semilla y se restan de la mochila las Pociones
  /// y las Cuerdas Huida usadas en el combate ([BandoCombate.pocionesUsadas],
  /// [BandoCombate.cuerdasUsadas]).
  PartidaCampana terminarCombate(CatalogoCampana c, EstadoCombate fin,
      {ParametrosCampana parametros = const ParametrosCampana()}) {
    if (fin.fase != FaseCombate.terminado) {
      throw const ReglaIncumplida('El combate no ha terminado.');
    }
    if (!hayCombate(c)) {
      throw const ReglaIncumplida('Aquí no hay ningún combate pendiente.');
    }
    final siguiente = _siguiente(semilla);
    final gastado = {
      ObjetoCampana.pocion: fin.jugador.pocionesUsadas,
      ObjetoCampana.cuerdaHuida: fin.jugador.cuerdasUsadas,
    }..removeWhere((_, n) => n == 0);
    final usadas = gastado.length;
    final mochilaTras = {
      ...mochila,
      for (final e in gastado.entries)
        e.key: cuantos(e.key) - e.value < 0 ? 0 : cuantos(e.key) - e.value,
    };
    if (fin.ganador != Bando.jugador) {
      return _copiar(
        progreso: progreso.volverA(c.region, ultimaCura ?? c.region.inicio),
        equipo: [for (final p in equipo) p.conPs(c.especie(p.id).ps)],
        semilla: siguiente,
        derrotas: derrotas + 1,
        mochila: usadas == 0 ? null : mochilaTras,
      );
    }
    final r = rival(c, parametros: parametros);
    final tras = fin.jugador.equipo;
    // Los aliados que llamó el jefe van detrás de su equipo; los que caen
    // cuentan como rivales derrotados (D-20 §4, Partida de campaña).
    final aliadosCaidos = [
      for (final a in fin.rival.equipo.skip(r.equipo.length))
        if (!a.enPie) a.especie,
    ];
    return _copiar(
      equipo: [
        for (var i = 0; i < equipo.length; i++)
          PokemonGuardado(equipo[i].id, tras[i].ps),
      ],
      progreso: progreso.resolver(c.region),
      puntos: puntos + r.puntos,
      dinero: dinero + r.dinero,
      xp: xp + r.xp + _xpDeEquipo(aliadosCaidos),
      mochila: r.piedrasEx == 0 && usadas == 0
          ? null
          : {
              ...mochilaTras,
              if (r.piedrasEx > 0)
                ObjetoCampana.piedraEx:
                    cuantos(ObjetoCampana.piedraEx) + r.piedrasEx,
            },
      semilla: siguiente,
      capturaPendiente: r.captura,
    );
  }

  /// Lo que vende la tienda del nodo actual, en el orden del catálogo: lo que
  /// lista el centro (`tienda`) y tiene precio, menos lo que pide más
  /// medallas de las que hay (D-20 §10.6). Vacía fuera de un centro.
  List<ObjetoCampana> tienda(CatalogoCampana c,
      {ParametrosCampana parametros = const ParametrosCampana()}) {
    final nodo = nodoActual(c);
    if (nodo.tipo != TipoNodo.descanso) return const [];
    return [
      for (final id in nodo.tienda)
        for (final o in ObjetoCampana.values)
          if (o.name == id &&
              parametros.precios.containsKey(o) &&
              progreso.medallas.length >=
                  (parametros.medallasParaComprar[o] ?? 0))
            o,
    ];
  }

  /// Compra [cantidad] de [objeto] en un centro Pokémon que lo venda.
  PartidaCampana comprar(CatalogoCampana c, ObjetoCampana objeto,
      {int cantidad = 1,
      ParametrosCampana parametros = const ParametrosCampana()}) {
    if (nodoActual(c).tipo != TipoNodo.descanso) {
      throw const ReglaIncumplida('La tienda está en los centros Pokémon.');
    }
    final precio = parametros.precios[objeto];
    final medallas = parametros.medallasParaComprar[objeto] ?? 0;
    if (precio != null &&
        nodoActual(c).tienda.contains(objeto.name) &&
        progreso.medallas.length < medallas) {
      throw ReglaIncumplida(
          'Se vende a partir de $medallas ${medallas == 1 ? 'medalla' : 'medallas'}.');
    }
    if (precio == null || !tienda(c, parametros: parametros).contains(objeto)) {
      throw const ReglaIncumplida('Eso no se vende aquí.');
    }
    if (cantidad < 1)
      throw const ReglaIncumplida('Hay que comprar al menos uno.');
    if (dinero < precio * cantidad) {
      throw const ReglaIncumplida('No tienes dinero suficiente.');
    }
    return _copiar(
      dinero: dinero - precio * cantidad,
      mochila: {...mochila, objeto: cuantos(objeto) + cantidad},
    );
  }

  /// Usa una Poción con el Pokémon [indice] del equipo, fuera de combate. No
  /// revive a uno fuera de combate ni pasa de sus PS máximos.
  PartidaCampana usarPocion(CatalogoCampana c, int indice,
      {ParametrosCampana parametros = const ParametrosCampana()}) {
    if (cuantos(ObjetoCampana.pocion) < 1) {
      throw const ReglaIncumplida('No te quedan Pociones.');
    }
    if (indice < 0 || indice >= equipo.length) {
      throw const ReglaIncumplida('Ese Pokémon no está en el equipo.');
    }
    final p = equipo[indice];
    final max = c.especie(p.id).ps;
    if (!p.enPie) {
      throw const ReglaIncumplida('Una Poción no revive a un Pokémon.');
    }
    if (p.ps >= max) throw const ReglaIncumplida('Ya tiene todos sus PS.');
    final ps = p.ps + parametros.psPocion;
    return _copiar(
      equipo: [...equipo]..[indice] = p.conPs(ps > max ? max : ps),
      mochila: {
        ...mochila,
        ObjetoCampana.pocion: cuantos(ObjetoCampana.pocion) - 1
      },
    );
  }

  /// Usa un Repelente en un combate contra un Pokémon salvaje: el nodo queda
  /// pasado sin combatir, sin puntos, XP ni captura.
  PartidaCampana usarRepelente(CatalogoCampana c) {
    if (cuantos(ObjetoCampana.repelente) < 1) {
      throw const ReglaIncumplida('No te quedan Repelentes.');
    }
    final nodo = nodoActual(c);
    if (!hayCombate(c) ||
        nodo.tipo != TipoNodo.combate ||
        nodo.rival != RivalDeCombate.salvaje) {
      throw const ReglaIncumplida('El Repelente solo evita Pokémon salvajes.');
    }
    return _copiar(
      progreso: progreso.resolver(c.region),
      mochila: {
        ...mochila,
        ObjetoCampana.repelente: cuantos(ObjetoCampana.repelente) - 1,
      },
    );
  }

  /// El equipo está lleno: capturar obliga a elegir a quién mandar al PC.
  bool equipoLleno(
          {ParametrosCampana parametros = const ParametrosCampana()}) =>
      equipo.length >= parametros.tamanoEquipo;

  /// Las Balls que hay en la mochila, de peor a mejor.
  List<ObjetoCampana> ballsEnMochila() => [
        for (final b in _balls)
          if (cuantos(b) > 0) b,
      ];

  static const _balls = [
    ObjetoCampana.pokeball,
    ObjetoCampana.superBall,
    ObjetoCampana.ultraBall,
  ];

  /// Categoría y si es segura la captura pendiente: la del jefe del nodo
  /// (si el nodo es un jefe) o la de la carta del salvaje.
  (CategoriaCaptura, bool) _capturaDelNodo(CatalogoCampana c) {
    final nodo = nodoActual(c);
    final jefe = nodo.tipo == TipoNodo.jefe ? c.jefes[nodo.jefe] : null;
    if (jefe != null) return (jefe.categoriaCaptura, jefe.capturaAsegurada);
    return (
      c.especie(capturaPendiente!).categoriaCaptura ?? CategoriaCaptura.comun,
      false
    );
  }

  /// Probabilidad, en tanto por mil, de capturar al pendiente con [ball].
  int probabilidadConBall(CatalogoCampana c, ObjetoCampana ball) {
    if (capturaPendiente == null) return 0;
    final (categoria, segura) = _capturaDelNodo(c);
    if (segura) return 1000;
    return probabilidadCaptura(categoria, _balls.indexOf(ball));
  }

  /// Lanza una [ball] al Pokémon pendiente (D-20 §10.6): gasta 1 Ball, salga
  /// lo que salga, y la moneda se tira con la semilla de la partida, que
  /// avanza. Con cara, [capturaLograda] y falta [capturar]; con cruz se puede
  /// volver a lanzar mientras queden Balls, sin tope.
  PartidaCampana lanzarBall(CatalogoCampana c, ObjetoCampana ball) {
    if (capturaPendiente == null) {
      throw const ReglaIncumplida('No hay nada que capturar.');
    }
    if (capturaLograda) throw const ReglaIncumplida('Ya está capturado.');
    if (!_balls.contains(ball)) {
      throw const ReglaIncumplida('Eso no es una Ball.');
    }
    if (cuantos(ball) < 1) {
      throw const ReglaIncumplida('No te quedan de esas.');
    }
    final s = _siguiente(semilla);
    final cara = s % 1000 < probabilidadConBall(c, ball);
    return _copiar(
      semilla: s,
      mochila: {...mochila, ball: cuantos(ball) - 1},
      capturaLograda: cara,
    );
  }

  /// Coloca el Pokémon ya capturado ([capturaLograda]), con todos sus PS. Si hay hueco se une al
  /// equipo; si no, con [sustituir] (índice del equipo) ese va al PC y el
  /// capturado ocupa su sitio, y sin [sustituir] el capturado va al PC. Nunca
  /// se pierde un Pokémon (D-20 §2).
  PartidaCampana capturar(CatalogoCampana c,
      {int? sustituir,
      ParametrosCampana parametros = const ParametrosCampana()}) {
    final id = capturaPendiente;
    if (id == null) throw const ReglaIncumplida('No hay nada que capturar.');
    if (!capturaLograda) {
      throw const ReglaIncumplida('Antes hay que lanzarle una Ball y acertar.');
    }
    final nuevo = PokemonGuardado.completo(c.especie(id));
    if (!equipoLleno(parametros: parametros)) {
      return _copiar(equipo: [...equipo, nuevo], limpiarCaptura: true);
    }
    if (sustituir == null) {
      return _copiar(pc: [...pc, nuevo], limpiarCaptura: true);
    }
    if (sustituir < 0 || sustituir >= equipo.length) {
      throw const ReglaIncumplida('Ese Pokémon no está en el equipo.');
    }
    final sale = equipo[sustituir];
    return _copiar(
      equipo: [...equipo]..[sustituir] = nuevo,
      pc: [...pc, sale],
      limpiarCaptura: true,
    );
  }

  /// Deja escapar al Pokémon pendiente sin capturarlo (también sin Balls).
  /// Un jefe que se deja ir ya no se puede capturar (D-20 §10.6).
  PartidaCampana noCapturar() {
    if (capturaPendiente == null) {
      throw const ReglaIncumplida('No hay nada que capturar.');
    }
    if (capturaLograda) {
      throw const ReglaIncumplida('Ya está capturado: elige dónde va.');
    }
    return _copiar(limpiarCaptura: true);
  }

  /// Pone primero (activo al empezar el combate) al Pokémon [indice] del
  /// equipo. Se puede hacer fuera de combate en cualquier momento.
  PartidaCampana ponerPrimero(int indice) {
    if (indice < 0 || indice >= equipo.length) {
      throw const ReglaIncumplida('Ese Pokémon no está en el equipo.');
    }
    final lista = [...equipo];
    final p = lista.removeAt(indice);
    return _copiar(equipo: [p, ...lista]);
  }

  /// En un centro Pokémon: cura a todo el equipo y al PC (D-20 §4) y pasa a
  /// ser el sitio al que se vuelve al perder. Se puede usar varias veces; la
  /// primera da el nodo por resuelto.
  PartidaCampana descansar(CatalogoCampana c) {
    if (nodoActual(c).tipo != TipoNodo.descanso) {
      throw const ReglaIncumplida('Aquí no hay un centro Pokémon.');
    }
    return _copiar(
      equipo: [for (final p in equipo) p.conPs(c.especie(p.id).ps)],
      pc: [for (final p in pc) p.conPs(c.especie(p.id).ps)],
      progreso: progreso.resuelto ? null : progreso.resolver(c.region),
      ultimaCura: progreso.nodoActual,
    );
  }

  /// En una conversación: el jugador escucha al personaje y sigue. Si el nodo
  /// cura, cura a todo el equipo y pasa a ser el sitio al que se vuelve al
  /// perder (D-20 §4, decidido el 2026-11-22). Da el nodo por resuelto.
  PartidaCampana conversar(CatalogoCampana c) {
    final nodo = nodoActual(c);
    if (nodo.tipo != TipoNodo.conversacion) {
      throw const ReglaIncumplida('Aquí no hay nadie con quien hablar.');
    }
    if (progreso.resuelto) {
      throw const ReglaIncumplida('Ya has hablado con este personaje.');
    }
    return _copiar(
      equipo: nodo.cura
          ? [for (final p in equipo) p.conPs(c.especie(p.id).ps)]
          : null,
      progreso: progreso.resolver(c.region),
      ultimaCura: nodo.cura ? progreso.nodoActual : null,
    );
  }

  /// En un centro Pokémon: cambia el Pokémon [deEquipo] del equipo por el
  /// [dePc] del PC. Con [deEquipo] null, saca del PC al equipo si hay hueco;
  /// con [dePc] null, deja en el PC al del equipo (si no es el último).
  PartidaCampana moverPc(CatalogoCampana c,
      {int? deEquipo,
      int? dePc,
      ParametrosCampana parametros = const ParametrosCampana()}) {
    if (nodoActual(c).tipo != TipoNodo.descanso) {
      throw const ReglaIncumplida('El PC solo se usa en un centro Pokémon.');
    }
    if (deEquipo != null && (deEquipo < 0 || deEquipo >= equipo.length)) {
      throw const ReglaIncumplida('Ese Pokémon no está en el equipo.');
    }
    if (dePc != null && (dePc < 0 || dePc >= pc.length)) {
      throw const ReglaIncumplida('Ese Pokémon no está en el PC.');
    }
    if (deEquipo != null && dePc != null) {
      final e = [...equipo];
      final p = [...pc];
      final sale = e[deEquipo];
      e[deEquipo] = p[dePc];
      p[dePc] = sale;
      return _copiar(equipo: e, pc: p);
    }
    if (dePc != null) {
      if (equipoLleno(parametros: parametros)) {
        throw const ReglaIncumplida('El equipo está lleno.');
      }
      final p = [...pc];
      final entra = p.removeAt(dePc);
      return _copiar(equipo: [...equipo, entra], pc: p);
    }
    if (deEquipo != null) {
      if (equipo.length <= 1) {
        throw const ReglaIncumplida('El equipo necesita al menos un Pokémon.');
      }
      final e = [...equipo];
      final sale = e.removeAt(deEquipo);
      return _copiar(equipo: e, pc: [...pc, sale]);
    }
    throw const ReglaIncumplida('No hay nada que mover.');
  }

  /// Las evoluciones por XP del Pokémon [indice] del equipo, con su coste.
  /// Puede haberlas aunque no llegue la reserva: [puedeEvolucionar] lo dice.
  List<EvolucionCampana> evolucionesPorXp(CatalogoCampana c, int indice) => [
        for (final e in evolucionesDe(c, indice))
          if (e.via == ViaEvolucion.xp) e,
      ];

  /// Todo lo que se ofrece en el menú del equipo para el Pokémon [indice]:
  /// evoluciones por XP y por objeto (la piedra ex incluida), cuyo Pokémon
  /// destino está en el catálogo. La de piedra ex lleva ya sus medallas
  /// mínimas: las de su ficha o, si son menos, las de [medallasMinimasEx]
  /// según la fase (D-20 §10.11, propuesta A). El intercambio no se ofrece
  /// aquí: va en la máquina de intercambio, que aún no existe.
  List<EvolucionCampana> evolucionesDe(CatalogoCampana c, int indice) {
    if (indice < 0 || indice >= equipo.length) return const [];
    final id = equipo[indice].id;
    return [
      for (final e in c.especie(id).evoluciones)
        if ((e.via == ViaEvolucion.xp || e.via == ViaEvolucion.objeto) &&
            c.pokemon.containsKey(e.a))
          e.esPiedraEx ? e.conMedallasMinimas(c.medallasParaEx(id, e)) : e,
    ];
  }

  /// Por qué no se puede hacer [evolucion] ahora, o null si se puede: faltan
  /// medallas (D-20 §10.11, #414), la reserva no llega (§10.6) o falta el
  /// objeto en la mochila (la piedra ex, §2.1).
  String? motivoSinEvolucion(EvolucionCampana evolucion) {
    if (evolucion.via == ViaEvolucion.intercambio) {
      return 'Se evoluciona por intercambio.';
    }
    final medallas = evolucion.medallasMinimas ?? 0;
    if (progreso.medallas.length < medallas) {
      return 'Requiere $medallas ${medallas == 1 ? 'medalla' : 'medallas'}.';
    }
    if (evolucion.via == ViaEvolucion.objeto) {
      final objeto = objetoDeEvolucion(evolucion.objeto!);
      if (objeto == null) return 'Aún no se puede conseguir ese objeto.';
      if (cuantos(objeto) < 1) {
        return objeto == ObjetoCampana.piedraEx
            ? 'No tienes ninguna piedra ex.'
            : 'No tienes el objeto.';
      }
      return null;
    }
    final coste = evolucion.xpEvolucion ?? 0;
    if (xp < coste) return 'Faltan ${coste - xp} XP.';
    return null;
  }

  /// Si [evolucion] se puede hacer ahora: hay medallas y XP (u objeto)
  /// suficientes.
  bool puedeEvolucionar(EvolucionCampana evolucion) =>
      motivoSinEvolucion(evolucion) == null;

  /// Evoluciona al Pokémon [indice] del equipo en [destino], si se tienen las
  /// medallas que pide (`medallasMinimas`, D-20 §10.11):
  ///
  /// - Por XP: gasta de la reserva la XP de esa evolución (§10.6).
  /// - Por objeto: gasta uno de la mochila. Hacerse ex gasta **una piedra ex**
  ///   y nada de XP (§2.1, decidido el 2026-11-24).
  ///
  /// Se hace fuera de combate, desde el menú del equipo, sin límite por
  /// visita. La carta evolucionada sustituye a la anterior y queda con
  /// **10 PS**, aunque tuviera más o estuviera debilitado (evolucionar revive
  /// a 10 PS).
  PartidaCampana evolucionar(CatalogoCampana c, int indice, String destino) {
    if (indice < 0 || indice >= equipo.length) {
      throw const ReglaIncumplida('Ese Pokémon no está en el equipo.');
    }
    final evolucion =
        evolucionesDe(c, indice).where((e) => e.a == destino).firstOrNull;
    if (evolucion == null) {
      throw ReglaIncumplida(
          '${c.especie(equipo[indice].id).nombre} no evoluciona en "$destino".');
    }
    final motivo = motivoSinEvolucion(evolucion);
    if (motivo != null) throw ReglaIncumplida(motivo);
    final nuevo = [...equipo]..[indice] =
        PokemonGuardado(destino, psAlEvolucionar);
    if (evolucion.via == ViaEvolucion.objeto) {
      final objeto = objetoDeEvolucion(evolucion.objeto!)!;
      return _copiar(
        equipo: nuevo,
        mochila: {...mochila, objeto: cuantos(objeto) - 1},
      );
    }
    return _copiar(equipo: nuevo, xp: xp - evolucion.xpEvolucion!);
  }

  /// PS con los que queda un Pokémon al evolucionar (D-20 §10.6).
  static const psAlEvolucionar = 10;

  Map<String, dynamic> aJson() => {
        'version': version,
        'progreso': progreso.aJson(),
        'equipo': [for (final p in equipo) p.aJson()],
        'pc': [for (final p in pc) p.aJson()],
        'puntos': puntos,
        'semilla': semilla,
        if (capturaPendiente != null) 'capturaPendiente': capturaPendiente,
        if (capturaLograda) 'capturaLograda': true,
        'derrotas': derrotas,
        'dinero': dinero,
        'xp': xp,
        'mochila': {for (final e in mochila.entries) e.key.name: e.value},
        if (ultimaCura != null) 'ultimaCura': ultimaCura,
      };

  factory PartidaCampana.desdeJson(Map<String, dynamic> json) {
    final v = json['version'];
    if (v != version && v != 1) {
      throw FormatException('Versión de partida de campaña desconocida: $v.');
    }
    // Versión 1: la XP iba por Pokémon; pasa entera a la reserva.
    final xpAntigua = v == 1
        ? [
            for (final clave in ['equipo', 'pc'])
              for (final p in json[clave] as List<dynamic>)
                ((p as Map<String, dynamic>)['xp'] as int?) ?? 0,
          ].fold(0, (a, b) => a + b)
        : 0;
    List<PokemonGuardado> lista(String clave) => [
          for (final p in json[clave] as List<dynamic>)
            PokemonGuardado.desdeJson(p as Map<String, dynamic>),
        ];
    return PartidaCampana(
      progreso:
          ProgresoRuta.desdeJson(json['progreso'] as Map<String, dynamic>),
      equipo: lista('equipo'),
      pc: lista('pc'),
      puntos: json['puntos'] as int,
      semilla: _normalizar(json['semilla'] as int),
      capturaPendiente: json['capturaPendiente'] as String?,
      capturaLograda: (json['capturaLograda'] as bool?) ?? false,
      derrotas: (json['derrotas'] as int?) ?? 0,
      dinero: (json['dinero'] as int?) ?? 0,
      xp: v == 1 ? xpAntigua : (json['xp'] as int?) ?? 0,
      mochila: {
        for (final e
            in ((json['mochila'] as Map<String, dynamic>?) ?? const {}).entries)
          ObjetoCampana.values.byName(e.key): e.value as int,
      },
      ultimaCura: json['ultimaCura'] as String?,
    );
  }

  /// Lo que no cuadra entre una partida guardada y el catálogo (vacía si se
  /// puede jugar): nodos o Pokémon que ya no existen.
  List<String> problemas(CatalogoCampana c) => [
        if (!c.region.nodos.containsKey(progreso.nodoActual))
          'El nodo "${progreso.nodoActual}" no existe.',
        for (final p in [...equipo, ...pc])
          if (!c.pokemon.containsKey(p.id)) 'El Pokémon "${p.id}" no existe.',
        if (capturaPendiente != null &&
            !c.pokemon.containsKey(capturaPendiente))
          'El Pokémon "$capturaPendiente" no existe.',
        if (ultimaCura != null && !c.region.nodos.containsKey(ultimaCura))
          'El nodo "$ultimaCura" no existe.',
        if (progreso.resuelto == false &&
            progreso.nodoActual != c.region.inicio &&
            equipo.isEmpty)
          'La partida no tiene equipo.',
      ];
}

const _modulo = 2147483647;

int _normalizar(int s) {
  final r = s % _modulo;
  return r <= 0 ? r + _modulo - 1 : r;
}

/// Park-Miller, como las monedas del combate (mismas cuentas en VM y web).
int _siguiente(int s) => (s * 16807) % _modulo;
