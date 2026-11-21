import 'tipos.dart';

/// Efecto de un ataque (D-20 §3.6). Hoy hay cuatro; los demás (monedas,
/// estados…) llegan con las cartas que los necesiten.
sealed class EfectoAtaque {
  const EfectoAtaque();
}

/// Mientras el Pokémon activo del rival siga activo, sus ataques hacen
/// [valor] puntos menos de daño, antes de aplicar debilidad y resistencia.
/// No se acumula: un segundo uso no quita más. Se acaba cuando ese Pokémon cae
/// o se cambia a la banca (Gruñido).
class ReduceDanoRival extends EfectoAtaque {
  final int valor;

  const ReduceDanoRival(this.valor);
}

/// Mientras el Pokémon activo del rival siga activo, recibe [valor] puntos más
/// de daño de los ataques, antes de aplicar debilidad y resistencia. No se
/// acumula. Se acaba cuando ese Pokémon cae o se cambia a la banca (Látigo).
class AumentaDanoRecibido extends EfectoAtaque {
  final int valor;

  const AumentaDanoRecibido(this.valor);
}

/// El rival pierde [valor] de energía (si le queda alguna) en el momento de
/// usar el ataque. Se aplica una vez y no deja estado (Disparo Demora).
class QuitaEnergiaRival extends EfectoAtaque {
  final int valor;

  const QuitaEnergiaRival(this.valor);
}

/// Lanza una moneda al atacar: si sale cara, el ataque hace [valor] puntos de
/// daño más (Hiper Colmillo). El daño de la carta ([AtaqueCampana.dano]) es el
/// de cruz; el extra se suma al daño base, antes de reducciones, debilidad y
/// resistencia. La moneda sale de la semilla del combate: mismo estado y misma
/// semilla, mismo resultado.
class MonedaDanoExtra extends EfectoAtaque {
  final int valor;

  const MonedaDanoExtra(this.valor);
}

/// Un ataque de un Pokémon de campaña. Un ataque con [efecto] puede tener
/// [dano] 0 (solo hace el efecto).
class AtaqueCampana {
  final String nombre;
  final TipoCampana tipo;

  /// Energía que gasta.
  final int coste;
  final int dano;
  final EfectoAtaque? efecto;

  const AtaqueCampana({
    required this.nombre,
    required this.tipo,
    required this.coste,
    required this.dano,
    this.efecto,
  });
}

/// Cómo se consigue una evolución (D-20 §2.1).
enum ViaEvolucion {
  /// Acumulando XP (convertida de puntos en un centro Pokémon).
  xp,

  /// Con un objeto de evolución (una piedra…).
  objeto,

  /// Por intercambio: cuesta puntos por usar la máquina de intercambio.
  intercambio,

  /// Gastando puntos, para hacerse ex un Pokémon que no evoluciona.
  puntos,
}

/// Una evolución posible de un Pokémon. La carta evolucionada sustituye a la
/// anterior.
class EvolucionCampana {
  /// Id del Pokémon en que evoluciona.
  final String a;
  final ViaEvolucion via;

  /// XP necesaria (con [ViaEvolucion.xp]).
  final int? xp;

  /// Id del objeto (con [ViaEvolucion.objeto]).
  final String? objeto;

  /// Puntos que cuesta (con [ViaEvolucion.intercambio] o
  /// [ViaEvolucion.puntos]).
  final int? puntos;

  const EvolucionCampana({
    required this.a,
    required this.via,
    this.xp,
    this.objeto,
    this.puntos,
  });
}

/// Un Pokémon de campaña tal como está en el catálogo.
class PokemonCampana {
  final String id;
  final String nombre;
  final TipoCampana tipo;
  final int ps;

  /// Debilidad y resistencia de la carta, si las tiene (D-20 §3.3).
  final Debilidad? debilidad;
  final Resistencia? resistencia;

  /// Energía que cuesta retirarlo, además del turno; 0 es retirada gratis.
  final int retirada;
  final List<AtaqueCampana> ataques;

  /// Carta ex: la última fase de cada Pokémon.
  final bool ex;

  /// Las formas en que puede evolucionar (vacía si no evoluciona).
  final List<EvolucionCampana> evoluciones;

  const PokemonCampana({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.ps,
    this.debilidad,
    this.resistencia,
    this.retirada = 0,
    required this.ataques,
    this.ex = false,
    this.evoluciones = const [],
  });
}

/// Un Pokémon del equipo durante un combate: la especie y su salud actual.
class PokemonEnCombate {
  final PokemonCampana especie;
  final int ps;

  const PokemonEnCombate(this.especie, this.ps);

  factory PokemonEnCombate.completo(PokemonCampana especie) =>
      PokemonEnCombate(especie, especie.ps);

  bool get enPie => ps > 0;

  PokemonEnCombate conPs(int nuevos) =>
      PokemonEnCombate(especie, nuevos < 0 ? 0 : nuevos);
}
