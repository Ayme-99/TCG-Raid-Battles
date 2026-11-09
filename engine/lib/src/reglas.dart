/// Constantes y funciones puras de las reglas (GDD v1.0 §2).

/// Pokémon que lleva cada jugador (1 Activo + 1 Banca), en todos los niveles.
const int pokemonPorJugador = 2;

/// Máximo de jugadores por partida.
const int maxJugadores = 4;

/// Tope del daño de un ataque al calcular X (`docs/D-02-dano-maximo.md`).
/// X máximo de cada nivel. El valor límite pertenece al nivel de abajo:
/// Nv1 `X <= 400`, Nv2 `400 < X <= 600`, Nv3 `600 < X <= 800`, Nv4 `X > 800`.
/// Con 4 jugadores, la media máxima por jugador es 100 / 150 / 200 en Nv1-3.
const int maxXNivel1 = 400;
const int maxXNivel2 = 600;
const int maxXNivel3 = 800;

/// Nivel del jefe según X. Un X menor de 250 se juega también como Nivel 1.
int nivelPorX(int x) {
  if (x > maxXNivel3) return 4;
  if (x > maxXNivel2) return 3;
  if (x > maxXNivel1) return 2;
  return 1;
}

/// Daño que cuenta para X: el introducido, sin tope superior (hay cartas de
/// más de 200 de daño) y nunca negativo.
int ataqueParaX(int impreso) => impreso < 0 ? 0 : impreso;

/// Ranuras de ataque del jefe (1, 2 o 3).
const int ranurasAtaqueJefe = 3;

/// Daño del veneno del jefe en cada chequeo (D-12). Provisional hasta T-17.
const int danoVeneno = 10;

/// Daño de la quemadura del jefe en cada chequeo (D-12). Provisional.
const int danoQuemadura = 20;

/// Daño de un contador de daño (efecto `contadorATodos`, D-14).
const int danoContador = 10;

/// Aplicaciones de estados que cuentan para el bono de puntos (D-12).
const int topeAplicacionesBono = 3;

/// Cartas de ánimo oficiales (numeradas 1 a 5).
const int cartasAnimoTotal = 5;
