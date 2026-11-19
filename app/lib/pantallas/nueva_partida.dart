import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:incursiones_engine/incursiones_engine.dart';

import 'fondo_menu.dart';
import 'inicio.dart';

const _morado = Color(0xFF1B1235);
const _moradoClaro = Color(0xFF2A1D52);
const _amarillo = Color(0xFFFFC400);
const _lila = Color(0xFFE6DDF7);

/// Selector de modo y formato (#233): tres pasos antes de entrar a la partida.
/// En móvil es un asistente de un paso por pantalla; en tablet y PC lleva un
/// carril con los pasos a la izquierda.
class PantallaNuevaPartida extends ConsumerStatefulWidget {
  const PantallaNuevaPartida({super.key});

  /// Ancho a partir del cual se usa el carril de pasos.
  static const anchoCarril = 700.0;

  @override
  ConsumerState<PantallaNuevaPartida> createState() =>
      _PantallaNuevaPartidaState();
}

class _Paso {
  const _Paso({
    required this.titulo,
    required this.pregunta,
    required this.valor,
  });

  /// Nombre corto del paso en el carril.
  final String titulo;

  /// Pregunta que se hace en la pantalla.
  final String pregunta;

  /// Lo elegido, para mostrarlo en el carril cuando el paso ya está hecho.
  final String valor;
}

const _pasos = [
  _Paso(
    titulo: 'Modo de juego',
    pregunta: '¿Cómo quieres jugar?',
    valor: 'Partida libre',
  ),
  _Paso(
    titulo: 'Formato',
    pregunta: '¿Con qué formato?',
    valor: 'Físico',
  ),
  _Paso(
    titulo: 'Preparación',
    pregunta: '¿Cómo preparas la partida?',
    valor: 'Daño por jugador',
  ),
];

class _PantallaNuevaPartidaState extends ConsumerState<PantallaNuevaPartida> {
  int _paso = 0;
  ModoPreparacion _modo = ModoPreparacion.equipo;

  void _atras() {
    if (_paso == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _paso--);
    }
  }

  void _elegirModo(ModoPreparacion modo) => setState(() => _modo = modo);

  void _ir(int paso) => setState(() => _paso = paso);

  Future<void> _siguiente() async {
    if (_paso < _pasos.length - 1) {
      setState(() => _paso++);
      return;
    }
    final navegador = Navigator.of(context);
    if (await empezarPartidaNueva(context, ref, modo: _modo)) navegador.pop();
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final carril = ancho >= PantallaNuevaPartida.anchoCarril;
    return Scaffold(
      key: const Key('nueva-partida'),
      backgroundColor: _morado,
      body: FondoMenu(
        child: SafeArea(
          child: carril ? _ConCarril(estado: this) : _Asistente(estado: this),
        ),
      ),
    );
  }
}

TextStyle _titulo(double tamano) => TextStyle(
      color: Colors.white,
      fontSize: tamano,
      fontWeight: FontWeight.w800,
      height: 1.1,
      shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
    );

