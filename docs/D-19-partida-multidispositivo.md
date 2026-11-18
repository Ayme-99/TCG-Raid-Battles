# D-19 · Partida multi-dispositivo (sala, sincronización, host autoritativo)

Estado: **borrador para cerrar** (2026-11-18). Issue #158 (T-57). Depende de T-53 (#154) y T-54 (#155, `docs/diseno-ui/mapa-pantallas.md`).

Este documento decide la arquitectura **antes de escribir código**. Cada decisión lleva una recomendación y lo que se descarta. Lo que sigue sin respuesta está en la sección 9.

## 1. Alcance

**Entra:** crear y entrar a una sala, sincronizar el registro de eventos en tiempo real, quién valida cada evento, desconexión y reconexión, transporte y reparto del servidor, guardado final.

**No entra:**
- Las **cartas digitales**, la campaña, la tienda y «Mis cartas». El formato digital aún no está diseñado (`flujo-app.md` §1 bis). Aquí solo se construye la **infraestructura** para que varios dispositivos compartan una partida.
- El aspecto de las pantallas: es de T-55 y T-56.
- Partida mixta (algunos en físico, otros en su dispositivo): descartada.

## 2. Lo ya decidido (no se reabre)

De T-53 y de las decisiones del 2026-11-18:

| Tema | Decisión |
|---|---|
| Modo | Un dispositivo por jugador = formato digital: online, con sesión **obligatoria** para todos. Da puntos. |
| Turnos | Cada jugador apunta su propio daño en su turno. |
| Turno del jefe | **Automático.** La baraja de ataques está en la app. Las monedas y los dados los tira el jefe (la app). El host solo pasa al «siguiente». |
| Cámara | Depende solo del estado de la partida; es igual para todos. |
| Deshacer | No existe en digital. El registro **solo crece**. |
| Desconexión de un jugador | Se espera 2 minutos, con un mensaje para todos. Si no vuelve, sus Pokémon se dan por KO. |
| Desconexión del host | Se pierde la partida. |
| Entrada | Invitación dentro de la app o código. |
| Resultados | Cada jugador guarda los suyos. |

## 3. De dónde partimos

Lo que ya existe y condiciona todo lo demás:

1. **El motor es un reductor puro de eventos** (`engine/`). Una partida es una lista de eventos y el estado sale de reproducirlos. No usa azar propio: **todo resultado de moneda o dado va dentro del evento** (`AtaqueJefe.efecto.moneda`, `FinTurnoJefe.monedaQuemadura`, `AliadoInvocado.monedas`, `AtaqueAliado.moneda`...). Por eso reproducir un registro da siempre lo mismo. Es lo que permite sincronizar: basta con repartir los eventos.
2. **El azar vive en la app**, no en el motor: `azarProvider` (`Random.secure()`) y el `MazoAtaquesJefe`, que se baraja en el dispositivo. El orden del mazo **no se guarda** en ningún evento.
3. **Hoy el turno del jefe lo hace el humano en la pantalla**: roba la carta, introduce el daño y el objetivo, tira las monedas y registra el evento (`turno_jefe.dart`). Hay que automatizarlo. El simulador (`sim/bin/sim_jefes.dart`) ya juega turnos de jefe enteros con el motor y el mazo, así que hay lógica que reutilizar.
4. **El servidor solo recibe partidas terminadas** (`server/`): valida el esquema, que el usuario juega en ella y que el resumen cuadra, y abona puntos. **No ejecuta las reglas** y no hay conexión en tiempo real. Es un módulo Express que se copia a `TCGMasters-server` (Render) y se monta junto al backend de Deck Tracker.
5. **El registro ya tiene `cuentas`** (id de usuario por asiento) y un `partidaId` idempotente.
6. **D-11 ya definía la sala por código** (4 a 6 caracteres), con QR y enlace de invitación. Las decisiones de la sección 2 lo concretan (ver sección 8).

## 4. Decisiones

### D1 · Quién es autoritativo: el dispositivo del host

