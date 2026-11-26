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
///    Si está Paralizado (Dragoaliento), carga: no puede atacar ni cambiar
///    (salvo curarse con una Poción, como en el paso 2 bis, o salir con una
///    Cuerda Huida si el paso 3 querría cambiar).
/// 2. Si puede dejar fuera de combate al rival, ataca con lo más barato que
///    lo logre.
/// 2 bis. Pociones (D-20 §3.2, #458; no gastan turno): si el rival puede
///    derribar a su activo en su próximo turno (con su golpe más fuerte que
///    pueda pagar, más el veneno de los dos chequeos) y con los PS máximos
///    sobreviviría, usa una Poción con el activo. Como no gasta turno, la
///    siguiente llamada vuelve a decidir (otra Poción o la acción del turno).
///    El rival no usa objetos mientras [ParametrosCombate.rivalUsaObjetos]
///    sea false (propuesta de Diseño por confirmar).
/// 3. Si su activo es débil a un ataque del rival, o no llega a ningún ataque,
///    cambia a un relevo que sí le sirva (nunca al jefe que espera a que caiga
///    su aliado).
///    Cuerda Huida (D-20 §10.6, #468; gasta el turno, no paga la retirada):
///    solo si cambiando no hay relevo que le sirva (no le llega la energía de
///    la retirada o le deja sin ataque) y con toda su energía sí lo hay. Así
///    no gasta un objeto de 550 en lo que un cambio normal ya resuelve.
/// 4. Si tiene un ataque que reduce el daño del rival (Gruñido) y compensa
///    (evita más daño en lo que le queda de vida que el que haría ahora
///    atacando), lo usa; nunca lo repite mientras siga activo el mismo rival.
/// 5. Si tiene un ataque que hace que el rival reciba más daño (Látigo) y lo
///    derriba en menos golpes contando el turno que gasta, lo usa.
///    Si tiene un ataque que envenena al rival y este no lo está ya, lo usa
///    (antes que Gruñido y compañía: el veneno cuenta aunque el golpe quede
///    en 0).
///    Si tiene un ataque que reduce el daño que recibe su activo (Fortaleza) y
///    compensa igual que Gruñido, lo usa.
///    Si tiene un ataque que quita energía al rival (Disparo Demora) y con ello
///    el rival deja de poder dar un golpe mayor que el suyo, lo usa.
/// 6. Si con la carga extra podría rematar al turno siguiente algo que hoy no
///    le llega, carga.
/// 7. Ataca: con el de más daño si la reserva está llena (la energía
///    sobrante se perdería) y, si no, con el de más daño por energía gastada.
/// 8. Si no llega a nada, carga.
///
/// Cuando le toca cargar (pasos 6 y 8), si tiene un ataque que da energía a
/// su bando (Pulimento) lo usa en su lugar, siempre que la reserva no esté
/// llena, le falte energía para algún ataque suyo y acabe con al menos la
/// misma energía que cargando.
AccionCombate decidirAccion(EstadoCombate estado, Bando bando) {
  if (estado.fase == FaseCombate.terminado) {
    throw const ReglaIncumplida('El combate ha terminado.');
  }
  if (estado.fase == FaseCombate.eligiendoActivo) {
    if (!estado.debenElegir.contains(bando)) {
      throw const ReglaIncumplida('Ese bando no tiene que elegir Pokémon.');
    }
  } else if (estado.turno != bando) {
    throw const ReglaIncumplida('No es el turno de ese bando.');
  }
  final yo = estado.bando(bando);
  final rival = estado.bando(bando.otro);
  final objetivo = rival.pokemonActivo;
  final p = estado.parametros;

  if (estado.fase == FaseCombate.eligiendoActivo) {
    final i = _mejorRelevo(yo, objetivo, yo.energia, p,
        exigirAtaque: false, extra: rival.extraRecibido);
    return ElegirSiguiente(bando, i ?? yo.relevos.first);
  }

  final pocion = _pocionQueSalva(estado, bando);

  final activo = _conRacha(yo);
  final ataque = _mejorAtaque(
      activo, yo.energia, objetivo, p, yo.danoReducido, rival.extraRecibido);
  final danoMio = ataque == null
      ? 0
      : danoDeAtaque(activo.ataques[ataque], objetivo.especie,
          reduccion: yo.danoReducido, extra: rival.extraRecibido);
  final debil = _esDebilContra(activo, objetivo.especie);

  // Relevo para salir con una Cuerda Huida (paso 3), o null.
  UsarCuerdaHuida? cuerda() {
    final candidatos = objetivosDeCuerda(estado, bando);
    if (candidatos.isEmpty) return null;
    final relevo = _mejorRelevo(yo, objetivo, yo.energia, p,
        exigirAtaque: true,
        exigirNoDebil: debil,
        extra: rival.extraRecibido,
        candidatos: candidatos);
    return relevo == null ? null : UsarCuerdaHuida(bando, relevo);
  }

  // Paralizado (Dragoaliento): este turno no puede atacar ni cambiar.
  if (yo.paralizado) {
    if (pocion != null) return pocion;
    return (debil || ataque == null ? cuerda() : null) ?? Cargar(bando);
  }

  if (ataque != null && danoMio >= objetivo.ps) {
    return Atacar(bando, ataque);
  }
  if (pocion != null) return pocion;

  if (debil || ataque == null) {
    if (activo.retirada <= yo.energia) {
      final relevo = _mejorRelevo(
        yo,
        objetivo,
        yo.energia - activo.retirada,
        p,
        exigirAtaque: true,
        exigirNoDebil: debil,
        extra: rival.extraRecibido,
        candidatos: yo.cambiables,
      );
      if (relevo != null) return Cambiar(bando, relevo);
    }
    final c = cuerda();
    if (c != null) return c;
  }

  final veneno = _ataqueDeVeneno(yo, rival);
  if (veneno != null) return Atacar(bando, veneno);

  final reduccion = _ataqueDeReduccion(yo, rival, danoMio);
  if (reduccion != null) return Atacar(bando, reduccion);

  final proteccion = _ataqueDeProteccion(yo, rival, danoMio);
  if (proteccion != null) return Atacar(bando, proteccion);

  final masDano = _ataqueDeDanoExtra(yo, rival, danoMio);
  if (masDano != null) return Atacar(bando, masDano);

  final sinEnergia = _ataqueDeQuitaEnergia(yo, rival, danoMio);
  if (sinEnergia != null) return Atacar(bando, sinEnergia);

  if (_remataCargando(
      activo, yo.energia, objetivo, p, yo.danoReducido, rival.extraRecibido)) {
    return _cargarOGanar(yo, bando, p);
  }
  if (ataque != null) return Atacar(bando, ataque);
  return _cargarOGanar(yo, bando, p);
}

