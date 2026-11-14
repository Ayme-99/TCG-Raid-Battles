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
      tipo == TipoEfectoAtaque.paralizarDefensor ||
      tipo == TipoEfectoAtaque.autodanoSiKo;

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

  /// Número de la carta en el set (informativo).
  final int? numero;
  final int hp;
  final String? ataqueNombre;

  /// Daño del ataque; con [ataqueMonedas], daño por cada cara.
  final int? ataqueDano;

  /// Número de monedas del ataque («20×»). null: el daño es fijo.
  final int? ataqueMonedas;

  /// Efecto del ataque, tal como lo lee la mesa.
  final String? ataqueTexto;

  /// Daño extra con monedas («30+»): se tiran [ataqueBonusMonedas] monedas y,
  /// con al menos [ataqueBonusCaras] caras, se suman [ataqueBonusDano].
  final int? ataqueBonusMonedas;
  final int? ataqueBonusCaras;
  final int? ataqueBonusDano;

  /// Cada daño de los jugadores al aliado se evita con cara en una moneda.
  final bool evitaDanoConMoneda;

  /// Daño que el ataque también hace a los Pokémon de los jugadores
  /// adyacentes al objetivo (lo aplican los jugadores).
  final int? ataqueDanoAdyacentes;

  /// Daño extra si el Pokémon Defensor ya tenía un estado especial.
  final int? ataqueDanoExtraSiEstado;

  /// Daño que se suma al ataque por cada uso anterior (Envite Ígneo).
  final int? ataqueEscalaPorUso;

  /// El ataque exige una moneda del jugador rival (Fuerza Lunar).
  final bool ataqueMonedaRival;

  /// El daño del ataque no se ve afectado por ningún efecto en el Pokémon
  /// Defensor (Energía Pura, Allanamiento).
  final bool ataqueIgnoraEfectos;

  /// Lo que la mesa tiene que hacer cuando el aliado entra en juego.
  final String? avisoAlEntrar;

  /// Lo que la mesa tiene que hacer en cada Chequeo Pokémon mientras el
  /// aliado está en juego.
  final String? avisoChequeo;

  /// Regla que cada jugador tiene que recordar en su turno mientras el aliado
  /// está en juego (o, si su efecto es permanente, el resto de la partida).
  final String? avisoTurno;

  /// Recordatorio al derrotar al aliado con un ataque de los jugadores.
  final String? avisoAlCaer;

  /// Aura: recordatorio cuando cae cualquier aliado mientras este está en
  /// juego (Moflete Estático).
  final String? avisoAliadoCaido;
  final String? habilidadNombre;
  final String? habilidad;
  final EfectosAliado efectos;
  final String? scriptId;

  const AliadoCatalogo({
    required this.categoria,
    required this.nombre,
    required this.hp,
    this.numero,
    this.ataqueIgnoraEfectos = false,
    this.avisoAlEntrar,
    this.avisoChequeo,
    this.avisoTurno,
    this.ataqueNombre,
    this.ataqueDano,
    this.ataqueMonedas,
    this.ataqueTexto,
    this.ataqueBonusMonedas,
    this.ataqueBonusCaras,
    this.ataqueBonusDano,
    this.evitaDanoConMoneda = false,
    this.ataqueDanoAdyacentes,
    this.ataqueDanoExtraSiEstado,
    this.ataqueEscalaPorUso,
    this.ataqueMonedaRival = false,
    this.avisoAlCaer,
    this.avisoAliadoCaido,
    this.habilidadNombre,
    this.habilidad,
    this.efectos = EfectosAliado.jugador,
    this.scriptId,
  });

  /// Texto de la carta que se guarda en el evento y se enseña a la mesa:
  /// el efecto del ataque y/o la habilidad con su nombre.
  String? get textoParaLaMesa {
    final partes = [
      if (ataqueTexto != null) ataqueTexto!,
      if (habilidad != null)
        habilidadNombre == null ? habilidad! : '$habilidadNombre: $habilidad',
    ];
    return partes.isEmpty ? null : partes.join(' ');
  }
}

