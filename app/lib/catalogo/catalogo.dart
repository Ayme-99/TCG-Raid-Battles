import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

/// Catálogo de jefes (T-13, `catalog/`). Va empaquetado dentro de la app:
/// un jefe nuevo exige publicar una versión nueva. Los esquemas JSON y el CI
/// validan los archivos; aquí solo se leen y se rechaza lo que no tenga forma.

/// Efecto de un ataque del jefe (D-14). [texto] es lo que lee la mesa.
class EfectoAtaqueCatalogo {
  final TipoEfectoAtaque tipo;
  final int? valor;
  final int? duracion;

  /// El ataque lanza una moneda y la lanza la app.
  final bool conMoneda;
  final String texto;

  const EfectoAtaqueCatalogo({
    required this.tipo,
    required this.texto,
    this.valor,
    this.duracion,
    this.conMoneda = false,
  });

  /// El efecto tal como se registra en el evento [AtaqueJefe].
  /// [moneda] es el resultado de la moneda, si el ataque la lleva.
  EfectoAtaque comoEfecto({bool? moneda}) => EfectoAtaque(
        tipo: tipo,
        valor: valor,
        duracion: duracion,
        moneda: conMoneda ? moneda : null,
      );

  /// El efecto necesita saber qué jugador defiende.
  bool get necesitaDefensor =>
      tipo == TipoEfectoAtaque.sinRetirada ||
      tipo == TipoEfectoAtaque.sinAtaque ||
      tipo == TipoEfectoAtaque.paralizarDefensor;

  factory EfectoAtaqueCatalogo.deJson(Map<String, Object?> m, String id) {
    final nombreTipo = _texto(m, 'tipo');
    final tipo = TipoEfectoAtaque.values.where((t) => t.name == nombreTipo);
    if (tipo.isEmpty) {
      throw FormatException('$id: efecto de ataque desconocido «$nombreTipo»');
    }
    return EfectoAtaqueCatalogo(
      tipo: tipo.first,
      texto: _texto(m, 'texto'),
      valor: m['valor'] == null ? null : _entero(m, 'valor', id),
      duracion: m['duracion'] == null ? null : _entero(m, 'duracion', id),
      conMoneda: m['conMoneda'] == true,
    );
  }
}

class AtaqueJefeCatalogo {
  final String nombre;
  final int dano;
  final EfectoAtaqueCatalogo? efecto;

  const AtaqueJefeCatalogo({
    required this.nombre,
    required this.dano,
    this.efecto,
  });

  /// Daño que se propone a la mesa al registrar el ataque: el base y, si el
  /// ataque suma daño por cada ataque anterior del turno (Danza Espada), lo
  /// que corresponde a [ataquesPrevios]. El «+» condicionado a la mesa
  /// (Castigo) lo añaden los jugadores.
  int danoPropuesto(int ataquesPrevios) {
    final e = efecto;
    if (e != null && e.tipo == TipoEfectoAtaque.danoPorAtaquePrevio) {
      return dano + (e.valor ?? 0) * ataquesPrevios;
    }
    return dano;
  }
}

class AliadoCatalogo {
  final CategoriaAliado categoria;
  final String nombre;
  final int hp;
  final String? ataqueNombre;
  final int? ataqueDano;
  final String? habilidad;
  final EfectosAliado efectos;
  final String? scriptId;

  const AliadoCatalogo({
    required this.categoria,
    required this.nombre,
    required this.hp,
    this.ataqueNombre,
    this.ataqueDano,
    this.habilidad,
    this.efectos = EfectosAliado.jugador,
    this.scriptId,
  });
}

class InvocacionCatalogo {
  /// Cada cuántos HP perdidos hay un intento de invocación.
  final int cadaHp;

  /// `true`: sin moneda, cada intento invoca si hay slot libre.
  final bool segura;

  /// Un aliado por categoría (D-13).
  final Map<CategoriaAliado, AliadoCatalogo> aliados;

  const InvocacionCatalogo({
    required this.cadaHp,
    required this.segura,
    required this.aliados,
  });
}

class JefeCatalogo {
  final String id;
  final String nombre;
  final int nivel;
  final int hp;
  final List<AtaqueJefeCatalogo> ataques;

  /// null: el jefe nunca invoca.
  final InvocacionCatalogo? invocacion;

  const JefeCatalogo({
    required this.id,
    required this.nombre,
    required this.nivel,
    required this.hp,
    required this.ataques,
    this.invocacion,
  });

  /// Cuántos umbrales de invocación tiene a lo largo de la partida: el golpe
  /// que lo deja a 0 HP no da ninguno.
  int get intentosDeInvocacion {
    final inv = invocacion;
    if (inv == null) return 0;
    return (hp + inv.cadaHp - 1) ~/ inv.cadaHp - 1;
  }

