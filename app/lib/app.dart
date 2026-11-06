import 'package:flutter/material.dart';

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
      home: const PantallaPartida(),
    );
  }
}
