import 'dart:math';

/// Carta del mazo de ataques del jefe (Incursión Max, 20 cartas): qué ataque
/// usa el jefe, contra qué jugador y si hay que robar otra carta.
final class CartaAtaqueJefe {
  /// Número impreso, de 1 a 20.
  final int numero;

  /// Ataque del jefe: 1, 2 o 3.
  final int ranura;

  /// Asiento del jugador atacado, de 0 a 3 («Jugador 1» a «Jugador 4»).
  final int jugador;

  /// La carta dice «Roba una carta más».
  final bool robaOtra;

  const CartaAtaqueJefe({
    required this.numero,
    required this.ranura,
    required this.jugador,
    required this.robaOtra,
  });

  @override
  String toString() =>
      'CartaAtaqueJefe($numero: ataque $ranura, jugador ${jugador + 1}'
      '${robaOtra ? ', roba otra' : ''})';
}

/// Las 20 cartas del PDF oficial «Cartas de ataque del Jefe».
///
/// 1-8: ataque 1 · 9-16: ataque 2 · 17-20: ataque 3; el objetivo recorre los
/// jugadores 1 a 4 en cada grupo de cuatro. Piden robar otra las cartas 1 a
/// 12 y la 20.
final List<CartaAtaqueJefe> cartasAtaqueJefe = List.unmodifiable([
  for (var n = 1; n <= 20; n++)
    CartaAtaqueJefe(
      numero: n,
      ranura: n <= 8 ? 1 : (n <= 16 ? 2 : 3),
      jugador: (n - 1) % 4,
      robaOtra: n <= 12 || n == 20,
    ),
]);

/// Máximo de ataques del jefe en un turno según su nivel: nivel + 1 (Nv1: 2,
/// Nv2: 3, Nv3: 4; el Nv4, propio de este formato, 5, como en D-03).
int maxAtaquesJefePorTurno(int nivel) => nivel + 1;

/// Las cartas del mazo según los jugadores de la partida:
///
/// - 4 jugadores: las 20 del juego oficial.
/// - 3 jugadores: desaparecen las 5 del Jugador 4 (quedan 15).
/// - 2 jugadores: siguen las 20; las del Jugador 3 apuntan al Jugador 1 y las
///   del Jugador 4 al Jugador 2.
/// - 1 jugador: siguen las 20, todas contra él.
List<CartaAtaqueJefe> cartasAtaqueJefePara(int jugadores) {
  if (jugadores < 1 || jugadores > 4) {
    throw ArgumentError.value(jugadores, 'jugadores', 'debe estar entre 1 y 4');
  }
  return [
    for (final c in cartasAtaqueJefe)
      if (jugadores == 3 && c.jugador == 3)
        ...const <CartaAtaqueJefe>[]
      else
        CartaAtaqueJefe(
          numero: c.numero,
          ranura: c.ranura,
          jugador: jugadores >= 3 ? c.jugador : c.jugador % jugadores,
          robaOtra: c.robaOtra,
        ),
  ];
}

/// Mazo de ataques del jefe: se baraja, se roba y, al agotarse, se baraja el
/// descarte.
class MazoAtaquesJefe {
  /// [jugadores]: los de la partida (1 a 4), que deciden las cartas del mazo
  /// (véase [cartasAtaqueJefePara]).
  MazoAtaquesJefe(this._azar, {int jugadores = 4}) {
    _mazo.addAll(cartasAtaqueJefePara(jugadores));
    _mazo.shuffle(_azar);
  }

  final Random _azar;
  final List<CartaAtaqueJefe> _mazo = [];
  final List<CartaAtaqueJefe> _descarte = [];

  /// Cartas que quedan por robar.
  int get restantes => _mazo.length;

  /// Roba la siguiente carta que apunte a uno de los [jugadoresActivos]
  /// (asientos). La carta que apunta a un jugador que no juega o está
  /// eliminado se descarta sin efecto y se roba otra.
  CartaAtaqueJefe robar(Set<int> jugadoresActivos) {
    if (!_mazo.followedBy(_descarte).any((c) => jugadoresActivos.contains(c.jugador))) {
      throw StateError('no hay ninguna carta que apunte a un jugador activo');
    }
    while (true) {
      if (_mazo.isEmpty) {
        _mazo.addAll(_descarte);
        _descarte.clear();
        _mazo.shuffle(_azar);
      }
      final carta = _mazo.removeLast();
      _descarte.add(carta);
      if (jugadoresActivos.contains(carta.jugador)) return carta;
    }
  }
}
