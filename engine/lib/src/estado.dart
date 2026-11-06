import 'eventos.dart';
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

  /// Cada cuántos HP perdidos hay un intento de invocar un aliado (D-04 §7).
  /// null: el jefe nunca invoca.
  final int? invocacionCadaHp;

  /// Veneno (permanente) y quemadura del jefe (D-12).
  final bool envenenado;
  final bool quemado;

  const JefeEstado({
    required this.nombre,
    required this.nivel,
    required this.hpMaximo,
    required this.hp,
    this.invocacionCadaHp,
    this.envenenado = false,
    this.quemado = false,
  });

  JefeEstado conHp(int nuevoHp) => JefeEstado(
        nombre: nombre,
        nivel: nivel,
        hpMaximo: hpMaximo,
        hp: nuevoHp,
        invocacionCadaHp: invocacionCadaHp,
        envenenado: envenenado,
        quemado: quemado,
      );

  JefeEstado conEstados({bool? envenenado, bool? quemado}) => JefeEstado(
        nombre: nombre,
        nivel: nivel,
        hpMaximo: hpMaximo,
        hp: hp,
        invocacionCadaHp: invocacionCadaHp,
        envenenado: envenenado ?? this.envenenado,
        quemado: quemado ?? this.quemado,
      );

  Map<String, Object?> toJson() => {
        'nombre': nombre,
        'nivel': nivel,
        'hpMaximo': hpMaximo,
        'hp': hp,
        'invocacionCadaHp': invocacionCadaHp,
        'envenenado': envenenado,
        'quemado': quemado,
      };
}

/// Aliado invocado por el jefe, en el slot de un jugador (D-04).
class AliadoEstado {
  /// Asiento del jugador dueño del slot.
  final int slot;

  /// Categoría del aliado (D-13): no hay dos vivos de la misma categoría.
  final CategoriaAliado categoria;
  final String nombre;
  final int hpMaximo;
  final int hp;
  final String? ataqueNombre;

  /// Daño de su único ataque. null: el aliado no ataca (solo habilidad).
  final int? ataqueDano;
  final String? habilidad;

  /// Quién aplica los efectos de su carta, y el script si lo hace el programa.
  final EfectosAliado efectos;
  final String? scriptId;

  /// Ya usó su ataque y/o habilidad al entrar.
  final bool entradaResuelta;

  /// Ya atacó en el turno del jefe actual.
  final bool atacoEnTurnoJefe;

  const AliadoEstado({
    required this.slot,
    required this.categoria,
    required this.nombre,
    required this.hpMaximo,
    required this.hp,
    this.ataqueNombre,
    this.ataqueDano,
    this.habilidad,
    this.efectos = EfectosAliado.jugador,
    this.scriptId,
    this.entradaResuelta = false,
    this.atacoEnTurnoJefe = false,
  });

  bool get tieneAtaque => ataqueDano != null;

  AliadoEstado copiarCon({
    int? hp,
    bool? entradaResuelta,
    bool? atacoEnTurnoJefe,
  }) =>
      AliadoEstado(
        slot: slot,
        categoria: categoria,
        nombre: nombre,
        hpMaximo: hpMaximo,
        hp: hp ?? this.hp,
        ataqueNombre: ataqueNombre,
        ataqueDano: ataqueDano,
        habilidad: habilidad,
        efectos: efectos,
        scriptId: scriptId,
        entradaResuelta: entradaResuelta ?? this.entradaResuelta,
        atacoEnTurnoJefe: atacoEnTurnoJefe ?? this.atacoEnTurnoJefe,
      );

