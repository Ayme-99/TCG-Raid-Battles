import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/campana.dart';

import 'controlador_campana.dart';
import 'escena_mapa.dart' show ColoresCampana;
import 'pantalla_campana.dart' show nombreObjeto;
import 'solo_horizontal.dart';
import 'widgets_campana.dart';

/// Pantalla de equipo (propuesta J de los wireframes, D-20 §10.7).
///
/// - Rejilla de 2×3 cartas con nombre, PS y barra de vida; los caídos en gris
///   y los huecos libres marcados.
/// - Arriba, la reserva de XP y las Pociones.
/// - Se toca una carta y sale su hoja: Usar Poción (+20 PS, no revive) y
///   Evolucionar (gasta XP y deja al Pokémon a 10 PS). En un debilitado, la
///   hoja avisa de que solo lo cura el centro Pokémon.
/// - Ordenar el equipo y dejar en el PC, solo en un centro Pokémon. El PC es
///   una pantalla aparte (la del centro), no una pestaña de esta.
///
/// El motor no cambia: todo pasa por [ControladorCampana].
class PantallaEquipo extends ConsumerWidget {
  const PantallaEquipo({super.key, required this.catalogo});

  final CatalogoCampana catalogo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(campanaProvider).partida;
    return SoloHorizontal(
        child: Scaffold(
      key: const Key('pantalla-equipo'),
      backgroundColor: ColoresCampana.crema,
      appBar: AppBar(
        title: const Text('Tu equipo'),
        backgroundColor: ColoresCampana.crema,
        foregroundColor: ColoresCampana.tinta,
        leading: IconButton(
          key: const Key('equipo-volver'),
          tooltip: 'Volver al mapa',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: p == null
          ? const SizedBox.shrink()
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, caja) => SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: _ContenidoEquipo(
                        catalogo: catalogo,
                        partida: p,
                        columnas: caja.maxWidth >= 600 ? 3 : 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    ));
  }
}

/// Abre la pantalla de equipo encima del mapa.
void abrirEquipo(BuildContext context, CatalogoCampana catalogo) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => PantallaEquipo(catalogo: catalogo),
  ));
}

class _ContenidoEquipo extends ConsumerWidget {
  const _ContenidoEquipo({
    required this.catalogo,
    required this.partida,
    required this.columnas,
  });

  final CatalogoCampana catalogo;
  final PartidaCampana partida;
  final int columnas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = partida;
    final c = catalogo;
    final huecos = parametrosCampana.tamanoEquipo;
    final enCentro = p.nodoActual(c).tipo == TipoNodo.descanso;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Arriba, la XP de reserva y las Pociones (propuesta J).
        Container(
          key: const Key('equipo-recursos'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: ColoresCampana.tinta, width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Wrap(
            spacing: 20,
            runSpacing: 4,
            children: [
              Text('Reserva de XP: ${p.xp}',
                  key: const Key('campana-xp'),
                  style: const TextStyle(
                      color: ColoresCampana.tinta,
                      fontWeight: FontWeight.w700)),
              Text('Pociones: ${p.cuantos(ObjetoCampana.pocion)}',
                  key: const Key('equipo-pociones'),
                  style: const TextStyle(
                      color: ColoresCampana.tinta,
                      fontWeight: FontWeight.w700)),
              // Contador de la mochila (D-20 §10.6, #447).
              Text('Piedras ex: ${p.cuantos(ObjetoCampana.piedraEx)}',
                  key: const Key('campana-piedras-ex'),
                  style: const TextStyle(
                      color: ColoresCampana.tinta,
                      fontWeight: FontWeight.w700)),
              // Piedras evolutivas, solo las que se tienen (#546).
              for (final o in piedrasEvolutivas)
                if (p.cuantos(o) > 0)
                  Text('${nombreObjeto(o)}: ${p.cuantos(o)}',
                      key: Key('campana-${o.name}'),
                      style: const TextStyle(
                          color: ColoresCampana.tinta,
                          fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          enCentro
              ? 'El primero sale a combatir. Toca una carta para ordenarla, '
                  'darle una Poción, evolucionarla o dejarla en el PC.'
              : 'El primero sale a combatir. Toca una carta para darle una '
                  'Poción o evolucionarla. El orden y el PC se cambian en un '
                  'centro Pokémon.',
          key: const Key('equipo-ayuda'),
          style: const TextStyle(color: ColoresCampana.tinta),
        ),
        const SizedBox(height: 12),
        GridView.count(
          key: const Key('equipo-rejilla'),
          crossAxisCount: columnas,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.62,
          children: [
            for (var i = 0; i < huecos; i++)
              if (i < p.equipo.length)
                _CartaEquipo(
                  clave: 'equipo-$i',
                  especie: c.especie(p.equipo[i].id),
                  ps: p.equipo[i].ps,
                  primero: i == 0,
                  onTap: () => _hoja(context, ref, i, enCentro),
                )
              else
                _Hueco(clave: 'equipo-hueco-$i'),
          ],
        ),
      ],
    );
  }

  /// La hoja de una carta del equipo: Poción, evoluciones y, en un centro,
  /// ordenar y dejar en el PC.
  void _hoja(BuildContext context, WidgetRef ref, int i, bool enCentro) {
    mostrarHojaCampana<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColoresCampana.crema,
      builder: (hoja) => Consumer(builder: (context, ref, _) {
        final partida = ref.watch(campanaProvider).partida!;
        if (i >= partida.equipo.length) return const SizedBox.shrink();
        return _HojaPokemon(
          catalogo: catalogo,
          partida: partida,
          indice: i,
          enCentro: enCentro,
        );
      }),
    );
  }
}

/// Una carta del equipo en la rejilla: imagen, nombre, PS y barra de vida. Un
/// debilitado va en gris.
class _CartaEquipo extends StatelessWidget {
  const _CartaEquipo({
    required this.clave,
    required this.especie,
    required this.ps,
    required this.primero,
    required this.onTap,
  });

