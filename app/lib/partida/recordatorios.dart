import 'package:incursiones_engine/incursiones_engine.dart';

import '../catalogo/catalogo.dart';

/// Recordatorios para la mesa (T-70). La app lleva al jefe y a sus aliados;
/// lo que cae sobre los Pokémon de los jugadores lo resuelven ellos, y estas
/// funciones dicen qué hay que recordarles y cuándo. Son puras: solo miran el
/// estado del motor y las cartas del catálogo.

/// Carta del catálogo del aliado [a], o null si el jefe no viene del catálogo
/// o la mesa cambió el aliado a mano.
AliadoCatalogo? cartaDeAliado(
  Catalogo? catalogo,
  EstadoPartida estado,
  AliadoEstado a,
) {
  final jefe = estado.jefe;
  if (catalogo == null || jefe == null) return null;
  final carta = catalogo.aliadoDe(jefe.nombre, jefe.nivel, a.categoria);
  return carta != null && carta.nombre == a.nombre ? carta : null;
}

/// Lo que la mesa tiene que hacer al entrar el aliado [a].
List<String> recordatoriosAlEntrar(
  Catalogo? catalogo,
  EstadoPartida estado,
  AliadoEstado a,
) =>
    [
      if (cartaDeAliado(catalogo, estado, a)?.avisoAlEntrar case final t?) t,
    ];

/// Lo que la mesa tiene que hacer en el Chequeo Pokémon, al terminar el turno
/// del jefe, por los aliados que siguen en juego.
List<String> recordatoriosDeChequeo(Catalogo? catalogo, EstadoPartida estado) =>
    [
      for (final a in estado.aliados)
        if (cartaDeAliado(catalogo, estado, a)?.avisoChequeo case final t?) t,
    ];

/// Texto de un efecto de ataque del jefe que sigue activo sobre un jugador.
String textoEfectoActivo(TipoEfectoAtaque tipo) => switch (tipo) {
      TipoEfectoAtaque.sinRetirada => 'no puede retirarse',
      TipoEfectoAtaque.sinAtaque => 'no puede atacar',
      TipoEfectoAtaque.paralizarDefensor =>
        'está Paralizado: no puede atacar ni retirarse',
      _ => tipo.name,
    };

/// Texto corto del efecto permanente [f]: el aviso de turno de la carta que
/// lo dejó o, si el jefe no viene del catálogo, el texto guardado.
String textoEfectoPermanente(
  Catalogo? catalogo,
  EstadoPartida estado,
  EfectoPermanente f,
) {
  final jefe = estado.jefe;
  final aliados = catalogo == null || jefe == null
      ? null
      : catalogo.invocacionDe(jefe.nombre, jefe.nivel)?.aliados.values;
  for (final carta in aliados ?? const <AliadoCatalogo>[]) {
    if (carta.scriptId == f.scriptId && carta.avisoTurno != null) {
      return carta.avisoTurno!;
    }
  }
  return f.texto ?? '${f.origen}: su efecto sigue aplicado.';
}

/// Efectos permanentes que afectan a las monedas de los jugadores (Fijar
/// Blanco), para recordarlos cuando un jugador va a lanzar una moneda.
List<String> recordatoriosDeMoneda(Catalogo? catalogo, EstadoPartida estado) =>
    [
      for (final f in estado.efectosPermanentes)
        textoEfectoPermanente(catalogo, estado, f),
    ];

/// Lo que el jugador [jugador] tiene que tener en cuenta en su turno: lo que
/// la app descuenta de su ataque, los efectos del jefe que le siguen
/// afectando, las habilidades de los aliados en juego que limitan lo que puede
/// hacer y los efectos permanentes.
List<String> recordatoriosDeTurno(
  Catalogo? catalogo,
  EstadoPartida estado,
  int jugador,
) {
  final lineas = <String>[];
  final reduccion = reduccionParaJugador(estado, jugador);
  if (reduccion > 0) {
    lineas.add(
      'Tu ataque hace $reduccion puntos de daño menos: apunta el daño de tu '
      'carta y la app lo descuenta.',
    );
  }
  for (final f in estado.efectosActivos) {
    if (f.jugador == jugador) {
      lineas.add('Tu Pokémon Activo ${textoEfectoActivo(f.tipo)}.');
    }
  }
  for (final a in estado.aliados) {
    final t = cartaDeAliado(catalogo, estado, a)?.avisoTurno;
    if (t != null) lineas.add(t);
  }
  for (final f in estado.efectosPermanentes) {
    final t = textoEfectoPermanente(catalogo, estado, f);
    if (!lineas.contains(t)) lineas.add(t);
  }
  return lineas;
}
