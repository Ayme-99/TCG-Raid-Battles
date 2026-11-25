import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:incursiones_app/almacen/almacen.dart';
import 'package:incursiones_app/app.dart';
import 'package:incursiones_app/tienda/pantalla_tienda.dart';

import 'ayudas.dart';

/// Servidor falso de la tienda: lleva el total y lo comprado, y cobra como el
/// de verdad (un solo total; moneda y dados, una vez por cuenta).
class TiendaFalsa {
  TiendaFalsa({this.puntos = 3000, this.nivelUnoDesbloqueado = false});

  int puntos;
  bool nivelUnoDesbloqueado;
  final Set<String> comprados = {};
  final List<Map<String, dynamic>> compras = [];

  /// Todas las compras que la app ha intentado, también sin red.
  final List<Map<String, dynamic>> intentos = [];
  bool sinRed = false;

  static const productos = [
    {
      'id': 'moneda-clasica',
      'familia': 'monedas',
      'nombre': 'Moneda clásica',
      'precio': 0,
      'disponible': true
    },
    {
      'id': 'moneda-serie',
      'familia': 'monedas',
      'nombre': 'Moneda de serie (color o metal)',
      'precio': 800,
      'disponible': true
    },
    {
      'id': 'dados-tematicos',
      'familia': 'dados',
      'nombre': 'Juego de dados temático',
      'precio': 3000,
      'disponible': true
    },
    {
      'id': 'sobre',
      'familia': 'sobres',
      'nombre': 'Sobre del formato digital',
      'precio': 1000,
      'disponible': false
    },
  ];

  Map<String, Object?> _puntos() => {
        'puntos': puntos,
        'niveles': [
          for (final (n, c) in [(1, 10000), (2, 20000)])
            {
              'nivel': n,
              'coste': c,
              'alcanzado': puntos >= c || (n == 1 && nivelUnoDesbloqueado),
              'faltan': puntos >= c || (n == 1 && nivelUnoDesbloqueado)
                  ? 0
                  : c - puntos,
            },
        ],
      };

  Future<http.Response> responder(http.Request p) async {
    final ruta = p.url.path;
    final esCompra = ruta.endsWith('/tienda/compras') && p.method == 'POST';
    if (esCompra) intentos.add(jsonDecode(p.body) as Map<String, dynamic>);
    if (sinRed) throw http.ClientException('sin red');
    // Como el servidor de verdad: JSON en UTF-8 («clásica», «temático»).
    http.Response json(Object cuerpo, [int estado = 200]) =>
        http.Response.bytes(utf8.encode(jsonEncode(cuerpo)), estado,
            headers: {'content-type': 'application/json; charset=utf-8'});
    if (ruta.endsWith('/me/puntos')) return json(_puntos());
    if (ruta.endsWith('/tienda')) return json({'productos': productos});
    if (ruta.endsWith('/tienda/compras') && p.method == 'GET') {
      return json({'productos': comprados.toList(), 'compras': compras});
    }
    if (ruta.endsWith('/tienda/compras')) {
      final cuerpo = jsonDecode(p.body) as Map<String, dynamic>;
      compras.add(cuerpo);
      final producto =
          productos.firstWhere((x) => x['id'] == cuerpo['producto']);
      final precio = producto['precio']! as int;
      if (comprados.contains(producto['id'])) {
        return json({'error': 'ya_comprado'}, 409);
      }
      if (puntos < precio) return json({'error': 'puntos_insuficientes'}, 409);
      puntos -= precio;
      comprados.add(producto['id']! as String);
      return json({'puntos': puntos, 'repetida': false}, 201);
    }
    return json({'error': 'no_encontrada'}, 404);
  }
}

Future<void> abrirTienda(
  WidgetTester tester, {
  required TiendaFalsa servidor,
  AlmacenMemoria? almacen,
  Size tamano = const Size(1280, 800),
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: sobrescribir(
      almacen: almacen ?? almacenConSesion(),
      servidor: servidor.responder,
      conInicio: true,
    ),
    child: const IncursionesApp(),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('inicio-tienda')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('tienda')), findsOneWidget);
}

String texto(WidgetTester tester, String clave) =>
    tester.widget<Text>(find.byKey(Key(clave))).data!;

Finder en(String producto, String texto) => find.descendant(
    of: find.byKey(Key('producto-$producto')), matching: find.text(texto));

bool activo(WidgetTester tester, String clave) =>
    tester.widget<FilledButton>(find.byKey(Key(clave))).onPressed != null;

