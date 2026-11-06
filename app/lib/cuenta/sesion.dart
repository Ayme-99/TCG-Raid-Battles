/// Sesión iniciada con una cuenta de Deck Tracker.
class Sesion {
  const Sesion({
    required this.token,
    required this.username,
    required this.userId,
  });

  factory Sesion.deJson(Map<String, Object?> json) => Sesion(
        token: json['token']! as String,
        username: json['username']! as String,
        userId: json['userId']! as String,
      );

  final String token;
  final String username;

  /// Id de usuario de Deck Tracker: es el que va en `cuentas` del registro.
  final String userId;

  Map<String, Object?> toJson() =>
      {'token': token, 'username': username, 'userId': userId};
}
