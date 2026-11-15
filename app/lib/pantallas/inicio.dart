import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../cuenta/controlador_sesion.dart';
import '../envios/botones_cuenta.dart';
import '../envios/controlador_envios.dart';
import '../partida/controlador_partida.dart';
import 'carta.dart';

/// Si la app está en la partida o en la pantalla de inicio (#232). Al abrir
/// siempre se ve el inicio; los tests pueden arrancar ya dentro de la partida.
class EnPartida extends Notifier<bool> {
  EnPartida([this.inicial = false]);

  final bool inicial;

  @override
  bool build() => inicial;

  void entrar() => state = true;

  void salir() => state = false;
}

final enPartidaProvider =
    NotifierProvider<EnPartida, bool>(() => EnPartida());

const _morado = Color(0xFF1B1235);
const _moradoClaro = Color(0xFF2A1D52);
const _amarillo = Color(0xFFFFC400);
const _lila = Color(0xFFE6DDF7);

/// Pantalla de inicio: nueva partida, continuar la que quedó a medias, Pokédex
/// y cuenta. En pantalla ancha (tablet, PC) es un menú de título con la carta
/// de Arceus; en móvil, el mapa de fondo con la partida guardada arriba.
class PantallaInicio extends ConsumerWidget {
  const PantallaInicio({super.key});

  /// Ancho a partir del cual se usa el menú de título.
  static const anchoMenuTitulo = 700.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ancho = MediaQuery.of(context).size.width;
    final menuTitulo = ancho >= anchoMenuTitulo;
    return Scaffold(
      key: const Key('inicio'),
      backgroundColor: _morado,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            menuTitulo
                ? 'assets/mapas/sala-origen.webp'
                : 'assets/mapas/ruta-110.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: _morado),
          ),
          ColoredBox(color: _morado.withValues(alpha: menuTitulo ? 0.35 : 0.45)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, caja) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: caja.maxHeight),
                  child: menuTitulo
                      ? _MenuTitulo(alto: caja.maxHeight)
                      : const _MenuMovil(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Resumen de la partida guardada.
class _Guardada {
  const _Guardada({required this.titulo, required this.detalle, this.jefe});

  final String titulo;
  final String detalle;

  /// Nombre del jefe, para su carta; null si aún no se ha elegido.
  final String? jefe;
}

/// La partida que se puede continuar, o null si no hay ninguna: sin eventos
/// no hay nada guardado, y una terminada cuyos resultados ya se guardaron no
/// tiene nada pendiente.
_Guardada? _resumen(Historial historial, EstadoPartida estado, bool guardada) {
  if (historial.partida.eventos.isEmpty) return null;
  if (estado.terminada && guardada) return null;
  final jugadores = estado.jugadores.length;
  final texto = jugadores == 1 ? '1 jugador' : '$jugadores jugadores';
  final jefe = estado.jefe;
  if (jefe == null) {
    return _Guardada(titulo: 'Preparando la partida', detalle: texto);
  }
  return _Guardada(
    titulo: '${jefe.nombre} · Nv. ${jefe.nivel}',
    detalle: estado.terminada
        ? 'Terminada, sin guardar · $texto'
        : 'Ronda ${estado.ronda} · $texto',
    jefe: jefe.nombre,
  );
}

/// Para usar dentro de `build`: se redibuja si cambia la partida.
_Guardada? _partidaGuardada(WidgetRef ref) => _resumen(
      ref.watch(partidaProvider),
      ref.watch(estadoProvider),
      ref.watch(enviosProvider.select((e) => e.partidaEncolada != null)),
    );

Future<void> _nuevaPartida(BuildContext context, WidgetRef ref) async {
  final hay = ref.read(partidaProvider).partida.eventos.isNotEmpty;
  final pendiente = _resumen(
    ref.read(partidaProvider),
    ref.read(estadoProvider),
    ref.read(enviosProvider).partidaEncolada != null,
  );
  if (hay && pendiente != null) {
    final descartar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Empezar una partida nueva?'),
        content: const Text(
          'Hay una partida a medias. Si empiezas otra, se descarta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            key: const Key('descartar-partida'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (descartar != true) return;
  }
  if (hay) ref.read(partidaProvider.notifier).nuevaPartida();
  ref.read(enPartidaProvider.notifier).entrar();
}

void _pokedex(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('El Pokédex llega pronto.')));
}

String _textoCuenta(WidgetRef ref) {
  final sesion = ref.watch(sesionActualProvider);
  return sesion == null ? 'Sin sesión' : 'Sesión de ${sesion.username}';
}

class _Logo extends StatelessWidget {
  const _Logo({required this.tamano});

  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INCURSIONES',
          style: TextStyle(
            color: Colors.white,
            fontSize: tamano,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            height: 1,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Raids cooperativos de Pokémon TCG',
          style: TextStyle(
            color: _lila,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
      ],
    );
  }
}

/// Botón grande del inicio. [principal]: amarillo; si no, morado con borde.
class _BotonInicio extends StatelessWidget {
  const _BotonInicio({
    required this.clave,
    required this.etiqueta,
    required this.icono,
    required this.onPressed,
    this.detalle,
    this.principal = false,
    this.alto = 64,
  });

