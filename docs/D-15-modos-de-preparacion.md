# D-15 · Modos de preparación de la partida

Estado: **modo 2 hecho** (2026-11-15, contrato v12). Issue #106 (T-32).

## Idea

La preparación de la partida decide qué nivel de jefe toca. Hay tres modos; solo cambia **de dónde sale el nivel**. El resto de la partida es igual.

| Modo | Cómo se decide el nivel | Estado |
|---|---|---|
| **1. Por equipo** | Cada jugador indica el daño de su Pokémon; el equipo da un nivel y se elige un jefe entre los de ese nivel. | Ya está |
| **2. Por jefe** | Se elige el jefe. Su nivel es el de la partida y su tarjeta muestra el daño máximo recomendado. | Ya está |
| **3. Por sobres** | Cada jugador abre un sobre, elige dos cartas y de ahí sale el daño y el nivel. | Idea futura |

## Modo 1: por equipo (el actual)

Los jugadores introducen el daño máximo de sus cartas. El nivel sale de `niveles.csv` (Nv1 250–390, Nv2 400–590, Nv3 600–799, Nv4 800+). Dentro del nivel se elige el jefe que se quiera del catálogo, incluidos los que se añadan más adelante.

## Modo 2: por jefe

- El jugador elige el jefe en el setup. El nivel de la partida es el del jefe.
- La tarjeta del jefe muestra el **daño máximo recomendado**: el rango `x_min`–`x_max` de su nivel (por ejemplo, 401–600 en Nv2).
- Después del jefe se piden los jugadores, con el jefe a la vista (su sprite y «Cambiar»). **El daño de cada jugador es opcional** (2026-11-20, T-102): si se escribe el de todos, la app avisa si el equipo queda **fuera del rango** («muy difícil» o «más fácil de lo previsto») o confirma que encaja; sin daños no hay aviso y se puede jugar igualmente.
- **Decisión: solo aviso.** No se bloquea la partida ni se cambia la recompensa según el desajuste. Se descartó escalar la recompensa (más puntos por debajo del rango, menos por encima) porque añadiría datos que introducir y complicaría la preparación. Los puntos siguen dependiendo solo del nivel del jefe.

## Modo 3: por sobres (futuro)

Cada jugador compra un sobre Pokémon, lo abre, elige dos cartas y de ahí sale un jefe de cierto nivel. Se deja para cuando el estilo de juego esté consolidado y **no se diseña todavía**. Como solo cambia la fuente del daño, debería reutilizar el modo 1 sin cambios en el motor.

## Cambios técnicos (modo 2)

1. **Motor:** `ElegirJefe` hoy exige que el nivel del jefe coincida con el calculado por el daño de los jugadores. En el modo `jefe`, el nivel de la partida es el del jefe y esa comprobación no se aplica.
2. **Contrato v12:** campo `modoPreparacion` (`equipo`, `jefe`; más adelante `sobres`) en el evento `configurarJugadores`, para el historial y para analizar el balance por modo. Migración v11 → v12: las partidas antiguas pasan a `equipo`. Servidor y deck-tracker-server, con el checklist de `docs/DEPENDENCIAS.md`.
3. **App:** selector de modo en el setup, rango recomendado en la tarjeta del jefe y aviso de desajuste.
4. **Simulador:** medir también equipos fuera del rango, porque el balance está calibrado para equipos en el centro de cada nivel (`x_centro`). Es lo que más afecta al porcentaje de victoria en el modo 2.

## Cómo queda en el motor

- `ConfigurarJugadores(jugadores, modo:)`: el modo se decide en el setup y queda en `EstadoPartida.modo`. El orden de eventos no cambia: en la app, «Elegir jefe primero» solo cambia el orden de las pantallas; el motor sigue recibiendo `ConfigurarJugadores` y después `ElegirJefe`.
- `ElegirJefe` solo exige que el nivel coincida con el del equipo en el modo `equipo`. En el modo `jefe` el nivel de la partida pasa a ser el del jefe (`EstadoPartida.nivel`).
- `rangoXDelNivel(nivel)` y `desajusteDeEquipo(x, nivel)` (`reglas.dart`) dan el rango recomendado y si el equipo queda por debajo (-1), dentro (0) o por encima (1).

## Simulador: equipos fuera del rango (2026-11-15, #246)

`dart run bin/sim_jefes.dart --desajuste` mide cada jefe contra equipos de todos los niveles de X (40 equipos por nivel, 30 partidas por equipo; informe completo en `balance/informes/desajuste_2026-11-15.txt`). Victoria con la política «solo-dueno» (la más dura):

| Jefe (nivel) | Equipo 3 niveles por debajo | 2 por debajo | 1 por debajo | En su nivel | 1 por encima | 2 por encima | 3 por encima |
|---|---|---|---|---|---|---|---|
| Onix (1) | | | | 61 % | 100 % | 100 % | 100 % |
| Manectric (2) | | | 0 % | 63 % | 88 % | 98 % | |
| Kingdra (3) | | 0 % | 7 % | 34 % | 69 % | | |
| Arceus (4) | 0 % | 0 % | 3 % | 20 % | | | |

Lo que enseña:

- **Por debajo del rango, un solo nivel ya es casi imposible** (0–7 %). No hay un «un poco por debajo» útil: o el equipo está dentro, o no hay partida.
- **Por encima, un nivel ya hace el jefe fácil** (69–100 %) y dos lo hacen trivial (98–100 %).
- Con la ayuda entre jugadores los números son casi iguales (±5 puntos).

Por tanto la distancia que importa es en **niveles de X**, no en puntos sueltos de daño. **Decidido (2026-11-15):** por debajo, «muy difícil» desde el primer nivel; por encima, «más fácil de lo previsto» a 1 nivel y «demasiado fácil» a 2 o más.

## Pendiente

Nada del modo 2. El modo 3 (por sobres) no se diseña hasta que exista el formato digital.
