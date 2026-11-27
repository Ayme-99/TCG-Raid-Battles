import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/almacen/almacen.dart';
import 'package:incursiones_app/campana/controlador_campana.dart';
import 'package:incursiones_app/campana/escena_mapa.dart';
import 'package:incursiones_app/campana/pantalla_campana.dart'
    show nombreObjeto;
import 'package:incursiones_engine/campana.dart';

import 'ayudas.dart';
import 'campana_test.dart' show abrirCampana, hay, tocar, jugarCombate;

/// Pantalla del mapa como escenas interactivas (D-20 §10.7, propuesta D;
/// #373): la escena del nodo, sus zonas pulsables y la barra de recursos.
void main() {
  bool zonaActiva(WidgetTester tester, String clave) {
    final ink = find.descendant(
        of: find.byKey(Key(clave)), matching: find.byType(InkWell));
    return tester.widget<InkWell>(ink).onTap != null;
  }

  testWidgets('se empieza en la escena de Pueblo Paleta y se elige inicial',
      (tester) async {
    final c = await abrirCampana(tester, almacen: AlmacenMemoria());
    await tocar(tester, 'campana-empezar');
    expect(hay('escena-pueblo-paleta'), isTrue);
    expect(hay('barra-recursos'), isTrue);
    expect(find.byKey(const Key('barra-dinero')), findsOneWidget);
    expect(zonaActiva(tester, 'zona-inicial'), isTrue);
    expect(zonaActiva(tester, 'zona-ir-ruta-1'), isFalse,
        reason: 'sin inicial no se sale');
    await tocar(tester, 'zona-inicial');
    await tocar(tester, 'hoja-inicial-charmander');
    expect(c.read(campanaProvider).partida!.equipo.single.id, 'charmander');
    expect(zonaActiva(tester, 'zona-inicial'), isFalse);
    expect(zonaActiva(tester, 'zona-ir-ruta-1'), isTrue);
    await tocar(tester, 'zona-ir-ruta-1');
    expect(hay('escena-ruta-1'), isTrue);
    expect(c.read(campanaProvider).partida!.progreso.nodoActual, 'ruta-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('la hierba alta lanza el combate y el borde vuelve atrás',
      (tester) async {
    const guardada = PartidaCampana(
      progreso: ProgresoRuta(
          nodoActual: 'ruta-1-pidgey',
          superados: {'pueblo-paleta', 'ruta-1'},
          visitados: {'pueblo-paleta', 'ruta-1', 'ruta-1-pidgey'},
          inicial: 'squirtle'),
      equipo: [PokemonGuardado('squirtle', 80)],
      dinero: 1000,
    );
    final c = await abrirCampana(tester,
        almacen: AlmacenMemoria(), guardada: guardada);
    expect(zonaActiva(tester, 'zona-combate'), isTrue);
    expect(zonaActiva(tester, 'zona-ir-ciudad-verde'), isFalse,
        reason: 'hasta ganar no se sigue');
    expect(zonaActiva(tester, 'zona-ir-ruta-1'), isTrue,
        reason: 'se puede volver atrás');
    await tocar(tester, 'zona-combate');
    expect(hay('campana-combate'), isTrue);
    await jugarCombate(tester);
    // La Ruta 1 ofrece captura, pero aún no hay Pokéballs: solo «Seguir».
    await tocar(tester, 'campana-no-capturar');
    expect(zonaActiva(tester, 'zona-ir-ciudad-verde'), isTrue);
    // El salvaje ganado se vuelve a buscar en la hierba (#412).
    expect(zonaActiva(tester, 'zona-combate'), isTrue);
    await tocar(tester, 'zona-ir-ruta-1');
    expect(c.read(campanaProvider).partida!.progreso.nodoActual, 'ruta-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('en el centro, el mostrador cura y la estantería abre la tienda',
      (tester) async {
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
    final c = await abrirCampana(tester,
        almacen: AlmacenMemoria(), guardada: guardada);
    await tocar(tester, 'zona-curar');
    expect(c.read(campanaProvider).partida!.equipo.single.ps, 80);
    await tocar(tester, 'zona-tienda');
    final hoja = find.byType(BottomSheet);
    expect(hoja, findsOneWidget);
    await tester.tap(find.descendant(
        of: hoja, matching: find.byKey(const Key('comprar-pokeball'))));
    await tester.pumpAndSettle();
    expect(c.read(campanaProvider).partida!.cuantos(ObjetoCampana.pokeball), 1);
    expect(find.text('800 \$'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('cada zona de Kanto tiene un rótulo y una clave únicos en su escena',
      () {
    final c = catalogoCampanaDeDisco();
    for (final n in c.region.nodos.values) {
      final claves = [for (final z in n.escena!.zonas) claveZona(z)];
      expect(claves.toSet().length, claves.length, reason: n.id);
      final p = PartidaCampana(
          progreso: ProgresoRuta(nodoActual: n.id),
          equipo: const [PokemonGuardado('squirtle', 80)]);
      for (final z in n.escena!.zonas) {
        expect(estadoZona(c, p, z).rotulo, isNotEmpty, reason: n.id);
      }
    }
  });

  testWidgets('al llegar a la galería del Monte Moon se coge la Piedra Luna',
      (tester) async {
    const guardada = PartidaCampana(
      progreso: ProgresoRuta(
          nodoActual: 'monte-moon',
          resuelto: true,
          visitados: {'monte-moon'},
          inicial: 'squirtle'),
      equipo: [PokemonGuardado('squirtle', 80)],
      dinero: 1000,
    );
    final c = await abrirCampana(tester,
        almacen: AlmacenMemoria(), guardada: guardada);
    expect(zonaActiva(tester, 'zona-ir-monte-moon-galeria'), isTrue);
    await tocar(tester, 'zona-ir-monte-moon-galeria');
    final p = c.read(campanaProvider).partida!;
    expect(p.progreso.nodoActual, 'monte-moon-galeria');
    expect(p.cuantos(ObjetoCampana.piedraLuna), 1);
    expect(find.text('¡Has encontrado una Piedra Luna!'), findsOneWidget);
    expect(nombreObjeto(ObjetoCampana.piedraLuna), 'Piedra Luna');
    expect(tester.takeException(), isNull);
  });
}
