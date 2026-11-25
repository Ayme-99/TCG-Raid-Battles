import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/almacen/almacen.dart';
import 'package:incursiones_app/campana/escena_mapa.dart';
import 'package:incursiones_engine/campana.dart';

import 'ayudas.dart';
import 'campana_test.dart' show abrirCampana;

/// Rótulos de las zonas pulsables legibles en horizontal (#495; D-20 §10.7,
/// campaña solo apaisada). En el playtest del 2026-11-25 la puerta bloqueada
/// «Salida de Ciudad Verde» salía en letra diminuta.
void main() {
  /// Letra mínima con la que se tiene que ver un rótulo en pantalla.
  const minimo = 12.0;

  /// El tamaño de letra con que se ve en pantalla el rótulo [texto] de la zona
  /// [clave]: el de su estilo por lo que lo encoja el `FittedBox`.
  double letraEnPantalla(WidgetTester tester, String clave, String texto) {
    final f = find.descendant(
        of: find.byKey(Key(clave)), matching: find.text(texto));
    expect(f, findsOneWidget, reason: clave);
    final parrafo = tester.renderObject<RenderParagraph>(f);
    final escala = tester.getSize(f).width / parrafo.size.width;
    final estilo = tester.widget<Text>(f).style!;
    return estilo.fontSize! * escala;
  }

  testWidgets('en el móvil apaisado, la puerta «Salida de Ciudad Verde» '
      'se lee sin encoger', (tester) async {
    const guardada = PartidaCampana(
      progreso: ProgresoRuta(
          nodoActual: 'ciudad-verde',
          superados: {'pueblo-paleta', 'ruta-1', 'ruta-1-pidgey'},
          visitados: {
            'pueblo-paleta',
            'ruta-1',
            'ruta-1-pidgey',
            'ciudad-verde'
          },
          inicial: 'squirtle'),
      equipo: [PokemonGuardado('squirtle', 30)],
      dinero: 1000,
    );
    await abrirCampana(tester,
        almacen: AlmacenMemoria(),
        guardada: guardada,
        tamano: const Size(844, 390));
    const clave = 'zona-ir-ciudad-verde-salida';
    final letra = letraEnPantalla(tester, clave, 'Salida de Ciudad Verde');
    expect(letra, closeTo(tamanoRotuloZona, 0.01),
        reason: 'parte en líneas en lugar de encogerse');
    // Y el texto no se sale de la puerta.
    final puerta = tester.getRect(find.byKey(const Key(clave)));
    final texto = tester.getRect(find.descendant(
        of: find.byKey(const Key(clave)),
        matching: find.text('Salida de Ciudad Verde')));
    expect(puerta.contains(texto.topLeft) && puerta.contains(texto.bottomRight),
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('todos los rótulos de Kanto se leen en una escena de 820 px',
      (tester) async {
    // 844×390 menos los márgenes de la pantalla de campaña.
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = catalogoCampanaDeDisco();
    for (final n in c.region.nodos.values) {
      final p = PartidaCampana(
          progreso: ProgresoRuta(nodoActual: n.id),
          equipo: const [PokemonGuardado('squirtle', 80)]);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: 820,
                  child: EscenaInteractiva(
                      catalogo: c, partida: p, alTocar: (_) {}),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      for (final z in n.escena!.zonas) {
        final rotulo = estadoZona(c, p, z).rotulo;
        expect(letraEnPantalla(tester, claveZona(z), rotulo),
            greaterThanOrEqualTo(minimo),
            reason: '${n.id}: $rotulo');
      }
      expect(tester.takeException(), isNull, reason: n.id);
    }
  });
}
