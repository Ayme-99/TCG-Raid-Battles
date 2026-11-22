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

EvolucionCampana _evolucionDesdeJson(Map<String, dynamic> json) {
  final via = _viaDeTexto(_campo<String>(json, 'via'));
  switch (via) {
    case ViaEvolucion.xp:
      return EvolucionCampana(
          a: _campo<String>(json, 'a'), via: via, xp: _campo<int>(json, 'xp'));
    case ViaEvolucion.objeto:
      return EvolucionCampana(
          a: _campo<String>(json, 'a'),
          via: via,
          objeto: _campo<String>(json, 'objeto'));
    case ViaEvolucion.intercambio:
    case ViaEvolucion.puntos:
      return EvolucionCampana(
          a: _campo<String>(json, 'a'),
          via: via,
          puntos: _campo<int>(json, 'puntos'));
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
      return const MonedaFalloRival();
    case 'reduceDanoPropio':
      return ReduceDanoPropio(_campo<int>(json, 'valor'));
    case 'envenenaDefensor':
      return EnvenenaDefensor(_campo<int>(json, 'valor'));
    case 'monedaDanoExtra':
      return MonedaDanoExtra(_campo<int>(json, 'valor'));
    case 'quitaEnergiaRival':
      return QuitaEnergiaRival(_campo<int>(json, 'valor'));
  }
  throw FormatException('Efecto de ataque desconocido: "$tipo".');
}

/// Un Pokémon de campaña a partir de su JSON del catálogo
/// (`catalog/campana/pokemon/*.json`).
PokemonCampana pokemonCampanaDesdeJson(Map<String, dynamic> json) {
  final debilidad = json['debilidad'];
  final resistencia = json['resistencia'];
  final ataques = _campo<List<dynamic>>(json, 'ataques');
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
    ex: (json['ex'] as bool?) ?? false,
    evoluciones: [
      for (final e in (json['evoluciones'] as List<dynamic>?) ?? const [])
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

  const JefeCampana({
    required this.numero,
    required this.pokemon,
    this.llamaAliado,
  });
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

  const EntrenadoresDeZona(this.clase, this.pokemon);
}

/// Una zona de la campaña: qué aparece en ella.
class ZonaCampana {
  final String id;
  final String nombre;
  final String region;

  /// Ids de los Pokémon salvajes.
  final List<String> salvajes;
  final List<EntrenadoresDeZona> entrenadores;

  /// Id del Pokémon jefe de la zona, si lo hay.
  final String? jefe;

  const ZonaCampana({
    required this.id,
    required this.nombre,
    required this.region,
    required this.salvajes,
    this.entrenadores = const [],
    this.jefe,
  });

  /// Todos los ids de Pokémon que aparecen en la zona, sin repetir.
  Set<String> get todosLosPokemon => {
        ...salvajes,
        for (final e in entrenadores) ...e.pokemon,
        if (jefe != null) jefe!,
      };
}

/// Una zona a partir de su JSON (`catalog/campana/zonas/*.json`).
ZonaCampana zonaCampanaDesdeJson(Map<String, dynamic> json) {
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
              ),
          ]
        : const [],
    jefe: json['jefe'] as String?,
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
            _campo<String>(lider, 'nombre'), _textos(lider, 'pokemon'))
        : null,
    medalla: json['medalla'] as String?,
    jefe: json['jefe'] as String?,
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
