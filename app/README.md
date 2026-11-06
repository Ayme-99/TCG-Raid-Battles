# app/

App Flutter para tablet ("tablet en medio de la mesa"). Es una interfaz fina: toda la lógica vive en `engine/`.

## Estado actual (T-10)

Partida completa en local, con inicio de sesión y envío de resultados (T-09):

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
- `lib/cuenta/`: inicio de sesión con la cuenta de Deck Tracker (`POST /api/auth/login`). Solo iniciar sesión: registrarse se hace en Deck Tracker. El token se guarda en el dispositivo (`shared_preferences`, vía `lib/almacen/`).
- `lib/envios/`: al terminar la partida, **«Guardar resultados»** mete el registro del contrato en una cola persistente y lo envía a `/api/incursiones/partidas`. El host es siempre el jugador 1 (su cuenta); los demás van como invitados. Hasta guardar se puede deshacer; después no.
  - Sin red, servidor caído o saturado (red, 408, 429, 5xx): se reintenta solo con espera creciente (30 s, 1 min, 2 min... tope 15 min), al abrir la app y al volver la sesión. Mientras tanto la barra superior muestra un icono con las partidas pendientes.
  - 400, 403, 409 y 422: el servidor la rechaza y no se reintenta; se aparta con el motivo y se puede consultar o descartar desde ese icono.
  - 401: la sesión ha caducado; se cierra y las partidas se conservan hasta volver a iniciar sesión.
  - Enviar dos veces es seguro: el servidor guarda una partida una sola vez por `partidaId`, y el id y la fecha del registro no cambian mientras no cambien los eventos.
  - **En web no hay modo sin conexión**: la cola vive en el navegador y solo sirve mientras la pestaña esté abierta.
- Servidor: `https://deck-tracker-server.onrender.com/api`; para otro, `--dart-define=API_URL=http://localhost:5000/api`.
- `test/`: pruebas del controlador, las pantallas (flujo completo, deshacer, quemadura y moneda, invocación, abandono, login y guardado), el cliente HTTP y la cola de envíos. El CI ejecuta `flutter analyze` y `flutter test`.

Las pantallas no duplican ninguna regla: toda decisión de juego es del motor, y si rechaza un evento la app muestra el motivo.

## Primera vez en un PC con Flutter

Este proyecto no incluye las carpetas de plataforma (`android/`, `windows/`...), porque se generan con Flutter. Una sola vez:

```
cd app
flutter create . --org dev.ayme99 --project-name incursiones_app --platforms=android,windows,web
git status        # revisa que no haya tocado lib/ ni test/; si lo hizo: git checkout -- lib test
flutter pub get
flutter test
flutter run
```

La versión web (`flutter run -d chrome`) funciona igual, pero **sin conexión no funciona**: la cola offline de envío (T-09) es solo para Android y Windows. El CI compila la web en cada cambio (`flutter build web`).
