/// Todo lo que ocurre en una partida es un evento. El estado solo cambia
/// aplicando eventos con `apply`, así que una partida es una lista de eventos.
sealed class Evento {
  const Evento();
}

/// Un jugador de la mesa y el daño de su mejor ataque (D-02).
class ConfigJugador {
  final String nombre;

  /// Daño introducido a mano; el motor lo recorta a [0, 200] para calcular X.
  final int ataqueMaximo;

  const ConfigJugador({required this.nombre, required this.ataqueMaximo});
}

/// Setup: jugadores (1 a 4, en orden de asiento) y su mejor ataque.
/// El motor calcula X y el nivel del jefe.
final class ConfigurarJugadores extends Evento {
  final List<ConfigJugador> jugadores;

  const ConfigurarJugadores(this.jugadores);
}

/// Setup: se elige el jefe del catálogo, que debe ser del nivel calculado.
final class ElegirJefe extends Evento {
  final String nombre;
  final int nivel;
  final int hp;

  const ElegirJefe({required this.nombre, required this.nivel, required this.hp});
}

/// Turno de un jugador: daño que ha hecho al jefe (0 si no le ha dañado,
/// por ejemplo si ha atacado a un aliado).
final class TurnoJugador extends Evento {
  final int jugador;
  final int dano;

  const TurnoJugador({required this.jugador, required this.dano});
}

/// Ataque del jefe: ranura (1 a 3, solo etiqueta), daño y objetivo.
/// [jugador] null significa que el ataque va a todos los jugadores.
/// [alAzar] solo deja constancia de que el objetivo salió de una tirada.
final class AtaqueJefe extends Evento {
  final int ranura;
  final int dano;
  final int? jugador;
  final bool alAzar;

  const AtaqueJefe({
    required this.ranura,
    required this.dano,
    this.jugador,
    this.alAzar = false,
  });
}

/// Un Pokémon de un jugador cae KO.
final class PokemonKo extends Evento {
  final int jugador;

  const PokemonKo(this.jugador);
}

/// El jugador con prioridad roba su carta de ánimo (1 a 5).
/// El efecto se resuelve en la mesa; el motor solo lo registra.
final class CartaAnimoRobada extends Evento {
  final int jugador;
  final int carta;

  const CartaAnimoRobada({required this.jugador, required this.carta});
}

/// Termina el turno del jefe y empieza la ronda siguiente.
final class FinTurnoJefe extends Evento {
  const FinTurnoJefe();
}
