/// Constantes y funciones puras de las reglas (GDD v1.0 §2).

/// Pokémon que lleva cada jugador según cuántos juegan (GDD v1.19): con 2
/// jugadores, 4 cada uno (1 Activo + 3 en Banca, 8 en mesa); con 3, 3 cada uno
/// (1 Activo + 2 en Banca, 9 en mesa); en el resto de casos, 2 (1 Activo + 1
/// Banca). Es igual en todos los niveles.
int pokemonPorJugadorSegun(int jugadores) =>
    jugadores == 2 ? 4 : (jugadores == 3 ? 3 : 2);

/// Mínimo de jugadores en una partida oficial (GDD v1.19): con 1 jugador no
/// hay modo oficial (solo existe Onix y no se puede equilibrar). El motor
/// sigue aceptando 1 jugador para práctica y pruebas.
const int minJugadores = 2;

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

/// Rango de X recomendado para un nivel (D-15): `(mínimo, máximo)`. El máximo
/// del nivel 4 es null (sin tope). El nivel 1 empieza en 250, el mínimo de la
/// tabla de balance, aunque un equipo más flojo también juegue ese nivel.
(int, int?) rangoXDelNivel(int nivel) => switch (nivel) {
      1 => (250, maxXNivel1),
      2 => (maxXNivel1 + 1, maxXNivel2),
      3 => (maxXNivel2 + 1, maxXNivel3),
      _ => (maxXNivel3 + 1, null),
    };

/// Si el equipo (X) queda fuera del rango del nivel: -1 por debajo (más difícil
/// de lo recomendado para el jefe), 1 por encima (más fácil), 0 dentro.
int desajusteDeEquipo(int x, int nivel) {
  final (minimo, maximo) = rangoXDelNivel(nivel);
  if (x < minimo) return -1;
  if (maximo != null && x > maximo) return 1;
  return 0;
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

/// Texto de cada carta de ánimo (D-05), en el orden de su número (1 a 5).
const List<String> textosCartaAnimo = [
  'Un Pokémon a elección hace el doble de daño este turno.',
  'Cura 80 de daño a cada Pokémon de los jugadores.',
  'Cura todo el daño de 1 Pokémon.',
  'El jefe no puede jugar más de una carta el próximo turno.',
  'Los ataques de todos los Pokémon de los jugadores hacen 50 más de '
      'daño este turno.',
];

/// Daño extra de la carta de ánimo 5 a cada ataque.
const int bonoCartaAnimoAtaque = 50;
