import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/campana.dart';

import 'catalogo_campana.dart';
import 'controlador_campana.dart';
import 'escena_mapa.dart';
import 'pantalla_combate.dart';
import 'widgets_campana.dart';

/// Modo campaña (D-20): el mapa del primer tramo de Kanto, con el nodo actual,
/// el equipo y lo que se puede hacer en cada nodo. Si hay un combate en curso
/// se muestra la pantalla de combate.
class PantallaCampana extends ConsumerWidget {
  const PantallaCampana({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(catalogoCampanaProvider);
    return catalogo.when(
      loading: () => const Scaffold(
        key: Key('campana-cargando'),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Modo campaña')),
        body: Center(child: Text('No se pudo leer el catálogo: $e')),
      ),
      data: (c) {
        final estado = ref.watch(campanaProvider);
        if (estado.combate != null) return PantallaCombateCampana(catalogo: c);
        return _Mapa(catalogo: c, partida: estado.partida);
      },
    );
  }
}

class _Mapa extends ConsumerWidget {
  const _Mapa({required this.catalogo, required this.partida});

  final CatalogoCampana catalogo;
  final PartidaCampana? partida;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = partida;
    final validos = p == null || p.problemas(catalogo).isEmpty;
    return Scaffold(
      key: const Key('campana-mapa'),
      appBar: AppBar(
        title: Text('Campaña · ${catalogo.region.nombre}'),
        bottom: p == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${p.puntos} puntos · ${p.dinero} \$ · '
                    '${p.progreso.medallas.length} medallas',
                    key: const Key('campana-puntos'),
                  ),
                ),
              ),
        actions: [
          if (p != null) ...[
            PopupMenuButton<String>(
              key: const Key('campana-menu'),
              onSelected: (v) async {
                if (v == 'nueva' && await _confirmarNueva(context)) {
                  ref.read(campanaProvider.notifier).nueva(catalogo);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'nueva', child: Text('Empezar de nuevo')),
              ],
            ),
          ],
        ],
      ),
      body: p == null || !validos
          ? _SinPartida(catalogo: catalogo, danada: !validos)
          : LayoutBuilder(
              builder: (context, caja) {
                final ancho = caja.maxWidth >= 900;
                // La escena del nodo, con su barra fija de recursos encima
                // (propuesta D de los wireframes, D-20 §10.7).
                final escena = Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BarraRecursos(partida: p),
                      const SizedBox(height: 8),
                      EscenaInteractiva(
                        catalogo: catalogo,
                        partida: p,
                        alTocar: (z) => _tocarZona(context, ref, p, z),
                      ),
                    ],
                  ),
                );
                final panel = [
                  _PanelNodo(catalogo: catalogo, partida: p),
                  const SizedBox(height: 16),
                  _Equipo(catalogo: catalogo, partida: p),
                ];
                if (ancho) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: SingleChildScrollView(child: escena)),
                      SizedBox(
                        width: 420,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: panel,
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      escena,
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: panel,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  /// Lo que hace tocar una zona de la escena (D-20 §4, Escenas). Solo se
  /// llama con zonas activas ([estadoZona]).
  void _tocarZona(
      BuildContext context, WidgetRef ref, PartidaCampana p, ZonaPulsable z) {
    final c = catalogo;
    final control = ref.read(campanaProvider.notifier);
    switch (z.accion) {
      case AccionZona.ir:
        if (p.opciones(c).contains(z.destino)) {
          control.avanzar(c, z.destino!);
        } else {
          _avisar(context, control.retroceder(c, z.destino!));
        }
      case AccionZona.combate:
        // Un salvaje ya vencido se vuelve a buscar en la hierba (#412).
        if (!p.hayCombate(c)) control.repetirCombate(c);
        control.combatir(c);
      case AccionZona.inicial:
        final nodo = p.nodoActual(c);
        showModalBottomSheet<void>(
          context: context,
          builder: (hoja) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final id in nodo.iniciales)
                    _OpcionInicial(
                      especie: c.especie(id),
                      clave: 'hoja-inicial-$id',
                      onTap: () {
                        Navigator.of(hoja).pop();
                        control.elegirInicial(c, id);
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      case AccionZona.hablar:
        control.conversar(c);
      case AccionZona.curar:
        control.descansar(c);
      case AccionZona.tienda:
      case AccionZona.pc:
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => SafeArea(
            child: Consumer(
              builder: (context, ref, _) {
                final actual = ref.watch(campanaProvider).partida!;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _Descanso(catalogo: c, partida: actual),
                );
              },
            ),
          ),
        );
    }
  }
}

