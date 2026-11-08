import 'estado.dart';

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

  const ScriptAliado({this.alEntrar, this.alFinTurnoJefe});
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
/// Cura curan al jefe al final de su turno (antes del chequeo de estados).
/// Los efectos de las demás cartas los siguen aplicando los jugadores.
const Map<String, ScriptAliado> scriptsAliado = {
  'cura-jefe-20': ScriptAliado(alFinTurnoJefe: _cura20),
  'cura-jefe-30': ScriptAliado(alFinTurnoJefe: _cura30),
  'cura-jefe-40': ScriptAliado(alFinTurnoJefe: _cura40),
  'cura-jefe-50': ScriptAliado(alFinTurnoJefe: _cura50),
};
