import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalogo/catalogo.dart';
import '../pokedex/pokedex.dart';
import 'carta.dart';

const _morado = Color(0xFF1B1235);
const _moradoClaro = Color(0xFF2A1D52);
const _amarillo = Color(0xFFFFC400);
const _lila = Color(0xFFE6DDF7);

/// Cómo se ve una carta en la Pokédex.
enum _Aspecto {
  /// Nunca vista: silueta con «?».
  oculta,

  /// Vista pero no derrotada: en gris.
  vista,

  /// Derrotada: a todo color.
  derrotada,
}

const _filtroGris = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

/// Pokédex local (#236): los jefes enfrentados y sus aliados, por expansión.
/// De momento solo la categoría «Enemigos»; «Mis cartas» llega con el formato
/// digital. Nunca vista = silueta, vista = gris, derrotada = a todo color.
class PantallaPokedex extends ConsumerWidget {
  const PantallaPokedex({super.key});

  /// Ancho a partir del cual los jefes se ponen en dos columnas.
  static const anchoDosColumnas = 700.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pokedex = ref.watch(pokedexProvider);
    final jefes = ref.watch(catalogoProvider).valueOrNull?.jefes ?? const [];
    final ancho = MediaQuery.of(context).size.width;
    final ancha = ancho >= anchoDosColumnas;

    var vistos = 0;
    var total = 0;
    for (final j in jefes) {
      total++;
      if (pokedex.jefe(j.nombre) != null) vistos++;
      for (final a in j.invocacion?.aliados.values ?? const <AliadoCatalogo>[]) {
        total++;
        if (pokedex.aliadoVisto(a.nombre)) vistos++;
      }
    }

    final paneles = [
      for (final j in jefes) _PanelJefe(jefe: j, pokedex: pokedex),
    ];
    return Scaffold(
      key: const Key('pokedex'),
      backgroundColor: _morado,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/mapas/sala-origen.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: _morado),
          ),
          ColoredBox(color: _morado.withValues(alpha: 0.62)),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ancha ? 48 : 16,
                vertical: ancha ? 24 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Cabecera(ancha: ancha),
                  const SizedBox(height: 16),
                  const _Pestanas(),
                  const SizedBox(height: 12),
                  _Progreso(vistos: vistos, total: total),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: ancha
                          ? Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                for (final p in paneles)
                                  SizedBox(
                                    width: (ancho - 96 - 16) / 2,
                                    child: p,
                                  ),
                              ],
                            )
                          : Column(
                              children: [
                                for (final p in paneles) ...[
                                  p,
                                  const SizedBox(height: 12),
                                ],
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.ancha});

  final bool ancha;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: _morado.withValues(alpha: 0.88),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Colors.white, width: 2),
          ),
          child: InkWell(
            key: const Key('pokedex-atras'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).maybePop(),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Pokédex',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: ancha ? 30 : 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _Pestanas extends StatelessWidget {
  const _Pestanas();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            key: const Key('pokedex-mis-cartas'),
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _morado.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white54, width: 2),
            ),
            child: const Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                Icon(Icons.lock_outline, size: 16, color: Color(0xFFCFC6E4)),
                Text(
                  'Mis cartas · Próximamente',
                  style: TextStyle(
                    color: Color(0xFFCFC6E4),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            key: const Key('pokedex-enemigos'),
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _amarillo,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Text(
              'Enemigos',
              style: TextStyle(
                color: _morado,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Progreso extends StatelessWidget {
  const _Progreso({required this.vistos, required this.total});

  final int vistos;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pokedex-progreso'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: _morado.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white54, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Expansión 1 · Origen',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$vistos de $total',
                style: const TextStyle(
                  color: _lila,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : vistos / total,
              minHeight: 12,
              backgroundColor: Colors.white24,
              color: _amarillo,
            ),
          ),
        ],
      ),
    );
  }
}

/// Un jefe con su estado y la fila de sus aliados.
class _PanelJefe extends StatelessWidget {
  const _PanelJefe({required this.jefe, required this.pokedex});

