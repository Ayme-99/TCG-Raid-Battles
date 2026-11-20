/// Tipos de los Pokémon de campaña (D-20).
///
/// Por ahora solo los de la región Túnel Roca y los de los tres iniciales.
enum TipoCampana {
  normal,
  fuego,
  agua,
  planta,
  electrico,
  roca,
  tierra,
  lucha,
  fantasma,
  veneno,
  psiquico,
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
