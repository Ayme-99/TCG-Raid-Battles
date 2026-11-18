import 'dart:math';

import 'estado.dart';
import 'eventos.dart';
import 'mazo_ataques_jefe.dart';
import 'motor.dart';
import 'reglas.dart';
import 'scripts_aliado.dart';

/// Ataque de la carta de un jefe, con lo que hace falta para componer el
/// evento [AtaqueJefe] sin que nadie lo escriba (T-77, D-19 §D4).
final class AtaqueJefeDatos {
  final String nombre;

  /// Daño base por Pokémon.
  final int dano;

  /// Efecto del ataque, sin el resultado de la moneda (lo pone la función).
  final EfectoAtaque? efecto;

  /// El efecto lleva una moneda: cara lo activa.
  final bool efectoConMoneda;

  const AtaqueJefeDatos({
    required this.nombre,
    required this.dano,
    this.efecto,
    this.efectoConMoneda = false,
  });
}

/// Cómo calcula su daño el ataque de un aliado (D-13).
final class AtaqueAliadoDatos {
  /// Número de monedas de un ataque «20×»: el daño base se multiplica por las
  /// caras. null: daño fijo.
  final int? monedas;

  /// Daño extra con monedas («30+»): con al menos [bonusCaras] caras en
  /// [bonusMonedas] monedas se suman [bonusDano].
  final int? bonusMonedas;
  final int bonusCaras;
  final int bonusDano;

  /// Daño que se suma por cada uso anterior (Envite Ígneo).
  final int? escalaPorUso;

  /// Daño extra si el Defensor ya tenía una Condición Especial (Puño
  /// Dinámico). Lo dice la mesa (véase `alPreguntarMesa`).
  final int? danoExtraSiEstado;

  /// El rival lanza una moneda al recibir el ataque (Fuerza Lunar).
  final bool monedaRival;

  const AtaqueAliadoDatos({
    this.monedas,
    this.bonusMonedas,
    this.bonusCaras = 1,
    this.bonusDano = 0,
    this.escalaPorUso,
    this.danoExtraSiEstado,
    this.monedaRival = false,
  });
}

/// Carta de un aliado que el jefe puede invocar.
final class AliadoDatos {
  final CategoriaAliado categoria;
  final String nombre;
  final int hp;
  final String? ataqueNombre;
  final int? ataqueDano;
  final String? habilidad;
  final EfectosAliado efectos;
  final String? scriptId;

  /// Cómo se calcula el daño de su ataque, si ataca.
  final AtaqueAliadoDatos ataque;

  const AliadoDatos({
    required this.categoria,
    required this.nombre,
    required this.hp,
    this.ataqueNombre,
    this.ataqueDano,
    this.habilidad,
    this.efectos = EfectosAliado.jugador,
    this.scriptId,
    this.ataque = const AtaqueAliadoDatos(),
  });
}

/// Lo que el jefe sabe invocar.
final class InvocacionDatos {
  /// La llamada siempre sale (no hay moneda del jefe).
  final bool segura;

  /// Un aliado por categoría.
  final Map<CategoriaAliado, AliadoDatos> aliados;

  const InvocacionDatos({this.segura = false, required this.aliados});
}

/// Datos de la carta de un jefe que necesita [turnoJefeAutomatico].
final class DatosJefe {
  /// Los tres ataques, por ranura (índice 0 = ataque 1).
  final List<AtaqueJefeDatos> ataques;

  /// Aliados que invoca. null: el jefe no invoca.
  final InvocacionDatos? invocacion;

  const DatosJefe({required this.ataques, this.invocacion});
}

/// Pregunta que solo puede responder la mesa física (por ejemplo «¿se cumple
/// la condición del Castigo?»). La función pura no ve los Pokémon de los
/// jugadores: quien la llama decide. Por defecto la respuesta es «no».
typedef PreguntaMesa = bool Function(String pregunta);

