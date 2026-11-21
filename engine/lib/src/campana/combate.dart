import '../errores.dart';
import 'pokemon.dart';

/// Los dos bandos de un combate de campaña.
enum Bando {
  jugador,
  rival;

  Bando get otro => this == Bando.jugador ? Bando.rival : Bando.jugador;
}

/// Parámetros de la energía (D-20 §3.1). Todos se ajustan con el simulador.
class ParametrosCombate {
  /// Energía con la que empieza cada bando.
  final int energiaInicial;

  /// Máximo de la reserva.
  final int energiaMaxima;

  /// Energía que recupera un bando al terminar su turno.
  final int energiaPorTurno;

  /// Energía extra que recupera al cargar (además de la del fin de turno).
  final int energiaAlCargar;

  const ParametrosCombate({
    this.energiaInicial = 10,
    this.energiaMaxima = 10,
    this.energiaPorTurno = 1,
    this.energiaAlCargar = 1,
  });
}

/// En qué punto está el combate.
enum FaseCombate {
  /// El bando al que toca debe elegir su siguiente Pokémon (el anterior cayó).
  eligiendoActivo,

  /// El bando al que toca puede atacar, cambiar o cargar.
  enCurso,

  /// Alguien se ha quedado sin Pokémon.
  terminado,
}

/// El equipo, el Pokémon activo y la energía de un bando.
class BandoCombate {
  final List<PokemonEnCombate> equipo;
  final int activo;
  final int energia;

  /// Daño que pierden los ataques del Pokémon activo de este bando por un
  /// efecto del rival (Gruñido). Se quita al cambiar de Pokémon activo.
  final int danoReducido;

  /// Daño extra que reciben los ataques contra el Pokémon activo de este
  /// bando por un efecto del rival (Látigo). Se quita al cambiar de activo.
  final int danoExtra;

  /// Daño que pierde el Pokémon activo de este bando en cada chequeo Pokémon
  /// por estar envenenado (0 = no lo está). Se quita al cambiar de activo.
  final int veneno;

  /// Daño que se resta a los ataques que recibe el Pokémon activo de este
  /// bando por un efecto propio (Fortaleza). Se quita al cambiar de activo.
  final int proteccion;

  /// Si es true, el próximo ataque de este bando lanza una moneda y con cruz
  /// no hace nada (Bofetón Lodo del rival). Dura solo su próximo turno.
  final bool cegado;

  /// Índice del ataque que usó el activo en su turno anterior (-1 si no atacó,
  /// o si cargó o cambió) y cuántas veces seguidas lo lleva usando (Rodar).
  final int ultimoAtaque;
  final int racha;

  const BandoCombate({
    required this.equipo,
    required this.activo,
    required this.energia,
    this.danoReducido = 0,
    this.danoExtra = 0,
    this.veneno = 0,
    this.proteccion = 0,
    this.cegado = false,
    this.ultimoAtaque = -1,
    this.racha = 0,
  });

  PokemonEnCombate get pokemonActivo => equipo[activo];

  /// Ajuste neto al daño que recibe el activo: el extra de Látigo menos la
  /// protección de Fortaleza (puede ser negativo).
  int get extraRecibido => danoExtra - proteccion;

  /// Sin ningún Pokémon en pie.
  bool get derrotado => !equipo.any((p) => p.enPie);

  /// Índices de los Pokémon en pie que no son el activo.
  List<int> get relevos => [
        for (var i = 0; i < equipo.length; i++)
          if (i != activo && equipo[i].enPie) i,
      ];

  BandoCombate copiarCon({
    List<PokemonEnCombate>? equipo,
    int? activo,
    int? energia,
    int? danoReducido,
    int? danoExtra,
    int? veneno,
    int? proteccion,
    bool? cegado,
    int? ultimoAtaque,
    int? racha,
  }) =>
      BandoCombate(
        equipo: equipo ?? this.equipo,
        activo: activo ?? this.activo,
        energia: energia ?? this.energia,
        danoReducido: danoReducido ?? this.danoReducido,
        danoExtra: danoExtra ?? this.danoExtra,
        veneno: veneno ?? this.veneno,
        proteccion: proteccion ?? this.proteccion,
        cegado: cegado ?? this.cegado,
        ultimoAtaque: ultimoAtaque ?? this.ultimoAtaque,
        racha: racha ?? this.racha,
      );
}

