# app/

App Flutter para tablet ("tablet en medio de la mesa"). Es una interfaz fina: toda la lógica vive en `engine/`.

## Estado actual (T-10)

- `lib/partida/controlador_partida.dart`: el controlador (Riverpod). Guarda el `Historial` del motor y expone `registrar(evento)` (devuelve `null` o el motivo del rechazo), `deshacer`, `rehacer`, `nuevaPartida` y `registro(cuentas)`, que genera el JSON del contrato (`contrato/`). Los providers `estadoProvider`, `puntosProvider`, `puedeDeshacerProvider` y `puedeRehacerProvider` son lo que leerán las pantallas.
- `lib/app.dart`: pantalla de inicio provisional. **Las pantallas esperan a los bocetos (T-18)**.
- Sin cuentas ni envío al servidor todavía (T-09).
- `test/`: pruebas del controlador y del arranque. El CI ejecuta `flutter analyze` y `flutter test`.

Las pantallas no deben duplicar ninguna regla: toda decisión de juego es del motor.

## Primera vez en un PC con Flutter

Este proyecto no incluye las carpetas de plataforma (`android/`, `windows/`...), porque se generan con Flutter. Una sola vez:

```
cd app
flutter create . --org dev.ayme99 --project-name incursiones_app --platforms=android,windows
git status        # revisa que no haya tocado lib/ ni test/; si lo hizo: git checkout -- lib test
flutter pub get
flutter test
flutter run
```
