# D-01 · Setup sin circularidad

Estado: **decidido** (2026-11-05). Issue #12.

## 1. Problema

El GDD v0.6 decía que cada jugador usa 2 Pokémon en los niveles 1-3 y 3 en el Nv4. Pero el nivel sale de X, y X se calcula con los Pokémon de los jugadores: círculo.

## 2. Decisión

**Cada jugador usa 2 Pokémon (1 Activo + 1 Banca) en todos los niveles, incluido el Nv4.** Es lo que hace el juego oficial. Sin Pokémon extra en el Nv4 no hay circularidad: el número de Pokémon no depende del nivel.

La dificultad del Nv4 sale del jefe (más HP y más ataques por turno), no de dar más Pokémon a los jugadores. Los valores de D-03 ya están calibrados con 2 Pokémon por jugador (4 parejas).

## 3. Orden del setup

1. Cada jugador elige **2 Pokémon** de cualquier carta del formato (sin restricciones de tipo de carta).
2. Se calcula **X** = suma, de todos los jugadores, del ataque base más fuerte de cada jugador (reglas de D-02 para qué cuenta y quién lo introduce).
3. El asistente muestra el **nivel** según X y lo fija:

| X | Nivel |
|---|---|
| menor de 400 (incluido menor de 250) | Nv1 |
| 400 a 599 | Nv2 |
| 600 a 799 | Nv3 |
| 800 o más | Nv4 |

4. Se elige el **jefe** del catálogo de ese nivel, a mano o al azar.
5. Empieza la partida.

## 4. Casos límite

- **Valores justo en el umbral**: el umbral inferior pertenece al nivel de arriba (X = 400 es Nv2, X = 600 es Nv3, X = 800 es Nv4).
- **X menor de 250**: se juega como Nv1. El juego oficial pone un jefe más duro, pero aquí no existe nivel inferior al Nv1. En el simulador, equipos con X entre 190 y 390 dan ≈ 75 % de victoria en Nv1.
- **Cambiar Pokémon después de ver el nivel**: no se permite. Una vez mostrado el nivel, los Pokémon quedan fijados, para que nadie ajuste su X a un nivel concreto. Qué cuenta como daño y cómo se evita la manipulación se cierra en D-02.
- **Menos de 4 jugadores**: el formato está pensado para 3-4 jugadores (GDD v0.6). Si juegan menos, se mantiene el criterio del GDD y no se añaden parejas extra; la regla de aliados con menos jugadores va en D-04.
- **Jugador eliminado**: no cambia X ni el nivel durante la partida; X se calcula una sola vez, en el setup.

## 5. Cambios en otros documentos

- `incursiones_gdd.md` pasa a v0.8: fila "Nº de Pokémon por jugador" fija en 2, regla de X < 250 y HP de referencia recalibrado (2382 / 4313 / 4411 / 5205).
- `docs/D-03-sistema-de-poder.md`: ya asumía 4 parejas de 2 Pokémon; el Nv4 propuesto con 3 Pokémon queda descartado.