/// Estado inmutable de un combate 1 contra 1.
class EstadoCombate {
  final BandoCombate jugador;
  final BandoCombate rival;

  /// A quién le toca.
  final Bando turno;
  final FaseCombate fase;
  final Bando? ganador;

  /// Turnos jugados (empieza en 1).
  final int numeroTurno;

  final ParametrosCombate parametros;

  /// Semilla del generador de monedas. Avanza cada vez que se lanza una
  /// moneda; el reductor sigue siendo puro (mismo estado, mismo resultado).
  final int semilla;

  /// Resultado de la última moneda lanzada (true = cara), o null si todavía
  /// no se ha lanzado ninguna. La interfaz lo usa para mostrarla.
  final bool? ultimaMoneda;

  const EstadoCombate({
    required this.jugador,
    required this.rival,
    required this.turno,
    required this.fase,
    required this.ganador,
    required this.numeroTurno,
    required this.parametros,
    this.semilla = 1,
    this.ultimaMoneda,
  });

  /// Combate nuevo: el primer Pokémon de cada equipo sale activo.
  factory EstadoCombate.inicial({
    required List<PokemonCampana> equipoJugador,
    required List<PokemonCampana> equipoRival,
    Bando empieza = Bando.jugador,
    ParametrosCombate parametros = const ParametrosCombate(),
    int semilla = 1,
  }) {
    if (equipoJugador.isEmpty || equipoRival.isEmpty) {
      throw const ReglaIncumplida('Cada bando necesita al menos un Pokémon.');
    }
    BandoCombate bando(List<PokemonCampana> equipo) => BandoCombate(
          equipo: [for (final p in equipo) PokemonEnCombate.completo(p)],
          activo: 0,
          energia: parametros.energiaInicial,
        );
    return EstadoCombate(
      jugador: bando(equipoJugador),
      rival: bando(equipoRival),
      turno: empieza,
      fase: FaseCombate.enCurso,
      ganador: null,
      numeroTurno: 1,
      parametros: parametros,
      semilla: _normalizarSemilla(semilla),
    );
  }

  /// Bandos cuyo Pokémon activo ha caído y tienen que elegir el siguiente
  /// (el del turno primero). Puede haber dos a la vez si el chequeo de veneno
  /// derriba a uno mientras el otro ya había caído.
  List<Bando> get debenElegir => [
        for (final b in [turno, turno.otro])
          if (!bando(b).pokemonActivo.enPie) b,
      ];

  /// Quién tiene que actuar ahora: quien elige Pokémon si hay que elegir, y si
  /// no, el del turno. Úsalo (no [turno]) para pedir la acción a la IA.
  Bando get actua =>
      fase == FaseCombate.eligiendoActivo && debenElegir.isNotEmpty
          ? debenElegir.first
          : turno;

  BandoCombate bando(Bando b) => b == Bando.jugador ? jugador : rival;

  EstadoCombate copiarCon({
    BandoCombate? jugador,
    BandoCombate? rival,
    Bando? turno,
    FaseCombate? fase,
    Bando? ganador,
    int? numeroTurno,
    int? semilla,
    bool? ultimaMoneda,
  }) =>
      EstadoCombate(
        jugador: jugador ?? this.jugador,
        rival: rival ?? this.rival,
        turno: turno ?? this.turno,
        fase: fase ?? this.fase,
        ganador: ganador ?? this.ganador,
        numeroTurno: numeroTurno ?? this.numeroTurno,
        parametros: parametros,
        semilla: semilla ?? this.semilla,
        ultimaMoneda: ultimaMoneda ?? this.ultimaMoneda,
      );

