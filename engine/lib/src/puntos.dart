import 'errores.dart';
import 'estado.dart';

/// Reglas de puntos y desbloqueos (D-10, `docs/D-10-sistema-de-puntos.md`).
///
/// Los valores salen de `balance/tablas/` y son provisionales hasta T-17.

/// Puntos de una victoria por nivel (1 a 4).
const Map<int, int> topeVictoriaPorNivel = {
  1: 3000,
  2: 6000,
  3: 9000,
  4: 15000,
};

/// Puntos acumulados que necesita una cuenta para desbloquear un jefe nuevo
/// de cada nivel. Los puntos no se gastan.
const Map<int, int> costeDesbloqueoPorNivel = {
  1: 10000,
  2: 20000,
  3: 30000,
  4: 40000,
};

/// Porcentaje por puesto según el número de jugadores (puesto 1 primero).
const Map<int, List<int>> repartoPorJugadores = {
  1: [100],
  2: [55, 45],
  3: [40, 33, 27],
  4: [27, 25, 25, 23],
};

/// Coeficiente Y de un jefe: tope de victoria de su nivel ÷ vida del jefe.
double coeficienteY(int nivel, int hpJefe) {
  final tope = topeVictoriaPorNivel[nivel];
  if (tope == null) {
    throw ReglaIncumplida('el nivel $nivel no existe');
  }
  if (hpJefe <= 0) {
    throw ReglaIncumplida('el HP del jefe debe ser mayor que 0');
  }
  return tope / hpJefe;
}

/// Puntos totales del equipo en una partida.
///
/// Victoria: `daño × Y`, que con el jefe a 0 HP es el tope del nivel.
/// Derrota: `round(daño × Y ÷ 4) + 1` (perder sin hacer nada da 1 punto).
/// Se calcula con enteros para no depender de decimales.
int puntosTotales({
  required int nivel,
  required int hpJefe,
  required int danoTotal,
  required Resultado resultado,
}) {
  coeficienteY(nivel, hpJefe); // valida nivel y HP
  if (danoTotal < 0) {
    throw ReglaIncumplida('el daño total no puede ser negativo');
  }
  final tope = topeVictoriaPorNivel[nivel]!;
  if (resultado == Resultado.victoria) {
    return (2 * danoTotal * tope + hpJefe) ~/ (2 * hpJefe);
  }
  return (danoTotal * tope + 2 * hpJefe) ~/ (4 * hpJefe) + 1;
}

/// Si una cuenta con [puntosAcumulados] puede jugar un jefe de ese nivel que
/// requiere desbloqueo.
bool jefeDesbloqueado(int puntosAcumulados, int nivelJefe) {
  final coste = costeDesbloqueoPorNivel[nivelJefe];
  if (coste == null) {
    throw ReglaIncumplida('el nivel $nivelJefe no existe');
  }
  return puntosAcumulados >= coste;
}

/// Puntos de un jugador al cerrar la partida.
class PuntosJugador {
  final int asiento;
  final String nombre;
  final int dano;
  final int pokemonPerdidos;

  /// 1 = quien más daño hizo.
  final int puesto;

  /// Porcentaje del total que corresponde a ese puesto.
  final int porcentaje;

  /// Puntos que le corresponden por el reparto.
  final int puntos;

  /// Si se le abonan: los invitados ocupan puesto pero no cobran.
  final bool abonado;

  const PuntosJugador({
    required this.asiento,
    required this.nombre,
    required this.dano,
    required this.pokemonPerdidos,
    required this.puesto,
    required this.porcentaje,
    required this.puntos,
    required this.abonado,
  });

  /// Lo que se suma a la cuenta del jugador.
  int get puntosAbonados => abonado ? puntos : 0;

  Map<String, Object?> toJson() => {
        'asiento': asiento,
        'nombre': nombre,
        'dano': dano,
        'pokemonPerdidos': pokemonPerdidos,
        'puesto': puesto,
        'porcentaje': porcentaje,
        'puntos': puntos,
        'abonado': abonado,
      };
}

/// Resultado económico de una partida terminada.
class PuntosPartida {
  final int nivel;
  final Resultado resultado;
  /// Vida perdida por el jefe (neto, descontando curaciones).
  final int danoTotal;
  final double coeficienteY;
  final int puntosTotal;

