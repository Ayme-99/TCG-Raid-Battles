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

/// Absorber (Paras, D-20 §3.6, decidido el 2026-11-26): **tras hacer su
/// daño**, el atacante se cura [valor] PS (10, fijo; no la mitad del daño),
/// sin pasar de su máximo. Cura aunque el Defensor caiga o tenga Muro Mágico
/// (es un ataque de daño directo); si el ataque no se lleva a cabo (moneda de
/// fallo con cruz), no cura. Instantáneo: no deja estado.
class CuraAlAtacar extends EfectoAtaque {
  final int valor;

  const CuraAlAtacar(this.valor);
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
/// [MonedaFalloRival] (`BandoCombate.confundido`, aparte de `cegado` para que
/// Rapidez no la ignore): en su próximo turno, si ataca,
/// lanza una moneda y con cruz ese ataque no hace nada. Si alguna sale cruz no
/// pasa nada. No se acumula (Supersónico con 1 moneda, Hidropulso con 2;
/// D-20 §3.6).
class ConfundeDefensor extends EfectoAtaque {
  final int monedas;

  const ConfundeDefensor([this.monedas = 1]);
}

/// Canto (Jigglypuff, D-20 §3.6 y §10.2, decidido el 2026-11-26): lanza
/// [monedas] monedas al usar el ataque y, si **todas** salen cara, el Pokémon
/// Defensor pasa a estar **Dormido** (`BandoCombate.dormido`): no puede atacar
/// ni retirarse (solo sale con la Cuerda Huida) y en cada chequeo Pokémon
/// lanza una moneda; con cara se despierta. No se acumula.
class DuermeDefensor extends EfectoAtaque {
  final int monedas;

  const DuermeDefensor([this.monedas = 1]);
}

/// Torbellino (Shellder) y Constricción (Ekans), D-20 §3.6 (decidido el
/// 2026-11-26): tras el daño, el Defensor queda **Apresado**
/// (`BandoCombate.apresado`): no puede retirarse (solo sale con la Cuerda
/// Huida), en cada chequeo Pokémon recibe [dano] (1 contador; Muro Mágico lo
/// bloquea pero sigue apresado) y se lanza una moneda: con cara se libera. Se
/// cura al pasar a la banca. No se acumula.
class ApresaDefensor extends EfectoAtaque {
  /// PS que quita en cada chequeo.
  static const dano = 10;

  const ApresaDefensor();
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

/// Muro Mágico (Clefairy jefe, D-20 §4 y §3.6, decidido el 2026-11-26):
/// mientras el Pokémon esté activo **solo le hacen daño los ataques**. No
/// recibe el daño indirecto: el del veneno, el de Drenadoras
/// ([DrenaDefensor], y entonces tampoco cura al que lo usó) y el de apresar
/// ([ApresaDefensor]: sigue apresado). Los estados sí se le ponen (sigue
/// Envenenado, sin perder PS). En campaña no hay golpe de la Confusión a uno mismo (Confundido es la
/// moneda de fallo), así que no hay nada que decidir sobre él.
class SinDanoIndirecto extends HabilidadCampana {
  const SinDanoIndirecto(super.nombre);
}

/// Si [especie] no recibe daño indirecto (Muro Mágico, [SinDanoIndirecto]).
bool sinDanoIndirecto(PokemonCampana especie) =>
    especie.habilidad is SinDanoIndirecto;

/// Un ataque de un Pokémon de campaña. Un ataque con [efecto] puede tener
/// [dano] 0 (solo hace el efecto).
class AtaqueCampana {
  final String nombre;
  final TipoCampana tipo;

  /// Energía que gasta.
  final int coste;
  final int dano;
  final EfectoAtaque? efecto;

  /// Rapidez (Starmie, D-20 §3.6, decidido el 2026-11-26): «Este ataque no se
  /// ve afectado por los efectos que hacen fallar a tus ataques». No lanza la
  /// moneda de [MonedaFalloRival] del rival (Bofetón Lodo y Pantalla de Humo).
  /// La de la Confusión ([ConfundeDefensor]) sí la lanza (recomendación de
  /// Dirección, por confirmar en #524). Va aparte de [efecto]: el ataque
  /// puede llevar los dos.
  final bool ignoraFallo;

  const AtaqueCampana({
    required this.nombre,
    required this.tipo,
    required this.coste,
    required this.dano,
    this.efecto,
    this.ignoraFallo = false,
  });
}

/// Cómo se consigue una evolución (D-20 §2.1).
enum ViaEvolucion {
  /// Gastando XP de la reserva común de la partida (D-20 §10.6).
  xp,

  /// Con un objeto de evolución (una piedra…). Hacerse ex es un objeto más,
  /// la piedra ex ([idPiedraEx], D-20 §2.1 y §10.11).
  objeto,

  /// Por intercambio: es gratis (decidido el 2026-11-24, D-20 §10.9).
  intercambio,
}

/// Id del objeto de evolución «piedra ex» (D-20 §2.1, decidido el
/// 2026-11-24): `"via": "objeto", "objeto": "piedra-ex"`. Convierte la última
/// fase normal en su carta ex; una piedra, un ex, sin XP.
const idPiedraEx = 'piedra-ex';

/// Medallas mínimas de cada carta ex según la fase del Pokémon que se hace
/// ex (Básico, Fase 1, Fase 2): **2 / 3 / 4**, fijadas por Ayme el 2026-11-24
/// (#447; Onix ex, a 2). Una evolución con piedra ex que no lleve
/// `medallasMinimas` en el JSON toma la de esta tabla; si la lleva, vale la
/// mayor de las dos. Para cambiarlas basta con tocar esta lista.
const medallasMinimasEx = [2, 3, 4];

/// Una evolución posible de un Pokémon. La carta evolucionada sustituye a la
/// anterior.
class EvolucionCampana {
  /// Id del Pokémon en que evoluciona.
  final String a;
  final ViaEvolucion via;

  /// XP que gasta de la reserva (con [ViaEvolucion.xp]); en el JSON,
  /// `xpEvolucion`.
  final int? xpEvolucion;

  /// Id del objeto (con [ViaEvolucion.objeto]); [idPiedraEx] para hacerse
  /// ex.
  final String? objeto;

  /// Medallas que hacen falta para que se ofrezca (D-20 §10.6 y §10.11): sin
  /// ellas no se evoluciona aunque haya XP. Null si está por decidir (no
  /// limita).
  final int? medallasMinimas;

  const EvolucionCampana({
    required this.a,
    required this.via,
    this.xpEvolucion,
    this.objeto,
    this.medallasMinimas,
  });

  /// Si es hacerse ex con la piedra ex.
  bool get esPiedraEx => via == ViaEvolucion.objeto && objeto == idPiedraEx;

  EvolucionCampana conMedallasMinimas(int? medallas) => EvolucionCampana(
      a: a,
      via: via,
      xpEvolucion: xpEvolucion,
      objeto: objeto,
      medallasMinimas: medallas);
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
