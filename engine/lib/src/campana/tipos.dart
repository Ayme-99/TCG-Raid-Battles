/// Tipos de los Pokémon de campaña: los 15 de la 1.ª generación (D-20).
///
/// El nombre de cada valor es el que se escribe en el catálogo JSON.
enum TipoCampana {
  normal,
  fuego,
  agua,
  planta,
  electrico,
  hielo,
  lucha,
  veneno,
  tierra,
  volador,
  psiquico,
  bicho,
  roca,
  fantasma,
  dragon,
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
