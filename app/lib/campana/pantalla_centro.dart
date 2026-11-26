import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/campana.dart';

import 'controlador_campana.dart';
import 'escena_mapa.dart' show ColoresCampana;
import 'pantalla_campana.dart' show nombreObjeto, descripcionObjeto;
import 'solo_horizontal.dart';
import 'widgets_campana.dart';

/// Centro Pokémon (propuesta M de los wireframes, D-20 §10.7). La escena del
/// centro es la del mapa (`EscenaInteractiva`): el **mostrador** cura a todo
/// el equipo, la **estantería** abre la tienda ([abrirTienda]), el **PC**
/// abre su pantalla aparte ([PantallaPc]) y la **puerta** (las salidas) vuelve
/// al mapa. Arriba van el dinero y las Pokéballs (`BarraRecursos`) y abajo, el
/// equipo con su vida. Este panel repite las tres acciones del centro con
/// botones, para quien no toque la escena. El motor no cambia.
class PanelCentro extends ConsumerWidget {
  const PanelCentro({super.key, required this.catalogo, required this.partida});

  final CatalogoCampana catalogo;
  final PartidaCampana partida;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = catalogo;
    final p = partida;
    final control = ref.read(campanaProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Curar es opcional: la puerta está abierta igual (D-20 §10.7, #510).
        Text(p.equipoSano(c)
            ? 'Tu equipo está como nuevo. En la estantería está la tienda y '
                'en el PC puedes cambiar el equipo.'
            : 'El mostrador cura a todo el equipo, gratis. Si quieres, '
                'puedes salir sin curar.'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const Key('campana-curar'),
              icon: const Icon(Icons.healing_rounded),
              label: const Text('Curar al equipo'),
              onPressed: () => control.descansar(c),
            ),
            if (p.nodoActual(c).tienda.isNotEmpty)
              FilledButton.tonalIcon(
                key: const Key('centro-tienda'),
                icon: const Icon(Icons.storefront_rounded),
                label: const Text('Tienda'),
                onPressed: () => abrirTienda(context, c),
              ),
            FilledButton.tonalIcon(
              key: const Key('centro-pc'),
              icon: const Icon(Icons.computer_rounded),
              label: Text('PC (${p.pc.length})'),
              onPressed: () => abrirPc(context, c),
            ),
          ],
        ),
      ],
    );
  }
}

/// La estantería: la tienda del centro en una hoja.
void abrirTienda(BuildContext context, CatalogoCampana catalogo) {
  mostrarHojaCampana<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ColoresCampana.crema,
    builder: (_) => SafeArea(
      child: Consumer(
        builder: (context, ref, _) {
          final p = ref.watch(campanaProvider).partida!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _Tienda(catalogo: catalogo, partida: p),
          );
        },
      ),
    ),
  );
}

class _Tienda extends ConsumerWidget {
  const _Tienda({required this.catalogo, required this.partida});

  final CatalogoCampana catalogo;
  final PartidaCampana partida;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = catalogo;
    final p = partida;
    final control = ref.read(campanaProvider.notifier);
    final venta = p.tienda(c, parametros: parametrosCampana);
    return Column(
      key: const Key('hoja-tienda'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Tienda · tienes ${p.dinero} \$',
            key: const Key('tienda-dinero'),
            style: const TextStyle(
                color: ColoresCampana.tinta,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        if (venta.isEmpty) const Text('Este centro no tiene tienda.'),
        // Lo que vende este centro (D-20 §10.6): en el primer tramo, Pokéball
        // y Poción; las Balls mejores piden medallas.
        for (final o in venta)
          ListTile(
            key: Key('tienda-${o.name}'),
            contentPadding: EdgeInsets.zero,
            title: Text(nombreObjeto(o)),
            subtitle: Text('${descripcionObjeto(o)} · '
                'en la mochila: ${p.cuantos(o)}'),
            trailing: FilledButton.tonal(
              key: Key('comprar-${o.name}'),
              onPressed: p.dinero >= parametrosCampana.precios[o]!
                  ? () => _avisar(context, control.comprar(c, o))
                  : null,
              child: Text('${parametrosCampana.precios[o]} \$'),
            ),
          ),
      ],
    );
  }
}

