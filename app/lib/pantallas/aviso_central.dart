import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Qué ha pasado: decide el color, el icono y el titular del aviso.
enum TipoAviso { info, ko, danio, cura, fallo, esquiva, error }

/// Un suceso de la partida, listo para mostrarse: de qué o de quién habla
/// ([nombre]), qué ha pasado ([titulo], en grande) y por qué ([motivo]).
class Aviso {
  const Aviso({
    required this.tipo,
    this.nombre,
    required this.titulo,
    this.motivo,
  });

  final TipoAviso tipo;
  final String? nombre;
  final String titulo;
  final String? motivo;

  /// Convierte un texto suelto («Magikarp: Jugador 2 está KO, el ataque
  /// falla.») en un aviso: el nombre antes de los dos puntos, el tipo según
  /// lo que cuente y el resto como motivo.
  factory Aviso.deTexto(String texto, {TipoAviso? tipo}) {
    final t = texto.trim();
    final m = RegExp(r'^([^:.\n]{1,28}): (.+)$', dotAll: true).firstMatch(t);
    // «Daño total: 80», «Moneda: cara»…: lo de antes de los dos puntos no es
    // el nombre de nadie.
    final esEtiqueta = m != null &&
        RegExp(r'^(daño|moneda|potenciador|se cumple)', caseSensitive: false)
            .hasMatch(m.group(1)!);
    final nombre = esEtiqueta ? null : m?.group(1)?.toUpperCase();
    var motivo = (m != null && !esEtiqueta ? m.group(2)! : t).trim();
    if (motivo.endsWith('.') && !motivo.endsWith('..')) {
      motivo = motivo.substring(0, motivo.length - 1);
    }
    final bajo = t.toLowerCase();
    final tp = tipo ??
        (bajo.contains('se evita')
            ? TipoAviso.esquiva
            : bajo.contains('falla') || bajo.contains('no se invoca')
                ? TipoAviso.fallo
                : RegExp(r'\bko\b|derrotad|\bcae\b|cae el').hasMatch(bajo)
                    ? TipoAviso.ko
                    : bajo.contains('cura') || bajo.contains('recupera')
                        ? TipoAviso.cura
                        : bajo.contains('daño')
                            ? TipoAviso.danio
                            : TipoAviso.info);
    return Aviso(
      tipo: tp,
      nombre: nombre,
      titulo: _titular(tp, bajo),
      motivo: motivo,
    );
  }
}

String _titular(TipoAviso t, String bajo) => switch (t) {
      TipoAviso.ko => '¡KO!',
      TipoAviso.danio => '¡DAÑO!',
      TipoAviso.cura => '¡CURACIÓN!',
      TipoAviso.fallo =>
        bajo.contains('ataque falla') ? '¡EL ATAQUE FALLA!' : '¡NO PUEDE SER!',
      TipoAviso.esquiva => '¡SE EVITA!',
      TipoAviso.error => 'NO SE PUEDE',
      TipoAviso.info => 'AVISO',
    };

class _Estilo {
  const _Estilo(this.color, this.oscuro, this.icono);
  final Color color;
  final Color oscuro;
  final IconData icono;
}

const _estilos = {
  TipoAviso.ko: _Estilo(Color(0xFFFF5A5F), Color(0xFF5E1220), Icons.heart_broken),
  TipoAviso.danio: _Estilo(Color(0xFFFFA726), Color(0xFF5A2E06), Icons.bolt),
  TipoAviso.cura: _Estilo(Color(0xFF3DDC84), Color(0xFF0E4A2A), Icons.favorite),
  TipoAviso.fallo: _Estilo(Color(0xFF9AA7BA), Color(0xFF2B3445), Icons.block),
  TipoAviso.esquiva: _Estilo(Color(0xFF9AA7BA), Color(0xFF2B3445), Icons.shield),
  TipoAviso.info:
      _Estilo(Color(0xFF4DA3FF), Color(0xFF16335F), Icons.notifications_active),
  TipoAviso.error:
      _Estilo(Color(0xFFFF7043), Color(0xFF5A1E10), Icons.warning_amber_rounded),
};

/// Lo que dura un aviso: más cuanto más hay que leer.
Duration duracionAviso(Aviso a) {
  final letras = (a.motivo?.length ?? 0) + a.titulo.length;
  final ms = (2400 + 40 * letras).clamp(2400, 7000);
  return Duration(milliseconds: ms);
}

class _Pendiente {
  _Pendiente(this.overlay, this.aviso);
  final OverlayState overlay;
  final Aviso aviso;
}

OverlayEntry? _actual;
final List<_Pendiente> _cola = [];

/// Cuántos avisos esperan su turno (sin contar el que se ve).
int avisosEnCola() => _cola.length;