  EstadoCombate conBando(Bando b, BandoCombate nuevo) => b == Bando.jugador
      ? copiarCon(jugador: nuevo)
      : copiarCon(rival: nuevo);
}

/// Una acción de un bando en el combate.
sealed class AccionCombate {
  final Bando bando;

  const AccionCombate(this.bando);
}

/// Ataca con el Pokémon activo usando su ataque número [indice].
class Atacar extends AccionCombate {
  final int indice;

  const Atacar(super.bando, this.indice);
}

/// Cambia el Pokémon activo por el del equipo en la posición [indice]. Gasta
/// el turno.
class Cambiar extends AccionCombate {
  final int indice;

  const Cambiar(super.bando, this.indice);
}

/// Carga energía: recupera 1 más de lo normal y termina el turno.
class Cargar extends AccionCombate {
  const Cargar(super.bando);
}

/// Elige el Pokémon que sustituye al que ha caído. No gasta turno.
class ElegirSiguiente extends AccionCombate {
  final int indice;

  const ElegirSiguiente(super.bando, this.indice);
}

/// Daño real de un ataque contra un defensor, como en las cartas: primero se
/// resta la [reduccion] de efectos (Gruñido) y se suma el [extra] del defensor
/// (Látigo), luego la debilidad (el daño se multiplica) y luego la resistencia
/// (se resta); nunca baja de 0. Un ataque sin daño sigue sin hacerlo.
int danoDeAtaque(AtaqueCampana ataque, PokemonCampana defensor,
    {int reduccion = 0, int extra = 0}) {
  if (ataque.dano <= 0) return 0;
  var dano = ataque.dano - reduccion + extra;
  if (dano < 0) dano = 0;
  final d = defensor.debilidad;
  if (d != null && d.tipo == ataque.tipo) dano *= d.multiplicador;
  final r = defensor.resistencia;
  if (r != null && r.tipo == ataque.tipo) dano -= r.reduccion;
  return dano < 0 ? 0 : dano;
}

/// Aplica una acción al combate y devuelve un estado nuevo (no modifica el
/// recibido). Si la acción no es válida lanza [ReglaIncumplida].
EstadoCombate aplicarCombate(EstadoCombate estado, AccionCombate accion) {
  if (estado.fase == FaseCombate.terminado) {
    throw const ReglaIncumplida('El combate ha terminado.');
  }
  if (estado.fase == FaseCombate.eligiendoActivo) {
    if (accion is! ElegirSiguiente) {
      throw const ReglaIncumplida('Primero hay que elegir el siguiente Pokémon.');
    }
    if (!estado.debenElegir.contains(accion.bando)) {
      throw const ReglaIncumplida('Ese bando no tiene que elegir Pokémon.');
    }
    return _elegirSiguiente(estado, accion);
  }
  if (accion.bando != estado.turno) {
    throw const ReglaIncumplida('No es el turno de ese bando.');
  }
  return switch (accion) {
    Atacar a => _atacar(estado, a),
    Cambiar a => _cambiar(estado, a),
    Cargar a => _cargar(estado, a),
    ElegirSiguiente _ =>
      throw const ReglaIncumplida('No hay que elegir Pokémon ahora.'),
  };
}

const _modulo = 2147483647;

/// Semilla válida para el generador (1 a 2^31-2).
int _normalizarSemilla(int s) {
  final r = s % _modulo;
  return r <= 0 ? r + _modulo - 1 : r;
}

/// Siguiente semilla del generador (Park-Miller). Las cuentas caben en 53 bits,
/// así que da lo mismo en la VM de Dart que compilado a web.
int _siguienteSemilla(int s) => (s * 48271) % _modulo;