void main() {
  test('los puntos se escriben con punto de miles', () {
    expect(puntosConPuntos(0), '0');
    expect(puntosConPuntos(800), '800');
    expect(puntosConPuntos(1500), '1.500');
    expect(puntosConPuntos(20000), '20.000');
    expect(puntosConPuntos(1234567), '1.234.567');
  });

  testWidgets('enseña el total, el próximo jefe, el aviso y el catálogo',
      (tester) async {
    await abrirTienda(tester, servidor: TiendaFalsa(puntos: 3000));
    expect(texto(tester, 'tienda-puntos'), '3.000 puntos');
    expect(texto(tester, 'tienda-proximo-jefe'),
        'Próximo jefe (nivel 1): 10.000 puntos. Te faltan 7.000.');
    expect(find.byKey(const Key('tienda-aviso')), findsOneWidget);
    expect(en('moneda-clasica', 'Ya lo tienes'), findsOneWidget);
    expect(en('sobre', 'Llegará con las cartas digitales'), findsOneWidget);
    expect(find.byKey(const Key('comprar-sobre')), findsNothing);
    expect(activo(tester, 'comprar-moneda-serie'), isTrue);
    expect(activo(tester, 'comprar-dados-tematicos'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('comprar pide confirmación con el precio y baja el total',
      (tester) async {
    final servidor = TiendaFalsa(puntos: 3000);
    await abrirTienda(tester, servidor: servidor);
    await tester.tap(find.byKey(const Key('comprar-moneda-serie')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirmar-compra')), findsOneWidget);
    expect(find.text('Cuesta 800 puntos. Te quedarán 2.200.'), findsOneWidget);
    expect(find.text('Para el próximo jefe te faltarán 7.800 puntos.'),
        findsOneWidget);
    expect(find.text('La compra es definitiva.'), findsOneWidget);
    // Cancelar no compra nada.
    await tester.tap(find.byKey(const Key('cancelar-compra')));
    await tester.pumpAndSettle();
    expect(servidor.compras, isEmpty);

    await tester.tap(find.byKey(const Key('comprar-moneda-serie')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('si-comprar')));
    await tester.pumpAndSettle();
    expect(servidor.compras.single['producto'], 'moneda-serie');
    expect(servidor.compras.single['version'], 1);
    expect(find.byKey(const Key('compra-hecha')), findsOneWidget);
    expect(texto(tester, 'tienda-puntos'), '2.200 puntos');
    expect(en('moneda-serie', 'Comprado'), findsOneWidget);
    expect(find.byKey(const Key('comprar-moneda-serie')), findsNothing);
    // Ya no llega a los dados temáticos.
    expect(activo(tester, 'comprar-dados-tematicos'), isFalse);
    expect(en('dados-tematicos', 'Te faltan 800'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un jefe desbloqueado sigue desbloqueado tras comprar',
      (tester) async {
    final servidor = TiendaFalsa(puntos: 10500);
    await abrirTienda(tester, servidor: servidor);
    expect(texto(tester, 'tienda-proximo-jefe'),
        'Próximo jefe (nivel 2): 20.000 puntos. Te faltan 9.500.');
    servidor.nivelUnoDesbloqueado = true;
    await tester.tap(find.byKey(const Key('comprar-dados-tematicos')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('si-comprar')));
    await tester.pumpAndSettle();
    expect(texto(tester, 'tienda-puntos'), '7.500 puntos');
    expect(texto(tester, 'tienda-proximo-jefe'),
        'Próximo jefe (nivel 2): 20.000 puntos. Te faltan 12.500.');
  });

  testWidgets('sin conexión se avisa y el reintento usa el mismo id de compra',
      (tester) async {
    final servidor = TiendaFalsa(puntos: 3000);
    await abrirTienda(tester, servidor: servidor);
    servidor.sinRed = true;
    await tester.tap(find.byKey(const Key('comprar-moneda-serie')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('si-comprar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('compra-fallida')), findsOneWidget);
    expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);
    expect(texto(tester, 'tienda-puntos'), '3.000 puntos');

    servidor.sinRed = false;
    await tester.tap(find.byKey(const Key('comprar-moneda-serie')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('si-comprar')));
    await tester.pumpAndSettle();
    expect(servidor.compras, hasLength(1));
    expect(servidor.intentos, hasLength(2));
    final id = servidor.intentos.first['compra'] as String;
    expect(id, matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(servidor.intentos.last['compra'], id);
    expect(texto(tester, 'tienda-puntos'), '2.200 puntos');
  });

  testWidgets('sin sesión pide iniciarla', (tester) async {
    await abrirTienda(tester,
        servidor: TiendaFalsa(), almacen: AlmacenMemoria());
    expect(find.byKey(const Key('tienda-sin-sesion')), findsOneWidget);
    expect(find.byKey(const Key('tienda-puntos')), findsNothing);
  });

  testWidgets('en el móvil la tienda se abre desde el inicio y cabe',
      (tester) async {
    await abrirTienda(tester,
        servidor: TiendaFalsa(puntos: 3000), tamano: const Size(390, 844));
    expect(texto(tester, 'tienda-puntos'), '3.000 puntos');
    expect(tester.takeException(), isNull);
  });
}
