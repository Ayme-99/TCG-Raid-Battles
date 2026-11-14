import 'errores.dart';
import 'estado.dart';
import 'eventos.dart';
import 'reglas.dart';
import 'scripts_aliado.dart';

/// Aplica un evento al estado y devuelve un estado nuevo.
///
/// No modifica el estado recibido. Si el evento no es válido en este momento
/// lanza [ReglaIncumplida] y el estado queda como estaba.
///
/// [scripts] son los efectos de aliados que ejecuta el programa (D-13).
EstadoPartida apply(
  EstadoPartida estado,
  Evento evento, {
  Map<String, ScriptAliado> scripts = scriptsAliado,
}) {
  final nuevo = _aplicar(estado, evento, scripts);
  // Un KO justo después de un ataque de aliado en el turno de los jugadores
  // lo ha causado ese ataque; cualquier otro evento corta la racha.
  final racha = switch (evento) {
    AtaqueAliado() => nuevo.fase == Fase.turnoJugadores,
    PokemonKo() => estado.koTrasAtaqueAliado && nuevo.fase == Fase.turnoJugadores,
    _ => false,
  };
  return racha == nuevo.koTrasAtaqueAliado
      ? nuevo
      : nuevo.copiarCon(koTrasAtaqueAliado: racha);
}

EstadoPartida _aplicar(
  EstadoPartida estado,
  Evento evento,
  Map<String, ScriptAliado> scripts,
) {
  return switch (evento) {
    ConfigurarJugadores ev => _configurar(estado, ev),
    ElegirJefe ev => _elegirJefe(estado, ev),
    TurnoJugador ev => _turnoJugador(estado, ev, scripts),
    AtaqueJefe ev => _ataqueJefe(estado, ev),
    PokemonKo ev => _pokemonKo(estado, ev),
    CartaAnimoRobada ev => _cartaAnimo(estado, ev),
    FinTurnoJefe ev => _finTurnoJefe(estado, ev, scripts),
    AplicarEstadoJefe ev => _aplicarEstadoJefe(estado, ev, scripts),
    AplicarEstadoAliado ev => _aplicarEstadoAliado(estado, ev, scripts),
    CuracionJefe ev => _curacionJefe(estado, ev),
    DanoDeEfecto ev => _danoDeEfecto(estado, ev),
    AtaqueAAliado ev => _ataqueAAliado(estado, ev, scripts),
    SinInvocacion() => _sinInvocacion(estado),
    AliadoInvocado ev => _aliadoInvocado(estado, ev, scripts),
    AtaqueAliado ev => _ataqueAliado(estado, ev, scripts),
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

/// Antes de seguir con la partida hay que resolver los intentos de
/// invocación y los ataques de entrada de los aliados.
void _exigeSinPendientes(EstadoPartida e, String evento) {
  if (e.intentosInvocacionPendientes > 0) {
    _error('$evento: quedan ${e.intentosInvocacionPendientes} intentos de '
        'invocación por resolver');
  }
  if (e.entradasPendientes.isNotEmpty) {
    _error('$evento: hay aliados que aún no han usado su ataque al entrar');
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
      pokemonTotal: pokemonPorJugadorSegun(n),
    ));
  }
  final x = jugadores.fold<int>(0, (suma, j) => suma + j.ataqueMaximo);
  return e.copiarCon(
    fase: Fase.eleccionJefe,
    jugadores: jugadores,
    x: x,
    nivel: nivelPorX(x),
    danoPorJugador: List<int>.filled(n, 0),
    estadosAplicados: List<int>.filled(n, 0),
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
  final cada = ev.invocacionCadaHp;
  if (cada != null && cada <= 0) {
    _error('los HP entre intentos de invocación deben ser mayores que 0');
  }
  final conJefe = e.copiarCon(
    jefe: JefeEstado(
      nombre: ev.nombre,
      nivel: ev.nivel,
      hpMaximo: ev.hp,
      hp: ev.hp,
      invocacionCadaHp: cada,
    ),
  );
  return _empezarRonda(conJefe);
}

/// Prepara la ronda siguiente. Los jugadores con un Pokémon KO se sientan
/// su turno (solo roban carta de ánimo, fuera de la app: TODO); actúan los
/// demás por orden de asiento. Si no queda nadie que actúe, pasa directo al
/// turno del jefe.
EstadoPartida _empezarRonda(EstadoPartida e) {
  final vivos = [
    for (final j in e.jugadores)
      if (!j.eliminado) j.asiento,
  ];
  final sentados = [
    for (final a in vivos)
      if (e.prioridad.contains(a)) a,
  ];
  final actuan = [
    for (final a in vivos)
      if (!e.prioridad.contains(a)) a,
  ];
  final nuevo = e.copiarCon(
    fase: Fase.turnoJugadores,
    ronda: e.ronda + 1,
    orden: actuan,
    turnoActual: 0,
    prioridad: const [],
    cartasAnimoPendientes: sentados,
    ataquesJefeEnTurno: 0,
    aliados: [
      for (final a in e.aliados) a.copiarCon(atacoEnTurnoJefe: false),
    ],
  );
  return actuan.isEmpty ? _avanzarTurno(nuevo, 0) : nuevo;
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
      efectosActivos: _caducarEfectos(e.efectosActivos),
    );
  }
  return e.copiarCon(turnoActual: i);
}

