# Guion de playtest en papel (T-17)

Objetivo: comprobar con cartas reales los valores provisionales del GDD §9, sobre todo si el **HP del jefe** y la **vida real de los Pokémon** de los jugadores casan con lo que dice el simulador.

Cada sesión se anota en una copia de `PLANTILLA.md` (`AAAA-MM-DD.md`). Este guion dice qué preparar, cómo jugar y qué medir.

## 1. Plan de sesiones

El catálogo de jefes (T-13/T-14) aún no existe, así que las primeras sesiones usan un **jefe de prueba**: una carta de Pokémon real con el HP de referencia del nivel (GDD §2) y los ataques genéricos del nivel.

| Sesión | Jugadores | Nivel objetivo | Qué responde |
|---|---|---|---|
| 1 | 3-4 | Nv1 | ¿Se entiende el flujo? ¿Gana el equipo ≈ 75 %? |
| 2 | 3-4 | Nv2 | ¿El salto Nv1 → Nv2 se nota demasiado? |
| 3 | 3-4 | Nv3 | ¿Nv2 y Nv3 se sienten distintos? (en el simulador son casi iguales) |
| 4 | 3-4 | Nv4 | ¿Es jugable con victoria ≈ 15 %? |
| 5 | 1-2 | el que salga | ¿La dificultad con pocos jugadores es aceptable? |

Cada nivel necesita varias partidas para decir algo sobre porcentajes: con 1 sola partida solo se detectan problemas de reglas o de números muy fuera de lugar. Apunta cada partida aunque sea repetición.

## 2. Materiales

- Cartas de Pokémon reales del formato: cada jugador lleva **2 Pokémon** (1 activo + 1 banca). Sin energías, sin entrenadores, sin mazo.
- Contadores de daño (o dados) para los Pokémon de los jugadores.
- **Jefe**: una carta de Pokémon con su HP, y un **mazo de jefe** con cartas de ataque (ver §4).
- Una moneda y dados de 3/4 caras (o un dado normal repitiendo): objetivo aleatorio, invocación de aliados y quemadura.
- Las **5 cartas de ánimo** oficiales (Cheer), o notas con su texto (`docs/D-05-carta-de-animo.md`).
- El asistente (app o la hoja de papel del §6) para llevar el HP del jefe, aliados y estados.

## 3. Cómo se juega (resumen)

Reglas completas en `incursiones_gdd.md` §2-§5. Orden:

1. Cada jugador elige 2 Pokémon y anota el daño de su mejor ataque (tope 200).
2. X = suma de esos números por jugador. Nivel: `<400` Nv1 · `400-599` Nv2 · `600-799` Nv3 · `≥800` Nv4 (un X menor de 250 se juega como Nv1).
3. Se elige el jefe del nivel y se pone su HP.
4. Ronda: primero los jugadores con KO reciente (roban carta de ánimo), luego el resto por orden de asiento. Cada uno ataca al jefe o a un aliado y dice el daño al asistente.
5. Turno del jefe: se revela una carta, se aplica su daño al objetivo y se registran los KO.
6. Gana el equipo si el jefe llega a 0. Pierde si caen todos los Pokémon de la mesa (8 con 4 jugadores) o si abandona.

## 4. Jefe de prueba (propuesta para esta fase)

Marcado como **propuesta de prueba**: el GDD define los ataques por nivel y las ranuras 1/2/3, pero no cuántas cartas tiene el mazo del jefe ni cómo se reparten.

- HP: el de referencia del nivel: Nv1 2382 · Nv2 4313 · Nv3 4411 · Nv4 5205 (o el de la carta si usas una real, anotándolo).
- Ataques por nivel (ranura 1 / 2 / 3): Nv1 30/60/120 · Nv2 40/80/160 · Nv3 60/100/200 · Nv4 80/120/240.
- Máximo de ataques por turno: Nv1 2 · Nv2 3 · Nv3 4 · Nv4 5.
- Mazo de jefe, como en el juego oficial (confirmado). Composición sugerida para empezar: 10 cartas con 5 de ranura 1, 3 de ranura 2 y 2 de ranura 3; objetivo de cada ataque (todos / uno elegido / uno al azar) repartido como prefieras, **pero anótalo** para poder repetirlo.
- Sin aliados en la sesión 1. Se añaden en la sesión 2 si el flujo base se entiende, porque aún no están calibrados (GDD §9).
- **Aliados (D-13):** cada jefe tiene 4 aliados, uno por categoría: Daño, Barrera, Cura y Pícaro (ejemplo: Rattata, Mr. Mime, Chansey y Scyther). Al cruzar un umbral se tira la moneda; si sale cara, un dado elige el slot y otro la categoría, sin repetir un slot ni una categoría en uso (en papel, repite la tirada si sale un valor ocupado). Sin slot libre no hay invocación. Los números de cada aliado están por definir: anota los que uséis.

Si el mazo sugerido da una partida claramente demasiado fácil o difícil, no lo ajustes sobre la marcha: anótalo y cambia una sola cosa en la partida siguiente.

## 5. Qué medir en cada partida

**Imprescindible (las incógnitas del GDD §9):**
- Vida real de los Pokémon de los jugadores (HP de cada carta) y el daño de su mejor ataque. Compáralo con la hipótesis `60-100 + 0,6 × ataque`.
- Resultado, número de rondas y HP del jefe al final.
- Cuántos Pokémon cayeron y en qué rondas.
- Si el X obtenido dio el nivel esperado y cuántas veces hubo que discutir el número del mejor ataque (D-02).

**Reglas provisionales a observar:**
- Tope de 200 por ataque: ¿recorta algo en la práctica?
- Cartas de ánimo: una por KO, máximo 3 distintas. ¿Hacen la partida más fácil de lo calibrado? ¿Alguna carta resulta rota?
- Veneno y quemadura del jefe (D-12): ¿importan o son ruido?
- Aliados (sesión 2 en adelante): umbral, moneda y dado de slot, y vida y daño de cada aliado.
- Bloqueo por aliado: ¿frustra o añade decisiones?

**Sensación de mesa (anótala con tus palabras):**
- ¿Hay turnos muertos? ¿Alguien deja de decidir?
- ¿Se sabe en cada momento a quién le toca y qué hay que decirle al asistente?
- ¿Se llega al final con tensión o la partida se decide pronto?

## 6. Hoja de registro de partida (si no usas la app)

Copia la tabla en la sesión y rellénala:

| Ronda | HP jefe al inicio | Daño J1 | Daño J2 | Daño J3 | Daño J4 | Ataque del jefe (ranura, daño, objetivo) | KO | Notas |
|---|---|---|---|---|---|---|---|---|
| 1 | | | | | | | | |

Datos fijos de la partida: HP y mejor ataque de cada Pokémon, X, nivel, jefe, estado del mazo del jefe.

## 7. Qué hacer con los resultados

- Un problema de reglas o un texto ambiguo: se corrige en el GDD (regla del repo: no solo en el tablero) y se enlaza en la sesión.
- Un número que parece mal: se anota en «Números que parecieron mal» y se contrasta con el simulador (`sim/`) antes de cambiar nada.
- Una propuesta de cambio: crea una tarjeta en el tablero y enlázala en «Cambios propuestos» de la plantilla.
- Si la vida real de los Pokémon supera mucho la hipótesis, la consecuencia está en `docs/D-03-sistema-de-poder.md` §8.2: hay que subir el HP de los jefes.
