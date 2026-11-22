import '../errores.dart';

/// Qué ocurre en un nodo de la ruta (D-20 §4).
enum TipoNodo {
  /// Elegir un Pokémon inicial. Es el único nodo sin entradas.
  inicio,

  /// Combate contra un Pokémon salvaje o un entrenador de una zona.
  combate,

  /// Sin evento: solo hay que elegir por qué ruta seguir (dos salidas o más).
  bifurcacion,

  /// El centro Pokémon: curar, PC, evolucionar, comprar.
  descanso,

  /// Combate contra un líder; da una medalla.
  gimnasio,

  /// Un Pokémon salvaje de la serie NN/20.
  jefe,

  /// Sin combate: un personaje habla con el jugador (por ejemplo, le avisa de
  /// lo que viene) y, si el nodo lo dice, cura al equipo. Un nodo que cura es
  /// un punto de curación: al perder se vuelve a él (D-20 §4).
  conversacion,
}

/// Contra quién se combate en un nodo de combate.
enum RivalDeCombate { salvaje, entrenador }

/// El líder de un gimnasio: usa cartas normales del catálogo (D-20 §4, Jefes).
class LiderDeGimnasio {
  final String nombre;

  /// Ids de sus Pokémon, en el orden en que salen.
  final List<String> pokemon;

  const LiderDeGimnasio(this.nombre, this.pokemon);
}

/// Un nodo de la ruta. Los campos que no son de su [tipo] van vacíos.
class NodoRuta {
  final String id;
  final TipoNodo tipo;
  final String nombre;

  /// Ids de los nodos a los que se puede ir desde este. Vacía en el final de
  /// una región; con una bifurcación, dos o más; en el resto, exactamente una.
  final List<String> salidas;

  /// Un combate o un descanso que se puede saltar: queda fuera del camino
  /// principal y siempre hay otra forma de llegar al resto de la ruta.
  final bool opcional;

  /// Pokémon entre los que se elige (solo [TipoNodo.inicio]).
  final List<String> iniciales;

  /// Id de la zona de la que sale el rival (solo [TipoNodo.combate]).
  final String? zona;
  final RivalDeCombate? rival;

  /// Clase de entrenador de la zona (solo combate contra un entrenador).
  final String? clase;

  /// Los Pokémon fijos del rival (solo [TipoNodo.combate]): uno si es salvaje
  /// (por ejemplo, el nodo que ofrece Pidgey en la Ruta 1) y su equipo si es un
  /// entrenador. Vacía: el rival sale de la zona (o de la clase) al llegar.
  final List<String> pokemon;

  /// El líder y el id de la medalla (solo [TipoNodo.gimnasio]).
  final LiderDeGimnasio? lider;
  final String? medalla;

  /// Id del jefe en `catalog/campana/jefes/` (solo [TipoNodo.jefe]).
  final String? jefe;

  /// Quién habla y lo que dice, línea a línea (solo [TipoNodo.conversacion]).
  final String? personaje;
  final List<String> texto;

  /// Si la conversación cura al equipo (solo [TipoNodo.conversacion]).
  final bool cura;

  /// Si en este nodo se cura el equipo y pasa a ser el sitio al que se vuelve
  /// al perder: un descanso o una conversación que cura.
  bool get curaEquipo =>
      tipo == TipoNodo.descanso || (tipo == TipoNodo.conversacion && cura);

  const NodoRuta({
    required this.id,
    required this.tipo,
    required this.nombre,
    this.salidas = const [],
    this.opcional = false,
    this.iniciales = const [],
    this.zona,
    this.rival,
    this.clase,
    this.pokemon = const [],
    this.lider,
    this.medalla,
    this.jefe,
    this.personaje,
    this.texto = const [],
    this.cura = false,
  });
}

/// Una región de la campaña (Kanto): un grafo dirigido y sin ciclos de nodos
/// que se recorre de [inicio] hacia delante.
class RegionCampana {
  final String id;
  final String nombre;

  /// Id del nodo de inicio.
  final String inicio;
  final Map<String, NodoRuta> nodos;

  const RegionCampana({
    required this.id,
    required this.nombre,
    required this.inicio,
    required this.nodos,
  });

  NodoRuta nodo(String id) {
    final n = nodos[id];
    if (n == null) throw ReglaIncumplida('El nodo "$id" no existe.');
    return n;
  }

  /// Ids de los nodos que llevan a [id].
  List<String> entradas(String id) => [
        for (final n in nodos.values)
          if (n.salidas.contains(id)) n.id,
      ];

  /// Nodos en los que acaba la región: los que no tienen salidas.
  List<NodoRuta> get finales => [
        for (final n in nodos.values)
          if (n.salidas.isEmpty) n
      ];