EstadoPartida _turnoJugador(
  EstadoPartida e,
  TurnoJugador ev,
  Map<String, ScriptAliado> scripts,
) {
  _exigeFase(e, Fase.turnoJugadores, 'TurnoJugador');
  _exigeSinPendientes(e, 'TurnoJugador');
  _exigeJugador(e, ev.jugador);
  if (e.jugadorActual != ev.jugador) {
    _error('no es el turno del jugador ${ev.jugador}');
  }
  if (ev.dano < 0) {
    _error('el daño no puede ser negativo');
  }
  final provocador = aliadoProvocador(e, scripts);
  if (ev.dano > 0 && provocador != null) {
    _error('${provocador.nombre} obliga a atacarle: ataca al aliado o pasa el '
        'turno con 0 de daño');
  }
  final jefe = e.jefe!;
  // El daño anotado es el del ataque; los aliados Tanque (D-13) y la
  // debilitación pendiente del jugador (Fuerza Lunar) le quitan una cantidad
  // fija y lo que cuenta es el que de verdad resta HP al jefe.
  var bruto = ev.dano;
  if (bruto > 0) {
    bruto -= reduccionDanoAlJefe(e, scripts) + (e.debilitados[ev.jugador] ?? 0);
    if (bruto < 0) bruto = 0;
  }
  final aplicado = bruto < jefe.hp ? bruto : jefe.hp;
  final dano = [...e.danoPorJugador];
  dano[ev.jugador] += aplicado;
  final nuevoHp = jefe.hp - aplicado;
  final conDano = e.copiarCon(
    jefe: jefe.conHp(nuevoHp),
    danoPorJugador: dano,
    debilitados: _sinDebilitar(e, ev.jugador),
  );
  if (nuevoHp <= 0) {
    return conDano.copiarCon(
      fase: Fase.terminada,
      resultado: Resultado.victoria,
    );
  }
  return _avanzarTurno(_llamarAliados(conDano), e.turnoActual + 1);
}

/// Máximo de aliados que el jefe puede llamar en una partida (T-69): el
/// nivel más uno.
int maxLlamadasAliado(int nivel) => nivel + 1;

/// Llamadas de aliados del jefe (T-69, corregido en T-71). El jefe llama:
///  - la primera vez, al terminar su turno de la ronda 1, y
///  - después, cada vez que su HP baja a un umbral definido (cada
///    `invocacionCadaHp` HP perdidos; los umbrales ya cruzados cuentan aunque
///    se cruzaran antes de la primera llamada, y una sola vez por partida).
/// Como mucho nivel + 1 llamadas por partida. No las frenan monedas, estados
/// ni objetos, y cada una es un intento que la mesa resuelve con los dados
/// de slot y de categoría (o sin invocación si no cabe).
EstadoPartida _llamarAliados(EstadoPartida e) {
  final jefe = e.jefe;
  final cada = jefe?.invocacionCadaHp;
  if (jefe == null || cada == null) return e;
  // Hasta que no termina el primer turno del jefe no hay primera llamada ni
  // umbrales que contar.
  if (e.ronda < 2) return e;
  final maxUmbrales = (jefe.hpMaximo - 1) ~/ cada;
  var cruzados = (jefe.hpMaximo - jefe.hp) ~/ cada;
  if (cruzados > maxUmbrales) cruzados = maxUmbrales;
  var debidas = 1 + cruzados;
  final tope = maxLlamadasAliado(e.nivel);
  if (debidas > tope) debidas = tope;
  if (debidas <= e.llamadasAliado) return e;
  return e.copiarCon(
    llamadasAliado: debidas,
    intentosInvocacionPendientes:
        e.intentosInvocacionPendientes + (debidas - e.llamadasAliado),
  );
}