EstadoCombate _elegirSiguiente(EstadoCombate estado, ElegirSiguiente a) {
  final b = estado.bando(a.bando);
  if (!b.relevos.contains(a.indice)) {
    throw const ReglaIncumplida('Ese Pokémon no puede salir.');
  }
  final nuevo = estado.conBando(
      a.bando,
      b.copiarCon(
          activo: a.indice,
          danoReducido: 0,
          danoExtra: 0,
          veneno: 0,
          proteccion: 0,
          cegado: false,
          ultimoAtaque: -1,
          racha: 0));
  return nuevo.copiarCon(
      fase: nuevo.debenElegir.isEmpty
          ? FaseCombate.enCurso
          : FaseCombate.eligiendoActivo);
}

EstadoCombate _atacar(EstadoCombate estado, Atacar a) {
  final atacante = estado.bando(a.bando);
  final ataques = atacante.pokemonActivo.especie.ataques;
  if (a.indice < 0 || a.indice >= ataques.length) {
    throw const ReglaIncumplida('Ese ataque no existe.');
  }
  final ataque = ataques[a.indice];
  if (atacante.energia < ataque.coste) {
    throw const ReglaIncumplida('No hay energía suficiente para ese ataque.');
  }
  final rivalBando = a.bando.otro;
  final defensor = estado.bando(rivalBando);
  final racha = atacante.ultimoAtaque == a.indice ? atacante.racha + 1 : 1;
  var semilla = estado.semilla;
  bool? moneda;
  if (atacante.cegado) {
    // Bofetón Lodo del rival: con cruz este ataque no hace nada.
    semilla = _siguienteSemilla(semilla);
    moneda = (semilla >> 8) & 1 == 1;
    if (!moneda) {
      final fallido = estado
          .conBando(
              a.bando,
              atacante.copiarCon(
                  energia: atacante.energia - ataque.coste,
                  cegado: false,
                  ultimoAtaque: a.indice,
                  racha: racha))
          .copiarCon(semilla: semilla, ultimaMoneda: moneda);
      return _terminarTurno(fallido);
    }
  }
  var golpe = ataque;
  final efecto = ataque.efecto;
  if (efecto is DanoPorRacha) {
    golpe = AtaqueCampana(
        nombre: ataque.nombre,
        tipo: ataque.tipo,
        coste: ataque.coste,
        dano: ataque.dano * racha);
  }
  if (efecto is MonedaDanoExtra) {
    semilla = _siguienteSemilla(semilla);
    moneda = (semilla >> 8) & 1 == 1;
    if (moneda) {
      golpe = AtaqueCampana(
          nombre: ataque.nombre,
          tipo: ataque.tipo,
          coste: ataque.coste,
          dano: ataque.dano + efecto.valor);
    }
  }
  final golpeado = defensor.pokemonActivo.conPs(defensor.pokemonActivo.ps -
      danoDeAtaque(golpe, defensor.pokemonActivo.especie,
          reduccion: atacante.danoReducido, extra: defensor.extraRecibido));
  final equipo = [...defensor.equipo]..[defensor.activo] = golpeado;
  var defensorNuevo = defensor.copiarCon(equipo: equipo);
  if (efecto is ReduceDanoRival && efecto.valor > defensor.danoReducido) {
    // No se acumula: solo cuenta el mayor.
    defensorNuevo = defensorNuevo.copiarCon(danoReducido: efecto.valor);
  }
  if (efecto is AumentaDanoRecibido && efecto.valor > defensor.danoExtra) {
    defensorNuevo = defensorNuevo.copiarCon(danoExtra: efecto.valor);
  }
  if (efecto is EnvenenaDefensor && efecto.valor > defensor.veneno) {
    defensorNuevo = defensorNuevo.copiarCon(veneno: efecto.valor);
  }
  if (efecto is MonedaFalloRival) {
    defensorNuevo = defensorNuevo.copiarCon(cegado: true);
  }
  if (efecto is QuitaEnergiaRival) {
    final resto = defensorNuevo.energia - efecto.valor;
    defensorNuevo = defensorNuevo.copiarCon(energia: resto < 0 ? 0 : resto);
  }
  var atacanteNuevo = atacante.copiarCon(
      energia: atacante.energia - ataque.coste,
      ultimoAtaque: a.indice,
      racha: racha);
  if (efecto is ReduceDanoPropio && efecto.valor > atacante.proteccion) {
    atacanteNuevo = atacanteNuevo.copiarCon(proteccion: efecto.valor);
  }
  var nuevo = estado
      .conBando(a.bando, atacanteNuevo)
      .conBando(rivalBando, defensorNuevo)
      .copiarCon(semilla: semilla, ultimaMoneda: moneda);
  if (defensorNuevo.derrotado) {
    return nuevo.copiarCon(fase: FaseCombate.terminado, ganador: a.bando);
  }
  return _terminarTurno(nuevo);
}

