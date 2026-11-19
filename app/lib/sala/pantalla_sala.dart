import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cuenta/controlador_sesion.dart';
import '../partida/controlador_partida.dart';
import 'cliente_sala.dart';
import 'controlador_sala.dart';

/// Letras y cifras de un código de sala (sin 0, 1, I, L ni O).
final RegExp _formatoCodigo = RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{5}$');

/// «1:05» a partir de una duración.
String formatearCuentaAtras(Duration d) {
  final segundos = d.isNegative ? 0 : d.inSeconds;
  return '${segundos ~/ 60}:${(segundos % 60).toString().padLeft(2, '0')}';
}

/// Sala antes de empezar la partida: el host ve el código y quién ha entrado
/// y empieza cuando están todos; los demás esperan (D-19 §D7).
class PantallaSala extends ConsumerWidget {
  const PantallaSala({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sala = ref.watch(salaProvider);
    final info = sala.info;
    final soyHost = info?.soyHost ?? false;
    final jugadores = info?.jugadores ?? const <JugadorSala>[];
    final conectada = sala.conexion == EstadoConexion.conectada;
    return Scaffold(
      key: const Key('sala'),
      appBar: AppBar(
        title: const Text('Sala'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            key: const Key('sala-salir'),
            onPressed: () => ref.read(salaProvider.notifier).salir(),
            icon: const Icon(Icons.logout),
            label: const Text('Salir'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (!conectada) ...[
                const LinearProgressIndicator(key: Key('sala-conectando')),
                const SizedBox(height: 8),
                Text(
                  sala.conexion == EstadoConexion.reconectando
                      ? 'Reconectando…'
                      : 'Conectando con la sala…',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Código de la sala',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SelectableText(
                    sala.codigo ?? '',
                    key: const Key('sala-codigo'),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          letterSpacing: 8,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  IconButton(
                    key: const Key('sala-copiar'),
                    tooltip: 'Copiar el código',
                    icon: const Icon(Icons.copy),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: sala.codigo ?? '')),
                  ),
                ],
              ),
              if (soyHost)
                const Text(
                  'Pásales este código a los demás jugadores.',
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 24),
              Text(
                'Jugadores (${jugadores.length}/4)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final j in jugadores)
                _FilaJugadorSala(
                  jugador: j,
                  esHost: j.asiento == info?.host,
                  puedeEchar: soyHost && j.asiento != info?.host,
                  esYo: j.asiento == info?.tuAsiento,
                ),
              const SizedBox(height: 24),
              if (sala.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    sala.error!,
                    key: const Key('sala-error'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (soyHost) ...[
                FilledButton(
                  key: const Key('sala-empezar'),
                  onPressed: conectada && jugadores.length >= 2
                      ? () => ref.read(salaProvider.notifier).empezar()
                      : null,
                  child: const Text('Empezar la partida'),
                ),
                if (jugadores.length < 2)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Hacen falta al menos 2 jugadores.',
                      key: Key('sala-faltan'),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ] else if (info != null)
                const Text(
                  'Esperando a que el host empiece la partida…',
                  key: Key('sala-esperando'),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaJugadorSala extends ConsumerWidget {
  const _FilaJugadorSala({
    required this.jugador,
    required this.esHost,
    required this.puedeEchar,
    required this.esYo,
  });

  final JugadorSala jugador;
  final bool esHost;
  final bool puedeEchar;
  final bool esYo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etiquetas = [
      if (esHost) 'host',
      if (esYo) 'tú',
      if (!jugador.conectado) 'sin conexión',
    ];
    return Card(
      key: Key('sala-jugador-${jugador.asiento}'),
      child: ListTile(
        leading: CircleAvatar(child: Text('${jugador.asiento + 1}')),
        title: Text(jugador.nombre),
        subtitle: etiquetas.isEmpty ? null : Text(etiquetas.join(' · ')),
        trailing: puedeEchar
            ? IconButton(
                key: Key('echar-${jugador.asiento}'),
                tooltip: 'Echar de la sala',
                icon: const Icon(Icons.person_remove_outlined),
                onPressed: () =>
                    ref.read(salaProvider.notifier).echar(jugador.asiento),
              )
            : null,
      ),
    );
  }
}

/// Pide el código de una sala y entra con la sesión iniciada.
class PantallaUnirse extends ConsumerStatefulWidget {
  const PantallaUnirse({super.key});

  @override
  ConsumerState<PantallaUnirse> createState() => _PantallaUnirseState();
}

class _PantallaUnirseState extends ConsumerState<PantallaUnirse> {
  final _codigo = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  String get _texto => _codigo.text.trim().toUpperCase();

  Future<void> _entrar() async {
    if (!_formatoCodigo.hasMatch(_texto)) {
      setState(() => _error = 'El código tiene 5 letras o cifras.');
      return;
    }
    setState(() => _error = null);
    final fallo = await ref.read(salaProvider.notifier).unirse(_texto);
    if (fallo != null && mounted) setState(() => _error = fallo);
  }

  @override
  Widget build(BuildContext context) {
    // Al conectar, la raíz de la app enseña la sala: esta pantalla sobra.
    ref.listen(salaProvider.select((s) => s.info), (_, info) {
      if (info != null && mounted) Navigator.of(context).maybePop();
    });
    final sala = ref.watch(salaProvider);
    final conectando = sala.enSala;
    final error = _error ?? sala.error;
    return Scaffold(
      key: const Key('unirse'),
      appBar: AppBar(title: const Text('Unirse a una sala')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Escribe el código que te ha dado el host.'),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('unirse-codigo'),
                  controller: _codigo,
                  autofocus: true,
                  maxLength: 5,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(letterSpacing: 8),
                  decoration: const InputDecoration(counterText: ''),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  ],
                  onSubmitted: (_) => _entrar(),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error,
                      key: const Key('unirse-error'),
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('unirse-entrar'),
                  onPressed: conectando ? null : _entrar,
                  child: Text(conectando ? 'Entrando…' : 'Entrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La partida se ha cancelado (se cayó el host): no se guarda ni da puntos.
class PantallaSalaCancelada extends ConsumerWidget {
  const PantallaSalaCancelada({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: const Key('sala-cancelada'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 64),
              const SizedBox(height: 16),
              Text(
                'Partida cancelada',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Se ha caído el host y la partida se ha perdido. '
                'No se guarda ni da puntos.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('sala-cancelada-volver'),
                onPressed: () =>
                    ref.read(salaProvider.notifier).descartarCancelada(),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso sobre la partida mientras algún jugador está desconectado: cuenta
/// atrás de los 2 minutos que tiene para volver (D-19 §D9). Vence con un
/// `PokemonKo` por cada Pokémon que le quede.
class AvisoDesconexion extends ConsumerWidget {
  const AvisoDesconexion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sala = ref.watch(salaProvider);
    if (sala.caidos.isEmpty) return const SizedBox.shrink();
    final nombres = {
      for (final j in sala.info?.jugadores ?? const <JugadorSala>[])
        j.asiento: j.nombre,
    };
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            key: const Key('aviso-desconexion'),
            elevation: 6,
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in sala.caidos.entries)
                    _CuentaAtras(
                      key: Key('caido-${e.key}'),
                      nombre: nombres[e.key] ?? 'Jugador ${e.key + 1}',
                      vence: e.value,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Texto con la cuenta atrás, que se repinta cada segundo mientras existe.
class _CuentaAtras extends ConsumerStatefulWidget {
  const _CuentaAtras({super.key, required this.nombre, required this.vence});

  final String nombre;
  final DateTime vence;

  @override
  ConsumerState<_CuentaAtras> createState() => _CuentaAtrasState();
}

class _CuentaAtrasState extends ConsumerState<_CuentaAtras> {
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ahora = ref.read(relojProvider)();
    final resta = formatearCuentaAtras(widget.vence.difference(ahora));
    return Text(
      '${widget.nombre} se ha desconectado. Tiene $resta para volver.',
      textAlign: TextAlign.center,
    );
  }
}

/// Elige entre crear una sala o unirse a una con su código.
Future<void> abrirSala(BuildContext context, WidgetRef ref) async {
  final opcion = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Jugar en sala'),
      children: [
        SimpleDialogOption(
          key: const Key('sala-crear'),
          onPressed: () => Navigator.of(context).pop('crear'),
          child: const Text('Crear una sala'),
        ),
        SimpleDialogOption(
          key: const Key('sala-unirse'),
          onPressed: () => Navigator.of(context).pop('unirse'),
          child: const Text('Unirme con un código'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  switch (opcion) {
    case 'crear':
      final fallo = await ref.read(salaProvider.notifier).crear();
      if (fallo != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(fallo)));
      }
    case 'unirse':
      if (ref.read(sesionActualProvider) == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Inicia sesión para jugar en una sala.'),
        ));
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PantallaUnirse()),
      );
  }
}
