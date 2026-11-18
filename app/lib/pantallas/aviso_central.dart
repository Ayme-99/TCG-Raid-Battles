import 'dart:async';

import 'package:flutter/material.dart';

/// Qué ha pasado, para elegir el icono del aviso.
enum TipoAviso { info, error }

/// Aviso que se muestra ahora mismo (solo hay uno: uno nuevo sustituye al
/// anterior).
OverlayEntry? _actual;

/// Segundos que se queda un aviso: más cuantas más líneas, para dar tiempo a
/// leerlo.
Duration duracionAviso(String mensaje) {
  final lineas = '\n'.allMatches(mensaje).length + 1;
  final segundos = (3 + 1.5 * (lineas - 1)).clamp(3.0, 10.0);
  return Duration(milliseconds: (segundos * 1000).round());
}

void _quitar() {
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

/// Muestra [mensaje] en medio de la pantalla, por encima de todo, sin tapar
/// ni bloquear lo que hay fuera de él. Se cierra solo o al tocarlo.
void mostrarAvisoCentral(
  BuildContext context,
  String mensaje, {
  TipoAviso tipo = TipoAviso.info,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _quitar();
  late final OverlayEntry entrada;
  entrada = OverlayEntry(
    builder: (_) => _AvisoCentral(
      mensaje: mensaje,
      tipo: tipo,
      duracion: duracionAviso(mensaje),
      alCerrar: () {
        if (identical(_actual, entrada)) _quitar();
      },
    ),
  );
  _actual = entrada;
  overlay.insert(entrada);
}

class _AvisoCentral extends StatefulWidget {
  const _AvisoCentral({
    required this.mensaje,
    required this.tipo,
    required this.duracion,
    required this.alCerrar,
  });

  final String mensaje;
  final TipoAviso tipo;
  final Duration duracion;
  final VoidCallback alCerrar;

  @override
  State<_AvisoCentral> createState() => _EstadoAviso();
}

class _EstadoAviso extends State<_AvisoCentral>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Timer? _temporizador;
  var _cerrando = false;
  var _sinMovimiento = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // «Reducir movimiento»: sin animación, solo aparece y desaparece.
    final sin = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final primera = !_anim.isAnimating && _anim.value == 0 && !_cerrando;
    _sinMovimiento = sin;
    if (primera) {
      if (sin) {
        _anim.value = 1;
      } else {
        _anim.forward();
      }
      _temporizador = Timer(widget.duracion, _cerrar);
    }
  }

  Future<void> _cerrar() async {
    if (_cerrando) return;
    _cerrando = true;
    _temporizador?.cancel();
    if (!_sinMovimiento && mounted) {
      await _anim.reverse();
    }
    widget.alCerrar();
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.tipo == TipoAviso.error;
    final color = error ? const Color(0xFFFF8A80) : const Color(0xFFFFE082);
    return Positioned.fill(
      child: SafeArea(
        child: Center(
          // Solo el propio aviso recibe toques; el resto de la pantalla sigue
          // siendo de los controles de debajo.
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: FadeTransition(
                opacity: _anim,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1).animate(
                    CurvedAnimation(parent: _anim, curve: Curves.easeOutBack),
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: GestureDetector(
                      key: const Key('aviso'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _cerrar,
                      child: Material(
                        type: MaterialType.transparency,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xF21B1235),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white38, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black54, blurRadius: 14),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                error
                                    ? Icons.error_outline
                                    : Icons.info_outline,
                                color: color,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  widget.mensaje,
                                  key: const Key('aviso-texto'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}
