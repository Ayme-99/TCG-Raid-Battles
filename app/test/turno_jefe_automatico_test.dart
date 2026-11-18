import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/catalogo/catalogo.dart';
import 'package:incursiones_app/catalogo/datos_jefe.dart';
import 'package:incursiones_app/partida/controlador_partida.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import 'ayudas.dart';

/// T-77: la app compone el turno del jefe con el motor.
JefeCatalogo _jefe(String id) => JefeCatalogo.deJson(
      jsonDecode(File('assets/catalogo/bosses/$id.json').readAsStringSync()),
    );

void main() {
  group('datos del jefe para el motor', () {
    test('Onix: tres ataques con su efecto y su invocación segura', () {
      final datos = datosDeJefe(_jefe('onix'));
      expect(datos.ataques.map((a) => a.nombre), [
        'Trampa Rocas',
        'Lanzarrocas',
        'Doble Filo',
      ]);
      expect(datos.ataques[0].efecto!.tipo, TipoEfectoAtaque.sinRetirada);
      expect(datos.ataques[1].efecto, isNull);
      expect(datos.ataques[2].efecto!.valor, 30);
      expect(datos.invocacion!.segura, isTrue);
      expect(
        datos.invocacion!.aliados[CategoriaAliado.danio]!.ataque.monedas,
        2,
      );
    });

    test('todos los jefes del catálogo se convierten', () {
      for (final id in ['onix', 'manectric', 'kingdra', 'arceus']) {
        expect(datosDeJefe(_jefe(id)).ataques, hasLength(3), reason: id);
      }
    });
  });

  group('turno del jefe automático en el controlador', () {
    ProviderContainer crear(int semilla) {
      final c = ProviderContainer(overrides: [
        ...sobrescribir(mazo: MazoAtaquesJefe(Random(semilla), jugadores: 3)),
        azarProvider.overrideWithValue(Random(semilla)),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    void ahoraTurnoDelJefe(ProviderContainer c) {
      final p = c.read(partidaProvider.notifier);
      expect(
        p.registrar(const ConfigurarJugadores([
          ConfigJugador(nombre: 'Ana', ataqueMaximo: 100),
          ConfigJugador(nombre: 'Bea', ataqueMaximo: 100),
          ConfigJugador(nombre: 'Cris', ataqueMaximo: 100),
        ])),
        isNull,
      );
      expect(
        p.registrar(const ElegirJefe(
          nombre: 'Onix',
          nivel: 1,
          hp: 2300,
          invocacionCadaHp: 1200,
        )),
        isNull,
      );
      while (c.read(estadoProvider).fase == Fase.turnoJugadores) {
        final s = c.read(estadoProvider);
        expect(
          p.registrar(TurnoJugador(jugador: s.jugadorActual!, dano: 10)),
          isNull,
        );
      }
    }

    test('registra el turno entero y pasa a la ronda siguiente', () {
      final c = crear(3);
      ahoraTurnoDelJefe(c);
      final antes = c.read(estadoProvider);
      expect(antes.fase, Fase.turnoJefe);
      final error = c
          .read(partidaProvider.notifier)
          .turnoDelJefeAutomatico(datosDeJefe(_jefe('onix')));
      expect(error, isNull);
      final despues = c.read(estadoProvider);
      expect(despues.fase, Fase.turnoJugadores);
      expect(despues.ronda, antes.ronda + 1);
      final eventos = c.read(partidaProvider).partida.eventos;
      expect(eventos.whereType<AtaqueJefe>(), isNotEmpty);
      expect(eventos.whereType<FinTurnoJefe>(), hasLength(1));
    });

    test('fuera del turno del jefe lanza el error del motor', () {
      final c = crear(1);
      expect(
        () => c
            .read(partidaProvider.notifier)
            .turnoDelJefeAutomatico(datosDeJefe(_jefe('onix'))),
        throwsStateError,
      );
    });
  });
}