/// Una Poción para el activo de [bando] si el rival lo derribaría en su
/// próximo turno y, curado del todo, aguantaría (paso 2 bis); si no, null.
UsarPocion? _pocionQueSalva(EstadoCombate estado, Bando bando) {
  final yo = estado.bando(bando);
  if (!objetivosDePocion(estado, bando).contains(yo.activo)) return null;
  final rival = estado.bando(bando.otro);
  final activo = yo.pokemonActivo;
  final atacante = _conRacha(rival);
  var amenaza = 0;
  for (final a in atacante.ataques) {
    if (a.coste > rival.energia) continue;
    final d = danoDeAtaque(a, activo.especie,
        reduccion: rival.danoReducido, extra: yo.extraRecibido);
    if (d > amenaza) amenaza = d;
  }
  // El veneno de los dos chequeos (nada con Muro Mágico).
  if (!sinDanoIndirecto(activo.especie)) amenaza += 2 * yo.veneno;
  if (amenaza <= 0 || activo.ps > amenaza) return null;
  if (activo.especie.ps <= amenaza) return null;
  return UsarPocion(bando, yo.activo);
}

/// Carga, o usa en su lugar un ataque que da energía a su bando (Pulimento)
/// si le sale igual o mejor.
AccionCombate _cargarOGanar(BandoCombate yo, Bando bando, ParametrosCombate p) {
  final gana = _ataqueDeGanaEnergia(yo, p);
  return gana == null ? Cargar(bando) : Atacar(bando, gana);
}

