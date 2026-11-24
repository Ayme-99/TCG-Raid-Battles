import 'tipos.dart';

/// Efecto de un ataque (D-20 §3.6). Hoy hay once; los demás (monedas,
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

/// El propio bando suma [valor] de energía a su reserva en el momento de usar
/// el ataque, después de pagar su coste y con tope en
/// la energía máxima del combate (10). Se aplica una vez y no deja estado
/// (Pulimento). Es el efecto «propio» de [QuitaEnergiaRival].
class GanaEnergia extends EfectoAtaque {
  final int valor;

  const GanaEnergia(this.valor);
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

/// Deja al Pokémon activo del rival envenenado: en cada chequeo Pokémon (cada
/// vez que cambia el turno) pierde [valor] PS. Dura mientras siga activo: se
/// quita cuando cae o se cambia a la banca. No se acumula (Picotazo Veneno).
class EnvenenaDefensor extends EfectoAtaque {
  final int valor;

  const EnvenenaDefensor(this.valor);
}

/// Mientras este Pokémon siga activo, recibe [valor] puntos menos de daño de
/// los ataques, antes de aplicar debilidad y resistencia. No se acumula. Se
/// acaba cuando cae o se cambia a la banca (Fortaleza). Es el efecto «propio»
/// de [ReduceDanoRival].
class ReduceDanoPropio extends EfectoAtaque {
  final int valor;

  const ReduceDanoPropio(this.valor);
}

/// En su próximo turno, si el Pokémon activo del rival ataca, lanza una moneda:
/// con cruz ese ataque no hace nada (la energía se gasta igual). Solo afecta a
/// ese turno, pase lo que pase en él (Bofetón Lodo).
class MonedaFalloRival extends EfectoAtaque {
  /// Si es true, no dura un turno sino **mientras el Defensor siga activo**:
  /// cada vez que ataque lanza la moneda; se quita al cambiarlo o cuando cae
  /// (Pantalla de Humo de Charmeleon, D-20 §3.6, decidido el 2026-11-23).
  final bool mientrasActivo;

  const MonedaFalloRival({this.mientrasActivo = false});
}

/// Drenadoras (Ivysaur, D-20 §3.6): el Defensor queda envenenado con 10 PS por
/// chequeo mientras siga activo, sin acumular, como [EnvenenaDefensor]; y cada
/// chequeo en que pierde PS por ello cura [cura] PS al Pokémon activo del
/// bando que lo usó en ese momento (no tiene por qué ser el mismo), hasta su
/// máximo.
class DrenaDefensor extends EfectoAtaque {
  /// PS que quita en cada chequeo.
  static const dano = 10;

  /// PS que cura al activo del que lo usó.
  static const cura = 10;

  const DrenaDefensor();
}

/// Dragoaliento (Charmeleon, D-20 §3.6, decidido el 2026-11-23): tras el daño
/// lanza [monedas] monedas y, con al menos [minimoCaras] caras, el Defensor
/// queda **Paralizado**: en su próximo turno no puede atacar ni cambiar de
/// Pokémon (solo cargar). Se quita al acabar ese turno y no se acumula.
class ParalizaDefensor extends EfectoAtaque {
  final int monedas;
  final int minimoCaras;

  const ParalizaDefensor(this.monedas, this.minimoCaras);
}

/// Lanza [monedas] monedas al usar el ataque: si **todas** salen cara, el
/// Pokémon Defensor queda Confundido, que en campaña es el mismo estado que
/// [MonedaFalloRival] (`BandoCombate.cegado`): en su próximo turno, si ataca,
/// lanza una moneda y con cruz ese ataque no hace nada. Si alguna sale cruz no
/// pasa nada. No se acumula (Supersónico con 1 moneda, Hidropulso con 2;
/// D-20 §3.6).
class ConfundeDefensor extends EfectoAtaque {
  final int monedas;

  const ConfundeDefensor([this.monedas = 1]);
}

/// El daño del ataque se multiplica por las veces **seguidas** que este
/// Pokémon lo ha usado, contando la actual: [AtaqueCampana.dano] la primera
/// vez, el doble la segunda, el triple la tercera… Se reinicia si el Pokémon usa
/// otro ataque, carga, se cambia o cae (Rodar).
class DanoPorRacha extends EfectoAtaque {
  const DanoPorRacha();
}

/// Lanza [monedas] monedas y el ataque hace el daño que toca según las caras
/// que salgan: [danoPorCaras] tiene [monedas] + 1 valores, y el de la posición
/// n es el daño con n caras (Ataque Furia). [AtaqueCampana.dano] no es el daño
/// real, sino el **daño esperado** que usa la IA y el baremo.
class MonedasDano extends EfectoAtaque {
  final int monedas;
  final List<int> danoPorCaras;

