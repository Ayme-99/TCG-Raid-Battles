# engine/

Motor de partida en **Dart puro** (sin Flutter). Estado inmutable y eventos:
`apply(estado, evento) -> estado nuevo`. Todo lo que ocurre en una partida es un evento en un log,
lo que permite deshacer, rehacer y repetir partidas.

Lo usan `sim/` (simulador), `app/` (tablet) y se prueba con `dart test`.

```
cd engine
dart pub get
dart test
```

## Uso básico

```dart
import 'package:incursiones_engine/incursiones_engine.dart';

var partida = Partida.nueva()
    .aplicar(const ConfigurarJugadores([
      ConfigJugador(nombre: 'Ana', ataqueMaximo: 120),
      ConfigJugador(nombre: 'Bea', ataqueMaximo: 100),
    ]))
    .aplicar(const ElegirJefe(nombre: 'Jefe', nivel: 1, hp: 300))
    .aplicar(const TurnoJugador(jugador: 0, dano: 120));

print(partida.estado.jefe!.hp); // 180
```

- `apply(estado, evento)` devuelve un estado nuevo; si el evento no es válido lanza `ReglaIncumplida`.
- `reproducir(eventos)` reconstruye una partida desde su registro y siempre da el mismo estado final.
- `Partida` guarda el estado y el registro de eventos.

Las reglas están en `docs/` y en `incursiones_gdd.md` (v1.0).
