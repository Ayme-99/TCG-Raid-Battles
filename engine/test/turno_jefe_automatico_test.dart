import 'dart:math';

import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

/// T-77: el turno del jefe completo sale de una función pura con el azar
/// inyectado (D-19 §D4).
void main() {
  const ataqueSimple = AtaqueJefeDatos(nombre: 'Golpe', dano: 40);
  const datosSimples = DatosJefe(ataques: [ataqueSimple, ataqueSimple, ataqueSimple]);

  DatosJefe tresIguales(AtaqueJefeDatos a) =>
      DatosJefe(ataques: [a, a, a]);

  // Partida de 3 jugadores en el turno del jefe de la ronda 1.
  EstadoPartida enTurnoDelJefe({EstadoPartida Function(EstadoPartida)? antes}) {
    var s = empezar();
    if (antes != null) s = antes(s);
    return todosActuan(s);
  }

  List<Evento> turno(
    EstadoPartida s,
    int semilla, {
    DatosJefe datos = datosSimples,
    PreguntaMesa? mesa,
  }) {
    final azar = Random(semilla);
    final mazo = MazoAtaquesJefe(azar, jugadores: s.jugadores.length);
    return mesa == null
        ? turnoJefeAutomatico(s, mazo, azar, datos)
        : turnoJefeAutomatico(s, mazo, azar, datos, alPreguntarMesa: mesa);
  }

  const aliadoDanio = AliadoDatos(
    categoria: CategoriaAliado.danio,
    nombre: 'Aliado',
    hp: 100,
    ataqueNombre: 'Zarpazo',
    ataqueDano: 30,
  );
  const conInvocacion = DatosJefe(
    ataques: [ataqueSimple, ataqueSimple, ataqueSimple],
    invocacion: InvocacionDatos(
      segura: true,
      aliados: {CategoriaAliado.danio: aliadoDanio},
    ),
  );

  group('el turno completo', () {
    test('es determinista: la misma semilla da los mismos eventos', () {
      final s = enTurnoDelJefe();
      final a = turno(s, 7).map((e) => e.runtimeType.toString()).toList();
      final b = turno(s, 7).map((e) => e.runtimeType.toString()).toList();
      expect(a, b);
    });

    test('no modifica el estado recibido', () {
      final s = enTurnoDelJefe();
      final antes = s.toJson().toString();
      turno(s, 1);
      expect(s.toJson().toString(), antes);
    });

    test('los eventos son válidos y acaban en la ronda siguiente', () {
      final s = enTurnoDelJefe();
      final eventos = turno(s, 3);
      expect(eventos.last, isA<FinTurnoJefe>());
      final fin = aplicarTodos(s, eventos);
      expect(fin.fase, Fase.turnoJugadores);
      expect(fin.ronda, s.ronda + 1);
    });

    test('hace entre 1 y el máximo del nivel de ataques', () {
      final s = enTurnoDelJefe();
      for (var semilla = 0; semilla < 50; semilla++) {
        final n = turno(s, semilla).whereType<AtaqueJefe>().length;
        expect(n, inInclusiveRange(1, maxAtaquesJefePorTurno(s.jefe!.nivel)));
      }
    });

    test('cada ataque apunta a un jugador en juego y deja constancia del azar', () {
      final s = enTurnoDelJefe();
      for (final a in turno(s, 11).whereType<AtaqueJefe>()) {
        expect(a.jugador, isNotNull);
        expect(a.jugador, inInclusiveRange(0, s.jugadores.length - 1));
        expect(a.alAzar, isTrue);
        expect(a.dano, 40);
      }
    });

    test('con cualquier semilla los eventos se pueden reproducir', () {
      final s = enTurnoDelJefe();
      for (var semilla = 0; semilla < 100; semilla++) {
        final fin = aplicarTodos(s, turno(s, semilla));
        expect(fin.fase, Fase.turnoJugadores);
      }
    });

    test('fuera del turno del jefe lanza un error claro', () {
      final s = empezar();
      expect(() => turno(s, 1), throwsStateError);
    });

    test('si el turno ya ha empezado lanza un error claro', () {
      final s = enTurnoDelJefe();
      final primero = turno(s, 1).whereType<AtaqueJefe>().first;
      final empezado = apply(s, primero);
      expect(() => turno(empezado, 1), throwsStateError);
    });
  });

  group('efectos de los ataques', () {
    test('danoPorAtaquePrevio suma el valor por cada ataque anterior', () {
      final s = enTurnoDelJefe();
      const danza = AtaqueJefeDatos(
        nombre: 'Danza',
        dano: 20,
        efecto: EfectoAtaque(tipo: TipoEfectoAtaque.danoPorAtaquePrevio, valor: 10),
      );
      for (var semilla = 0; semilla < 20; semilla++) {
        final ataques = turno(s, semilla, datos: tresIguales(danza))
            .whereType<AtaqueJefe>()
            .toList();
        for (var i = 0; i < ataques.length; i++) {
          expect(ataques[i].dano, 20 + 10 * i);
        }
      }
    });

    test('la moneda del efecto queda dentro del evento', () {
      final s = enTurnoDelJefe();
      const paraliza = AtaqueJefeDatos(
        nombre: 'Paralizar',
        dano: 10,
        efecto: EfectoAtaque(tipo: TipoEfectoAtaque.sinAtaque),
        efectoConMoneda: true,
      );
      final ataques = turno(s, 5, datos: tresIguales(paraliza))
          .whereType<AtaqueJefe>()
          .toList();
      expect(ataques, isNotEmpty);
      for (final a in ataques) {
        expect(a.efecto!.tipo, TipoEfectoAtaque.sinAtaque);
        expect(a.efecto!.moneda, isNotNull);
      }
    });

    test('sin moneda el efecto no lleva resultado', () {
      final s = enTurnoDelJefe();
      const autodano = AtaqueJefeDatos(
        nombre: 'Retroceso',
        dano: 10,
        efecto: EfectoAtaque(tipo: TipoEfectoAtaque.autodano, valor: 10),
      );
      for (final a in turno(s, 2, datos: tresIguales(autodano))
          .whereType<AtaqueJefe>()) {
        expect(a.efecto!.moneda, isNull);
      }
    });

    test('el daño extra condicionado lo decide la mesa (por defecto, no)', () {
      final s = enTurnoDelJefe();
      const castigo = AtaqueJefeDatos(
        nombre: 'Castigo',
        dano: 30,
        efecto: EfectoAtaque(tipo: TipoEfectoAtaque.danoExtraSi, valor: 50),
      );
      final sin = turno(s, 4, datos: tresIguales(castigo)).whereType<AtaqueJefe>();
      expect(sin.every((a) => a.dano == 30), isTrue);
      final con = turno(s, 4, datos: tresIguales(castigo), mesa: (_) => true)
          .whereType<AtaqueJefe>();
      expect(con.every((a) => a.dano == 80), isTrue);
    });
  });

  group('aliados y estados', () {
    test('resuelve la llamada pendiente y el ataque de entrada', () {
      final s = conIntentos(enTurnoDelJefe());
      final eventos = turno(s, 9, datos: conInvocacion);
      final invocado = eventos.indexWhere((e) => e is AliadoInvocado);
      final entrada = eventos.indexWhere((e) => e is AtaqueAliado);
      expect(invocado, 0);
      expect(entrada, 1);
      final fin = aplicarTodos(s, eventos);
      expect(fin.intentosInvocacionPendientes, 0);
      expect(fin.aliados, hasLength(1));
    });

    test('el aliado ataca otra vez al cerrar el turno', () {
      final s = conIntentos(enTurnoDelJefe());
      final eventos = turno(s, 9, datos: conInvocacion);
      expect(eventos.whereType<AtaqueAliado>(), hasLength(2));
      expect(eventos.whereType<AtaqueAliado>().last.dano, 30);
    });

    test('una llamada no segura puede salir cruz y no invoca', () {
      const insegura = DatosJefe(
        ataques: [ataqueSimple, ataqueSimple, ataqueSimple],
        invocacion: InvocacionDatos(aliados: {CategoriaAliado.danio: aliadoDanio}),
      );
      final s = conIntentos(enTurnoDelJefe());
      final resultados = {
        for (var semilla = 0; semilla < 40; semilla++)
          turno(s, semilla, datos: insegura).first.runtimeType,
      };
      expect(resultados, containsAll([SinInvocacion, AliadoInvocado]));
    });

    test('las monedas de la quemadura del jefe van en FinTurnoJefe', () {
      final s = enTurnoDelJefe(
        antes: (s) => apply(
          s,
          AplicarEstadoJefe(jugador: 0, estado: EstadoDelJefe.quemadura),
        ),
      );
      final fin = turno(s, 6).last as FinTurnoJefe;
      expect(fin.monedaQuemadura, isNotNull);
      aplicarTodos(s, turno(s, 6));
    });

    test('sin quemadura no hay moneda', () {
      final fin = turno(enTurnoDelJefe(), 6).last as FinTurnoJefe;
      expect(fin.monedaQuemadura, isNull);
      expect(fin.monedasQuemaduraAliados, isNull);
    });
  });

  test('los ataques de datos con otro número de ranuras se rechazan', () {
    final s = enTurnoDelJefe();
    expect(
      () => turno(s, 1, datos: const DatosJefe(ataques: [ataqueSimple])),
      throwsArgumentError,
    );
  });
}
