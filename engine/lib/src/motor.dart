import 'errores.dart';
import 'estado.dart';
import 'eventos.dart';
import 'reglas.dart';

/// Aplica un evento al estado y devuelve un estado nuevo.
///
/// No modifica el estado recibido. Si el evento no es válido en este momento
/// lanza [ReglaIncumplida] y el estado queda como estaba.
EstadoPartida apply(EstadoPartida estado, Evento evento) {
  return switch (evento) {
    ConfigurarJugadores ev => _configurar(estado, ev),
    ElegirJefe ev => _elegirJefe(estado, ev),
    TurnoJugador ev => _turnoJugador(estado, ev),
    AtaqueJefe ev => _ataqueJefe(estado, ev),
    PokemonKo ev => _pokemonKo(estado, ev),
    CartaAnimoRobada ev => _cartaAnimo(estado, ev),
    FinTurnoJefe() => _finTurnoJefe(estado),
    CuracionJefe ev => _curacionJefe(estado, ev),
    Abandonar() => _abandonar(estado),
  };
}

/// Reproduce una lista de eventos desde el estado inicial (o desde [desde]).
EstadoPartida reproducir(Iterable<Evento> eventos, {EstadoPartida? desde}) {
  var estado = desde ?? EstadoPartida.inicial();
  for (final evento in eventos) {
    estado = apply(estado, evento);
  }
  return estado;
}

/// Partida con su registro de eventos. Es un valor inmutable: aplicar un
/// evento devuelve una partida nueva con el evento añadido al registro.
class Partida {
  final EstadoPartida estado;
  final List<Evento> eventos;

  Partida._(this.estado, List<Evento> eventos)
      : eventos = List<Evento>.unmodifiable(eventos);

  /// Partida nueva, sin eventos.
  factory Partida.nueva() => Partida._(EstadoPartida.inicial(), const []);

  /// Reconstruye una partida a partir de su registro de eventos.
  factory Partida.desdeEventos(Iterable<Evento> eventos) {
    final lista = List<Evento>.of(eventos);
    return Partida._(reproducir(lista), lista);
  }

  Partida aplicar(Evento evento) =>
      Partida._(apply(estado, evento), [...eventos, evento]);
}

// ---------------------------------------------------------------------------
// Reglas por evento
// ---------------------------------------------------------------------------

Never _error(String mensaje) => throw ReglaIncumplida(mensaje);

void _exigeFase(EstadoPartida e, Fase fase, String evento) {
  if (e.fase != fase) {
    _error('$evento no es válido en la fase ${e.fase.name}');
  }
}

void _exigeJugador(EstadoPartida e, int jugador) {
  if (jugador < 0 || jugador >= e.jugadores.length) {
    _error('el jugador $jugador no existe');
  }
  if (e.jugadores[jugador].eliminado) {
    _error('el jugador $jugador está eliminado');
  }
}

EstadoPartida _configurar(EstadoPartida e, ConfigurarJugadores ev) {
  _exigeFase(e, Fase.preparacion, 'ConfigurarJugadores');
  final n = ev.jugadores.length;
  if (n < 1 || n > maxJugadores) {
    _error('la partida admite de 1 a $maxJugadores jugadores, no $n');
  }
  final jugadores = <JugadorEstado>[];
  for (var i = 0; i < n; i++) {
    final cfg = ev.jugadores[i];
    if (cfg.ataqueMaximo < 0) {
      _error('el daño del mejor ataque de ${cfg.nombre} no puede ser negativo');
    }
    jugadores.add(JugadorEstado(
      asiento: i,
      nombre: cfg.nombre,
      ataqueMaximo: ataqueParaX(cfg.ataqueMaximo),
    ));
  }
  final x = jugadores.fold<int>(0, (suma, j) => suma + j.ataqueMaximo);
  return e.copiarCon(
    fase: Fase.eleccionJefe,
    jugadores: jugadores,
    x: x,
    nivel: nivelPorX(x),
    danoPorJugador: List<int>.filled(n, 0),
  );
}

