import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controlador_sesion.dart';

/// Inicio de sesión con la cuenta de Deck Tracker. Registrarse se hace en
/// Deck Tracker.
class PantallaLogin extends ConsumerStatefulWidget {
  const PantallaLogin({super.key});

  @override
  ConsumerState<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends ConsumerState<PantallaLogin> {
  final _usuario = TextEditingController();
  final _contrasena = TextEditingController();
  bool _entrando = false;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    setState(() {
      _entrando = true;
      _error = null;
    });
    final error = await ref
        .read(sesionProvider.notifier)
        .iniciarSesion(_usuario.text.trim(), _contrasena.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _entrando = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Usa tu cuenta de Deck Tracker. Si aún no tienes, '
                'regístrate allí primero.',
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('login-usuario'),
                controller: _usuario,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('login-contrasena'),
                controller: _contrasena,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) {
                  if (!_entrando) _entrar();
                },
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  key: const Key('login-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('login-entrar'),
                onPressed: _entrando ? null : _entrar,
                child: Text(_entrando ? 'Entrando...' : 'Entrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
