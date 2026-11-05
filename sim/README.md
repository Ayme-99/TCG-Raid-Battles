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
