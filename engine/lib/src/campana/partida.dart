import '../errores.dart';
import 'catalogo.dart';
import 'combate.dart';
import 'pokemon.dart';
import 'ruta.dart';

/// Cifras de la partida de campaña que todavía no están cerradas (D-20 §5 y
/// §8). Están todas aquí para cambiarlas en un solo sitio.
///
/// Decidido por Ayme el 2026-11-22: la XP se gana al derrotar Pokémon
/// (salvajes o de entrenador) y el dinero, al derrotar entrenadores; la tienda
/// del descanso vende, de salida, Poción, Pokéball y Repelente. **Las cifras son
/// provisionales.**
class ParametrosCampana {
  /// Puntos (de la cuenta) por vencer a un Pokémon salvaje.
  final int puntosSalvaje;

  /// Puntos por vencer a un entrenador.
  final int puntosEntrenador;

  /// Puntos por derrotar a un jefe (solo la primera vez, D-20 §4).
  final int puntosJefe;

  /// Puntos por ganar una medalla.
  final int puntosMedalla;

  /// XP por cada Pokémon rival derrotado. Se la llevan los Pokémon del equipo
  /// que siguen en pie al acabar el combate (suposición).
  final int xpPorPokemon;

  /// Dinero por vencer a un entrenador de zona y a un líder de gimnasio.
  final int dineroEntrenador;
  final int dineroLider;

  /// Dinero con el que se empieza la campaña (suposición).
  final int dineroInicial;

  /// Precio de cada objeto de la tienda.
  final Map<ObjetoCampana, int> precios;

  /// PS que cura una Poción.
  final int psPocion;

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
    this.xpPorPokemon = 10,
    this.dineroEntrenador = 200,
    this.dineroLider = 500,
    this.dineroInicial = 300,
    this.precios = const {
      ObjetoCampana.pocion: 100,
      ObjetoCampana.repelente: 150,
    },
    this.psPocion = 20,
    this.tamanoEquipo = 6,
    this.pokemonPorEntrenador = 2,
  });
}

/// Objetos de la tienda del descanso (D-20 §8, pregunta 3). La Pokéball
/// (probabilidad de capturar) todavía no está: hoy capturar siempre funciona.
enum ObjetoCampana {
  /// Cura [ParametrosCampana.psPocion] PS a un Pokémon en pie, fuera de
  /// combate. No cuenta como «sitio donde te curaste».
  pocion,

  /// Evita un combate contra un Pokémon salvaje: el nodo se da por pasado sin
  /// puntos, XP ni captura.
  repelente,
}

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
      ];
}

/// Un Pokémon del jugador: su especie, sus PS actuales (se conservan entre
/// combates hasta descansar) y su XP (D-20 §2.1).
class PokemonGuardado {
  final String id;
  final int ps;
  final int xp;

  const PokemonGuardado(this.id, this.ps, {this.xp = 0});

  factory PokemonGuardado.completo(PokemonCampana especie) =>
      PokemonGuardado(especie.id, especie.ps);

  bool get enPie => ps > 0;

  PokemonGuardado conPs(int nuevos) =>
      PokemonGuardado(id, nuevos < 0 ? 0 : nuevos, xp: xp);

  Map<String, dynamic> aJson() => {'id': id, 'ps': ps, 'xp': xp};

  factory PokemonGuardado.desdeJson(Map<String, dynamic> json) =>
      PokemonGuardado(json['id'] as String, json['ps'] as int,
          xp: (json['xp'] as int?) ?? 0);
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

  /// La llamada de aliado del jefe (D-20 §4, Jefes), o null.
  final LlamadaEnCombate? llamada;

  const RivalDelNodo({
    required this.equipo,
    required this.nombre,
    required this.captura,
    required this.puntos,
    this.dinero = 0,
    this.llamada,
  });
}

/// Una partida de la campaña de un jugador: dónde está, su equipo, su PC y sus
/// puntos. Es lo que se guarda en el dispositivo (D-20 §6). Inmutable: cada
/// operación devuelve una partida nueva.
class PartidaCampana {
  /// Versión del formato guardado.
  static const version = 1;

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

  /// Dinero, que se gana a entrenadores y se gasta en la tienda.
  final int dinero;

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
    this.derrotas = 0,
    this.dinero = 0,
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
    int? derrotas,
    int? dinero,
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
        derrotas: derrotas ?? this.derrotas,
        dinero: dinero ?? this.dinero,
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
            captura: especie.id,
            puntos: parametros.puntosSalvaje,
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
        return RivalDelNodo(
          equipo: [for (final id in elegidos) c.especie(id)],
          nombre: grupo.clase,
          captura: null,
          puntos: parametros.puntosEntrenador,
          dinero: parametros.dineroEntrenador,
        );
      case TipoNodo.gimnasio:
        final lider = nodo.lider!;
        return RivalDelNodo(
          equipo: [for (final id in lider.pokemon) c.especie(id)],
          nombre: lider.nombre,
          captura: null,
          puntos: parametros.puntosMedalla,
          dinero: parametros.dineroLider,
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
          llamada: llamadaEnCombate(jefe, c.pokemon),
        );
      case TipoNodo.inicio:
      case TipoNodo.bifurcacion:
      case TipoNodo.descanso:
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