EstadoPartida _elegirJefe(EstadoPartida e, ElegirJefe ev) {
  _exigeFase(e, Fase.eleccionJefe, 'ElegirJefe');
  if (ev.nivel != e.nivel) {
    _error('el jefe es de nivel ${ev.nivel} y la partida es de nivel ${e.nivel}');
  }
  if (ev.hp <= 0) {
    _error('el HP del jefe debe ser mayor que 0');
  }
  final conJefe = e.copiarCon(
    jefe: JefeEstado(
      nombre: ev.nombre,
      nivel: ev.nivel,
      hpMaximo: ev.hp,
      hp: ev.hp,
    ),
  );
  return _empezarRonda(conJefe);
}

/// Prepara la ronda siguiente. Actúan primero los jugadores con KO pendiente
/// (por orden de asiento) y después el resto (por orden de asiento).
EstadoPartida _empezarRonda(EstadoPartida e) {
  final vivos = [
    for (final j in e.jugadores)
      if (!j.eliminado) j.asiento,
  ];
  final primeros = [
    for (final a in vivos)
      if (e.prioridad.contains(a)) a,
  ];
  final resto = [
    for (final a in vivos)
      if (!e.prioridad.contains(a)) a,
  ];
  return e.copiarCon(
    fase: Fase.turnoJugadores,
    ronda: e.ronda + 1,
    orden: [...primeros, ...resto],
    turnoActual: 0,
    prioridad: const [],
    cartasAnimoPendientes: primeros,
    ataquesJefeEnTurno: 0,
  );
}

/// Avanza al siguiente jugador que siga en juego. Si ya no quedan,
/// pasa al turno del jefe.
EstadoPartida _avanzarTurno(EstadoPartida e, int desde) {
  var i = desde;
  while (i < e.orden.length && e.jugadores[e.orden[i]].eliminado) {
    i++;
  }
  if (i >= e.orden.length) {
    return e.copiarCon(
      fase: Fase.turnoJefe,
      turnoActual: e.orden.length,
      ataquesJefeEnTurno: 0,
    );
  }
  return e.copiarCon(turnoActual: i);
}

EstadoPartida _turnoJugador(EstadoPartida e, TurnoJugador ev) {
  _exigeFase(e, Fase.turnoJugadores, 'TurnoJugador');
  _exigeJugador(e, ev.jugador);
  if (e.jugadorActual != ev.jugador) {
    _error('no es el turno del jugador ${ev.jugador}');
  }
  if (ev.dano < 0) {
    _error('el daño no puede ser negativo');
  }
  final jefe = e.jefe!;
  // El daño que cuenta es el que de verdad resta HP al jefe.
  final aplicado = ev.dano < jefe.hp ? ev.dano : jefe.hp;
  final dano = [...e.danoPorJugador];
  dano[ev.jugador] += aplicado;
  final nuevoHp = jefe.hp - aplicado;
  final conDano = e.copiarCon(jefe: jefe.conHp(nuevoHp), danoPorJugador: dano);
  if (nuevoHp <= 0) {
    return conDano.copiarCon(
      fase: Fase.terminada,
      resultado: Resultado.victoria,
    );
  }
  return _avanzarTurno(conDano, e.turnoActual + 1);
}

EstadoPartida _ataqueJefe(EstadoPartida e, AtaqueJefe ev) {
  _exigeFase(e, Fase.turnoJefe, 'AtaqueJefe');
  if (ev.ranura < 1 || ev.ranura > ranurasAtaqueJefe) {
    _error('la ranura de ataque debe estar entre 1 y $ranurasAtaqueJefe');
  }
  if (ev.dano < 0) {
    _error('el daño no puede ser negativo');
  }
  final objetivo = ev.jugador;
  if (objetivo != null) {
    _exigeJugador(e, objetivo);
  }
  return e.copiarCon(ataquesJefeEnTurno: e.ataquesJefeEnTurno + 1);
}