/// Índice de un ataque que da energía al propio bando (Pulimento) y compensa
/// usarlo en vez de cargar, o null.
///
/// Solo sirve si la reserva no está llena y al activo le falta energía para
/// alguno de sus ataques (normalmente el grande). Compensa si, pagado el coste
/// y sumado el efecto (con tope), la reserva queda igual o mejor que cargando.
/// Entre varios, el que más energía deja.
int? _ataqueDeGanaEnergia(BandoCombate yo, ParametrosCombate p) {
  final energia = yo.energia;
  if (energia >= p.energiaMaxima) return null;
  final ataques = yo.pokemonActivo.especie.ataques;
  if (!ataques.any((a) => a.coste > energia)) return null;
  int tope(int e) => e > p.energiaMaxima ? p.energiaMaxima : e;
  var mejorEnergia = tope(energia + p.energiaAlCargar);
  int? mejor;
  for (var i = 0; i < ataques.length; i++) {
    final a = ataques[i];
    final e = a.efecto;
    if (e is! GanaEnergia || a.coste > energia) continue;
    final tras = tope(energia - a.coste + e.valor);
    if (tras >= mejorEnergia && (mejor == null || tras > mejorEnergia)) {
      mejor = i;
      mejorEnergia = tras;
    }
  }
  return mejor;
}

