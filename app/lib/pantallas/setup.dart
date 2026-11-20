import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../catalogo/catalogo.dart';
import '../cuenta/controlador_sesion.dart';
import '../partida/controlador_partida.dart';
import '../sala/controlador_sala.dart';
import 'comun.dart';

/// Modo de preparación de la partida que se está montando (D-15). Lo fija el
/// selector de «Nueva partida»; una revancha lo conserva.
class ModoPreparacionActual extends Notifier<ModoPreparacion> {
  @override
  ModoPreparacion build() => ModoPreparacion.equipo;

  void fijar(ModoPreparacion modo) => state = modo;
}

final modoPreparacionProvider =
    NotifierProvider<ModoPreparacionActual, ModoPreparacion>(
        ModoPreparacionActual.new);

/// Jefe elegido antes de meter el daño del equipo (modo `jefe`).
class JefePreelegido extends Notifier<JefeCatalogo?> {
  @override
  JefeCatalogo? build() => null;

  void fijar(JefeCatalogo? jefe) => state = jefe;
}

final jefePreelegidoProvider =
    NotifierProvider<JefePreelegido, JefeCatalogo?>(JefePreelegido.new);

/// «250–400», «801 o más»: el daño total de equipo recomendado para un nivel.
String textoRango(int nivel) {
  final (minimo, maximo) = rangoXDelNivel(nivel);
  return maximo == null ? '$minimo o más' : '$minimo–$maximo';
}

/// Aviso cuando el equipo (X) no encaja con el jefe; null si encaja. Según el
/// simulador (D-15, #246) la distancia que importa es en niveles: un nivel por
/// debajo ya es casi imposible y uno por encima ya es fácil.
String? avisoDesajuste(int x, int nivel) => switch (desajusteDeEquipo(x, nivel)) {
      -1 => 'Con X = $x tu equipo queda por debajo del rango recomendado '
          '(${textoRango(nivel)}): será muy difícil. Puedes jugar igualmente.',
      1 when nivelPorX(x) - nivel >= 2 =>
        'Con X = $x tu equipo queda muy por encima del rango recomendado '
            '(${textoRango(nivel)}): será demasiado fácil. '
            'Puedes jugar igualmente.',
      1 => 'Con X = $x tu equipo queda por encima del rango recomendado '
          '(${textoRango(nivel)}): será más fácil de lo previsto. '
          'Puedes jugar igualmente.',
      _ => null,
    };

/// Setup, modo `jefe`, paso 1: elegir el jefe antes de meter el daño.
class PantallaJefePrimero extends ConsumerWidget {
  const PantallaJefePrimero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jefes = (ref.watch(catalogoProvider).valueOrNull ?? Catalogo.vacio).jefes;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('¿Contra qué jefe?',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text(
          'Después indicas el daño de tu equipo y la app te avisa si no encaja '
          'con el jefe.',
        ),
        const SizedBox(height: 16),
        if (jefes.isEmpty)
          const Text('No hay jefes en el catálogo.')
        else
          _RejillaJefes(
            jefes: jefes,
            clave: (j) => Key('jefe-primero-${j.id}'),
            onElegir: (j) => ref.read(jefePreelegidoProvider.notifier).fijar(j),
          ),
      ],
    );
  }
}

/// Rejilla de tarjetas de jefe: 2 columnas como mínimo, más si hay ancho.
class _RejillaJefes extends StatelessWidget {
  const _RejillaJefes({
    required this.jefes,
    required this.clave,
    required this.onElegir,
    this.aviso,
  });

  final List<JefeCatalogo> jefes;
  final Key Function(JefeCatalogo) clave;
  final void Function(JefeCatalogo) onElegir;

