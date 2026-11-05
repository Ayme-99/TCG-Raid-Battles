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
