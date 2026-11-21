import '../errores.dart';
import 'combate.dart';
import 'pokemon.dart';

/// Decide la acción de [bando] en el combate (D-20 §3.4).
///
/// Es la «máquina»: juega con las mismas reglas que el jugador y es
/// determinista (el mismo estado da siempre la misma acción). Sirve para el
/// rival de la campaña y para simular combates y equilibrar la energía.
///
/// Orden de decisión:
/// 1. Si cae su Pokémon activo, saca el relevo con mejor combinación de no ser
///    débil, daño que puede hacer y salud.
/// 2. Si puede dejar fuera de combate al rival, ataca con lo más barato que
///    lo logre.
/// 3. Si su activo es débil a un ataque del rival, o no llega a ningún ataque,
///    cambia a un relevo que sí le sirva.
/// 4. Si tiene un ataque que reduce el daño del rival (Gruñido) y compensa
///    (evita más daño en lo que le queda de vida que el que haría ahora
///    atacando), lo usa; nunca lo repite mientras siga activo el mismo rival.
/// 5. Si con la carga extra podría rematar al turno siguiente algo que hoy no
///    le llega, carga.
/// 6. Ataca: con el de más daño si la reserva está llena (la energía
///    sobrante se perdería) y, si no, con el de más daño por energía gastada.
/// 7. Si no llega a nada, carga.
AccionCombate decidirAccion(EstadoCombate estado, Bando bando) {
  if (estado.fase == FaseCombate.terminado) {
    throw const ReglaIncumplida('El combate ha terminado.');
  }
  if (estado.turno != bando) {
    throw const ReglaIncumplida('No es el turno de ese bando.');
  }
  final yo = estado.bando(bando);
  final rival = estado.bando(bando.otro);
  final objetivo = rival.pokemonActivo;
  final p = estado.parametros;

  if (estado.fase == FaseCombate.eligiendoActivo) {
    final i = _mejorRelevo(yo, objetivo, yo.energia, p, exigirAtaque: false);
    return ElegirSiguiente(bando, i ?? yo.relevos.first);
  }

  final activo = yo.pokemonActivo.especie;
  final ataque =
      _mejorAtaque(activo, yo.energia, objetivo, p, yo.danoReducido);
  final danoMio = ataque == null
      ? 0
      : danoDeAtaque(activo.ataques[ataque], objetivo.especie,
          reduccion: yo.danoReducido);
  if (ataque != null && danoMio >= objetivo.ps) {
    return Atacar(bando, ataque);
  }

  final debil = _esDebilContra(activo, objetivo.especie);
  if (debil || ataque == null) {
    if (activo.retirada <= yo.energia) {
      final relevo = _mejorRelevo(
        yo,
        objetivo,
        yo.energia - activo.retirada,
        p,
        exigirAtaque: true,
        exigirNoDebil: debil,
      );
      if (relevo != null) return Cambiar(bando, relevo);
    }
  }

  final reduccion = _ataqueDeReduccion(yo, rival, danoMio);
  if (reduccion != null) return Atacar(bando, reduccion);

  if (_remataCargando(activo, yo.energia, objetivo, p, yo.danoReducido)) {
    return Cargar(bando);
  }
  if (ataque != null) return Atacar(bando, ataque);
  return Cargar(bando);
}

/// ¿Hay un ataque que remata al [objetivo], hoy no le llega la energía y
/// cargando sí le llegará al turno siguiente?
bool _remataCargando(
  PokemonCampana atacante,
  int energia,
  PokemonEnCombate objetivo,
  ParametrosCombate p,
  int reduccion,
) {
  final total = energia + p.energiaPorTurno + p.energiaAlCargar;
  final siguiente = total > p.energiaMaxima ? p.energiaMaxima : total;
  return atacante.ataques.any((a) =>
      a.coste > energia &&
      a.coste <= siguiente &&
      danoDeAtaque(a, objetivo.especie, reduccion: reduccion) >= objetivo.ps);
}

