import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incursiones_engine/incursiones_engine.dart';

import '../catalogo/catalogo.dart';
import '../cuenta/controlador_sesion.dart';
import '../partida/controlador_partida.dart';
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
          for (final j in jefes)
            Card(
              child: ListTile(
                key: Key('jefe-primero-${j.id}'),
                title: Text('${j.nombre} · Nv. ${j.nivel}'),
                subtitle: Text(
                  '${j.hp} HP · equipo recomendado ${textoRango(j.nivel)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => ref.read(jefePreelegidoProvider.notifier).fijar(j),
              ),
            ),
      ],
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

  @override
  void initState() {
    super.initState();
    // El jugador 1 es el host: empieza con su nickname si ha iniciado sesión.
    final nick = ref.read(sesionActualProvider)?.username;
    _filas = [
      _FilaJugador(nick ?? 'Jugador 1'),
      _FilaJugador('Jugador 2'),
    ];
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
      if (!_nombreEditado) {
        _filas[0].nombre.text = sesion?.username ?? 'Jugador 1';
      }
    });
    final jefe = ref.watch(jefePreelegidoProvider);
    final aviso = jefe == null || _x == 0 ? null : avisoDesajuste(_x, jefe.nivel);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Jugadores y su mejor ataque',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          jefe == null
              ? 'Escribe el daño del mejor ataque de cada jugador. '
                  'Con eso se calcula X y el nivel del jefe.'
              : 'Escribe el daño del mejor ataque de cada jugador. '
                  'La app avisa si el equipo no encaja con el jefe.',
        ),
        const SizedBox(height: 16),
        if (jefe != null) ...[
          Card(
            key: const Key('jefe-elegido'),
            child: ListTile(
              title: Text('${jefe.nombre} · Nv. ${jefe.nivel}'),
              subtitle: Text(
                '${jefe.hp} HP · equipo recomendado ${textoRango(jefe.nivel)}',
              ),
              trailing: TextButton(
                key: const Key('cambiar-jefe'),
                onPressed: () =>
                    ref.read(jefePreelegidoProvider.notifier).fijar(null),
                child: const Text('Cambiar'),
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
                      etiqueta: 'Mejor ataque',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
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
  final _nombre = TextEditingController();
  final _hp = TextEditingController();
  final _invocacion = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    _hp.dispose();
    _invocacion.dispose();
    super.dispose();
  }

  void _elegir(EstadoPartida estado) {
    final cada = int.tryParse(_invocacion.text);
    registrar(
      context,
      ref,
      ElegirJefe(
        nombre: _nombre.text.trim().isEmpty ? 'Jefe' : _nombre.text.trim(),
        nivel: estado.nivel,
        hp: int.tryParse(_hp.text) ?? 0,
        invocacionCadaHp: cada == null || cada == 0 ? null : cada,
      ),
    );
  }

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

  String _resumen(JefeCatalogo j) {
    final ataques = j.ataques.map((a) => a.dano).join('/');
    final n = j.intentosDeInvocacion;
    final invoca = n == 0
        ? 'no invoca'
        : 'invoca $n aliado${n == 1 ? '' : 's'}'
            '${j.invocacion!.segura ? ' (seguro)' : ''}';
    return '${j.hp} HP · ataques $ataques · $invoca';
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
              ? 'Elige el jefe (X = ${estado.x})'
              : 'Nivel ${estado.nivel} (X = ${estado.x})',
          key: const Key('nivel-calculado'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          porJefe
              ? 'La app avisa si tu equipo no encaja con el jefe.'
              : 'Elige un jefe del catálogo o introduce su carta a mano.',
        ),
        const SizedBox(height: 16),
        if (delNivel.isNotEmpty) ...[
          Text(
            'Jefes del catálogo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final j in delNivel)
            Card(
              child: ListTile(
                key: Key('catalogo-${j.id}'),
                title: Text(porJefe ? '${j.nombre} · Nv. ${j.nivel}' : j.nombre),
                subtitle: Text(
                  porJefe
                      ? '${_resumen(j)}\nEquipo recomendado ${textoRango(j.nivel)}'
                          '${avisoDesajuste(estado.x, j.nivel) == null ? '' : ' · fuera de rango'}'
                      : _resumen(j),
                ),
                isThreeLine: porJefe,
                trailing: const Icon(Icons.play_arrow),
                onTap: () => _elegirDelCatalogo(j),
              ),
            ),
          const SizedBox(height: 16),
        ],
        if (!porJefe) ..._jefePersonalizado(context, estado),
      ],
    );
  }

  List<Widget> _jefePersonalizado(BuildContext context, EstadoPartida estado) {
    return [
        if (ref.watch(catalogoProvider).valueOrNull?.delNivel(estado.nivel).isNotEmpty ?? false) ...[
          Text(
            'Jefe personalizado',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          key: const Key('jefe-nombre'),
          controller: _nombre,
          decoration: const InputDecoration(
            labelText: 'Nombre del jefe',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: const Key('jefe-hp'),
          child: CampoNumero(controlador: _hp, etiqueta: 'HP del jefe'),
        ),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: const Key('jefe-invocacion'),
          child: CampoNumero(
            controlador: _invocacion,
            etiqueta: 'Llama a aliados cada X HP perdidos (vacío o 0: nunca)',
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('elegir-jefe'),
          onPressed: () => _elegir(estado),
          child: const Text('Empezar la partida'),
        ),
    ];
  }
}