class InvocacionCatalogo {
  /// Cada cuántos HP perdidos el jefe vuelve a llamar a un aliado, después de
  /// la primera llamada (que sale al terminar su primer turno).
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

  /// Número de la carta en el set (informativo).
  final int? numero;

  /// Mapa o escenario del jefe (informativo).
  final String? mapa;
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
    this.mapa,
    this.numero,
    this.invocacion,
  });

  /// Cuántos aliados puede llamar a lo largo de la partida (T-69/T-71): su
  /// nivel más uno.
  int get intentosDeInvocacion => invocacion == null ? 0 : nivel + 1;

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
      mapa: m['mapa'] as String?,
      numero: m['numero'] == null ? null : _entero(m, 'numero', id),
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
        numero: am['numero'] == null ? null : _entero(am, 'numero', id),
        ataqueIgnoraEfectos: atm?['ignoraEfectos'] == true,
        avisoAlEntrar: am['avisoAlEntrar'] as String?,
        avisoChequeo: am['avisoChequeo'] as String?,
        avisoTurno: am['avisoTurno'] as String?,
        hp: _entero(am, 'hp', id),
        ataqueNombre: atm == null ? null : _texto(atm, 'nombre'),
        ataqueDano: atm == null ? null : _entero(atm, 'dano', id),
        ataqueMonedas:
            atm?['monedas'] == null ? null : _entero(atm!, 'monedas', id),
        ataqueTexto: atm?['texto'] as String?,
        ataqueBonusMonedas: _bonus(atm, 'monedas', id),
        ataqueBonusCaras: _bonus(atm, 'carasMinimas', id),
        ataqueBonusDano: _bonus(atm, 'dano', id),
        evitaDanoConMoneda: am['evitaDanoConMoneda'] == true,
        ataqueDanoAdyacentes: atm?['danoAdyacentes'] == null
            ? null
            : _entero(atm!, 'danoAdyacentes', id),
        ataqueDanoExtraSiEstado: atm?['danoExtraSiEstado'] == null
            ? null
            : _entero(atm!, 'danoExtraSiEstado', id),
        ataqueEscalaPorUso: atm?['escalaPorUso'] == null
            ? null
            : _entero(atm!, 'escalaPorUso', id),
        ataqueMonedaRival: atm?['monedaRival'] == true,
        avisoAlCaer: am['avisoAlCaer'] as String?,
        avisoAliadoCaido: am['avisoAliadoCaido'] as String?,
        habilidadNombre: am['habilidadNombre'] as String?,
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

  /// Aliado de la carta del catálogo del jefe [nombre] de ese [nivel] en la
  /// [categoria] dada. null si el jefe no viene del catálogo, no invoca o no
  /// tiene aliado en esa categoría.
  AliadoCatalogo? aliadoDe(String nombre, int nivel, CategoriaAliado categoria) =>
      invocacionDe(nombre, nivel)?.aliados[categoria];

  /// Invocación de la carta del catálogo del jefe [nombre] de ese [nivel].
  InvocacionCatalogo? invocacionDe(String nombre, int nivel) =>
      jefeDe(nombre, nivel)?.invocacion;

  /// Carta del catálogo del jefe [nombre] de ese [nivel], o null.
  JefeCatalogo? jefeDe(String nombre, int nivel) {
    for (final j in jefes) {
      if (j.nombre == nombre && j.nivel == nivel) return j;
    }
    return null;
  }

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

/// Campo de `ataque.bonusConMonedas`, o null si el ataque no lo tiene.
int? _bonus(Map<String, Object?>? ataque, String clave, String donde) {
  final b = ataque?['bonusConMonedas'];
  if (b == null) return null;
  return _entero(_mapa(b, '$donde bonusConMonedas'), clave, donde);
}

int _entero(Map<String, Object?> m, String clave, String donde) {
  final v = m[clave];
  if (v is int) return v;
  throw FormatException('$donde: «$clave» debe ser un número entero');
}
