import 'tipos.dart';

/// Un ataque de un Pokémon de campaña. Los efectos (monedas, estados…) llegan
/// más adelante (D-20 §2).
class AtaqueCampana {
  final String nombre;
  final TipoCampana tipo;

  /// Energía que gasta.
  final int coste;
  final int dano;

  const AtaqueCampana({
    required this.nombre,
    required this.tipo,
    required this.coste,
    required this.dano,
  });
}

/// Un Pokémon de campaña tal como está en el catálogo.
class PokemonCampana {
  final String id;
  final String nombre;
  final TipoCampana tipo;
  final int ps;

  /// Debilidad y resistencia de la carta, si las tiene (D-20 §3.3).
  final Debilidad? debilidad;
  final Resistencia? resistencia;

  /// Energía que cuesta retirarlo, además del turno; 0 es retirada gratis.
  final int retirada;
  final List<AtaqueCampana> ataques;

  const PokemonCampana({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.ps,
    this.debilidad,
    this.resistencia,
    this.retirada = 0,
    required this.ataques,
  });
}

/// Un Pokémon del equipo durante un combate: la especie y su salud actual.
class PokemonEnCombate {
  final PokemonCampana especie;
  final int ps;

  const PokemonEnCombate(this.especie, this.ps);

  factory PokemonEnCombate.completo(PokemonCampana especie) =>
      PokemonEnCombate(especie, especie.ps);

  bool get enPie => ps > 0;

  PokemonEnCombate conPs(int nuevos) =>
      PokemonEnCombate(especie, nuevos < 0 ? 0 : nuevos);
}