Future<bool> _confirmarNueva(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Empezar la campaña de nuevo?'),
        content: const Text('Se pierde el equipo, el PC y los puntos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            key: const Key('campana-confirmar-nueva'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Empezar de nuevo'),
          ),
        ],
      ),
    ) ??
    false;

class _SinPartida extends ConsumerWidget {
  const _SinPartida({required this.catalogo, required this.danada});

  final CatalogoCampana catalogo;
  final bool danada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 64),
            const SizedBox(height: 12),
            Text(
              danada
                  ? 'La campaña guardada ya no encaja con el catálogo.'
                  : 'De Pueblo Paleta al Gimnasio de Brock.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('campana-empezar'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Empezar campaña'),
              onPressed: () =>
                  ref.read(campanaProvider.notifier).nueva(catalogo),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _icono(TipoNodo t) => switch (t) {
      TipoNodo.inicio => Icons.home_rounded,
      TipoNodo.combate => Icons.grass_rounded,
      TipoNodo.bifurcacion => Icons.alt_route_rounded,
      TipoNodo.descanso => Icons.local_hospital_rounded,
      TipoNodo.gimnasio => Icons.emoji_events_rounded,
      TipoNodo.jefe => Icons.whatshot_rounded,
      TipoNodo.conversacion => Icons.forum_rounded,
    };

/// Lo que se hace en el nodo actual.
class _PanelNodo extends ConsumerWidget {
  const _PanelNodo({required this.catalogo, required this.partida});

  final CatalogoCampana catalogo;
  final PartidaCampana partida;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = catalogo;
    final p = partida;
    final nodo = p.nodoActual(c);
    final control = ref.read(campanaProvider.notifier);
    final tema = Theme.of(context);
    final hijos = <Widget>[
      Text(nodo.nombre, style: tema.textTheme.headlineSmall),
      const SizedBox(height: 8),
    ];

    if (p.terminada(c)) {
      hijos.addAll([
        const Text('¡Has conseguido la Medalla Roca! Aquí acaba, por ahora, '
            'el primer tramo de Kanto.'),
        Text('Puntos de la campaña: ${p.puntos}'),
      ]);
    } else if (p.capturaPendiente != null) {
      hijos.add(_Captura(catalogo: c, partida: p));
    } else if (nodo.tipo == TipoNodo.inicio && !p.progreso.resuelto) {
      hijos.addAll([
        const Text('Elige tu Pokémon inicial.'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final id in nodo.iniciales)
              _OpcionInicial(
                especie: c.especie(id),
                onTap: () => control.elegirInicial(c, id),
              ),
          ],
        ),
      ]);
    } else if (p.hayCombate(c)) {
      final r = p.rival(c, parametros: parametrosCampana);
      hijos.addAll([
        Text('Rival: ${r.nombre}'),
        Text(r.equipo.map((e) => e.nombre).join(', '),
            style: tema.textTheme.bodySmall),
        if (r.puntos > 0) Text('Recompensa: ${r.puntos} puntos'),
        if (r.llamada != null)
          Text('Al llegar a la mitad de sus PS, el jefe llama a un aliado.',
              style: tema.textTheme.bodySmall),
        if (r.dinero > 0) Text('Dinero: ${r.dinero} \$'),
        if (r.piedrasEx > 0)
          Text('Con la medalla: ${r.piedrasEx} '
              '${r.piedrasEx == 1 ? 'Piedra ex' : 'Piedras ex'}'),
        Text(
            'Si pierdes, vuelves a ${c.region.nodo(p.ultimaCura ?? c.region.inicio).nombre}.',
            style: tema.textTheme.bodySmall),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('campana-combatir'),
          icon: const Icon(Icons.sports_mma_rounded),
          label: const Text('Combatir'),
          onPressed: () => control.combatir(c),
        ),
        if (nodo.tipo == TipoNodo.combate &&
            nodo.rival == RivalDeCombate.salvaje &&
            p.cuantos(ObjetoCampana.repelente) > 0) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('campana-repelente'),
            icon: const Icon(Icons.shield_moon_outlined),
            label:
                Text('Usar Repelente (${p.cuantos(ObjetoCampana.repelente)})'),
            onPressed: () => _avisar(context, control.usarRepelente(c)),
          ),
        ],
      ]);
    } else if (p.puedeRepetir(c)) {
      // Un salvaje ya vencido se puede repetir: XP y captura, sin dinero ni
      // puntos (D-20 §10.7).
      hijos.addAll([
        const Text('Ya venciste aquí. Puedes volver a buscar un Pokémon '
            'salvaje: da XP y se puede capturar, pero no da dinero ni puntos.'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('campana-repetir'),
          icon: const Icon(Icons.grass_rounded),
          label: const Text('Buscar otro salvaje'),
          onPressed: () => control.repetirCombate(c),
        ),
      ]);
    } else if (nodo.tipo == TipoNodo.descanso) {
      hijos.add(_Descanso(catalogo: c, partida: p));
    } else if (nodo.tipo == TipoNodo.conversacion) {
      hijos.addAll([
        if (nodo.personaje != null)
          Text(nodo.personaje!, style: tema.textTheme.titleMedium),
        for (final linea in nodo.texto)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('«$linea»'),
          ),
        const SizedBox(height: 12),
        if (!p.progreso.resuelto)
          FilledButton.icon(
            key: const Key('campana-conversar'),
            icon: Icon(nodo.cura ? Icons.healing_rounded : Icons.check_rounded),
            label: Text(nodo.cura ? 'Curar al equipo y seguir' : 'Seguir'),
            onPressed: () => control.conversar(c),
          )
        else if (nodo.cura)
          const Text('Tu equipo está como nuevo.'),
      ]);
    }

    final opciones = p.opciones(c);
    if (opciones.isNotEmpty) {
      hijos.addAll([
        const SizedBox(height: 16),
        Text(opciones.length > 1 ? '¿Por dónde sigues?' : 'Siguiente parada',
            style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in opciones)
              FilledButton.tonalIcon(
                key: Key('ir-$id'),
                icon: Icon(_icono(c.region.nodo(id).tipo)),
                label: Text(c.region.nodo(id).opcional
                    ? '${c.region.nodo(id).nombre} (opcional)'
                    : c.region.nodo(id).nombre),
                onPressed: () => control.avanzar(c, id),
              ),
          ],
        ),
      ]);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: hijos,
        ),
      ),
    );
  }
}

