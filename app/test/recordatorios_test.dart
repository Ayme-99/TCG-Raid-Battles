import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/catalogo/catalogo.dart';
import 'package:incursiones_app/partida/controlador_partida.dart';
import 'package:incursiones_app/partida/recordatorios.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import 'ayudas.dart';

/// Partida de dos jugadores contra el jefe [nombre] del catálogo, en el turno
/// del primer jugador y con una llamada de aliado por resolver.
EstadoPartida _partida(Catalogo c, String nombre) {
  final jefe = c.jefes.firstWhere((j) => j.nombre == nombre);
  // El mejor ataque de cada jugador decide el nivel: 200, 500, 700 o 1000.
  final ataque = const [100, 250, 350, 500][jefe.nivel - 1];
  var s = apply(
    EstadoPartida.inicial(),
    ConfigurarJugadores([
      ConfigJugador(nombre: 'Ana', ataqueMaximo: ataque),
      ConfigJugador(nombre: 'Beto', ataqueMaximo: ataque),
    ]),
  );
  s = apply(
    s,
    ElegirJefe(
      nombre: jefe.nombre,
      nivel: jefe.nivel,
      hp: jefe.hp,
      invocacionCadaHp: jefe.invocacion!.cadaHp,
    ),
  );
  return s.copiarCon(intentosInvocacionPendientes: 1);
}

