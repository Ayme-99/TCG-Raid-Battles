import 'dart:convert';
import 'dart:math';

import '../almacen/almacen.dart';

/// Una partida terminada que espera a enviarse (o que el servidor rechazó).
class EnvioPendiente {
  const EnvioPendiente({
    required this.registro,
    this.intentos = 0,
    this.error,
  });

  factory EnvioPendiente.deJson(Map<String, Object?> json) => EnvioPendiente(
        registro: Map<String, Object?>.from(json['registro']! as Map),
        intentos: (json['intentos'] as int?) ?? 0,
        error: json['error'] as String?,
      );

  /// El registro del contrato, tal cual se enviará (con su `resumen`).
  final Map<String, Object?> registro;
  final int intentos;

  /// Motivo del rechazo, solo en las rechazadas.
  final String? error;

  String get partidaId => registro['partidaId']! as String;

  EnvioPendiente copiarCon({int? intentos, String? error}) => EnvioPendiente(
        registro: registro,
        intentos: intentos ?? this.intentos,
        error: error ?? this.error,
      );

  Map<String, Object?> toJson() => {
        'registro': registro,
        'intentos': intentos,
        if (error != null) 'error': error,
      };
}

/// Espera antes del reintento número [intentos] (1, 2, 3...): 30 s, 1 min,
/// 2 min, 4 min... con tope de 15 minutos.
Duration esperaTrasFallo(int intentos) {
  final n = intentos < 1 ? 1 : intentos;
  final segundos = 30 * pow(2, min(n - 1, 10)).toInt();
  return Duration(seconds: min(segundos, 15 * 60));
}

/// Cola de partidas por enviar, guardada en el dispositivo para que sobreviva
/// a cerrar la app. Las que el servidor rechaza se apartan en otra lista: no
/// se reintentan, pero tampoco se pierden.
class ColaEnvios {
  ColaEnvios(this._almacen);

  final Almacen _almacen;

  static const String _clavePendientes = 'envios_pendientes';
  static const String _claveRechazadas = 'envios_rechazadas';

  Future<List<EnvioPendiente>> pendientes() => _leer(_clavePendientes);

  Future<List<EnvioPendiente>> rechazadas() => _leer(_claveRechazadas);

  /// Añade una partida. Si ya está en la cola (pendiente o rechazada) no hace
  /// nada: una partida se encola una sola vez por `partidaId`.
  Future<void> encolar(Map<String, Object?> registro) async {
    final nuevo = EnvioPendiente(registro: registro);
    final pendientes = await this.pendientes();
    final rechazadas = await this.rechazadas();
    final yaEsta = [...pendientes, ...rechazadas]
        .any((e) => e.partidaId == nuevo.partidaId);
    if (yaEsta) return;
    await _escribir(_clavePendientes, [...pendientes, nuevo]);
  }

  /// La partida se ha guardado en el servidor: sale de la cola.
  Future<void> quitar(String partidaId) async {
    final pendientes = await this.pendientes();
    await _escribir(
      _clavePendientes,
      [for (final e in pendientes) if (e.partidaId != partidaId) e],
    );
  }

  /// Apunta un intento fallido y devuelve cuántos lleva la partida.
  Future<int> registrarFallo(String partidaId) async {
    final pendientes = await this.pendientes();
    var intentos = 0;
    final nuevas = <EnvioPendiente>[];
    for (final e in pendientes) {
      if (e.partidaId == partidaId) {
        final actualizado = e.copiarCon(intentos: e.intentos + 1);
        intentos = actualizado.intentos;
        nuevas.add(actualizado);
      } else {
        nuevas.add(e);
      }
    }
    await _escribir(_clavePendientes, nuevas);
    return intentos;
  }

  /// El servidor la rechaza: pasa de pendientes a rechazadas, con el motivo.
  Future<void> rechazar(String partidaId, String motivo) async {
    final pendientes = await this.pendientes();
    final rechazadas = await this.rechazadas();
    final envio = pendientes.where((e) => e.partidaId == partidaId);
    if (envio.isEmpty) return;
    await _escribir(
      _clavePendientes,
      [for (final e in pendientes) if (e.partidaId != partidaId) e],
    );
    await _escribir(
      _claveRechazadas,
      [...rechazadas, envio.first.copiarCon(error: motivo)],
    );
  }

  /// Olvida todas las rechazadas.
  Future<void> descartarRechazadas() => _almacen.borrar(_claveRechazadas);

  Future<List<EnvioPendiente>> _leer(String clave) async {
    final texto = await _almacen.leer(clave);
    if (texto == null) return const [];
    try {
      return [
        for (final e in jsonDecode(texto) as List)
          EnvioPendiente.deJson(Map<String, Object?>.from(e as Map)),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _escribir(String clave, List<EnvioPendiente> envios) =>
      _almacen.escribir(
        clave,
        jsonEncode([for (final e in envios) e.toJson()]),
      );
}
