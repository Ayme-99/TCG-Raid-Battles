import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cuenta/cliente_api.dart';
import '../cuenta/controlador_sesion.dart';
import '../envios/botones_cuenta.dart';
import '../pantallas/boton_atras.dart';
import 'controlador_tienda.dart';

const _morado = Color(0xFF1B1235);
const _moradoClaro = Color(0xFF2A1D52);
const _amarillo = Color(0xFFFFC400);
const _lila = Color(0xFFE6DDF7);

/// Nombre de cada familia de la tienda (D-21 §2.2), en el orden en que salen.
const _familias = {
  'monedas': 'Monedas',
  'dados': 'Dados',
  'sobres': 'Sobres',
  'cartas': 'Cartas sueltas',
};

/// «1500» → «1.500».
String puntosConPuntos(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

/// Tienda de puntos de la pantalla de inicio (#374, D-21 §2). Exige sesión,
/// porque los puntos son de la cuenta. Hay un solo total: comprar lo baja, y
/// los jefes ya desbloqueados no se pierden (D-21 §1.2).
class PantallaTienda extends ConsumerStatefulWidget {
  const PantallaTienda({super.key});

  @override
  ConsumerState<PantallaTienda> createState() => _EstadoPantallaTienda();
}

class _EstadoPantallaTienda extends ConsumerState<PantallaTienda> {
  @override
  void initState() {
    super.initState();
    unawaited(
        Future.microtask(() => ref.read(tiendaProvider.notifier).cargar()));
  }

  Future<void> _comprar(ProductoTienda p) async {
    final tienda = ref.read(tiendaProvider);
    final total = tienda.puntos?.puntos ?? 0;
    final quedan = total - p.precio;
    final siguiente = tienda.puntos?.proximoJefe;
    final si = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        key: const Key('confirmar-compra'),
        title: Text('¿Comprar ${p.nombre}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cuesta ${puntosConPuntos(p.precio)} puntos. '
                'Te quedarán ${puntosConPuntos(quedan)}.'),
            if (siguiente != null) ...[
              const SizedBox(height: 8),
              Text('Para el próximo jefe te faltarán '
                  '${puntosConPuntos(siguiente.coste - quedan)} puntos.'),
            ],
            const SizedBox(height: 8),
            const Text('La compra es definitiva.'),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('cancelar-compra'),
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('si-comprar'),
            onPressed: () => Navigator.of(contexto).pop(true),
            child: Text('Comprar por ${puntosConPuntos(p.precio)}'),
          ),
        ],
      ),
    );
    if (si != true || !mounted) return;
    final motivo = await ref.read(tiendaProvider.notifier).comprar(p);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      key: Key(motivo == null ? 'compra-hecha' : 'compra-fallida'),
      content: Text(motivo ?? '¡${p.nombre} es tuyo!'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(sesionActualProvider);
    final tienda = ref.watch(tiendaProvider);
    final ancha = MediaQuery.of(context).size.width >= 700;
    final margen = ancha ? 48.0 : 16.0;

    final Widget contenido;
    if (sesion == null) {
      contenido = _Aviso(
        clave: 'tienda-sin-sesion',
        texto: 'La tienda usa los puntos de tu cuenta: inicia sesión para '
            'verla.',
        boton: 'Iniciar sesión',
        onPressed: () => abrirCuenta(context, ref),
      );
    } else if (tienda.puntos == null) {
      contenido = tienda.error != null
          ? _Aviso(
              clave: 'tienda-error',
              texto: tienda.error!,
              boton: 'Reintentar',
              onPressed: () => ref.read(tiendaProvider.notifier).cargar(),
            )
          : const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            );
    } else {
      final controlador = ref.read(tiendaProvider.notifier);
      contenido = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Saldo(puntos: tienda.puntos!),
          for (final familia in _familias.entries)
            if (tienda.productos.any((p) => p.familia == familia.key)) ...[
              const SizedBox(height: 20),
              Text(
                familia.value,
                style: const TextStyle(
                  color: _amarillo,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              for (final p in tienda.productos)
                if (p.familia == familia.key) ...[
                  _Producto(
                    producto: p,
                    disponibilidad: controlador.disponibilidad(p),
                    total: tienda.puntos!.puntos,
                    comprando: tienda.comprando == p.id,
                    onComprar: () => _comprar(p),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
        ],
      );
    }

    return Scaffold(
      key: const Key('tienda'),
      backgroundColor: _morado,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/mapas/sala-origen.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: _morado),
          ),
          ColoredBox(color: _morado.withValues(alpha: 0.62)),
          SafeArea(
            child: ListView(
              key: const Key('tienda-lista'),
              padding: EdgeInsets.fromLTRB(margen, 8, margen, 24),
              children: [
                Row(
                  children: [
                    BotonAtras(onPressed: () => Navigator.of(context).pop()),
                    const SizedBox(width: 12),
                    const Text(
                      'Tienda',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: contenido,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// El total de puntos, lo que falta para el próximo jefe y el aviso de que
/// comprar retrasa ese jefe (D-21 §1.2).
class _Saldo extends StatelessWidget {
  const _Saldo({required this.puntos});

  final PuntosCuenta puntos;

  @override
  Widget build(BuildContext context) {
    final proximo = puntos.proximoJefe;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _moradoClaro.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${puntosConPuntos(puntos.puntos)} puntos',
            key: const Key('tienda-puntos'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            proximo == null
                ? 'Tienes todos los jefes desbloqueados.'
                : 'Próximo jefe (nivel ${proximo.nivel}): '
                    '${puntosConPuntos(proximo.coste)} puntos. '
                    'Te faltan ${puntosConPuntos(proximo.faltan)}.',
            key: const Key('tienda-proximo-jefe'),
            style: const TextStyle(color: _lila, fontSize: 15),
          ),
          const SizedBox(height: 8),
          const Text(
            'Comprar baja tus puntos, así que tardarás más en llegar al '
            'próximo jefe. Los jefes que ya tienes no se pierden.',
            key: Key('tienda-aviso'),
            style: TextStyle(color: _amarillo, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Producto extends StatelessWidget {
  const _Producto({
    required this.producto,
    required this.disponibilidad,
    required this.total,
    required this.comprando,
    required this.onComprar,
  });

  final ProductoTienda producto;
  final DisponibilidadProducto disponibilidad;
  final int total;
  final bool comprando;
  final VoidCallback onComprar;

  @override
  Widget build(BuildContext context) {
    final precio = producto.precio <= 0
        ? 'Gratis'
        : '${puntosConPuntos(producto.precio)} puntos';
    final estado = switch (disponibilidad) {
      DisponibilidadProducto.gratis => 'Ya lo tienes',
      DisponibilidadProducto.comprado => 'Comprado',
      DisponibilidadProducto.proximamente => 'Llegará con las cartas digitales',
      DisponibilidadProducto.faltanPuntos =>
        'Te faltan ${puntosConPuntos(producto.precio - total)}',
      DisponibilidadProducto.comprable => null,
    };
    return Container(
      key: Key('producto-${producto.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _morado.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(precio, style: const TextStyle(color: _lila)),
                if (estado != null)
                  Text(
                    estado,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
              ],
            ),
          ),
          if (disponibilidad == DisponibilidadProducto.comprable ||
              disponibilidad == DisponibilidadProducto.faltanPuntos)
            FilledButton(
              key: Key('comprar-${producto.id}'),
              style: FilledButton.styleFrom(
                backgroundColor: _amarillo,
                foregroundColor: _morado,
              ),
              onPressed: disponibilidad == DisponibilidadProducto.comprable &&
                      !comprando
                  ? onComprar
                  : null,
              child: comprando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Comprar'),
            ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.clave,
    required this.texto,
    required this.boton,
    required this.onPressed,
  });

  final String clave;
  final String texto;
  final String boton;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key(clave),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _moradoClaro.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        children: [
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _amarillo,
              foregroundColor: _morado,
            ),
            onPressed: onPressed,
            child: Text(boton),
          ),
        ],
      ),
    );
  }
}