  final String clave;
  final PokemonCampana especie;
  final int ps;
  final bool primero;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final caido = ps <= 0;
    Widget carta = LayoutBuilder(
      builder: (context, caja) =>
          ImagenCartaCampana(especie: especie, ancho: caja.maxWidth),
    );
    if (caido) {
      carta = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 0.6, 0,
        ]),
        child: carta,
      );
    }
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: primero ? ColoresCampana.dorado : ColoresCampana.tinta,
            width: primero ? 4 : 2),
      ),
      child: InkWell(
        key: Key(clave),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: Center(child: carta)),
              const SizedBox(height: 6),
              Text(especie.nombre,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: ColoresCampana.tinta,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              BarraVidaCampana(fraccion: ps / especie.ps),
              const SizedBox(height: 2),
              Text(
                caido
                    ? 'Debilitado'
                    : primero
                        ? '$ps / ${especie.ps} PS · sale primero'
                        : '$ps / ${especie.ps} PS',
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: ColoresCampana.tinta, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra de vida de la paleta de la campaña: verde, naranja por debajo de la
/// mitad y roja por debajo de un cuarto (como en la mesa de combate).
class BarraVidaCampana extends StatelessWidget {
  const BarraVidaCampana({super.key, required this.fraccion, this.alto = 8});

  final double fraccion;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final f = fraccion.clamp(0.0, 1.0);
    final color = f > 0.5
        ? ColoresCampana.verde
        : f > 0.25
            ? ColoresCampana.naranja
            : ColoresCampana.rojo;
    return Container(
      height: alto,
      decoration: BoxDecoration(
        color: ColoresCampana.tinta.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(alto),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: f,
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(alto),
          ),
        ),
      ),
    );
  }
}

/// Un hueco libre del equipo.
class _Hueco extends StatelessWidget {
  const _Hueco({required this.clave});

  final String clave;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key(clave),
      decoration: BoxDecoration(
        color: ColoresCampana.tinta.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: ColoresCampana.tinta.withValues(alpha: 0.35), width: 2),
      ),
      alignment: Alignment.center,
      child: Text('Hueco libre',
          style: TextStyle(color: ColoresCampana.tinta.withValues(alpha: 0.6))),
    );
  }
}

/// La hoja de un Pokémon del equipo.
class _HojaPokemon extends ConsumerWidget {
  const _HojaPokemon({
    required this.catalogo,
    required this.partida,
    required this.indice,
    required this.enCentro,
  });

