import 'errores.dart';
import 'estado.dart';
import 'eventos.dart';

/// Efecto de un aliado que ejecuta el programa (D-13). Recibe el estado y el
/// aliado y devuelve el estado nuevo. Tiene que ser determinista: nada de
/// azar ni de reloj. Si el efecto necesita una tirada, la hace la mesa y la
/// registra como un evento.
///
/// Un script no puede terminar la partida: si el estado que devuelve no está
/// en la misma fase, el motor rechaza el evento.
typedef EfectoAliado = EstadoPartida Function(
  EstadoPartida estado,
  AliadoEstado aliado,
);

/// Como [EfectoAliado], pero recibe también el evento de invocación (para leer
/// las monedas que registró la app).
typedef EfectoAliadoAlEntrar = EstadoPartida Function(
  EstadoPartida estado,
  AliadoEstado aliado,
  AliadoInvocado evento,
);

/// Como [EfectoAliado], pero recibe también el evento del ataque (para leer
/// la moneda que registró la app).
typedef EfectoAliadoAlAtacar = EstadoPartida Function(
  EstadoPartida estado,
  AliadoEstado aliado,
  AtaqueAliado evento,
);

/// Los momentos en los que un script puede actuar. Cualquiera puede faltar.
class ScriptAliado {
  /// Justo después de invocar al aliado.
  final EfectoAliado? alEntrar;

  /// Al cerrar el turno del jefe, antes del chequeo de estados del jefe
  /// (D-12) y en el orden en que se invocaron los aliados.
  final EfectoAliado? alFinTurnoJefe;

  /// Justo después de un ataque del aliado (al entrar o al final del turno
  /// del jefe), con el aliado ya anotado como que ha atacado.
  final EfectoAliado? alAtacar;

  /// Como [alEntrar], con acceso al evento de invocación.
  final EfectoAliadoAlEntrar? alEntrarConEvento;

  /// Como [alAtacar], con acceso al evento del ataque.
  final EfectoAliadoAlAtacar? alAtacarConEvento;

  /// Mientras el aliado siga vivo, los jugadores solo pueden atacarlo a él
  /// (o pasar el turno con 0 de daño) (Bloqueo).
  final bool provoca;

  /// Daño que el propio aliado recibe de menos por cada ataque de los
  /// jugadores, además de las reducciones de otros aliados (Bloqueo).
  final int reduccionPropia;

  /// Daño extra que el jefe suma a cada uno de sus ataques mientras el aliado
  /// siga vivo (D-16, Potenciador). Con [bonusConMoneda] solo se suma si al
  /// tirar una moneda sale cara. La tirada la hace la app, que ya registra el
  /// daño final del ataque; el motor no calcula el daño de los ataques del
  /// jefe.
  final int bonusAtaqueJefe;
  final bool bonusConMoneda;

  /// El bonus solo se suma al primer ataque del jefe de cada turno.
  final bool bonusSoloPrimerAtaque;

  /// Mientras el aliado siga vivo, el jefe no puede sufrir estados (veneno,
  /// quemadura): se rechaza aplicarlos.
  final bool bloqueaEstados;

  /// Daño que el jefe y los aliados reciben de menos por cada ataque de los
  /// jugadores
  /// mientras el aliado siga vivo. Las reducciones de varios aliados se suman
  /// y el daño de un ataque nunca baja de 0.
  final int reduccionDano;

  /// Aura (Moflete Estático): mientras el aliado está en juego, cada vez que
  /// un ataque de los jugadores deja fuera de combate a un aliado (él
  /// incluido), el Pokémon atacante queda Paralizado. El motor lo anota como
  /// efecto activo sobre ese jugador durante su siguiente turno.
  final bool paralizaAlCaerAliado;

  /// Al entrar deja un efecto que sigue aplicado el resto de la partida,
  /// aunque el aliado caiga (Fijar Blanco). Lo resuelve la mesa; el motor lo
  /// guarda en `efectosPermanentes` para que el asistente lo recuerde.
  final bool efectoPermanente;

