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

/// Tipos de efecto de un ataque del jefe (D-14).
enum TipoEfectoAtaque {
  /// El Defensor no puede retirarse durante [EfectoAtaque.duracion] turnos de
  /// los jugadores. Necesita `jugador` en el ataque.
  sinRetirada,

  /// El Defensor no puede atacar durante [EfectoAtaque.duracion] turnos de los
  /// jugadores. Necesita `jugador` en el ataque.
  sinAtaque,

  /// El Defensor queda paralizado. Si el ataque lanza moneda,
  /// [EfectoAtaque.moneda] es el resultado (cara = paralizado). Necesita
  /// `jugador` en el ataque.
  paralizarDefensor,

  /// El daño ignora los efectos del Pokémon activo rival. Solo se registra.
  ignoraEfectos,

  /// Daño extra condicionado a la mesa (por ejemplo, «si el Defensor no tiene
  /// contadores»). Los jugadores lo aplican; solo se registra.
  danoExtraSi,

  /// Daño extra por cada ataque anterior del turno del jefe. El daño final ya
  /// va en [AtaqueJefe.dano]; el efecto solo se registra.
  danoPorAtaquePrevio,

  /// Pone [EfectoAtaque.valor] contadores de daño en todos los Pokémon en
  /// juego menos el jefe. El programa los aplica a los aliados del jefe; los
  /// jugadores los ponen en sus Pokémon en la mesa.
  contadorATodos,

  /// El jefe se hace [EfectoAtaque.valor] puntos de daño a sí mismo. Se aplica
  /// después del daño al jugador y no se atribuye a ningún jugador.
  autodano,

  /// Rebote: si el ataque deja KO al Pokémon Defensor, el atacante (el jefe)
  /// se hace [EfectoAtaque.valor] puntos de daño. Necesita `jugador` en el
  /// ataque. El motor solo lo registra: la mesa dice si hubo KO y entonces se
  /// registran `PokemonKo` y `DanoDeEfecto` (T-59).
  autodanoSiKo,
}

/// Efecto de un ataque del jefe (D-14).
/// [valor]: cantidad (HP de autodaño, contadores...). [duracion]: turnos de
/// los jugadores que dura el efecto (1 si no se indica). [moneda]: resultado
/// de la moneda del ataque (true cara), si la lleva.
final class EfectoAtaque {
  final TipoEfectoAtaque tipo;
  final int? valor;
  final int? duracion;
  final bool? moneda;

  const EfectoAtaque({
    required this.tipo,
    this.valor,
    this.duracion,
    this.moneda,
  });
}

/// Ataque del jefe: ranura (1 a 3, solo etiqueta), daño y objetivo.
/// [jugador] null significa que el ataque va a todos los jugadores.
/// [alAzar] solo deja constancia de que el objetivo salió de una tirada.
/// [efecto] es el efecto del ataque, si lo tiene (D-14).
final class AtaqueJefe extends Evento {
  final int ranura;
  final int dano;
  final int? jugador;
  final bool alAzar;
  final EfectoAtaque? efecto;

  const AtaqueJefe({
    required this.ranura,
    required this.dano,
    this.jugador,
    this.alAzar = false,
    this.efecto,
  });
}

/// Daño que un efecto (rebote, contadores) hace al jefe o a un aliado (T-59).
/// Con [jugador] va al jefe y se atribuye a ese jugador (el defensor del
/// ataque): cuenta para su daño y para los umbrales de llamada, y puede dar la
/// victoria. Con [slot] va a ese aliado, sin atribuir a nadie; a 0 HP sale de
/// la mesa y libera el slot. Se indica exactamente uno de los dos.
final class DanoDeEfecto extends Evento {
  final int puntos;
  final int? jugador;
  final int? slot;

  const DanoDeEfecto({required this.puntos, this.jugador, this.slot});
}

/// Un Pokémon de un jugador cae KO.
final class PokemonKo extends Evento {
  final int jugador;

  const PokemonKo(this.jugador);
}

/// El jugador KO roba su carta de ánimo (1 a 5) en el turno que se sienta.
/// La app ya no lo pide (TODO: la carta se roba en la mesa); el motor sigue
/// aceptando el registro por compatibilidad con el contrato.
/// El efecto se resuelve en la mesa; el motor solo lo registra.
final class CartaAnimoRobada extends Evento {
  final int jugador;
  final int carta;

  const CartaAnimoRobada({required this.jugador, required this.carta});
}

