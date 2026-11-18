# Protocolo de sala (versión 1)

Mensajes WebSocket de la partida multi-dispositivo. Decisión de D-19 §D11 (`docs/D-19-partida-multidispositivo.md`), tarea T-78 (#268). Es un protocolo **aparte del contrato del registro** y se versiona por separado: `protocolo` en el `hola`.

Los **eventos viajan con el JSON del contrato del registro** (hoy la versión 13: `$ref` a `partida.v13.schema.json#/$defs/evento`); solo se añade el sobre. Si el contrato sube de versión, hay que actualizar esa referencia y comprobar que el protocolo sigue valiendo.

| Archivo | Qué es |
|---|---|
| `sala.v1.schema.json` | Esquema JSON (draft 2020-12) de todos los mensajes: cada mensaje es un objeto con `tipo` y sin campos desconocidos. |
| `ejemplos/validos/` | Un ejemplo de cada mensaje (y variantes). |
| `ejemplos/invalidos-estructura/` | Mensajes que el esquema rechaza: tipo desconocido, versión futura, código con letra ambigua, campo que falta o sobra... |

Los prueba `server/test/protocolo_sala.test.js` (el CI lo ejecuta con el resto del servidor).

## Mensajes

| Dirección | `tipo` | Campos | Para qué |
|---|---|---|---|
| Cliente → servidor | `hola` | `protocolo` (1), `token`, `codigo`, `ultimoSeq?` | Primer mensaje: autentica y entra en la sala. `ultimoSeq` si reconecta. El token va aquí, **nunca en la URL**. |
| Servidor → cliente | `sala` | `estado`, `host`, `tuAsiento`, `jugadores[{asiento, nombre, conectado}]`, `ultimoSeq`, `partidaId?`, `creadaEn?` | Estado de la sala. Se manda al entrar y cada vez que cambia. |
| Cliente → servidor | `proponer` | `idMensaje`, `evento` | Un jugador propone un evento de su asiento y de su turno (D2). |
| Servidor → host | `proponer` | `idMensaje`, `asiento`, `evento` | La propuesta, con el asiento de la conexión de origen (lo pone el servidor). |
| Host → servidor | `aceptar` | `seq`, `evento`, `idMensaje?` | El evento entra en el registro. Sin `idMensaje` si lo genera el propio host (turno del jefe). |
| Host → servidor | `rechazar` | `idMensaje`, `motivo` | El motor ha rechazado la propuesta; el servidor se la reenvía a quien la hizo. |
| Servidor → todos | `evento` | `seq`, `evento`, `idMensaje?` | Evento aceptado, con su número en el registro. |
| Servidor → todos | `jugadorDesconectado` | `asiento`, `venceEn` | Se cayó una conexión. Con el asiento del host, la sala queda en «host ausente». |
| Servidor → todos | `jugadorVuelve` | `asiento` | Ha vuelto antes de que venza. |
| Servidor → host | `ventanaVencida` | `asiento` | **Añadido.** Venció la ventana de un jugador: el host registra un `pokemonKo` por cada Pokémon que le quede (D9). |
| Servidor → todos | `partidaCancelada` | `motivo` (`hostDesconectado`, `hostCancelo`), `texto?` | La sala se cierra sin guardar ni dar puntos. |
| Ambos | `registro` | `desdeSeq`, `eventos[]` | Servidor → cliente al reconectar. Host → servidor para reconstruir la sala tras un reinicio (`desdeSeq` 1). |
| Ambos | `ping` / `pong` | — | Latido cada 10 s; sin respuesta en 25 s, caída (D5). |
| Host → servidor | `empezar` | `partidaId`, `creadaEn` | **Añadido.** Cierra la sala a nuevas entradas y fija el id y la fecha para todos (D8). |
| Host → servidor | `echar` | `asiento` | **Añadido.** Expulsa a un jugador en el lobby (D7). |
| Cliente → servidor | `salir` | — | **Añadido.** Sale en el lobby (D7). |
| Servidor → cliente | `error` | `codigo`, `texto`, `idMensaje?` | **Añadido.** Un mensaje no se puede atender. Un cliente con otra versión recibe `protocoloNoSoportado` (D11). |

**Añadido** = lo exigen D7, D8, D9 o D11 («un error claro») pero no estaba en la tabla de §D11. Es la única diferencia con el documento.

## Reglas

- **`seq`** es la posición del evento en el registro, **desde 1** y sin huecos. `ultimoSeq` 0 significa «no tengo ninguno». El servidor responde a un `hola` con `ultimoSeq` con un `registro` desde `ultimoSeq + 1`.
- **`idMensaje`** (1 a 64 caracteres) lo genera quien propone. Un reintento con el mismo id no se aplica dos veces.
- El **código de sala** son 5 caracteres de `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (sin `0`, `1`, `I`, `L` ni `O`).
- `estado` de la sala: `abierta` → `completa` → `enCurso` → `terminada` | `cancelada` (D6).
- Lo que valida el motor lo decide el **host**. El servidor solo comprueba que quien manda es quien dice ser y que está en la sala (D11). El esquema solo comprueba la **estructura**.
- Los eventos que puede proponer un jugador son solo los de su asiento y su turno (D2); eso lo aplica el host, no el esquema.

## Flujo básico

1. El host crea la sala con `POST /salas` y recibe el código. Todos abren el WebSocket y mandan `hola`; el servidor contesta `sala`.
2. El host manda `empezar`; la sala pasa a `enCurso` y todos reciben `sala` con `partidaId` y `creadaEn`.
3. Un jugador manda `proponer`; el servidor se lo pasa al host; el host manda `aceptar` (o `rechazar`) y el servidor difunde `evento`.
4. El turno del jefe lo genera la app del host (T-77): una serie de `aceptar` sin `idMensaje`.
5. Si cae un jugador: `jugadorDesconectado` → (vuelve: `jugadorVuelve` + `registro`) o (vence: `ventanaVencida` al host).
