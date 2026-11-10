# app/

App Flutter para tablet ("tablet en medio de la mesa"). Es una interfaz fina: toda la lógica vive en `engine/`.

## Estado actual

Partida completa en local, con inicio de sesión y envío de resultados (T-09):

- `lib/partida/controlador_partida.dart`: el controlador (Riverpod). Guarda el `Historial` del motor y expone `registrar(evento)` (devuelve `null` o el motivo del rechazo), `deshacer`, `rehacer`, `nuevaPartida` y `registro(cuentas)`, que genera el JSON del contrato (`contrato/`).
- `lib/pantallas/`: una sola pantalla (`PantallaPartida`) que cambia según la fase del motor. En juego, la **mesa** (`mesa.dart`) ocupa toda la pantalla: cámara 2.5D sobre el jefe, los aliados y los jugadores, con sus cartas (`carta.dart`, imágenes en `assets/cartas/`) y los controles en un bocadillo que sale del asiento del jugador que actúa (`panel_acciones.dart`; por debajo de 1100 px de ancho va plegable bajo la mesa). La cámara se queda en vista general y solo se mueve con eventos (dados, ataques del jefe o de los aliados). Fases:
  - `setup.dart`: jugadores y mejor ataque (calcula X y el nivel) y elección del jefe.
  - `turno_jugadores.dart`: orden de la ronda, daño al jefe, ataque a un aliado, cartas de ánimo, estados y KO.
  - `turno_jefe.dart`: ataques del jefe (ranura, daño, objetivo), ataques de aliados, KO, estados y moneda de la quemadura al cerrar el turno.
  - `fin_partida.dart`: resultado y puntos por jugador (con el bono de estados).
  - `pendientes.dart`: intentos de invocación y ataques de entrada de los aliados, que el motor exige resolver antes de seguir.
  - Deshacer, rehacer, envíos, cuenta y abandonar van en una barra flotante sobre la mesa (en las demás fases, en la barra superior).
- El jefe se escribe a mano (nombre, HP, cada cuántos HP invoca) hasta que exista el catálogo versionado (T-13).
- **El diseño visual sigue evolucionando** (maquetas en curso: #155–#157).
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

## Ejecutar la app

Las carpetas de plataforma (`android/`, `windows/`, `web/`) ya están en el repo, generadas con:

```
flutter create . --org dev.ayme99 --project-name incursiones_app --platforms=android,windows,web
```

(No hace falta repetirlo. Si algún día se añade otra plataforma, se ejecuta con ella y se revisa que no toque `lib/` ni `test/`.)

```
cd app
flutter pub get
flutter test
flutter run -d windows     # o: -d chrome, o un móvil Android conectado
```

La versión web funciona igual, pero **sin conexión no funciona**: la cola de envío de resultados vive en el navegador. El CI compila la web en cada cambio (`flutter build web`).

## Catálogo de jefes (T-29)

El catálogo (`../catalog/`) va empaquetado dentro de la app en `assets/catalogo/`, porque Flutter solo incluye archivos de dentro de `app/`. Si cambias un jefe en `catalog/`, copia el catálogo con `tool/sync_catalogo.sh`; `test/catalogo_test.dart` falla si las dos copias no coinciden. En el setup, tras calcular el nivel, la app ofrece los jefes de ese nivel (HP, ataques e invocación) o la entrada a mano. Los aliados de cada jefe se leen en `lib/catalogo/catalogo.dart` y los usa la pantalla de invocación.
