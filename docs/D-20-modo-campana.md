# D-20 · Modo campaña

Estado: **diseño, pendiente de aprobar** (2026-11-21). Issue #334. Nada de esto está implementado.

## 1. Idea

La campaña es un **juego de Pokémon para un jugador**: eliges un inicial, recorres rutas, capturas Pokémon, descansas, ganas medallas y te enfrentas a un jefe con sus aliados. Es **ajena a la partida libre**: tiene sus propias criaturas, su propio combate y su propio motor. Lo único que comparte con las incursiones es el **catálogo de jefes** (nombres, mapas, aliados) y la **moneda del juego** (los puntos).

| | Partida libre | Modo campaña |
|---|---|---|
| Jugadores | 1 a 4 | 1 |
| Formato | físico (offline) o digital (online) | digital |
| Qué se juega | cartas reales (físico) o cartas digitales | Pokémon de campaña con PS, ataques y energía |
| Rival | el jefe, con su baraja de ataques | un Pokémon salvaje, un entrenador o un jefe con aliados |
| Da puntos | solo la digital | sí |

Decisiones de Ayme (2026-11-21): el modo es **1 contra 1** (2 contra 2 y 3 contra 3, en el futuro); las cartas de campaña **no** se usan en la partida libre; los puntos compran en la tienda monedas, dados, sobres y cartas sueltas del formato digital (y quizá campañas, aunque lo normal es que estén abiertas de primeras). Cuántos puntos da cada cosa es irrelevante salvo que la campaña tenga compras con puntos, y lo que sobre al terminarla se conserva.

## 2. Pokémon de campaña

Cada Pokémon es un registro del catálogo:

| Campo | Significado |
|---|---|
| `id`, `nombre`, `numero` | identidad |
| `tipo` | el tipo del Pokémon y de sus ataques |
| `debilidad`, `resistencia` | opcionales: tipo y valor (×2 y −30 de salida) |
| `ps` | puntos de salud |
| `retirada` | coste de cambiarlo por otro; **0 (gratis)** de salida |
| `ataques` | 1 a 3: `nombre`, `tipo`, `coste` (energía), `dano`, `efecto` opcional |
| `evoluciones` | lista (puede ser vacía): `a` (id) y cómo se consigue (ver 2.1) |
| `ex` | `true` si es una carta ex |
| `rareza` | cuánto cuesta encontrarlo en las rutas |

- El equipo tiene un **máximo de Pokémon por definir** (propuesta provisional: 6; es un parámetro).
- Los efectos de los ataques reutilizan las piezas que ya existen en las cartas de los aliados: monedas, curar, estados y habilidades pasivas. No se inventa un sistema de efectos nuevo.

### 2.1 Progresión: sin niveles, con XP y evolución

Decidido el 2026-11-21. **No hay niveles**: las cartas tienen siempre los mismos PS y daños; se mejora evolucionando.

- **Las victorias en combate dan puntos** (los mismos puntos del juego, §5).
- En un **centro Pokémon** (el nodo de descanso) se pueden **convertir puntos en XP** de un Pokémon del equipo. Cuántos puntos cuesta cada XP queda por equilibrar.
- Cada Pokémon necesita **N de XP** para evolucionar (`via: "xp"` y `xp: N` en la carta). Al llegar a N, puede evolucionar en un centro Pokémon, con un máximo de **un Pokémon por visita** (§4).
- **Objetos de evolución** (piedras…): se compran fuera de los centros Pokémon o se encuentran en las rutas (`via: "objeto"`, `objeto: "piedra-trueno"`).
- **Evolución por intercambio** (Kadabra, Haunter, Machoke, Graveler): cuesta **puntos**, por usar la máquina de intercambio (`via: "intercambio"`, `puntos: N`).
- **Cartas ex.** La **última fase de cada Pokémon es una carta ex**. Un Pokémon que no evoluciona (Onix…) puede hacerse ex **gastando puntos** (`via: "puntos"`, `puntos: N`), con el mismo proceso. Cada carta ex es una **entrada propia del catálogo** (`"ex": true`).
- **La carta evolucionada sustituye a la anterior** y recupera todos sus PS. Una forma evolucionada también puede aparecer salvaje en una zona si el catálogo la incluye, y entonces se captura aparte.
- Un Pokémon puede tener **varias** evoluciones (Eevee con sus piedras), por eso `evoluciones` es una lista.

Datos que hay que guardar en el progreso de campaña: **XP acumulada por cada Pokémon del equipo**.

## 3. Combate

**1 contra 1.** Cada bando tiene un Pokémon activo y el resto de su equipo en reserva. Gana quien deja sin Pokémon al otro.

### 3.1 Energía

Cada bando (jugador y «máquina») tiene una **reserva de energía de máximo 10**.

- Empieza en **10**.
- Cada ataque **gasta** su coste de la reserva. Si no hay energía suficiente, no se puede usar.
- Al **terminar su turno**, un bando **recupera 1** (decidido el 2026-11-21).