  const ScriptAliado({
    this.alEntrar,
    this.alFinTurnoJefe,
    this.alAtacar,
    this.alEntrarConEvento,
    this.alAtacarConEvento,
    this.provoca = false,
    this.reduccionPropia = 0,
    this.bonusAtaqueJefe = 0,
    this.bonusConMoneda = false,
    this.bonusSoloPrimerAtaque = false,
    this.bloqueaEstados = false,
    this.reduccionDano = 0,
    this.paralizaAlCaerAliado = false,
    this.efectoPermanente = false,
  });
}

/// Bonus de daño que un aliado Potenciador vivo añade a los ataques del jefe.
class BonusAtaqueJefe {
  final String aliado;
  final int valor;
  final bool conMoneda;

  const BonusAtaqueJefe(this.aliado, this.valor, this.conMoneda);
}

/// Bonus de los aliados vivos cuyos efectos aplica el programa. La app tira
/// la moneda de cada uno que la lleve y suma el valor al daño del ataque.
List<BonusAtaqueJefe> bonusAtaqueJefeActivos(
  EstadoPartida e, [
  Map<String, ScriptAliado> scripts = scriptsAliado,
]) {
  final bonus = <BonusAtaqueJefe>[];
  for (final a in e.aliados) {
    final id = a.scriptId;
    if (a.efectos != EfectosAliado.programa || id == null) continue;
    final script = scripts[id];
    if (script == null || script.bonusAtaqueJefe <= 0) continue;
    if (script.bonusSoloPrimerAtaque && e.ataquesJefeEnTurno > 0) continue;
    bonus.add(BonusAtaqueJefe(
      a.nombre,
      script.bonusAtaqueJefe,
      script.bonusConMoneda,
    ));
  }
  return bonus;
}

/// El jefe no puede sufrir estados mientras viva un aliado con
/// `bloqueaEstados` (Velo Sagrado) cuyos efectos aplica el programa.
bool estadosBloqueados(
  EstadoPartida e, [
  Map<String, ScriptAliado> scripts = scriptsAliado,
]) {
  for (final a in e.aliados) {
    final id = a.scriptId;
    if (a.efectos != EfectosAliado.programa || id == null) continue;
    if (scripts[id]?.bloqueaEstados ?? false) return true;
  }
  return false;
}

/// Daño que el jefe y los aliados reciben de menos por cada ataque de los
/// jugadores por los aliados vivos cuyos efectos aplica el programa (categoría Tanque, D-13).
int reduccionDanoAlJefe(
  EstadoPartida e, [
  Map<String, ScriptAliado> scripts = scriptsAliado,
]) {
  var total = 0;
  for (final a in e.aliados) {
    final id = a.scriptId;
    if (a.efectos != EfectosAliado.programa || id == null) continue;
    total += scripts[id]?.reduccionDano ?? 0;
  }
  return total;
}

/// Hay en juego un aliado con el aura de Moflete Estático: el jugador que
/// deje fuera de combate a un aliado con un ataque queda Paralizado.
bool paralizaAlCaerAliado(
  EstadoPartida e, [
  Map<String, ScriptAliado> scripts = scriptsAliado,
]) {
  for (final a in e.aliados) {
    final id = a.scriptId;
    if (a.efectos != EfectosAliado.programa || id == null) continue;
    if (scripts[id]?.paralizaAlCaerAliado ?? false) return true;
  }
  return false;
}

/// Daño que se resta al próximo ataque del jugador [jugador], vaya contra el
/// jefe o contra un aliado: las reducciones de los aliados en juego (Rizo
/// Defensa, Gruñido) más su debilitación pendiente (Fuerza Lunar). No incluye
/// la reducción propia de un aliado (Bloqueo), que depende del objetivo.
int reduccionParaJugador(
  EstadoPartida e,
  int jugador, [
  Map<String, ScriptAliado> scripts = scriptsAliado,
]) =>
    reduccionDanoAlJefe(e, scripts) + (e.debilitados[jugador] ?? 0);

/// Aliado que obliga a los jugadores a atacarle (Bloqueo), o null.
AliadoEstado? aliadoProvocador(
  EstadoPartida e, [
  Map<String, ScriptAliado> scripts = scriptsAliado,
]) {
  for (final a in e.aliados) {
    final id = a.scriptId;
    if (a.efectos != EfectosAliado.programa || id == null) continue;
    if (scripts[id]?.provoca ?? false) return a;
  }
  return null;
}