void _quitarActual() {
  final e = _actual;
  _actual = null;
  if (e == null) return;
  try {
    e.remove();
    e.dispose();
  } catch (_) {
    // Su Overlay ya se había ido (la pantalla se cerró): nada que quitar.
  }
}

void _siguiente() {
  if (_actual != null) return;
  while (_cola.isNotEmpty) {
    final p = _cola.removeAt(0);
    if (!p.overlay.mounted) continue;
    late final OverlayEntry entrada;
    entrada = OverlayEntry(
      builder: (_) => _AvisoCentral(
        aviso: p.aviso,
        duracion: duracionAviso(p.aviso),
        alCerrar: () {
          if (!identical(_actual, entrada)) return;
          _quitarActual();
          _siguiente();
        },
      ),
    );
    _actual = entrada;
    p.overlay.insert(entrada);
    return;
  }
}

/// Pone [aviso] en la cola: salen de uno en uno, en medio de la pantalla, sin
/// tapar ni bloquear los controles. Los de tipo error pasan por delante y
/// tiran la cola (es la respuesta a lo que se acaba de intentar).
void mostrarAvisoCentral(BuildContext context, Aviso aviso) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  if (aviso.tipo == TipoAviso.error) {
    _cola.clear();
    _quitarActual();
  }
  _cola.add(_Pendiente(overlay, aviso));
  _siguiente();
}

class _AvisoCentral extends StatefulWidget {
  const _AvisoCentral({
    required this.aviso,
    required this.duracion,
    required this.alCerrar,
  });

  final Aviso aviso;
  final Duration duracion;
  final VoidCallback alCerrar;

  @override
  State<_AvisoCentral> createState() => _EstadoAviso();
}