/// La debilitación pendiente del jugador se consume en su turno.
Map<int, int> _sinDebilitar(EstadoPartida e, int jugador) =>
    {...e.debilitados}..remove(jugador);

EstadoPartida _ataqueJefe(EstadoPartida e, AtaqueJefe ev) {
  _exigeFase(e, Fase.turnoJefe, 'AtaqueJefe');
  _exigeSinPendientes(e, 'AtaqueJefe');
  if (ev.ranura < 1 || ev.ranura > ranurasAtaqueJefe) {
    _error('la ranura de ataque debe estar entre 1 y $ranurasAtaqueJefe');
  }
  if (ev.dano < 0) {
    _error('el daño no puede ser negativo');
  }
  final objetivo = ev.jugador;
  if (objetivo != null) {
    _exigeJugador(e, objetivo);
    if (e.enKo(objetivo)) {
      _error('el jugador $objetivo está KO: el ataque falla; se descarta la '
          'carta y se roba otra');
    }
  }
  final efecto = ev.efecto;
  if (efecto != null) _validarEfecto(ev, efecto);
  final conAtaque = e.copiarCon(ataquesJefeEnTurno: e.ataquesJefeEnTurno + 1);
  return efecto == null ? conAtaque : _aplicarEfecto(conAtaque, ev, efecto);
}

/// Comprueba que el efecto trae lo que su tipo necesita (D-14).
void _validarEfecto(AtaqueJefe ev, EfectoAtaque ef) {
  final tipo = ef.tipo.name;
  if (ef.valor != null && ef.valor! < 1) {
    _error('el efecto $tipo: el valor debe ser como mínimo 1');
  }
  if (ef.duracion != null && ef.duracion! < 1) {
    _error('el efecto $tipo: la duración debe ser como mínimo 1');
  }
  switch (ef.tipo) {
    case TipoEfectoAtaque.autodano:
    case TipoEfectoAtaque.contadorATodos:
      if (ef.valor == null) _error('el efecto $tipo necesita un valor');
    case TipoEfectoAtaque.autodanoSiKo:
      if (ef.valor == null) _error('el efecto $tipo necesita un valor');
      if (ev.jugador == null) {
        _error('el efecto $tipo necesita el jugador que defiende');
      }
    case TipoEfectoAtaque.sinRetirada:
    case TipoEfectoAtaque.sinAtaque:
    case TipoEfectoAtaque.paralizarDefensor:
      if (ev.jugador == null) {
        _error('el efecto $tipo necesita el jugador que defiende');
      }
    case TipoEfectoAtaque.ignoraEfectos:
    case TipoEfectoAtaque.danoExtraSi:
    case TipoEfectoAtaque.danoPorAtaquePrevio:
      break;
  }
}

/// Aplica el efecto de un ataque del jefe (D-14). Lo que cae en la mesa lo
/// resuelven los jugadores; aquí solo lo que lleva el programa.
EstadoPartida _aplicarEfecto(EstadoPartida e, AtaqueJefe ev, EfectoAtaque ef) {
  switch (ef.tipo) {
    case TipoEfectoAtaque.autodano:
      // Después del daño al jugador. No se atribuye a nadie; a 0 HP termina
      // la partida en victoria.
      final jefe = e.jefe!;
      final aplicado = ef.valor! < jefe.hp ? ef.valor! : jefe.hp;
      final nuevoHp = jefe.hp - aplicado;
      final conDano = e.copiarCon(
        jefe: jefe.conHp(nuevoHp),
        danoEstados: e.danoEstados + aplicado,
      );
      if (nuevoHp <= 0) {
        return conDano.copiarCon(
          fase: Fase.terminada,
          resultado: Resultado.victoria,
        );
      }
      return _llamarAliados(conDano);
    case TipoEfectoAtaque.contadorATodos:
      // Los aliados del jefe reciben los contadores; sin atribuir a nadie.
      final dano = ef.valor! * danoContador;
      final vivos = <AliadoEstado>[];
      var derrotados = 0;
      for (final a in e.aliados) {
        final restante = a.hp - dano;
        if (restante > 0) {
          vivos.add(a.copiarCon(hp: restante));
        } else {
          derrotados++;
        }
      }
      return e.copiarCon(
        aliados: vivos,
        aliadosDerrotados: e.aliadosDerrotados + derrotados,
      );
    case TipoEfectoAtaque.sinRetirada:
    case TipoEfectoAtaque.sinAtaque:
    case TipoEfectoAtaque.paralizarDefensor:
      // Cruz en la moneda: no pasa nada.
      if (ef.moneda == false) return e;
      final nuevo = EfectoActivo(
        tipo: ef.tipo,
        jugador: ev.jugador!,
        restantes: ef.duracion ?? 1,
      );
      return e.copiarCon(efectosActivos: [
        // Repetir el mismo efecto sobre el mismo jugador renueva su duración.
        for (final a in e.efectosActivos)
          if (a.tipo != nuevo.tipo || a.jugador != nuevo.jugador) a,
        nuevo,
      ]);
    case TipoEfectoAtaque.ignoraEfectos:
    case TipoEfectoAtaque.danoExtraSi:
    case TipoEfectoAtaque.danoPorAtaquePrevio:
    case TipoEfectoAtaque.autodanoSiKo:
      // Solo se registra: si hay KO, la mesa lo dice y se registran PokemonKo
      // y DanoDeEfecto.
      return e;
  }
}

