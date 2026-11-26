import 'combate.dart';
import 'pokemon.dart';
import 'ruta.dart';
import 'tipos.dart';

/// Lee un tipo del catálogo (`"agua"`, `"electrico"`…).
TipoCampana tipoCampanaDeTexto(String texto) {
  for (final t in TipoCampana.values) {
    if (t.name == texto) return t;
  }
  throw FormatException('Tipo de campaña desconocido: "$texto".');
}

T _campo<T>(Map<String, dynamic> json, String clave) {
  final v = json[clave];
  if (v is! T) {
    throw FormatException('Falta "$clave" o no es del tipo esperado.');
  }
  return v;
}

ViaEvolucion _viaDeTexto(String texto) {
  for (final v in ViaEvolucion.values) {
    if (v.name == texto) return v;
  }
  throw FormatException('Vía de evolución desconocida: "$texto".');
}

/// Lee una categoría de captura del catálogo (`"comun"`, `"intermedio"`…).
CategoriaCaptura categoriaCapturaDeTexto(String texto) {
  for (final c in CategoriaCaptura.values) {
    if (c.name == texto) return c;
  }
  throw FormatException('Categoría de captura desconocida: "$texto".');
}

EvolucionCampana _evolucionDesdeJson(Map<String, dynamic> json) {
  final via = _viaDeTexto(_campo<String>(json, 'via'));
  final a = _campo<String>(json, 'a');
  final medallas = json['medallasMinimas'] as int?;
  if (medallas != null && medallas < 0) {
    throw const FormatException('"medallasMinimas" no puede ser negativo.');
  }
  switch (via) {
    case ViaEvolucion.xp:
      return EvolucionCampana(
          a: a,
          via: via,
          xpEvolucion: _campo<int>(json, 'xpEvolucion'),
          medallasMinimas: medallas);
    case ViaEvolucion.objeto:
      return EvolucionCampana(
          a: a,
          via: via,
          objeto: _campo<String>(json, 'objeto'),
          medallasMinimas: medallas);
    case ViaEvolucion.intercambio:
      // Gratis desde el 2026-11-24 (D-20 §10.9): ya no lleva `puntos`.
      if (json.containsKey('puntos')) {
        throw const FormatException(
            'El intercambio es gratis: quita "puntos" (D-20 §10.9).');
      }
      return EvolucionCampana(a: a, via: via, medallasMinimas: medallas);
  }
}

EfectoAtaque? _efectoDesdeJson(dynamic json) {
  if (json == null) return null;
  if (json is! Map<String, dynamic>) {
    throw const FormatException('"efecto" no es un objeto.');
  }
  final tipo = _campo<String>(json, 'tipo');
  switch (tipo) {
    case 'reduceDanoRival':
      return ReduceDanoRival(_campo<int>(json, 'valor'));
    case 'aumentaDanoRecibido':
      return AumentaDanoRecibido(_campo<int>(json, 'valor'));
    case 'monedasDano':
      final monedas = _campo<int>(json, 'monedas');
      final tabla = [
        for (final d in _campo<List<dynamic>>(json, 'danoPorCaras')) d as int,
      ];
      if (tabla.length != monedas + 1) {
        throw const FormatException(
            '"danoPorCaras" necesita un valor por cada número de caras (de 0 a monedas).');
      }
      return MonedasDano(monedas, tabla);
    case 'repiteDanoAlDerribar':
      return const RepiteDanoAlDerribar();
    case 'danoPorRacha':
      return const DanoPorRacha();
    case 'monedaFalloRival':
      return MonedaFalloRival(
          mientrasActivo: (json['mientrasActivo'] as bool?) ?? false);
    case 'drenaDefensor':
      return const DrenaDefensor();
    case 'paralizaDefensor':
      final monedas = _campo<int>(json, 'monedas');
      final minimo = _campo<int>(json, 'minimoCaras');
      if (monedas < 1 || minimo < 1 || minimo > monedas) {
        throw const FormatException(
            '"minimoCaras" tiene que estar entre 1 y "monedas".');
      }
      return ParalizaDefensor(monedas, minimo);
    case 'confundeDefensor':
      final monedas = (json['monedas'] as int?) ?? 1;
      if (monedas < 1) {
        throw const FormatException('"monedas" tiene que ser 1 o más.');
      }
      return ConfundeDefensor(monedas);
    case 'reduceDanoPropio':
      return ReduceDanoPropio(_campo<int>(json, 'valor'));
    case 'envenenaDefensor':
      return EnvenenaDefensor(_campo<int>(json, 'valor'));
    case 'monedaDanoExtra':
      return MonedaDanoExtra(_campo<int>(json, 'valor'));
    case 'quitaEnergiaRival':
      return QuitaEnergiaRival(_campo<int>(json, 'valor'));
    case 'ganaEnergia':
      return GanaEnergia(_campo<int>(json, 'valor'));
  }
  throw FormatException('Efecto de ataque desconocido: "$tipo".');
}

