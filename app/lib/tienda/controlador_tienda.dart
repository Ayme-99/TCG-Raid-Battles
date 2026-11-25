import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../campana/controlador_campana.dart' show nuevoIdPartida;
import '../cuenta/cliente_api.dart';
import '../cuenta/controlador_sesion.dart';
import '../cuenta/sesion.dart';
import '../partida/controlador_partida.dart' show azarProvider;

/// Lo que enseña la tienda de puntos (#374, D-21 §2).
class EstadoTienda {
  const EstadoTienda({
    this.cargando = false,
    this.error,
    this.puntos,
    this.productos = const [],
    this.comprados = const {},
    this.comprando,
  });

  final bool cargando;

  /// Por qué no se ha podido leer la tienda (sin conexión, sesión caducada).
  final String? error;

  /// El total de la cuenta y los niveles de jefe; null si aún no se ha leído.
  final PuntosCuenta? puntos;
  final List<ProductoTienda> productos;

  /// Ids de los productos que ya tiene la cuenta.
  final Set<String> comprados;

  /// Id del producto que se está comprando, o null.
  final String? comprando;

  EstadoTienda copiar({
    bool? cargando,
    String? error,
    bool sinError = false,
    PuntosCuenta? puntos,
    List<ProductoTienda>? productos,
    Set<String>? comprados,
    String? comprando,
    bool sinComprando = false,
  }) =>
      EstadoTienda(
        cargando: cargando ?? this.cargando,
        error: sinError ? null : (error ?? this.error),
        puntos: puntos ?? this.puntos,
        productos: productos ?? this.productos,
        comprados: comprados ?? this.comprados,
        comprando: sinComprando ? null : (comprando ?? this.comprando),
      );
}

/// Si un producto se puede comprar ya y, si no, por qué.
enum DisponibilidadProducto {
  comprable,
  gratis,
  comprado,
  proximamente,
  faltanPuntos
}

/// Lee la tienda y compra. Las reglas (precio, saldo, una moneda o unos dados
/// por cuenta) son del servidor; aquí solo se enseñan.
class ControladorTienda extends Notifier<EstadoTienda> {
  /// Id de la compra que se intentó y no tuvo respuesta, por producto: si se
  /// reintenta, va con el mismo id y el servidor no cobra dos veces.
  final Map<String, String> _pendientes = {};
  bool _vivo = true;

  @override
  EstadoTienda build() {
    _vivo = true;
    ref.onDispose(() => _vivo = false);
    ref.listen<Sesion?>(sesionActualProvider, (_, sesion) {
      if (sesion != null) unawaited(Future.microtask(cargar));
    });
    return const EstadoTienda();
  }

  /// Lee los puntos, el catálogo y lo comprado.
  Future<void> cargar() async {
    final sesion = ref.read(sesionActualProvider);
    if (sesion == null || state.cargando) return;
    state = state.copiar(cargando: true, sinError: true);
    final api = ref.read(clienteApiProvider);
    try {
      final puntos = await api.leerPuntos(sesion.token);
      final productos = await api.leerTienda(sesion.token);
      final comprados = await api.leerComprados(sesion.token);
      if (!_vivo) return;
      state = state.copiar(
        cargando: false,
        puntos: puntos,
        productos: productos,
        comprados: comprados,
      );
    } on ErrorApi catch (e) {
      if (!_vivo) return;
      state = state.copiar(cargando: false, error: e.mensaje);
    }
  }

  DisponibilidadProducto disponibilidad(ProductoTienda p) {
    if (!p.disponible) return DisponibilidadProducto.proximamente;
    if (p.precio <= 0) return DisponibilidadProducto.gratis;
    if (state.comprados.contains(p.id)) return DisponibilidadProducto.comprado;
    if ((state.puntos?.puntos ?? 0) < p.precio) {
      return DisponibilidadProducto.faltanPuntos;
    }
    return DisponibilidadProducto.comprable;
  }

  /// Compra [p]. Devuelve null si ha ido bien o el motivo para enseñar.
  Future<String?> comprar(ProductoTienda p) async {
    final sesion = ref.read(sesionActualProvider);
    if (sesion == null) return 'Inicia sesión para comprar.';
    if (state.comprando != null) return 'Ya hay una compra en curso.';
    final compra = _pendientes[p.id] ??= nuevoIdPartida(ref.read(azarProvider));
    state = state.copiar(comprando: p.id);
    try {
      await ref
          .read(clienteApiProvider)
          .comprar(sesion.token, compra: compra, producto: p.id);
      _pendientes.remove(p.id);
      if (!_vivo) return null;
      state = state.copiar(sinComprando: true);
      // Se vuelven a leer el total, los niveles y lo comprado.
      await cargar();
      return null;
    } on ErrorApi catch (e) {
      // Sin respuesta, la compra pudo llegar: se reintenta con el mismo id.
      if (e.estado != null) _pendientes.remove(p.id);
      if (!_vivo) return e.mensaje;
      state = state.copiar(sinComprando: true);
      if (e.estado != null) unawaited(cargar());
      return e.mensaje;
    }
  }
}

final tiendaProvider =
    NotifierProvider<ControladorTienda, EstadoTienda>(ControladorTienda.new);