Ejemplo con un ataque de coste 3 usado todos los turnos: se puede atacar con `10, 8, 6, 4` de reserva y después queda en `2`, así que toca ahorrar (en cada turno se gastan 3 y se recupera 1 al terminar). Es una reserva y no un maná que sube por turno, y es lo que encaja con **una acción por turno**.

Los números (inicio, recuperación, máximo) son **parámetros** y se ajustan con el simulador.

### 3.2 Turno

Empieza el **jugador**. En su turno, un bando hace **una acción, y las tres gastan el turno**:

1. **Atacar** con el Pokémon activo (si le llega la energía).
2. **Cambiar** de Pokémon activo.
3. **Cargar:** no ataca y recupera **1 de energía más** de lo normal (2 en total ese turno), pensada para llegar al ataque grande. Sustituye a «Pasar» (decidido el 2026-11-21).

**Elegir el siguiente Pokémon** cuando cae el activo **no** gasta turno: su dueño lo elige y sigue su turno.

**Cambiar: turno o energía.** Se decidió que cambiar **gasta el turno**. La carta puede añadir además una **retirada con coste de energía** (el campo `retirada`; es 0 de salida, es decir, «retirada gratis»). Así, la retirada gratis significa que cambiar no cuesta energía, y un Pokémon pesado podría costar turno **y** energía. Si preferís que la retirada sea solo energía y no turno, es cambiar una línea del motor; queda a validar con el simulador.

### 3.3 Debilidades y resistencias

No hay una tabla de tipos global: **lo escribe cada carta**, como en el juego de cartas. Un Pokémon puede tener una **debilidad** (el daño de ese tipo se multiplica, ×2 de salida) y una **resistencia** (el daño de ese tipo baja, −30 de salida), o ninguna. Primero se aplica la debilidad y luego la resistencia, y el daño nunca baja de 0. Cada Pokémon tiene **un solo tipo**. No existen las inmunidades.

**Victoria:** gana el bando que deja sin Pokémon en pie al otro.

### 3.4 La «máquina»