/// Reducción extra de daño que recibe el aliado [a] por su propia habilidad.
int reduccionPropiaDe(
  AliadoEstado a, [
  Map<String, ScriptAliado> scripts = scriptsAliado,
]) {
  final id = a.scriptId;
  if (a.efectos != EfectosAliado.programa || id == null) return 0;
  return scripts[id]?.reduccionPropia ?? 0;
}

/// Sustituye el aliado del slot [slot] por [nuevo].
EstadoPartida _conAliado(EstadoPartida e, AliadoEstado nuevo) =>
    e.copiarCon(
      aliados: [
        for (final a in e.aliados)
          if (a.slot == nuevo.slot) nuevo else a,
      ],
    );

/// Deseo: el jefe lanza 10 monedas y se cura 100 por cada cara; cada aliado
/// (el propio incluido, por orden de slot de entrada) lanza una y, con cara,
/// se cura 100. Las monedas las tira la app y vienen en el evento: primero
/// las 10 del jefe y después una por aliado en el orden de `aliados`. Los
/// Pokémon de los jugadores lanzan las suyas en la mesa.
EstadoPartida _deseo100(
  EstadoPartida e,
  AliadoEstado a,
  AliadoInvocado ev,
) {
  final monedas = ev.monedas;
  final esperadas = 10 + e.aliados.length;
  if (monedas == null || monedas.length != esperadas) {
    throw ReglaIncumplida(
      'Deseo necesita $esperadas monedas (10 del jefe y una por aliado)',
    );
  }
  final carasJefe = monedas.take(10).where((c) => c).length;
  var r = _curarJefe(e, 100 * carasJefe);
  r = r.copiarCon(
    aliados: [
      for (var i = 0; i < r.aliados.length; i++)
        if (monedas[10 + i])
          r.aliados[i].copiarCon(
            hp: r.aliados[i].hp + 100 < r.aliados[i].hpMaximo
                ? r.aliados[i].hp + 100
                : r.aliados[i].hpMaximo,
          )
        else
          r.aliados[i],
    ],
  );
  return r;
}

/// Envite Ígneo: en cada uso el aliado gana 10 HP (máximo y actual).
EstadoPartida _enviteIgneo10(EstadoPartida e, AliadoEstado a) => _conAliado(
      e,
      a.copiarCon(hpMaximo: a.hpMaximo + 10, hp: a.hp + 10),
    );

/// Fuerza Lunar: si la moneda del jugador rival sale cruz, sus ataques hacen
/// 30 puntos menos en el siguiente turno que juegue.
EstadoPartida _fuerzaLunar30(
  EstadoPartida e,
  AliadoEstado a,
  AtaqueAliado ev,
) {
  final moneda = ev.moneda;
  if (moneda == null) {
    throw const ReglaIncumplida(
      'Fuerza Lunar necesita el resultado de la moneda del jugador rival',
    );
  }
  if (moneda) return e;
  final rival = ev.objetivo ?? a.slot;
  return e.copiarCon(debilitados: {...e.debilitados, rival: 30});
}

/// El jefe se cura [cantidad] HP sin pasar de su máximo. Cuenta como
/// curación del jefe igual que el evento `CuracionJefe` (la resta del daño
/// total y de los puntos).
EstadoPartida _curarJefe(EstadoPartida e, int cantidad) {
  final jefe = e.jefe!;
  final falta = jefe.hpMaximo - jefe.hp;
  final sube = cantidad < falta ? cantidad : falta;
  return e.copiarCon(
    jefe: jefe.conHp(jefe.hp + sube),
    curacionJefe: e.curacionJefe + sube,
  );
}

/// Cura [cantidad] HP al jefe y a cada aliado vivo (el que actúa incluido),
/// sin pasar del máximo de cada uno.
EstadoPartida _curarJefeYAliados(EstadoPartida e, int cantidad) {
  final conJefe = _curarJefe(e, cantidad);
  return conJefe.copiarCon(
    aliados: [
      for (final a in conJefe.aliados)
        a.copiarCon(
          hp: a.hp + cantidad < a.hpMaximo ? a.hp + cantidad : a.hpMaximo,
        ),
    ],
  );
}