  /// Lo que está mal en la estructura de la región (vacía si es válida):
  /// un solo inicio sin entradas, salidas que existen, el número de salidas de
  /// cada tipo, sin ciclos, todo alcanzable desde el inicio, todo lleva a un
  /// final que sea un gimnasio o un jefe, los datos de cada tipo, y que a todos
  /// los nodos obligatorios se llegue sin pasar por ninguno opcional.
  List<String> problemas() {
    final p = <String>[];
    final inicios = nodos.values.where((n) => n.tipo == TipoNodo.inicio);
    if (inicios.length != 1) {
      p.add('Tiene que haber un solo nodo de inicio (hay ${inicios.length}).');
    }
    if (nodos[inicio]?.tipo != TipoNodo.inicio) {
      p.add('"$inicio" no es un nodo de inicio.');
    }
    for (final n in nodos.values) {
      for (final s in n.salidas) {
        if (!nodos.containsKey(s)) p.add('${n.id}: la salida "$s" no existe.');
      }
      if (n.salidas.toSet().length != n.salidas.length) {
        p.add('${n.id}: tiene una salida repetida.');
      }
      if (n.salidas.contains(n.id)) p.add('${n.id}: lleva a sí mismo.');
      final previos = entradas(n.id);
      if (n.tipo == TipoNodo.inicio && previos.isNotEmpty) {
        p.add('${n.id}: el inicio no puede tener entradas.');
      }
      if (n.tipo != TipoNodo.inicio && previos.isEmpty) {
        p.add('${n.id}: no se llega a él desde ningún nodo.');
      }
      if (n.tipo == TipoNodo.bifurcacion) {
        if (n.salidas.length < 2) {
          p.add('${n.id}: una bifurcación necesita dos salidas o más.');
        }
      } else if (n.salidas.length > 1) {
        p.add('${n.id}: solo una bifurcación puede tener varias salidas.');
      }
      if (n.salidas.isEmpty &&
          n.tipo != TipoNodo.gimnasio &&
          n.tipo != TipoNodo.jefe) {
        p.add('${n.id}: una región solo acaba en un gimnasio o un jefe.');
      }
      if (n.opcional &&
          n.tipo != TipoNodo.combate &&
          n.tipo != TipoNodo.descanso) {
        p.add('${n.id}: solo un combate o un descanso puede ser opcional.');
      }
      p.addAll(_problemasDeDatos(n));
    }
    if (p.isNotEmpty) return p;

    // Sin ciclos: se ordenan los nodos quitando los que no tienen entradas.
    final pendientes = {
      for (final n in nodos.values) n.id: entradas(n.id).length,
    };
    final listos = [
      for (final e in pendientes.entries)
        if (e.value == 0) e.key
    ];
    var ordenados = 0;
    while (listos.isNotEmpty) {
      final id = listos.removeLast();
      ordenados++;
      for (final s in nodos[id]!.salidas) {
        pendientes[s] = pendientes[s]! - 1;
        if (pendientes[s] == 0) listos.add(s);
      }
    }
    if (ordenados != nodos.length) {
      return ['La ruta tiene un ciclo: solo se avanza hacia delante.'];
    }

    final alcanzables = _alcanzables(inicio, (_) => true);
    for (final n in nodos.values) {
      if (!alcanzables.contains(n.id)) {
        p.add('${n.id}: no se llega a él desde el inicio.');
      }
    }
    final sinOpcionales = _alcanzables(inicio, (n) => !n.opcional);
    for (final n in nodos.values) {
      if (!n.opcional && !sinOpcionales.contains(n.id)) {
        p.add('${n.id}: obliga a pasar por un nodo opcional.');
      }
    }
    return p;
  }

  Set<String> _alcanzables(String desde, bool Function(NodoRuta) vale) {
    final vistos = <String>{};
    final pila = [desde];
    while (pila.isNotEmpty) {
      final id = pila.removeLast();
      final n = nodos[id];
      if (n == null || !vale(n) || !vistos.add(id)) continue;
      pila.addAll(n.salidas);
    }
    return vistos;
  }

