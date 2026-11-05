# D-10 · Sistema de puntos

Estado: **propuesta v2 para validar** (2026-11-05). Issue #10.

## 1. Lo que decidió Ayme

- Los puntos **no son una puntuación competitiva**. Sirven para **desbloquear jefes nuevos**.
- Cada partida genera unos puntos **para todo el equipo**, pero **no se reparten a partes iguales**: cada jugador recibe según lo que aportó en el combate (el daño que hizo).
- **Solo cobran los jugadores con cuenta** en la aplicación. Un invitado no cobra, y su parte **se pierde** (no se reparte a los demás). Si la partida se juega en modo invitado, solo el host recibe la parte que le toca.
- Los puntos de la partida dependen del **daño total hecho al jefe**: `puntos = X × Y`, con X el daño hecho y Y un coeficiente propio de cada jefe, calculado a partir de su vida.
- **Perder da `X × Y + 1`**: perder sin haber hecho nada da 1 punto.
- El coste de desbloquear jefes nuevos **no está decidido**.
- D-10 incluye las reglas y el **modelo de datos del guardado**.

## 2. Puntos de una partida

1. Cada nivel tiene un **tope de puntos por victoria** (`balance/tablas/puntos_niveles.csv`): Nv1 = 3000, Nv2 = 6000, Nv3 = 9000, Nv4 = 15000. Mantienen la proporción de dificultad de D-03 y son cifras grandes para no tener decimales.
2. Cada jefe tiene un coeficiente **Y = tope de victoria de su nivel ÷ vida del jefe**. Con los jefes de referencia: Nv1 1,2594; Nv2 1,3911; Nv3 2,0403; Nv4 2,8818.
3. **Victoria**: puntos = X × Y, con X el daño hecho (la vida del jefe), es decir el tope del nivel.
4. **Derrota**: el coeficiente baja a **Y ÷ 4**, es decir, solo se lleva una cuarta parte. Puntos = `round(X × Y ÷ 4) + 1`. Perder sin hacer nada da 1 punto.
5. El total se reparte entre los jugadores con la tabla de §3. Cada jugador recibe `floor(total × porcentaje)` y el resto por redondeo va al primer puesto.
6. **Cuentas e invitados**: el reparto se calcula siempre con todos los jugadores de la mesa. Después, solo se abonan los puntos de los jugadores con cuenta. La parte de un invitado no se abona a nadie. El host recibe la suya (ver pregunta abierta 1).
7. **Qué cuenta como daño de un jugador**: el de sus ataques y el de las cartas de Cheer que juegue. El daño de un aliado invocado se atribuye al jugador que lo invocó (propuesta).

## 3. Reparto entre jugadores

Tabla en `balance/tablas/reparto_puntos.csv`.

| Jugadores | Puesto 1 (más daño) | Intermedios | Último |
|---|---|---|---|
| 1 | 100 % | | |
| 2 | 55 % | | 45 % |
| 3 | 40 % | 33 % | 27 % |
| 4 | 27 % | 25 % y 25 % | 23 % |

Cómo se asignan los puestos (propuesta para dejar la regla sin ambigüedad):
1. El que más daño hizo es el puesto 1. En empate gana el que perdió menos Pokémon; si sigue el empate, se decide al azar.
2. De los demás, los que **no perdieron ningún Pokémon** ocupan primero los puestos intermedios, ordenados por daño.
3. Si sobran puestos intermedios, se rellenan con los demás por orden de daño.
4. El que queda es el último.

Ejemplo con 4 jugadores y victoria Nv2 (6000 puntos): A hace el 40 % del daño, B el 30 % y perdió un Pokémon, C el 20 % y D el 10 %, ambos sin perder ninguno.
A es puesto 1 (27 % = 1620 puntos). C y D, sin pérdidas, ocupan los dos intermedios (25 % = 1500 puntos cada uno). B, aunque hizo más daño que ellos, queda último (23 % = 1380 puntos). Suma 6000.