  /// Por puesto (el primero es el puesto 1).
  final List<PuntosJugador> jugadores;

  PuntosPartida({
    required this.nivel,
    required this.resultado,
    required this.danoTotal,
    required this.coeficienteY,
    required this.puntosTotal,
    required List<PuntosJugador> jugadores,
  }) : jugadores = List<PuntosJugador>.unmodifiable(jugadores);

  Map<String, Object?> toJson() => {
        'nivel': nivel,
        'resultado': resultado.name,
        'danoTotal': danoTotal,
        'coeficienteY': coeficienteY,
        'puntosTotal': puntosTotal,
        'jugadores': [for (final j in jugadores) j.toJson()],
      };
}

/// Calcula los puntos de una partida terminada.
///
/// [asientosConCuenta] indica quién cobra; si es null, cobran todos. Los
/// invitados participan en el reparto pero su parte no se abona a nadie.
///
/// Los empates que D-10 deja «al azar» se resuelven aquí por orden de asiento
/// para que el cálculo sea siempre el mismo; la app puede decidir otro
/// criterio y ordenar antes.
PuntosPartida calcularPuntos(
  EstadoPartida estado, {
  Set<int>? asientosConCuenta,
}) {
  if (!estado.terminada || estado.resultado == null || estado.jefe == null) {
    throw const ReglaIncumplida(
      'los puntos solo se calculan con la partida terminada',
    );
  }
  final jefe = estado.jefe!;
  // Para el total cuenta la vida que ha perdido el jefe (neto), no el daño
  // bruto: un jefe que se cura no regala puntos (D-06).
  final danoTotal = jefe.hpMaximo - jefe.hp;
  final total = puntosTotales(
    nivel: jefe.nivel,
    hpJefe: jefe.hpMaximo,
    danoTotal: danoTotal,
    resultado: estado.resultado!,
  );
  final porcentajes = repartoPorJugadores[estado.jugadores.length]!;
  final puestos = _ordenarPuestos(estado);

  // Cada uno recibe floor(total × %) y el resto del redondeo va al puesto 1.
  final partes = [for (final p in porcentajes) total * p ~/ 100];
  partes[0] += total - partes.fold<int>(0, (a, b) => a + b);

  final jugadores = <PuntosJugador>[];
  for (var i = 0; i < puestos.length; i++) {
    final j = estado.jugadores[puestos[i]];
    jugadores.add(PuntosJugador(
      asiento: j.asiento,
      nombre: j.nombre,
      dano: estado.danoPorJugador[j.asiento],
      pokemonPerdidos: j.pokemonPerdidos,
      puesto: i + 1,
      porcentaje: porcentajes[i],
      puntos: partes[i],
      abonado: asientosConCuenta?.contains(j.asiento) ?? true,
    ));
  }
  return PuntosPartida(
    nivel: jefe.nivel,
    resultado: estado.resultado!,
    danoTotal: danoTotal,
    coeficienteY: coeficienteY(jefe.nivel, jefe.hpMaximo),
    puntosTotal: total,
    jugadores: jugadores,
  );
}

/// Asientos ordenados por puesto, de 1 al último (D-10 §3).
List<int> _ordenarPuestos(EstadoPartida e) {
  int dano(int a) => e.danoPorJugador[a];
  int perdidos(int a) => e.jugadores[a].pokemonPerdidos;

  // Más daño primero; empate: menos Pokémon perdidos; luego, por asiento.
  int porDano(int a, int b) {
    final d = dano(b).compareTo(dano(a));
    if (d != 0) return d;
    final p = perdidos(a).compareTo(perdidos(b));
    if (p != 0) return p;
    return a.compareTo(b);
  }

  final todos = [for (final j in e.jugadores) j.asiento]..sort(porDano);
  if (todos.length <= 2) return todos;

  final primero = todos.first;
  final resto = todos.sublist(1);
  // Los intermedios van primero a quien no perdió ningún Pokémon.
  final ordenado = [
    ...resto.where((a) => perdidos(a) == 0),
    ...resto.where((a) => perdidos(a) > 0),
  ];
  return [primero, ...ordenado];
}