**Recomendación:** el **host valida** cada evento con el motor y es la fuente de verdad. El servidor es un **repetidor** con memoria del registro: reparte eventos y no ejecuta reglas.

| Opción | A favor | En contra |
|---|---|---|
| **A. Host autoritativo, servidor repetidor** (recomendada) | El motor ya está en Dart y en la app: cero portado. Casa con «si cae el host se pierde la partida». El servidor sigue siendo simple. | Un host tramposo podría falsear su partida (ver D8). |
| B. Servidor autoritativo ejecutando el motor | Sin confianza en el host; admite recuperar la partida si cae el host. | Hay que portar el motor a JS o ejecutar Dart en el servidor, y rehacer el despliegue. Contradice la decisión de perder la partida si cae el host. |

El flujo de un evento:

```
Jugador ──propone──▶ Servidor ──▶ Host: valida con el motor
                                    ├─ válido:   difunde evento nº N a todos (vía servidor)
                                    └─ inválido: rechazo solo al que propuso
```

- Cada evento aceptado lleva un **número de secuencia** (`seq`, 0, 1, 2…). Los clientes los aplican **en orden**.
- Todos los clientes (host incluido) llevan el mismo registro y reconstruyen el mismo estado con el motor. El host no es especial salvo en que decide qué se acepta.
- Un cliente **nunca aplica** un evento que no haya difundido el host. Así no hay estado «provisional» que deshacer.

### D2 · Quién puede proponer qué

Un jugador solo propone eventos **de su asiento y de su turno**:

| Propone | Eventos |
|---|---|
| Jugador, en su turno | `TurnoJugador` (su daño) y `AtaqueAAliado` (su ataque a un aliado) |
| Host | `Abandonar` y el «siguiente» del turno del jefe |
| La app del host, automáticamente | Todo el turno del jefe: `AtaqueJefe`, `DanoDeEfecto`, `AliadoInvocado`, `AtaqueAliado`, `FinTurnoJefe`, `CuracionJefe`, `PokemonKo` por desconexión… |

El host rechaza una propuesta si el motor la rechaza (fase equivocada, no es su turno, jugador eliminado) o si el asiento no coincide con el de la conexión. Los estados alterados (`AplicarEstado*`), las cartas de ánimo y las demás acciones dependen de cómo sean las **cartas digitales**, que no están diseñadas: se decide cuando lo estén.

### D3 · El azar lo genera el host

Todo azar (mazo de ataques del jefe, monedas, dados de invocación) lo genera la **app del host** y **se queda dentro de los eventos**, como hoy. Los demás dispositivos no tiran nada: pintan lo que llega.

- El **mazo de ataques** (orden de las 20 cartas) vive solo en el host. No hace falta sincronizarlo: si cae el host, la partida se pierde (sección 2).
- Consecuencia buena: las animaciones de dados y monedas se pueden reproducir **en todos los dispositivos a partir del evento**, que ya trae el resultado.
- No se cambia el contrato ahora. Más adelante, si el servidor ha de auditar partidas, habría que guardar la carta robada (`numero`) en el evento y subir la versión del contrato.

### D4 · El turno del jefe automático es un requisito previo

Hoy el turno del jefe se compone a mano en pantalla. Para el digital hace falta una función que, dado el estado, el mazo y un `Random`, **devuelva los eventos del turno completo**.

**Recomendación:** ponerla en el **motor** (`engine/`), como función pura con el azar inyectado: se prueba con semillas, la usa el simulador (que ya tiene esa lógica repetida en `sim_jefes.dart`) y la puede usar el host único en formato digital con un solo dispositivo. Es la primera tarea de la lista de la sección 7.

Queda fuera de esta función lo que hoy «resuelve la mesa» (efectos de los aliados con `efectos: jugador`): en digital no hay mesa, así que cada aliado debería pasar a tener `programa`/script. Es un efecto colateral que se apunta, no se diseña aquí.

### D5 · Transporte: WebSocket en el mismo backend

**Recomendación:** **WebSocket** sobre el servidor HTTP que ya despliega Render (`TCGMasters-server`), con la librería `ws`, y **reconexión propia** en el cliente (con espera creciente).

