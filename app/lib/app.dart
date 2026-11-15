import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pantallas/inicio.dart';
import 'pantallas/pantalla_partida.dart';

/// Raíz de la app. El diseño visual definitivo llega con los bocetos (T-18);
/// de momento las pantallas son funcionales y sencillas.
class IncursionesApp extends StatelessWidget {
  const IncursionesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Incursiones',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: const _Raiz(),
    );
  }
}

/// Pantalla de inicio al abrir; la partida, al empezar o continuar (#232).
class _Raiz extends ConsumerWidget {
  const _Raiz();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(enPartidaProvider)
        ? const PantallaPartida()
        : const PantallaInicio();
  }
}