  const MonedasDano(this.monedas, this.danoPorCaras);
}

/// Si el ataque deja fuera de combate al Pokémon activo del rival, el nuevo
/// activo recibe de nuevo ese mismo ataque (con su propia debilidad y
/// resistencia) en cuanto sale. Solo se repite una vez (Doble Patada).
class RepiteDanoAlDerribar extends EfectoAtaque {
  const RepiteDanoAlDerribar();
}

/// Habilidad pasiva de una carta (D-20 §3.6). Hoy hay una.
sealed class HabilidadCampana {
  final String nombre;

  const HabilidadCampana(this.nombre);
}

/// Mientras el Pokémon siga activo, cada vez que ataca lanza una moneda: con
/// cara, ese ataque hace [valor] puntos más de daño, antes de reducciones,
/// debilidad y resistencia (Foco Energía). Es una moneda aparte de las que
/// pueda lanzar el propio ataque.
class MonedaDanoExtraAlAtacar extends HabilidadCampana {
  final int valor;

  const MonedaDanoExtraAlAtacar(super.nombre, this.valor);
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
  /// Gastando XP de la reserva común de la partida (D-20 §10.6).
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

  /// XP que gasta de la reserva (con [ViaEvolucion.xp]); en el JSON,
  /// `xpEvolucion`.
  final int? xpEvolucion;

  /// Id del objeto (con [ViaEvolucion.objeto]).
  final String? objeto;

  /// Puntos que cuesta (con [ViaEvolucion.intercambio] o
  /// [ViaEvolucion.puntos]).
  final int? puntos;

  /// Medallas que hacen falta para que se ofrezca (D-20 §10.6 y §10.11): sin
  /// ellas no se evoluciona aunque haya XP. Null si está por decidir (no
  /// limita).
  final int? medallasMinimas;

  const EvolucionCampana({
    required this.a,
    required this.via,
    this.xpEvolucion,
    this.objeto,
    this.puntos,
    this.medallasMinimas,
  });
}

/// Categoría de captura de un Pokémon (D-20 §10.6). Fija la probabilidad de
/// capturarlo (#368) y la XP que da derrotarlo: Común 10, Intermedio 20, Fuerte
/// y Jefe 30. En el JSON, `categoriaCaptura`.
enum CategoriaCaptura { comun, intermedio, fuerte, jefe }

/// XP que suma a la reserva derrotar a un Pokémon de [categoria] (D-20 §10.6,
/// decidido el 2026-11-22).
int xpDeCategoria(CategoriaCaptura categoria) => switch (categoria) {
      CategoriaCaptura.comun => 10,
      CategoriaCaptura.intermedio => 20,
      CategoriaCaptura.fuerte => 30,
      CategoriaCaptura.jefe => 30,
    };

/// Probabilidad de capturar, en tanto por mil, a un Pokémon de [categoria]
/// con una Ball de [nivelBall] (0 Pokéball, 1 Super Ball, 2 Ultra Ball). D-20
/// §10.6, decidido el 2026-11-22: Común 75/100/100 %, Intermedio 50/75/100 %,
/// Fuerte 25/50/75 % y Jefe 12,5/25/50 %.
int probabilidadCaptura(CategoriaCaptura categoria, int nivelBall) {
  const tabla = {
    CategoriaCaptura.comun: [750, 1000, 1000],
    CategoriaCaptura.intermedio: [500, 750, 1000],
    CategoriaCaptura.fuerte: [250, 500, 750],
    CategoriaCaptura.jefe: [125, 250, 500],
  };
  return tabla[categoria]![nivelBall];
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

  /// Habilidad pasiva, si la tiene.
  final HabilidadCampana? habilidad;

  /// Carta ex: la última fase de cada Pokémon.
  final bool ex;

  /// Las formas en que puede evolucionar (vacía si no evoluciona).
  final List<EvolucionCampana> evoluciones;

  /// Categoría de captura, o null si no aplica (los iniciales).
  final CategoriaCaptura? categoriaCaptura;

  const PokemonCampana({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.ps,
    this.debilidad,
    this.resistencia,
    this.retirada = 0,
    required this.ataques,
    this.habilidad,
    this.ex = false,
    this.evoluciones = const [],
    this.categoriaCaptura,
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
