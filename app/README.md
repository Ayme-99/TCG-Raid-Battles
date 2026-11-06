# app/

App Flutter para tablet ("tablet en medio de la mesa"). Es una interfaz fina: toda la lógica vive en `engine/`.

## Estado actual (T-10)

Partida local completa, sin red ni cuentas:

- `lib/partida/controlador_partida.dart`: el controlador (Riverpod). Guarda el `Historial` del motor y expone `registrar(evento)` (devuelve `null` o el motivo del rechazo), `deshacer`, `rehacer`, `nuevaPartida` y `registro(cuentas)`, que genera el JSON del contrato (`contrato/`).
- `lib/pantallas/`: una sola pantalla (`PantallaPartida`) que cambia según la fase del motor:
  - `setup.dart`: jugadores y mejor ataque (calcula X y el nivel) y elección del jefe.
  - `turno_jugadores.dart`: orden de la ronda, daño al jefe, ataque a un aliado, cartas de ánimo, estados y KO.
  - `turno_jefe.dart`: ataques del jefe (ranura, daño, objetivo), ataques de aliados, KO, estados y moneda de la quemadura al cerrar el turno.
  - `fin_partida.dart`: resultado y puntos por jugador (con el bono de estados).
  - `pendientes.dart`: intentos de invocación y ataques de entrada de los aliados, que el motor exige resolver antes de seguir.
  - La barra superior lleva deshacer, rehacer y abandonar en todas las fases.
- El jefe se escribe a mano (nombre, HP, cada cuántos HP invoca) hasta que exista el catálogo versionado (T-13).
- **El diseño visual es provisional**: espera a los bocetos (T-18). La estructura y los eventos no cambian con el diseño.
- Sin envío al servidor todavía (T-09).
- `test/`: pruebas del controlador y de las pantallas (flujo completo, deshacer, quemadura y moneda, invocación, abandono). El CI ejecuta `flutter analyze` y `flutter test`.

Las pantallas no duplican ninguna regla: toda decisión de juego es del motor, y si rechaza un evento la app muestra el motivo.

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