/// Un Pokémon de campaña a partir de su JSON del catálogo
/// (`catalog/campana/pokemon/*.json`).
PokemonCampana pokemonCampanaDesdeJson(Map<String, dynamic> json) {
  final debilidad = json['debilidad'];
  final resistencia = json['resistencia'];
  final ataques = _campo<List<dynamic>>(json, 'ataques');
  final ex = (json['ex'] as bool?) ?? false;
  final evoluciones = (json['evoluciones'] as List<dynamic>?) ?? const [];
  // La piedra ex es el último paso de la línea (D-20 §10.11, punto 4).
  if (ex && evoluciones.isNotEmpty) {
    throw FormatException(
        '${json['id']}: una carta ex no lleva "evoluciones" (D-20 §10.11).');
  }
  return PokemonCampana(
    id: _campo<String>(json, 'id'),
    nombre: _campo<String>(json, 'nombre'),
    tipo: tipoCampanaDeTexto(_campo<String>(json, 'tipo')),
    ps: _campo<int>(json, 'ps'),
    debilidad: debilidad is Map<String, dynamic>
        ? Debilidad(
            tipoCampanaDeTexto(_campo<String>(debilidad, 'tipo')),
            multiplicador: (debilidad['multiplicador'] as int?) ?? 2,
          )
        : null,
    resistencia: resistencia is Map<String, dynamic>
        ? Resistencia(
            tipoCampanaDeTexto(_campo<String>(resistencia, 'tipo')),
            reduccion: (resistencia['reduccion'] as int?) ?? 30,
          )
        : null,
    retirada: (json['retirada'] as int?) ?? 0,
    habilidad: _habilidadDesdeJson(json['habilidad']),
    ex: ex,
    categoriaCaptura: json['categoriaCaptura'] == null
        ? null
        : categoriaCapturaDeTexto(_campo<String>(json, 'categoriaCaptura')),
    evoluciones: [
      for (final e in evoluciones)
        _evolucionDesdeJson(e as Map<String, dynamic>),
    ],
    ataques: [
      for (final a in ataques)
        AtaqueCampana(
          nombre: _campo<String>(a as Map<String, dynamic>, 'nombre'),
          tipo: tipoCampanaDeTexto(_campo<String>(a, 'tipo')),
          coste: _campo<int>(a, 'coste'),
          dano: _campo<int>(a, 'dano'),
          efecto: _efectoDesdeJson(a['efecto']),
          ignoraFallo: (a['ignoraFallo'] as bool?) ?? false,
        ),
    ],
  );
}

HabilidadCampana? _habilidadDesdeJson(dynamic json) {
  if (json == null) return null;
  final h = json as Map<String, dynamic>;
  final nombre = _campo<String>(h, 'nombre');
  switch (_campo<String>(h, 'tipo')) {
    case 'monedaDanoExtraAlAtacar':
      return MonedaDanoExtraAlAtacar(nombre, _campo<int>(h, 'valor'));
  }
  throw FormatException('Habilidad desconocida: ${h['tipo']}');
}

/// Total de la serie de jefes de campaña (cartas NN/20): 8 de tramo, 8 de
/// rutas clave y 4 legendarios (D-20 §4).
const totalJefesCampana = 20;

/// Cuándo y quién llama a un aliado durante el combate contra un jefe: al
/// llegar a [alBajarDePorcentaje] % de sus PS o bajar de él (el nombre del
/// campo es anterior; decidido el 2026-11-22: con 50 PS justos de 100 ya
/// llama) invoca a uno de los [aliados] (ids de Pokémon del catálogo), que
/// aparece en la banca, y al llegar a [alFrenteAlPorcentaje] % el aliado pasa
/// al puesto activo y el jefe a la banca. Ver [LlamadaEnCombate].
class LlamadaDeAliado {
  final int alBajarDePorcentaje;

  /// Porcentaje al que el aliado pasa de la banca al puesto activo; null si
  /// entra directamente al invocarlo (D-20 §4, Jefes).
  final int? alFrenteAlPorcentaje;
  final List<String> aliados;

  const LlamadaDeAliado(this.alBajarDePorcentaje, this.aliados,
      {this.alFrenteAlPorcentaje});
}

