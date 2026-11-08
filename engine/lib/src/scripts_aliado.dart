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

/// Los momentos en los que un script puede actuar. Cualquiera puede faltar.
class ScriptAliado {
  /// Justo después de invocar al aliado.
  final EfectoAliado? alEntrar;

  /// Al cerrar el turno del jefe, antes del chequeo de estados del jefe
  /// (D-12) y en el orden en que se invocaron los aliados.
  final EfectoAliado? alFinTurnoJefe;

  /// Daño que el jefe recibe de menos por cada ataque de los jugadores
  /// mientras el aliado siga vivo. Las reducciones de varios aliados se suman
  /// y el daño de un ataque nunca baja de 0.
  final int reduccionDano;

  const ScriptAliado({
    this.alEntrar,
    this.alFinTurnoJefe,
    this.reduccionDano = 0,
  });
}

/// Daño que el jefe recibe de menos por cada ataque de los jugadores por los
/// aliados vivos cuyos efectos aplica el programa (categoría Tanque, D-13).
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

// Funciones de nivel superior para poder usarlas en un mapa `const`.
EstadoPartida _cura20(EstadoPartida e, AliadoEstado a) => _curarJefe(e, 20);
EstadoPartida _cura30(EstadoPartida e, AliadoEstado a) => _curarJefe(e, 30);
EstadoPartida _cura40(EstadoPartida e, AliadoEstado a) => _curarJefe(e, 40);
EstadoPartida _cura50(EstadoPartida e, AliadoEstado a) => _curarJefe(e, 50);

/// Scripts de aliados disponibles, por identificador. Los de la categoría
/// Cura curan al jefe al final de su turno (antes del chequeo de estados) y
/// los de la categoría Tanque reducen el daño que recibe el jefe. Los efectos
/// que afectan a los Pokémon de los jugadores los siguen aplicando ellos.
const Map<String, ScriptAliado> scriptsAliado = {
  'cura-jefe-20': ScriptAliado(alFinTurnoJefe: _cura20),
  'cura-jefe-30': ScriptAliado(alFinTurnoJefe: _cura30),
  'cura-jefe-40': ScriptAliado(alFinTurnoJefe: _cura40),
  'cura-jefe-50': ScriptAliado(alFinTurnoJefe: _cura50),
  'tanque-jefe-10': ScriptAliado(reduccionDano: 10),
  'tanque-jefe-20': ScriptAliado(reduccionDano: 20),
  'tanque-jefe-30': ScriptAliado(reduccionDano: 30),
  'tanque-jefe-40': ScriptAliado(reduccionDano: 40),
};
