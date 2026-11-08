# sim/

Simulador Monte Carlo por consola. Juega miles de partidas automáticas con el motor de `engine/`
y calcula la tasa de victoria por jefe y número de jugadores (1 a 4).

Lee los jefes de `catalog/bosses/` y las tablas de `balance/tablas/`, y escribe los informes en
`balance/informes/`. Ningún jefe se publica sin un informe aquí (tarjetas D-03 y T-14).

```
cd sim
dart pub get
dart run bin/sim.dart
```

## Simulador con cartas reales (D-03)

`bin/sim_cartas.dart` usa cartas reales (`balance/tablas/cartas_prueba.csv` y `ataques_prueba.csv`) y las
reglas de la hoja oficial de Raid Battle. Es el que debe usarse para calibrar los jefes de
`balance/tablas/niveles.csv`. `bin/sim.dart` es el modelo abstracto anterior y ya no está calibrado.

```
dart run bin/sim_cartas.dart              # mide con los HP de niveles.csv
dart run bin/sim_cartas.dart --calibrar   # busca el HP que da 75/50/30/15 %
```

## Jefes del catálogo con aliados (T-28, primera parte)

`bin/sim_jefes.dart` simula **cada jefe de `catalog/bosses/`** con su HP, sus ataques y su invocación de aliados (umbral, tirada, slot y categoría, ataque de entrada y de final de turno, bloqueo y exceso de daño perdido). Mide dos políticas de los jugadores: `solo-dueno` (solo el dueño del slot ataca a su aliado, la más dura) y `ayuda` (un jugador libre ataca al aliado de un compañero con probabilidad `--ayuda`, 0,5 por defecto, un supuesto sin datos de playtest). Escribe `balance/informes/jefes_aliados.csv`.

```
dart run bin/sim_jefes.dart
dart run bin/sim_jefes.dart --equipos=20 --partidas=20 --informe=/tmp/prueba.csv   # prueba rápida
dart run bin/sim_jefes.dart --calibrar   # busca el HP que da el objetivo (75/50/30/15 %)
```

Con `--calibrar` busca, por jefe, el mayor HP (en centenas) con el que la política `solo-dueno` llega al objetivo del nivel, manteniendo el mismo número de aliados (el `cadaHp` se reparte en tramos iguales), y escribe `balance/informes/jefes_aliados_calibrado.csv`.

**Modela los efectos de los ataques del jefe (D-14)** que lee del catálogo: daño variable (Danza Espada, Castigo), autodaño, contadores a todos, y que el Defensor no ataque o no se retire el siguiente turno (siempre 1 turno; `ignoraEfectos` no cuenta). **Modela los scripts de aliados que aplica el programa (D-13):** Tanque (`tanque-jefe-N`: los ataques de los jugadores hacen N de daño menos mientras viva) y Cura (`cura-jefe-N`: el jefe se cura N HP al final de su turno). **No modela** el Pícaro (lo aplican los jugadores), ni el veneno y la quemadura del jefe. Las cifras siguen siendo una cota optimista para los jugadores; la política `solo-dueno` es la más prudente. El CI compila el simulador y lanza una partida mínima, pero **no comprueba que los resultados sean razonables**: eso se mira al leer el informe.

