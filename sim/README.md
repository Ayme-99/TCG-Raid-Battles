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
