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

  /// Cada cuántos HP perdidos hay un intento de invocación. null: no invoca.
  final int? invocacionCadaHp;

  /// Id del jefe en el catálogo (`catalog/bosses`), si viene de él.
  final String? jefeId;

  const ElegirJefe({
    required this.nombre,
    required this.nivel,
    required this.hp,
    this.invocacionCadaHp,
    this.jefeId,
  });
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

/// La mesa abandona la partida: termina en derrota con el daño hecho hasta
/// ese momento. Un empate no existe: o gana el equipo o pierde.
final class Abandonar extends Evento {
  const Abandonar();
}

/// El jefe se cura [cantidad] (carta del jefe, aliado curandero...).
/// El motor registra lo que sube de verdad, sin pasar del HP máximo.
final class CuracionJefe extends Evento {
  final int cantidad;
  const CuracionJefe(this.cantidad);
}

/// Un jugador ataca a un aliado (en lugar de al jefe) y gasta su turno.
/// Cualquier jugador puede atacar a cualquier aliado. El exceso de daño se
/// pierde y el daño a aliados no cuenta para los puntos.
final class AtaqueAAliado extends Evento {
  final int jugador;
  final int slot;
  final int dano;

  const AtaqueAAliado({
    required this.jugador,
    required this.slot,
    required this.dano,
  });
}

/// La mesa resuelve un intento de invocación sin aliado (la moneda no salió
/// cara o no quedan slots libres).
final class SinInvocacion extends Evento {
  const SinInvocacion();
}

/// La mesa resuelve un intento de invocación con un aliado nuevo en [slot].
/// [ataqueDano] null: el aliado no tiene ataque.
final class AliadoInvocado extends Evento {
  final int slot;
  final String nombre;
  final int hp;
  final String? ataqueNombre;
  final int? ataqueDano;
  final String? habilidad;

  const AliadoInvocado({
    required this.slot,
    required this.nombre,
    required this.hp,
    this.ataqueNombre,
    this.ataqueDano,
    this.habilidad,
  });
}

/// Ataque de un aliado: al entrar y una vez en cada turno del jefe.
/// [objetivo] null: ataca al dueño de su slot. Si el dueño está eliminado
/// hay que indicar el jugador activo que salió en la tirada.
final class AtaqueAliado extends Evento {
  final int slot;
  final int dano;
  final int? objetivo;

  const AtaqueAliado({required this.slot, required this.dano, this.objetivo});
}
