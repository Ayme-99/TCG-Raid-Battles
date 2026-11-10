import 'dart:convert';

import 'package:incursiones_engine/incursiones_engine.dart';

import '../almacen/almacen.dart';

/// Clave bajo la que se guarda la partida en curso.
const claveEnCurso = 'partida_en_curso';

/// Una partida recuperada del almacén: los eventos ya reproducidos y la
/// identidad con la que se enviaría al servidor.
class PartidaGuardada {
  const PartidaGuardada({
    required this.historial,
    this.partidaId,
    this.creadaEn,
  });

  final Historial historial;
  final String? partidaId;
  final String? creadaEn;
}

/// Lee la partida en curso. Si no hay ninguna, o lo guardado ya no es válido
/// (otra versión de la app, datos dañados), la descarta y devuelve `null`.
Future<PartidaGuardada?> leerPartidaEnCurso(Almacen almacen) async {
  final texto = await almacen.leer(claveEnCurso);
  if (texto == null) return null;
  try {
    final json = jsonDecode(texto) as Map<String, dynamic>;
    final eventos = [
      for (final e in json['eventos'] as List<dynamic>) eventoDeJson(e),
    ];
    return PartidaGuardada(
      historial: Historial.de(Partida.desdeEventos(eventos)),
      partidaId: json['partidaId'] as String?,
      creadaEn: json['creadaEn'] as String?,
    );
  } catch (_) {
    await almacen.borrar(claveEnCurso);
    return null;
  }
}

/// Guarda la partida en curso; sin eventos no hay nada que recuperar y se
/// borra lo que hubiera.
Future<void> guardarPartidaEnCurso(
  Almacen almacen, {
  required List<Evento> eventos,
  String? partidaId,
  String? creadaEn,
}) {
  if (eventos.isEmpty) return almacen.borrar(claveEnCurso);
  return almacen.escribir(
    claveEnCurso,
    jsonEncode({
      if (partidaId != null) 'partidaId': partidaId,
      if (creadaEn != null) 'creadaEn': creadaEn,
      'eventos': [for (final e in eventos) eventoAJson(e)],
    }),
  );
}