  /// Texto de aviso bajo la tarjeta de un jefe (p. ej. «fuera de rango»).
  final String? Function(JefeCatalogo)? aviso;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, caja) {
        const separacion = 12.0;
        final columnas = max(2, (caja.maxWidth / 200).floor());
        final ancho = (caja.maxWidth - separacion * (columnas - 1)) / columnas;
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: separacion,
          runSpacing: separacion,
          children: [
            for (final j in jefes)
              SizedBox(
                width: ancho,
                child: _TarjetaJefe(
                  key: clave(j),
                  jefe: j,
                  aviso: aviso?.call(j),
                  onTap: () => onElegir(j),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Ataques e invocación de un jefe en una línea.
String resumenAtaquesJefe(JefeCatalogo j) {
  final ataques = j.ataques.map((a) => a.dano).join('/');
  final n = j.intentosDeInvocacion;
  final invoca = n == 0
      ? 'no invoca'
      : 'invoca $n aliado${n == 1 ? '' : 's'}'
          '${j.invocacion!.segura ? ' (seguro)' : ''}';
  return 'ataques $ataques · $invoca';
}

/// Color del tipo de cada jefe, para el fondo de su foto de perfil.
Color _colorTipoJefe(String id) => switch (id) {
      'onix' => const Color(0xFF7A6A55),
      'manectric' => const Color(0xFFB59A12),
      'kingdra' => const Color(0xFF2E7DB5),
      'arceus' => const Color(0xFF8A8F9C),
      _ => const Color(0xFF5B4A8A),
    };

/// Artwork del Pokémon del jefe sobre un degradado del color de su tipo: su
/// foto de perfil.
class _FotoJefe extends StatelessWidget {
  const _FotoJefe({required this.jefe});

  final JefeCatalogo jefe;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_colorTipoJefe(jefe.id), const Color(0xFF1B1235)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          'assets/jefes/${jefe.id}.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) =>
              const Center(child: Icon(Icons.catching_pokemon, size: 48)),
        ),
      ),
    );
  }
}

/// Un jefe del catálogo en la rejilla: su artwork oficial como foto de perfil, con su nombre, nivel, HP y el equipo recomendado.
class _TarjetaJefe extends StatelessWidget {
  const _TarjetaJefe({
    super.key,
    required this.jefe,
    required this.onTap,
    this.aviso,
  });

