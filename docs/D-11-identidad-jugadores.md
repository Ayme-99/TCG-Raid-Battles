# D-11 · Identidad de jugadores

Estado: decidido (2026-11-05). Issue #20.

## 1. Cuentas

Incursiones **usa las mismas cuentas que Deck Tracker**: un solo usuario y una sola sesión para las dos apps.

- El backend de Incursiones no tiene tabla de usuarios propia. Valida la sesión de Deck Tracker (el mismo token) y lee el **id de usuario**.
- Los datos de Incursiones (partidas, puntos, desbloqueos) guardan solo ese id como `jugador_id` / `cuenta_id`. No se acoplan los modelos de datos de las dos apps (el router de `server/` se monta en el backend de Deck Tracker, como indica el README).
- No hay registro ni login propio en Incursiones: si no tienes cuenta de Deck Tracker, la creas allí.

## 2. Quién juega y quién cobra

| Rol | Cuenta | Cobra puntos |
|---|---|---|
| **Host** | Obligatoria (necesita cuenta para usar la app) | Sí |
| **Jugador unido** | Cuenta iniciada en su propio dispositivo | Sí |
| **Invitado** | Ninguna: juega en el dispositivo del host con un nombre de mesa | No (su parte se pierde, D-10) |

## 3. Unirse a una partida

Un jugador con cuenta se une desde su dispositivo por **cualquiera de estas tres vías**:

1. **Código corto de sala**: el host muestra un código de 4-6 caracteres y los demás lo escriben con su sesión iniciada.
2. **QR**: el host muestra un QR con el código y se escanea.
3. **Botón de invitar**: el host comparte un enlace de invitación (compartir del sistema) que abre la app y entra en la sala.

Las tres llevan a la misma sala; el código es el identificador común. Cada jugador unido puede introducir sus valores en su turno, o todo lo gestiona el host (D-10 §7).

## 4. Invitados en el historial

Las filas de invitados **se guardan** en `partida_jugadores` con `jugador_id` vacío y el **nombre de mesa** que puso el host, con `puntos` calculados pero no abonados. Así se puede auditar el reparto y reconstruir la partida. No cuentan para el total de ninguna cuenta.

## 5. Sin conexión

- Una partida puede jugarse **sin conexión** en el dispositivo del host (con invitados). Se guarda en el dispositivo y se envía al backend al recuperar la red, con el `_id` generado por el cliente para que los reintentos no dupliquen (D-10 §5).
- **Unirse con otra cuenta requiere conexión** (hay que validar la cuenta y sincronizar). Sin red, solo el host cobra su parte y los demás participan como invitados.
- Si el host no ha iniciado sesión al guardar, la partida queda pendiente hasta que lo haga.

## 6. Requisitos para el backend

- Validar el token de Deck Tracker en cada petición de `/api/incursiones/*` y extraer el id de usuario.
- Guardar partidas con `_id` de cliente (idempotente).
- Crear, unir y cerrar salas por código; resolver el enlace de invitación al código.
- No exponer datos de Deck Tracker más allá del id y el nombre visible del usuario.

## 7. Cambios en otros documentos

- `docs/D-10-sistema-de-puntos.md`: invitados guardados con nombre de mesa; `jugador_id` = id de usuario de Deck Tracker.
- `incursiones_gdd.md` → v0.12: identidad de jugadores.
