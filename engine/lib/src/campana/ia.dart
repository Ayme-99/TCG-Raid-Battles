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
/// 4. Si con la carga extra podría rematar al turno siguiente algo que hoy no
///    le llega, carga.
/// 5. Ataca: con el de más daño si la reserva está llena (la energía
///    sobrante se perdería) y, si no, con el de más daño por energía gastada.
/// 6. Si no llega a nada, carga.
AccionCombate decidirAccion(EstadoCombate estado, Bando bando) {
  if (estado.fase == FaseCombate.terminado) {
    throw const ReglaIncumplida('El combate ha terminado.');
  }
  if (estado.turno != bando) {
    throw const ReglaIncumplida('No es el turno de ese bando.');
  }
  final yo = estado.bando(bando);
  final objetivo = estado.bando(bando.otro).pokemonActivo;
  final p = estado.parametros;

  if (estado.fase == FaseCombate.eligiendoActivo) {
    final i = _mejorRelevo(yo, objetivo, yo.energia, p, exigirAtaque: false);
    return ElegirSiguiente(bando, i ?? yo.relevos.first);
  }

  final activo = yo.pokemonActivo.especie;
  final ataque = _mejorAtaque(activo, yo.energia, objetivo, p);
  if (ataque != null &&
      danoDeAtaque(activo.ataques[ataque], objetivo.especie) >= objetivo.ps) {
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

  if (_remataCargando(activo, yo.energia, objetivo, p)) return Cargar(bando);
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
) {
  final total = energia + p.energiaPorTurno + p.energiaAlCargar;
  final siguiente = total > p.energiaMaxima ? p.energiaMaxima : total;
  return atacante.ataques.any((a) =>
      a.coste > energia &&
      a.coste <= siguiente &&
      danoDeAtaque(a, objetivo.especie) >= objetivo.ps);
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
) {
  int? mejor;
  var mejorDano = 0;
  var mejorCoste = 1;
  var mejorMata = false;
  for (var i = 0; i < atacante.ataques.length; i++) {
    final a = atacante.ataques[i];
    if (a.coste > energia) continue;
    final dano = danoDeAtaque(a, objetivo.especie);
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
    final ataque = _mejorAtaque(r.especie, energia, objetivo, p);
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