/// Un jefe de campaña: un Pokémon salvaje con su carta de la serie NN/20.
class JefeCampana {
  /// Posición en la serie de jefes (1 a [totalJefesCampana]).
  final int numero;
  final PokemonCampana pokemon;
  final LlamadaDeAliado? llamaAliado;

  /// XP que da derrotarlo, si lleva una propia en su JSON (`xp`); si no, la
  /// de la categoría Jefe (D-20 §10.6).
  final int? xpPropia;

  /// La moneda de captura sale siempre cara (Pikachu jefe, por ser el
  /// tutorial: D-20 §10.6). La tirada gasta su Ball igualmente.
  final bool capturaAsegurada;

  const JefeCampana({
    required this.numero,
    required this.pokemon,
    this.llamaAliado,
    this.xpPropia,
    this.capturaAsegurada = false,
  });

  /// Categoría con la que se captura: la de su carta (`categoriaCaptura` del
  /// `pokemon` del JSON) o, si no la lleva, Jefe.
  CategoriaCaptura get categoriaCaptura =>
      pokemon.categoriaCaptura ?? CategoriaCaptura.jefe;

  /// XP que suma a la reserva derrotarlo.
  int get xp => xpPropia ?? xpDeCategoria(CategoriaCaptura.jefe);
}

/// Un jefe de campaña a partir de su JSON del catálogo
/// (`catalog/campana/jefes/*.json`).
JefeCampana jefeCampanaDesdeJson(Map<String, dynamic> json) {
  final llamada = json['llamaAliado'];
  return JefeCampana(
    numero: _campo<int>(json, 'numero'),
    pokemon:
        pokemonCampanaDesdeJson(_campo<Map<String, dynamic>>(json, 'pokemon')),
    llamaAliado: llamada == null
        ? null
        : LlamadaDeAliado(
            _campo<int>(llamada as Map<String, dynamic>, 'alBajarDePorcentaje'),
            [
              for (final a in _campo<List<dynamic>>(llamada, 'aliados'))
                a as String,
            ],
            alFrenteAlPorcentaje: llamada['alFrenteAlPorcentaje'] as int?,
          ),
    xpPropia: json['xp'] as int?,
    capturaAsegurada: (json['capturaAsegurada'] as bool?) ?? false,
  );
}

/// La llamada de aliado de [jefe] lista para [EstadoCombate.inicial]
/// (`llamadaRival`), con los aliados sacados de [pokemon] (el catálogo de
/// campaña por id), o null si el jefe no llama a nadie. El jefe va el primero
/// del equipo rival.
LlamadaEnCombate? llamadaEnCombate(
    JefeCampana jefe, Map<String, PokemonCampana> pokemon) {
  final l = jefe.llamaAliado;
  if (l == null) return null;
  return LlamadaEnCombate(
      l.alBajarDePorcentaje,
      [
        for (final id in l.aliados)
          pokemon[id] ??
              (throw FormatException(
                  'El aliado "$id" no está en el catálogo.')),
      ],
      alFrente: l.alFrenteAlPorcentaje);
}

/// Un grupo de entrenadores de una zona (por ejemplo, los PokéManiacos).
class EntrenadoresDeZona {
  final String clase;

  /// Ids de sus Pokémon.
  final List<String> pokemon;

  /// Dinero que paga cada entrenador de la clase al ser vencido (D-20 §10.6),
  /// o null si aún no tiene cifra.
  final int? dinero;

  const EntrenadoresDeZona(this.clase, this.pokemon, {this.dinero});
}

/// Una zona de la campaña: qué aparece en ella.
class ZonaCampana {
  final String id;
  final String nombre;
  final String region;

  /// Ids de los Pokémon salvajes.
  final List<String> salvajes;
  final List<EntrenadoresDeZona> entrenadores;

  /// Si sus salvajes se pueden capturar. La Ruta 1 no deja: solo se aprende
  /// a combatir (D-20 §10.6). En el JSON, `captura` (true si no está).
  final bool permiteCaptura;

  const ZonaCampana({
    required this.id,
    required this.nombre,
    required this.region,
    required this.salvajes,
    this.entrenadores = const [],
    this.permiteCaptura = true,
  });

  /// Todos los ids de Pokémon que aparecen en la zona, sin repetir.
  Set<String> get todosLosPokemon => {
        ...salvajes,
        for (final e in entrenadores) ...e.pokemon,
      };
}

