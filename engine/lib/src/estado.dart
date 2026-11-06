import 'reglas.dart';

/// Fase en la que está la partida.
enum Fase {
  /// Falta indicar los jugadores y su mejor ataque.
  preparacion,

  /// X y el nivel ya están calculados; falta elegir el jefe.
  eleccionJefe,

  /// Los jugadores actúan en su orden de la ronda.
  turnoJugadores,

  /// Ataca el jefe y se registran los KO.
  turnoJefe,

  /// La partida ha terminado (ver [EstadoPartida.resultado]).
  terminada,
}

enum Resultado { victoria, derrota }

/// Estado de un jugador. Solo lleva lo que el asistente necesita:
/// los Pokémon que le quedan (el HP de los Pokémon vive en la mesa).
class JugadorEstado {
  /// Posición en la mesa (0 a 3). El orden de turno usa el asiento.
  final int asiento;
  final String nombre;

  /// Daño de su mejor ataque, ya recortado al tope de X.
  final int ataqueMaximo;

  /// Pokémon que le quedan en juego (2 al empezar).
  final int pokemonVivos;

  const JugadorEstado({
    required this.asiento,
    required this.nombre,
    required this.ataqueMaximo,
    this.pokemonVivos = pokemonPorJugador,
  });

  /// Un jugador queda eliminado solo cuando no le queda ningún Pokémon.
  bool get eliminado => pokemonVivos <= 0;

  int get pokemonPerdidos => pokemonPorJugador - pokemonVivos;

  JugadorEstado conPokemonVivos(int vivos) => JugadorEstado(
        asiento: asiento,
        nombre: nombre,
        ataqueMaximo: ataqueMaximo,
        pokemonVivos: vivos,
      );

  Map<String, Object?> toJson() => {
        'asiento': asiento,
        'nombre': nombre,
        'ataqueMaximo': ataqueMaximo,
        'pokemonVivos': pokemonVivos,
      };
}

/// Estado del jefe: carta fija del catálogo, con su HP actual.
class JefeEstado {
  final String nombre;
  final int nivel;
  final int hpMaximo;
  final int hp;

  const JefeEstado({
    required this.nombre,
    required this.nivel,
    required this.hpMaximo,
    required this.hp,
  });

  JefeEstado conHp(int nuevoHp) => JefeEstado(
        nombre: nombre,
        nivel: nivel,
        hpMaximo: hpMaximo,
        hp: nuevoHp,
      );

  Map<String, Object?> toJson() => {
        'nombre': nombre,
        'nivel': nivel,
        'hpMaximo': hpMaximo,
        'hp': hp,
      };
}

/// Registro de una carta de ánimo robada (el efecto se resuelve en la mesa).
class RegistroCartaAnimo {
  final int ronda;
  final int jugador;
  final int carta;

  const RegistroCartaAnimo({
    required this.ronda,
    required this.jugador,
    required this.carta,
  });

  Map<String, Object?> toJson() =>
      {'ronda': ronda, 'jugador': jugador, 'carta': carta};
}

List<T> _fija<T>(List<T> lista) => List<T>.unmodifiable(lista);

/// Estado completo e inmutable de una partida.
///
/// Solo cambia al aplicar un evento con `apply` (ver `motor.dart`).
class EstadoPartida {
  final Fase fase;
  final List<JugadorEstado> jugadores;

  /// Suma del mejor ataque de cada jugador (0 hasta configurar la partida).
  final int x;

  /// Nivel del jefe (0 hasta configurar la partida).
  final int nivel;
  final JefeEstado? jefe;

  /// Ronda actual, empezando en 1 (0 antes de empezar).
  final int ronda;

  /// Asientos de los jugadores en el orden de actuación de la ronda.
  final List<int> orden;

  /// Posición dentro de [orden] del jugador al que le toca.
  final int turnoActual;

  /// Jugadores con un Pokémon activo KO que actuarán primero la ronda siguiente.
  final List<int> prioridad;

  /// Jugadores de esta ronda que todavía no han robado su carta de ánimo.
  final List<int> cartasAnimoPendientes;
  final List<RegistroCartaAnimo> cartasAnimo;

  /// Ataques del jefe registrados en el turno del jefe actual.
  final int ataquesJefeEnTurno;

