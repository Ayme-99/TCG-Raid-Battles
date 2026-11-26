import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/campana.dart';

import 'controlador_campana.dart';
import 'escena_mapa.dart' show ColoresCampana, carpetaSpritesAjenos;
import 'solo_horizontal.dart';
import 'widgets_campana.dart';

// Colores del kit de interfaz (docs/diseno-ui/campana-arte-interfaz.md).
const _tinta = ColoresCampana.tinta;
const _crema = ColoresCampana.crema;
const _dorado = ColoresCampana.dorado;
const _tapete = ColoresCampana.tapete;
const _verde = ColoresCampana.verde;
const _naranja = ColoresCampana.naranja;
const _rojo = ColoresCampana.rojo;

/// La ficha de energía (sprite de EP, aislado en `sprites_ajenos/`).
const _fichaEnergia = '${carpetaSpritesAjenos}energia/energia_arcoiris.png';

/// Los combates del tutorial, en los que el primer toque va señalado
/// (D-20 §10.7, propuesta I): los de la Ruta 1 y el de Pikachu.
bool esCombateTutorial(NodoRuta nodo) =>
    nodo.zona == 'ruta-1' || nodo.jefe == 'pikachu-jefe';

/// Combate 1 contra 1 de la campaña (D-20 §3) con la mesa de la propuesta I
/// (D-20 §10.7): un tapete con la banca rival, el activo rival, tu activo y
/// tu banca. Se toca a tu activo para atacar o cargar y a uno de tu banca para
/// cambiar. La máquina (`decidirAccion`) responde al momento.
class PantallaCombateCampana extends ConsumerStatefulWidget {
  const PantallaCombateCampana({super.key, required this.catalogo});

  final CatalogoCampana catalogo;

  @override
  ConsumerState<PantallaCombateCampana> createState() =>
      _PantallaCombateCampanaState();
}

