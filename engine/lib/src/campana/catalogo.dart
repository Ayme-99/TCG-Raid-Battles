import 'pokemon.dart';
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
                [for (final p in _campo<List<dynamic>>(e, 'pokemon')) p as String],
              ),
          ]
        : const [],
    jefe: json['jefe'] as String?,
  );
}
