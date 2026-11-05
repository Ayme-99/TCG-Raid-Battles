# D-03 · Sistema de poder y balance

**Estado:** borrador 1. Decisiones A y B tomadas (ver §7); falta validar con el simulador. Los números marcados como *propuesta* o *hipótesis* no están validados todavía: los validará el simulador (`sim/`) y los playtests (T-17).

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

1. **Cómo se calcula X.** El oficial suma el mejor ataque *de cada jugador* (4 números). El GDD suma el máximo daño *de cada Pokémon* (hasta 8 números), que da valores casi el doble de grandes para el mismo equipo. Con los mismos cortes (400/600/800), un equipo normal caería un nivel por encima de lo que el HP oficial espera. **Decidido: se usa la definición oficial** (§7, decisión A).
2. **Derrota.** Oficial: 4 KO en total. GDD: un jugador cae al perder todos sus Pokémon y se pierde cuando caen todos. Con 4 jugadores y 2 Pokémon cada uno son 8 KO en vez de 4, así que a igual daño de jefe nuestra versión es más fácil. **Decidido: se mantiene la regla del GDD** (§7, decisión C); el simulador la usa por defecto.
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

## 7. Decisiones tomadas (2026-11-05)

- **A. X se calcula como en el oficial:** se suma el ataque base más fuerte de cada jugador. El GDD v0.6 ya lo recoge.
- **B. Formato pensado para 3-4 jugadores.** Con 1 o 2 jugadores la partida es más larga y dura (un jefe Nv1 de 1600 HP necesita ≈ 5 rondas de X = 320; con X ≈ 100-200 son 8-16 rondas). Se acepta. No se añaden niveles bajos por ahora.
- **Jefe = carta fija** (sin escalado) con HP parecido al oficial.
- **C. Regla de derrota: se mantiene la del GDD.** La partida solo se pierde cuando todos los Pokémon de todos los jugadores han caído (8 KO con 4 jugadores y 2 Pokémon cada uno). Mientras quede uno en pie, se sigue. No se adopta el límite oficial de 4 KO. Consecuencia: a igual jefe nuestra versión es más fácil que la oficial y la tabla de HP se valida con esta regla.

## 8. Resultados del simulador y lo que falta validar

### 8.1 Primeros resultados (`sim/bin/sim.dart`, 2000 partidas por nivel, X en el centro de cada banda)

Modelo simplificado: 4 jugadores × 2 Pokémon, Pokémon con HP `60 + 0,6 × ataque`, el segundo Pokémon ataca al 60 % del primero, eficiencia 85 %, el jefe encadena ataques con probabilidad 0,65 y cada ataque va a un jugador al azar. Cheer y revivir no están modelados.

| Variante | Nv1 | Nv2 | Nv3 | Nv4 |
|---|---|---|---|---|
| Regla oficial (4 KO), HP 0,6 | 42 % | 32 % | 17 % | 13 % |
| Regla oficial, 3 jugadores | 49 % | 27 % | 17 % | 15 % |
| Regla oficial, HP 1,0 | 83 % | 69 % | 52 % | 41 % |
| **Regla GDD (todos eliminados), HP 0,6** | **84 %** | **66 %** | **45 %** | **34 %** |

Lectura:

- La victoria baja de forma regular con el nivel en todas las variantes, así que el orden de dificultad de la tabla es correcto.
- Pasar de 3 a 4 jugadores casi no cambia el resultado (X ya escala con los jugadores).
- El nivel absoluto depende de dos incógnitas: la vida de los Pokémon de los jugadores y la regla de derrota. Con la regla de derrota decidida (decisión C), queda la vida de los Pokémon.
- Con la regla del GDD el Nv1 queda en ≈ 84 %, el Nv3 en ≈ 45 % y el Nv4 en ≈ 34 %. El Nv1 sale alto para un nivel inicial; el objetivo de victoria por nivel está por fijar.

### 8.2 Pendiente

- **Medir la vida de los Pokémon de los jugadores** con cartas reales en playtest (T-17). Es la incógnita principal (hipótesis `60-100 + 0,6 × ataque`).
- **Fijar el objetivo de victoria por nivel** y, si hace falta, retocar HP o ataques de los jefes de `balance/tablas/niveles.csv`.
- Dentro de un nivel, la dificultad cambia mucho entre el X más bajo y el más alto de la banda (el Poder crece con X²: de 400 a 590 es ≈ 2,2 veces). Es lo mismo que pasa en el oficial; hay que decidir si lo aceptamos o estrechamos bandas.
- Modelar el efecto de no tener "revivir" y de los ataques "a todos".
- Validar el Nv4 (sigue siendo propuesta sin validar).

## 9. Fuentes

- Bulbapedia, *Raid Battle (TCG)*: reglas, umbrales de X, mazo de ataques, Cheer, límite de KO. https://bulbapedia.bulbagarden.net/wiki/Raid_Battle_(TCG)
- Serebii, *Raid Battles in Pokémon TCG*, carta Drednaw VMAX (HP y daño por nivel): https://serebii.net/card/raidbattles/002.shtml
- Página oficial: https://tcg.pokemon.com/en-us/raid-battle/
