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

  /// PS que cura una Poción en combate (la campaña pasa los suyos,
  /// `ParametrosCampana.psPocion`: 20).
  final int psPocion;

  /// Propuesta de Diseño por confirmar (D-20 §3.2): la Poción en combate cura
  /// a cualquier Pokémon en pie del equipo, también de la banca. Con false,
  /// solo al activo.
  final bool pocionCuraBanca;

  /// Decidido (D-20 §10.6, #458): el rival no usa objetos por ahora. Con
  /// true, el motor acepta [UsarPocion] y [UsarCuerdaHuida] del rival y la IA
  /// los usa.
  final bool rivalUsaObjetos;

  const ParametrosCombate({
    this.energiaInicial = 10,
    this.energiaMaxima = 10,
    this.energiaPorTurno = 1,
    this.energiaAlCargar = 1,
    this.psPocion = 20,
    this.pocionCuraBanca = true,
    this.rivalUsaObjetos = false,
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

  /// Si es true, cada ataque de este bando lanza una moneda y con cruz no hace
  /// nada, **mientras siga activo el mismo Pokémon** (Pantalla de Humo del
  /// rival, [MonedaFalloRival.mientrasActivo]). Se quita al cambiar de activo.
  final bool cegadoMientrasActivo;

  /// Si el veneno de [veneno] es de Drenadoras ([DrenaDefensor]): cada chequeo
  /// que quita PS cura además al activo del otro bando. Se quita al cambiar.
  final bool drenado;

  /// Paralizado (Dragoaliento del rival, [ParalizaDefensor]): en su próximo
  /// turno este bando no puede atacar ni cambiar de Pokémon, solo cargar. Se
  /// quita al acabar ese turno, o si su activo cae o deja de estar activo.
  final bool paralizado;

  /// Índice del ataque que usó el activo en su turno anterior (-1 si no atacó,
  /// o si cargó o cambió) y cuántas veces seguidas lo lleva usando (Rodar).
  final int ultimoAtaque;
  final int racha;

  /// Posición de un Pokémon del equipo que no puede salir con [Cambiar]
  /// (-1 si no hay ninguno), por la llamada de aliado (D-20 §4, Jefes): el
  /// aliado que espera en la banca a que el jefe llegue al segundo umbral, o
  /// el jefe que se ha retirado y solo vuelve cuando el aliado cae.
  final int enEspera;

  /// Pociones que le quedan a este bando en el combate (D-20 §3.2, #458): las
  /// del inventario al empezar. No hay límite por combate.
  final int pociones;

  /// Pociones gastadas en este combate; la partida las resta de la mochila
  /// al terminarlo.
  final int pocionesUsadas;

  /// Cuerdas Huida que le quedan a este bando en el combate (D-20 §10.6,
  /// #468): las del inventario al empezar.
  final int cuerdas;

  /// Cuerdas Huida gastadas en este combate; la partida las resta de la
  /// mochila al terminarlo.
  final int cuerdasUsadas;

  const BandoCombate({
    required this.equipo,
    required this.activo,
    required this.energia,
    this.danoReducido = 0,
    this.danoExtra = 0,
    this.veneno = 0,
    this.proteccion = 0,
    this.cegado = false,
    this.cegadoMientrasActivo = false,
    this.drenado = false,
    this.paralizado = false,
    this.ultimoAtaque = -1,
    this.racha = 0,
    this.enEspera = -1,
    this.pociones = 0,
    this.pocionesUsadas = 0,
    this.cuerdas = 0,
    this.cuerdasUsadas = 0,
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

  /// Los relevos a los que se puede cambiar con [Cambiar]: todos menos el
  /// que está [enEspera].
  List<int> get cambiables => [
        for (final i in relevos)
          if (i != enEspera) i,
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
    bool? cegadoMientrasActivo,
    bool? drenado,
    bool? paralizado,
    int? ultimoAtaque,
    int? racha,
    int? enEspera,
    int? pociones,
    int? pocionesUsadas,
    int? cuerdas,
    int? cuerdasUsadas,
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
        cegadoMientrasActivo: cegadoMientrasActivo ?? this.cegadoMientrasActivo,
        drenado: drenado ?? this.drenado,
        paralizado: paralizado ?? this.paralizado,
        ultimoAtaque: ultimoAtaque ?? this.ultimoAtaque,
        racha: racha ?? this.racha,
        enEspera: enEspera ?? this.enEspera,
        pociones: pociones ?? this.pociones,
        pocionesUsadas: pocionesUsadas ?? this.pocionesUsadas,
        cuerdas: cuerdas ?? this.cuerdas,
        cuerdasUsadas: cuerdasUsadas ?? this.cuerdasUsadas,
      );
}

/// Un ataque que se repite sobre el Pokémon que salga tras caer el activo
/// (Doble Patada): quién lo lanzó, con qué daño y la reducción que llevaba.
class DanoRepetido {
  final Bando atacante;
  final AtaqueCampana ataque;
  final int reduccion;

  const DanoRepetido(this.atacante, this.ataque, this.reduccion);
}

/// La llamada de aliado de un jefe en combate (D-20 §4, Jefes), en dos
/// pasos. Cuando el Pokémon de la posición [jefe] del rival **llega** al
/// [porcentaje] de sus PS o baja de él sin caer, invoca a uno de los
/// [aliados] (elegido con la semilla del combate), que aparece **en la
/// banca**. Cuando llega a [alFrente] % o baja de él, el jefe se retira a la
/// banca (pierde todos sus efectos, como al cambiar) y el aliado pasa al
/// puesto activo. Un golpe que cruce los dos umbrales hace las dos cosas a la
/// vez. Llama una sola vez por combate; el aliado no sale con [Cambiar]
/// mientras espera, y el jefe no vuelve hasta que cae el aliado, con los PS
/// que tenía. El combate se gana cuando cae el jefe.
class LlamadaEnCombate {
  final int porcentaje;

  /// Porcentaje de PS al que el aliado pasa al puesto activo (igual o menor
  /// que [porcentaje]; si es igual, entra directamente).
  final int alFrente;
  final List<PokemonCampana> aliados;

  /// Posición del jefe en el equipo del rival (el primero, de salida).
  final int jefe;

  const LlamadaEnCombate(this.porcentaje, this.aliados,
      {int? alFrente, this.jefe = 0})
      : alFrente = alFrente ?? porcentaje;
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

  /// Todas las monedas del último ataque que lanzó alguna, en orden (true =
  /// cara). Null si todavía no se ha lanzado ninguna.
  final List<bool>? ultimasMonedas;

  /// Daño pendiente de aplicar al Pokémon que salga tras caer el activo, o
  /// null (Doble Patada).
  final DanoRepetido? repetirDano;

  /// La llamada de aliado del rival, si es un jefe que la tiene; null si no.
  final LlamadaEnCombate? llamada;

  /// Posición en el equipo del rival del aliado invocado, o null si el jefe
  /// todavía no ha llamado. Los aliados no se capturan.
  final int? aliado;

  /// Si el aliado ya ha pasado al puesto activo (segundo umbral).
  final bool aliadoAlFrente;

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
    this.ultimasMonedas,
    this.repetirDano,
    this.llamada,
    this.aliado,
    this.aliadoAlFrente = false,
  });

  /// Si el jefe ya ha llamado a su aliado en este combate.
  bool get llamadaHecha => aliado != null;

  /// Combate nuevo: el primer Pokémon de cada equipo sale activo.
  factory EstadoCombate.inicial({
    required List<PokemonCampana> equipoJugador,
    required List<PokemonCampana> equipoRival,
    Bando empieza = Bando.jugador,
    ParametrosCombate parametros = const ParametrosCombate(),
    int semilla = 1,
    LlamadaEnCombate? llamadaRival,
    int pocionesJugador = 0,
    int pocionesRival = 0,
    int cuerdasJugador = 0,
    int cuerdasRival = 0,
  }) {
    if (equipoJugador.isEmpty || equipoRival.isEmpty) {
      throw const ReglaIncumplida('Cada bando necesita al menos un Pokémon.');
    }
    if (llamadaRival != null &&
        (llamadaRival.aliados.isEmpty ||
            llamadaRival.alFrente > llamadaRival.porcentaje ||
            llamadaRival.jefe < 0 ||
            llamadaRival.jefe >= equipoRival.length)) {
      throw const ReglaIncumplida('La llamada de aliado no es válida.');
    }
    BandoCombate bando(List<PokemonCampana> equipo, int pociones,
            int cuerdas) =>
        BandoCombate(
          equipo: [for (final p in equipo) PokemonEnCombate.completo(p)],
          activo: 0,
          energia: parametros.energiaInicial,
          pociones: pociones,
          cuerdas: cuerdas,
        );
    return EstadoCombate(
      jugador: bando(equipoJugador, pocionesJugador, cuerdasJugador),
      rival: bando(equipoRival, pocionesRival, cuerdasRival),
      turno: empieza,
      fase: FaseCombate.enCurso,
      ganador: null,
      numeroTurno: 1,
      parametros: parametros,
      semilla: _normalizarSemilla(semilla),
      llamada: llamadaRival,
    );
  }

  /// Combate nuevo con equipos que ya traen sus PS (la campaña conserva los
  /// PS entre combates). Sale activo el primer Pokémon en pie de cada equipo.
  factory EstadoCombate.conEquipos({
    required List<PokemonEnCombate> equipoJugador,
    required List<PokemonEnCombate> equipoRival,
    Bando empieza = Bando.jugador,
    ParametrosCombate parametros = const ParametrosCombate(),
    int semilla = 1,
    LlamadaEnCombate? llamadaRival,
    int pocionesJugador = 0,
    int pocionesRival = 0,
    int cuerdasJugador = 0,
    int cuerdasRival = 0,
  }) {
    if (llamadaRival != null &&
        (llamadaRival.aliados.isEmpty ||
            llamadaRival.alFrente > llamadaRival.porcentaje ||
            llamadaRival.jefe < 0 ||
            llamadaRival.jefe >= equipoRival.length)) {
      throw const ReglaIncumplida('La llamada de aliado no es válida.');
    }
    BandoCombate bando(
        List<PokemonEnCombate> equipo, int pociones, int cuerdas) {
      final activo = equipo.indexWhere((p) => p.enPie);
      if (activo < 0) {
        throw const ReglaIncumplida(
            'Cada bando necesita al menos un Pokémon en pie.');
      }
      return BandoCombate(
        equipo: List.of(equipo),
        activo: activo,
        energia: parametros.energiaInicial,
        pociones: pociones,
        cuerdas: cuerdas,
      );
    }

    return EstadoCombate(
      jugador: bando(equipoJugador, pocionesJugador, cuerdasJugador),
      rival: bando(equipoRival, pocionesRival, cuerdasRival),
      turno: empieza,
      fase: FaseCombate.enCurso,
      ganador: null,
      numeroTurno: 1,
      parametros: parametros,
      semilla: _normalizarSemilla(semilla),
      llamada: llamadaRival,
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
    List<bool>? ultimasMonedas,
    DanoRepetido? repetirDano,
    bool limpiarRepetirDano = false,
    int? aliado,
    bool? aliadoAlFrente,
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
        ultimasMonedas: ultimasMonedas ?? this.ultimasMonedas,
        repetirDano:
            limpiarRepetirDano ? null : (repetirDano ?? this.repetirDano),
        llamada: llamada,
        aliado: aliado ?? this.aliado,
        aliadoAlFrente: aliadoAlFrente ?? this.aliadoAlFrente,
      );

  EstadoCombate conBando(Bando b, BandoCombate nuevo) =>
      b == Bando.jugador ? copiarCon(jugador: nuevo) : copiarCon(rival: nuevo);
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

/// Usa una Poción con el Pokémon del equipo en la posición [indice] (D-20
/// §3.2, #458): cura [ParametrosCombate.psPocion] PS sin pasar de sus PS
/// máximos y **no gasta el turno**, así que después se ataca, cambia o carga.
/// No hay límite por combate, solo [BandoCombate.pociones]. No revive. Cura a
/// cualquiera en pie si [ParametrosCombate.pocionCuraBanca]; si no, solo al
/// activo. El rival solo puede si [ParametrosCombate.rivalUsaObjetos].
class UsarPocion extends AccionCombate {
  final int indice;

  const UsarPocion(super.bando, this.indice);
}

/// Usa una Cuerda Huida (D-20 §10.6, #437 y #468): cambia el activo por el
/// del equipo en la posición [indice] **sin pagar la retirada** y aunque esté
/// Paralizado. **Gasta el turno**, como [Cambiar]. Solo hay las
/// [BandoCombate.cuerdas] del inventario. El rival solo puede si
/// [ParametrosCombate.rivalUsaObjetos].
class UsarCuerdaHuida extends AccionCombate {
  final int indice;

  const UsarCuerdaHuida(super.bando, this.indice);
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
      throw const ReglaIncumplida(
          'Primero hay que elegir el siguiente Pokémon.');
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
    UsarPocion a => _usarPocion(estado, a),
    UsarCuerdaHuida a => _usarCuerdaHuida(estado, a),
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
          cegadoMientrasActivo: false,
          drenado: false,
          paralizado: false,
          ultimoAtaque: -1,
          racha: 0,
          enEspera: -1));
  final rep = estado.repetirDano;
  if (rep == null || rep.atacante == a.bando) {
    return nuevo.copiarCon(
        fase: nuevo.debenElegir.isEmpty
            ? FaseCombate.enCurso
            : FaseCombate.eligiendoActivo);
  }
  // Doble Patada: el que sale recibe de nuevo el ataque que derribó al anterior.
  final bando = nuevo.bando(a.bando);
  final activo = bando.pokemonActivo;
  final dano = danoDeAtaque(rep.ataque, activo.especie,
      reduccion: rep.reduccion, extra: bando.extraRecibido);
  final equipo = [...bando.equipo]..[bando.activo] =
      activo.conPs(activo.ps - dano);
  final golpeado = nuevo
      .conBando(a.bando, bando.copiarCon(equipo: equipo))
      .copiarCon(limpiarRepetirDano: true);
  if (golpeado.bando(a.bando).derrotado || _jefeCaido(golpeado)) {
    return golpeado.copiarCon(
        fase: FaseCombate.terminado, ganador: rep.atacante);
  }
  return golpeado.copiarCon(
      fase: golpeado.debenElegir.isEmpty
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
  if (atacante.paralizado) {
    throw const ReglaIncumplida('Está paralizado: este turno no puede atacar.');
  }
  if (atacante.energia < ataque.coste) {
    throw const ReglaIncumplida('No hay energía suficiente para ese ataque.');
  }
  final rivalBando = a.bando.otro;
  final defensor = estado.bando(rivalBando);
  final racha = atacante.ultimoAtaque == a.indice ? atacante.racha + 1 : 1;
  var semilla = estado.semilla;
  bool? moneda;
  final monedas = <bool>[];
  if (atacante.cegado || atacante.cegadoMientrasActivo) {
    // Bofetón Lodo o Pantalla de Humo del rival: con cruz este ataque no hace
    // nada. Pantalla de Humo sigue mientras el Pokémon siga activo.
    semilla = _siguienteSemilla(semilla);
    moneda = (semilla >> 8) & 1 == 1;
    monedas.add(moneda);
    if (!moneda) {
      final fallido = estado
          .conBando(
              a.bando,
              atacante.copiarCon(
                  energia: atacante.energia - ataque.coste,
                  cegado: false,
                  ultimoAtaque: a.indice,
                  racha: racha))
          .copiarCon(
              semilla: semilla, ultimaMoneda: moneda, ultimasMonedas: monedas);
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
  if (efecto is MonedasDano) {
    var caras = 0;
    for (var i = 0; i < efecto.monedas; i++) {
      semilla = _siguienteSemilla(semilla);
      moneda = (semilla >> 8) & 1 == 1;
      monedas.add(moneda);
      if (moneda) caras++;
    }
    golpe = AtaqueCampana(
        nombre: ataque.nombre,
        tipo: ataque.tipo,
        coste: ataque.coste,
        dano: efecto.danoPorCaras[caras]);
  }
  if (efecto is MonedaDanoExtra) {
    semilla = _siguienteSemilla(semilla);
    moneda = (semilla >> 8) & 1 == 1;
    monedas.add(moneda);
    if (moneda) {
      golpe = AtaqueCampana(
          nombre: ataque.nombre,
          tipo: ataque.tipo,
          coste: ataque.coste,
          dano: ataque.dano + efecto.valor);
    }
  }
  final habilidad = atacante.pokemonActivo.especie.habilidad;
  if (habilidad is MonedaDanoExtraAlAtacar) {
    semilla = _siguienteSemilla(semilla);
    moneda = (semilla >> 8) & 1 == 1;
    monedas.add(moneda);
    if (moneda) {
      golpe = AtaqueCampana(
          nombre: golpe.nombre,
          tipo: golpe.tipo,
          coste: golpe.coste,
          dano: golpe.dano + habilidad.valor);
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
    defensorNuevo =
        defensorNuevo.copiarCon(veneno: efecto.valor, drenado: false);
  }
  if (efecto is DrenaDefensor && !defensor.drenado) {
    // Drenadoras: el veneno de 10 sin acumular (si ya había uno mayor, se
    // queda el mayor) y, desde ahora, cada chequeo cura al otro bando.
    defensorNuevo = defensorNuevo.copiarCon(
        veneno: defensor.veneno > DrenaDefensor.dano
            ? defensor.veneno
            : DrenaDefensor.dano,
        drenado: true);
  }
  if (efecto is MonedaFalloRival) {
    defensorNuevo = efecto.mientrasActivo
        ? defensorNuevo.copiarCon(cegadoMientrasActivo: true)
        : defensorNuevo.copiarCon(cegado: true);
  }
  if (efecto is ParalizaDefensor) {
    // Dragoaliento: tras el daño, con suficientes caras queda Paralizado.
    var caras = 0;
    for (var i = 0; i < efecto.monedas; i++) {
      semilla = _siguienteSemilla(semilla);
      moneda = (semilla >> 8) & 1 == 1;
      monedas.add(moneda);
      if (moneda) caras++;
    }
    if (caras >= efecto.minimoCaras && golpeado.enPie) {
      defensorNuevo = defensorNuevo.copiarCon(paralizado: true);
    }
  }
  if (efecto is ConfundeDefensor) {
    // Supersónico e Hidropulso: si todas salen cara, el mismo estado que
    // Bofetón Lodo.
    var todasCara = true;
    for (var i = 0; i < efecto.monedas; i++) {
      semilla = _siguienteSemilla(semilla);
      moneda = (semilla >> 8) & 1 == 1;
      monedas.add(moneda);
      if (!moneda) todasCara = false;
    }
    if (todasCara) defensorNuevo = defensorNuevo.copiarCon(cegado: true);
  }
  if (efecto is QuitaEnergiaRival) {
    final resto = defensorNuevo.energia - efecto.valor;
    defensorNuevo = defensorNuevo.copiarCon(energia: resto < 0 ? 0 : resto);
  }
  var atacanteNuevo = atacante.copiarCon(
      energia: atacante.energia - ataque.coste,
      ultimoAtaque: a.indice,
      racha: racha);
  if (efecto is GanaEnergia) {
    // El coste ya está pagado; se suma después, con tope en el máximo.
    final max = estado.parametros.energiaMaxima;
    final total = atacanteNuevo.energia + efecto.valor;
    atacanteNuevo = atacanteNuevo.copiarCon(energia: total > max ? max : total);
  }
  if (efecto is ReduceDanoPropio && efecto.valor > atacante.proteccion) {
    atacanteNuevo = atacanteNuevo.copiarCon(proteccion: efecto.valor);
  }
  var nuevo = estado
      .conBando(a.bando, atacanteNuevo)
      .conBando(rivalBando, defensorNuevo)
      .copiarCon(
          semilla: semilla,
          ultimaMoneda: moneda,
          ultimasMonedas: monedas.isEmpty ? null : monedas);
  if (defensorNuevo.derrotado || _jefeCaido(nuevo)) {
    return nuevo.copiarCon(fase: FaseCombate.terminado, ganador: a.bando);
  }
  if (efecto is RepiteDanoAlDerribar && !golpeado.enPie) {
    nuevo = nuevo.copiarCon(
        repetirDano: DanoRepetido(a.bando, golpe, atacante.danoReducido));
  }
  return _terminarTurno(nuevo);
}

/// Cambiar siempre gasta el turno; además cuesta la retirada del Pokémon que
/// sale (0 de salida, así que normalmente solo cuesta el turno).
EstadoCombate _cambiar(EstadoCombate estado, Cambiar a) {
  final b = estado.bando(a.bando);
  if (b.paralizado) {
    throw const ReglaIncumplida(
        'Está paralizado: este turno no puede cambiar.');
  }
  if (a.indice == b.enEspera && b.relevos.contains(a.indice)) {
    throw ReglaIncumplida(estado.aliadoAlFrente
        ? 'El jefe no vuelve hasta que caiga su aliado.'
        : 'El aliado espera en la banca hasta que el jefe lo saque.');
  }
  if (!b.cambiables.contains(a.indice)) {
    throw const ReglaIncumplida('Ese Pokémon no puede salir.');
  }
  final retirada = b.pokemonActivo.especie.retirada;
  if (b.energia < retirada) {
    throw const ReglaIncumplida('No hay energía para retirar al Pokémon.');
  }
  return _terminarTurno(
      estado.conBando(a.bando, _conNuevoActivo(b, a.indice, b.energia - retirada)));
}

/// [b] con [indice] de activo y [energia]: se quitan los efectos que solo
/// duran mientras sigue el mismo activo.
BandoCombate _conNuevoActivo(BandoCombate b, int indice, int energia) =>
    b.copiarCon(
        activo: indice,
        energia: energia,
        danoReducido: 0,
        danoExtra: 0,
        veneno: 0,
        proteccion: 0,
        cegadoMientrasActivo: false,
        drenado: false,
        ultimoAtaque: -1,
        racha: 0);

/// Si [a] es válida, el estado con la Cuerda Huida usada y el turno
/// terminado; si no, lanza [ReglaIncumplida]. No paga la retirada y vale
/// aunque el activo esté Paralizado.
EstadoCombate _usarCuerdaHuida(EstadoCombate estado, UsarCuerdaHuida a) {
  final b = estado.bando(a.bando);
  if (a.bando == Bando.rival && !estado.parametros.rivalUsaObjetos) {
    throw const ReglaIncumplida('El rival no usa objetos.');
  }
  if (b.cuerdas < 1) {
    throw const ReglaIncumplida('No te quedan Cuerdas Huida.');
  }
  if (a.indice == b.enEspera && b.relevos.contains(a.indice)) {
    throw ReglaIncumplida(estado.aliadoAlFrente
        ? 'El jefe no vuelve hasta que caiga su aliado.'
        : 'El aliado espera en la banca hasta que el jefe lo saque.');
  }
  if (!b.cambiables.contains(a.indice)) {
    throw const ReglaIncumplida('Ese Pokémon no puede salir.');
  }
  final nuevo = _conNuevoActivo(b, a.indice, b.energia)
      .copiarCon(cuerdas: b.cuerdas - 1, cuerdasUsadas: b.cuerdasUsadas + 1);
  return _terminarTurno(estado.conBando(a.bando, nuevo));
}

/// A quién puede sacar ahora [bando] con una Cuerda Huida (índices del
/// equipo), o vacío si no puede usarla: no es su turno, no le quedan, es el
/// rival sin [ParametrosCombate.rivalUsaObjetos] o no tiene relevos.
List<int> objetivosDeCuerda(EstadoCombate estado, Bando bando) {
  final b = estado.bando(bando);
  if (estado.fase != FaseCombate.enCurso ||
      estado.turno != bando ||
      b.cuerdas < 1 ||
      (bando == Bando.rival && !estado.parametros.rivalUsaObjetos)) {
    return const [];
  }
  return b.cambiables;
}

/// Si [a] es válida, el estado con la Poción usada; si no, lanza
/// [ReglaIncumplida]. No termina el turno ni toca la racha ni los estados.
EstadoCombate _usarPocion(EstadoCombate estado, UsarPocion a) {
  final p = estado.parametros;
  final b = estado.bando(a.bando);
  if (a.bando == Bando.rival && !p.rivalUsaObjetos) {
    throw const ReglaIncumplida('El rival no usa objetos.');
  }
  if (b.pociones < 1) throw const ReglaIncumplida('No te quedan Pociones.');
  if (a.indice < 0 || a.indice >= b.equipo.length) {
    throw const ReglaIncumplida('Ese Pokémon no está en el equipo.');
  }
  if (!p.pocionCuraBanca && a.indice != b.activo) {
    throw const ReglaIncumplida(
        'En combate, la Poción solo cura al Pokémon activo.');
  }
  final x = b.equipo[a.indice];
  if (!x.enPie) {
    throw const ReglaIncumplida('Una Poción no revive a un Pokémon.');
  }
  final max = x.especie.ps;
  if (x.ps >= max) throw const ReglaIncumplida('Ya tiene todos sus PS.');
  final ps = x.ps + p.psPocion;
  return estado.conBando(
    a.bando,
    b.copiarCon(
      equipo: [...b.equipo]..[a.indice] = x.conPs(ps > max ? max : ps),
      pociones: b.pociones - 1,
      pocionesUsadas: b.pocionesUsadas + 1,
    ),
  );
}

/// A quién puede curar ahora [bando] con una Poción (índices del equipo), o
/// vacío si no puede usarla: no es su turno, no le quedan, es el rival sin
/// [ParametrosCombate.rivalUsaObjetos] o nadie en pie le falta PS.
List<int> objetivosDePocion(EstadoCombate estado, Bando bando) {
  final p = estado.parametros;
  final b = estado.bando(bando);
  if (estado.fase != FaseCombate.enCurso ||
      estado.turno != bando ||
      b.pociones < 1 ||
      (bando == Bando.rival && !p.rivalUsaObjetos)) {
    return const [];
  }
  return [
    for (var i = 0; i < b.equipo.length; i++)
      if ((p.pocionCuraBanca || i == b.activo) &&
          b.equipo[i].enPie &&
          b.equipo[i].ps < b.equipo[i].especie.ps)
        i,
  ];
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
  // Bofetón Lodo y la parálisis solo duran el turno que acaba de jugarse.
  final cambiado = estado
      .conBando(termina,
          actual.copiarCon(energia: energia, cegado: false, paralizado: false))
      .copiarCon(
        turno: termina.otro,
        numeroTurno: estado.numeroTurno + 1,
      );
  final chequeado = _chequeoPokemon(cambiado, termina);
  if (chequeado.fase == FaseCombate.terminado) return chequeado;
  if (_jefeCaido(chequeado)) {
    return chequeado.copiarCon(
        fase: FaseCombate.terminado, ganador: Bando.jugador);
  }
  final tras = _llamarAliado(chequeado);
  // Si cae algún activo (por un ataque o por el veneno), hay que elegir relevo.
  return tras.debenElegir.isEmpty
      ? tras
      : tras.copiarCon(fase: FaseCombate.eligiendoActivo);
}

/// Chequeo Pokémon, cada vez que cambia el turno: el activo envenenado de cada
/// bando pierde su veneno en PS (salvo con Muro Mágico, [SinDanoIndirecto]). Va primero el bando que acaba de terminar su
/// turno; si su último Pokémon cae, el combate termina y gana el otro aunque
/// el segundo chequeo también lo hubiera derribado.
EstadoCombate _chequeoPokemon(EstadoCombate estado, Bando primero) {
  var s = estado;
  for (final b in [primero, primero.otro]) {
    final bando = s.bando(b);
    final activo = bando.pokemonActivo;
    if (bando.veneno <= 0 || !activo.enPie) continue;
    // Muro Mágico: sigue Envenenado pero no pierde PS, y Drenadoras tampoco
    // cura (no ha quitado nada).
    if (sinDanoIndirecto(activo.especie)) continue;
    final equipo = [...bando.equipo]..[bando.activo] =
        activo.conPs(activo.ps - bando.veneno);
    final nuevo = bando.copiarCon(equipo: equipo);
    s = s.conBando(b, nuevo);
    if (bando.drenado) {
      // Drenadoras: el chequeo ha quitado PS, así que cura al activo del otro
      // bando (el que esté ahora), hasta su máximo y si sigue en pie.
      final otro = s.bando(b.otro);
      final suyo = otro.pokemonActivo;
      if (suyo.enPie && suyo.ps < suyo.especie.ps) {
        final ps = suyo.ps + DrenaDefensor.cura;
        s = s.conBando(
            b.otro,
            otro.copiarCon(
                equipo: [...otro.equipo]..[otro.activo] =
                    suyo.conPs(ps > suyo.especie.ps ? suyo.especie.ps : ps)));
      }
    }
    if (nuevo.derrotado) {
      return s.copiarCon(fase: FaseCombate.terminado, ganador: b.otro);
    }
  }
  return s;
}

/// Con llamada de aliado, el combate se gana cuando cae el jefe, aunque su
/// aliado siga en pie (D-20 §4, Jefes).
bool _jefeCaido(EstadoCombate e) {
  final l = e.llamada;
  return l != null && !e.rival.equipo[l.jefe].enPie;
}

/// Llamada de aliado del jefe (D-20 §4, Jefes). Se comprueba al terminar cada
/// turno, después del chequeo Pokémon, así que cuenta cualquier daño: el de
/// un ataque y el del veneno. Con el jefe activo y en pie: al llegar al
/// primer umbral invoca a un aliado elegido con la semilla, que aparece en la
/// banca; al llegar al segundo, el jefe se retira a la banca (pierde todos
/// sus efectos, como al cambiar) y el aliado pasa al puesto activo. Un mismo
/// golpe puede hacer las dos cosas.
EstadoCombate _llamarAliado(EstadoCombate estado) {
  final llamada = estado.llamada;
  if (llamada == null || estado.aliadoAlFrente) return estado;
  var s = estado;
  var rival = s.rival;
  if (rival.activo != llamada.jefe) return s;
  final jefe = rival.pokemonActivo;
  if (!jefe.enPie) return s;
  bool llega(int porcentaje) => jefe.ps * 100 <= porcentaje * jefe.especie.ps;
  if (!s.llamadaHecha) {
    if (!llega(llamada.porcentaje)) return s;
    final semilla = _siguienteSemilla(s.semilla);
    final elegido = llamada.aliados[(semilla >> 8) % llamada.aliados.length];
    final posicion = rival.equipo.length;
    rival = rival.copiarCon(
        equipo: [...rival.equipo, PokemonEnCombate.completo(elegido)],
        enEspera: posicion);
    s = s
        .conBando(Bando.rival, rival)
        .copiarCon(semilla: semilla, aliado: posicion);
  }
  if (!llega(llamada.alFrente)) return s;
  return s
      .conBando(
          Bando.rival,
          rival.copiarCon(
            activo: s.aliado,
            danoReducido: 0,
            danoExtra: 0,
            veneno: 0,
            proteccion: 0,
            cegado: false,
            cegadoMientrasActivo: false,
            drenado: false,
            paralizado: false,
            ultimoAtaque: -1,
            racha: 0,
            enEspera: llamada.jefe,
          ))
      .copiarCon(aliadoAlFrente: true);
}
