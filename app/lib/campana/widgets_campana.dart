import 'package:flutter/material.dart';
import 'package:incursiones_engine/campana.dart';

import '../pantallas/estilo.dart' show BarraVida;

/// Color de cada tipo de campaña, para las fichas y los botones de ataque.
Color colorTipo(TipoCampana t) => switch (t) {
      TipoCampana.normal => const Color(0xFF9E9E9E),
      TipoCampana.fuego => const Color(0xFFE53935),
      TipoCampana.agua => const Color(0xFF1E88E5),
      TipoCampana.planta => const Color(0xFF43A047),
      TipoCampana.electrico => const Color(0xFFFDD835),
      TipoCampana.lucha => const Color(0xFF8D6E63),
      TipoCampana.psiquico => const Color(0xFFEC407A),
      TipoCampana.oscuridad => const Color(0xFF455A64),
      TipoCampana.dragon => const Color(0xFF3949AB),
    };

/// Nombre de cada tipo para mostrarlo.
String nombreTipo(TipoCampana t) => switch (t) {
      TipoCampana.electrico => 'eléctrico',
      TipoCampana.psiquico => 'psíquico',
      TipoCampana.dragon => 'dragón',
      _ => t.name,
    };

/// La imagen de la carta (`assets/campana/cartas/<id>.webp`) o, si todavía no
/// existe, un hueco del color de su tipo con el nombre.
class ImagenCartaCampana extends StatelessWidget {
  const ImagenCartaCampana({super.key, required this.especie, this.ancho = 96});

  final PokemonCampana especie;
  final double ancho;

  @override
  Widget build(BuildContext context) {
    final hueco = Container(
      width: ancho,
      height: ancho * 670 / 480,
      decoration: BoxDecoration(
        color: colorTipo(especie.tipo).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorTipo(especie.tipo), width: 2),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      child: Text(especie.nombre,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/campana/cartas/${especie.id}.webp',
        width: ancho,
        height: ancho * 670 / 480,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => hueco,
      ),
    );
  }
}

/// Ficha de un Pokémon: nombre, tipo y barra de PS.
class FichaPokemon extends StatelessWidget {
  const FichaPokemon({
    super.key,
    required this.especie,
    required this.ps,
    this.detalle,
    this.destacada = false,
    this.onTap,
  });

  final PokemonCampana especie;
  final int ps;
  final String? detalle;
  final bool destacada;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      elevation: destacada ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: destacada
            ? BorderSide(color: tema.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                        radius: 6, backgroundColor: colorTipo(especie.tipo)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(especie.nombre,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                BarraVida(fraccion: ps / especie.ps, alto: 10),
                const SizedBox(height: 4),
                Text(
                  ps > 0 ? '$ps / ${especie.ps} PS' : 'Fuera de combate',
                  style: tema.textTheme.bodySmall,
                ),
                if (detalle != null)
                  Text(detalle!, style: tema.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Resumen de la carta: tipo, debilidad, resistencia, retirada y ataques.
String resumenCarta(PokemonCampana p) {
  final partes = <String>[
    '${nombreTipo(p.tipo)} · ${p.ps} PS',
    if (p.debilidad != null)
      'débil a ${nombreTipo(p.debilidad!.tipo)} ×${p.debilidad!.multiplicador}',
    if (p.resistencia != null)
      'resiste ${nombreTipo(p.resistencia!.tipo)} −${p.resistencia!.reduccion}',
    'retirada ${p.retirada}',
  ];
  return partes.join(' · ');
}

String textoAtaque(AtaqueCampana a) =>
    '${a.nombre} · coste ${a.coste} · ${a.dano} de daño';
