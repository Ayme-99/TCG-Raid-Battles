import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
      expect(c.jefes.map((j) => j.hp), [2300, 2600, 3700, 3800]);
      expect(c.jefes.map((j) => j.intentosDeInvocacion), [1, 2, 3, 4]);
      for (final j in c.jefes) {
        expect(j.ataques, hasLength(3));
        expect(j.invocacion!.segura, isTrue);
        // Los 4 jefes tienen ya los 6 roles de D-16.
        expect(j.invocacion!.aliados.keys, CategoriaAliado.values);
      }
      expect(c.jefes[0].mapa, 'Túnel Roca');
      expect(c.jefes[3].mapa, 'Sala Origen');
      final medicham = c.aliadoDe('Arceus', 4, CategoriaAliado.danio)!;
      expect(medicham.ataqueDanoExtraSiEstado, 70);
      expect(medicham.habilidadNombre, 'Energía Pura');
      expect(
        c.aliadoDe('Arceus', 4, CategoriaAliado.tanque)!.scriptId,
        'bloqueo-100',
      );
      expect(
        c.aliadoDe('Arceus', 4, CategoriaAliado.cura)!.scriptId,
        'deseo-100',
      );
      expect(
        c.aliadoDe('Arceus', 4, CategoriaAliado.control)!.habilidadNombre,
        'Fijar Blanco',
      );
      final solrock = c.aliadoDe('Arceus', 4, CategoriaAliado.potenciador)!;
      expect(solrock.ataqueEscalaPorUso, 10);
      expect(solrock.scriptId, 'envite-igneo-10');
      final lunatone = c.aliadoDe('Arceus', 4, CategoriaAliado.debilitador)!;
      expect(lunatone.ataqueMonedaRival, isTrue);
      expect(lunatone.scriptId, 'fuerza-lunar-30');
      final machop = c.aliadoDe('Onix', 1, CategoriaAliado.danio)!;
      expect(machop.nombre, 'Machop');
      expect(machop.ataqueMonedas, 2);
      expect(machop.ataqueDano, 20);
      final cubone = c.aliadoDe('Onix', 1, CategoriaAliado.potenciador)!;
      expect(cubone.scriptId, 'foco-energia-10');
      expect(cubone.textoParaLaMesa, contains('Foco Energía'));
      expect(c.delNivel(3).single.nombre, 'Kingdra');
      expect(c.delNivel(3).single.mapa, 'Islas Remolino');
      final krabby = c.aliadoDe('Kingdra', 3, CategoriaAliado.danio)!;
      expect(krabby.ataqueBonusMonedas, 2);
      expect(krabby.ataqueBonusCaras, 1);
      expect(krabby.ataqueBonusDano, 50);
      expect(
        c.aliadoDe('Kingdra', 3, CategoriaAliado.debilitador)!.evitaDanoConMoneda,
        isTrue,
      );
      expect(
        c.aliadoDe('Kingdra', 3, CategoriaAliado.tanque)!.scriptId,
        'velo-sagrado',
      );
      expect(c.delNivel(2).single.invocacion!.aliados[CategoriaAliado.control]!.nombre,
          'Gulpin');
      final plusle = c.aliadoDe('Manectric', 2, CategoriaAliado.danio)!;
      expect(plusle.ataqueDanoAdyacentes, 30);
      final minun = c.aliadoDe('Manectric', 2, CategoriaAliado.tanque)!;
      expect(minun.avisoAlCaer, contains('Paralizado'));
      expect(
        c.aliadoDe('Manectric', 2, CategoriaAliado.cura)!.scriptId,
        'drenadoras-10',
      );
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
    expect(estado.jefe!.hp, 2300);
    expect(estado.jefe!.invocacionCadaHp, 1150);

    // Turno del jefe: la pantalla propone el ataque de la carta y su efecto.
    final partida = c.read(partidaProvider.notifier);
    for (final j in estado.orden) {
      expect(partida.registrar(TurnoJugador(jugador: j, dano: 1)), isNull);
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('robar-carta-jefe')));
    await tester.pumpAndSettle();
    expect(find.text('Trampa Rocas · 30'), findsOneWidget);
    expect(find.byKey(const Key('efecto-ataque')), findsOneWidget);
    // La carta robada ya dice el ataque y el objetivo (Jugador 1).
    expect(find.byKey(const Key('carta-ataque-jefe')), findsOneWidget);
    expect(find.text('JUGADOR 1'), findsOneWidget);
    expect(find.byKey(const Key('falta-defensor')), findsNothing);
    await tester.tap(find.byKey(const Key('registrar-ataque-jefe')));
    await tester.pumpAndSettle();

    final conEfecto = c.read(estadoProvider);
    expect(conEfecto.efectosActivos.single.tipo, TipoEfectoAtaque.sinRetirada);
    expect(conEfecto.efectosActivos.single.jugador, 0);
    expect(find.byKey(const Key('efectos-activos')), findsOneWidget);
  });

  testWidgets('invocar un aliado del catálogo rellena su carta y lo muestra',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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
    await tester.tap(find.byKey(const Key('catalogo-onix')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aliado-0')), findsNothing);
    expect(find.byKey(const Key('slot-libre-0')), findsOneWidget);

    // 1150 de daño cruza el primer (y único) umbral de invocación de Onix.
    expect(
      c.read(partidaProvider.notifier).registrar(
            const TurnoJugador(jugador: 0, dano: 1150),
          ),
      isNull,
    );
    await tester.pumpAndSettle();
    expect(c.read(estadoProvider).intentosInvocacionPendientes, 1);

    await tester.tap(find.byKey(const Key('invocar-aliado')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aliado-del-catalogo')), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Machop'), findsOneWidget);

    await tester.tap(find.byKey(const Key('aliado-categoria-tanque')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Geodude'), findsOneWidget);
    await tester.tap(find.byKey(const Key('aliado-aceptar')));
    await tester.pumpAndSettle();

    final aliado = c.read(estadoProvider).aliados.single;
    expect(aliado.nombre, 'Geodude');
    expect(aliado.categoria, CategoriaAliado.tanque);
    expect(aliado.hp, 90);
    expect(aliado.habilidad, isNotNull);
    expect(find.byKey(const Key('aliado-0')), findsOneWidget);
    expect(find.byKey(const Key('slot-libre-0')), findsNothing);
    expect(find.textContaining('Geodude'), findsOneWidget);
  });

  testWidgets('tirar dados elige slot y categoría libres y rellena el aliado',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final catalogo =
        (await tester.runAsync(() => Catalogo.cargar(rootBundle)))!;
    // Dado de slot → segundo slot libre; dado de categoría → tercera libre.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...sobrescribir(),
          catalogoProvider.overrideWith((ref) async => catalogo),
          azarProvider.overrideWithValue(_AzarFijo([1, 2])),
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
    await tester.tap(find.byKey(const Key('catalogo-onix')));
    await tester.pumpAndSettle();
    expect(
      c.read(partidaProvider.notifier).registrar(
            const TurnoJugador(jugador: 0, dano: 1150),
          ),
      isNull,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('invocar-aliado')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tirar-dados')));
    // T-44: el diálogo se cierra y los dados ruedan sobre la mesa.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('resultado-dados')), findsNothing);
    expect(find.byKey(const ValueKey('dado-mesa-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('dado-mesa-1')), findsOneWidget);
    // Al pararse vuelve el diálogo con la tirada puesta.
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dado-mesa-0')), findsNothing);
    expect(find.byKey(const Key('resultado-dados')), findsOneWidget);
    expect(find.textContaining('Dado de slot (moneda): Jugador 2'),
        findsOneWidget);
    expect(find.widgetWithText(TextField, 'Zubat'), findsOneWidget);

    await tester.tap(find.byKey(const Key('aliado-aceptar')));
    await tester.pumpAndSettle();
    final aliado = c.read(estadoProvider).aliados.single;
    expect(aliado.slot, 1);
    expect(aliado.categoria, CategoriaAliado.cura);
    expect(aliado.nombre, 'Zubat');
    // La cura del jefe la aplica el programa (D-13), no la mesa.
    expect(aliado.efectos, EfectosAliado.programa);
    expect(aliado.scriptId, 'chupavidas-10');
  });
}

/// Azar que devuelve valores fijos (módulo el máximo), en orden.
class _AzarFijo implements Random {
  _AzarFijo(this._valores);

  final List<int> _valores;
  var _i = 0;

  @override
  int nextInt(int max) => _valores[_i++ % _valores.length] % max;

  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0;
}
