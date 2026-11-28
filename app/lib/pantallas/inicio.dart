import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/campana.dart' show CatalogoCampana;
import 'package:incursiones_engine/incursiones_engine.dart';

import '../campana/catalogo_campana.dart';
import '../campana/controlador_campana.dart';
import '../campana/pantalla_campana.dart';
import '../cuenta/controlador_sesion.dart';
import '../cuenta/pantalla_login.dart';
import '../envios/botones_cuenta.dart';
import '../envios/controlador_envios.dart';
import '../partida/controlador_partida.dart';
import '../sala/pantalla_sala.dart';
import '../tienda/pantalla_tienda.dart';
import 'carta.dart';
import 'nueva_partida.dart';
import 'pantalla_pokedex.dart';
import 'setup.dart';

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

/// Pantalla de inicio: un bloque para la **partida rápida** y otro para la
/// **campaña**, cada uno con su «Continuar» y su «Nueva» (#585, decidido por
/// Ayme el 2026-11-28), y además sala, Pokédex, tienda y cuenta. En pantalla ancha (tablet, PC) es un menú de título con la carta
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

/// Abre el selector de modo y formato (#233). Nada se descarta hasta que se
/// pulsa «Empezar», así que se puede volver atrás sin perder la partida.
void _nuevaPartida(BuildContext context, WidgetRef ref) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const PantallaNuevaPartida()),
  );
}

/// Resumen de la campaña guardada, o null si no hay ninguna. Para usar
/// dentro de `build`.
String? _campanaGuardada(WidgetRef ref) {
  final p = ref.watch(campanaProvider.select((e) => e.partida));
  if (p == null) return null;
  final medallas = p.progreso.medallas.length;
  final equipo = p.equipo.length;
  if (equipo == 0) return 'Aún sin inicial';
  return '${medallas == 1 ? '1 medalla' : '$medallas medallas'} · '
      '${equipo == 1 ? '1 Pokémon' : '$equipo Pokémon'} en el equipo';
}

/// La campaña exige cuenta (D-20 §10.1). Sin sesión abre el inicio de sesión
/// y, al volver con sesión, sigue con lo que se había pulsado (#585).
/// Devuelve false si se vuelve sin iniciar sesión.
Future<bool> _conSesion(BuildContext context, WidgetRef ref) async {
  if (ref.read(sesionActualProvider) != null) return true;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const PantallaLogin()),
  );
  if (!context.mounted || ref.read(sesionActualProvider) == null) return false;
  // Con la sesión recién abierta se trae la campaña de la cuenta, si la hay,
  // antes de decidir si hay algo que continuar o que pisar.
  await ref.read(campanaProvider.notifier).sincronizar();
  return context.mounted;
}

void _abrirCampana(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const PantallaCampana()),
  );
}

/// «Continuar» del bloque de campaña: abre el mapa donde se dejó.
Future<void> continuarCampana(BuildContext context, WidgetRef ref) async {
  if (!await _conSesion(context, ref) || !context.mounted) return;
  if (ref.read(campanaProvider).partida == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Aún no has empezado una campaña.')),
    );
    return;
  }
  _abrirCampana(context);
}

/// «Nueva» del bloque de campaña: si ya hay una guardada pide confirmar antes
/// de pisarla (una sola campaña guardada, #585); después, a elegir inicial.
Future<void> nuevaCampana(BuildContext context, WidgetRef ref) async {
  if (!await _conSesion(context, ref) || !context.mounted) return;
  if (ref.read(campanaProvider).partida != null) {
    final pisar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Empezar una campaña nueva?'),
        content: const Text('Se perderá tu progreso actual.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            key: const Key('inicio-confirmar-nueva-campana'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Empezar de nuevo'),
          ),
        ],
      ),
    );
    if (pisar != true || !context.mounted) return;
  }
  final CatalogoCampana catalogo;
  try {
    catalogo = await ref.read(catalogoCampanaProvider.future);
  } catch (_) {
    // Sin catálogo, la pantalla de campaña explica el error.
    if (context.mounted) _abrirCampana(context);
    return;
  }
  if (!context.mounted) return;
  ref.read(campanaProvider.notifier).nueva(catalogo);
  _abrirCampana(context);
}

/// Último paso del selector: pide confirmar si hay una partida a medias, la
/// descarta y entra a la partida nueva. Devuelve false si se cancela.
Future<bool> empezarPartidaNueva(
  BuildContext context,
  WidgetRef ref, {
  ModoPreparacion modo = ModoPreparacion.equipo,
}) async {
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
    if (descartar != true) return false;
  }
  if (hay) ref.read(partidaProvider.notifier).nuevaPartida();
  ref.read(modoPreparacionProvider.notifier).fijar(modo);
  ref.read(jefePreelegidoProvider.notifier).fijar(null);
  ref.read(enPartidaProvider.notifier).entrar();
  return true;
}

void _tienda(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const PantallaTienda()),
  );
}

void _pokedex(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const PantallaPokedex()),
  );
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

/// Un modo del inicio (#585): su nombre, una línea con la partida guardada
/// (o por qué no se puede continuar) y sus botones «Continuar» y «Nueva».
class _BloqueModo extends StatelessWidget {
  const _BloqueModo({
    required this.clave,
    required this.titulo,
    required this.linea,
    required this.claveContinuar,
    required this.claveNueva,
    required this.onContinuar,
    required this.onNueva,
    this.jefe,
  });