/// El evento que registra la app al invocar al aliado de esa categoría.
AliadoInvocado _invocar(
  Catalogo c,
  EstadoPartida s,
  CategoriaAliado categoria, {
  int slot = 1,
}) {
  final a = c.aliadoDe(s.jefe!.nombre, s.jefe!.nivel, categoria)!;
  return AliadoInvocado(
    slot: slot,
    categoria: categoria,
    nombre: a.nombre,
    hp: a.hp,
    ataqueNombre: a.ataqueNombre,
    ataqueDano: a.ataqueDano,
    habilidad: a.textoParaLaMesa,
    efectos: a.efectos,
    scriptId: a.scriptId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('recordatorios de las cartas', () {
    late Catalogo c;

    setUpAll(() async {
      c = await Catalogo.cargar(rootBundle);
    });

    test('Rhyhorn: Tormenta de Arena se recuerda en el Chequeo Pokémon', () {
      var s = _partida(c, 'Onix');
      expect(recordatoriosDeChequeo(c, s), isEmpty);
      s = apply(s, _invocar(c, s, CategoriaAliado.control));
      expect(recordatoriosDeChequeo(c, s).single, contains('Tormenta de Arena'));
      expect(recordatoriosAlEntrar(c, s, s.aliados.single), isEmpty);
      expect(recordatoriosDeTurno(c, s, 0), isEmpty);
    });

    test('Haunter: Rencor se recuerda en el turno de cada jugador', () {
      var s = _partida(c, 'Onix');
      s = apply(s, _invocar(c, s, CategoriaAliado.debilitador));
      expect(recordatoriosDeTurno(c, s, 0).single, contains('Rencor'));
      expect(recordatoriosDeTurno(c, s, 1).single, contains('Rencor'));
      expect(recordatoriosDeChequeo(c, s), isEmpty);
    });

    test('Geodude: el turno avisa de que la app descuenta 10 del ataque', () {
      var s = _partida(c, 'Onix');
      s = apply(s, _invocar(c, s, CategoriaAliado.tanque));
      expect(
        recordatoriosDeTurno(c, s, 0).single,
        contains('10 puntos de daño menos'),
      );
    });

    test('Oddish: Drenadoras se recuerda al entrar y en cada chequeo', () {
      var s = _partida(c, 'Manectric');
      s = apply(s, _invocar(c, s, CategoriaAliado.cura));
      expect(
        recordatoriosAlEntrar(c, s, s.aliados.single).single,
        contains('Drenadoras'),
      );
      expect(recordatoriosDeChequeo(c, s).single, contains('Drenadoras'));
    });

    test('Gulpin: Tóxico es un ataque sin daño que usa al entrar', () {
      var s = _partida(c, 'Manectric');
      s = apply(s, _invocar(c, s, CategoriaAliado.control));
      final gulpin = s.entradasPendientes.single;
      expect(gulpin.ataqueNombre, 'Tóxico');
      expect(gulpin.ataqueDano, 0);
      s = apply(s, const AtaqueAliado(slot: 1, dano: 0));
      expect(s.entradasPendientes, isEmpty);
    });

    test('Minun: quien lo deja fuera de combate ve que está Paralizado', () {
      var s = _partida(c, 'Manectric');
      s = apply(s, _invocar(c, s, CategoriaAliado.tanque));
      s = apply(s, const AtaqueAliado(slot: 1, dano: 10));
      s = apply(s, const AtaqueAAliado(jugador: 0, slot: 1, dano: 90));
      expect(s.aliados, isEmpty);
      expect(recordatoriosDeTurno(c, s, 0).single, contains('Paralizado'));
      expect(recordatoriosDeTurno(c, s, 1), isEmpty);
    });

    test('Tentacruel y Seel recuerdan su regla en el turno', () {
      var s = _partida(c, 'Kingdra');
      s = apply(s, _invocar(c, s, CategoriaAliado.control));
      expect(recordatoriosDeTurno(c, s, 0).single, contains('Constricción'));
      var t = _partida(c, 'Kingdra');
      t = apply(t, _invocar(c, t, CategoriaAliado.tanque));
      expect(recordatoriosDeTurno(c, t, 0).single, contains('Velo Sagrado'));
    });

    test('Nosepass: Fijar Blanco sigue recordándose cuando ya ha caído', () {
      var s = _partida(c, 'Arceus');
      s = apply(s, _invocar(c, s, CategoriaAliado.control));
      expect(
        recordatoriosAlEntrar(c, s, s.aliados.single).single,
        contains('Fijar Blanco'),
      );
      // En juego: una sola línea, no dos.
      expect(recordatoriosDeTurno(c, s, 0).single, contains('Fijar Blanco'));
      s = apply(s, const AtaqueAAliado(jugador: 0, slot: 1, dano: 60));
      expect(s.aliados, isEmpty);
      expect(recordatoriosDeTurno(c, s, 1).single, contains('Fijar Blanco'));
      expect(recordatoriosDeMoneda(c, s).single, contains('cruz'));
    });

    test('sin catálogo no hay recordatorios de cartas', () {
      var s = _partida(c, 'Onix');
      s = apply(s, _invocar(c, s, CategoriaAliado.control));
      expect(recordatoriosDeChequeo(null, s), isEmpty);
      expect(recordatoriosDeTurno(null, s, 0), isEmpty);
    });
  });

  group('en la mesa', () {
    /// Abre la app con el catálogo, configura dos jugadores con ese mejor
    /// ataque y elige el jefe [id] del catálogo.
    Future<ProviderContainer> abrir(
      WidgetTester tester, {
      required String id,
      required String ataque,
      MazoAtaquesJefe? mazo,
    }) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final catalogo =
          (await tester.runAsync(() => Catalogo.cargar(rootBundle)))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...sobrescribir(mazo: mazo),
            catalogoProvider.overrideWith((ref) async => catalogo),
          ],
          child: const IncursionesApp(),
        ),
      );
      await tester.pumpAndSettle();
      for (final clave in ['ataque-0', 'ataque-1']) {
        await tester.enterText(
          find.descendant(
            of: find.byKey(Key(clave)),
            matching: find.byType(TextField),
          ),
          ataque,
        );
      }
      await tester.tap(find.byKey(const Key('configurar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('catalogo-$id')));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(IncursionesApp)),
      );
    }

    void registrar(ProviderContainer c, Evento e) {
      final error = c.read(partidaProvider.notifier).registrar(e);
      if (error != null) throw StateError('$e: $error');
    }

    testWidgets('con Rhyhorn, el turno del jefe pide el Chequeo Pokémon',
        (tester) async {
      final c = await abrir(tester, id: 'onix', ataque: '100');
      llegarALaLlamadaDelJefe(c);
      registrar(
        c,
        const AliadoInvocado(
          slot: 0,
          categoria: CategoriaAliado.control,
          nombre: 'Rhyhorn',
          hp: 100,
          habilidad: 'Tormenta de Arena',
        ),
      );
      jugadoresActuanSinDano(c);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('robar-carta-jefe')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('registrar-ataque-jefe')));
      await tester.pumpAndSettle();

      // Antes de terminar el turno hay que hacer el chequeo.
      expect(find.byKey(const Key('fin-turno-jefe')), findsNothing);
      await tester.tap(find.byKey(const Key('chequeo-pokemon')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('aviso-mesa')), findsOneWidget);
      expect(find.textContaining('Tormenta de Arena: pon 1 contador'),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('aviso-mesa-hecho')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chequeo-pokemon')), findsNothing);
      await tester.tap(find.byKey(const Key('fin-turno-jefe')));
      await tester.pumpAndSettle();
      expect(c.read(estadoProvider).fase, Fase.turnoJugadores);
      expect(c.read(estadoProvider).ronda, 3);
    });

    testWidgets('con Geodude, el turno del jugador avisa del descuento',
        (tester) async {
      final c = await abrir(tester, id: 'onix', ataque: '100');
      llegarALaLlamadaDelJefe(c);
      for (final e in const <Evento>[
        AliadoInvocado(
          slot: 0,
          categoria: CategoriaAliado.tanque,
          nombre: 'Geodude',
          hp: 90,
          efectos: EfectosAliado.programa,
          scriptId: 'tanque-jefe-10',
        ),
      ]) {
        registrar(c, e);
      }
      jugadoresActuanSinDano(c);
      for (final e in const <Evento>[
        AtaqueJefe(ranura: 1, dano: 0),
        FinTurnoJefe(),
      ]) {
        registrar(c, e);
      }
      await tester.pumpAndSettle();

      expect(c.read(estadoProvider).fase, Fase.turnoJugadores);
      expect(find.byKey(const Key('recordatorios-turno')), findsOneWidget);
      expect(find.textContaining('10 puntos de daño menos'), findsOneWidget);
    });

    testWidgets('Castigo pregunta si se cumple y suma los 50', (tester) async {
      final c = await abrir(
        tester,
        id: 'arceus',
        ataque: '500',
        mazo: MazoFijo(const [
          CartaAtaqueJefe(numero: 14, ranura: 2, jugador: 1, robaOtra: false),
        ]),
      );
      for (final j in c.read(estadoProvider).orden) {
        registrar(c, TurnoJugador(jugador: j, dano: 1));
      }
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('robar-carta-jefe')));
      await tester.pumpAndSettle();
      expect(find.text('Castigo · 100'), findsOneWidget);
      await tester.tap(find.byKey(const Key('registrar-ataque-jefe')));
      await tester.pumpAndSettle();
      expect(find.textContaining('¿Se cumple?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pregunta-si')));
      await tester.pumpAndSettle();

      final ataque =
          c.read(partidaProvider).partida.eventos.last as AtaqueJefe;
      expect(ataque.ranura, 2);
      expect(ataque.jugador, 1);
      expect(ataque.dano, 150);
    });
  });
}
