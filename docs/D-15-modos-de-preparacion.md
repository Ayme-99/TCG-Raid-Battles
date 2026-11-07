# D-15 · Modos de preparación de la partida

Estado: **diseño** (2026-11-07). Issue #106 (T-32).

## Idea

La preparación de la partida decide qué nivel de jefe toca. Hay tres modos; solo cambia **de dónde sale el nivel**. El resto de la partida es igual.

| Modo | Cómo se decide el nivel | Estado |
|---|---|---|
| **1. Por equipo** | Cada jugador indica el daño de su Pokémon; el equipo da un nivel y se elige un jefe entre los de ese nivel. | Ya está |
| **2. Por jefe** | Se elige el jefe. Su nivel es el de la partida y su tarjeta muestra el daño máximo recomendado. | A construir |
| **3. Por sobres** | Cada jugador abre un sobre, elige dos cartas y de ahí sale el daño y el nivel. | Idea futura |

## Modo 1: por equipo (el actual)

Los jugadores introducen el daño máximo de sus cartas. El nivel sale de `niveles.csv` (Nv1 250–390, Nv2 400–590, Nv3 600–799, Nv4 800+). Dentro del nivel se elige el jefe que se quiera del catálogo, incluidos los que se añadan más adelante.

## Modo 2: por jefe

- El jugador elige el jefe en el setup. El nivel de la partida es el del jefe.
- La tarjeta del jefe muestra el **daño máximo recomendado**: el rango `x_min`–`x_max` de su nivel (por ejemplo, 400–590 en Nv2).
- Se pide el daño de los jugadores igual que en el modo 1. Si el equipo queda **fuera del rango**, la app lo avisa («probablemente demasiado difícil» o «probablemente demasiado fácil»), pero se puede jugar igualmente.
- **Decisión: solo aviso.** No se bloquea la partida ni se cambia la recompensa según el desajuste. Se descartó escalar la recompensa (más puntos por debajo del rango, menos por encima) porque añadiría datos que introducir y complicaría la preparación. Los puntos siguen dependiendo solo del nivel del jefe.

## Modo 3: por sobres (futuro)

Cada jugador compra un sobre Pokémon, lo abre, elige dos cartas y de ahí sale un jefe de cierto nivel. Se deja para cuando el estilo de juego esté consolidado y **no se diseña todavía**. Como solo cambia la fuente del daño, debería reutilizar el modo 1 sin cambios en el motor.

## Cambios técnicos (modo 2)

1. **Motor:** `ElegirJefe` hoy exige que el nivel del jefe coincida con el calculado por el daño de los jugadores. En el modo `jefe`, el nivel de la partida es el del jefe y esa comprobación no se aplica.
2. **Contrato v6:** campo `modoPreparacion` (`equipo`, `jefe`; más adelante `sobres`), para el historial y para analizar el balance por modo. Migración v5 → v6: las partidas antiguas pasan a `equipo`. Servidor y deck-tracker-server, con el checklist de `docs/DEPENDENCIAS.md`.
3. **App:** selector de modo en el setup, rango recomendado en la tarjeta del jefe y aviso de desajuste.
4. **Simulador:** medir también equipos fuera del rango, porque el balance está calibrado para equipos en el centro de cada nivel (`x_centro`). Es lo que más afecta al porcentaje de victoria en el modo 2.

## Pendiente

- Decidir si el aviso de desajuste distingue «un poco» de «mucho» fuera del rango.
- Orden de trabajo: primero el simulador de efectos (D-14) y la recalibración de HP, y después este modo.
