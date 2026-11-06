import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'almacen/almacen.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferencias = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        almacenProvider.overrideWithValue(AlmacenPreferencias(preferencias)),
      ],
      child: const IncursionesApp(),
    ),
  );
}