  factory JefeCatalogo.deJson(Object? json) {
    final m = _mapa(json, 'jefe');
    final id = _texto(m, 'id');
    final ataques = _lista(m, 'ataques', id);
    if (ataques.length != 3) {
      throw FormatException('$id: un jefe tiene exactamente 3 ataques');
    }
    final inv = m['invocacion'];
    return JefeCatalogo(
      id: id,
      nombre: _texto(m, 'nombre'),
      nivel: _entero(m, 'nivel', id),
      hp: _entero(m, 'hp', id),
      ataques: [
        for (final a in ataques)
          _ataque(_mapa(a, '$id ataque'), id),
      ],
      invocacion: inv == null ? null : _invocacion(_mapa(inv, '$id invocacion'), id),
    );
  }

  static AtaqueJefeCatalogo _ataque(Map<String, Object?> m, String id) {
    final efecto = m['efecto'];
    return AtaqueJefeCatalogo(
      nombre: _texto(m, 'nombre'),
      dano: _entero(m, 'dano', id),
      efecto: efecto == null
          ? null
          : EfectoAtaqueCatalogo.deJson(_mapa(efecto, '$id efecto'), id),
    );
  }

  static InvocacionCatalogo _invocacion(Map<String, Object?> m, String id) {
    final aliados = _mapa(m['aliados'], '$id aliados');
    final resultado = <CategoriaAliado, AliadoCatalogo>{};
    for (final categoria in CategoriaAliado.values) {
      final a = aliados[categoria.name];
      if (a == null) {
        throw FormatException('$id: falta el aliado de ${categoria.name}');
      }
      final am = _mapa(a, '$id ${categoria.name}');
      final ataque = am['ataque'];
      final atm = ataque == null ? null : _mapa(ataque, '$id ataque aliado');
      resultado[categoria] = AliadoCatalogo(
        categoria: categoria,
        nombre: _texto(am, 'nombre'),
        hp: _entero(am, 'hp', id),
        ataqueNombre: atm == null ? null : _texto(atm, 'nombre'),
        ataqueDano: atm == null ? null : _entero(atm, 'dano', id),
        habilidad: am['habilidad'] as String?,
        efectos: am['efectos'] == 'programa'
            ? EfectosAliado.programa
            : EfectosAliado.jugador,
        scriptId: am['scriptId'] as String?,
      );
    }
    return InvocacionCatalogo(
      cadaHp: _entero(m, 'cadaHp', id),
      segura: m['tirada'] == 'segura',
      aliados: resultado,
    );
  }
}

class Catalogo {
  final int version;
  final List<JefeCatalogo> jefes;

  const Catalogo({required this.version, required this.jefes});

  static const vacio = Catalogo(version: 0, jefes: []);

  /// Jefes de un nivel, en el orden del índice.
  List<JefeCatalogo> delNivel(int nivel) =>
      [for (final j in jefes) if (j.nivel == nivel) j];

  static const _raiz = 'assets/catalogo';

  /// Lee el índice y cada jefe que lista. Lanza [FormatException] si algo no
  /// tiene la forma esperada.
  static Future<Catalogo> cargar(AssetBundle bundle) async {
    final indice = _mapa(
      jsonDecode(await bundle.loadString('$_raiz/catalogo.json')),
      'catalogo',
    );
    final ids = _lista(indice, 'jefes', 'catalogo');
    final jefes = <JefeCatalogo>[];
    for (final id in ids) {
      final jefe = JefeCatalogo.deJson(
        jsonDecode(await bundle.loadString('$_raiz/bosses/$id.json')),
      );
      if (jefe.id != id) {
        throw FormatException('$id: el id del archivo no coincide');
      }
      jefes.add(jefe);
    }
    return Catalogo(version: _entero(indice, 'version', 'catalogo'), jefes: jefes);
  }
}

/// Catálogo empaquetado. Si no se puede leer, la app sigue funcionando con la
/// entrada manual del jefe.
final catalogoProvider = FutureProvider<Catalogo>((ref) async {
  try {
    return await Catalogo.cargar(rootBundle);
  } on Object {
    return Catalogo.vacio;
  }
});

Map<String, Object?> _mapa(Object? v, String donde) {
  if (v is Map<String, Object?>) return v;
  if (v is Map) return Map<String, Object?>.from(v);
  throw FormatException('$donde: se esperaba un objeto');
}

List<Object?> _lista(Map<String, Object?> m, String clave, String donde) {
  final v = m[clave];
  if (v is List) return List<Object?>.from(v);
  throw FormatException('$donde: «$clave» debe ser una lista');
}

String _texto(Map<String, Object?> m, String clave) {
  final v = m[clave];
  if (v is String && v.isNotEmpty) return v;
  throw FormatException('falta el texto «$clave»');
}

int _entero(Map<String, Object?> m, String clave, String donde) {
  final v = m[clave];
  if (v is int) return v;
  throw FormatException('$donde: «$clave» debe ser un número entero');
}
