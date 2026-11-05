/// Se lanza cuando un evento no se puede aplicar al estado actual.
class ReglaIncumplida implements Exception {
  final String mensaje;

  const ReglaIncumplida(this.mensaje);

  @override
  String toString() => 'ReglaIncumplida: $mensaje';
}