  final JefeCatalogo jefe;
  final VoidCallback onTap;
  final String? aviso;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(aspectRatio: 1.3, child: _FotoJefe(jefe: jefe)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    jefe.nombre,
                    style: tema.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text('Nivel ${jefe.nivel}',
                      style: tema.textTheme.labelLarge
                          ?.copyWith(color: const Color(0xFFFFC400))),
                  const SizedBox(height: 4),
                  Text(
                    '${jefe.hp} HP · equipo ${textoRango(jefe.nivel)}',
                    style: tema.textTheme.bodySmall,
                  ),
                  Text(resumenAtaquesJefe(jefe),
                      style: tema.textTheme.bodySmall),
                  if (aviso != null)
                    Text(aviso!,
                        style: tema.textTheme.bodySmall
                            ?.copyWith(color: tema.colorScheme.error)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Setup, paso 1: jugadores y daño de su mejor ataque (D-02).
class PantallaJugadores extends ConsumerStatefulWidget {
  const PantallaJugadores({super.key});

  @override
  ConsumerState<PantallaJugadores> createState() => _PantallaJugadoresState();
}

class _FilaJugador {
  _FilaJugador(String nombre) : nombre = TextEditingController(text: nombre);

  final TextEditingController nombre;
  final TextEditingController ataque = TextEditingController();

  void dispose() {
    nombre.dispose();
    ataque.dispose();
  }
}

class _PantallaJugadoresState extends ConsumerState<PantallaJugadores> {
  late final List<_FilaJugador> _filas;

  /// Si el host ha cambiado a mano el nombre del jugador 1, la sesión ya no se
  /// lo pisa.
  bool _nombreEditado = false;

  /// Partida de una sala: el número de jugadores lo fijan los que entraron.
  bool _enSala = false;

  @override
  void initState() {
    super.initState();
    // El jugador 1 es el host: empieza con su nickname si ha iniciado sesión.
    final nick = ref.read(sesionActualProvider)?.username;
    final sala = ref.read(salaProvider).info;
    if (sala != null && sala.enCurso) {
      // En una sala los jugadores son los que han entrado, en su orden.
      final ordenados = [...sala.jugadores]
        ..sort((a, b) => a.asiento.compareTo(b.asiento));
      _filas = [for (final j in ordenados) _FilaJugador(j.nombre)];
      _enSala = true;
    } else {
      _filas = [
        _FilaJugador(nick ?? 'Jugador 1'),
        _FilaJugador('Jugador 2'),
      ];
    }
  }

  @override
  void dispose() {
    for (final f in _filas) {
      f.dispose();
    }
    super.dispose();
  }

  void _anadir() {
    if (_filas.length >= maxJugadores) return;
    setState(() => _filas.add(_FilaJugador('Jugador ${_filas.length + 1}')));
  }

  void _quitar() {
    if (_filas.length <= minJugadores) return;
    setState(() => _filas.removeLast().dispose());
  }

  int get _x => _filas.fold(0, (s, f) => s + (int.tryParse(f.ataque.text) ?? 0));

  ConfigurarJugadores _evento(ModoPreparacion modo) => ConfigurarJugadores(
        [
          for (final f in _filas)
            ConfigJugador(
              nombre: f.nombre.text.trim().isEmpty
                  ? 'Jugador'
                  : f.nombre.text.trim(),
              ataqueMaximo: int.tryParse(f.ataque.text) ?? 0,
            ),
        ],
        modo: modo,
        formato: _enSala ? FormatoPartida.digital : FormatoPartida.fisico,
      );

  /// Modo `jefe`: se registran la configuración y el jefe ya elegido.
  void _empezarConJefe(JefeCatalogo jefe) {
    if (!registrar(context, ref, _evento(ModoPreparacion.jefe))) return;
    final ok = registrar(
      context,
      ref,
      ElegirJefe(
        nombre: jefe.nombre,
        nivel: jefe.nivel,
        hp: jefe.hp,
        invocacionCadaHp: jefe.invocacion?.cadaHp,
        jefeId: jefe.id,
      ),
    );
    if (ok) ref.read(jefePreelegidoProvider.notifier).fijar(null);
  }

  void _configurar() => registrar(context, ref, _evento(ModoPreparacion.equipo));

  @override
  Widget build(BuildContext context) {
    // La sesión se lee de forma asíncrona: si llega con la pantalla abierta, el
    // nickname entra solo mientras el host no haya escrito otro nombre.
    ref.listen(sesionActualProvider, (_, sesion) {
      if (!_nombreEditado && !_enSala) {
        _filas[0].nombre.text = sesion?.username ?? 'Jugador 1';
      }
    });
    final jefe = ref.watch(jefePreelegidoProvider);
    // La recomendación necesita el daño de todos: con solo algunos, X se
    // quedaría corta y el aviso engañaría.
    final completos = _filas.every((f) => (int.tryParse(f.ataque.text) ?? 0) > 0);
    final algunos = _filas.any((f) => f.ataque.text.trim().isNotEmpty);
    final aviso = jefe == null || !completos ? null : avisoDesajuste(_x, jefe.nivel);
    final encaja = jefe != null && completos && aviso == null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          jefe == null ? 'Jugadores y su mejor ataque' : 'Jugadores',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          jefe == null
              ? 'Escribe el daño del mejor ataque de cada jugador. '
                  'Con eso se calcula X y el nivel del jefe.'
              : 'Opcional: si escribes el daño del mejor ataque de cada '
                  'jugador, la app te dice si el equipo es demasiado flojo o '
                  'demasiado fuerte para este jefe.',
        ),
        const SizedBox(height: 16),
        if (jefe != null) ...[
          Card(
            key: const Key('jefe-elegido'),
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            child: SizedBox(
              height: 112,
              child: Row(
                children: [
                  SizedBox(width: 128, child: _FotoJefe(jefe: jefe)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            jefe.nombre,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Nivel ${jefe.nivel}',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: const Color(0xFFFFC400)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${jefe.hp} HP · equipo recomendado '
                            '${textoRango(jefe.nivel)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton(
                      key: const Key('cambiar-jefe'),
                      onPressed: () =>
                          ref.read(jefePreelegidoProvider.notifier).fijar(null),
                      child: const Text('Cambiar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < _filas.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    key: Key('nombre-$i'),
                    controller: _filas[i].nombre,
                    onChanged: i == 0 ? (_) => _nombreEditado = true : null,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: KeyedSubtree(
                    key: Key('ataque-$i'),
                    child: CampoNumero(
                      controlador: _filas[i].ataque,
                      etiqueta:
                          jefe == null ? 'Mejor ataque' : 'Mejor ataque (opcional)',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (!_enSala) Row(
          children: [
            OutlinedButton.icon(
              key: const Key('anadir-jugador'),
              onPressed: _filas.length < maxJugadores ? _anadir : null,
              icon: const Icon(Icons.person_add),
              label: const Text('Añadir jugador'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              key: const Key('quitar-jugador'),
              onPressed: _filas.length > minJugadores ? _quitar : null,
              icon: const Icon(Icons.person_remove),
              label: const Text('Quitar jugador'),
            ),
          ],
        ),
        if (jefe != null && algunos && !completos) ...[
          const SizedBox(height: 12),
          const Text(
            'Escribe el daño de todos los jugadores para recibir la '
            'recomendación.',
            key: Key('faltan-danos'),
          ),
        ],
        if (encaja) ...[
          const SizedBox(height: 16),
          Card(
            key: const Key('equipo-adecuado'),
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Con X = $_x tu equipo encaja con el jefe '
                      '(${textoRango(jefe.nivel)}).',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (aviso != null) ...[
          const SizedBox(height: 16),
          Card(
            key: const Key('aviso-desajuste'),
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 12),
                  Expanded(child: Text(aviso)),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (jefe == null)
          FilledButton(
            key: const Key('configurar'),
            onPressed: _configurar,
            child: const Text('Calcular nivel'),
          )
        else
          FilledButton(
            key: const Key('empezar-con-jefe'),
            onPressed: () => _empezarConJefe(jefe),
            child: const Text('Empezar la partida'),
          ),
      ],
    );
  }
}

/// Setup, paso 2: elegir el jefe del nivel calculado.
class PantallaEleccionJefe extends ConsumerStatefulWidget {
  const PantallaEleccionJefe({super.key});

  @override
  ConsumerState<PantallaEleccionJefe> createState() =>
      _PantallaEleccionJefeState();
}

class _PantallaEleccionJefeState extends ConsumerState<PantallaEleccionJefe> {
  void _elegirDelCatalogo(JefeCatalogo jefe) {
    registrar(
      context,
      ref,
      ElegirJefe(
        nombre: jefe.nombre,
        nivel: jefe.nivel,
        hp: jefe.hp,
        invocacionCadaHp: jefe.invocacion?.cadaHp,
        jefeId: jefe.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(estadoProvider);
    final catalogo = ref.watch(catalogoProvider).valueOrNull ?? Catalogo.vacio;
    // Por jefe (una revancha lo conserva) vale cualquier nivel y la app solo
    // avisa si el equipo no encaja.
    final porJefe = estado.modo == ModoPreparacion.jefe;
    final delNivel = porJefe ? catalogo.jefes : catalogo.delNivel(estado.nivel);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          porJefe
              ? (estado.x == 0 ? 'Elige el jefe' : 'Elige el jefe (X = ${estado.x})')
              : 'Nivel ${estado.nivel} (X = ${estado.x})',
          key: const Key('nivel-calculado'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          porJefe
              ? 'La app avisa si tu equipo no encaja con el jefe.'
              : 'Elige el jefe al que os enfrentáis.',
        ),
        const SizedBox(height: 16),
        if (delNivel.isEmpty)
          const Text('No hay jefes en el catálogo para este nivel.')
        else
          _RejillaJefes(
            jefes: delNivel,
            clave: (j) => Key('catalogo-${j.id}'),
            onElegir: _elegirDelCatalogo,
            aviso: porJefe && estado.x > 0
                ? (j) => avisoDesajuste(estado.x, j.nivel) == null
                    ? null
                    : 'Fuera de rango'
                : null,
          ),
      ],
    );
  }
}
