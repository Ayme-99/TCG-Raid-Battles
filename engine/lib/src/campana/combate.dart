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

  const BandoCombate({
    required this.equipo,
    required this.activo,
    required this.energia,
    this.danoReducido = 0,
    this.danoExtra = 0,
  });

  PokemonEnCombate get pokemonActivo => equipo[activo];

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
  }) =>
      BandoCombate(
        equipo: equipo ?? this.equipo,
        activo: activo ?? this.activo,
        energia: energia ?? this.energia,
        danoReducido: danoReducido ?? this.danoReducido,
        danoExtra: danoExtra ?? this.danoExtra,
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

  const EstadoCombate({
    required this.jugador,
    required this.rival,
    required this.turno,
    required this.fase,
    required this.ganador,
    required this.numeroTurno,
    required this.parametros,
  });

  /// Combate nuevo: el primer Pokémon de cada equipo sale activo.
  factory EstadoCombate.inicial({
    required List<PokemonCampana> equipoJugador,
    required List<PokemonCampana> equipoRival,
    Bando empieza = Bando.jugador,
    ParametrosCombate parametros = const ParametrosCombate(),
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
    );
  }

  BandoCombate bando(Bando b) => b == Bando.jugador ? jugador : rival;

  EstadoCombate copiarCon({
    BandoCombate? jugador,
    BandoCombate? rival,
    Bando? turno,
    FaseCombate? fase,
    Bando? ganador,
    int? numeroTurno,
  }) =>
      EstadoCombate(
        jugador: jugador ?? this.jugador,
        rival: rival ?? this.rival,
        turno: turno ?? this.turno,
        fase: fase ?? this.fase,
        ganador: ganador ?? this.ganador,
        numeroTurno: numeroTurno ?? this.numeroTurno,
        parametros: parametros,
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
  if (accion.bando != estado.turno) {
    throw const ReglaIncumplida('No es el turno de ese bando.');
  }
  if (estado.fase == FaseCombate.eligiendoActivo) {
    if (accion is! ElegirSiguiente) {
      throw const ReglaIncumplida('Primero hay que elegir el siguiente Pokémon.');
    }
    return _elegirSiguiente(estado, accion);
  }
  return switch (accion) {
    Atacar a => _atacar(estado, a),
    Cambiar a => _cambiar(estado, a),
    Cargar a => _cargar(estado, a),
    ElegirSiguiente _ =>
      throw const ReglaIncumplida('No hay que elegir Pokémon ahora.'),
  };
}

EstadoCombate _elegirSiguiente(EstadoCombate estado, ElegirSiguiente a) {
  final b = estado.bando(a.bando);
  if (!b.relevos.contains(a.indice)) {
    throw const ReglaIncumplida('Ese Pokémon no puede salir.');
  }
  return estado
      .conBando(a.bando, b.copiarCon(activo: a.indice, danoReducido: 0, danoExtra: 0))
      .copiarCon(fase: FaseCombate.enCurso);
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
  final golpeado = defensor.pokemonActivo.conPs(defensor.pokemonActivo.ps -
      danoDeAtaque(ataque, defensor.pokemonActivo.especie,
          reduccion: atacante.danoReducido, extra: defensor.danoExtra));
  final equipo = [...defensor.equipo]..[defensor.activo] = golpeado;
  var defensorNuevo = defensor.copiarCon(equipo: equipo);
  final efecto = ataque.efecto;
  if (efecto is ReduceDanoRival && efecto.valor > defensor.danoReducido) {
    // No se acumula: solo cuenta el mayor.
    defensorNuevo = defensorNuevo.copiarCon(danoReducido: efecto.valor);
  }
  if (efecto is AumentaDanoRecibido && efecto.valor > defensor.danoExtra) {
    defensorNuevo = defensorNuevo.copiarCon(danoExtra: efecto.valor);
  }
  var nuevo = estado
      .conBando(
          a.bando, atacante.copiarCon(energia: atacante.energia - ataque.coste))
      .conBando(rivalBando, defensorNuevo);
  if (defensorNuevo.derrotado) {
    return nuevo.copiarCon(fase: FaseCombate.terminado, ganador: a.bando);
  }
  nuevo = _terminarTurno(nuevo);
  if (!golpeado.enPie) {
    nuevo = nuevo.copiarCon(fase: FaseCombate.eligiendoActivo);
  }
  return nuevo;
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
        danoExtra: 0),
  ));
}

EstadoCombate _cargar(EstadoCombate estado, Cargar a) {
  final b = estado.bando(a.bando);
  final p = estado.parametros;
  final total = b.energia + p.energiaAlCargar;
  final energia = total > p.energiaMaxima ? p.energiaMaxima : total;
  return _terminarTurno(estado.conBando(a.bando, b.copiarCon(energia: energia)));
}

/// Termina el turno del bando actual: recupera energía y pasa el turno al otro.
EstadoCombate _terminarTurno(EstadoCombate estado) {
  final actual = estado.bando(estado.turno);
  final p = estado.parametros;
  final total = actual.energia + p.energiaPorTurno;
  final energia = total > p.energiaMaxima ? p.energiaMaxima : total;
  return estado
      .conBando(estado.turno, actual.copiarCon(energia: energia))
      .copiarCon(
        turno: estado.turno.otro,
        numeroTurno: estado.numeroTurno + 1,
      );
}
