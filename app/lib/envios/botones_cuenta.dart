import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cuenta/controlador_sesion.dart';
import '../cuenta/pantalla_login.dart';
import 'controlador_envios.dart';

/// Botón de la barra superior: iniciar sesión o ver y cerrar la sesión.
class BotonCuenta extends ConsumerWidget {
  const BotonCuenta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionActualProvider);
    return IconButton(
      key: const Key('cuenta'),
      tooltip: sesion == null ? 'Iniciar sesión' : 'Sesión de ${sesion.username}',
      icon: Icon(
        sesion == null ? Icons.account_circle_outlined : Icons.account_circle,
      ),
      onPressed: () {
        if (sesion == null) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PantallaLogin()),
          );
          return;
        }
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Sesión de ${sesion.username}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
              FilledButton(
                key: const Key('cerrar-sesion'),
                onPressed: () {
                  ref.read(sesionProvider.notifier).cerrarSesion();
                  Navigator.of(context).pop();
                },
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Aparece en la barra superior si hay partidas sin enviar o rechazadas, y
/// abre el detalle con la opción de reintentar.
class BotonEnvios extends ConsumerWidget {
  const BotonEnvios({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final envios = ref.watch(enviosProvider);
    if (envios.pendientes == 0 && envios.rechazadas == 0) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: const Key('envios'),
      tooltip: 'Resultados sin enviar',
      icon: Badge(
        label: Text('${envios.pendientes + envios.rechazadas}'),
        child: Icon(
          envios.rechazadas > 0 ? Icons.error_outline : Icons.cloud_upload,
        ),
      ),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => const _DetalleEnvios(),
      ),
    );
  }
}

class _DetalleEnvios extends ConsumerWidget {
  const _DetalleEnvios();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final envios = ref.watch(enviosProvider);
    final sesion = ref.watch(sesionActualProvider);
    return AlertDialog(
      title: const Text('Resultados sin enviar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pendientes de enviar: ${envios.pendientes}'),
          Text('Rechazadas por el servidor: ${envios.rechazadas}'),
          if (sesion == null && envios.pendientes > 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Inicia sesión para poder enviarlas.'),
            ),
          if (envios.mensaje != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(envios.mensaje!),
            ),
        ],
      ),
      actions: [
        if (envios.rechazadas > 0)
          TextButton(
            key: const Key('descartar-rechazadas'),
            onPressed: () =>
                ref.read(enviosProvider.notifier).descartarRechazadas(),
            child: const Text('Descartar rechazadas'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        FilledButton(
          key: const Key('reintentar-ahora'),
          onPressed: envios.pendientes == 0 || envios.enviando || sesion == null
              ? null
              : () => ref.read(enviosProvider.notifier).procesar(),
          child: const Text('Reintentar ahora'),
        ),
      ],
    );
  }
}
