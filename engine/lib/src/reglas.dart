/// Constantes y funciones puras de las reglas (GDD v1.0 §2).

/// Pokémon que lleva cada jugador (1 Activo + 1 Banca), en todos los niveles.
const int pokemonPorJugador = 2;

/// Máximo de jugadores por partida.
const int maxJugadores = 4;

/// Tope del daño de un ataque al calcular X (`docs/D-02-dano-maximo.md`).
const int topeAtaqueX = 200;

/// Umbrales de X para cada nivel. El valor umbral pertenece al nivel de arriba.
const int umbralNivel2 = 400;
const int umbralNivel3 = 600;
const int umbralNivel4 = 800;

/// Nivel del jefe según X. Un X menor de 250 se juega también como Nivel 1.
int nivelPorX(int x) {
  if (x >= umbralNivel4) return 4;
  if (x >= umbralNivel3) return 3;
  if (x >= umbralNivel2) return 2;
  return 1;
}

/// Daño que cuenta para X: el introducido, recortado a [0, topeAtaqueX].
int ataqueParaX(int impreso) => impreso.clamp(0, topeAtaqueX).toInt();

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