/// Al terminar el turno de los jugadores, a cada efecto le queda un turno
/// menos y los que llegan a 0 desaparecen.
List<EfectoActivo> _caducarEfectos(List<EfectoActivo> efectos) => [
      for (final f in efectos)
        if (f.restantes > 1)
          EfectoActivo(
            tipo: f.tipo,
            jugador: f.jugador,
            restantes: f.restantes - 1,
          ),
    ];

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
    // Le queda un Pokémon: asciende la banca y el jugador se sienta su
    // próximo turno (solo roba carta de ánimo).
    // Lo ha dejado KO el ataque de entrada de un aliado (D-13) y todavía no
    // ha actuado esta ronda: ese turno es el que se sienta, así que no se
    // sienta también el de la ronda siguiente; el Pokémon que sube no ataca
    // hasta entonces.
    // También cuenta si la mesa marca el KO antes de registrar el ataque de
    // entrada (aún pendiente): en ese intervalo nada más puede haberlo causado.
    final porAliado =
        e.koTrasAtaqueAliado || e.entradasPendientes.isNotEmpty;
    if (porAliado && nuevo.fase == Fase.turnoJugadores) {
      final pos = nuevo.orden.indexOf(ev.jugador);
      if (pos >= nuevo.turnoActual) {
        nuevo = nuevo.copiarCon(orden: [...nuevo.orden]..removeAt(pos));
        if (pos == nuevo.turnoActual) {
          nuevo = _avanzarTurno(nuevo, nuevo.turnoActual);
        }
        return nuevo;
      }
    }
    // Se sienta el turno de la ronda siguiente (una sola vez, aunque caigan
    // varios).
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

/// Ejecuta el script de cada aliado vivo que lo tenga, en el momento
/// indicado por [momento]. Un script no puede terminar la partida.
EstadoPartida _ejecutarScripts(
  EstadoPartida e,
  Map<String, ScriptAliado> scripts,
  EfectoAliado? Function(ScriptAliado) momento,
) {
  var estado = e;
  for (final aliado in e.aliados) {
    final id = aliado.scriptId;
    if (aliado.efectos != EfectosAliado.programa || id == null) continue;
    final efecto = momento(scripts[id]!);
    if (efecto == null) continue;
    estado = efecto(estado, aliado);
    if (estado.fase != e.fase) {
      _error('el script «$id» no puede terminar la partida');
    }
  }
  return estado;
}

