# Cuánto vale empezar primero en el combate de campaña

Fecha: 2026-11-26 · Issues: #451 y #386 (lo planteó Ayme el 2026-11-26) · Herramientas: `sim/bin/sim_campana.dart --modo=empezar` (duelos 1 contra 1) y `sim/bin/sim_campana_partida.dart --modo=pociones --empieza=…` (motor real de partida) · Datos: `campana_empieza_2026-11-26/` (salidas completas y CSV)

Solo `sim/` e informes: no se ha tocado el motor, el catálogo ni las reglas. Objetivo de Ayme: **75 % de victoria por combate**.

## Resumen

1. **Empezar primero vale unos 26 puntos de victoria** en los duelos 1 contra 1 (63,1 % si empieza el jugador, 36,9 % si empieza el rival). Es mucho: en los duelos parejos la diferencia es de unos 60 puntos.
2. **Pikachu jefe se hunde con empieza=rival**: con evolución, Bulbasaur 93,7 → 58,9 %, Squirtle 71,0 → 42,8 % (Charmander aguanta: 100 → 95,1 %). Sin evolución, 87,8 → 45,5 % y 65,2 → 38,1 %. Queda lejos del 75 %.
3. **Brock apenas baja con evolución** (98,9 → 98,6 %; Charmander 96,5 → 80,5 %, y 97,9 % con 1 Poción; Squirtle 100 %). Sin evolución y sin Pociones queda cerca del 75 % (77,2 / 73,5 / 89,3 %).
4. **Recomendación**: que el rival empiece **en los gimnasios, no en los jefes** como Pikachu (con los números actuales es demasiado fuerte), y **nunca en los combates normales** (la ruta se rompe: solo llega a Brock el 21 % con Bulbasaur y el 7 % con Squirtle). Solo hay datos de Pikachu jefe y de Brock; de los demás jefes y gimnasios no hay nada medido.

## 1. Duelos 1 contra 1 de la tabla

25 Pokémon del catálogo, cada uno contra cada uno (625 parejas), 20 semillas por pareja y por quién empieza (los combates dependen de la semilla). Victoria del jugador según la categoría del **rival** (Común, Intermedio, Fuerte; Jefe es el que no tiene categoría de captura).

| Rival | Empieza el jugador | Empieza el rival | Diferencia | Combates |
|---|---:|---:|---:|---:|
| Común | 75,1 % | 46,3 % | 28,9 pt | 7.000 |
| Intermedio | 57,9 % | 31,4 % | 26,5 pt | 2.000 |
| Fuerte | 23,4 % | 5,2 % | 18,2 pt | 500 |
| Jefe | 45,3 % | 23,8 % | 21,5 pt | 3.000 |
| **Todos** | **63,1 %** | **36,9 %** | **26,3 pt** | 12.500 |
| Igualados (todos) | 80,2 % | 19,8 % | 60,4 pt | 5.420 |
| Igualados (rival Jefe) | 68,9 % | 10,5 % | 58,5 pt | 1.100 |

- «Igualados» son las parejas que no están decididas (las que no dan ≥ 95 % ni ≤ 5 % en las dos formas de empezar). Ahí es donde se nota: quien empieza gana cuatro de cada cinco duelos. Es una selección que mira el resultado, así que sirve para ver el orden de magnitud, no como cifra del juego.
- La diferencia es parecida en todas las categorías (18 a 29 puntos). Es menor en Fuerte porque casi todo lo gana el rival de todos modos.
- Los equipos de 1 Pokémon no son los combates reales (hay equipos de 2 o más, cambios, Pociones y llamada de aliado), pero el orden de magnitud se confirma en el punto 2.

## 2. Brock y Pikachu jefe con empieza=rival

Motor real de partida (`--modo=pociones`, 1.500 recorridos por inicial, Ruta 1 sí, volver a curar sí, 5 Balls, 0 a 3 Pociones, IA real con Poción). Se cuenta el **primer intento** de cada casilla, de los recorridos que llegan a ella. Tres formas de empezar:

