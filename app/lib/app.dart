import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pantallas/inicio.dart';
import 'sala/controlador_sala.dart';
import 'sala/pantalla_sala.dart';
import 'pantallas/pantalla_partida.dart';
import 'pokedex/pokedex.dart';

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
    // Apunta en la Pokédex cada partida que termina, en cualquier pantalla.
    ref.watch(pokedexProvider);
    final sala = ref.watch(salaProvider);
    final Widget pantalla;
    if (sala.cancelada) {
      pantalla = const PantallaSalaCancelada();
    } else if (sala.enSala && !(sala.info?.enCurso ?? false)) {
      pantalla = const PantallaSala();
    } else if (ref.watch(enPartidaProvider) || sala.enSala) {
      pantalla = const PantallaPartida();
    } else {
      pantalla = const PantallaInicio();
    }
    // El aviso de desconexión flota sobre cualquier pantalla de la sala.
    return Stack(children: [pantalla, const AvisoDesconexion()]);
  }
}