class _Atras extends StatelessWidget {
  const _Atras({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Volver',
      excludeSemantics: true,
      child: Material(
        color: _morado.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: const Key('nueva-atras'),
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _BotonPaso extends StatelessWidget {
  const _BotonPaso({required this.ultimo, required this.onPressed});

  final bool ultimo;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: ultimo ? 'Empezar' : 'Siguiente',
      excludeSemantics: true,
      child: Material(
        color: _amarillo,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: Key(ultimo ? 'nueva-empezar' : 'nueva-siguiente'),
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Container(
            height: 64,
            constraints: const BoxConstraints(minWidth: 260),
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0xFFA57F00), offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  ultimo ? Icons.play_arrow_rounded : Icons.chevron_right,
                  color: _morado,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  ultimo ? 'Empezar' : 'Siguiente',
                  style: const TextStyle(
                    color: _morado,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
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

/// Una opción de un paso. Las bloqueadas llevan «Próximamente» y no se pulsan.
class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.clave,
    required this.titulo,
    required this.detalle,
    required this.arte,
    this.seleccionada = false,
    this.bloqueada = false,
    this.horizontal = true,
    this.onTap,
  });

  final String clave;
  final String titulo;
  final String detalle;
  final Widget arte;
  final bool seleccionada;
  final bool bloqueada;
  final VoidCallback? onTap;

  /// Fila con el dibujo a la izquierda (tablet, PC) o columna (móvil).
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final borde = seleccionada ? _amarillo : Colors.white.withValues(alpha: 0.6);
    final texto = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          horizontal ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          titulo,
          textAlign: horizontal ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            color: bloqueada ? const Color(0xFFCFC6E4) : Colors.white,
            fontSize: horizontal ? 26 : 22,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          detalle,
          textAlign: horizontal ? TextAlign.start : TextAlign.center,
          style: const TextStyle(color: _lila, fontSize: 16, height: 1.3),
        ),
        if (bloqueada) ...[
          const SizedBox(height: 8),
          const Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Icon(Icons.lock_outline, size: 16, color: _lila),
              Text(
                'Próximamente',
                style: TextStyle(color: _lila, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ],
    );
    final contenido = horizontal
        ? Row(
            children: [
              SizedBox(width: 120, child: Center(child: arte)),
              const SizedBox(width: 20),
              Expanded(child: texto),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [arte, const SizedBox(height: 14), texto],
          );
    return Semantics(
      button: !bloqueada,
      selected: seleccionada,
      enabled: !bloqueada,
      label: bloqueada ? '$titulo, próximamente' : titulo,
      excludeSemantics: true,
      child: Material(
        color: bloqueada
            ? _morado.withValues(alpha: 0.7)
            : seleccionada
                ? _moradoClaro
                : _morado.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          key: Key(clave),
          borderRadius: BorderRadius.circular(24),
          onTap: bloqueada ? null : onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: horizontal ? 24 : 18,
              vertical: horizontal ? 20 : 18,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: borde,
                width: seleccionada ? 4 : 3,
              ),
            ),
            child: Stack(
              children: [
                SizedBox(width: double.infinity, child: contenido),
                if (seleccionada)
                  const Positioned(
                    right: 0,
                    top: 0,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: _amarillo,
                      child: Icon(Icons.check, color: _morado, size: 20),
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

Widget _icono(IconData icono, {bool activo = true}) => Icon(
      icono,
      size: 56,
      color: activo ? _amarillo : _lila,
    );

/// Las opciones de cada paso.
List<Widget> _opciones(
  int paso, {
  required bool horizontal,
  required ModoPreparacion modo,
  required ValueChanged<ModoPreparacion> alElegir,
  required VoidCallback alSeguir,
}) {
  switch (paso) {
    case 0:
      return [
        _Opcion(
          clave: 'opcion-libre',
          titulo: 'Partida libre',
          detalle: 'Una incursión suelta, sin historia.',
          arte: _icono(Icons.sports_esports_rounded),
          seleccionada: true,
          horizontal: horizontal,
          onTap: alSeguir,
        ),
        _Opcion(
          clave: 'opcion-campana',
          titulo: 'Modo campaña',
          detalle: 'Historia, mapas y recompensas.',
          arte: _icono(Icons.map_outlined, activo: false),
          bloqueada: true,
          horizontal: horizontal,
        ),
      ];
    case 1:
      return [
        _Opcion(
          clave: 'opcion-fisico',
          titulo: 'Físico',
          detalle: 'Juegas con tus cartas y la app lleva la cuenta.',
          arte: _icono(Icons.style_rounded),
          seleccionada: true,
          horizontal: horizontal,
          onTap: alSeguir,
        ),
        _Opcion(
          clave: 'opcion-digital',
          titulo: 'Digital',
          detalle: 'Cartas y dados dentro de la app.',
          arte: _icono(Icons.smartphone_rounded, activo: false),
          bloqueada: true,
          horizontal: horizontal,
        ),
      ];
    default:
      return [
        _Opcion(
          clave: 'opcion-jefe',
          titulo: 'Elegir jefe primero',
          detalle: 'La app te recomienda el daño total del equipo y avisa '
              'si no encaja.',
          arte: _icono(Icons.emoji_events_outlined,
              activo: modo == ModoPreparacion.jefe),
          seleccionada: modo == ModoPreparacion.jefe,
          horizontal: horizontal,
          onTap: modo == ModoPreparacion.jefe
              ? alSeguir
              : () => alElegir(ModoPreparacion.jefe),
        ),
        _Opcion(
          clave: 'opcion-danio',
          titulo: 'Insertar daño por jugador',
          detalle: 'El daño de cada uno da el nivel y eliges entre sus jefes.',
          arte: const _FichasJugador(),
          seleccionada: modo == ModoPreparacion.equipo,
          horizontal: horizontal,
          onTap: modo == ModoPreparacion.equipo
              ? alSeguir
              : () => alElegir(ModoPreparacion.equipo),
        ),
      ];
  }
}

class _FichasJugador extends StatelessWidget {
  const _FichasJugador();

  @override
  Widget build(BuildContext context) {
    Widget ficha(String texto, Color fondo, Color letra) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            texto,
            style: TextStyle(
              color: letra,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ficha('J1 · 120', _amarillo, _morado),
        const SizedBox(height: 8),
        ficha('J2 · 90', const Color(0xFF448AFF), Colors.white),
      ],
    );
  }
}

/// Móvil: un paso por pantalla, con «Paso N de 3» arriba.
class _Asistente extends StatelessWidget {
  const _Asistente({required this.estado});

  final _PantallaNuevaPartidaState estado;

  @override
  Widget build(BuildContext context) {
    final paso = estado._paso;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Atras(onPressed: estado._atras),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Nueva partida',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _titulo(24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'Paso ${paso + 1} de ${_pasos.length}',
                key: const Key('nueva-paso'),
                style: const TextStyle(
                  color: _lila,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              for (var i = 0; i < _pasos.length; i++)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: i == paso ? 26 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: i <= paso
                        ? _amarillo
                        : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(_pasos[paso].pregunta, style: _titulo(32)),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final o in _opciones(paso,
                      horizontal: false,
                      modo: estado._modo,
                      alElegir: estado._elegirModo,
                      alSeguir: estado._siguiente)) ...[
                    o,
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: _BotonPaso(
              ultimo: paso == _pasos.length - 1,
              onPressed: estado._siguiente,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tablet y PC: carril de pasos a la izquierda y las opciones en filas.
class _ConCarril extends StatelessWidget {
  const _ConCarril({required this.estado});

  final _PantallaNuevaPartidaState estado;

  @override
  Widget build(BuildContext context) {
    final paso = estado._paso;
    final lado = MediaQuery.of(context).size.width >= 900 ? 56.0 : 32.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(lado, 40, lado, 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 250,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _Atras(onPressed: estado._atras),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text('Nueva partida', style: _titulo(24)),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                for (var i = 0; i < _pasos.length; i++) ...[
                  _PasoCarril(
                    indice: i,
                    paso: _pasos[i],
                    hecho: i < paso,
                    activo: i == paso,
                    onTap: i < paso ? () => estado._ir(i) : null,
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
          SizedBox(width: lado),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_pasos[paso].pregunta, style: _titulo(36)),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final o in _opciones(paso,
                            horizontal: true,
                            modo: estado._modo,
                            alElegir: estado._elegirModo,
                      alSeguir: estado._siguiente)) ...[
                          o,
                          const SizedBox(height: 18),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: _BotonPaso(
                    ultimo: paso == _pasos.length - 1,
                    onPressed: estado._siguiente,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PasoCarril extends StatelessWidget {
  const _PasoCarril({
    required this.indice,
    required this.paso,
    required this.hecho,
    required this.activo,
    required this.onTap,
  });

  final int indice;
  final _Paso paso;
  final bool hecho;
  final bool activo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final valor = hecho
        ? paso.valor
        : activo
            ? 'Elige'
            : 'Pendiente';
    return Semantics(
      button: onTap != null,
      label: '${paso.titulo}: $valor',
      excludeSemantics: true,
      child: Material(
        color: activo ? _moradoClaro : _morado.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: Key('paso-$indice'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: activo
                    ? _amarillo
                    : Colors.white.withValues(alpha: hecho ? 0.45 : 0.25),
                width: activo ? 3 : 2,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: hecho ? _amarillo : Colors.white,
                  child: hecho
                      ? const Icon(Icons.check, color: _morado, size: 20)
                      : Text(
                          '${indice + 1}',
                          style: const TextStyle(
                            color: _morado,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paso.titulo,
                        style: const TextStyle(
                          color: _lila,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        valor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: activo || hecho ? Colors.white : _lila,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
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
