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

`bin/sim_jefes.dart` simula **cada jefe de `catalog/bosses/`** con su HP, sus ataques y su invocación de aliados (umbral, tirada, slot y categoría, ataque de entrada y de final de turno, Bloqueo de Bronzong y exceso de daño perdido). Mide tres políticas de los jugadores: `solo-jefe` (todos ignoran a los aliados y dañan al jefe, salvo que Bronzong obligue; el aliado sigue atacando a su dueño), `solo-dueno` (el dueño del slot ataca siempre a su aliado, la más dura) y `ayuda` (un jugador libre ataca al aliado de un compañero con probabilidad `--ayuda`, 0,5 por defecto, un supuesto sin datos de playtest). Escribe `balance/informes/jefes_aliados.csv`.

```
dart run bin/sim_jefes.dart
dart run bin/sim_jefes.dart --equipos=20 --partidas=20 --informe=/tmp/prueba.csv   # prueba rápida
dart run bin/sim_jefes.dart --calibrar   # busca el HP que da el objetivo (75/50/30/15 %)
```

Opciones para probar partidas con menos jugadores (T-67): `--jugadores=N` (equipos de 1 a 4 jugadores; el mazo de ataques del jefe se adapta), `--mesa8` (se mantienen 8 Pokémon en mesa: 3 jugadores 3+3+2, 2 jugadores 4+4), `--mejor-primero` (cada jugador saca de Activo su mejor Pokémon) y `--menos-ataques=K` (quita K ataques por turno al jefe). El jefe roba sus ataques del mazo real de 20 cartas (`MazoAtaquesJefe` del motor).

Con `--causas` añade una tabla que desglosa los intentos de invocación de cada jefe (media por partida): invocados, perdidos por falta de slot o de categoría, y umbrales que no llegaron a cruzarse porque la partida terminó antes.

Con `--calibrar` busca, por jefe, el mayor HP (en centenas) con el que la política `solo-dueno` llega al objetivo del nivel, manteniendo el mismo número de aliados (el `cadaHp` se reparte en tramos iguales), y escribe `balance/informes/jefes_aliados_calibrado.csv`.

**Modela los efectos de los ataques del jefe (D-14)** que lee del catálogo: daño variable (Danza Espada, Castigo), autodaño, contadores a todos, y que el Defensor no ataque o no se retire el siguiente turno (siempre 1 turno; `ignoraEfectos` no cuenta). **Modela los scripts de aliados que aplica el programa (D-13):** Tanque (`tanque-jefe-N`: los ataques de los jugadores hacen N de daño menos mientras viva) y Cura (`cura-jefe-N`: el jefe se cura N HP al final de su turno). También modela (D-16) Chupavidas (cura al jefe y a los aliados cada vez que ataca), Foco Energía (+N al ataque del jefe con moneda), los ataques de monedas («20×»), el Tanque sobre los aliados y, como si la mesa los aplicara siempre, «Tormenta de arena» (10 al activo de cada jugador en el chequeo) y «Rencor» (sin repetir ataque). Y los de Manectric: Drenadoras (contador de 10 en cada activo y el jefe se cura 10 por cada uno, al entrar y en el chequeo), Aullido (+20 a cada ataque del jefe), Gruñido (−10 a los ataques de los jugadores) y el daño de Chispazo a los adyacentes. **No modela** el veneno (tampoco el de Tóxico) ni la parálisis de Moflete Estático,  y la quemadura del jefe. Las cifras siguen siendo una cota optimista para los jugadores; la política `solo-dueno` es la más prudente. El CI compila el simulador y lanza una partida mínima, pero **no comprueba que los resultados sean razonables**: eso se mira al leer el informe.


> **T-69:** la invocación del simulador de jefes ya no es por umbrales de HP: el jefe llama a un aliado al empezar su turno desde la ronda 2 si no hay ninguno en juego, hasta nivel + 1 veces, sin moneda. `cadaHp` y `tirada` del catálogo se ignoran (salvo que `invocacion` exista).