class _OpcionInicial extends StatelessWidget {
  const _OpcionInicial(
      {required this.especie, required this.onTap, this.clave});

  final PokemonCampana especie;
  final VoidCallback onTap;

  /// Clave del botón; por defecto `inicial-<id>`.
  final String? clave;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key(clave ?? 'inicial-${especie.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 150,
        child: Column(
          children: [
            ImagenCartaCampana(especie: especie, ancho: 140),
            const SizedBox(height: 4),
            Text(especie.nombre,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(resumenCarta(especie),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Tras vencer a un salvaje (o a un jefe por primera vez): capturarlo o no.
class _Captura extends ConsumerWidget {
  const _Captura({required this.catalogo, required this.partida});

  final CatalogoCampana catalogo;
  final PartidaCampana partida;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = catalogo;
    final p = partida;
    final especie = c.especie(p.capturaPendiente!);
    final control = ref.read(campanaProvider.notifier);
    final lleno = p.equipoLleno(parametros: parametrosCampana);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Capturas a ${especie.nombre}?',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ImagenCartaCampana(especie: especie, ancho: 110),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(resumenCarta(especie)),
                  for (final a in especie.ataques) Text(textoAtaque(a)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Primero hay que acertar con una Ball (D-20 §10.6): cada tirada gasta
        // una y se puede repetir mientras queden.
        if (!p.capturaLograda) ...[
          if (p.ballsEnMochila().isEmpty)
            const Text('No te quedan Balls: este combate acaba sin captura.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in p.ballsEnMochila())
                  FilledButton.icon(
                    key: Key('lanzar-${b.name}'),
                    icon: const Icon(Icons.catching_pokemon),
                    label: Text('${nombreObjeto(b)} (${p.cuantos(b)}) · '
                        '${_porcentaje(p.probabilidadConBall(c, b))}'),
                    onPressed: () => _avisar(context, control.lanzarBall(c, b)),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('campana-no-capturar'),
            onPressed: control.noCapturar,
            child: Text(p.ballsEnMochila().isEmpty ? 'Seguir' : 'Dejarlo ir'),
          ),
        ] else ...[
          Text('¡${especie.nombre} capturado!'),
          const SizedBox(height: 8),
          if (lleno) ...[
            const Text('Tu equipo está lleno. Elige a quién mandas al PC, o '
                'manda allí al nuevo.'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < p.equipo.length; i++)
                  OutlinedButton(
                    key: Key('sustituir-$i'),
                    onPressed: () => control.capturar(c, sustituir: i),
                    child:
                        Text('Sustituir a ${c.especie(p.equipo[i].id).nombre}'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('campana-capturar'),
                icon: const Icon(Icons.catching_pokemon),
                label: Text(lleno ? 'Mandarlo al PC' : 'Al equipo'),
                onPressed: () => control.capturar(c),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 750 → «75 %», 125 → «12,5 %».
String _porcentaje(int porMil) =>
    porMil % 10 == 0 ? '${porMil ~/ 10} %' : '${porMil ~/ 10},${porMil % 10} %';

/// El centro Pokémon: curar y el PC.
class _Descanso extends ConsumerWidget {
  const _Descanso({required this.catalogo, required this.partida});

  final CatalogoCampana catalogo;
  final PartidaCampana partida;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = catalogo;
    final p = partida;
    final control = ref.read(campanaProvider.notifier);
    final lleno = p.equipoLleno(parametros: parametrosCampana);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(p.progreso.resuelto
            ? 'Tu equipo está como nuevo. Puedes ordenar el equipo y usar el PC.'
            : 'Aquí se cura todo el equipo.'),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('campana-curar'),
          icon: const Icon(Icons.healing_rounded),
          label: const Text('Curar al equipo'),
          onPressed: () => control.descansar(c),
        ),
        const SizedBox(height: 16),
        Text('Tienda · tienes ${p.dinero} \$',
            style: Theme.of(context).textTheme.titleMedium),
        // Lo que vende este centro (D-20 §10.6): en el primer tramo, Pokéball
        // y Poción; las Balls mejores piden medallas.
        for (final o in p.tienda(c, parametros: parametrosCampana))
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
        const SizedBox(height: 16),
        Text('PC (${p.pc.length})',
            style: Theme.of(context).textTheme.titleMedium),
        if (p.pc.isEmpty) const Text('No tienes Pokémon en el PC.'),
        for (var i = 0; i < p.pc.length; i++)
          ListTile(
            key: Key('pc-$i'),
            contentPadding: EdgeInsets.zero,
            title: Text(c.especie(p.pc[i].id).nombre),
            subtitle: Text('${p.pc[i].ps} / ${c.especie(p.pc[i].id).ps} PS'),
            trailing: lleno
                ? PopupMenuButton<int>(
                    key: Key('pc-cambiar-$i'),
                    tooltip: 'Cambiar por uno del equipo',
                    icon: const Icon(Icons.swap_horiz_rounded),
                    onSelected: (e) => control.moverPc(c, deEquipo: e, dePc: i),
                    itemBuilder: (_) => [
                      for (var e = 0; e < p.equipo.length; e++)
                        PopupMenuItem(
                          value: e,
                          child:
                              Text('Por ${c.especie(p.equipo[e].id).nombre}'),
                        ),
                    ],
                  )
                : IconButton(
                    key: Key('pc-sacar-$i'),
                    tooltip: 'Al equipo',
                    icon: const Icon(Icons.group_add_rounded),
                    onPressed: () => control.moverPc(c, dePc: i),
                  ),
          ),
      ],
    );
  }
}

/// El equipo: el primero sale a combatir. Tocar uno lo pone primero y, en un
/// centro Pokémon, también se puede dejar en el PC.
class _Equipo extends ConsumerWidget {
  const _Equipo({required this.catalogo, required this.partida});

  final CatalogoCampana catalogo;
  final PartidaCampana partida;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = catalogo;
    final p = partida;
    if (p.equipo.isEmpty) return const SizedBox.shrink();
    final control = ref.read(campanaProvider.notifier);
    final enCentro = p.nodoActual(c).tipo == TipoNodo.descanso;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tu equipo (${p.equipo.length}/${parametrosCampana.tamanoEquipo})',
            style: Theme.of(context).textTheme.titleMedium),
        Text('Reserva de XP: ${p.xp}',
            key: const Key('campana-xp'),
            style: Theme.of(context).textTheme.bodyMedium),
        Text(
            'El primero sale a combatir. Toca uno para ponerlo primero, '
            'darle una Poción o evolucionarlo con la XP de la reserva. '
            'Mochila: '
            '${p.cuantos(ObjetoCampana.pokeball)} Pokéballs, '
            '${p.cuantos(ObjetoCampana.pocion)} Pociones, '
            '${p.cuantos(ObjetoCampana.repelente)} Repelentes.',
            style: Theme.of(context).textTheme.bodySmall),
        // Contador de la mochila (D-20 §10.6, propuesta del 2026-11-24).
        Text('Piedras ex: ${p.cuantos(ObjetoCampana.piedraEx)}',
            key: const Key('campana-piedras-ex'),
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < p.equipo.length; i++)
              FichaPokemon(
                key: Key('equipo-$i'),
                especie: c.especie(p.equipo[i].id),
                ps: p.equipo[i].ps,
                destacada: i == 0,
                detalle: i == 0 ? 'sale primero' : null,
                onTap: () => _opciones(context, control, i, enCentro),
              ),
          ],
        ),
      ],
    );
  }

  void _opciones(
      BuildContext context, ControladorCampana control, int i, bool enCentro) {
    final especie = catalogo.especie(partida.equipo[i].id);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(especie.nombre,
                  style: Theme.of(context).textTheme.titleLarge),
              Text(resumenCarta(especie)),
              for (final a in especie.ataques) Text(textoAtaque(a)),
              const SizedBox(height: 12),
              if (i != 0)
                ListTile(
                  key: const Key('equipo-primero'),
                  leading: const Icon(Icons.vertical_align_top_rounded),
                  title: const Text('Poner primero'),
                  onTap: () {
                    Navigator.of(context).pop();
                    control.ponerPrimero(i);
                  },
                ),
              if (partida.cuantos(ObjetoCampana.pocion) > 0)
                ListTile(
                  key: const Key('equipo-pocion'),
                  leading: const Icon(Icons.local_drink_rounded),
                  title:
                      Text('Usar Poción (+${parametrosCampana.psPocion} PS)'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _avisar(context, control.usarPocion(catalogo, i));
                  },
                ),
              // Evolucionar (D-20 §10.6): gasta XP de la reserva (o una piedra
              // ex para hacerse ex, §2.1) y deja al Pokémon con 10 PS, también
              // si estaba debilitado.
              for (final e in partida.evolucionesDe(catalogo, i))
                ListTile(
                  key: Key('equipo-evolucionar-${e.a}'),
                  leading: const Icon(Icons.auto_awesome_rounded),
                  title: Text(e.esPiedraEx
                      ? 'Hacerse ex (1 piedra): ${catalogo.especie(e.a).nombre}'
                      : e.via == ViaEvolucion.xp
                          ? 'Evolucionar en '
                              '${catalogo.especie(e.a).nombre} (${e.xpEvolucion} XP)'
                          : 'Evolucionar en ${catalogo.especie(e.a).nombre}'),
                  subtitle: Text(partida.motivoSinEvolucion(e) ??
                      'Queda con ${PartidaCampana.psAlEvolucionar} PS.'),
                  enabled: partida.puedeEvolucionar(e),
                  onTap: () {
                    Navigator.of(context).pop();
                    _avisar(context, control.evolucionar(catalogo, i, e.a));
                  },
                ),
              if (enCentro && partida.equipo.length > 1)
                ListTile(
                  key: const Key('equipo-al-pc'),
                  leading: const Icon(Icons.computer_rounded),
                  title: const Text('Dejar en el PC'),
                  onTap: () {
                    Navigator.of(context).pop();
                    control.moverPc(catalogo, deEquipo: i);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Muestra el motivo si el motor no ha dejado hacer algo.
void _avisar(BuildContext context, String? motivo) {
  if (motivo == null) return;
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(motivo)));
}

String nombreObjeto(ObjetoCampana o) => switch (o) {
      ObjetoCampana.pokeball => 'Pokéball',
      ObjetoCampana.superBall => 'Super Ball',
      ObjetoCampana.ultraBall => 'Ultra Ball',
      ObjetoCampana.pocion => 'Poción',
      ObjetoCampana.repelente => 'Repelente',
      ObjetoCampana.piedraEx => 'Piedra ex',
    };

String descripcionObjeto(ObjetoCampana o) => switch (o) {
      ObjetoCampana.pokeball ||
      ObjetoCampana.superBall ||
      ObjetoCampana.ultraBall =>
        'Para capturar; cada intento gasta una',
      ObjetoCampana.pocion =>
        'Cura ${parametrosCampana.psPocion} PS fuera de combate',
      ObjetoCampana.repelente => 'Evita un combate contra un Pokémon salvaje',
      ObjetoCampana.piedraEx =>
        'Hace ex a un Pokémon que ya no evoluciona; una por ex',
    };