/// Cambiar siempre gasta el turno; además cuesta la retirada del Pokémon que
/// sale (0 de salida, así que normalmente solo cuesta el turno).
EstadoCombate _cambiar(EstadoCombate estado, Cambiar a) {
  final b = estado.bando(a.bando);
  if (!b.relevos.contains(a.indice)) {
    throw const ReglaIncumplida('Ese Pokémon no puede salir.');
  }
  final retirada = b.pokemonActivo.especie.retirada;
  if (b.energia < retirada) {
    throw const ReglaIncumplida('No hay energía para retirar al Pokémon.');
  }
  return _terminarTurno(estado.conBando(
    a.bando,
    b.copiarCon(
        activo: a.indice,
        energia: b.energia - retirada,
        danoReducido: 0,
        danoExtra: 0,
        veneno: 0,
        proteccion: 0,
        ultimoAtaque: -1,
        racha: 0),
  ));
}

EstadoCombate _cargar(EstadoCombate estado, Cargar a) {
  final b = estado.bando(a.bando);
  final p = estado.parametros;
  final total = b.energia + p.energiaAlCargar;
  final energia = total > p.energiaMaxima ? p.energiaMaxima : total;
  return _terminarTurno(estado.conBando(
      a.bando, b.copiarCon(energia: energia, ultimoAtaque: -1, racha: 0)));
}

/// Termina el turno del bando actual: recupera energía y pasa el turno al otro.
EstadoCombate _terminarTurno(EstadoCombate estado) {
  final actual = estado.bando(estado.turno);
  final p = estado.parametros;
  final total = actual.energia + p.energiaPorTurno;
  final energia = total > p.energiaMaxima ? p.energiaMaxima : total;
  final termina = estado.turno;
  // El efecto de Bofetón Lodo solo dura el turno que acaba de jugarse.
  final cambiado = estado
      .conBando(termina, actual.copiarCon(energia: energia, cegado: false))
      .copiarCon(
        turno: termina.otro,
        numeroTurno: estado.numeroTurno + 1,
      );
  final tras = _chequeoPokemon(cambiado, termina);
  if (tras.fase == FaseCombate.terminado) return tras;
  // Si cae algún activo (por un ataque o por el veneno), hay que elegir relevo.
  return tras.debenElegir.isEmpty
      ? tras
      : tras.copiarCon(fase: FaseCombate.eligiendoActivo);
}

/// Chequeo Pokémon, cada vez que cambia el turno: el activo envenenado de cada
/// bando pierde su veneno en PS. Va primero el bando que acaba de terminar su
/// turno; si su último Pokémon cae, el combate termina y gana el otro aunque
/// el segundo chequeo también lo hubiera derribado.
EstadoCombate _chequeoPokemon(EstadoCombate estado, Bando primero) {
  var s = estado;
  for (final b in [primero, primero.otro]) {
    final bando = s.bando(b);
    final activo = bando.pokemonActivo;
    if (bando.veneno <= 0 || !activo.enPie) continue;
    final equipo = [...bando.equipo]
      ..[bando.activo] = activo.conPs(activo.ps - bando.veneno);
    final nuevo = bando.copiarCon(equipo: equipo);
    s = s.conBando(b, nuevo);
    if (nuevo.derrotado) {
      return s.copiarCon(fase: FaseCombate.terminado, ganador: b.otro);
    }
  }
  return s;
}