| Opción | Veredicto |
|---|---|
| **WebSocket (`ws`)** | Recomendada. Es bidireccional, de baja latencia y la app Flutter lo trae resuelto. Render lo admite. |
| Server-Sent Events + peticiones REST | Válida, pero obliga a mantener dos canales por jugador. |
| Sondeo (polling) | Descartada: latencia mala y mucho tráfico para turnos con animaciones. |
| Servicio externo (Firebase, Supabase Realtime) | Descartada: nueva dependencia, otro sistema de cuentas y otro coste. Las cuentas ya son las de Deck Tracker. |

Puntos prácticos:
- El módulo actual (`crearRouter`) es un router Express; el WebSocket necesita el **servidor HTTP** (`upgrade`), así que el módulo exporta además una función de montaje para esa parte, y `TCGMasters-server` debe pasársela.
- La **autenticación** va en el primer mensaje (`hola` con el token de sesión), **no en la URL** (las URL acaban en registros).
- **Latido:** un `ping` cada 10 s; sin respuesta en 25 s se da la conexión por caída y empieza la cuenta de desconexión.
- **Una sola instancia** del servidor. Si algún día hay varias, hará falta enrutado por sala; no se resuelve ahora.
- Un reinicio del servidor (despliegue, Render) tira las salas. Es aceptable por D6, pero hay que **evitar desplegar con partidas en curso** y la app debe mostrar un mensaje claro.

### D6 · Dónde vive el estado de la sala

**Recomendación:** **en memoria del servidor**, sin base de datos. La verdad la tiene el host (D1); el servidor guarda una copia del registro solo para servir a quien vuelve.

- Si el servidor se reinicia, el host reconecta y **vuelve a enviar su registro**, y la sala se reconstruye. Los demás jugadores reconectan después y reciben el registro. Mientras tanto se ven en «reconectando».
- La partida solo se escribe en base de datos **al terminar**, por el camino que ya existe (`POST /partidas`, sección D8).
- El estado de una sala: `abierta` (en el lobby) → `completa` → `en curso` → `terminada` | `cancelada`.

### D7 · Salas y entrada