  final JefeCatalogo jefe;
  final Pokedex pokedex;

  @override
  Widget build(BuildContext context) {
    final registro = pokedex.jefe(jefe.nombre);
    final aspecto = registro == null
        ? _Aspecto.oculta
        : registro.derrotado
            ? _Aspecto.derrotada
            : _Aspecto.vista;
    final aliados = jefe.invocacion?.aliados.values.toList() ?? const [];
    final vistos = aliados.where((a) => pokedex.aliadoVisto(a.nombre)).length;
    final etiqueta = switch (aspecto) {
      _Aspecto.derrotada => 'Derrotado',
      _Aspecto.vista => 'Enfrentado',
      _Aspecto.oculta => 'Sin enfrentar',
    };
    final oculto = aspecto == _Aspecto.oculta;
    return Container(
      key: Key('pokedex-jefe-${idCarta(jefe.nombre)}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _morado.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white54, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                child: _CartaPokedex(nombre: jefe.nombre, aspecto: aspecto),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      oculto ? '???' : jefe.nombre,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: oculto ? const Color(0xFFCFC6E4) : Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Jefe · Nivel ${jefe.nivel}',
                      style: const TextStyle(
                        color: _lila,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      key: Key('pokedex-estado-${idCarta(jefe.nombre)}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: switch (aspecto) {
                          _Aspecto.derrotada => _amarillo,
                          _Aspecto.vista => Colors.white24,
                          _Aspecto.oculta => Colors.white12,
                        },
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        etiqueta,
                        style: TextStyle(
                          color: aspecto == _Aspecto.derrotada
                              ? _morado
                              : _lila,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (registro != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        registro.enfrentado == 1
                            ? '1 partida · ${registro.victorias} '
                                '${registro.victorias == 1 ? 'victoria' : 'victorias'}'
                            : '${registro.enfrentado} partidas · '
                                '${registro.victorias} '
                                '${registro.victorias == 1 ? 'victoria' : 'victorias'}',
                        style: const TextStyle(color: _lila, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Aliados',
                            style: TextStyle(
                              color: _lila,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '$vistos/${aliados.length}',
                          key: Key('pokedex-aliados-${idCarta(jefe.nombre)}'),
                          style: const TextStyle(
                            color: _lila,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: aliados.isEmpty ? 0 : vistos / aliados.length,
                        minHeight: 10,
                        backgroundColor: Colors.white24,
                        color: _amarillo,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < aliados.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: KeyedSubtree(
                    key: Key('pokedex-aliado-${idCarta(aliados[i].nombre)}'),
                    child: _CartaPokedex(
                      nombre: aliados[i].nombre,
                      aspecto: pokedex.aliadoVencido(aliados[i].nombre)
                          ? _Aspecto.derrotada
                          : pokedex.aliadoVisto(aliados[i].nombre)
                              ? _Aspecto.vista
                              : _Aspecto.oculta,
                      pequena: true,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// La carta según su aspecto: color, gris o silueta.
class _CartaPokedex extends StatelessWidget {
  const _CartaPokedex({
    required this.nombre,
    required this.aspecto,
    this.pequena = false,
  });

  final String nombre;
  final _Aspecto aspecto;
  final bool pequena;

  @override
  Widget build(BuildContext context) {
    final carta = CartaImagen(
      nombre: nombre,
      alternativa: ColoredBox(
        color: _moradoClaro,
        child: Center(
          child: Text(
            nombre,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ),
    );
    switch (aspecto) {
      case _Aspecto.derrotada:
        return carta;
      case _Aspecto.vista:
        return ColorFiltered(
          colorFilter: _filtroGris,
          child: Opacity(opacity: 0.75, child: carta),
        );
      case _Aspecto.oculta:
        return Stack(
          alignment: Alignment.center,
          children: [
            ColorFiltered(
              colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
              child: Opacity(opacity: 0.55, child: carta),
            ),
            Text(
              '?',
              style: TextStyle(
                color: _lila,
                fontSize: pequena ? 20 : 40,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
    }
  }
}