class _EstadoAviso extends State<_AvisoCentral> with TickerProviderStateMixin {
  // Toda la vida del aviso (los brillos, el pulso y la barra salen de aquí).
  late final AnimationController _vida =
      AnimationController(vsync: this, duration: widget.duracion);
  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final AnimationController _salida = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  var _cerrando = false;
  var _sinMovimiento = false;
  var _arrancado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sinMovimiento = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_arrancado) return;
    _arrancado = true;
    if (_sinMovimiento) {
      _entrada.value = 1;
    } else {
      _entrada.forward();
    }
    _vida.forward().whenComplete(_cerrar);
  }

  Future<void> _cerrar() async {
    if (_cerrando || !mounted) return;
    _cerrando = true;
    _vida.stop();
    if (!_sinMovimiento) await _salida.forward();
    widget.alCerrar();
  }

  @override
  void dispose() {
    _vida.dispose();
    _entrada.dispose();
    _salida.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.aviso;
    final est = _estilos[a.tipo]!;
    final texto = [a.nombre, a.titulo, a.motivo].whereType<String>().join('. ');
    return Positioned.fill(
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Semantics(
                liveRegion: true,
                label: texto,
                child: ExcludeSemantics(
                  child: GestureDetector(
                    key: const Key('aviso'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _cerrar,
                    // Sin un Material encima, el texto de un Overlay sale con
                    // el subrayado amarillo de «sin estilo».
                    child: Material(
                      type: MaterialType.transparency,
                      child: AnimatedBuilder(
                      animation:
                          Listenable.merge([_vida, _entrada, _salida]),
                      builder: (context, _) => _Cartel(
                        aviso: a,
                        estilo: est,
                        // Milisegundos desde que apareció.
                        ms: _vida.value * widget.duracion.inMilliseconds,
                        progreso: _vida.value,
                        entrada: _entrada.value,
                        salida: _salida.value,
                        animado: !_sinMovimiento,
                      ),
                    ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _suave(double t) => t * t * (3 - 2 * t);

/// El aviso dibujado en el instante [ms] de su vida (estilo «Cartel»: banda
/// inclinada con una medalla que sobresale por la izquierda).
class _Cartel extends StatelessWidget {
  const _Cartel({
    required this.aviso,
    required this.estilo,
    required this.ms,
    required this.progreso,
    required this.entrada,
    required this.salida,
    required this.animado,
  });

  final Aviso aviso;
  final _Estilo estilo;
  final double ms;
  final double progreso;
  final double entrada;
  final double salida;
  final bool animado;

  static const _inclinacion = 0.1405; // tan(8°)

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final compacto = w < 480;
        final medalla = compacto ? 76.0 : 100.0;
        final izq = compacto ? 30.0 : 44.0;
        final alto = compacto ? 108.0 : 122.0;
        final textoIzq = izq + (compacto ? 82 : 94);
        final fNombre = compacto ? 12.0 : 15.0;
        final fTitulo = compacto ? 32.0 : 46.0;
        final fMotivo = compacto ? 13.5 : 17.0;

        // Entrada: se desliza desde la izquierda con rebote.
        final t = entrada.clamp(0.0, 1.0);
        final dx = t < .6
            ? -160 + 176 * Curves.easeOut.transform(t / .6)
            : 16 * (1 - _suave((t - .6) / .4));
        final esc = t < .6
            ? .85 + .19 * Curves.easeOut.transform(t / .6)
            : 1.04 - .04 * _suave((t - .6) / .4);
        final opac = (t / .3).clamp(0.0, 1.0) * (1 - salida);

        // Temblor tras la entrada, solo en golpes.
        var temblor = 0.0;
        if (animado &&
            (aviso.tipo == TipoAviso.ko || aviso.tipo == TipoAviso.danio)) {
          final u = ((ms - 400) / 450).clamp(0.0, 1.0);
          if (u > 0 && u < 1) temblor = 11 * (1 - u) * math.sin(u * 5 * math.pi);
        }

        // Pulso de la medalla y balanceo del icono.
        final pulso = animado ? 1 + .05 * math.sin(ms / 1000 * 2 * math.pi) : 1.0;
        final giro = animado ? .09 * math.sin(ms / 800 * 2 * math.pi) : 0.0;
        // Onda que sale de la medalla al aparecer.
        final u = ((ms - 250) / 700).clamp(0.0, 1.0);
        final onda = animado && ms > 250 && u < 1;

        // Brillo que cruza la banda cada poco.
        final fase = (ms % 1800) / 1800;
        final brillo = animado && fase < .55 ? fase / .55 : -1.0;

        final banda = Transform(
          alignment: Alignment.center,
          transform: Matrix4.skewX(-_inclinacion),
          child: Container(
            height: alto,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), offset: Offset(0, 9)),
                BoxShadow(color: Color(0x73000000), blurRadius: 40, offset: Offset(0, 20)),
              ],
              gradient: LinearGradient(
                colors: [
                  estilo.color,
                  estilo.color,
                  estilo.oscuro,
                  estilo.oscuro,
                ],
                stops: const [0, .23, .23, 1],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  if (brillo >= 0)
                    Positioned(
                      left: -80 + (w + 160) * brillo,
                      top: 0,
                      bottom: 0,
                      width: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: .22),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 7,
                    child: ColoredBox(
                      color: const Color(0x59000000),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: (1 - progreso).clamp(0.0, 1.0),
                          child: ColoredBox(color: estilo.color),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final textos = Padding(
          padding: EdgeInsets.only(
            left: textoIzq,
            right: compacto ? 14 : 22,
            top: 4,
            bottom: 8,
          ),
          child: SizedBox(
            height: alto,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aviso.nombre != null)
                  Text(
                    aviso.nombre!,
                    key: const Key('aviso-nombre'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Blanco y no el color del aviso: las primeras letras caen
                    // sobre la franja de ese mismo color y desaparecían.
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .92),
                      fontSize: fNombre,
                      fontWeight: FontWeight.w900,
                      letterSpacing: fNombre * .2,
                      shadows: const [
                        Shadow(color: Color(0x73000000), offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    aviso.titulo,
                    key: const Key('aviso-titulo'),
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fTitulo,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      shadows: const [
                        Shadow(color: Color(0x73000000), offset: Offset(0, 3)),
                      ],
                    ),
                  ),
                ),
                if (aviso.motivo != null)
                  Text(
                    aviso.motivo!,
                    key: const Key('aviso-texto'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .92),
                      fontSize: fMotivo,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
              ],
            ),
          ),
        );

        final medallon = SizedBox(
          width: medalla,
          height: medalla,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (onda)
                Opacity(
                  opacity: (.95 * (1 - u)).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: .6 + 1.4 * u,
                    child: Container(
                      width: medalla,
                      height: medalla,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: estilo.color, width: 4),
                      ),
                    ),
                  ),
                ),
              Transform.scale(
                scale: pulso,
                child: Container(
                  width: medalla,
                  height: medalla,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: estilo.color,
                    border: Border.all(color: Colors.white, width: 5),
                    boxShadow: [
                      BoxShadow(color: estilo.oscuro, offset: const Offset(0, 5)),
                      const BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 22,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Transform.rotate(
                    angle: giro,
                    child: Icon(
                      estilo.icono,
                      size: medalla * .54,
                      color: const Color(0xFF10131C),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        return Opacity(
          opacity: opac,
          child: Transform.translate(
            offset: Offset(dx + temblor, -26 * salida),
            child: Transform.scale(
              scale: esc * (1 - .04 * salida),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: izq, top: 4),
                    child: banda,
                  ),
                  Positioned.fill(child: textos),
                  Positioned(left: 0, top: 14, child: medallon),
                  // Reserva el alto del cartel para centrarlo bien.
                  SizedBox(height: alto + 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