/// ¿Hay un ataque que remata al [objetivo], hoy no le llega la energía y
/// cargando sí le llegará al turno siguiente?
bool _remataCargando(
  PokemonCampana atacante,
  int energia,
  PokemonEnCombate objetivo,
  ParametrosCombate p,
  int reduccion,
  int extra,
) {
  final total = energia + p.energiaPorTurno + p.energiaAlCargar;
  final siguiente = total > p.energiaMaxima ? p.energiaMaxima : total;
  return atacante.ataques.any((a) =>
      a.coste > energia &&
      a.coste <= siguiente &&
      danoDeAtaque(a, objetivo.especie, reduccion: reduccion, extra: extra) >=
          objetivo.ps);
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
    final d = danoDeAtaque(a, activo.especie,
        reduccion: actual, extra: yo.extraRecibido);
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

/// Índice de un ataque que envenena al activo rival (Picotazo Veneno), o null.
///
/// Nunca contra un rival con Muro Mágico ([SinDanoIndirecto]). Si no, siempre
/// compensa mientras el rival no esté envenenado (o lo esté con menos
/// daño): el veneno quita PS en cada chequeo aunque el golpe quede en 0 por
/// Fortaleza o Gruñido. No se repite mientras siga envenenado.
int? _ataqueDeVeneno(BandoCombate yo, BandoCombate rival) {
  // Muro Mágico: el veneno no le quita PS, así que no compensa.
  if (sinDanoIndirecto(rival.pokemonActivo.especie)) return null;
  final ataques = yo.pokemonActivo.especie.ataques;
  int? mejor;
  var mejorValor = rival.veneno;
  for (var i = 0; i < ataques.length; i++) {
    final a = ataques[i];
    final e = a.efecto;
    if (e is! EnvenenaDefensor || a.coste > yo.energia) continue;
    if (e.valor > mejorValor) {
      mejor = i;
      mejorValor = e.valor;
    }
  }
  return mejor;
}

/// Índice de un ataque que reduce el daño que recibe el propio activo
/// (Fortaleza) y compensa usarlo ahora, o null. Mismo criterio que
/// [_ataqueDeReduccion]: evita más daño, en los golpes que el rival necesita
/// para derribarlo, que el que haría atacando. No sirve si ya tiene una
/// protección igual o mayor.
int? _ataqueDeProteccion(BandoCombate yo, BandoCombate rival, int danoMio) {
  final activo = yo.pokemonActivo;
  final actual = yo.proteccion;
  var danoRival = 0;
  for (final a in rival.pokemonActivo.especie.ataques) {
    final d = danoDeAtaque(a, activo.especie,
        reduccion: rival.danoReducido, extra: yo.extraRecibido);
    if (d > danoRival) danoRival = d;
  }
  if (danoRival <= 0) return null;
  final golpes = (activo.ps + danoRival - 1) ~/ danoRival;
  int? mejor;
  var mejorEvitado = 0;
  for (var i = 0; i < activo.especie.ataques.length; i++) {
    final a = activo.especie.ataques[i];
    final e = a.efecto;
    if (e is! ReduceDanoPropio || a.coste > yo.energia) continue;
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

/// Índice de un ataque que hace que el rival reciba más daño (Látigo) y
/// compensa usarlo ahora, o null.
///
/// Compensa si, contando el turno que se gasta en usarlo, el rival cae en
/// menos golpes que sin él. Si el rival ya tiene aplicado un extra igual o
/// mayor, no sirve.
int? _ataqueDeDanoExtra(BandoCombate yo, BandoCombate rival, int danoMio) {
  if (danoMio <= 0) return null;
  final objetivo = rival.pokemonActivo;
  final actual = rival.danoExtra;
  var mejorGolpes = (objetivo.ps + danoMio - 1) ~/ danoMio;
  int? mejor;
  final ataques = yo.pokemonActivo.especie.ataques;
  for (var i = 0; i < ataques.length; i++) {
    final a = ataques[i];
    final e = a.efecto;
    if (e is! AumentaDanoRecibido || a.coste > yo.energia) continue;
    if (e.valor <= actual) continue;
    final nuevo = danoMio + (e.valor - actual);
    final golpes = 1 + (objetivo.ps + nuevo - 1) ~/ nuevo;
    if (golpes < mejorGolpes) {
      mejor = i;
      mejorGolpes = golpes;
    }
  }
  return mejor;
}

/// Índice de un ataque que quita energía al rival (Disparo Demora) y compensa
/// usarlo ahora, o null.
///
/// Compensa si el mejor golpe que el rival puede dar en su turno baja (por no
/// llegarle ya la energía a un ataque) en más de lo que yo haría atacando.
int? _ataqueDeQuitaEnergia(BandoCombate yo, BandoCombate rival, int danoMio) {
  final activo = yo.pokemonActivo;
  int mejorGolpe(int energia) {
    var mejor = 0;
    for (final a in rival.pokemonActivo.especie.ataques) {
      if (a.coste > energia) continue;
      final d = danoDeAtaque(a, activo.especie,
          reduccion: rival.danoReducido, extra: yo.extraRecibido);
      if (d > mejor) mejor = d;
    }
    return mejor;
  }

  final ahora = mejorGolpe(rival.energia);
  int? mejor;
  var mejorEvitado = 0;
  final ataques = activo.especie.ataques;
  for (var i = 0; i < ataques.length; i++) {
    final a = ataques[i];
    final e = a.efecto;
    if (e is! QuitaEnergiaRival || a.coste > yo.energia) continue;
    final resto = rival.energia - e.valor;
    final evitado = ahora - mejorGolpe(resto < 0 ? 0 : resto);
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
  int extra,
) {
  int? mejor;
  var mejorDano = 0;
  var mejorCoste = 1;
  var mejorMata = false;
  for (var i = 0; i < atacante.ataques.length; i++) {
    final a = atacante.ataques[i];
    if (a.coste > energia) continue;
    final dano =
        danoDeAtaque(a, objetivo.especie, reduccion: reduccion, extra: extra);
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
      mejora =
          izquierda > derecha || (izquierda == derecha && dano > mejorDano);
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
  int extra = 0,
  List<int>? candidatos,
}) {
  int? mejor;
  var mejorPuntos = -1;
  for (final i in candidatos ?? yo.relevos) {
    final r = yo.equipo[i];
    final debil = _esDebilContra(r.especie, objetivo.especie);
    if (exigirNoDebil && debil) continue;
    // El relevo que sale no arrastra reducciones: llega sin ellas.
    final ataque = _mejorAtaque(r.especie, energia, objetivo, p, 0, extra);
    if (exigirAtaque && ataque == null) continue;
    final dano = ataque == null
        ? 0
        : danoDeAtaque(r.especie.ataques[ataque], objetivo.especie,
            extra: extra);
    final puntos = (debil ? 0 : 100000000) + dano * 10000 + r.ps;
    if (puntos > mejorPuntos) {
      mejor = i;
      mejorPuntos = puntos;
    }
  }
  return mejor;
}

/// El Pokémon activo de [yo] con el daño de sus ataques de racha (Rodar) ya
/// escalado a lo que harían si los usara ahora. Los índices no cambian.
PokemonCampana _conRacha(BandoCombate yo) {
  final e = yo.pokemonActivo.especie;
  if (!e.ataques.any((a) => a.efecto is DanoPorRacha)) return e;
  return PokemonCampana(
    id: e.id,
    nombre: e.nombre,
    tipo: e.tipo,
    ps: e.ps,
    debilidad: e.debilidad,
    resistencia: e.resistencia,
    retirada: e.retirada,
    ex: e.ex,
    evoluciones: e.evoluciones,
    categoriaCaptura: e.categoriaCaptura,
    ataques: [
      for (var i = 0; i < e.ataques.length; i++)
        if (e.ataques[i].efecto is DanoPorRacha)
          AtaqueCampana(
            nombre: e.ataques[i].nombre,
            tipo: e.ataques[i].tipo,
            coste: e.ataques[i].coste,
            dano: e.ataques[i].dano * (yo.ultimoAtaque == i ? yo.racha + 1 : 1),
            efecto: e.ataques[i].efecto,
          )
        else
          e.ataques[i],
    ],
  );
}