EstadoPartida _finTurnoJefe(
  EstadoPartida e,
  FinTurnoJefe ev,
  Map<String, ScriptAliado> scripts,
) {
  _exigeFase(e, Fase.turnoJefe, 'FinTurnoJefe');
  _exigeSinPendientes(e, 'FinTurnoJefe');
  final jefe = e.jefe!;
  if (jefe.quemado && ev.monedaQuemadura == null) {
    _error('el jefe está quemado: FinTurnoJefe necesita el resultado de la '
        'moneda');
  }
  if (!jefe.quemado && ev.monedaQuemadura != null) {
    _error('el jefe no está quemado: no hay moneda que registrar');
  }
  // Chequeo de estados (D-12): veneno y quemadura bajan el HP del jefe sin
  // atribuirse a ningún jugador. Si lo dejan a 0 HP, victoria.
  // Antes, los efectos de los aliados que aplica el programa (D-13).
  var estado = _ejecutarScripts(e, scripts, (s) => s.alFinTurnoJefe);
  // Aliados quemados: hace falta la moneda de cada uno (D-17).
  final quemados = {
    for (final a in estado.aliados)
      if (a.quemado) a.slot,
  };
  final monedas = <int, bool>{};
  for (final m in ev.monedasQuemaduraAliados ?? const <MonedaQuemaduraAliado>[]) {
    if (monedas.containsKey(m.slot)) {
      _error('FinTurnoJefe: hay dos monedas para el aliado del slot ${m.slot}');
    }
    monedas[m.slot] = m.cara;
  }
  for (final slot in quemados) {
    if (!monedas.containsKey(slot)) {
      _error('el aliado del slot $slot está quemado: FinTurnoJefe necesita el '
          'resultado de su moneda');
    }
  }
  for (final slot in monedas.keys) {
    if (!quemados.contains(slot)) {
      _error('el aliado del slot $slot no está quemado: no hay moneda que '
          'registrar');
    }
  }
  final jefeActual = estado.jefe!;
  final dano = (jefeActual.envenenado ? danoVeneno : 0) +
      (jefeActual.quemado ? danoQuemadura : 0);
  if (dano > 0) {
    final aplicado = dano < jefeActual.hp ? dano : jefeActual.hp;
    final nuevoHp = jefeActual.hp - aplicado;
    estado = estado.copiarCon(
      jefe: jefeActual.conHp(nuevoHp),
      danoEstados: estado.danoEstados + aplicado,
    );
    if (nuevoHp <= 0) {
      return estado.copiarCon(
        fase: Fase.terminada,
        resultado: Resultado.victoria,
      );
    }
  }
  // Moneda de la quemadura, después de aplicar su daño: cara la quita.
  if (ev.monedaQuemadura == true) {
    estado = estado.copiarCon(jefe: estado.jefe!.conEstados(quemado: false));
  }
  // Chequeo de los aliados (D-17), por orden de slot: su daño no se atribuye
  // a nadie y un aliado a 0 HP sale de la mesa. La moneda de la quemadura
  // se aplica después del daño, como en el jefe.
  if (estado.aliados.any((a) => a.envenenado || a.quemado)) {
    final aliados = <AliadoEstado>[];
    var derrotados = 0;
    final ordenados = [...estado.aliados]
      ..sort((a, b) => a.slot.compareTo(b.slot));
    for (final a in ordenados) {
      final dano = (a.envenenado ? danoVeneno : 0) +
          (a.quemado ? danoQuemadura : 0);
      if (dano == 0) {
        aliados.add(a);
        continue;
      }
      final hp = a.hp - dano;
      if (hp <= 0) {
        derrotados++;
        continue;
      }
      aliados.add(a.copiarCon(
        hp: hp,
        quemado: a.quemado && monedas[a.slot] == true ? false : null,
      ));
    }
    estado = estado.copiarCon(
      aliados: aliados,
      aliadosDerrotados: estado.aliadosDerrotados + derrotados,
    );
  }
  return _llamarAliados(_empezarRonda(estado));
}

EstadoPartida _aplicarEstadoAliado(
  EstadoPartida e,
  AplicarEstadoAliado ev,
  Map<String, ScriptAliado> scripts,
) {
  if (e.fase != Fase.turnoJugadores && e.fase != Fase.turnoJefe) {
    _error('AplicarEstadoAliado no es válido en la fase ${e.fase.name}');
  }
  _exigeJugador(e, ev.jugador);
  if (estadosBloqueados(e, scripts)) {
    _error('un aliado (Velo Sagrado) impide que el jefe y los aliados sufran '
        'estados');
  }
  final aliado = e.aliadoEn(ev.slot);
  if (aliado == null) {
    _error('no hay ningún aliado en el slot ${ev.slot}');
  }
  final yaLoTiene = switch (ev.estado) {
    EstadoDelJefe.veneno => aliado.envenenado,
    EstadoDelJefe.quemadura => aliado.quemado,
  };
  // Aplicar un estado que ya tiene no cambia nada ni cuenta (D-12, D-17).
  if (yaLoTiene) return e;
  final aplicados = [...e.estadosAplicados];
  aplicados[ev.jugador] += 1;
  return e.copiarCon(
    aliados: [
      for (final a in e.aliados)
        if (a.slot != ev.slot)
          a
        else
          switch (ev.estado) {
            EstadoDelJefe.veneno => a.copiarCon(envenenado: true),
            EstadoDelJefe.quemadura => a.copiarCon(quemado: true),
          },
    ],
    estadosAplicados: aplicados,
  );
}