EstadoPartida _pokemonKo(EstadoPartida e, PokemonKo ev) {
  if (e.fase != Fase.turnoJefe && e.fase != Fase.turnoJugadores) {
    _error('PokemonKo no es válido en la fase ${e.fase.name}');
  }
  _exigeJugador(e, ev.jugador);
  final jugador = e.jugadores[ev.jugador];
  final vivos = jugador.pokemonVivos - 1;
  final jugadores = [...e.jugadores];
  jugadores[ev.jugador] = jugador.conPokemonVivos(vivos);
  var nuevo = e.copiarCon(jugadores: jugadores);

  if (vivos > 0) {
    // Le queda un Pokémon: asciende la banca y gana prioridad la ronda
    // siguiente (una sola vez, aunque caigan varios).
    if (!nuevo.prioridad.contains(ev.jugador)) {
      nuevo = nuevo.copiarCon(prioridad: [...nuevo.prioridad, ev.jugador]);
    }
    return nuevo;
  }

  // Queda eliminado: no actúa, no gana prioridad y no roba carta.
  nuevo = nuevo.copiarCon(
    prioridad: [for (final a in nuevo.prioridad) if (a != ev.jugador) a],
    cartasAnimoPendientes: [
      for (final a in nuevo.cartasAnimoPendientes)
        if (a != ev.jugador) a,
    ],
  );
  if (jugadores.every((j) => j.eliminado)) {
    return nuevo.copiarCon(
      fase: Fase.terminada,
      resultado: Resultado.derrota,
    );
  }
  if (nuevo.fase == Fase.turnoJugadores) {
    // Si era el jugador al que le tocaba, se salta su turno.
    return _avanzarTurno(nuevo, nuevo.turnoActual);
  }
  return nuevo;
}

EstadoPartida _cartaAnimo(EstadoPartida e, CartaAnimoRobada ev) {
  if (e.fase != Fase.turnoJugadores) {
    _error('CartaAnimoRobada solo es válida en el turno de jugadores');
  }
  _exigeJugador(e, ev.jugador);
  if (ev.carta < 1 || ev.carta > cartasAnimoTotal) {
    _error('la carta de ánimo debe estar entre 1 y $cartasAnimoTotal');
  }
  if (!e.cartasAnimoPendientes.contains(ev.jugador)) {
    _error('el jugador ${ev.jugador} no tiene carta de ánimo pendiente');
  }
  return e.copiarCon(
    cartasAnimoPendientes: [
      for (final a in e.cartasAnimoPendientes)
        if (a != ev.jugador) a,
    ],
    cartasAnimo: [
      ...e.cartasAnimo,
      RegistroCartaAnimo(
        ronda: e.ronda,
        jugador: ev.jugador,
        carta: ev.carta,
      ),
    ],
  );
}

EstadoPartida _finTurnoJefe(EstadoPartida e) {
  _exigeFase(e, Fase.turnoJefe, 'FinTurnoJefe');
  return _empezarRonda(e);
}

EstadoPartida _abandonar(EstadoPartida e) {
  if (e.fase != Fase.turnoJugadores && e.fase != Fase.turnoJefe) {
    _error('Abandonar no es válido en la fase ${e.fase.name}');
  }
  return e.copiarCon(
    fase: Fase.terminada,
    resultado: Resultado.derrota,
    prioridad: const [],
    cartasAnimoPendientes: const [],
  );
}

EstadoPartida _curacionJefe(EstadoPartida e, CuracionJefe ev) {
  if (e.fase != Fase.turnoJefe && e.fase != Fase.turnoJugadores) {
    _error('CuracionJefe no es válido en la fase ${e.fase.name}');
  }
  if (ev.cantidad < 0) {
    _error('la curación no puede ser negativa');
  }
  final jefe = e.jefe!;
  final falta = jefe.hpMaximo - jefe.hp;
  final efectiva = ev.cantidad < falta ? ev.cantidad : falta;
  return e.copiarCon(
    jefe: jefe.conHp(jefe.hp + efectiva),
    curacionJefe: e.curacionJefe + efectiva,
  );
}