- El host crea la sala con `POST /salas` (con su sesión). Recibe un **código de 5 caracteres**, sin las letras que se confunden (`0/O`, `1/I/L`), único entre las salas vivas.
- Hasta **4 jugadores** (el máximo del motor). El host es el asiento 0 y **también juega**. Los demás reciben asiento por orden de llegada.
- Se entra con el **código** (se escribe con la sesión iniciada) o con una **invitación dentro de la app**. La invitación requiere amigos (T-64, #237); **el código funciona solo** y es lo que se construye primero.
- La sala **se cierra a nuevas entradas** cuando empieza la partida. Solo se puede volver a entrar quien ya estaba (reconexión, D9).
- Antes de empezar, el host puede **echar** a un jugador. Un jugador puede salir libremente en el lobby. Una vez empezada, salir equivale a desconectarse.
- Una cuenta solo puede estar en **una sala viva** a la vez.

### D8 · Guardar el resultado

Cada jugador guarda el suyo con el camino ya existente (`POST /partidas`, idempotente por `partidaId`). Para que funcione con varios dispositivos:

1. El **`partidaId` y `creadaEn`** los fija el host al crear la partida y viajan a todos. Hoy se generan al pedir el registro (`controlador_partida.dart`), lo que daría un id distinto en cada dispositivo.
2. **El registro serializado debe ser idéntico** en todos los dispositivos. Como los eventos son los mismos y el motor serializa de forma determinista, basta con que el orden y el contenido no cambien.
3. **`cuentas` lo rellena el servidor** a partir de los jugadores autenticados de la sala, no el cliente. Así nadie puede anotarse una cuenta ajena.
4. El primero que guarda crea la partida; los demás reciben `200 duplicada` y su `tusPuntos`. Ya lo hace el servidor.

**Riesgo asumido y apuntado:** como el servidor no ejecuta las reglas, un host y su grupo podrían fabricar una partida para ganar puntos. Hoy el servidor ya acepta ese riesgo (`server/README.md`: «no ejecuta las reglas»), y con puntos cobra más importancia en el digital. Cuando importe, la salida es reproducir el registro en el servidor (portar el motor o ejecutar Dart). Es una decisión aparte y no bloquea esto.

### D9 · Desconexión y reconexión

**Un jugador (no host):**

1. El servidor detecta la caída (D5) y avisa a todos: `jugadorDesconectado { asiento, venceEn }`. Todos ven el mensaje con la cuenta atrás de **2 minutos**.
2. Si es **su turno**, la partida **espera** (no se salta el turno).
3. Si vuelve antes de vencer: reconecta con su sesión, recupera su asiento y el servidor le manda el registro desde el último evento que tenía (`seq`).
4. Si vence: el servidor avisa al host y la **app del host registra un `PokemonKo` por cada Pokémon que le quede** a ese jugador. Reutiliza el evento que ya existe; **no hace falta contrato nuevo**. Si el motor lo da por eliminado, se salta su turno como cualquier jugador eliminado.

**El host:**

- Si se cae, la partida **se pierde** (decidido). Todos reciben `partidaCancelada { motivo: hostDesconectado }`, la sala se cierra y no se guarda ni se dan puntos.
- Propuesta: dar al host **la misma ventana de 2 minutos** antes de cancelar, para no perder una partida entera por un parpadeo de la red o por pasar la app a segundo plano un momento. Ver pregunta 1.

**En móviles:** si el sistema suspende la app, el WebSocket se corta, así que cuenta como desconexión. Conviene que la app mantenga la pantalla encendida en partida (ya lo hace `wakelock`) y avise al jugador antes de salir de ella.

### D10 · Presentación sincronizada

La cámara y todo lo visible salen del **estado**, igual para todos (decidido). Falta decidir cómo se muestran las animaciones, porque hoy se lanzan desde la acción del usuario y no desde el evento:

- Cada dispositivo **reproduce las animaciones a partir de cada evento que llega** (monedas, dados, avisos centrales): el evento ya trae el resultado (D3).
- Los eventos de un turno de jefe llegan juntos; cada cliente los pone en **cola** y los reproduce de uno en uno (como ya hacen los avisos centrales).
- Un jugador solo puede apuntar su daño cuando **es su turno y su cola de animaciones está vacía**. Así no actúa sobre un estado que aún no ha visto.
- El host no espera a que los demás terminen de animar para difundir; cada cliente se pone al día por su cuenta.

### D11 · Protocolo de mensajes

Los **eventos viajan con el mismo JSON del contrato** (el del registro); solo se añade un sobre. El resto de mensajes es un protocolo nuevo, versionado aparte.

| Dirección | Mensaje | Contenido |
|---|---|---|
| Cliente → servidor | `hola` | token de sesión, `codigo`, `ultimoSeq` (si reconecta) |
| Servidor → cliente | `sala` | jugadores y asientos, estado, quién es el host |
| Cliente → servidor | `proponer` | `idMensaje`, evento propuesto |
| Servidor → host | `proponer` | lo mismo, más el asiento de origen |
| Host → servidor | `aceptar` | `seq`, evento |
| Host → servidor | `rechazar` | `idMensaje`, motivo |
| Servidor → todos | `evento` | `seq`, evento |
| Servidor → todos | `jugadorDesconectado` / `jugadorVuelve` | asiento, `venceEn` |
| Servidor → todos | `partidaCancelada` | motivo |
| Servidor → cliente | `registro` | eventos desde `seq` (al reconectar) |
| Ambos | `ping` / `pong` | latido |

- Los mensajes llevan `idMensaje` para que un reintento no se aplique dos veces.
- La versión del protocolo va en `hola`; un cliente viejo recibe un error claro.
- Lo que valida el motor (reglas) lo decide el host. El servidor solo comprueba que quien manda es quien dice ser y que está en la sala.

## 5. Qué cambia en cada pieza

| Pieza | Cambio |
|---|---|
| **Motor** (`engine/`) | Función del **turno del jefe automático** (D4). Ningún evento nuevo ni versión de contrato. |
| **Contrato** (`contrato/`) | Nada por ahora. Un documento nuevo describe el **protocolo de sala** (D11). |
| **Servidor** (`server/`) | Módulo de salas con WebSocket, `POST /salas`, estado en memoria, latidos, cuenta atrás de desconexión. Relleno de `cuentas` al guardar. Exportación a `TCGMasters-server` (`docs/DEPENDENCIAS.md` §3) y su montaje con el servidor HTTP. |
| **App** (`app/`) | Capa de red (sala, sincronización, reconexión); partida basada en el registro compartido; animaciones a partir de eventos; pantallas de sala, unirse y espera (T-54, T-56); `partidaId` fijado por el host. |
| **Deck Tracker** | Ninguno, salvo montar el módulo. Las invitaciones dependen de amigos (T-64). |

## 6. Dependencias con otras tarjetas

- **T-64 (#237, perfil, historial y amigos):** las invitaciones dentro de la app. El código no depende de ella.
- **T-55 y T-56 (diseño):** las pantallas de sala, unirse, espera y desconexión.
- **Formato digital (cartas, campaña):** qué eventos pueden proponer los jugadores aparte de su daño (D2). Es lo único de este documento que **queda abierto a propósito**.

## 7. Tareas derivadas (para crear tras aprobar)

En este orden, porque cada una desbloquea la siguiente:

1. **Motor:** turno del jefe automático (D4). Sirve ya para el digital en un solo dispositivo.
2. **Contrato del protocolo:** mensajes de sala (D11), con esquema y ejemplos, como el del registro.
3. **Servidor:** salas por código, WebSocket, difusión de eventos y registro en memoria (D5 a D7, D11), con tests.
4. **Servidor:** latidos, desconexión con cuenta atrás y reconexión (D9).
5. **App:** capa de red y partida compartida (sala, sincronización, sesión obligatoria).
6. **App:** animaciones y avisos a partir de eventos, con cola (D10).
7. **App:** pantallas de sala, unirse, espera y desconexión (con los diseños de T-56).
8. **Guardado:** `partidaId` del host y `cuentas` puestas por el servidor (D8).
9. **Invitaciones dentro de la app** (cuando haya amigos, T-64).

## 8. Cambios en otros documentos

- **`D-11-identidad-jugadores.md`:** en el modo un dispositivo por jugador (digital) la sesión es **obligatoria para todos** y **no hay invitados**; el QR no se construye (solo código e invitación). Lo de «sin conexión» e invitados sigue valiendo para el **formato físico** en un solo dispositivo.
- **`DEPENDENCIAS.md`:** cuando exista el módulo de salas, añadir su fila (servidor externo y protocolo).
- **`flujo-app.md` §8:** la partida multi-dispositivo deja de estar «fuera de alcance» cuando se apruebe este documento.
- **GDD:** sin cambios; esto no toca reglas de juego.

## 9. Preguntas para cerrar

1. **¿Qué margen tiene el host al caerse?** Recomendado: la misma ventana de 2 minutos que los jugadores antes de cancelar la partida (D9). La alternativa es cancelar al instante.
2. **¿Cobra puntos un jugador que se desconecta y no vuelve?** Sus Pokémon se dan por KO, pero la partida puede ganarse o perderse. Recomendado: **cobra lo que le toque** por el daño hecho (el reparto ya lo calcula `puntos.dart`) y sin penalización añadida; no se castiga más de lo decidido.
3. **¿Se acepta confiar en el host en esta primera versión (D8)?** Recomendado: sí, con el riesgo apuntado, y revisarlo cuando los puntos desbloqueen cosas que importen.
4. **¿Puede una sala tener un solo jugador (el host)?** Recomendado: no; con un jugador es el digital de un solo dispositivo, sin sala.
5. **¿Hay espectadores?** Recomendado: no, ni ahora ni en esta tarjeta.