El rival juega con **las mismas reglas** (la misma energía y las mismas debilidades y resistencias), de modo que los combates se igualan sin reglas asimétricas. Su decisión es **determinista** (`decidirAccion` en `engine/lib/src/campana/ia.dart`, #338), en este orden:

1. Si cae su activo, saca al relevo que no sea débil al rival, haga más daño y tenga más salud.
2. Si puede **rematar** al Pokémon rival, ataca con lo más barato que lo consiga.
3. Si su activo es **débil** a un ataque del rival, o no llega a ningún ataque, **cambia** a un relevo que no sea débil y sí pueda atacar (si le llega la energía de la retirada).
4. Si con la carga extra podría **rematar** al turno siguiente un ataque que hoy no le llega, **carga**.
5. Ataca: con el de **más daño** si la reserva está llena (la energía sobrante se perdería) y, si no, con el de **más daño por energía gastada**.
6. Si no llega a nada, **carga**.

## 4. Mapa

La campaña inicial es **Kanto** (decidido el 2026-11-21). La región se recorre por **zonas** (rutas, cuevas, ciudades), como en los juegos, y cada zona define qué Pokémon salvajes aparecen y qué entrenadores hay. El **Túnel Roca** es una de esas zonas. El recorrido es un grafo de **nodos**:

| Nodo | Qué pasa |
|---|---|
| **Inicio** | Elegir un Pokémon inicial entre tres (cuáles, por decidir). |
| **Ruta** | Combate contra un Pokémon salvaje. Al derrotarlo se pregunta si se añade al equipo (si hay hueco; si no, hay que soltar uno). |
| **Descanso** | Cura el equipo, permite gestionar el equipo, **evolucionar 1 Pokémon** y comprar (qué se vende, por decidir). |
| **Gimnasio** | Combate contra un entrenador. Da una **medalla** y puntos. |
| **Jefe** | Con la medalla, se puede retar a un **Pokémon jefe con sus aliados**. Da muchos puntos. |
| **Liga** | Tras reunir todas las medallas. **Fase 2.** |

Estructura de una región: `Inicio → rutas → descanso → gimnasio (medalla) → jefe → vuelta a las rutas → medalla → jefe → …→ Liga`. Hay ramas: en una bifurcación se elige por qué ruta seguir.

### Jefe con aliados

El jefe se enfrenta como un **equipo rival**: sus aliados salen primero y el jefe al final, en combates 1 contra 1 seguidos. Usa los nombres y el mapa del catálogo de incursiones, pero con **estadísticas de campaña propias** (los 2300 PS de Onix no tienen sentido en un combate 1 contra 1). El número de aliados depende del nivel del jefe, igual que en las incursiones (Lv1: 1, Lv2: 2…).

## 5. Puntos y tienda

- La campaña da puntos por **victoria en combate**, por **medalla** y por **jefe**, más una cantidad menor por ruta superada (las cifras son provisionales y se ajustan al final; solo importan si hay compras dentro de la campaña).
- Los puntos van a la **cuenta** (hace falta sesión) y se gastan en la **tienda** de la pantalla de inicio: monedas, dados, sobres y cartas sueltas del formato digital.
- Compras dentro de la campaña (el descanso), la **XP de evolución** y la evolución por intercambio o a ex se pagan con los mismos puntos, y lo que sobra al terminar se conserva. Gastar puntos en evolucionar es renunciar a gastarlos en la tienda.

## 6. Cómo encaja en el proyecto

| Pieza | Propuesta |
|---|---|
| Motor | Librería nueva `engine/lib/campana.dart` (código en `engine/lib/src/campana/`), con el mismo patrón que la partida: estado inmutable y reductor puro, `aplicarCombate(estado, acción)`. No toca el motor de las incursiones. **Hecho el combate 1 contra 1 (#336)**: energía, atacar, cambiar, cargar, elegir siguiente, debilidad y resistencia; **IA rival (#338)**. |
| Catálogo | `catalog/campana/`: `pokemon/*.json` (uno por Pokémon, con su número de la Pokédex), `zonas/*.json` (qué aparece en cada zona) y sus esquemas en `catalog/schema/`. El JSON manda, como con los jefes. |
| Simulador | `sim/` simula combates y rutas de campaña para equilibrar PS, costes de energía y la IA rival. |
| Guardado | Progreso de campaña (región, nodo, equipo, medallas, puntos pendientes) **en el dispositivo**, sincronizado con la cuenta al iniciar sesión. Es un esquema **aparte** del contrato de partida. |
| Servidor | Recibe los puntos ganados al terminar un jefe o una medalla. Al ser un solo jugador y coste 0, se acepta lo que reporta el cliente con un tope por hito (no hay competición). |
| App | Pantallas nuevas: mapa de región, combate, equipo, descanso y tienda. Reutiliza los fondos de mesa por mapa y los avisos. |

`flujo-app.md` se corrige en este mismo cambio: la campaña **ya no** entrega las cartas de la partida libre digital, y «Mis cartas» deja de depender de ella.

## 7. Primera entrega

**El primer set tendrá los 151 Pokémon de Kanto, pero se rellena por zonas:** de cada zona solo entran los Pokémon que aparecen en ella. La primera zona es el **Túnel Roca**, con datos de Serebii y Bulbapedia (Rojo, Azul y Amarillo):

- **Salvajes:** Zubat, Geodude, Machop y Onix. El Onix salvaje se puede capturar y es distinto del Onix jefe.
- **Entrenadores (PokéManiacos):** Cubone y Slowpoke.
- El jefe de la zona es **Onix**, con sus aliados.

Contenido de la primera entrega, además:

- Los 15 tipos de la 1.ª generación en el motor.
- Esquema JSON de Pokémon y de zona, y su carga en el motor (#340).
- Combate completo con energía, cambio de Pokémon, IA rival y victoria o derrota (hecho).
- Guardado local del progreso.

Fuera de la primera entrega: el resto de las zonas y los 151 completos, Liga, evolución, tienda, sincronización con la cuenta y los combates 2 contra 2 y 3 contra 3.

## 8. Preguntas abiertas

1. **Derrota.** ¿Qué pasa al perder un combate? Propuesta: volver al último descanso con el equipo curado y sin perder lo ganado, para que no frustre. Alternativa más dura: perder una parte del dinero.
2. **Máximo de Pokémon en el equipo** y qué pasa con los que se sueltan.
3. **Qué se vende en el descanso** (curas, objetos, Pokémon).
4. **Cuántos ataques** puede tener un Pokémon y rango de costes (propuesta: 1 a 3 ataques, coste de 1 a 5).
5. **Cifras de progresión:** cuántos puntos cuesta cada XP, cuántas XP necesita cada Pokémon para evolucionar, y cuánto cuestan el intercambio y hacerse ex.
6. **Qué dan y qué cuestan las cartas ex** (más PS y ataques más fuertes, con otro coste de energía) y cuántas fases tiene cada cadena (por ejemplo, Machop → Machoke → Machamp ex).
7. **Contenido:** cada Pokémon necesita sus datos y su imagen, y ese es el cuello de botella (la creación de cartas es manual).

## 9. Tareas derivadas (para crear tras aprobar)

1. Catálogo de campaña: esquema y los primeros Pokémon de Túnel Roca.
2. Motor de combate 1 contra 1: energía, acciones, debilidades y resistencias.
3. IA rival determinista.
4. Simulador de combates de campaña y primer equilibrado.
5. Modelo de región y de nodos, y avance por el mapa.
6. Captura, equipo y descanso.
7. Jefe con aliados y medalla.
8. Guardado de progreso de campaña en el dispositivo.
9. Pantallas de la app: mapa, combate, equipo, descanso.
10. Puntos al servidor y tienda (después de la porción vertical).