  final String clave;
  final String etiqueta;
  final String? detalle;
  final IconData icono;
  final VoidCallback onPressed;
  final bool principal;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final fondo = principal ? _amarillo : _moradoClaro;
    final texto = principal ? _morado : Colors.white;
    return Semantics(
      button: true,
      label: etiqueta,
      excludeSemantics: true,
      child: Material(
        color: fondo,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: Key(clave),
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Container(
            constraints: BoxConstraints(minHeight: alto),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: principal
                  ? const [BoxShadow(color: Color(0xFFA57F00), offset: Offset(0, 4))]
                  : null,
            ),
            child: Row(
              children: [
                Icon(icono, color: texto, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        etiqueta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: texto,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (detalle != null)
                        Text(
                          detalle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: principal ? const Color(0xFF4A3B00) : _lila,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Menú de título (tablet y PC): menú a la izquierda, Arceus a la derecha.
class _MenuTitulo extends ConsumerWidget {
  const _MenuTitulo({required this.alto});

  final double alto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guardada = _partidaGuardada(ref);
    final altoCarta = (alto - 96).clamp(160.0, 475.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 56, 72, 40),
      child: IntrinsicHeight(
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Logo(tamano: 52),
                const SizedBox(height: 48),
                if (guardada != null) ...[
                  _BotonInicio(
                    clave: 'inicio-continuar',
                    etiqueta: 'Continuar',
                    detalle: '${guardada.titulo} · ${guardada.detalle}',
                    icono: Icons.play_arrow_rounded,
                    principal: true,
                    alto: 84,
                    onPressed: () =>
                        ref.read(enPartidaProvider.notifier).entrar(),
                  ),
                  const SizedBox(height: 16),
                ],
                _BotonInicio(
                  clave: 'inicio-nueva',
                  etiqueta: 'Nueva partida',
                  detalle: 'Elige modo y jefe',
                  icono: Icons.add_rounded,
                  principal: guardada == null,
                  alto: 84,
                  onPressed: () => _nuevaPartida(context, ref),
                ),
                const SizedBox(height: 16),
                _BotonInicio(
                  clave: 'inicio-pokedex',
                  etiqueta: 'Pokédex',
                  detalle: 'Jefes y aliados enfrentados',
                  icono: Icons.catching_pokemon,
                  alto: 84,
                  onPressed: () => _pokedex(context),
                ),
                const SizedBox(height: 16),
                _BotonInicio(
                  clave: 'inicio-cuenta',
                  etiqueta: 'Cuenta',
                  detalle: _textoCuenta(ref),
                  icono: Icons.account_circle_outlined,
                  alto: 84,
                  onPressed: () => abrirCuenta(context, ref),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Transform.rotate(
                angle: 0.07,
                child: SizedBox(
                  width: altoCarta * 480 / 670,
                  height: altoCarta,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        rutaCarta('Arceus'),
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

/// Inicio en móvil: logo arriba, la partida guardada y las demás opciones
/// abajo, sobre el mapa de fondo.
class _MenuMovil extends ConsumerWidget {
  const _MenuMovil();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guardada = _partidaGuardada(ref);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: IntrinsicHeight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Logo(tamano: 40),
            const Spacer(),
            if (guardada != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _morado.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (guardada.jefe != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.asset(
                              rutaCarta(guardada.jefe!),
                              width: 52,
                              height: 73,
                              fit: BoxFit.cover,
                              excludeFromSemantics: true,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox(width: 52, height: 73),
                            ),
                          ),
                          const SizedBox(width: 14),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PARTIDA A MEDIAS',
                                style: TextStyle(
                                  color: _amarillo,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                guardada.titulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                guardada.detalle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: _lila),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _BotonInicio(
                      clave: 'inicio-continuar',
                      etiqueta: 'Continuar',
                      icono: Icons.play_arrow_rounded,
                      principal: true,
                      onPressed: () =>
                          ref.read(enPartidaProvider.notifier).entrar(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _BotonInicio(
              clave: 'inicio-nueva',
              etiqueta: 'Nueva partida',
              icono: Icons.add_rounded,
              principal: guardada == null,
              onPressed: () => _nuevaPartida(context, ref),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MosaicoInicio(
                    clave: 'inicio-pokedex',
                    etiqueta: 'Pokédex',
                    detalle: 'Jefes y aliados',
                    icono: Icons.catching_pokemon,
                    onPressed: () => _pokedex(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MosaicoInicio(
                    clave: 'inicio-cuenta',
                    etiqueta: 'Cuenta',
                    detalle: _textoCuenta(ref),
                    icono: Icons.account_circle_outlined,
                    onPressed: () => abrirCuenta(context, ref),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MosaicoInicio extends StatelessWidget {
  const _MosaicoInicio({
    required this.clave,
    required this.etiqueta,
    required this.detalle,
    required this.icono,
    required this.onPressed,
  });

  final String clave;
  final String etiqueta;
  final String detalle;
  final IconData icono;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _morado.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key(clave),
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, color: _amarillo),
              const SizedBox(height: 6),
              Text(
                etiqueta,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                detalle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _lila, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
