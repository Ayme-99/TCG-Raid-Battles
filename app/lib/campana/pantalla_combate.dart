import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/campana.dart';

import 'controlador_campana.dart';
import 'widgets_campana.dart';

/// Combate 1 contra 1 de la campaña (D-20 §3). El jugador elige la acción; la
/// máquina (`decidirAccion`) responde al momento y lo que pasa queda en el
/// registro.
class PantallaCombateCampana extends ConsumerWidget {
  const PantallaCombateCampana({super.key, required this.catalogo});

  final CatalogoCampana catalogo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(campanaProvider);
    final combate = estado.combate!;
    final control = ref.read(campanaProvider.notifier);

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
    final registro = _Registro(lineas: estado.registro);
    final mesa = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Bando(
            bando: combate.rival,
            titulo: 'Rival',
            energiaMax: combate.parametros.energiaMaxima),
        const SizedBox(height: 12),
        _Bando(
            bando: combate.jugador,
            titulo: 'Tú',
            energiaMax: combate.parametros.energiaMaxima,
            propio: true),
        const SizedBox(height: 12),
        if (terminado)
          _Final(
            gano: combate.ganador == Bando.jugador,
            onContinuar: () => control.cerrarCombate(catalogo),
          )
        else if (eligiendo)
          _ElegirRelevo(
            bando: combate.jugador,
            titulo: 'Tu Pokémon ha caído. ¿Quién sale?',
            onElegir: (i) => actuar(ElegirSiguiente(Bando.jugador, i)),
          )
        else
          _Acciones(combate: combate, actuar: actuar),
      ],
    );

    return Scaffold(
      key: const Key('campana-combate'),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Combate · turno ${combate.numeroTurno}'),
      ),
      body: LayoutBuilder(
        builder: (context, caja) {
          if (caja.maxWidth >= 900) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16), child: mesa),
                ),
                const VerticalDivider(width: 1),
                SizedBox(width: 360, child: registro),
              ],
            );
          }
          return Column(
            children: [
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12), child: mesa),
              ),
              const Divider(height: 1),
              Expanded(flex: 1, child: registro),
            ],
          );
        },
      ),
    );
  }
}

class _Bando extends StatelessWidget {
  const _Bando({
    required this.bando,
    required this.titulo,
    required this.energiaMax,
    this.propio = false,
  });

  final BandoCombate bando;
  final String titulo;
  final int energiaMax;
  final bool propio;

  @override
  Widget build(BuildContext context) {
    final activo = bando.pokemonActivo;
    final especie = activo.especie;
    final tema = Theme.of(context);
    final estados = [
      if (bando.veneno > 0) 'envenenado',
      if (bando.danoReducido > 0) 'pega −${bando.danoReducido}',
      if (bando.danoExtra > 0) 'recibe +${bando.danoExtra}',
      if (bando.proteccion > 0) 'recibe −${bando.proteccion}',
      if (bando.cegado) 'puede fallar',
      if (bando.racha > 1) 'racha ×${bando.racha}',
    ];
    return Card(
      key: Key(propio ? 'bando-jugador' : 'bando-rival'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ImagenCartaCampana(especie: especie, ancho: 90),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$titulo · ${especie.nombre}',
                      style: tema.textTheme.titleMedium),
                  Text(resumenCarta(especie), style: tema.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  FichaVida(ps: activo.ps, max: especie.ps),
                  const SizedBox(height: 6),
                  Text('Energía ${bando.energia} / $energiaMax',
                      key: Key(propio ? 'energia-jugador' : 'energia-rival')),
                  if (estados.isNotEmpty)
                    Text(estados.join(' · '),
                        style: TextStyle(color: tema.colorScheme.error)),
                  const SizedBox(height: 4),
                  Text(
                    'Equipo: ${[
                      for (var i = 0; i < bando.equipo.length; i++)
                        if (i != bando.activo)
                          '${bando.equipo[i].especie.nombre} ${bando.equipo[i].ps}/${bando.equipo[i].especie.ps}',
                    ].join(', ').ifEmpty('nadie más')}',
                    style: tema.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String otro) => isEmpty ? otro : this;
}

/// PS del activo: barra y número.
class FichaVida extends StatelessWidget {
  const FichaVida({super.key, required this.ps, required this.max});

  final int ps;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (ps / max).clamp(0.0, 1.0),
              minHeight: 12,
              color: ps / max > 0.5
                  ? Colors.green
                  : ps / max > 0.25
                      ? Colors.amber
                      : Colors.red,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$ps / $max PS'),
      ],
    );
  }
}

class _Acciones extends StatelessWidget {
  const _Acciones({required this.combate, required this.actuar});

  final EstadoCombate combate;
  final void Function(AccionCombate) actuar;

  @override
  Widget build(BuildContext context) {
    final yo = combate.jugador;
    final especie = yo.pokemonActivo.especie;
    final miTurno = combate.actua == Bando.jugador;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(miTurno ? 'Tu turno: una acción' : 'Turno del rival…',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var i = 0; i < especie.ataques.length; i++) ...[
              FilledButton(
                key: Key('ataque-$i'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorTipo(especie.ataques[i].tipo),
                  foregroundColor: Colors.black,
                ),
                onPressed: miTurno && yo.energia >= especie.ataques[i].coste
                    ? () => actuar(Atacar(Bando.jugador, i))
                    : null,
                child: Text(textoAtaque(especie.ataques[i])),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('accion-cargar'),
                    icon: const Icon(Icons.bolt_rounded),
                    label: Text(
                        'Cargar (+${combate.parametros.energiaAlCargar + combate.parametros.energiaPorTurno})'),
                    onPressed: miTurno
                        ? () => actuar(const Cargar(Bando.jugador))
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('accion-cambiar'),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: Text(especie.retirada > 0
                        ? 'Cambiar (−${especie.retirada})'
                        : 'Cambiar'),
                    onPressed: miTurno &&
                            yo.relevos.isNotEmpty &&
                            yo.energia >= especie.retirada
                        ? () => _cambiar(context)
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _cambiar(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (hoja) => SafeArea(
        child: _ElegirRelevo(
          bando: combate.jugador,
          titulo: '¿Quién sale? Cambiar gasta el turno.',
          onElegir: (i) {
            Navigator.of(hoja).pop();
            actuar(Cambiar(Bando.jugador, i));
          },
        ),
      ),
    );
  }
}

class _ElegirRelevo extends StatelessWidget {
  const _ElegirRelevo({
    required this.bando,
    required this.titulo,
    required this.onElegir,
  });

  final BandoCombate bando;
  final String titulo;
  final void Function(int) onElegir;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final i in bando.relevos)
                FichaPokemon(
                  key: Key('relevo-$i'),
                  especie: bando.equipo[i].especie,
                  ps: bando.equipo[i].ps,
                  onTap: () => onElegir(i),
                ),
            ],
          ),
        ],
      ),
    );
  }
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

class _Registro extends StatelessWidget {
  const _Registro({required this.lineas});

  final List<String> lineas;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const Key('combate-registro'),
      reverse: true,
      padding: const EdgeInsets.all(12),
      itemCount: lineas.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(lineas[lineas.length - 1 - i]),
      ),
    );
  }
}