/// Índice de un ataque que reduce el daño del rival y compensa usarlo ahora,
/// o null.
///
/// Compensa si lo que evita en los golpes que el rival necesita para
/// derribar al activo (cada golpe, como mucho lo que el efecto quita) supera
/// el daño que haría atacando ahora ([danoMio]). Si el rival ya tiene
/// aplicada una reducción igual o mayor, no sirve.
int? _ataqueDeReduccion(BandoCombate yo, BandoCombate rival, int danoMio) {
  final activo = yo.pokemonActivo;
  final actual = rival.danoReducido;
  var danoRival = 0;
  for (final a in rival.pokemonActivo.especie.ataques) {
    final d = danoDeAtaque(a, activo.especie, reduccion: actual);
    if (d > danoRival) danoRival = d;
  }
  if (danoRival <= 0) return null;
  final golpes = (activo.ps + danoRival - 1) ~/ danoRival;
  int? mejor;
  var mejorEvitado = 0;
  for (var i = 0; i < activo.especie.ataques.length; i++) {
    final a = activo.especie.ataques[i];
    final e = a.efecto;
    if (e is! ReduceDanoRival || a.coste > yo.energia) continue;
    final extra = e.valor - actual;
    if (extra <= 0) continue;
    final evitado = (danoRival < extra ? danoRival : extra) * golpes;
    if (evitado > danoMio && evitado > mejorEvitado) {
      mejor = i;
      mejorEvitado = evitado;
    }
  }
  return mejor;
}

/// ¿Tiene [rival] algún ataque con daño del tipo al que [mio] es débil?
bool _esDebilContra(PokemonCampana mio, PokemonCampana rival) {
  final d = mio.debilidad;
  if (d == null) return false;
  return rival.ataques.any((a) => a.tipo == d.tipo && a.dano > 0);
}

/// Índice del mejor ataque que llega con [energia] y hace daño al [objetivo],
/// o null si no hay ninguno.
int? _mejorAtaque(
  PokemonCampana atacante,
  int energia,
  PokemonEnCombate objetivo,
  ParametrosCombate p,
  int reduccion,
) {
  int? mejor;
  var mejorDano = 0;
  var mejorCoste = 1;
  var mejorMata = false;
  for (var i = 0; i < atacante.ataques.length; i++) {
    final a = atacante.ataques[i];
    if (a.coste > energia) continue;
    final dano = danoDeAtaque(a, objetivo.especie, reduccion: reduccion);
    if (dano <= 0) continue;
    final coste = a.coste < 1 ? 1 : a.coste;
    final mata = dano >= objetivo.ps;
    var mejora = false;
    if (mejor == null) {
      mejora = true;
    } else if (mata != mejorMata) {
      mejora = mata;
    } else if (mata) {
      // Entre los que rematan, el más barato.
      mejora = a.coste < atacante.ataques[mejor].coste;
    } else if (energia >= p.energiaMaxima) {
      // Reserva llena: lo que sobra se perdería, así que el de más daño.
      mejora = dano > mejorDano ||
          (dano == mejorDano && a.coste < atacante.ataques[mejor].coste);
    } else {
      // Daño por energía: dano / coste, comparado sin dividir.
      final izquierda = dano * mejorCoste;
      final derecha = mejorDano * coste;
      mejora = izquierda > derecha || (izquierda == derecha && dano > mejorDano);
    }
    if (mejora) {
      mejor = i;
      mejorDano = dano;
      mejorCoste = coste;
      mejorMata = mata;
    }
  }
  return mejor;
}

/// Mejor relevo para sacar al combate, o null si ninguno vale.
///
/// Puntúa primero no ser débil al rival, luego el daño que puede hacer con la
/// energía que le quedará y por último su salud; a igualdad, el de menor
/// posición.
int? _mejorRelevo(
  BandoCombate yo,
  PokemonEnCombate objetivo,
  int energia,
  ParametrosCombate p, {
  required bool exigirAtaque,
  bool exigirNoDebil = false,
}) {
  int? mejor;
  var mejorPuntos = -1;
  for (final i in yo.relevos) {
    final r = yo.equipo[i];
    final debil = _esDebilContra(r.especie, objetivo.especie);
    if (exigirNoDebil && debil) continue;
    // El relevo que sale no arrastra reducciones: llega sin ellas.
    final ataque = _mejorAtaque(r.especie, energia, objetivo, p, 0);
    if (exigirAtaque && ataque == null) continue;
    final dano = ataque == null
        ? 0
        : danoDeAtaque(r.especie.ataques[ataque], objetivo.especie);
    final puntos = (debil ? 0 : 100000000) + dano * 10000 + r.ps;
    if (puntos > mejorPuntos) {
      mejor = i;
      mejorPuntos = puntos;
    }
  }
  return mejor;
}