  Map<String, Object?> toJson() => {
        'slot': slot,
        'categoria': categoria.name,
        'nombre': nombre,
        'hpMaximo': hpMaximo,
        'hp': hp,
        'ataqueNombre': ataqueNombre,
        'ataqueDano': ataqueDano,
        'habilidad': habilidad,
        'efectos': efectos.name,
        'scriptId': scriptId,
        'entradaResuelta': entradaResuelta,
        'atacoEnTurnoJefe': atacoEnTurnoJefe,
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

  /// Daño que el veneno y la quemadura han hecho al jefe (D-12). No se
  /// atribuye a ningún jugador.
  final int danoEstados;

  /// Veces que cada jugador (por asiento) ha aplicado un estado que el jefe no
  /// tenía; cuentan para el bono de puntos (D-12).
  final List<int> estadosAplicados;

  /// Curación efectiva acumulada del jefe (lo que subió de verdad, sin pasar
  /// del máximo). El daño bruto menos esta cifra es la vida que ha perdido.
  final int curacionJefe;

  /// Aliados vivos, en el orden en que fueron invocados.
  final List<AliadoEstado> aliados;

  /// Aliados derrotados en la partida (para estadísticas).
  final int aliadosDerrotados;

  /// Umbrales de invocación ya cruzados. Cada umbral cuenta una sola vez
  /// por partida aunque el jefe se cure y vuelva a cruzarlo.
  final int umbralesCruzados;

  /// Intentos de invocación que la mesa aún tiene que resolver.
  final int intentosInvocacionPendientes;
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
    required this.danoEstados,
    required List<int> estadosAplicados,
    required this.curacionJefe,
    required List<AliadoEstado> aliados,
    required this.aliadosDerrotados,
    required this.umbralesCruzados,
    required this.intentosInvocacionPendientes,
    required this.resultado,
  })  : jugadores = _fija(jugadores),
        orden = _fija(orden),
        prioridad = _fija(prioridad),
        cartasAnimoPendientes = _fija(cartasAnimoPendientes),
        cartasAnimo = _fija(cartasAnimo),
        danoPorJugador = _fija(danoPorJugador),
        estadosAplicados = _fija(estadosAplicados),
        aliados = _fija(aliados);

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
        danoEstados: 0,
        estadosAplicados: const [],
        curacionJefe: 0,
        aliados: const [],
        aliadosDerrotados: 0,
        umbralesCruzados: 0,
        intentosInvocacionPendientes: 0,
        resultado: null,
      );

  /// Jugador al que le toca actuar, o null si no es el turno de jugadores.
  int? get jugadorActual =>
      fase == Fase.turnoJugadores && turnoActual < orden.length
          ? orden[turnoActual]
          : null;

  bool get terminada => fase == Fase.terminada;

  /// Aliado vivo en el slot del jugador [slot], o null.
  AliadoEstado? aliadoEn(int slot) {
    for (final a in aliados) {
      if (a.slot == slot) return a;
    }
    return null;
  }

  /// Slots de jugadores activos que no tienen aliado.
  List<int> get slotsLibres => [
        for (final j in jugadores)
          if (!j.eliminado && aliadoEn(j.asiento) == null) j.asiento,
      ];

  /// Categorías sin aliado vivo (D-13): son las que puede elegir el dado.
  List<CategoriaAliado> get categoriasLibres => [
        for (final c in CategoriaAliado.values)
          if (!aliados.any((a) => a.categoria == c)) c,
      ];

  /// Un jugador con un aliado vivo en su slot no puede dañar al jefe.
  bool estaBloqueado(int jugador) => aliadoEn(jugador) != null;

  /// Aliados con ataque que aún no han usado su ataque al entrar.
  List<AliadoEstado> get entradasPendientes => [
        for (final a in aliados)
          if (a.tieneAtaque && !a.entradaResuelta) a,
      ];

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
    int? danoEstados,
    List<int>? estadosAplicados,
    int? curacionJefe,
    List<AliadoEstado>? aliados,
    int? aliadosDerrotados,
    int? umbralesCruzados,
    int? intentosInvocacionPendientes,
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
        danoEstados: danoEstados ?? this.danoEstados,
        estadosAplicados: estadosAplicados ?? this.estadosAplicados,
        curacionJefe: curacionJefe ?? this.curacionJefe,
        aliados: aliados ?? this.aliados,
        aliadosDerrotados: aliadosDerrotados ?? this.aliadosDerrotados,
        umbralesCruzados: umbralesCruzados ?? this.umbralesCruzados,
        intentosInvocacionPendientes:
            intentosInvocacionPendientes ?? this.intentosInvocacionPendientes,
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
        'danoEstados': danoEstados,
        'estadosAplicados': estadosAplicados,
        'curacionJefe': curacionJefe,
        'aliados': [for (final a in aliados) a.toJson()],
        'aliadosDerrotados': aliadosDerrotados,
        'umbralesCruzados': umbralesCruzados,
        'intentosInvocacionPendientes': intentosInvocacionPendientes,
        'resultado': resultado?.name,
      };
}