/// Abre el PC del centro, que es una pantalla aparte (propuesta M).
void abrirPc(BuildContext context, CatalogoCampana catalogo) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => PantallaPc(catalogo: catalogo),
  ));
}

/// El PC del centro Pokémon: el equipo arriba y los Pokémon guardados debajo.
/// Se saca uno del PC al equipo si hay hueco, se cambia por uno del equipo si
/// está lleno y se deja uno del equipo en el PC si queda al menos otro.
class PantallaPc extends ConsumerWidget {
  const PantallaPc({super.key, required this.catalogo});

  final CatalogoCampana catalogo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(campanaProvider).partida;
    final c = catalogo;
    final control = ref.read(campanaProvider.notifier);
    return SoloHorizontal(
        child: Scaffold(
      key: const Key('pantalla-pc'),
      backgroundColor: ColoresCampana.crema,
      appBar: AppBar(
        title: const Text('PC del centro Pokémon'),
        backgroundColor: ColoresCampana.crema,
        foregroundColor: ColoresCampana.tinta,
        leading: IconButton(
          key: const Key('pc-volver'),
          tooltip: 'Volver al centro',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: p == null
          ? const SizedBox.shrink()
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Titulo('Equipo (${p.equipo.length}/'
                            '${parametrosCampana.tamanoEquipo})'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < p.equipo.length; i++)
                              FichaPokemon(
                                key: Key('pc-equipo-$i'),
                                especie: c.especie(p.equipo[i].id),
                                ps: p.equipo[i].ps,
                                destacada: i == 0,
                                detalle: p.equipo.length > 1
                                    ? 'Toca para dejarlo en el PC'
                                    : 'Es el único: no se puede dejar',
                                onTap: p.equipo.length > 1
                                    ? () => control.moverPc(c, deEquipo: i)
                                    : null,
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _Titulo('PC (${p.pc.length})'),
                        const SizedBox(height: 8),
                        if (p.pc.isEmpty)
                          const Text('No tienes Pokémon en el PC.',
                              key: Key('pc-vacio'),
                              style: TextStyle(color: ColoresCampana.tinta)),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < p.pc.length; i++)
                              FichaPokemon(
                                key: Key('pc-$i'),
                                especie: c.especie(p.pc[i].id),
                                ps: p.pc[i].ps,
                                detalle:
                                    p.equipoLleno(parametros: parametrosCampana)
                                        ? 'Toca para cambiarlo'
                                        : 'Toca para sacarlo',
                                onTap: () => _sacar(context, ref, p, i),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    ));
  }

  /// Saca al Pokémon [i] del PC: al equipo si hay hueco y, si está lleno, se
  /// elige por cuál cambiarlo.
  void _sacar(BuildContext context, WidgetRef ref, PartidaCampana p, int i) {
    final c = catalogo;
    final control = ref.read(campanaProvider.notifier);
    if (!p.equipoLleno(parametros: parametrosCampana)) {
      control.moverPc(c, dePc: i);
      return;
    }
    mostrarHojaCampana<void>(
      context: context,
      backgroundColor: ColoresCampana.crema,
      builder: (hoja) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            key: const Key('hoja-pc-cambiar'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('¿Por quién cambias a ${c.especie(p.pc[i].id).nombre}?',
                  style: const TextStyle(
                      color: ColoresCampana.tinta,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              for (var e = 0; e < p.equipo.length; e++)
                ListTile(
                  key: Key('pc-cambiar-$i-$e'),
                  leading: const Icon(Icons.swap_horiz_rounded),
                  title: Text(c.especie(p.equipo[e].id).nombre),
                  subtitle: Text('${p.equipo[e].ps} / '
                      '${c.especie(p.equipo[e].id).ps} PS'),
                  onTap: () {
                    Navigator.of(hoja).pop();
                    control.moverPc(c, deEquipo: e, dePc: i);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Text(texto,
      style: const TextStyle(
          color: ColoresCampana.tinta,
          fontSize: 18,
          fontWeight: FontWeight.w700));
}

void _avisar(BuildContext context, String? motivo) {
  if (motivo == null) return;
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(motivo)));
}