  /// Daño aplicado al jefe por cada jugador (por asiento), para los puntos.
  final List<int> danoPorJugador;

  /// Curación efectiva acumulada del jefe (lo que subió de verdad, sin pasar
  /// del máximo). El daño bruto menos esta cifra es la vida que ha perdido.
  final int curacionJefe;
  final Resultado? resultado;

  EstadoPartida({
    required this.fase,
    required List<JugadorEstado> jugadores,
    required this.x,
    required this.nivel,
    required this.jefe,
    required this.ronda,
    required List<int> orden,
    required this.turnoActual,
    required List<int> prioridad,
    required List<int> cartasAnimoPendientes,
    required List<RegistroCartaAnimo> cartasAnimo,
    required this.ataquesJefeEnTurno,
    required List<int> danoPorJugador,
    required this.curacionJefe,
    required this.resultado,
  })  : jugadores = _fija(jugadores),
        orden = _fija(orden),
        prioridad = _fija(prioridad),
        cartasAnimoPendientes = _fija(cartasAnimoPendientes),
        cartasAnimo = _fija(cartasAnimo),
        danoPorJugador = _fija(danoPorJugador);

  /// Estado de una partida recién creada, sin jugadores.
  factory EstadoPartida.inicial() => EstadoPartida(
        fase: Fase.preparacion,
        jugadores: const [],
        x: 0,
        nivel: 0,
        jefe: null,
        ronda: 0,
        orden: const [],
        turnoActual: 0,
        prioridad: const [],
        cartasAnimoPendientes: const [],
        cartasAnimo: const [],
        ataquesJefeEnTurno: 0,
        danoPorJugador: const [],
        curacionJefe: 0,
        resultado: null,
      );

  /// Jugador al que le toca actuar, o null si no es el turno de jugadores.
  int? get jugadorActual =>
      fase == Fase.turnoJugadores && turnoActual < orden.length
          ? orden[turnoActual]
          : null;

  bool get terminada => fase == Fase.terminada;

  /// Copia con cambios. Los campos que no se indican se mantienen.
  EstadoPartida copiarCon({
    Fase? fase,
    List<JugadorEstado>? jugadores,
    int? x,
    int? nivel,
    JefeEstado? jefe,
    int? ronda,
    List<int>? orden,
    int? turnoActual,
    List<int>? prioridad,
    List<int>? cartasAnimoPendientes,
    List<RegistroCartaAnimo>? cartasAnimo,
    int? ataquesJefeEnTurno,
    List<int>? danoPorJugador,
    int? curacionJefe,
    Resultado? resultado,
  }) =>
      EstadoPartida(
        fase: fase ?? this.fase,
        jugadores: jugadores ?? this.jugadores,
        x: x ?? this.x,
        nivel: nivel ?? this.nivel,
        jefe: jefe ?? this.jefe,
        ronda: ronda ?? this.ronda,
        orden: orden ?? this.orden,
        turnoActual: turnoActual ?? this.turnoActual,
        prioridad: prioridad ?? this.prioridad,
        cartasAnimoPendientes:
            cartasAnimoPendientes ?? this.cartasAnimoPendientes,
        cartasAnimo: cartasAnimo ?? this.cartasAnimo,
        ataquesJefeEnTurno: ataquesJefeEnTurno ?? this.ataquesJefeEnTurno,
        danoPorJugador: danoPorJugador ?? this.danoPorJugador,
        curacionJefe: curacionJefe ?? this.curacionJefe,
        resultado: resultado ?? this.resultado,
      );

  /// Representación simple, útil para comparar estados en los tests.
  Map<String, Object?> toJson() => {
        'fase': fase.name,
        'jugadores': [for (final j in jugadores) j.toJson()],
        'x': x,
        'nivel': nivel,
        'jefe': jefe?.toJson(),
        'ronda': ronda,
        'orden': orden,
        'turnoActual': turnoActual,
        'prioridad': prioridad,
        'cartasAnimoPendientes': cartasAnimoPendientes,
        'cartasAnimo': [for (final c in cartasAnimo) c.toJson()],
        'ataquesJefeEnTurno': ataquesJefeEnTurno,
        'danoPorJugador': danoPorJugador,
        'curacionJefe': curacionJefe,
        'resultado': resultado?.name,
      };
}
