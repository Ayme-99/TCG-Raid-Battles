import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../partida/controlador_partida.dart';
import 'carta.dart';
import 'comun.dart';
import 'estilo.dart';

/// El jefe: vida, estados alterados y curación.
class TarjetaJefe extends ConsumerWidget {
  const TarjetaJefe({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoProvider);
    final jefe = estado.jefe;
    if (jefe == null) return const SizedBox.shrink();
    final color = colorNivel(jefe.nivel);
    final reduccion = reduccionDanoAlJefe(estado);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // La carta del jefe, grande y con el aura de su nivel.
        CartaImagen(
          nombre: jefe.nombre,
          brillo: color,
          alternativa: _CartaSinImagen(
            nombre: jefe.nombre,
            nivel: jefe.nivel,
            color: color,
          ),
        ),
        const SizedBox(height: 12),
        // Lo que cambia durante la partida: vida, estados y curación.
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1033).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${jefe.nombre} · Nv. ${jefe.nivel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    if (jefe.envenenado)
                      const _EtiquetaEstado(
                        icono: Icons.science,
                        texto: 'Envenenado',
                        color: Color(0xFFE1BEE7),
                      ),
                    if (jefe.quemado)
                      const _EtiquetaEstado(
                        icono: Icons.whatshot,
                        texto: 'Quemado',
                        color: Color(0xFFFFCCBC),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                BarraVida(
                  fraccion: jefe.hpMaximo == 0 ? 0 : jefe.hp / jefe.hpMaximo,
                  alto: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  'HP ${jefe.hp} / ${jefe.hpMaximo}',
                  key: const Key('hp-jefe'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                if (reduccion > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Los jugadores hacen $reduccion de daño menos al jefe '
                      '(lo descuenta la app).',
                      key: const Key('reduccion-dano'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 8),
                ActionChip(
                  key: const Key('curar-jefe'),
                  avatar: const Icon(Icons.favorite, color: Colors.green),
                  label: const Text('Curar al jefe'),
                  onPressed: () async {
                    final cantidad = await pedirNumero(
                      context,
                      titulo: 'Curar al jefe',
                      etiqueta: 'HP que recupera',
                    );
                    if (cantidad == null || !context.mounted) return;
                    registrar(context, ref, CuracionJefe(cantidad));
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Estado alterado del jefe, en una etiqueta pequeña junto a su nombre.
class _EtiquetaEstado extends StatelessWidget {
  const _EtiquetaEstado({
    required this.icono,
    required this.texto,
    required this.color,
  });

  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: const Color(0xFF4A148C)),
          const SizedBox(width: 4),
          Text(
            texto,
            style: const TextStyle(
              color: Color(0xFF4A148C),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lo que se ve mientras el jefe no tiene todavía su imagen.
class _CartaSinImagen extends StatelessWidget {
  const _CartaSinImagen({
    required this.nombre,
    required this.nivel,
    required this.color,
  });

  final String nombre;
  final int nivel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.black, 0.15)!, const Color(0xFF1A1033)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 4),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: FittedBox(
        child: Text(
          '$nombre\nNv. $nivel',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
