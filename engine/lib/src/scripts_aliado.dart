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

/// Scripts de aliados disponibles, por identificador. Los efectos concretos
/// llegan con las cartas de los jefes (T-14): hoy está vacío, así que ninguna
/// carta puede declarar todavía efectos del programa. El motor admite otro
/// catálogo en `apply(..., scripts: ...)`, que es lo que usan los tests.
const Map<String, ScriptAliado> scriptsAliado = {};
