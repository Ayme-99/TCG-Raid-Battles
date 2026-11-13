import 'dart:math';

import 'package:incursiones_engine/incursiones_engine.dart';

/// Estado tras configurar jugadores con el daño de su mejor ataque.
EstadoPartida configurar(List<int> ataques) => apply(
      EstadoPartida.inicial(),
      ConfigurarJugadores([
        for (var i = 0; i < ataques.length; i++)
          ConfigJugador(nombre: 'J$i', ataqueMaximo: ataques[i]),
      ]),
    );

/// Partida lista para el turno de jugadores de la ronda 1.
/// Por defecto X = 300 (nivel 1) y un jefe de 1000 HP.
EstadoPartida empezar({
  List<int> ataques = const [100, 100, 100],
  int hp = 1000,
}) {
  final s = configurar(ataques);
  return apply(s, ElegirJefe(nombre: 'Jefe', nivel: s.nivel, hp: hp));
}

/// Deja [n] intentos de invocación pendientes sin pasar por el turno del jefe
/// (T-69/T-71: la llamada sale de `_llamarAliados`; los tests de aliados la
/// inyectan para probar solo cómo se resuelve el intento). Las llamadas
/// quedan agotadas: el jefe no hace ninguna más durante el test.
EstadoPartida conIntentos(EstadoPartida s, [int n = 1]) {
  final hechas = s.llamadasAliado + n;
  final tope = maxLlamadasAliado(s.nivel);
  return s.copiarCon(
    intentosInvocacionPendientes: s.intentosInvocacionPendientes + n,
    llamadasAliado: hechas > tope ? hechas : tope,
  );
}

/// Hace actuar a todos los jugadores que quedan en la ronda, sin tocar al
/// jefe más de lo que indique [dano]. Termina en el turno del jefe.
EstadoPartida todosActuan(EstadoPartida s, {int dano = 1}) {
  while (s.fase == Fase.turnoJugadores) {
    s = apply(s, TurnoJugador(jugador: s.jugadorActual!, dano: dano));
  }
  return s;
}

EstadoPartida aplicarTodos(EstadoPartida s, Iterable<Evento> eventos) {
  for (final e in eventos) {
    s = apply(s, e);
  }
  return s;
}

/// Genera una partida legal con eventos aleatorios y comprueba invariantes
/// después de cada evento.
List<Evento> partidaAleatoria(
  int semilla, {
  void Function(EstadoPartida estado, String donde)? alAplicar,
}) {
  final azar = Random(semilla);
  final eventos = <Evento>[];
  var s = EstadoPartida.inicial();

  void aplica(Evento e) {
    s = apply(s, e);
    eventos.add(e);
    alAplicar?.call(s, 'semilla $semilla, evento ${eventos.length}');
  }

  List<int> vivos() => [
        for (final j in s.jugadores)
          if (!j.eliminado) j.asiento,
      ];

  void koAlAzar() {
    final v = vivos();
    if (v.isNotEmpty) aplica(PokemonKo(v[azar.nextInt(v.length)]));
  }

  void estadoAlAzar() {
    final v = vivos();
    if (v.isEmpty) return;
    aplica(AplicarEstadoJefe(
      jugador: v[azar.nextInt(v.length)],
      estado: azar.nextBool() ? EstadoDelJefe.veneno : EstadoDelJefe.quemadura,
    ));
  }

  final n = 1 + azar.nextInt(4);
  aplica(ConfigurarJugadores([
    for (var i = 0; i < n; i++)
      ConfigJugador(nombre: 'J$i', ataqueMaximo: azar.nextInt(260)),
  ]));
  aplica(ElegirJefe(
    nombre: 'Jefe',
    nivel: s.nivel,
    hp: 100 + azar.nextInt(900),
    invocacionCadaHp: azar.nextBool() ? null : 40 + azar.nextInt(200),
  ));

  int objetivoVivo() {
    final v = vivos();
    return v[azar.nextInt(v.length)];
  }

  // Resuelve los intentos de invocación y los ataques de entrada.
  void resolverPendientes() {
    while (s.intentosInvocacionPendientes > 0) {
      final libres = s.slotsLibres;
      if (libres.isEmpty || azar.nextBool()) {
        aplica(const SinInvocacion());
      } else {
        final categorias = s.categoriasLibres;
        aplica(AliadoInvocado(
          slot: libres[azar.nextInt(libres.length)],
          categoria: categorias[azar.nextInt(categorias.length)],
          nombre: 'Aliado',
          hp: 20 + azar.nextInt(100),
          ataqueNombre: 'Placaje',
          ataqueDano: azar.nextBool() ? 10 + azar.nextInt(30) : null,
        ));
      }
    }
    for (final a in List.of(s.entradasPendientes)) {
      aplica(AtaqueAliado(
        slot: a.slot,
        dano: azar.nextInt(40),
        objetivo: s.jugadores[a.slot].eliminado ? objetivoVivo() : null,
      ));
    }
  }

  var pasos = 0;
  while (!s.terminada && pasos++ < 400) {
    resolverPendientes();
    if (s.fase == Fase.turnoJugadores) {
      for (final a in List.of(s.cartasAnimoPendientes)) {
        aplica(CartaAnimoRobada(jugador: a, carta: 1 + azar.nextInt(5)));
      }
      final j = s.jugadorActual!;
      if (s.aliados.isNotEmpty && azar.nextInt(3) == 0) {
        final objetivo = s.aliados[azar.nextInt(s.aliados.length)];
        aplica(AtaqueAAliado(
          jugador: j,
          slot: objetivo.slot,
          dano: azar.nextInt(120),
        ));
      } else {
        aplica(TurnoJugador(
          jugador: j,
          dano: azar.nextInt(120),
        ));
      }
      if (!s.terminada && azar.nextInt(5) == 0) estadoAlAzar();
      if (!s.terminada && azar.nextInt(6) == 0) koAlAzar();
    } else if (s.fase == Fase.turnoJefe) {
      if (azar.nextInt(3) == 0) aplica(CuracionJefe(azar.nextInt(300)));
      for (var k = 0; k < 1 + azar.nextInt(3); k++) {
        // El ataque contra un jugador KO falla: el jefe solo apunta a quien
        // puede recibirlo.
        final v = [for (final a in vivos()) if (!s.enKo(a)) a];
        aplica(AtaqueJefe(
          ranura: 1 + azar.nextInt(3),
          dano: azar.nextInt(250),
          jugador: v.isEmpty || azar.nextBool()
              ? null
              : v[azar.nextInt(v.length)],
        ));
      }
      for (final a in List.of(s.aliados)) {
        if (a.tieneAtaque && !a.atacoEnTurnoJefe) {
          aplica(AtaqueAliado(
            slot: a.slot,
            dano: azar.nextInt(40),
            objetivo: s.jugadores[a.slot].eliminado ? objetivoVivo() : null,
          ));
        }
      }
      while (!s.terminada && azar.nextInt(3) == 0) {
        koAlAzar();
      }
      if (!s.terminada && azar.nextInt(5) == 0) estadoAlAzar();
      if (!s.terminada) {
        // Con el jefe quemado, la app tira la moneda y la registra.
        aplica(FinTurnoJefe(
          monedaQuemadura: s.jefe!.quemado ? azar.nextBool() : null,
        ));
      }
    }
  }
  return eventos;
}