  final String clave;
  final String titulo;
  final String linea;
  final String claveContinuar;
  final String claveNueva;

  /// null: «Continuar» sale apagado.
  final VoidCallback? onContinuar;
  final VoidCallback onNueva;

  /// Jefe de la partida rápida guardada, para su carta.
  final String? jefe;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key(clave),
      padding: const EdgeInsets.all(14),
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
              if (jefe != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Image.asset(
                    rutaCarta(jefe!),
                    width: 34,
                    height: 48,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(width: 34, height: 48),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo.toUpperCase(),
                      style: const TextStyle(
                        color: _amarillo,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      linea,
                      key: Key('$clave-linea'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _lila),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BotonBloque(
                  clave: claveContinuar,
                  etiqueta: 'Continuar',
                  semantica: 'Continuar $titulo',
                  icono: Icons.play_arrow_rounded,
                  principal: onContinuar != null,
                  onPressed: onContinuar,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BotonBloque(
                  clave: claveNueva,
                  etiqueta: 'Nueva',
                  semantica: 'Nueva $titulo',
                  icono: Icons.add_rounded,
                  principal: onContinuar == null,
                  onPressed: onNueva,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Botón de un bloque del inicio; con [onPressed] null sale apagado.
class _BotonBloque extends StatelessWidget {
  const _BotonBloque({
    required this.clave,
    required this.etiqueta,
    required this.semantica,
    required this.icono,
    required this.onPressed,
    this.principal = false,
  });

  final String clave;
  final String etiqueta;
  final String semantica;
  final IconData icono;
  final VoidCallback? onPressed;
  final bool principal;

  @override
  Widget build(BuildContext context) {
    final apagado = onPressed == null;
    final fondo = apagado
        ? _moradoClaro.withValues(alpha: 0.5)
        : principal
            ? _amarillo
            : _moradoClaro;
    final texto = apagado
        ? _lila.withValues(alpha: 0.6)
        : principal
            ? _morado
            : Colors.white;
    return Semantics(
      button: true,
      enabled: !apagado,
      label: semantica,
      excludeSemantics: true,
      child: Material(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: Key(clave),
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: apagado ? Colors.white38 : Colors.white,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icono, color: texto, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    etiqueta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: texto,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
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

/// Los dos bloques del inicio: partida rápida y campaña (#585).
class _BloquesModo extends ConsumerWidget {
  const _BloquesModo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rapida = _partidaGuardada(ref);
    final campana = _campanaGuardada(ref);
    final conSesion = ref.watch(sesionActualProvider) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BloqueModo(
          clave: 'inicio-bloque-rapida',
          titulo: 'Partida rápida',
          linea: rapida == null
              ? 'No hay ninguna partida a medias'
              : '${rapida.titulo} · ${rapida.detalle}',
          jefe: rapida?.jefe,
          claveContinuar: 'inicio-continuar',
          claveNueva: 'inicio-nueva',
          onContinuar: rapida == null
              ? null
              : () => ref.read(enPartidaProvider.notifier).entrar(),
          onNueva: () => _nuevaPartida(context, ref),
        ),
        const SizedBox(height: 14),
        _BloqueModo(
          clave: 'inicio-bloque-campana',
          titulo: 'Campaña',
          linea: campana ??
              (conSesion
                  ? 'Aún no has empezado una campaña'
                  : 'Inicia sesión para jugar la campaña'),
          claveContinuar: 'inicio-continuar-campana',
          claveNueva: 'inicio-nueva-campana',
          // Sin sesión, los dos llevan al inicio de sesión (la campaña
          // guardada puede estar en la cuenta).
          onContinuar: campana == null && conSesion
              ? null
              : () => continuarCampana(context, ref),
          onNueva: () => nuevaCampana(context, ref),
        ),
      ],
    );
  }
}

/// Menú de título (tablet y PC): menú a la izquierda, Arceus a la derecha.
class _MenuTitulo extends StatelessWidget {
  const _MenuTitulo({required this.alto});

  final double alto;

  @override
  Widget build(BuildContext context) {
    final altoCarta = (alto - 96).clamp(160.0, 475.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 40, 72, 32),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(
              width: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Logo(tamano: 52),
                  SizedBox(height: 24),
                  _BloquesModo(),
                  SizedBox(height: 14),
                  _Mosaicos(),
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

/// Inicio en móvil: logo arriba, los bloques de partida rápida y campaña y
/// las demás opciones abajo, sobre el mapa de fondo.
class _MenuMovil extends StatelessWidget {
  const _MenuMovil();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: IntrinsicHeight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Logo(tamano: 40),
            Spacer(),
            _BloquesModo(),
            SizedBox(height: 12),
            _Mosaicos(),
          ],
        ),
      ),
    );
  }
}

/// Sala, tienda, Pokédex y cuenta, en dos filas de dos.
class _Mosaicos extends ConsumerWidget {
  const _Mosaicos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _MosaicoInicio(
                clave: 'inicio-sala',
                etiqueta: 'Jugar en sala',
                detalle: 'Con otros dispositivos',
                icono: Icons.groups_rounded,
                onPressed: () => abrirSala(context, ref),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MosaicoInicio(
                clave: 'inicio-tienda',
                etiqueta: 'Tienda',
                detalle: 'Con tus puntos',
                icono: Icons.storefront_rounded,
                onPressed: () => _tienda(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