class _PantallaCombateCampanaState
    extends ConsumerState<PantallaCombateCampana> {
  /// Si el jugador ya ha tocado algo en este combate (apaga el destello del
  /// tutorial).
  bool _tocado = false;

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(campanaProvider);
    final combate = estado.combate!;
    final control = ref.read(campanaProvider.notifier);
    final partida = estado.partida;
    final tutorial = !_tocado &&
        partida != null &&
        esCombateTutorial(partida.nodoActual(widget.catalogo));

    void actuar(AccionCombate a) {
      final motivo = control.actuar(a);
      if (motivo != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(motivo)));
      }
    }

    final terminado = combate.fase == FaseCombate.terminado;
    final eligiendo = !terminado &&
        combate.fase == FaseCombate.eligiendoActivo &&
        combate.actua == Bando.jugador;
    final miTurno = !terminado && !eligiendo && combate.actua == Bando.jugador;
    final yo = combate.jugador;
    final max = combate.parametros.energiaMaxima;

    void tocarActivo() {
      setState(() => _tocado = true);
      _hojaAcciones(context, combate, actuar);
    }

    void tocarBanca(int i) {
      setState(() => _tocado = true);
      if (eligiendo) {
        actuar(ElegirSiguiente(Bando.jugador, i));
      } else if ((combate.jugador.paralizado || combate.jugador.dormido) &&
          !objetivosDeCuerda(combate, Bando.jugador).contains(i)) {
        // Dragoaliento o Canto: no se puede cambiar (D-20 §3.6, §10.2), salvo
        // con una Cuerda Huida (§10.6).
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
            content: Text(combate.jugador.dormido
                ? 'Está dormido: solo sale con una Cuerda Huida.'
                : 'Está paralizado: este turno no puede cambiar.')));
      } else {
        _confirmarCambio(context, combate, i, actuar);
      }
    }

    final mesa = Container(
      key: const Key('combate-tapete'),
      decoration: BoxDecoration(
        color: _tapete,
        border: Border.all(color: _dorado, width: 4),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Banca(
            clave: 'banca-rival',
            bando: combate.rival,
          ),
          const SizedBox(height: 10),
          _Activo(
            clave: 'activo-rival',
            bando: combate.rival,
            energiaMax: max,
          ),
          const SizedBox(height: 10),
          _UltimaJugada(
            texto: estado.registro.isEmpty ? '' : estado.registro.last,
            alVerTodo: () => _hojaRegistro(context, estado.registro),
          ),
          const SizedBox(height: 10),
          _Activo(
            clave: 'activo-jugador',
            bando: yo,
            energiaMax: max,
            propio: true,
            destello: tutorial && miTurno,
            alTocar: miTurno ? tocarActivo : null,
          ),
          const SizedBox(height: 10),
          _Banca(
            clave: 'banca-jugador',
            bando: yo,
            alTocar: (eligiendo ||
                    (miTurno &&
                        (yo.energia >= yo.pokemonActivo.especie.retirada ||
                            objetivosDeCuerda(combate, Bando.jugador)
                                .isNotEmpty)))
                ? tocarBanca
                : null,
          ),
        ],
      ),
    );

    return Scaffold(
      key: const Key('campana-combate'),
      backgroundColor: _crema,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Combate · turno ${combate.numeroTurno}'),
        actions: [
          IconButton(
            key: const Key('combate-ver-registro'),
            tooltip: 'Registro del combate',
            icon: const Icon(Icons.receipt_long_rounded),
            onPressed: () => _hojaRegistro(context, estado.registro),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  mesa,
                  const SizedBox(height: 12),
                  if (terminado)
                    _Final(
                      gano: combate.ganador == Bando.jugador,
                      onContinuar: () => control.cerrarCombate(widget.catalogo),
                    )
                  else if (eligiendo)
                    const _Aviso(
                      clave: 'combate-elige-relevo',
                      texto: 'Tu Pokémon ha caído. Toca a uno de tu banca '
                          'para que salga.',
                    )
                  else if (tutorial && miTurno)
                    const _Aviso(
                      clave: 'combate-tutorial',
                      texto: 'Toca a tu Pokémon para atacar o cargar energía.',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja de acciones del activo: sus ataques con su coste, Cargar, Usar
/// Poción (no gasta turno, D-20 §3.2; #458) y, si lleva alguna, Usar Cuerda
/// Huida (gasta el turno y no paga la retirada, §10.6; #468).
void _hojaAcciones(BuildContext context, EstadoCombate combate,
    void Function(AccionCombate) actuar) {
  final yo = combate.jugador;
  final especie = yo.pokemonActivo.especie;
  final p = combate.parametros;
  final curables = objetivosDePocion(combate, Bando.jugador);
  final relevos = objetivosDeCuerda(combate, Bando.jugador);
  mostrarHojaCampana<void>(
    context: context,
    backgroundColor: _crema,
    // Con scroll: en un móvil apaisado la hoja es baja (§10.7).
    builder: (hoja) => SafeArea(
      child: SingleChildScrollView(
          child: Padding(
        key: const Key('hoja-acciones'),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${especie.nombre} · energía ${yo.energia}',
                style: const TextStyle(
                    color: _tinta, fontSize: 18, fontWeight: FontWeight.w700)),
            if (yo.paralizado)
              const Padding(
                key: Key('aviso-paralizado'),
                padding: EdgeInsets.only(top: 4),
                child: Text(
                    'Paralizado: este turno solo puede cargar (o usar una '
                    'Poción o una Cuerda Huida).',
                    style: TextStyle(color: _tinta)),
              ),
            if (yo.dormido)
              const Padding(
                key: Key('aviso-dormido'),
                padding: EdgeInsets.only(top: 4),
                child: Text(
                    'Dormido: no puede atacar ni retirarse. Puede cargar, usar '
                    'una Poción o salir con una Cuerda Huida. En cada cambio '
                    'de turno se lanza una moneda: con cara se despierta.',
                    style: TextStyle(color: _tinta)),
              ),
            const SizedBox(height: 12),
            for (var i = 0; i < especie.ataques.length; i++) ...[
              _BotonAccion(
                clave: 'ataque-$i',
                color: colorTipo(especie.ataques[i].tipo),
                texto: textoAtaque(especie.ataques[i]),
                activo: !yo.paralizado &&
                    !yo.dormido &&
                    yo.energia >= especie.ataques[i].coste,
                alTocar: () {
                  Navigator.of(hoja).pop();
                  actuar(Atacar(Bando.jugador, i));
                },
              ),
              const SizedBox(height: 8),
            ],
            _BotonAccion(
              clave: 'accion-cargar',
              color: _dorado,
              texto: 'Cargar (+${p.energiaAlCargar + p.energiaPorTurno})',
              activo: true,
              alTocar: () {
                Navigator.of(hoja).pop();
                actuar(const Cargar(Bando.jugador));
              },
            ),
            const SizedBox(height: 8),
            _BotonAccion(
              clave: 'accion-pocion',
              color: _verde,
              texto: yo.pociones == 0
                  ? 'Poción: no te quedan'
                  : 'Usar Poción (+${p.psPocion} PS, no gasta turno) · '
                      'quedan ${yo.pociones}',
              activo: curables.isNotEmpty,
              alTocar: () {
                Navigator.of(hoja).pop();
                if (curables.length == 1) {
                  actuar(UsarPocion(Bando.jugador, curables.single));
                } else {
                  _elegirParaPocion(context, combate, curables, actuar);
                }
              },
            ),
            if (yo.cuerdas > 0) ...[
              const SizedBox(height: 8),
              _BotonAccion(
                clave: 'accion-cuerda',
                color: _naranja,
                texto: 'Usar Cuerda Huida (sin retirada, gasta el turno) · '
                    'quedan ${yo.cuerdas}',
                activo: relevos.isNotEmpty,
                alTocar: () {
                  Navigator.of(hoja).pop();
                  _elegirParaCuerda(context, combate, relevos, actuar);
                },
              ),
            ],
          ],
        ),
      )),
    ),
  );
}

/// A quién curar con la Poción cuando hay más de uno en pie al que le faltan
/// PS (la propuesta de Diseño deja curar también a la banca).
void _elegirParaPocion(BuildContext context, EstadoCombate combate,
    List<int> curables, void Function(AccionCombate) actuar) {
  final yo = combate.jugador;
  mostrarHojaCampana<void>(
    context: context,
    backgroundColor: _crema,
    builder: (hoja) => SafeArea(
      child: Padding(
        key: const Key('hoja-pocion'),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('¿A quién curas?',
                style: TextStyle(
                    color: _tinta, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            for (final i in curables) ...[
              _BotonAccion(
                clave: 'pocion-$i',
                color: _verde,
                texto: '${yo.equipo[i].especie.nombre}'
                    '${i == yo.activo ? ' (activo)' : ''} · '
                    '${yo.equipo[i].ps}/${yo.equipo[i].especie.ps} PS',
                activo: true,
                alTocar: () {
                  Navigator.of(hoja).pop();
                  actuar(UsarPocion(Bando.jugador, i));
                },
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    ),
  );
}

/// A quién sacar con la Cuerda Huida (cualquier relevo que pueda salir).
void _elegirParaCuerda(BuildContext context, EstadoCombate combate,
    List<int> relevos, void Function(AccionCombate) actuar) {
  final yo = combate.jugador;
  mostrarHojaCampana<void>(
    context: context,
    backgroundColor: _crema,
    builder: (hoja) => SafeArea(
      child: Padding(
        key: const Key('hoja-cuerda'),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('¿Quién sale?',
                style: TextStyle(
                    color: _tinta, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            for (final i in relevos) ...[
              _BotonAccion(
                clave: 'cuerda-$i',
                color: _naranja,
                texto: '${yo.equipo[i].especie.nombre} · '
                    '${yo.equipo[i].ps}/${yo.equipo[i].especie.ps} PS',
                activo: true,
                alTocar: () {
                  Navigator.of(hoja).pop();
                  actuar(UsarCuerdaHuida(Bando.jugador, i));
                },
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Cambiar gasta el turno (y la retirada): se pide confirmación. Si lleva una
/// Cuerda Huida, el diálogo la ofrece también (sin retirada y aunque esté
/// Paralizado; gasta el turno igual, D-20 §10.6).
Future<void> _confirmarCambio(BuildContext context, EstadoCombate combate,
    int indice, void Function(AccionCombate) actuar) async {
  final yo = combate.jugador;
  final sale = yo.equipo[indice].especie;
  final retirada = yo.pokemonActivo.especie.retirada;
  final puedeCambiar =
      !yo.paralizado && !yo.dormido && yo.energia >= retirada;
  final puedeCuerda =
      objetivosDeCuerda(combate, Bando.jugador).contains(indice);
  final eleccion = await mostrarDialogoCampana<AccionCombate>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: Text('¿Sacar a ${sale.nombre}?'),
      content: Text([
        if (puedeCambiar)
          retirada > 0
              ? 'Cambiar gasta el turno y $retirada de energía.'
              : 'Cambiar gasta el turno.',
        if (puedeCuerda)
          'La Cuerda Huida no paga la retirada, pero gasta el turno '
              '(te quedan ${yo.cuerdas}).',
      ].join('\n')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogo).pop(),
          child: const Text('Volver'),
        ),
        if (puedeCuerda)
          FilledButton(
            key: const Key('confirmar-cuerda'),
            onPressed: () => Navigator.of(dialogo)
                .pop(UsarCuerdaHuida(Bando.jugador, indice)),
            child: const Text('Cuerda Huida'),
          ),
        if (puedeCambiar)
          FilledButton(
            key: const Key('confirmar-cambio'),
            onPressed: () =>
                Navigator.of(dialogo).pop(Cambiar(Bando.jugador, indice)),
            child: const Text('Cambiar'),
          ),
      ],
    ),
  );
  if (eleccion != null) actuar(eleccion);
}

void _hojaRegistro(BuildContext context, List<String> lineas) {
  mostrarHojaCampana<void>(
    context: context,
    backgroundColor: _crema,
    builder: (_) => SafeArea(
      child: ListView.builder(
        key: const Key('combate-registro'),
        reverse: true,
        padding: const EdgeInsets.all(16),
        itemCount: lineas.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(lineas[lineas.length - 1 - i]),
        ),
      ),
    ),
  );
}

/// Los estados del bando que se ven en la mesa («pega −10», envenenado…).
List<String> estadosDeBando(BandoCombate b) => [
      if (b.veneno > 0) b.drenado ? 'drenado' : 'envenenado',
      if (b.paralizado) 'paralizado',
      if (b.dormido) 'dormido',
      if (b.danoReducido > 0) 'pega −${b.danoReducido}',
      if (b.danoExtra > 0) 'recibe +${b.danoExtra}',
      if (b.proteccion > 0) 'recibe −${b.proteccion}',
      if (b.cegado || b.cegadoMientrasActivo) 'puede fallar',
      if (b.racha > 1) 'racha ×${b.racha}',
    ];

/// El activo de un bando: su carta, la vida, la energía como fichas y sus
/// estados.
class _Activo extends StatelessWidget {
  const _Activo({
    required this.clave,
    required this.bando,
    required this.energiaMax,
    this.propio = false,
    this.destello = false,
    this.alTocar,
  });

  final String clave;
  final BandoCombate bando;
  final int energiaMax;
  final bool propio;
  final bool destello;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final activo = bando.pokemonActivo;
    final especie = activo.especie;
    final estados = estadosDeBando(bando);
    final carta = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: destello ? _dorado : Colors.transparent, width: 4),
        boxShadow: destello
            ? const [BoxShadow(color: _dorado, blurRadius: 18, spreadRadius: 2)]
            : null,
      ),
      child: ImagenCartaCampana(especie: especie, ancho: 110),
    );
    final datos = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(especie.nombre,
              style: const TextStyle(
                  color: _crema, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _Vida(ps: activo.ps, max: especie.ps, alto: 14),
          const SizedBox(height: 2),
          Text('${activo.ps} / ${especie.ps} PS',
              key: Key('ps-$clave'), style: const TextStyle(color: _crema)),
          const SizedBox(height: 6),
          _Energia(
            clave: propio ? 'energia-jugador' : 'energia-rival',
            energia: bando.energia,
            max: energiaMax,
          ),
          if (estados.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final e in estados)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _naranja,
                      border: Border.all(color: _tinta, width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(e,
                        style: const TextStyle(
                            color: _tinta, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
    return Semantics(
      button: alTocar != null,
      label: propio ? 'Tu Pokémon activo' : 'Pokémon activo rival',
      child: Material(
        key: Key(clave),
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: alTocar,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: propio
                  ? [carta, const SizedBox(width: 12), datos]
                  : [datos, const SizedBox(width: 12), carta],
            ),
          ),
        ),
      ),
    );
  }
}

/// La banca de un bando: hasta 5 miniaturas de la carta (60×84) con una barra
/// de vida fina encima; los caídos en gris y sin poder elegirse.
class _Banca extends StatelessWidget {
  const _Banca({required this.clave, required this.bando, this.alTocar});

  final String clave;
  final BandoCombate bando;
  final void Function(int indice)? alTocar;

  @override
  Widget build(BuildContext context) {
    final indices = [
      for (var i = 0; i < bando.equipo.length; i++)
        if (i != bando.activo) i,
    ];
    return SizedBox(
      key: Key(clave),
      height: 100,
      child: indices.isEmpty
          ? const Center(
              child: Text('Banca vacía', style: TextStyle(color: _crema)))
          : ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final i in indices)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Miniatura(
                      clave: '$clave-$i',
                      pokemon: bando.equipo[i],
                      alTocar: alTocar != null && bando.equipo[i].enPie
                          ? () => alTocar!(i)
                          : null,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.clave, required this.pokemon, this.alTocar});

  final String clave;
  final PokemonEnCombate pokemon;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final caido = !pokemon.enPie;
    Widget carta = ImagenCartaCampana(especie: pokemon.especie, ancho: 60);
    if (caido) {
      carta = ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.srcATop),
        child: carta,
      );
    }
    return Semantics(
      button: alTocar != null,
      label: '${pokemon.especie.nombre}, ${pokemon.ps} PS',
      child: InkWell(
        key: Key(clave),
        onTap: alTocar,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 60,
          child: Column(
            children: [
              _Vida(ps: pokemon.ps, max: pokemon.especie.ps, alto: 6),
              const SizedBox(height: 4),
              carta,
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra de vida con los colores del kit: verde, naranja por debajo de la
/// mitad y rojo por debajo de un cuarto.
class _Vida extends StatelessWidget {
  const _Vida({required this.ps, required this.max, required this.alto});

  final int ps;
  final int max;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final f = (ps / max).clamp(0.0, 1.0);
    return Container(
      height: alto,
      decoration: BoxDecoration(
        color: _tinta,
        borderRadius: BorderRadius.circular(alto),
        border: Border.all(color: _tinta, width: 1.5),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: f,
          child: Container(
            decoration: BoxDecoration(
              color: f > 0.5
                  ? _verde
                  : f > 0.25
                      ? _naranja
                      : _rojo,
              borderRadius: BorderRadius.circular(alto),
            ),
          ),
        ),
      ),
    );
  }
}

/// La energía como fichas de 0 a [max] (no barra): las vacías, en gris.
class _Energia extends StatelessWidget {
  const _Energia(
      {required this.clave, required this.energia, required this.max});

  final String clave;
  final int energia;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Energía $energia de $max',
      child: Wrap(
        key: Key(clave),
        spacing: 2,
        runSpacing: 2,
        children: [
          for (var i = 0; i < max; i++)
            i < energia
                ? Image.asset(_fichaEnergia, width: 20, height: 20)
                : ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                        Color(0xFF3A3A3A), BlendMode.srcATop),
                    child: Opacity(
                      opacity: 0.6,
                      child: Image.asset(_fichaEnergia, width: 20, height: 20),
                    ),
                  ),
        ],
      ),
    );
  }
}

/// La última jugada, siempre a la vista; tocarla abre el registro entero.
class _UltimaJugada extends StatelessWidget {
  const _UltimaJugada({required this.texto, required this.alVerTodo});

  final String texto;
  final VoidCallback alVerTodo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _crema,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _tinta, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: alVerTodo,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(texto,
              key: const Key('combate-ultima'),
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: _tinta, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _BotonAccion extends StatelessWidget {
  const _BotonAccion({
    required this.clave,
    required this.color,
    required this.texto,
    required this.activo,
    required this.alTocar,
  });

  final String clave;
  final Color color;
  final String texto;
  final bool activo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: Key(clave),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: _tinta,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _tinta, width: 2),
        ),
      ),
      onPressed: activo ? alTocar : null,
      child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.clave, required this.texto});

  final String clave;
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
        key: Key(clave),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _dorado,
          border: Border.all(color: _tinta, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(texto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _tinta, fontWeight: FontWeight.w700)),
      );
}

class _Final extends StatelessWidget {
  const _Final({required this.gano, required this.onContinuar});

  final bool gano;
  final VoidCallback onContinuar;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(gano ? '¡Victoria!' : 'Derrota',
                style: Theme.of(context).textTheme.headlineSmall),
            Text(gano
                ? 'Tu equipo conserva los PS que le quedan.'
                : 'Vuelves al último sitio donde te curaste, con el equipo '
                    'curado. Conservas lo que has ganado.'),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('combate-continuar'),
              onPressed: onContinuar,
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }
}
