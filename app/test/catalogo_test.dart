import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/catalogo/catalogo.dart';
import 'package:incursiones_app/partida/controlador_partida.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import 'ayudas.dart';

/// `flutter test` se ejecuta en app/, así que el catálogo original queda en
/// ../catalog.
Object? _json(String ruta) => jsonDecode(File(ruta).readAsStringSync());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('catálogo empaquetado', () {
    test('la copia de app/assets es la misma que catalog/', () {
      expect(_json('assets/catalogo/catalogo.json'),
          equals(_json('../catalog/catalogo.json')));
      final originales = Directory('../catalog/bosses')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.json'))
          .toList()
        ..sort();
      final copias = Directory('assets/catalogo/bosses')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.json'))
          .toList()
        ..sort();
      expect(copias, equals(originales),
          reason: 'ejecuta app/tool/sync_catalogo.sh');
      for (final nombre in originales) {
        expect(_json('assets/catalogo/bosses/$nombre'),
            equals(_json('../catalog/bosses/$nombre')),
            reason: '$nombre: ejecuta app/tool/sync_catalogo.sh');
      }
    });

    test('se carga desde los assets y trae los 4 jefes iniciales', () async {
      final c = await Catalogo.cargar(rootBundle);
      expect(c.jefes.map((j) => j.id), ['onix', 'manectric', 'kingdra', 'arceus']);
      expect(c.jefes.map((j) => j.nivel), [1, 2, 3, 4]);
      expect(c.jefes.map((j) => j.hp), [1800, 2200, 3000, 4600]);
      expect(c.jefes.map((j) => j.intentosDeInvocacion), [1, 2, 3, 4]);
      for (final j in c.jefes) {
        expect(j.ataques, hasLength(3));
        expect(j.invocacion!.segura, isTrue);
        expect(j.invocacion!.aliados.keys, CategoriaAliado.values);
      }
      expect(c.delNivel(3).single.nombre, 'Kingdra');
      expect(c.delNivel(2).single.invocacion!.aliados[CategoriaAliado.picaro]!.nombre,
          'Plusle');
    });

    test('los ataques traen los efectos de D-14', () async {
      final c = await Catalogo.cargar(rootBundle);
      final onix = c.jefes[0].ataques;
      expect(onix.map((a) => a.nombre), ['Trampa Rocas', 'Lanzarrocas', 'Doble filo']);
      expect(onix[0].efecto!.tipo, TipoEfectoAtaque.sinRetirada);
      expect(onix[0].efecto!.duracion, 1);
      expect(onix[0].efecto!.necesitaDefensor, isTrue);
      expect(onix[1].efecto, isNull);
      expect(onix[2].efecto!.tipo, TipoEfectoAtaque.autodano);
      expect(onix[2].efecto!.valor, 30);

      final onda = c.jefes[1].ataques[0].efecto!;
      expect(onda.tipo, TipoEfectoAtaque.paralizarDefensor);
      expect(onda.conMoneda, isTrue);
      expect(onda.comoEfecto(moneda: true).moneda, isTrue);
      expect(c.jefes[0].ataques[2].efecto!.comoEfecto(moneda: true).moneda, isNull);

      final arceus = c.jefes[3].ataques;
      expect(arceus[0].danoPropuesto(0), 40);
      expect(arceus[0].danoPropuesto(2), 100);
      expect(arceus[1].danoPropuesto(2), 100);
      expect(arceus[2].efecto!.tipo, TipoEfectoAtaque.contadorATodos);
    });

    test('un efecto de ataque desconocido se rechaza', () {
      final jefe = Map<String, Object?>.from(
          _json('../catalog/bosses/onix.json') as Map);
      final ataques = [
        for (final a in jefe['ataques'] as List) Map<String, Object?>.from(a as Map),
      ];
      ataques[0]['efecto'] = {'tipo': 'bailar', 'texto': 'x'};
      jefe['ataques'] = ataques;
      expect(() => JefeCatalogo.deJson(jefe), throwsFormatException);
    });

    test('un jefe sin la categoría de un aliado se rechaza', () {
      final jefe = Map<String, Object?>.from(
          _json('../catalog/bosses/onix.json') as Map);
      final inv = Map<String, Object?>.from(jefe['invocacion'] as Map);
      final aliados = Map<String, Object?>.from(inv['aliados'] as Map)
        ..remove('cura');
      inv['aliados'] = aliados;
      jefe['invocacion'] = inv;
      expect(() => JefeCatalogo.deJson(jefe), throwsFormatException);
    });
  });

  testWidgets('el setup ofrece los jefes del nivel y se elige uno del catálogo',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // La lectura de assets es E/S real: dentro de un test de widgets hay que
    // hacerla fuera del reloj falso y pasársela al provider ya leída.
    final catalogo =
        (await tester.runAsync(() => Catalogo.cargar(rootBundle)))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...sobrescribir(),
          catalogoProvider.overrideWith((ref) async => catalogo),
        ],
        child: const IncursionesApp(),
      ),
    );
    await tester.pumpAndSettle();
    final c =
        ProviderScope.containerOf(tester.element(find.byType(IncursionesApp)));

    for (final (clave, texto) in [('ataque-0', '100'), ('ataque-1', '100')]) {
      await tester.enterText(
        find.descendant(
          of: find.byKey(Key(clave)),
          matching: find.byType(TextField),
        ),
        texto,
      );
    }
    await tester.tap(find.byKey(const Key('configurar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catalogo-onix')), findsOneWidget);
    expect(find.byKey(const Key('catalogo-manectric')), findsNothing);
    expect(find.textContaining('invoca 1 aliado (seguro)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalogo-onix')));
    await tester.pumpAndSettle();

    final estado = c.read(estadoProvider);
    expect(estado.fase, Fase.turnoJugadores);
    expect(estado.jefe!.nombre, 'Onix');
    expect(estado.jefe!.hp, 1800);
    expect(estado.jefe!.invocacionCadaHp, 900);

    // Turno del jefe: la pantalla propone el ataque de la carta y su efecto.
    final partida = c.read(partidaProvider.notifier);
    for (final j in estado.orden) {
      expect(partida.registrar(TurnoJugador(jugador: j, dano: 1)), isNull);
    }
    await tester.pumpAndSettle();
    expect(find.text('Trampa Rocas · 30'), findsOneWidget);
    expect(find.byKey(const Key('efecto-ataque')), findsOneWidget);
    expect(find.byKey(const Key('falta-defensor')), findsOneWidget);

    await tester.tap(find.byKey(const Key('objetivo-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('falta-defensor')), findsNothing);
    await tester.tap(find.byKey(const Key('registrar-ataque-jefe')));
    await tester.pumpAndSettle();

    final conEfecto = c.read(estadoProvider);
    expect(conEfecto.efectosActivos.single.tipo, TipoEfectoAtaque.sinRetirada);
    expect(conEfecto.efectosActivos.single.jugador, 0);
    expect(find.byKey(const Key('efectos-activos')), findsOneWidget);
  });
}
