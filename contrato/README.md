# Contrato del registro de partida (versión 1)

Formato JSON con el que la app guarda una partida y la envía al backend. Una partida es **el registro de sus eventos**: el estado se reconstruye reproduciéndolos con el motor (`engine/`). Decisión de T-07 (issue #41).

## Qué hay en esta carpeta

| Archivo | Qué es |
|---|---|
| `partida.v1.schema.json` | Esquema JSON (draft 2020-12) de la versión 1. Es el que usa el backend para validar. |
| `ejemplos/validos/` | Registros correctos (terminados y en curso). |
| `ejemplos/invalidos-estructura/` | Registros que **el esquema rechaza** (versión futura, tipo de evento desconocido, campo del tipo equivocado, campo que falta, campo desconocido). |
| `ejemplos/invalidos-reglas/` | Registros con estructura correcta que **solo el motor rechaza** porque incumplen las reglas (turno fuera de orden, eventos tras el final, cuentas que no coinciden con los jugadores). |

Los ejemplos válidos están probados por los dos lados: el motor los lee y los vuelve a escribir igual (`engine/test/registro_test.dart`) y el esquema los acepta (`server/test/contrato.test.js`). El CI ejecuta ambos.

## Registro

```json
{
  "version": 1,
  "partidaId": "id generado por el cliente",
  "creadaEn": "2026-11-06T09:30:00Z",
  "cuentas": ["usuario-ana", null],
  "eventos": [ { "tipo": "configurarJugadores", "...": "..." } ],
  "resumen": { "...": "solo si la partida ha terminado" }
}
```

| Campo | Obligatorio | Descripción |
|---|---|---|
| `version` | sí | Entero. Hoy, `1`. |
| `partidaId` | sí | De 1 a 64 caracteres, generado por el cliente. Una partida se guarda una sola vez con este id (así los reintentos de red no la duplican, D-11). |
| `creadaEn` | no | Fecha ISO 8601. |
| `cuentas` | no | Un elemento por jugador, por asiento: el id de cuenta (el id de usuario de Deck Tracker, D-11) o `null` si es un invitado. Si falta, se asume que todos cobran. |
| `eventos` | sí | Lista no vacía de eventos, en orden. |
| `resumen` | no | Puntos de la partida, calculados al cerrarla (ver más abajo). |

## Eventos

Cada evento es un objeto con un campo `tipo`. Los campos marcados con `?` son opcionales y, si no hay valor, **no se escriben** (nunca `null`). Los jugadores se indican por **asiento** (0 a 3). No se admiten campos desconocidos.

| `tipo` | Campos | Cuándo |
|---|---|---|
| `configurarJugadores` | `jugadores`: lista de 1 a 4 `{nombre, ataqueMaximo}` | Setup: calcula X y el nivel |
| `elegirJefe` | `nombre`, `nivel` (1-4), `hp`, `jefeId?`, `invocacionCadaHp?` | Setup: empieza la ronda 1 |
| `turnoJugador` | `jugador`, `dano` (≥ 0) | Turno de un jugador contra el jefe (0 si pasa) |
| `ataqueAAliado` | `jugador`, `slot`, `dano` | Un jugador ataca a un aliado en lugar de al jefe |
| `ataqueJefe` | `ranura` (1-3), `dano`, `jugador?`, `alAzar?` | Ataque del jefe (sin `jugador`: a todos) |
| `pokemonKo` | `jugador` | Cae un Pokémon de un jugador |
| `cartaAnimoRobada` | `jugador`, `carta` (1-5) | Un jugador con prioridad roba carta de ánimo |
| `curacionJefe` | `cantidad` | El jefe se cura (el motor topa al HP máximo) |
| `sinInvocacion` | — | Intento de invocación sin aliado |
| `aliadoInvocado` | `slot`, `nombre`, `hp`, `ataqueNombre?`, `ataqueDano?`, `habilidad?` | Intento de invocación con aliado |
| `ataqueAliado` | `slot`, `dano`, `objetivo?` | Ataque de un aliado (al entrar y al final del turno del jefe) |
| `finTurnoJefe` | — | Cierra la ronda |
| `abandonar` | — | La mesa abandona: derrota |

## Resumen

Se escribe al cerrar la partida y **se conserva tal cual**: cambios futuros en las tablas de puntos no reescriben el historial (D-10 §5). Contiene `jefeId?`, `nivel`, `resultado` (`victoria` o `derrota`), `danoTotal` (vida perdida por el jefe, neto de curaciones, D-06), `coeficienteY`, `puntosTotal` y `jugadores`, ordenados por puesto, con `asiento`, `nombre`, `dano`, `pokemonPerdidos`, `puesto`, `porcentaje`, `puntos` y `abonado` (los invitados ocupan puesto pero no se les abona).

### Relación con el guardado de D-10 §5

| Colección | Sale de |
|---|---|
| `partidas` | `_id` = `partidaId`; `fecha` = `creadaEn`; `jefe_id`, `nivel`, `resultado`, `dano_total`, `coeficiente_y`, `puntos_total` = campos del `resumen`; `jugadores` = longitud de `resumen.jugadores` |
| `partida_jugadores` | Una fila por `resumen.jugadores`: `jugador_id` = `cuentas[asiento]` (`null` = invitado), `dano`, `pokemon_perdidos`, `puesto`, `porcentaje`, `puntos` |

El backend guarda además el registro completo (los eventos) para poder repetir o auditar la partida.

## Versionado y compatibilidad

- `version` es un entero. **Cualquier cambio del formato sube la versión**, también añadir un tipo de evento o un campo; el esquema de cada versión vive en su propio archivo (`partida.v2.schema.json`, ...) y los antiguos se conservan.
- El motor **lee todas las versiones hasta la suya**: cada versión antigua se migra a la siguiente con una función sobre el JSON (`_migraciones` en `engine/lib/src/registro.dart`). Un cambio que solo añade cosas opcionales se migra sin tocar nada. Las partidas guardadas se leen siempre; no se reescriben al migrar.
- Un registro de una **versión futura se rechaza** con un mensaje que pide actualizar la aplicación.
- El backend valida con el esquema de la versión que declara el registro y guarda el JSON original con su `version`.

## Quién valida qué

| Qué | Quién |
|---|---|
| Estructura, tipos, rangos de campos, campos desconocidos | Esquema JSON (backend) y lector del motor (app) |
| Que los eventos cumplan las reglas del juego (orden de turno, fases, KO, aliados...) | Solo el motor (Dart) |
| Que `cuentas` tenga un elemento por jugador | Solo el motor |
| Que el `resumen` sea el que saldría de las reglas | Nadie al leer: se conserva lo guardado |

**Decisión abierta para T-08:** el backend es Node y no puede ejecutar el motor Dart, así que hoy se fía de que la app envía una partida legal y un `resumen` correcto. Si eso fuera un problema (puntos que desbloquean jefes), habría que recalcular en el servidor, por ejemplo portando el motor o ejecutándolo como proceso aparte.
