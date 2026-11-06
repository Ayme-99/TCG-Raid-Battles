# D-12 · Estados alterados del jefe: veneno y quemadura

Estado: **cerrada** (2026-11-06). Issue #47. Valores provisionales hasta T-17. La implementación en el motor es una tarea aparte.

## Decisiones

1. **Solo el jefe.** El asistente lleva los estados del jefe. Los de los Pokémon de los jugadores se siguen resolviendo en la mesa (GDD §4.3).
2. **Veneno**: permanente. Una vez puesto, el jefe lo conserva toda la partida. Hace **10 de daño** en cada chequeo.
3. **Quemadura**: hace **20 de daño** en cada chequeo. Después de aplicar el daño se tira una moneda **automáticamente**: cara, se quita la quemadura; cruz, se mantiene.
4. **Chequeo**: una vez por ronda, **al cerrar el turno del jefe**, después de los ataques de los aliados. Orden: veneno, quemadura, moneda.
5. Los estados no se quitan al curar al jefe.
6. **El daño de los estados no se atribuye a ningún jugador.** Baja el HP del jefe y cuenta para el daño total del equipo (puntos de derrota, D-06), pero no cuenta para el daño individual ni para el puesto. Esto sustituye a la decisión 3 de D-08 para los estados.
7. Si el chequeo deja al jefe a 0 HP, la partida termina en **victoria** en ese mismo momento.
8. **Bono de estados** por jugador, en lugar del daño que no se cuenta (ver más abajo).

## Qué cuenta como aplicar un estado

Una aplicación cuenta solo si el estado **no estaba ya en el jefe**. El veneno cuenta como mucho una vez por partida. La quemadura cuenta cada vez que se vuelve a poner después de que la moneda la haya quitado. Aplicar un estado que el jefe ya tiene no cuenta.

## Bono de estados

Para un jugador con `n` aplicaciones contables:

```
b      = tope de victoria del nivel ÷ 100
bono   = b × min(n, 3)                      en victoria
bono   = round(b × min(n, 3) ÷ 4)           en derrota (también al abandonar)
```

- El bono es **individual**, se **suma a la parte del reparto** del jugador y queda **fuera del total del equipo**: no cambia `puntosTotal` ni los porcentajes de los demás.
- No cambia los puestos, que se siguen decidiendo por el daño.
- Los invitados no cobran bono, igual que no cobran su parte.
- Redondeo de la derrota: `(b × min(n, 3) + 2) ÷ 4` con división entera, es decir, mitades hacia arriba.

| Nivel | b | 1 aplicación | 2 aplicaciones | 3 o más | En derrota (1 / 2 / 3) |
|---|---|---|---|---|---|
| Nv1 | 30 | 30 | 60 | 90 | 8 / 15 / 23 |
| Nv2 | 60 | 60 | 120 | 180 | 15 / 30 / 45 |
| Nv3 | 90 | 90 | 180 | 270 | 23 / 45 / 68 |
| Nv4 | 150 | 150 | 300 | 450 | 38 / 75 / 113 |

El máximo es el 3 % del tope del nivel. Ejemplo: victoria de Nv1 con 4 jugadores, el reparto medio es 750 puntos por jugador; el bono máximo (90) es un +12 % sobre eso. Un jugador que aplica veneno y dos quemaduras tiene `n = 3` y cobra 90.

## Cambios que implican en el motor (tarea aparte)

- Estado del jefe con `envenenado` y `quemado`.
- Evento nuevo `AplicarEstadoJefe(jugador, estado)`, válido en el turno de jugadores. Guarda cuántas aplicaciones contables lleva cada jugador.
- `FinTurnoJefe` pasa a llevar `monedaQuemadura` (cara/cruz) cuando el jefe está quemado. La app tira la moneda y la registra, porque el motor es determinista: reproducir el registro da siempre el mismo resultado. Sin ese dato, el evento se rechaza.
- `calcularPuntos` suma el bono a cada jugador; el resumen guarda `estadosAplicados` y `bonoEstados` por jugador.
- Contrato JSON: cualquier cambio sube la versión, así que pasa a la **versión 2** (migración 1 → 2 sin cambios, porque todo lo nuevo es opcional).
- Un chequeo que deja al jefe a 0 HP termina la partida antes de pasar a la ronda siguiente.
