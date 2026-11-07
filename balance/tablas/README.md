# balance/tablas/

Tablas que usa la fórmula de poder (ver `docs/D-03-sistema-de-poder.md`).

## niveles.csv

| Columna | Qué significa |
|---|---|
| nivel | Nivel del jefe (1-4) |
| x_min, x_max | Rango de X que activa este nivel. X = suma del mejor ataque de cada jugador (definición oficial, pendiente de confirmar en la decisión A) |
| x_centro | X de referencia para calcular el poder objetivo |
| hp | HP de referencia del jefe de ese nivel |
| ataque1, ataque2, ataque3 | Daño de cada ranura de ataque |
| max_ataques_turno | Parámetro del simulador (supuesto): en el juego real el máximo lo define la baraja de ataques del jefe, no el GDD |
| amenaza_esperada | Ataques esperados por turno × daño medio por ataque |
| poder | HP × amenaza_esperada. Objetivo para jefes nuevos: ≈ 1,5 × x_centro² |
| estado | `oficial` si viene del juego oficial; `propuesta sin validar` si lo hemos inventado |

Edítalo en VS Code (extensión Rainbow CSV) o en Excel/LibreOffice guardando siempre como CSV.