- `jugador`: como ahora (referencia, repite las cifras de #476).
- `rival-jefes`: el rival empieza solo en Pikachu jefe y en los gimnasios (Entrenador Joven y Brock). Es la propuesta que hay que valorar.
- `rival`: el rival empieza todos los combates (solo para ver el techo).

Margen de error: unos ±2,5 puntos en las cifras de 1.500 recorridos, más en las que parten de menos recorridos.

### Con evolución del inicial (a 70 XP)

| Primer intento | Bulbasaur | Charmander | Squirtle |
|---|---:|---:|---:|
| **Pikachu jefe**: empieza jugador | 93,7 % | 100,0 % | 71,0 % |
| Pikachu jefe: **rival-jefes** | **58,9 %** | **95,1 %** | **42,8 %** |
| Pikachu jefe: rival (todos) | 30,5 % | 90,6 % | 48,6 % |
| Entrenador Joven: jugador → rival-jefes | 99,5 → 91,7 % | 99,6 → 91,5 % | 92,5 → 74,9 % |
| **Brock, 0 Pociones**: jugador → rival-jefes | 98,9 → 98,6 % | 96,5 → 80,5 % | 100 → 100 % |
| Brock, 1 Poción: jugador → rival-jefes | 98,9 → 98,6 % | 96,9 → 97,9 % | 100 → 100 % |
| Brock, 2 Pociones: jugador → rival-jefes | 98,9 → 98,6 % | 96,9 → 97,9 % | 100 → 100 % |
| Llegan a Brock: jugador → rival-jefes → rival | 99,7 → 95,3 → 20,7 % | 100 → 100 → 100 % | 91,1 → 90,8 → 7,1 % |
| Tramo entero sin perder: jugador → rival-jefes | 69,9 → 37,2 % | 96,1 → 71,0 % (84,9 con Pociones) | 53,4 → 24,1 % |

### Sin evolución del inicial

| Primer intento | Bulbasaur | Charmander | Squirtle |
|---|---:|---:|---:|
| **Pikachu jefe**: empieza jugador | 87,8 % | 96,0 % | 65,2 % |
| Pikachu jefe: **rival-jefes** | **45,5 %** | **89,7 %** | **38,1 %** |
| Entrenador Joven: jugador → rival-jefes | 87,9 → 59,6 % | 76,4 → 59,6 % | 83,0 → 65,8 % |
| **Brock, 0 Pociones**: jugador → rival-jefes | 76,6 → 77,2 % | 97,9 → 73,5 % | 98,0 → 89,3 % |
| Brock, 1 Poción: jugador → rival-jefes | 95,0 → 100 % | 97,9 → 73,5 % | 98,0 → 89,3 % |
| Brock, 2 Pociones: jugador → rival-jefes | 95,0 → 100 % | 98,4 → 97,9 % | 98,0 → 100 % |

(Las cifras de Brock son de los recorridos que llegan a él, y las de Pikachu jefe y Joven de los que llegan a cada uno. Un 100 % quiere decir que no se pierde ninguno de esos primeros intentos en la muestra, no que sea imposible perder.)

### Lectura

- **Cuánto baja el primer intento**
  - En Pikachu jefe baja entre 5 y 42 puntos. Bulbasaur y Squirtle caen a 59 y 43 % con evolución y a 46 y 38 % sin ella. Charmander casi no nota nada (95 y 90 %).
  - En Brock baja poco con evolución (Bulbasaur 0,3 puntos, Squirtle nada, Charmander 16 puntos si no tiene Pociones).
  - En el Entrenador Joven baja 8 a 28 puntos.
  - La probabilidad de pasar el tramo sin perder cae a la mitad con Bulbasaur y Squirtle.
- **¿Cerca del 75 %?** Brock sin evolución y sin Pociones, sí: 77,2, 73,5 y 89,3 %. Brock con evolución sigue por encima del 98 % (salvo Charmander sin Pociones, 80,5 %). Pikachu jefe no: está en 59 / 95 / 43 % con evolución y 46 / 90 / 38 % sin ella, con un reparto muy desigual entre iniciales (50 puntos de distancia entre Charmander y Squirtle).
- **Con empieza=rival en todo, la ruta se rompe**: con Bulbasaur solo llega a Brock el 21 % y con Squirtle el 7 %. No es una opción.
- Las Pociones no ayudan contra Pikachu jefe: se compran en Ciudad Plateada, después de él.

## 3. ¿Aconsejan los números que el rival empiece en jefes y gimnasios?

- **En gimnasios, sí es asumible** con lo medido (solo Brock y el Entrenador Joven). Brock sigue en el rango alto (80 a 100 %) con evolución y baja a ~75 % sin ella, que es lo que busca Ayme. Con 1 a 2 Pociones queda en 97 a 100 %. El Entrenador Joven baja más (60 a 92 %).
- **En jefes como Pikachu, es demasiado fuerte** con los números actuales: 43 y 59 % para Squirtle y Bulbasaur con evolución, 38 y 46 % sin ella, y no se pueden arreglar con Pociones (llegan después). Para que empezara el rival habría que rebajar al jefe (no medido aquí) o aceptar que el tramo quede casi cerrado a dos de los tres iniciales.
- **En combates normales (salvajes y entrenadores), no**: los duelos 1 contra 1 pierden 26 puntos de victoria y, con el rival empezando en todo, la ruta se rompe (punto 2).
- **Límite de estos datos**: de los demás jefes (D-20 §4, 02–16) y gimnasios no hay catálogo en master, así que no se puede decir nada de ellos. Hay que repetir la medición cuando existan.

## Cómo repetirlo

```
cd sim
dart run bin/sim_campana.dart --modo=empezar --informe=../balance/informes/campana_empieza_2026-11-26/duelos_empezar.csv
dart run bin/sim_campana_partida.dart --modo=pociones --partidas=1500 --ruta1=si --retroceder=si --balls=5 --pociones=3 [--evolucion-inicial=si] --empieza=jugador|rival-jefes|rival
```

Archivos: `duelos_empezar.txt` y `.csv`; `sievo_*.txt` (con evolución) y `noevo_*.txt` (sin evolución) por cada valor de `--empieza`.
