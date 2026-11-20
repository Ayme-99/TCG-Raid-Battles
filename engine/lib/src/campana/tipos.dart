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

/// Efectividad de un ataque según el tipo del defensor.
///
/// Solo se anotan los casos que no son ×1: ×2 (fuerte), ×0,5 (débil) y ×0
/// (inmune). Valores provisionales (D-20 §3.3).
const Map<TipoCampana, Map<TipoCampana, double>> tablaTiposCampana = {
  TipoCampana.normal: {TipoCampana.roca: 0.5, TipoCampana.fantasma: 0},
  TipoCampana.fuego: {
    TipoCampana.planta: 2,
    TipoCampana.agua: 0.5,
    TipoCampana.roca: 0.5,
    TipoCampana.fuego: 0.5,
  },
  TipoCampana.agua: {
    TipoCampana.fuego: 2,
    TipoCampana.tierra: 2,
    TipoCampana.roca: 2,
    TipoCampana.agua: 0.5,
    TipoCampana.planta: 0.5,
  },
  TipoCampana.planta: {
    TipoCampana.agua: 2,
    TipoCampana.tierra: 2,
    TipoCampana.roca: 2,
    TipoCampana.fuego: 0.5,
    TipoCampana.planta: 0.5,
    TipoCampana.veneno: 0.5,
  },
  TipoCampana.electrico: {
    TipoCampana.agua: 2,
    TipoCampana.planta: 0.5,
    TipoCampana.electrico: 0.5,
    TipoCampana.tierra: 0,
  },
  TipoCampana.roca: {
    TipoCampana.fuego: 2,
    TipoCampana.lucha: 0.5,
    TipoCampana.tierra: 0.5,
  },
  TipoCampana.tierra: {
    TipoCampana.fuego: 2,
    TipoCampana.electrico: 2,
    TipoCampana.roca: 2,
    TipoCampana.veneno: 2,
    TipoCampana.planta: 0.5,
  },
  TipoCampana.lucha: {
    TipoCampana.normal: 2,
    TipoCampana.roca: 2,
    TipoCampana.veneno: 0.5,
    TipoCampana.psiquico: 0.5,
    TipoCampana.fantasma: 0,
  },
  TipoCampana.fantasma: {
    TipoCampana.fantasma: 2,
    TipoCampana.psiquico: 2,
    TipoCampana.normal: 0,
  },
  TipoCampana.veneno: {
    TipoCampana.planta: 2,
    TipoCampana.veneno: 0.5,
    TipoCampana.tierra: 0.5,
    TipoCampana.roca: 0.5,
    TipoCampana.fantasma: 0.5,
  },
  TipoCampana.psiquico: {
    TipoCampana.lucha: 2,
    TipoCampana.veneno: 2,
    TipoCampana.psiquico: 0.5,
  },
};

/// Multiplicador de un ataque de tipo [ataque] contra un defensor de [tipos]
/// (uno o dos): el producto de la efectividad contra cada uno.
double multiplicadorDeTipos(TipoCampana ataque, List<TipoCampana> tipos) {
  var m = 1.0;
  for (final t in tipos) {
    m *= tablaTiposCampana[ataque]?[t] ?? 1.0;
  }
  return m;
}
