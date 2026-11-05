# D-03 · Sistema de poder y balance

**Estado:** borrador 1. Pendiente de dos decisiones (ver §7). Los números marcados como *propuesta* o *hipótesis* no están validados todavía: los validará el simulador (`sim/`) y los playtests (T-17).

## 1. Para qué sirve

Cada jefe es una **carta fija**: su HP y sus ataques no cambian durante la partida ni se escalan según los jugadores. Para poder diseñar jefes nuevos sin adivinar (y para que 2 jefes del mismo nivel se sientan igual de duros aunque uno tenga mucho HP y otro pegue mucho) necesitamos una **medida común de lo duro que es un jefe**. Eso es el *Poder*.

## 2. Qué hace el juego oficial (hechos comprobados)

| Dato | Valor oficial |
|---|---|
| Jugadores | 4, cada uno con 2 Pokémon (activo + banca) |
| Cómo se elige el nivel | Cada pareja aporta **solo su ataque base más fuerte**; se suman los 4 valores (X). 250-390 → Nv1 · 400-590 → Nv2 · 600+ → Nv3. Menos de 250 se desaconseja |
| Ataques del jefe por turno | Máximo 2 (Nv1), 3 (Nv2), 4 (Nv3) |
| Mazo de ataques del jefe | 20 cartas. Cada una dice "ataque 1/2/3 contra el jugador N" (5 cartas por jugador). 13 de 20 dicen "roba otra carta" |
| Reparto de ranuras | Ataque 1: 8 cartas · Ataque 2: 8 cartas · Ataque 3: 4 cartas |
| Derrota | 4 KO en total (cada KO cuenta, aunque sea el mismo Pokémon) |
| Cheer | Un jugador con KO actúa primero, roba una carta de ánimo (5 posibles, se usan máx. 3) y su Pokémon vuelve al final de la ronda |
| HP del jefe (Drednaw VMAX) | **1600 / 2200 / 3000** (Nv1 / Nv2 / Nv3) |
| Daño de sus ataques 1/2/3 | Nv1: 30/60/120 · Nv2: 40/80/160 · Nv3: 60/100/200 |

Fuentes en §9. No he abierto los PDF oficiales; los datos vienen de Bulbapedia y Serebii.

## 3. Diferencias entre nuestro GDD v0.5 y el oficial

1. **Cómo se calcula X.** El oficial suma el mejor ataque *de cada jugador* (4 números). El GDD suma el máximo daño *de cada Pokémon* (hasta 8 números), que da valores casi el doble de grandes para el mismo equipo. Con los mismos cortes (400/600/800), un equipo normal caería un nivel por encima de lo que el HP oficial espera. **Hay que elegir una definición** (§7, decisión A).
2. **Derrota.** Oficial: 4 KO en total. GDD: un jugador cae al perder todos sus Pokémon y se pierde cuando caen todos. Con 4 jugadores y 2 Pokémon cada uno son 8 KO en vez de 4, así que a igual daño de jefe nuestra versión es más fácil. El simulador tiene que medirlo.
3. **Objetivo de los ataques.** Oficial: cada carta apunta a un jugador concreto. GDD: todos / uno elegido / uno al azar. Los ataques "a todos" no existen en el oficial y pegan mucho más fuerte al equipo.
4. **Revivir.** Oficial: el Cheer devuelve al Pokémon caído. GDD: no hay revivir definido.

## 4. La fórmula

**Amenaza del jefe** = ataques esperados por turno × daño medio por ataque (con el efecto de objetivo si es "a todos").

**Poder del jefe** = HP efectivo × Amenaza.

- *HP efectivo* = HP + curación esperada + HP de los aliados que invoca (si los hay).
- *Ataques esperados* con la mecánica oficial de "roba otra carta": probabilidad media de seguir robando 0,65 → 1,65 ataques (máx. 2), 2,07 (máx. 3), 2,35 (máx. 4), 2,53 (máx. 5).

**Por qué es el producto:** el equipo gana si derriba al jefe (HP ÷ daño del equipo por ronda) antes de que el jefe derribe al equipo (vida del equipo ÷ amenaza). Comparando ambos tiempos, queda HP × Amenaza frente a daño × vida del equipo, y las dos partes del equipo crecen con X.

**Comprobación con el juego oficial** (usando el centro de cada banda de X):