/// Una zona a partir de su JSON (`catalog/campana/zonas/*.json`).
///
/// Una zona no lleva jefe: los jefes son cartas NN/20 de `jefes/` y los pone
/// un nodo `jefe` de la región (D-20 §4, Jefes; §10.8). Un `jefe` en la zona
/// es un error de datos (#375).
ZonaCampana zonaCampanaDesdeJson(Map<String, dynamic> json) {
  if (json.containsKey('jefe')) {
    throw FormatException('La zona "${json['id']}" lleva "jefe": los jefes '
        'van en un nodo de la región, no en la zona (D-20 §4, Jefes).');
  }
  final entrenadores = json['entrenadores'];
  return ZonaCampana(
    id: _campo<String>(json, 'id'),
    nombre: _campo<String>(json, 'nombre'),
    region: _campo<String>(json, 'region'),
    salvajes: [
      for (final s in _campo<List<dynamic>>(json, 'salvajes')) s as String,
    ],
    entrenadores: entrenadores is List
        ? [
            for (final e in entrenadores)
              EntrenadoresDeZona(
                _campo<String>(e as Map<String, dynamic>, 'clase'),
                [
                  for (final p in _campo<List<dynamic>>(e, 'pokemon'))
                    p as String
                ],
                dinero: e['dinero'] as int?,
              ),
          ]
        : const [],
    permiteCaptura: (json['captura'] as bool?) ?? true,
  );
}

T _enumDeTexto<T extends Enum>(List<T> valores, String texto, String que) {
  for (final v in valores) {
    if (v.name == texto) return v;
  }
  throw FormatException('$que desconocido: "$texto".');
}

List<String> _textos(Map<String, dynamic> json, String clave) => [
      for (final s in (json[clave] as List<dynamic>?) ?? const []) s as String,
    ];

double _relativa(Map<String, dynamic> json, String clave) {
  final v = json[clave];
  if (v is! num) {
    throw FormatException('Falta "$clave" o no es un número.');
  }
  return v.toDouble();
}

EscenaNodo? _escenaDesdeJson(dynamic json) {
  if (json == null) return null;
  if (json is! Map<String, dynamic>) {
    throw const FormatException('"escena" no es un objeto.');
  }
  return EscenaNodo(
    imagen: _campo<String>(json, 'imagen'),
    zonas: [
      for (final z in (json['zonas'] as List<dynamic>?) ?? const [])
        ZonaPulsable(
          accion: _enumDeTexto(AccionZona.values,
              _campo<String>(z as Map<String, dynamic>, 'accion'), 'Acción'),
          destino: z['destino'] as String?,
          x: _relativa(z, 'x'),
          y: _relativa(z, 'y'),
          ancho: _relativa(z, 'ancho'),
          alto: _relativa(z, 'alto'),
        ),
    ],
  );
}

/// Un nodo de la ruta a partir de su JSON.
NodoRuta nodoRutaDesdeJson(Map<String, dynamic> json) {
  final lider = json['lider'];
  final rival = json['rival'] as String?;
  return NodoRuta(
    id: _campo<String>(json, 'id'),
    tipo: _enumDeTexto(
        TipoNodo.values, _campo<String>(json, 'tipo'), 'Tipo de nodo'),
    nombre: _campo<String>(json, 'nombre'),
    salidas: _textos(json, 'salidas'),
    opcional: (json['opcional'] as bool?) ?? false,
    iniciales: _textos(json, 'iniciales'),
    zona: json['zona'] as String?,
    rival: rival == null
        ? null
        : _enumDeTexto(RivalDeCombate.values, rival, 'Rival'),
    clase: json['clase'] as String?,
    pokemon: _textos(json, 'pokemon'),
    lider: lider is Map<String, dynamic>
        ? LiderDeGimnasio(
            _campo<String>(lider, 'nombre'), _textos(lider, 'pokemon'),
            dinero: lider['dinero'] as int?)
        : null,
    medalla: json['medalla'] as String?,
    jefe: json['jefe'] as String?,
    personaje: json['personaje'] as String?,
    texto: _textos(json, 'texto'),
    cura: (json['cura'] as bool?) ?? false,
    escena: _escenaDesdeJson(json['escena']),
    tienda: _textos(json, 'tienda'),
  );
}

/// Una región a partir de su JSON (`catalog/campana/regiones/*.json`).
RegionCampana regionCampanaDesdeJson(Map<String, dynamic> json) {
  final nodos = <String, NodoRuta>{};
  for (final n in _campo<List<dynamic>>(json, 'nodos')) {
    final nodo = nodoRutaDesdeJson(n as Map<String, dynamic>);
    if (nodos.containsKey(nodo.id)) {
      throw FormatException('El nodo "${nodo.id}" está repetido.');
    }
    nodos[nodo.id] = nodo;
  }
  return RegionCampana(
    id: _campo<String>(json, 'id'),
    nombre: _campo<String>(json, 'nombre'),
    inicio: _campo<String>(json, 'inicio'),
    nodos: nodos,
  );
}