/// Compone **todos los eventos del turno del jefe** a partir del estado, el
/// mazo de ataques y un generador de azar inyectado (T-77, D-19 §D4):
///
/// 1. Resuelve lo pendiente: llamadas de aliado y ataques de entrada.
/// 2. Roba cartas del [mazo] y registra cada ataque del jefe con su daño, su
///    efecto y las monedas (potenciadores incluidos), hasta que una carta no
///    diga «roba otra» o se llegue al máximo del nivel.
/// 3. Hace atacar a cada aliado que aún no lo haya hecho en este turno.
/// 4. Cierra con [FinTurnoJefe], con las monedas de las quemaduras.
/// 5. Resuelve lo que ese cierre deje pendiente (la llamada de aliado).
///
/// Es una función pura: no modifica [estado] y todo el azar sale de [azar] y
/// queda dentro de los eventos, así que reproducirlos da siempre lo mismo.
/// [estado] debe estar al **empezar** el turno del jefe.
///
/// Queda fuera lo que resuelve la mesa: los KO, el rebote de `autodanoSiKo` y
/// los efectos de los aliados con `efectos: jugador` (D-19 §D4).
List<Evento> turnoJefeAutomatico(
  EstadoPartida estado,
  MazoAtaquesJefe mazo,
  Random azar,
  DatosJefe datos, {
  PreguntaMesa alPreguntarMesa = _siempreNo,
  Map<String, ScriptAliado> scripts = scriptsAliado,
}) {
  if (estado.fase != Fase.turnoJefe) {
    throw StateError('el turno del jefe automático se pide en la fase '
        'turnoJefe, no en ${estado.fase.name}');
  }
  if (estado.ataquesJefeEnTurno != 0 ||
      estado.aliados.any((a) => a.atacoEnTurnoJefe)) {
    throw StateError('el turno del jefe ya ha empezado: pide los eventos al '
        'principio del turno');
  }
  final jefe = estado.jefe!;
  if (datos.ataques.length != ranurasAtaqueJefe) {
    throw ArgumentError.value(
      datos.ataques.length,
      'datos.ataques',
      'el jefe tiene $ranurasAtaqueJefe ataques',
    );
  }
  final eventos = <Evento>[];
  var s = estado;
  void emitir(Evento ev) {
    s = apply(s, ev, scripts: scripts);
    eventos.add(ev);
  }

  bool moneda() => azar.nextBool();

  AliadoDatos? cartaDe(AliadoEstado a) {
    final c = datos.invocacion?.aliados[a.categoria];
    return c != null && c.nombre == a.nombre ? c : null;
  }

  // Ataque de un aliado (al entrar o al cerrar el turno).
  void atacarConAliado(AliadoEstado a) {
    int? objetivo;
    if (s.jugadores[a.slot].eliminado) {
      final activos = [
        for (final j in s.jugadores)
          if (!j.eliminado) j.asiento,
      ];
      if (activos.isEmpty) return;
      objetivo = activos[azar.nextInt(activos.length)];
    }
    final blanco = objetivo ?? a.slot;
    // Contra un jugador KO el ataque falla: se registra sin daño ni tiradas.
    if (s.enKo(blanco)) {
      emitir(AtaqueAliado(slot: a.slot, dano: 0, objetivo: objetivo));
      return;
    }
    final c = cartaDe(a)?.ataque ?? const AtaqueAliadoDatos();
    var dano = a.ataqueDano ?? 0;
    if (c.monedas != null) {
      var caras = 0;
      for (var i = 0; i < c.monedas!; i++) {
        if (moneda()) caras++;
      }
      dano *= caras;
    }
    if (c.bonusMonedas != null) {
      var caras = 0;
      for (var i = 0; i < c.bonusMonedas!; i++) {
        if (moneda()) caras++;
      }
      if (caras >= c.bonusCaras) dano += c.bonusDano;
    }
    if (c.escalaPorUso != null) dano += c.escalaPorUso! * a.usos;
    if (c.danoExtraSiEstado != null &&
        alPreguntarMesa(
          '${a.ataqueNombre ?? a.nombre}: ¿el Pokémon Defensor ya tenía una '
          'Condición Especial?',
        )) {
      dano += c.danoExtraSiEstado!;
    }
    final rival = c.monedaRival ? moneda() : null;
    emitir(AtaqueAliado(
      slot: a.slot,
      dano: dano,
      objetivo: objetivo,
      moneda: rival,
    ));
  }

  // Intentos de invocación y ataques de entrada pendientes.
  void resolverPendientes() {
    while (!s.terminada) {
      if (s.entradasPendientes.isNotEmpty) {
        atacarConAliado(s.entradasPendientes.first);
        continue;
      }
      if (s.intentosInvocacionPendientes == 0) return;
      final inv = datos.invocacion;
      if (inv == null) {
        throw StateError('hay llamadas de aliado pendientes y el jefe no '
            'tiene datos de invocación');
      }
      if (!inv.segura && !moneda()) {
        emitir(const SinInvocacion());
        continue;
      }
      final slots = s.slotsLibres;
      final categorias = [
        for (final c in s.categoriasLibres)
          if (inv.aliados.containsKey(c)) c,
      ];
      if (slots.isEmpty || categorias.isEmpty) {
        emitir(const SinInvocacion());
        continue;
      }
      final slot = slots[azar.nextInt(slots.length)];
      final categoria = categorias[azar.nextInt(categorias.length)];
      final c = inv.aliados[categoria]!;
      emitir(AliadoInvocado(
        slot: slot,
        categoria: categoria,
        nombre: c.nombre,
        hp: c.hp,
        ataqueNombre: c.ataqueNombre,
        ataqueDano: c.ataqueDano,
        habilidad: c.habilidad,
        efectos: c.efectos,
        scriptId: c.scriptId,
        monedas: c.scriptId == 'deseo-100'
            ? [for (var i = 0; i < 10 + s.aliados.length; i++) moneda()]
            : null,
      ));
    }
  }

  // Un ataque del jefe, con la carta robada.
  void atacarConJefe(CartaAtaqueJefe carta) {
    final def = datos.ataques[carta.ranura - 1];
    final efecto = def.efecto;
    var dano = def.dano;
    if (efecto != null && efecto.valor != null) {
      if (efecto.tipo == TipoEfectoAtaque.danoPorAtaquePrevio) {
        dano += efecto.valor! * s.ataquesJefeEnTurno;
      } else if (efecto.tipo == TipoEfectoAtaque.danoExtraSi &&
          alPreguntarMesa('${def.nombre}: ¿se cumple la condición?')) {
        dano += efecto.valor!;
      }
    }
    // La moneda del efecto, antes que las de los potenciadores (D-14, D-16).
    final monedaEfecto = def.efectoConMoneda ? moneda() : null;
    for (final b in bonusAtaqueJefeActivos(s, scripts)) {
      if (!b.conMoneda || moneda()) dano += b.valor;
    }
    emitir(AtaqueJefe(
      ranura: carta.ranura,
      dano: dano,
      jugador: carta.jugador,
      alAzar: true,
      efecto: efecto == null
          ? null
          : EfectoAtaque(
              tipo: efecto.tipo,
              valor: efecto.valor,
              duracion: efecto.duracion,
              moneda: def.efectoConMoneda ? monedaEfecto : null,
            ),
    ));
  }

  resolverPendientes();

  // Ataques del jefe. Sin nadie a quien atacar (todos KO) fallan y no hay
  // carta que robar.
  final maximo = maxAtaquesJefePorTurno(jefe.nivel);
  while (!s.terminada && s.ataquesJefeEnTurno < maximo) {
    final objetivos = {
      for (final j in s.jugadores)
        if (!j.eliminado && !s.enKo(j.asiento)) j.asiento,
    };
    if (objetivos.isEmpty) break;
    final carta = mazo.robar(objetivos);
    atacarConJefe(carta);
    resolverPendientes();
    if (s.terminada) return eventos;
    if (!carta.robaOtra) break;
  }

  // Ataques de los aliados que aún no han atacado, por orden de slot.
  for (final slot in [for (final a in s.aliados) a.slot]..sort()) {
    final a = s.aliadoEn(slot);
    if (a != null && a.tieneAtaque && !a.atacoEnTurnoJefe) atacarConAliado(a);
    if (s.terminada) return eventos;
  }

  // Cierre: monedas de las quemaduras, primero la del jefe y luego las de los
  // aliados por orden de slot (D-12, D-17).
  final quemadosJefe = s.jefe!.quemado;
  final quemados = [
    for (final a in s.aliados)
      if (a.quemado) a.slot,
  ]..sort();
  emitir(FinTurnoJefe(
    monedaQuemadura: quemadosJefe ? moneda() : null,
    monedasQuemaduraAliados: quemados.isEmpty
        ? null
        : [for (final slot in quemados) MonedaQuemaduraAliado(slot: slot, cara: moneda())],
  ));
  if (!s.terminada) resolverPendientes();
  return eventos;
}

bool _siempreNo(String _) => false;
