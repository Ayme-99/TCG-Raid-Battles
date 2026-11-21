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

/// Cómo se consigue una evolución (D-20 §2.1).
enum ViaEvolucion {
  /// Acumulando XP (convertida de puntos en un centro Pokémon).
  xp,

  /// Con un objeto de evolución (una piedra…).
  objeto,

  /// Por intercambio: cuesta puntos por usar la máquina de intercambio.
  intercambio,

  /// Gastando puntos, para hacerse ex un Pokémon que no evoluciona.
  puntos,
}

/// Una evolución posible de un Pokémon. La carta evolucionada sustituye a la
/// anterior.
class EvolucionCampana {
  /// Id del Pokémon en que evoluciona.
  final String a;
  final ViaEvolucion via;

  /// XP necesaria (con [ViaEvolucion.xp]).
  final int? xp;

  /// Id del objeto (con [ViaEvolucion.objeto]).
  final String? objeto;

  /// Puntos que cuesta (con [ViaEvolucion.intercambio] o
  /// [ViaEvolucion.puntos]).
  final int? puntos;

  const EvolucionCampana({
    required this.a,
    required this.via,
    this.xp,
    this.objeto,
    this.puntos,
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

  /// Carta ex: la última fase de cada Pokémon.
  final bool ex;

  /// Las formas en que puede evolucionar (vacía si no evoluciona).
  final List<EvolucionCampana> evoluciones;

  const PokemonCampana({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.ps,
    this.debilidad,
    this.resistencia,
    this.retirada = 0,
    required this.ataques,
    this.ex = false,
    this.evoluciones = const [],
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
