/// Se lanza cuando un evento no se puede aplicar al estado actual.
class ReglaIncumplida implements Exception {
  final String mensaje;

  const ReglaIncumplida(this.mensaje);

  @override
  String toString() => 'ReglaIncumplida: $mensaje';
}

/// Se lanza cuando un registro de partida (JSON) no cumple el contrato:
/// versión no soportada, estructura incorrecta o eventos que rompen las reglas.
class RegistroInvalido implements Exception {
  final String mensaje;

  const RegistroInvalido(this.mensaje);

  @override
  String toString() => 'RegistroInvalido: $mensaje';
}