| Nivel | X centro | HP | Daño medio por ataque | Amenaza | Poder | Poder ÷ X² |
|---|---|---|---|---|---|---|
| Nv1 | 320 | 1600 | 60 | 99 | 158.400 | 1,55 |
| Nv2 | 500 | 2200 | 80 | 166 | 364.760 | 1,46 |
| Nv3 | 700 | 3000 | 104 | 244 | 732.303 | 1,49 |

El último cuadro es la clave: **Poder ≈ 1,5 × X²** en los tres niveles. Los diseñadores oficiales no lo dijeron, pero sus números lo cumplen. Eso nos da una regla para crear jefes nuevos: **elegir el nivel, calcular el Poder objetivo = 1,5 × X_centro², y repartirlo entre HP y amenaza como queramos.**

## 5. Cómo se reparte el Poder (ejemplos para Nv2, Poder objetivo ≈ 365.000)

| Tipo de jefe | HP | Amenaza por turno | Sensación |
|---|---|---|---|
| Equilibrado (oficial) | 2200 | 166 | Referencia |
| Tanque | 3000 | 122 | Mucho HP, pega poco: partida larga y relajada |
| Cañón de cristal | 1400 | 260 | Poco HP, pega mucho: partida corta y tensa, hay que derribarlo rápido |

Dos jefes con el mismo Poder son igual de difíciles en media, aunque se jueguen distinto. Esto es lo que permite que un jefe de poco HP y mucho daño siga siendo Nv3.

## 6. Propuesta de Nv4 (hipótesis, sin validar)

El oficial llega hasta Nv3. Con X de referencia ≈ 900 y la misma regla: Poder ≈ 1,5 × 900² ≈ 1.215.000. Con ataques 80/120/240, hasta 5 ataques por turno (amenaza ≈ 323) sale **HP ≈ 3750**. El valor lo confirmará el simulador. Que Nv4 use 3 Pokémon por jugador cambia la durabilidad del equipo y también hay que simularlo.

## 7. Decisiones pendientes

**A. Definición de X.** (recomendada: la oficial)
- Oficial: mejor ataque de cada jugador. Con ella, los HP oficiales y la regla Poder ≈ 1,5 × X² cuadran tal cual.
- GDD actual: ataque máximo de cada Pokémon. Habría que rehacer los cortes (≈ el doble) o reducir los HP de la tabla.

**B. Jugar con menos de 4 jugadores.** Con X oficial, 1 jugador suma ≈ 80-150 y 2 jugadores ≈ 160-300. Un jefe Nv1 de 1600 HP necesita ≈ 5 rondas de X = 320 de daño por ronda. Para 1-2 jugadores sería mucho más largo y duro. Opciones:
- Añadir niveles bajos (Nv0 o más tramos) con jefes de HP pequeño.
- Aceptar que el formato está pensado para 3-4 jugadores y 1-2 usan Pokémon más fuertes.
- Que el jefe tenga distinto HP según nº de jugadores (rompe "carta fija").

## 8. Lo que falta validar con el simulador

- Un modelo simplificado del juego oficial (4 jugadores, 4 KO, Cheer sin efectos) da victoria entre 24 % y 96 % y 5-6 rondas **según cuánta vida suponga a los Pokémon de los jugadores**. Esa vida (hipótesis `60-100 + 0,6 × ataque`) es la incógnita principal. Hay que medir Pokémon reales en playtest (T-17).
- Dentro de un nivel, la dificultad cambia mucho entre el X más bajo y el más alto de la banda (el Poder crece con X²: de 400 a 590 es ≈ 2,2 veces). Es lo mismo que pasa en el oficial; hay que decidir si lo aceptamos o estrechamos bandas.
- Cómo afecta que no haya "revivir" en nuestra versión y que los ataques "a todos" existan.

## 9. Fuentes

- Bulbapedia, *Raid Battle (TCG)*: reglas, umbrales de X, mazo de ataques, Cheer, límite de KO. https://bulbapedia.bulbagarden.net/wiki/Raid_Battle_(TCG)
- Serebii, *Raid Battles in Pokémon TCG*, carta Drednaw VMAX (HP y daño por nivel): https://serebii.net/card/raidbattles/002.shtml
- Página oficial: https://tcg.pokemon.com/en-us/raid-battle/