  List<String> _problemasDeDatos(NodoRuta n) {
    final p = <String>[];
    void exige(bool ok, String que) {
      if (!ok) p.add('${n.id}: ${n.tipo.name} $que.');
    }

    void sin(bool vacio, String campo) {
      if (!vacio) p.add('${n.id}: ${n.tipo.name} no lleva "$campo".');
    }

    final esInicio = n.tipo == TipoNodo.inicio;
    final esCombate = n.tipo == TipoNodo.combate;
    final esGimnasio = n.tipo == TipoNodo.gimnasio;
    exige(!esInicio || n.iniciales.isNotEmpty, 'necesita "iniciales"');
    exige(!esCombate || (n.zona != null && n.rival != null),
        'necesita "zona" y "rival"');
    exige(!esGimnasio || (n.lider != null && n.medalla != null),
        'necesita "lider" y "medalla"');
    exige(!esGimnasio || (n.lider?.pokemon.isNotEmpty ?? true),
        'necesita Pokémon en el líder');
    exige(n.tipo != TipoNodo.jefe || n.jefe != null, 'necesita "jefe"');
    exige(
        !(esCombate && n.rival == RivalDeCombate.entrenador) || n.clase != null,
        'necesita "clase" con un entrenador');
    if (!esInicio) sin(n.iniciales.isEmpty, 'iniciales');
    if (!esCombate) {
      sin(n.zona == null, 'zona');
      sin(n.rival == null, 'rival');
      sin(n.pokemon.isEmpty, 'pokemon');
      sin(n.clase == null, 'clase');
    }
    exige(
        !(esCombate && n.rival == RivalDeCombate.salvaje) ||
            n.pokemon.length <= 1,
        'salvaje lleva un solo Pokémon');
    exige(
        !(esCombate && n.clase != null) || n.rival == RivalDeCombate.entrenador,
        'solo lleva "clase" con un entrenador');
    if (!esGimnasio) {
      sin(n.lider == null, 'lider');
      sin(n.medalla == null, 'medalla');
    }
    if (n.tipo != TipoNodo.jefe) sin(n.jefe == null, 'jefe');
    final esConversacion = n.tipo == TipoNodo.conversacion;
    exige(!esConversacion || (n.personaje != null && n.texto.isNotEmpty),
        'necesita "personaje" y "texto"');
    if (!esConversacion) {
      sin(n.personaje == null, 'personaje');
      sin(n.texto.isEmpty, 'texto');
      sin(!n.cura, 'cura');
    }
    return p;
  }

  /// Lo que no existe en el catálogo: Pokémon, zonas, clases de entrenador y
  /// jefes a los que apuntan los nodos, y Pokémon fijos que no son de su zona.
  /// [salvajesPorZona] da los Pokémon salvajes de cada zona y
  /// [entrenadoresPorZona] los de cada clase de entrenador de cada zona.
  List<String> problemasDeCatalogo({
    required Set<String> pokemon,
    required Set<String> jefes,
    required Map<String, Set<String>> salvajesPorZona,
    required Map<String, Map<String, Set<String>>> entrenadoresPorZona,
  }) {
    final p = <String>[];
    for (final n in nodos.values) {
      for (final id in [...n.iniciales, ...n.pokemon, ...?n.lider?.pokemon]) {
        if (!pokemon.contains(id))
          p.add('${n.id}: el Pokémon "$id" no existe.');
      }
      final zona = n.zona;
      if (zona != null) {
        if (!salvajesPorZona.containsKey(zona)) {
          p.add('${n.id}: la zona "$zona" no existe.');
        } else if (n.rival == RivalDeCombate.salvaje) {
          for (final id in n.pokemon) {
            if (!salvajesPorZona[zona]!.contains(id)) {
              p.add('${n.id}: "$id" no es un salvaje de "$zona".');
            }
          }
        } else if (n.clase != null) {
          final equipo = entrenadoresPorZona[zona]?[n.clase];
          if (equipo == null) {
            p.add(
                '${n.id}: la zona "$zona" no tiene entrenadores "${n.clase}".');
          } else {
            for (final id in n.pokemon) {
              if (!equipo.contains(id)) {
                p.add('${n.id}: "$id" no es de los "${n.clase}" de "$zona".');
              }
            }
          }
        }
      }
      if (n.jefe != null && !jefes.contains(n.jefe)) {
        p.add('${n.id}: el jefe "${n.jefe}" no existe.');
      }
    }
    return p;
  }
}

/// Dónde está el jugador en la región y lo que lleva ganado (D-20 §6,
/// guardado). Inmutable: cada acción devuelve un progreso nuevo.
class ProgresoRuta {
  final String nodoActual;

  /// Si ya se ha hecho lo que había que hacer en el nodo actual (ganar el
  /// combate, usar el descanso, elegir inicial…). Hasta entonces no se avanza.
  final bool resuelto;

  /// Ids de los nodos ya resueltos.
  final Set<String> superados;

  /// Ids de las medallas ganadas.
  final Set<String> medallas;

  /// Ids de los jefes derrotados: solo se capturan la primera vez (D-20 §4).
  final Set<String> jefesDerrotados;

  /// El Pokémon inicial que se eligió.
  final String? inicial;