  final CatalogoCampana catalogo;
  final PartidaCampana partida;
  final int indice;
  final bool enCentro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = catalogo;
    final p = partida;
    final i = indice;
    final guardado = p.equipo[i];
    final especie = c.especie(guardado.id);
    final control = ref.read(campanaProvider.notifier);
    final pociones = p.cuantos(ObjetoCampana.pocion);
    final caido = !guardado.enPie;
    final lleno = guardado.ps >= especie.ps;
    void hacer(String? Function() accion) {
      final motivo = accion();
      if (motivo != null) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(motivo)));
      }
    }

    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('hoja-equipo'),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ImagenCartaCampana(especie: especie, ancho: 96),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(especie.nombre,
                          style: const TextStyle(
                              color: ColoresCampana.tinta,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      BarraVidaCampana(fraccion: guardado.ps / especie.ps),
                      const SizedBox(height: 2),
                      Text('${guardado.ps} / ${especie.ps} PS',
                          style: const TextStyle(color: ColoresCampana.tinta)),
                      const SizedBox(height: 4),
                      Text(resumenCarta(especie),
                          style: const TextStyle(
                              color: ColoresCampana.tinta, fontSize: 12)),
                      for (final a in especie.ataques)
                        Text(textoAtaque(a),
                            style: const TextStyle(
                                color: ColoresCampana.tinta, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (caido)
              const Padding(
                key: Key('equipo-aviso-debilitado'),
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                    'Está debilitado: una Poción no lo revive. Solo lo cura '
                    'el centro Pokémon (o evolucionar, que lo deja a 10 PS).',
                    style: TextStyle(color: ColoresCampana.tinta)),
              ),
            // Usar Poción (+20 PS, no revive; quedan las que haya).
            ListTile(
              key: const Key('equipo-pocion'),
              leading: const Icon(Icons.local_drink_rounded),
              title: Text('Usar Poción (+${parametrosCampana.psPocion} PS)'),
              subtitle: Text(pociones == 0
                  ? 'No te quedan Pociones.'
                  : caido
                      ? 'No revive a un debilitado.'
                      : lleno
                          ? 'Ya tiene todos sus PS.'
                          : 'Te quedan $pociones.'),
              enabled: pociones > 0 && !caido && !lleno,
              onTap: () => hacer(() => control.usarPocion(c, i)),
            ),
            // Evolucionar (D-20 §10.6): gasta XP de la reserva (o una piedra
            // ex para hacerse ex, §2.1, #447) y deja al Pokémon con 10 PS,
            // también si estaba debilitado.
            for (final e in p.evolucionesDe(c, i))
              ListTile(
                key: Key('equipo-evolucionar-${e.a}'),
                leading: const Icon(Icons.auto_awesome_rounded),
                title: Text(e.esPiedraEx
                    ? 'Hacerse ex (1 piedra): ${c.especie(e.a).nombre}'
                    : e.via == ViaEvolucion.xp
                        ? 'Evolucionar en '
                            '${c.especie(e.a).nombre} (${e.xpEvolucion} XP)'
                        : e.via == ViaEvolucion.objeto &&
                                objetoDeEvolucion(e.objeto!) != null
                            ? 'Evolucionar en ${c.especie(e.a).nombre} (1 '
                                '${nombreObjeto(objetoDeEvolucion(e.objeto!)!)})'
                            : 'Evolucionar en ${c.especie(e.a).nombre}'),
                subtitle: Text(p.motivoSinEvolucion(e) ??
                    'Queda con ${PartidaCampana.psAlEvolucionar} PS.'),
                enabled: p.puedeEvolucionar(e),
                onTap: () {
                  Navigator.of(context).pop();
                  hacer(() => control.evolucionar(c, i, e.a));
                },
              ),
            // Ordenar y el PC, solo en un centro Pokémon (D-20 §10.7).
            if (enCentro && i != 0)
              ListTile(
                key: const Key('equipo-primero'),
                leading: const Icon(Icons.vertical_align_top_rounded),
                title: const Text('Poner primero'),
                onTap: () {
                  Navigator.of(context).pop();
                  control.ponerPrimero(i);
                },
              ),
            if (enCentro && p.equipo.length > 1)
              ListTile(
                key: const Key('equipo-al-pc'),
                leading: const Icon(Icons.computer_rounded),
                title: const Text('Dejar en el PC'),
                onTap: () {
                  Navigator.of(context).pop();
                  control.moverPc(c, deEquipo: i);
                },
              ),
            if (!enCentro)
              const Padding(
                key: Key('equipo-solo-centro'),
                padding: EdgeInsets.only(top: 8),
                child: Text(
                    'Para ordenar el equipo o usar el PC, ve a un centro '
                    'Pokémon.',
                    style:
                        TextStyle(color: ColoresCampana.tinta, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
