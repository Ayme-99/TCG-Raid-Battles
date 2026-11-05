# D-10 · Sistema de puntos

Estado: **propuesta v2 para validar** (2026-11-05). Issue #10.

## 1. Lo que decidió Ayme

- Los puntos **no son una puntuación competitiva**. Sirven para **desbloquear jefes nuevos**.
- Cada partida reparte unos puntos entre los jugadores según el **daño que hizo cada uno**.
- Los puntos de la partida dependen del **daño total hecho al jefe**: `puntos = X × Y`, con X el daño hecho y Y un coeficiente propio de cada jefe, calculado a partir de su vida.
- **Perder da `X × Y + 1`**: perder sin haber hecho nada da 1 punto.
- El coste de desbloquear jefes nuevos **no está decidido**.
- D-10 incluye las reglas y el **modelo de datos del guardado**.

## 2. Puntos de una partida

1. Cada nivel tiene un **tope de puntos por victoria** (`balance/tablas/puntos_niveles.csv`): Nv1 = 100, Nv2 = 200, Nv3 = 300, Nv4 = 500. Mantienen la proporción 1 : 2 : 3 : 5 de la dificultad (D-03).
2. Cada jefe tiene su coeficiente **Y = puntos de victoria de su nivel ÷ vida del jefe**. Así el daño total de una victoria (la vida del jefe) siempre da exactamente el tope del nivel. Con los jefes de referencia: Nv1 0,0420; Nv2 0,0464; Nv3 0,0680; Nv4 0,0961.
3. **Victoria**: puntos = tope del nivel. **Derrota**: puntos = `round(X × Y) + 1`, con X = daño hecho al jefe en la partida.
4. El total se reparte entre los jugadores con la tabla de §3. Cada jugador recibe `floor(total × porcentaje)` y el resto por redondeo va al primer puesto.

## 3. Reparto entre jugadores

Tabla en `balance/tablas/reparto_puntos.csv`.

| Jugadores | Puesto 1 (más daño) | Intermedios | Último |
|---|---|---|---|
| 1 | 100 % | | |
| 2 | 55 % | | 45 % |
| 3 | 40 % | 33 % | 27 % |
| 4 | 28 % | 25 % y 25 % | 23 % |

Cómo se asignan los puestos (propuesta para dejar la regla sin ambigüedad):
1. El que más daño hizo es el puesto 1. En empate gana el que perdió menos Pokémon; si sigue el empate, se decide al azar.
2. De los demás, los que **no perdieron ningún Pokémon** ocupan primero los puestos intermedios, ordenados por daño.
3. Si sobran puestos intermedios, se rellenan con los demás por orden de daño.
4. El que queda es el último.

Ejemplo con 4 jugadores y victoria Nv2 (200 puntos): A hace el 40 % del daño, B el 30 % y perdió un Pokémon, C el 20 % y D el 10 %, ambos sin perder ninguno.
A es puesto 1 (28 % = 56 puntos). C y D, sin pérdidas, ocupan los dos intermedios (25 % = 50 puntos cada uno). B, aunque hizo más daño que ellos, queda último (23 % = 46 puntos). Suma 202: ver pregunta abierta 1.

## 4. Resultado del simulador (cartas de prueba, jefes de D-03)

| Nivel | Victoria | Daño medio en derrota | Puntos medios por derrota | Puntos medios por partida |
|---|---|---|---|---|
| Nv1 | 74 % | 82 % de la vida | 82 | 96 |
| Nv2 | 49 % | 81 % | 163 | 182 |
| Nv3 | 33 % | 76 % | 230 | 253 |
| Nv4 | 15 % | 69 % | 347 | 369 |

Consecuencia: con puntos proporcionales al daño, **perder da entre el 69 y el 82 % de lo que da ganar**, porque casi todas las derrotas llegan cerca de matar al jefe. Ganar apenas se premia más que perder. Si se quiere que la victoria pese más, hace falta un bonus de victoria (por ejemplo +50 %). Pregunta abierta 3.

## 5. Modelo de datos del guardado

Se guarda el **registro de partidas** y los totales se **calculan** a partir de él.

| Colección | Campos |
|---|---|
| `partidas` | `_id` (generado por el cliente), `fecha`, `jefe_id`, `nivel`, `jugadores` (nº), `resultado`, `dano_total`, `coeficiente_y`, `puntos_total` |
| `partida_jugadores` | `partida_id`, `jugador_id`, `dano`, `pokemon_perdidos`, `puesto`, `porcentaje`, `puntos` |
| `desbloqueos` | `jefe_id`, `ambito` (jugador o grupo), `ambito_id`, `fecha` |

- El `puntos` de cada fila se calcula al cerrar la partida con las tablas vigentes y se guarda, para que cambios futuros de las tablas no reescriban el historial.
- Total de un jugador = suma de sus `partida_jugadores.puntos`.
- Los 7 jefes de lanzamiento están disponibles desde el principio. Un jefe nuevo se desbloquea al llegar a su coste. Los puntos no se gastan.
- Una partida se guarda una sola vez (clave `_id` del cliente) para que los reintentos de red no sumen dos veces.
- `jugador_id` depende de D-11 (identidad de jugadores).

## 6. Preguntas abiertas

1. **El 4 jugadores suma 101 %** (28 + 25 + 25 + 23). Habría que ajustar uno, por ejemplo 27 / 25 / 25 / 23.
2. **¿Los puntos para desbloquear son del jugador o del grupo?** Con este reparto cada jugador acumula los suyos. Hay que decidir si un jefe se desbloquea para cada jugador por separado o para todo el grupo con la suma.
3. **Bonus de victoria**: ver §4.
4. **Costes de desbloqueo**: sin decidir. Referencia: una partida da entre ~100 y ~500 puntos en total, repartidos entre los jugadores.
5. **Daño de los aliados o efectos de Cheer**: si cuentan como daño de un jugador.