  /// El combate del nodo actual, con los PS que trae el equipo.
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
    );
  }

  /// Aplica el final de un combate empezado con [empezarCombate].
  ///
  /// - Victoria: el equipo se queda con los PS del combate, el nodo se
  ///   resuelve (un gimnasio da su medalla), se suman puntos y dinero, los
  ///   Pokémon en pie ganan XP por cada rival derrotado y, si el rival se puede
  ///   capturar, queda como [capturaPendiente].
  /// - Derrota (decidido el 2026-11-22, D-20 §8 pregunta 1): se vuelve al
  ///   último sitio donde se curó el equipo ([ultimaCura]) con el equipo
  ///   curado. Se conserva lo ganado (capturas, puntos, dinero, medallas).
  ///
  /// En los dos casos avanza la semilla.
  PartidaCampana terminarCombate(CatalogoCampana c, EstadoCombate fin,
      {ParametrosCampana parametros = const ParametrosCampana()}) {
    if (fin.fase != FaseCombate.terminado) {
      throw const ReglaIncumplida('El combate no ha terminado.');
    }
    if (!hayCombate(c)) {
      throw const ReglaIncumplida('Aquí no hay ningún combate pendiente.');
    }
    final siguiente = _siguiente(semilla);
    if (fin.ganador != Bando.jugador) {
      return _copiar(
        progreso: progreso.volverA(c.region, ultimaCura ?? c.region.inicio),
        equipo: [for (final p in equipo) p.conPs(c.especie(p.id).ps)],
        semilla: siguiente,
        derrotas: derrotas + 1,
      );
    }
    final r = rival(c, parametros: parametros);
    final tras = fin.jugador.equipo;
    final derrotados = fin.rival.equipo.where((p) => !p.enPie).length;
    final xp = parametros.xpPorPokemon * derrotados;
    return _copiar(
      equipo: [
        for (var i = 0; i < equipo.length; i++)
          PokemonGuardado(equipo[i].id, tras[i].ps,
              xp: equipo[i].xp + (tras[i].enPie ? xp : 0)),
      ],
      progreso: progreso.resolver(c.region),
      puntos: puntos + r.puntos,
      dinero: dinero + r.dinero,
      semilla: siguiente,
      capturaPendiente: r.captura,
    );
  }

  /// Compra [cantidad] de [objeto] en un centro Pokémon.
  PartidaCampana comprar(CatalogoCampana c, ObjetoCampana objeto,
      {int cantidad = 1,
      ParametrosCampana parametros = const ParametrosCampana()}) {
    if (nodoActual(c).tipo != TipoNodo.descanso) {
      throw const ReglaIncumplida('La tienda está en los centros Pokémon.');
    }
    final precio = parametros.precios[objeto];
    if (precio == null) throw const ReglaIncumplida('Eso no se vende.');
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

  /// Captura el Pokémon pendiente, con todos sus PS. Si hay hueco se une al
  /// equipo; si no, con [sustituir] (índice del equipo) ese va al PC y el
  /// capturado ocupa su sitio, y sin [sustituir] el capturado va al PC. Nunca
  /// se pierde un Pokémon (D-20 §2).
  PartidaCampana capturar(CatalogoCampana c,
      {int? sustituir,
      ParametrosCampana parametros = const ParametrosCampana()}) {
    final id = capturaPendiente;
    if (id == null) throw const ReglaIncumplida('No hay nada que capturar.');
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

  /// Deja escapar al Pokémon pendiente sin capturarlo.
  PartidaCampana noCapturar() {
    if (capturaPendiente == null) {
      throw const ReglaIncumplida('No hay nada que capturar.');
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

  Map<String, dynamic> aJson() => {
        'version': version,
        'progreso': progreso.aJson(),
        'equipo': [for (final p in equipo) p.aJson()],
        'pc': [for (final p in pc) p.aJson()],
        'puntos': puntos,
        'semilla': semilla,
        if (capturaPendiente != null) 'capturaPendiente': capturaPendiente,
        'derrotas': derrotas,
        'dinero': dinero,
        'mochila': {for (final e in mochila.entries) e.key.name: e.value},
        if (ultimaCura != null) 'ultimaCura': ultimaCura,
      };

  factory PartidaCampana.desdeJson(Map<String, dynamic> json) {
    if (json['version'] != version) {
      throw FormatException(
          'Versión de partida de campaña desconocida: ${json['version']}.');
    }
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
      derrotas: (json['derrotas'] as int?) ?? 0,
      dinero: (json['dinero'] as int?) ?? 0,
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
