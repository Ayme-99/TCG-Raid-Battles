import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/campana.dart';

/// Carpeta de los assets del catálogo de campaña: copia de `catalog/campana/`
/// que hace `tool/sync_catalogo.sh`.
const carpetaCampana = 'assets/catalogo/campana';

/// Región que se juega. Hoy solo existe el primer tramo de Kanto.
const regionCampana = 'kanto';

/// Lee el catálogo de campaña empaquetado en la app: todos los JSON de
/// `pokemon/`, `zonas/` y `jefes/`, y la región [regionCampana].
Future<CatalogoCampana> cargarCatalogoCampana(AssetBundle bundle) async {
  final manifiesto = await AssetManifest.loadFromAssetBundle(bundle);
  final todos = manifiesto.listAssets();
  List<String> de(String carpeta) => [
        for (final a in todos)
          if (a.startsWith('$carpetaCampana/$carpeta/') && a.endsWith('.json'))
            a,
      ]..sort();
  Future<Map<String, dynamic>> leer(String ruta) async =>
      jsonDecode(await bundle.loadString(ruta)) as Map<String, dynamic>;
  String id(String ruta) => ruta.split('/').last.replaceAll('.json', '');
  return CatalogoCampana.desdeJson(
    pokemon: [for (final r in de('pokemon')) await leer(r)],
    zonas: [for (final r in de('zonas')) await leer(r)],
    jefes: {for (final r in de('jefes')) id(r): await leer(r)},
    region: await leer('$carpetaCampana/regiones/$regionCampana.json'),
  );
}

/// El catálogo de campaña. Los tests lo sustituyen por uno leído de disco.
final catalogoCampanaProvider = FutureProvider<CatalogoCampana>(
  (ref) => cargarCatalogoCampana(rootBundle),
);