EstadoPartida _chupavidas10(EstadoPartida e, AliadoEstado a) =>
    _curarJefeYAliados(e, 10);
EstadoPartida _chupavidas30(EstadoPartida e, AliadoEstado a) =>
    _curarJefeYAliados(e, 30);

/// Velo Sagrado: al entrar se quitan los estados que tuviera el jefe (las
/// aplicaciones ya contadas para el bono se conservan).
EstadoPartida _veloSagrado(EstadoPartida e, AliadoEstado a) =>
    e.copiarCon(jefe: e.jefe!.conEstados(envenenado: false, quemado: false));

/// Drenadoras: los jugadores ponen un contador de daño (10) en cada Pokémon
/// Activo y el jefe se cura 10 por cada uno. Se cuenta un contador por jugador
/// no eliminado.
EstadoPartida _drenadoras10(EstadoPartida e, AliadoEstado a) {
  final contadores = e.jugadores.where((j) => !j.eliminado).length;
  return _curarJefe(e, 10 * contadores);
}

// Funciones de nivel superior para poder usarlas en un mapa `const`.
EstadoPartida _cura20(EstadoPartida e, AliadoEstado a) => _curarJefe(e, 20);
EstadoPartida _cura30(EstadoPartida e, AliadoEstado a) => _curarJefe(e, 30);
EstadoPartida _cura40(EstadoPartida e, AliadoEstado a) => _curarJefe(e, 40);
EstadoPartida _cura50(EstadoPartida e, AliadoEstado a) => _curarJefe(e, 50);

/// Scripts de aliados disponibles, por identificador. Los de la categoría
/// Cura curan al jefe al final de su turno (antes del chequeo de estados) y
/// los de la categoría Tanque reducen el daño que reciben el jefe y los aliados. Los efectos
/// que afectan a los Pokémon de los jugadores los siguen aplicando ellos.
const Map<String, ScriptAliado> scriptsAliado = {
  'cura-jefe-20': ScriptAliado(alFinTurnoJefe: _cura20),
  'cura-jefe-30': ScriptAliado(alFinTurnoJefe: _cura30),
  'cura-jefe-40': ScriptAliado(alFinTurnoJefe: _cura40),
  'cura-jefe-50': ScriptAliado(alFinTurnoJefe: _cura50),
  'chupavidas-10': ScriptAliado(alAtacar: _chupavidas10),
  'chupavidas-30': ScriptAliado(alAtacar: _chupavidas30),
  'bloqueo-100': ScriptAliado(provoca: true, reduccionPropia: 100),
  'deseo-100': ScriptAliado(alEntrarConEvento: _deseo100),
  'envite-igneo-10': ScriptAliado(alAtacar: _enviteIgneo10),
  'fuerza-lunar-30': ScriptAliado(alAtacarConEvento: _fuerzaLunar30),
  'velo-sagrado': ScriptAliado(alEntrar: _veloSagrado, bloqueaEstados: true),
  'agilidad-30': ScriptAliado(bonusAtaqueJefe: 30, bonusSoloPrimerAtaque: true),
  'foco-energia-10': ScriptAliado(bonusAtaqueJefe: 10, bonusConMoneda: true),
  'drenadoras-10': ScriptAliado(
    alEntrar: _drenadoras10,
    alFinTurnoJefe: _drenadoras10,
  ),
  'aullido-20': ScriptAliado(bonusAtaqueJefe: 20),
  'grunido-10': ScriptAliado(reduccionDano: 10),
  'moflete-estatico': ScriptAliado(paralizaAlCaerAliado: true),
  'fijar-blanco': ScriptAliado(efectoPermanente: true),
  'tanque-jefe-10': ScriptAliado(reduccionDano: 10),
  'tanque-jefe-20': ScriptAliado(reduccionDano: 20),
  'tanque-jefe-30': ScriptAliado(reduccionDano: 30),
  'tanque-jefe-40': ScriptAliado(reduccionDano: 40),
};
