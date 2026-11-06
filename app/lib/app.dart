import 'package:flutter/material.dart';

/// Raíz de la app. Las pantallas llegan con los bocetos (T-18): de momento
/// solo hay una pantalla de inicio que confirma que la app arranca.
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
      home: const PantallaInicio(),
    );
  }
}

class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Incursiones')),
      body: const Center(
        child: Text('Las pantallas llegan con los bocetos (T-18).'),
      ),
    );
  }
}