  const ProgresoRuta({
    required this.nodoActual,
    this.resuelto = false,
    this.superados = const {},
    this.medallas = const {},
    this.jefesDerrotados = const {},
    this.inicial,
  });

  /// Al empezar: en el nodo de inicio, sin resolver.
  factory ProgresoRuta.inicial(RegionCampana region) =>
      ProgresoRuta(nodoActual: region.inicio);

  ProgresoRuta _copiar({
    String? nodoActual,
    bool? resuelto,
    Set<String>? superados,
    Set<String>? medallas,
    Set<String>? jefesDerrotados,
    String? inicial,
  }) =>
      ProgresoRuta(
        nodoActual: nodoActual ?? this.nodoActual,
        resuelto: resuelto ?? this.resuelto,
        superados: superados ?? this.superados,
        medallas: medallas ?? this.medallas,
        jefesDerrotados: jefesDerrotados ?? this.jefesDerrotados,
        inicial: inicial ?? this.inicial,
      );

  /// Si el jefe todavía se puede capturar al derrotarlo.
  bool puedeCapturarJefe(String jefe) => !jefesDerrotados.contains(jefe);

  /// A dónde se puede ir desde aquí: nada hasta resolver el nodo.
  List<String> opciones(RegionCampana region) =>
      resuelto ? region.nodo(nodoActual).salidas : const [];

  /// La región se ha acabado: el nodo final está resuelto.
  bool terminado(RegionCampana region) =>
      resuelto && region.nodo(nodoActual).salidas.isEmpty;

  /// Da por hecho el nodo actual: en el inicio hay que decir qué [inicial] se
  /// elige; un gimnasio da su medalla y un jefe se anota como derrotado.
  ProgresoRuta resolver(RegionCampana region, {String? inicial}) {
    final nodo = region.nodo(nodoActual);
    if (resuelto) throw const ReglaIncumplida('Este nodo ya está resuelto.');
    if (nodo.tipo == TipoNodo.inicio &&
        (inicial == null || !nodo.iniciales.contains(inicial))) {
      throw const ReglaIncumplida('Hay que elegir uno de los iniciales.');
    }
    return _copiar(
      resuelto: true,
      superados: {...superados, nodo.id},
      medallas: nodo.medalla == null ? null : {...medallas, nodo.medalla!},
      jefesDerrotados:
          nodo.jefe == null ? null : {...jefesDerrotados, nodo.jefe!},
      inicial: nodo.tipo == TipoNodo.inicio ? inicial : null,
    );
  }

  /// Pasa a [destino], que tiene que ser una salida del nodo actual ya
  /// resuelto. Una bifurcación no tiene evento y se da por resuelta al llegar.
  ProgresoRuta avanzar(RegionCampana region, String destino) {
    if (!resuelto) {
      throw const ReglaIncumplida('Antes hay que resolver este nodo.');
    }
    if (!region.nodo(nodoActual).salidas.contains(destino)) {
      throw ReglaIncumplida('Desde aquí no se puede ir a "$destino".');
    }
    final sinEvento = region.nodo(destino).tipo == TipoNodo.bifurcacion;
    return _copiar(
      nodoActual: destino,
      resuelto: sinEvento,
      superados: sinEvento ? {...superados, destino} : null,
    );
  }

  /// Vuelve a [nodo], uno ya superado (el último sitio donde el equipo se
  /// curó, tras perder un combate: D-20 §8, pregunta 1). Se queda resuelto,
  /// así que se puede seguir desde él; los nodos de después hay que pasarlos
  /// otra vez. Medallas y jefes derrotados se conservan.
  ProgresoRuta volverA(RegionCampana region, String nodo) {
    region.nodo(nodo);
    if (!superados.contains(nodo)) {
      throw ReglaIncumplida('No se puede volver a "$nodo": no se ha pasado.');
    }
    return _copiar(nodoActual: nodo, resuelto: true);
  }

  Map<String, dynamic> aJson() => {
        'nodoActual': nodoActual,
        'resuelto': resuelto,
        'superados': superados.toList()..sort(),
        'medallas': medallas.toList()..sort(),
        'jefesDerrotados': jefesDerrotados.toList()..sort(),
        if (inicial != null) 'inicial': inicial,
      };

  factory ProgresoRuta.desdeJson(Map<String, dynamic> json) => ProgresoRuta(
        nodoActual: json['nodoActual'] as String,
        resuelto: json['resuelto'] as bool,
        superados: {...(json['superados'] as List<dynamic>).cast<String>()},
        medallas: {...(json['medallas'] as List<dynamic>).cast<String>()},
        jefesDerrotados: {
          ...(json['jefesDerrotados'] as List<dynamic>).cast<String>()
        },
        inicial: json['inicial'] as String?,
      );
}
