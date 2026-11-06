# D-06 · Curación del jefe y final de partida

Estado: decidido (2026-11-06). Issue #37.

## 1. Problema

El jefe puede curarse sin límite de veces (con tope en su HP máximo). ¿Puede una partida no acabar nunca?

## 2. Decisión

**No se añade ningún tope** (ni de rondas ni de curación total). Toda partida tiene un final:

- **Victoria**: el HP del jefe llega a 0.
- **Derrota**: todos los Pokémon de todos los jugadores han caído. El jefe ataca en cada turno y los jugadores solo se curan con las cartas de ánimo (D-05), que son pocas, así que si el jefe se cura más de lo que le dañan, la mesa acaba perdiendo.
- **Abandono**: la mesa puede dejar la partida en cualquier momento y cuenta como **derrota**.

No existe el empate.

Esta conclusión es un razonamiento, no una medición: el simulador (`sim/`) todavía no modela curación del jefe ni aliados curanderos. Si en los playtests (T-17) aparecen partidas que se alargan, el siguiente paso sería un tope de rondas con derrota automática.

## 3. Cómo se registra

- La curación del jefe es un evento del log con la cantidad **efectiva**: lo que sube de verdad, sin pasar del HP máximo (curar a vida completa registra 0). El estado acumula la curación total.
- El abandono es el evento `Abandonar`: termina la partida en derrota conservando el daño hecho.

## 4. Daño para los puntos (D-10)

Con la curación, el daño bruto hecho al jefe puede superar su vida máxima. Para los puntos de una derrota se usa el **daño neto**: la vida perdida por el jefe (HP máximo − HP actual).

`puntos de derrota = round(vida perdida × Y ÷ 4) + 1`

Así un jefe que se cura no regala puntos y el total de una derrota nunca supera el de una victoria. El **reparto entre jugadores** sigue usando el daño que hizo cada uno (bruto), para ordenar los puestos.

## 5. Cambios en otros documentos

- `incursiones_gdd.md` → v1.2: §4.5, §5, §7 y historial.
- `docs/D-10-sistema-de-puntos.md`: la derrota usa el daño neto (§2 punto 4).
- Un aliado curandero (D-04 §7.5) cura al jefe con esta misma regla.