EstadoPartida _aplicarEstadoJefe(
  EstadoPartida e,
  AplicarEstadoJefe ev,
  Map<String, ScriptAliado> scripts,
) {
  if (e.fase != Fase.turnoJugadores && e.fase != Fase.turnoJefe) {
    _error('AplicarEstadoJefe no es válido en la fase ${e.fase.name}');
  }
  _exigeJugador(e, ev.jugador);
  if (estadosBloqueados(e, scripts)) {
    _error('un aliado (Velo Sagrado) impide que el jefe sufra estados');
  }
  final jefe = e.jefe!;
  final yaLoTiene = switch (ev.estado) {
    EstadoDelJefe.veneno => jefe.envenenado,
    EstadoDelJefe.quemadura => jefe.quemado,
  };
  // Aplicar un estado que ya tiene no cambia nada ni cuenta (D-12).
  if (yaLoTiene) return e;
  final aplicados = [...e.estadosAplicados];
  aplicados[ev.jugador] += 1;
  return e.copiarCon(
    jefe: switch (ev.estado) {
      EstadoDelJefe.veneno => jefe.conEstados(envenenado: true),
      EstadoDelJefe.quemadura => jefe.conEstados(quemado: true),
    },
    estadosAplicados: aplicados,
  );
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

/// Daño de un efecto (rebote) al jefe o a un aliado (T-59).
EstadoPartida _danoDeEfecto(EstadoPartida e, DanoDeEfecto ev) {
  if (e.fase != Fase.turnoJefe && e.fase != Fase.turnoJugadores) {
    _error('DanoDeEfecto no es válido en la fase ${e.fase.name}');
  }
  if (ev.puntos < 1) {
    _error('el daño de un efecto debe ser como mínimo 1');
  }
  final jugador = ev.jugador;
  final slot = ev.slot;
  if ((jugador == null) == (slot == null)) {
    _error('DanoDeEfecto: indica el jugador (daño al jefe) o el slot (daño a '
        'un aliado), solo uno');
  }
  if (jugador != null) {
    // Al jefe: se atribuye al jugador que recibió el ataque y puede dar la
    // victoria.
    _exigeJugador(e, jugador);
    final jefe = e.jefe!;
    final aplicado = ev.puntos < jefe.hp ? ev.puntos : jefe.hp;
    final dano = [...e.danoPorJugador];
    dano[jugador] += aplicado;
    final nuevoHp = jefe.hp - aplicado;
    final conDano = e.copiarCon(
      jefe: jefe.conHp(nuevoHp),
      danoPorJugador: dano,
    );
    if (nuevoHp <= 0) {
      return conDano.copiarCon(
        fase: Fase.terminada,
        resultado: Resultado.victoria,
      );
    }
    return _llamarAliados(conDano);
  }
  final aliado = e.aliadoEn(slot!);
  if (aliado == null) {
    _error('no hay ningún aliado en el slot $slot');
  }
  final restante = aliado.hp - ev.puntos;
  return e.copiarCon(
    aliados: [
      for (final a in e.aliados)
        if (a.slot != slot)
          a
        else if (restante > 0)
          a.copiarCon(hp: restante),
    ],
    aliadosDerrotados: e.aliadosDerrotados + (restante > 0 ? 0 : 1),
  );
}

EstadoPartida _ataqueAAliado(
  EstadoPartida e,
  AtaqueAAliado ev,
  Map<String, ScriptAliado> scripts,
) {
  _exigeFase(e, Fase.turnoJugadores, 'AtaqueAAliado');
  _exigeSinPendientes(e, 'AtaqueAAliado');
  _exigeJugador(e, ev.jugador);
  if (e.jugadorActual != ev.jugador) {
    _error('no es el turno del jugador ${ev.jugador}');
  }
  final aliado = e.aliadoEn(ev.slot);
  if (aliado == null) {
    _error('no hay ningún aliado en el slot ${ev.slot}');
  }
  if (ev.dano < 0) {
    _error('el daño no puede ser negativo');
  }
  final provocador = aliadoProvocador(e, scripts);
  if (provocador != null && provocador.slot != ev.slot) {
    _error('${provocador.nombre} obliga a atacarle: no se puede atacar a '
        '${aliado.nombre}');
  }
  // Los aliados Tanque (D-13) reducen cada ataque de los jugadores también
  // cuando va contra un aliado, y cada aliado puede reducir además lo que
  // recibe él (Bloqueo) o el jugador estar debilitado (Fuerza Lunar). El
  // exceso de daño se pierde: no pasa al jefe ni a otro aliado.
  var dano = ev.dano;
  if (dano > 0) {
    dano -= reduccionDanoAlJefe(e, scripts) +
        reduccionPropiaDe(aliado, scripts) +
        (e.debilitados[ev.jugador] ?? 0);
    if (dano < 0) dano = 0;
  }
  final restante = aliado.hp - dano;
  final aliados = <AliadoEstado>[
    for (final a in e.aliados)
      if (a.slot != ev.slot)
        a
      else if (restante > 0)
        a.copiarCon(hp: restante),
  ];
  // Moflete Estático: si el ataque deja fuera de combate a un aliado mientras
  // el aura está en juego (cuenta también el propio aliado que cae), el
  // Pokémon atacante queda Paralizado. Dura lo que queda de este turno de los
  // jugadores y todo el siguiente, que es el que pierde.
  final paraliza = restante <= 0 && paralizaAlCaerAliado(e, scripts);
  final conDano = e.copiarCon(
    aliados: aliados,
    aliadosDerrotados: e.aliadosDerrotados + (restante > 0 ? 0 : 1),
    debilitados: _sinDebilitar(e, ev.jugador),
    efectosActivos: !paraliza
        ? null
        : [
            for (final f in e.efectosActivos)
              if (f.tipo != TipoEfectoAtaque.paralizarDefensor ||
                  f.jugador != ev.jugador)
                f,
            EfectoActivo(
              tipo: TipoEfectoAtaque.paralizarDefensor,
              jugador: ev.jugador,
              restantes: 2,
            ),
          ],
  );
  return _avanzarTurno(conDano, e.turnoActual + 1);
}

void _exigeResolverInvocacion(EstadoPartida e, String evento) {
  if (e.fase != Fase.turnoJugadores && e.fase != Fase.turnoJefe) {
    _error('$evento no es válido en la fase ${e.fase.name}');
  }
  if (e.intentosInvocacionPendientes <= 0) {
    _error('$evento: no hay ningún intento de invocación por resolver');
  }
}

EstadoPartida _sinInvocacion(EstadoPartida e) {
  _exigeResolverInvocacion(e, 'SinInvocacion');
  return e.copiarCon(
    intentosInvocacionPendientes: e.intentosInvocacionPendientes - 1,
  );
}

EstadoPartida _aliadoInvocado(
  EstadoPartida e,
  AliadoInvocado ev,
  Map<String, ScriptAliado> scripts,
) {
  _exigeResolverInvocacion(e, 'AliadoInvocado');
  if (ev.slot < 0 || ev.slot >= e.jugadores.length) {
    _error('el slot ${ev.slot} no existe');
  }
  if (e.jugadores[ev.slot].eliminado) {
    _error('el jugador ${ev.slot} está eliminado: su slot no admite aliados');
  }
  if (e.aliadoEn(ev.slot) != null) {
    _error('el slot ${ev.slot} ya tiene un aliado');
  }
  if (e.aliados.any((a) => a.categoria == ev.categoria)) {
    _error('ya hay un aliado de la categoría ${ev.categoria.name}');
  }
  if (ev.efectos == EfectosAliado.programa) {
    final id = ev.scriptId;
    if (id == null) {
      _error('un aliado con efectos del programa necesita un scriptId');
    }
    if (!scripts.containsKey(id)) {
      _error('no existe el script «$id» de los efectos del aliado');
    }
  } else if (ev.scriptId != null) {
    _error('un aliado con efectos del jugador no lleva scriptId');
  }
  if (ev.hp <= 0) {
    _error('el HP del aliado debe ser mayor que 0');
  }
  final dano = ev.ataqueDano;
  if (dano != null && dano < 0) {
    _error('el daño del ataque del aliado no puede ser negativo');
  }
  final aliado = AliadoEstado(
    slot: ev.slot,
    categoria: ev.categoria,
    nombre: ev.nombre,
    hpMaximo: ev.hp,
    hp: ev.hp,
    ataqueNombre: ev.ataqueNombre,
    ataqueDano: dano,
    habilidad: ev.habilidad,
    efectos: ev.efectos,
    scriptId: ev.scriptId,
    // Sin ataque no hay ataque de entrada que esperar.
    entradaResuelta: dano == null,
  );
  final nuevo = e.copiarCon(
    aliados: [...e.aliados, aliado],
    intentosInvocacionPendientes: e.intentosInvocacionPendientes - 1,
  );
  if (aliado.efectos != EfectosAliado.programa) return nuevo;
  final script = scripts[aliado.scriptId]!;
  var resultado = nuevo;
  if (script.efectoPermanente &&
      !nuevo.efectosPermanentes.any((f) => f.scriptId == aliado.scriptId)) {
    resultado = resultado.copiarCon(efectosPermanentes: [
      ...nuevo.efectosPermanentes,
      EfectoPermanente(
        scriptId: aliado.scriptId!,
        origen: aliado.nombre,
        texto: aliado.habilidad,
      ),
    ]);
  }
  final alEntrar = script.alEntrar;
  if (alEntrar != null) resultado = alEntrar(resultado, aliado);
  final conEvento = script.alEntrarConEvento;
  if (conEvento != null) resultado = conEvento(resultado, aliado, ev);
  if (resultado.fase != nuevo.fase) {
    _error('el script «${aliado.scriptId}» no puede terminar la partida');
  }
  return resultado;
}

EstadoPartida _ataqueAliado(
  EstadoPartida e,
  AtaqueAliado ev,
  Map<String, ScriptAliado> scripts,
) {
  if (e.fase != Fase.turnoJugadores && e.fase != Fase.turnoJefe) {
    _error('AtaqueAliado no es válido en la fase ${e.fase.name}');
  }
  final aliado = e.aliadoEn(ev.slot);
  if (aliado == null) {
    _error('no hay ningún aliado en el slot ${ev.slot}');
  }
  if (!aliado.tieneAtaque) {
    _error('${aliado.nombre} no tiene ataque');
  }
  if (ev.dano < 0) {
    _error('el daño no puede ser negativo');
  }
  final objetivo = ev.objetivo;
  if (objetivo == null) {
    if (e.jugadores[aliado.slot].eliminado) {
      _error('el dueño del slot ${aliado.slot} está eliminado: indica a qué '
          'jugador activo ataca el aliado');
    }
  } else {
    _exigeJugador(e, objetivo);
  }
  // Contra un jugador KO el ataque falla: se omite (no cuenta como uso ni
  // dispara los efectos del aliado), pero gasta el turno de ese ataque.
  final falla = e.enKo(objetivo ?? aliado.slot);
  final usos = falla ? aliado.usos : aliado.usos + 1;

  AliadoEstado actualizado;
  if (!aliado.entradaResuelta) {
    // Ataque al entrar.
    actualizado = aliado.copiarCon(entradaResuelta: true, usos: usos);
  } else if (e.fase == Fase.turnoJefe && !aliado.atacoEnTurnoJefe) {
    // Ataque del final del turno del jefe, una vez por turno.
    actualizado = aliado.copiarCon(
      atacoEnTurnoJefe: true,
      usos: usos,
    );
  } else if (e.fase == Fase.turnoJefe) {
    _error('${aliado.nombre} ya ha atacado en este turno del jefe');
  } else {
    _error('${aliado.nombre} solo ataca al entrar y al final del turno del '
        'jefe');
  }
  final resultado = e.copiarCon(
    aliados: [
      for (final a in e.aliados)
        if (a.slot == ev.slot) actualizado else a,
    ],
  );
  if (falla) return resultado;
  final id = aliado.scriptId;
  if (aliado.efectos != EfectosAliado.programa || id == null) return resultado;
  final script = scripts[id]!;
  var conEfecto = resultado;
  final alAtacar = script.alAtacar;
  if (alAtacar != null) conEfecto = alAtacar(conEfecto, actualizado);
  final conEvento = script.alAtacarConEvento;
  if (conEvento != null) conEfecto = conEvento(conEfecto, actualizado, ev);
  if (conEfecto.fase != resultado.fase) {
    _error('el script «$id» no puede terminar la partida');
  }
  return conEfecto;
}