/// Estados alterados que el asistente lleva en el jefe (D-12).
enum EstadoDelJefe { veneno, quemadura }

/// Un jugador deja al jefe con un estado alterado. Si el jefe ya lo tenía no
/// cambia nada y no cuenta para el bono de puntos.
final class AplicarEstadoJefe extends Evento {
  final int jugador;
  final EstadoDelJefe estado;

  const AplicarEstadoJefe({required this.jugador, required this.estado});
}

/// Termina el turno del jefe y empieza la ronda siguiente. Antes se hace el
/// chequeo de estados del jefe (D-12): veneno, quemadura y, si está quemado,
/// la moneda.
final class FinTurnoJefe extends Evento {
  /// Resultado de la moneda de la quemadura: true = cara (se quita la
  /// quemadura), false = cruz (se mantiene). Obligatorio si el jefe está
  /// quemado y no se admite si no lo está. La app la tira y la registra para
  /// que reproducir el registro dé siempre el mismo resultado.
  final bool? monedaQuemadura;

  const FinTurnoJefe({this.monedaQuemadura});
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

/// La mesa resuelve un intento de invocación sin aliado (no quedan slots
/// libres). Desde T-69 la llamada ya no depende de una moneda.
final class SinInvocacion extends Evento {
  const SinInvocacion();
}

/// Categoría de un aliado del jefe (D-13). Cada jefe tiene un aliado por
/// categoría y no puede haber dos de la misma categoría a la vez.
enum CategoriaAliado {
  /// Ataca fuerte: amenaza directa para los jugadores.
  danio,

  /// Protege al jefe y a su bando (reducción de daño, escudo).
  tanque,

  /// Curandero: cura al jefe o a otros aliados, quita estados. (El id sigue
  /// siendo `cura` por compatibilidad con los registros guardados.)
  cura,

  /// Estados alterados, contadores de daño y limitar las acciones de los
  /// jugadores. Antes se llamaba Pícaro; es el único que ataca a la Banca.
  control,

  /// Mejora al jefe y a los aliados (más daño, defensa o velocidad).
  potenciador,

  /// Reduce al jugador: su daño, su defensa o sus ventajas.
  debilitador,
}

/// Quién aplica los efectos de la carta de un aliado (D-13).
enum EfectosAliado {
  /// Los resuelve la mesa; el asistente solo los registra.
  jugador,

  /// Los ejecuta el programa con un script identificado por `scriptId`.
  programa,
}

/// La mesa resuelve un intento de invocación con un aliado nuevo en [slot] y
/// de la categoría [categoria] (D-13). Los dos salen de dados que tira la mesa
/// sin repetir slots ni categorías en uso.
/// [ataqueDano] null: el aliado no tiene ataque.
/// [efectos] indica quién aplica los efectos de su carta; si es
/// [EfectosAliado.programa], [scriptId] es el script que los ejecuta.
final class AliadoInvocado extends Evento {
  final int slot;
  final CategoriaAliado categoria;
  final String nombre;
  final int hp;
  final String? ataqueNombre;
  final int? ataqueDano;
  final String? habilidad;
  final EfectosAliado efectos;
  final String? scriptId;

  /// Monedas que lanza la app al entrar el aliado, en orden (true = cara),
  /// para los scripts que las usan (Deseo): el motor es determinista y solo
  /// reproduce el resultado registrado.
  final List<bool>? monedas;

  const AliadoInvocado({
    required this.slot,
    required this.categoria,
    required this.nombre,
    required this.hp,
    this.ataqueNombre,
    this.ataqueDano,
    this.habilidad,
    this.efectos = EfectosAliado.jugador,
    this.scriptId,
    this.monedas,
  });
}

/// Ataque de un aliado: al entrar y una vez en cada turno del jefe.
/// [objetivo] null: ataca al dueño de su slot. Si el dueño está eliminado
/// hay que indicar el jugador activo que salió en la tirada.
/// Si el objetivo está KO el ataque falla: el evento se acepta, gasta el
/// ataque del aliado, pero no cuenta como uso ni dispara sus efectos.
final class AtaqueAliado extends Evento {
  final int slot;
  final int dano;
  final int? objetivo;

  /// Resultado de la moneda que lanza el jugador rival cuando el ataque la
  /// lleva (Fuerza Lunar): true = cara, false = cruz.
  final bool? moneda;

  const AtaqueAliado({
    required this.slot,
    required this.dano,
    this.objetivo,
    this.moneda,
  });
}
