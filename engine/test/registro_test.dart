import 'dart:convert';
import 'dart:io';

import 'package:incursiones_engine/incursiones_engine.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

/// Carpeta con los ejemplos del contrato (`dart test` se ejecuta en engine/).
Directory _carpeta(String nombre) =>
    Directory('../contrato/ejemplos/$nombre');

List<(String, Object?)> _ejemplos(String nombre) => [
      for (final f in _carpeta(nombre).listSync().whereType<File>())
        if (f.path.endsWith('.json'))
          (
            f.uri.pathSegments.last,
            jsonDecode(f.readAsStringSync()),
          ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

void main() {
  /// Lo que debe salir de leer un registro de la versión 1: el mismo registro
  /// en versión 2, con el bono de estados a 0 en cada jugador del resumen.
  Object? migradoDeV1(Object? json) {
    final m = Map<String, Object?>.from(json as Map);
    m['version'] = 2;
    final r = m['resumen'];
    if (r is Map) {
      final resumen = Map<String, Object?>.from(r);
      resumen['jugadores'] = [
        for (final j in resumen['jugadores'] as List)
          {
            ...Map<String, Object?>.from(j as Map),
            'estadosAplicados': 0,
            'bonoEstados': 0,
          },
      ];
      m['resumen'] = resumen;
    }
    return m;
  }

  void resumenEsElDelMotor(Object? json) {
    final registro = RegistroPartida.deJson(json);
    if (!registro.estado.terminada) {
      expect(registro.resumen, isNull);
      return;
    }
    final nuevo = RegistroPartida.crear(
      partidaId: registro.partidaId,
      eventos: registro.eventos,
      cuentas: registro.cuentas,
    );
    expect(registro.resumen, equals(nuevo.resumen));
  }

  group('ejemplos del contrato v1 (se migran a la versión 2)', () {
    test('hay ejemplos de cada tipo', () {
      expect(_ejemplos('v1/validos'), isNotEmpty);
      expect(_ejemplos('v1/invalidos-estructura'), isNotEmpty);
      expect(_ejemplos('v1/invalidos-reglas'), isNotEmpty);
    });

    for (final (nombre, json) in _ejemplos('v1/validos')) {
      test('válido: $nombre se lee, se migra y se escribe en versión 2', () {
        final registro = RegistroPartida.deJson(json);
        expect(registro.version, 2);
        expect(registro.toJson(), equals(migradoDeV1(json)));
      });

      test('válido: $nombre guarda el resumen que calcularía el motor', () {
        resumenEsElDelMotor(json);
      });
    }

    for (final (nombre, json) in _ejemplos('v1/invalidos-estructura')) {
      test('inválido de estructura: $nombre', () {
        expect(() => RegistroPartida.deJson(json),
            throwsA(isA<RegistroInvalido>()));
      });
    }

    for (final (nombre, json) in _ejemplos('v1/invalidos-reglas')) {
      test('reglas incumplidas: $nombre', () {
        expect(() => RegistroPartida.deJson(json),
            throwsA(isA<RegistroInvalido>()));
      });
    }
  });

  group('ejemplos del contrato v2', () {
    test('hay ejemplos de cada tipo', () {
      expect(_ejemplos('v2/validos'), isNotEmpty);
      expect(_ejemplos('v2/invalidos-estructura'), isNotEmpty);
      expect(_ejemplos('v2/invalidos-reglas'), isNotEmpty);
    });

    for (final (nombre, json) in _ejemplos('v2/validos')) {
      test('válido: $nombre se lee y se vuelve a escribir igual', () {
        expect(RegistroPartida.deJson(json).toJson(), equals(json));
      });

      test('válido: $nombre guarda el resumen que calcularía el motor', () {
        resumenEsElDelMotor(json);
      });
    }

    for (final (nombre, json) in _ejemplos('v2/invalidos-estructura')) {
      test('inválido de estructura: $nombre', () {
        expect(() => RegistroPartida.deJson(json),
            throwsA(isA<RegistroInvalido>()));
      });
    }

    for (final (nombre, json) in _ejemplos('v2/invalidos-reglas')) {
      test('reglas incumplidas: $nombre', () {
        expect(() => RegistroPartida.deJson(json),
            throwsA(isA<RegistroInvalido>()));
      });
    }
  });

  group('mensajes de error', () {
    String mensaje(Object? json) {
      try {
        RegistroPartida.deJson(json);
      } on RegistroInvalido catch (e) {
        return e.mensaje;
      }
      return '';
    }

    Map<String, Object?> ejemplo(String nombre) =>
        Map<String, Object?>.from(_ejemplos('v1/validos')
            .firstWhere((e) => e.$1 == nombre)
            .$2 as Map);

    test('versión futura pide actualizar la app', () {
      final m = mensaje({
        'version': 99,
        'partidaId': 'x',
        'eventos': [
          {'tipo': 'finTurnoJefe'}
        ],
      });
      expect(m, contains('versión 99'));
      expect(m, contains('Actualiza'));
    });

    test('indica el evento y el campo que fallan', () {
      final m = mensaje(_ejemplos('v1/invalidos-estructura')
          .firstWhere((e) => e.$1 == 'dano-no-es-entero.json')
          .$2);
      expect(m, contains('eventos[2]'));
      expect(m, contains('dano'));
    });

    test('indica el evento que rompe las reglas', () {
      final m = mensaje(_ejemplos('v1/invalidos-reglas')
          .firstWhere((e) => e.$1 == 'turno-fuera-de-orden.json')
          .$2);
      expect(m, startsWith('eventos[2]:'));
    });

    test('campo desconocido', () {
      final m = mensaje(_ejemplos('v1/invalidos-estructura')
          .firstWhere((e) => e.$1 == 'campo-desconocido.json')
          .$2);
      expect(m, contains('critico'));
    });

    test('no es un objeto, versión que falta o fecha mala', () {
      expect(mensaje([]), contains('objeto'));
      expect(mensaje({'partidaId': 'x'}), contains('version'));
      final malaFecha = ejemplo('victoria-2-jugadores.json')
        ..['creadaEn'] = 'ayer';
      expect(mensaje(malaFecha), contains('creadaEn'));
    });

    test('cuentas con valores no válidos', () {
      final j = ejemplo('victoria-2-jugadores.json')..['cuentas'] = ['a', 5];
      expect(mensaje(j), contains('cuentas[1]'));
    });

    test('lista de eventos vacía', () {
      final j = ejemplo('victoria-2-jugadores.json')..['eventos'] = [];
      expect(mensaje(j), isNotEmpty);
    });
  });

  group('eventos uno a uno', () {
    final todos = <Evento>[
      const ConfigurarJugadores([
        ConfigJugador(nombre: 'Ana', ataqueMaximo: 120),
        ConfigJugador(nombre: 'Bea', ataqueMaximo: 90),
      ]),
      const ElegirJefe(nombre: 'J', nivel: 1, hp: 500),
      const ElegirJefe(
        nombre: 'J',
        nivel: 2,
        hp: 600,
        invocacionCadaHp: 150,
        jefeId: 'jefe-1',
      ),
      const TurnoJugador(jugador: 1, dano: 40),
      const AtaqueJefe(ranura: 3, dano: 90),
      const AtaqueJefe(ranura: 1, dano: 30, jugador: 2, alAzar: true),
      const PokemonKo(3),
      const CartaAnimoRobada(jugador: 0, carta: 5),
      const FinTurnoJefe(),
      const Abandonar(),
      const CuracionJefe(70),
      const AtaqueAAliado(jugador: 0, slot: 2, dano: 15),
      const SinInvocacion(),
      const AliadoInvocado(slot: 1, nombre: 'Wobbuffet', hp: 110),
      const AliadoInvocado(
        slot: 0,
        nombre: 'Rattata',
        hp: 60,
        ataqueNombre: 'Placaje',
        ataqueDano: 20,
        habilidad: 'Ágil',
      ),
      const AtaqueAliado(slot: 1, dano: 20),
      const AtaqueAliado(slot: 1, dano: 20, objetivo: 2),
    ];

    test('el motor tiene un tipo JSON para cada evento', () {
      final tipos = {for (final e in todos) eventoAJson(e)['tipo']};
      expect(tipos.length, 13);
    });

    for (final e in todos) {
      test('ida y vuelta de ${eventoAJson(e)}', () {
        final json = eventoAJson(e);
        final lectura = eventoDeJson(jsonDecode(jsonEncode(json)));
        expect(eventoAJson(lectura), equals(json));
      });
    }

    test('los opcionales ausentes no se escriben', () {
      expect(eventoAJson(const AtaqueJefe(ranura: 1, dano: 5)),
          {'tipo': 'ataqueJefe', 'ranura': 1, 'dano': 5});
      expect(eventoAJson(const AtaqueAliado(slot: 0, dano: 1)),
          {'tipo': 'ataqueAliado', 'slot': 0, 'dano': 1});
    });

    test('rechaza tipos incorrectos y valores fuera de rango', () {
      for (final malo in <Object?>[
        {'tipo': 'turnoJugador', 'jugador': 4, 'dano': 1},
        {'tipo': 'turnoJugador', 'jugador': 0, 'dano': -1},
        {'tipo': 'turnoJugador', 'jugador': 0, 'dano': 1.5},
        {'tipo': 'ataqueJefe', 'ranura': 4, 'dano': 1},
        {'tipo': 'ataqueJefe', 'ranura': 1, 'dano': 1, 'alAzar': 'si'},
        {'tipo': 'cartaAnimoRobada', 'jugador': 0, 'carta': 6},
        {'tipo': 'elegirJefe', 'nombre': 'J', 'nivel': 5, 'hp': 10},
        {'tipo': 'elegirJefe', 'nombre': '', 'nivel': 1, 'hp': 10},
        {'tipo': 'aliadoInvocado', 'slot': 0, 'nombre': 'A', 'hp': 0},
        {'tipo': 'configurarJugadores', 'jugadores': []},
        {'tipo': 'finTurnoJefe', 'extra': 1},
        {'dano': 1},
        'turnoJugador',
      ]) {
        expect(() => eventoDeJson(malo), throwsA(isA<RegistroInvalido>()),
            reason: '$malo');
      }
    });
  });

  group('crear un registro', () {
    test('en curso: sin resumen', () {
      final r = RegistroPartida.crear(
        partidaId: 'p1',
        eventos: [
          const ConfigurarJugadores([
            ConfigJugador(nombre: 'Ana', ataqueMaximo: 100),
          ]),
          const ElegirJefe(nombre: 'J', nivel: 1, hp: 500),
        ],
      );
      expect(r.resumen, isNull);
      expect(r.version, versionRegistro);
      expect(r.estado.fase, Fase.turnoJugadores);
      expect(r.partida.eventos.length, 2);
    });

    test('terminada: incluye el resumen y respeta invitados', () {
      final r = RegistroPartida.crear(
        partidaId: 'p2',
        cuentas: const ['usuario-ana', null],
        eventos: [
          const ConfigurarJugadores([
            ConfigJugador(nombre: 'Ana', ataqueMaximo: 100),
            ConfigJugador(nombre: 'Bea', ataqueMaximo: 100),
          ]),
          const ElegirJefe(nombre: 'J', jefeId: 'j-1', nivel: 1, hp: 300),
          const TurnoJugador(jugador: 0, dano: 200),
          const TurnoJugador(jugador: 1, dano: 100),
        ],
      );
      final resumen = r.resumen!;
      expect(resumen['jefeId'], 'j-1');
      expect(resumen['resultado'], 'victoria');
      expect(resumen['puntosTotal'], 3000);
      final js = resumen['jugadores'] as List;
      expect((js[0] as Map)['abonado'], isTrue);
      expect((js[1] as Map)['abonado'], isFalse);
    });

    test('rechaza un id vacío o eventos que rompen las reglas', () {
      expect(
        () => RegistroPartida.crear(partidaId: '', eventos: const [FinTurnoJefe()]),
        throwsA(isA<RegistroInvalido>()),
      );
      expect(
        () => RegistroPartida.crear(
          partidaId: 'x',
          eventos: const [TurnoJugador(jugador: 0, dano: 1)],
        ),
        throwsA(isA<RegistroInvalido>()),
      );
    });

    test('las listas del registro no se pueden modificar', () {
      final r = RegistroPartida.crear(
        partidaId: 'p3',
        eventos: const [
          ConfigurarJugadores([
            ConfigJugador(nombre: 'Ana', ataqueMaximo: 100),
          ]),
        ],
      );
      expect(() => r.eventos.add(const Abandonar()), throwsUnsupportedError);
    });
  });

  group('partidas aleatorias', () {
    test('se escriben, se leen y dan el mismo estado', () {
      for (var semilla = 0; semilla < 60; semilla++) {
        final eventos = partidaAleatoria(semilla);
        final r = RegistroPartida.crear(
          partidaId: 'semilla-$semilla',
          eventos: eventos,
        );
        // Pasa por texto JSON de verdad, como al guardarse y enviarse.
        final texto = jsonEncode(r.toJson());
        final leido = RegistroPartida.deJson(jsonDecode(texto));
        expect(leido.toJson(), equals(r.toJson()), reason: 'semilla $semilla');
        expect(leido.estado.toJson(), equals(r.estado.toJson()),
            reason: 'semilla $semilla');
      }
    });
  });
}