## 4. Cuánto se tarda en desbloquear (simulador, cartas de prueba)

Coste de desbloquear un jefe nuevo (por cuenta, sobre el total acumulado, sin gastar): Lv1 = 10.000, Lv2 = 20.000, Lv3 = 30.000, Lv4 = 40.000. De salida solo habrá un jefe extra de Lv4 y se irán añadiendo.

Con la derrota a un cuarto, los puntos medios por partida y las partidas que necesita una cuenta jugando siempre ese nivel son:

| Nivel | Victoria | Derrota media | Puntos medios por partida (equipo) | Partidas para desbloquear: grupo de 4 (25 % medio) | Grupo de 2 (40 % medio) |
|---|---|---|---|---|---|
| Nv1 | 74 % | 615 | 2380 | 17 | 11 |
| Nv2 | 49 % | 1215 | 3560 | 22 | 14 |
| Nv3 | 33 % | 1710 | 4116 | 29 | 18 |
| Nv4 | 15 % | 2588 | 4449 | 36 | 22 |

Los topes se fijaron en 3000 / 6000 / 9000 / 15000 (tres veces los de la versión anterior) porque con la escala anterior hacían falta de 50 a 108 partidas por jefe, demasiado. Ahora son unas 17 a 36 partidas en grupo de 4.

Notas:
- Ganar pesa: una victoria da cuatro veces lo que da una derrota con el mismo daño.
- Jugar solo da el 100 % de los puntos, pero Ayme espera que casi siempre sea una derrota (solo cobra un cuarto), así que no se considera un atajo.
- Los topes son el único mando para acelerar o frenar los desbloqueos: los costes no cambian.

## 5. Modelo de datos del guardado

Se guarda el **registro de partidas** y los totales se **calculan** a partir de él.

| Colección | Campos |
|---|---|
| `partidas` | `_id` (generado por el cliente), `fecha`, `jefe_id`, `nivel`, `jugadores` (nº), `resultado`, `dano_total`, `coeficiente_y`, `puntos_total` |
| `partida_jugadores` | `partida_id`, `jugador_id`, `dano`, `pokemon_perdidos`, `puesto`, `porcentaje`, `puntos` |
| `desbloqueos` | `jefe_id`, `cuenta_id`, `fecha` |

- El `puntos` de cada fila se calcula al cerrar la partida con las tablas vigentes y se guarda, para que cambios futuros de las tablas no reescriban el historial.
- Los invitados no tienen `jugador_id`: sus filas se guardan sin cuenta (`jugador_id` vacío, `puntos` calculados pero no abonados) para poder auditar el reparto, o no se guardan. Decisión pendiente.
- Total de una cuenta = suma de sus `partida_jugadores.puntos` abonados.
- Los 7 jefes de lanzamiento están disponibles desde el principio. Un jefe nuevo se desbloquea al llegar a su coste. Los puntos no se gastan.
- Una partida se guarda una sola vez (clave `_id` del cliente) para que los reintentos de red no sumen dos veces.
- `jugador_id` es el id de cuenta. Depende de D-11 (identidad de jugadores y cuentas).

## 6. Preguntas abiertas

Resueltas: reparto de 4 jugadores (27 / 25 / 25 / 23), derrota a un cuarto del coeficiente, todo el daño de la fuente de un jugador (ataques, Cheer, aliados que invoca) cuenta para él, costes de desbloqueo 10.000 / 20.000 / 30.000 / 40.000, el desbloqueo es por cuenta, el host necesita cuenta (porque la aplicación exige cuenta), jugar solo es posible aunque casi siempre se pierda.

1. **Escala de los topes**: 3000 / 6000 / 9000 / 15000 dan de 17 a 36 partidas por desbloqueo en grupo de 4. Confirmar o ajustar tras playtests (T-17).
2. **Invitados**: si la aplicación exige cuenta para usarla, ¿existe de verdad el modo invitado? Confirmar cómo entra un invitado (D-11).
