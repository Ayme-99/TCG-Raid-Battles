/// Tipos de los Pokémon de campaña (D-20). Siguen al TCG: no hay tipo tierra ni
/// roca, los Pokémon de tierra y de roca son de tipo [lucha].
///
/// Tampoco hay hielo, veneno, volador, bicho ni fantasma (D-20 §10.3): pasan a
/// agua, oscuridad, normal, planta y oscuridad. [metal] está aunque aún no lo
/// lleve ninguna carta.
///
/// El nombre de cada valor es el que se escribe en el catálogo JSON.
enum TipoCampana {
  normal,
  fuego,
  agua,
  planta,
  electrico,
  lucha,
  psiquico,
  oscuridad,
  dragon,
  metal,
}

/// Debilidad de una carta: los ataques de [tipo] le hacen [multiplicador]
/// veces su daño (×2 de salida). Se escribe en la carta de cada Pokémon.
class Debilidad {
  final TipoCampana tipo;
  final int multiplicador;

  const Debilidad(this.tipo, {this.multiplicador = 2});
}

/// Resistencia de una carta: los ataques de [tipo] le hacen [reduccion] puntos
/// de daño menos (−30 de salida). Se escribe en la carta de cada Pokémon.
class Resistencia {
  final TipoCampana tipo;
  final int reduccion;

  const Resistencia(this.tipo, {this.reduccion = 30});
}
