import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../almacen/almacen.dart';
import '../partida/controlador_partida.dart';
import '../pantallas/carta.dart';

/// Clave bajo la que se guarda la Pokédex en el dispositivo.
const clavePokedex = 'pokedex';

/// Lo que se sabe de un jefe enfrentado.
class RegistroJefe {
  const RegistroJefe({this.enfrentado = 0, this.victorias = 0, this.ultima});

  /// Partidas terminadas contra él, con victoria o sin ella.
  final int enfrentado;
  final int victorias;

  /// Fecha de la última partida (UTC).
  final DateTime? ultima;

  bool get derrotado => victorias > 0;

  RegistroJefe sumar({required bool victoria, required DateTime cuando}) =>
      RegistroJefe(
        enfrentado: enfrentado + 1,
        victorias: victorias + (victoria ? 1 : 0),
        ultima: cuando,
      );

  Map<String, Object?> toJson() => {
        'enfrentado': enfrentado,
        'victorias': victorias,
        if (ultima != null) 'ultima': ultima!.toIso8601String(),
      };

  static RegistroJefe deJson(Map<String, Object?> m) => RegistroJefe(
        enfrentado: m['enfrentado'] as int,
        victorias: m['victorias'] as int,
        ultima: m['ultima'] == null
            ? null
            : DateTime.parse(m['ultima']! as String),
      );
}

/// Jefes y aliados que el jugador ya ha visto en este dispositivo. Las claves
/// son el id de carta del nombre (`idCarta`), así «Kingdra ex» y «Kingdra»
/// son el mismo.
class Pokedex {
  const Pokedex({
    this.jefes = const {},
    this.aliados = const {},
    this.aliadosVencidos = const {},
  });

  final Map<String, RegistroJefe> jefes;

  /// Aliados que han salido alguna vez.
  final Set<String> aliados;

  /// Aliados que han salido en una partida ganada (se ven a todo color; los
  /// que solo salieron en partidas perdidas, en gris).
  final Set<String> aliadosVencidos;

  RegistroJefe? jefe(String nombre) => jefes[idCarta(nombre)];

  bool aliadoVisto(String nombre) => aliados.contains(idCarta(nombre));

  bool aliadoVencido(String nombre) =>
      aliadosVencidos.contains(idCarta(nombre));

  /// Suma una partida terminada: el jefe y los aliados que llegaron a salir.
  Pokedex conPartida({
    required String jefe,
    required Iterable<String> aliadosVistos,
    required bool victoria,
    required DateTime cuando,
  }) {
    final id = idCarta(jefe);
    return Pokedex(
      jefes: {
        ...jefes,
        id: (jefes[id] ?? const RegistroJefe())
            .sumar(victoria: victoria, cuando: cuando),
      },
      aliados: {...aliados, for (final a in aliadosVistos) idCarta(a)},
      aliadosVencidos: {
        ...aliadosVencidos,
        if (victoria) for (final a in aliadosVistos) idCarta(a),
      },
    );
  }

  Map<String, Object?> toJson() => {
        'version': 1,
        'jefes': {for (final e in jefes.entries) e.key: e.value.toJson()},
        'aliados': aliados.toList()..sort(),
        'aliadosVencidos': aliadosVencidos.toList()..sort(),
      };

  /// Lee lo guardado; si no es válido devuelve una Pokédex vacía.
  static Pokedex deTexto(String? texto) {
    if (texto == null) return const Pokedex();
    try {
      final m = jsonDecode(texto) as Map<String, dynamic>;
      return Pokedex(
        jefes: {
          for (final e in (m['jefes'] as Map<String, dynamic>).entries)
            e.key: RegistroJefe.deJson(Map<String, Object?>.from(e.value as Map)),
        },
        aliados: {for (final a in m['aliados'] as List<dynamic>) a as String},
        aliadosVencidos: {
          for (final a in (m['aliadosVencidos'] as List<dynamic>? ?? []))
            a as String,
        },
      );
    } catch (_) {
      return const Pokedex();
    }
  }
}

/// Guarda en el dispositivo cada partida terminada: funciona sin sesión. Hay
/// que mantenerlo vivo desde la raíz de la app para que vea terminar partidas.
class ControladorPokedex extends Notifier<Pokedex> {
  late Future<void> _cargada;

  /// Partida ya apuntada, para que deshacer y volver a terminar no cuente dos
  /// veces la misma.
  String? _ultimaApuntada;

  @override
  Pokedex build() {
    _cargada = _cargar();
    ref.listen<EstadoPartida>(estadoProvider, (anterior, estado) {
      if (anterior != null && !anterior.terminada && estado.terminada) {
        unawaited(_apuntarPartida(estado));
      }
    });
    return const Pokedex();
  }

  Future<void> _cargar() async {
    try {
      final guardada =
          Pokedex.deTexto(await ref.read(almacenProvider).leer(clavePokedex));
      state = Pokedex(
        jefes: {...guardada.jefes, ...state.jefes},
        aliados: {...guardada.aliados, ...state.aliados},
        aliadosVencidos: {
          ...guardada.aliadosVencidos,
          ...state.aliadosVencidos,
        },
      );
    } catch (_) {}
  }

  Future<void> _apuntarPartida(EstadoPartida estado) async {
    final jefe = estado.jefe;
    if (jefe == null) return;
    final eventos = ref.read(partidaProvider).partida.eventos;
    final marca = '${jefe.nombre}/${eventos.length}';
    if (marca == _ultimaApuntada) return;
    _ultimaApuntada = marca;
    await _cargada;
    state = state.conPartida(
      jefe: jefe.nombre,
      aliadosVistos: [
        for (final e in eventos)
          if (e is AliadoInvocado) e.nombre,
      ],
      victoria: estado.resultado == Resultado.victoria,
      cuando: ref.read(relojProvider)().toUtc(),
    );
    try {
      await ref
          .read(almacenProvider)
          .escribir(clavePokedex, jsonEncode(state.toJson()));
    } catch (_) {}
  }
}

final pokedexProvider =
    NotifierProvider<ControladorPokedex, Pokedex>(ControladorPokedex.new);
