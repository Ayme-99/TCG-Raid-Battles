# Guion de playtest en papel (T-17)

Objetivo: comprobar con cartas reales los valores provisionales del GDD §9, sobre todo si el **HP del jefe** y la **vida real de los Pokémon** de los jugadores casan con lo que dice el simulador.

Cada sesión se anota en una copia de `PLANTILLA.md` (`AAAA-MM-DD.md`). Este guion dice qué preparar, cómo jugar y qué medir.

## 1. Plan de sesiones

Cada nivel se juega con su jefe del catálogo (§4): Nv1 Onix, Nv2 Manectric, Nv3 Kingdra, Nv4 Arceus.

| Sesión | Jugadores | Nivel objetivo | Qué responde |
|---|---|---|---|
| 1 | 3-4 | Nv1 (Onix) | ¿Se entiende el flujo? ¿Gana el equipo ≈ 75 %? |
| 2 | 3-4 | Nv2 (Manectric) | ¿El salto Nv1 → Nv2 se nota demasiado? |
| 3 | 3-4 | Nv3 (Kingdra) | ¿Nv2 y Nv3 se sienten distintos? |
| 4 | 3-4 | Nv4 (Arceus) | ¿Es jugable con victoria ≈ 15 %? |
| 5 | 1-2 | el que salga | ¿La dificultad con pocos jugadores es aceptable? |

Cada nivel necesita varias partidas para decir algo sobre porcentajes: con 1 sola partida solo se detectan problemas de reglas o de números muy fuera de lugar. Apunta cada partida aunque sea repetición.

## 2. Materiales

- Cartas de Pokémon reales del formato: cada jugador lleva **2 Pokémon** (1 activo + 1 banca). Sin energías, sin entrenadores, sin mazo.
- Contadores de daño (o dados) para los Pokémon de los jugadores.
- **Jefe**: una carta de Pokémon con su HP, y un **mazo de jefe** con cartas de ataque (ver §4), más las 6 cartas de sus aliados.
- Una moneda y dados de 4 y 6 caras (o un dado normal repitiendo): objetivo aleatorio, slot y categoría de los aliados, quemadura y las monedas de los aliados.
- Las **5 cartas de ánimo** oficiales (Cheer), o notas con su texto (`docs/D-05-carta-de-animo.md`).
- El asistente (app o la hoja de papel del §6) para llevar el HP del jefe, aliados y estados.

## 3. Cómo se juega (resumen)

Reglas completas en `incursiones_gdd.md` §2-§5. Orden:

1. Cada jugador elige 2 Pokémon y anota el daño de su mejor ataque (sin tope).
2. X = suma de esos números por jugador. Nivel: `≤400` Nv1 · `401-600` Nv2 · `601-800` Nv3 · `>800` Nv4 (un X menor de 250 se juega como Nv1).
3. Se elige el jefe del nivel y se pone su HP.
4. Ronda: primero los jugadores con KO reciente (roban carta de ánimo), luego el resto por orden de asiento. Cada uno ataca al jefe o a un aliado y dice el daño al asistente.
5. Turno del jefe: se revela una carta, se aplica su daño al objetivo y se registran los KO.
6. Gana el equipo si el jefe llega a 0. Pierde si caen todos los Pokémon de la mesa (8 con 4 jugadores) o si abandona.

## 4. Jefes del catálogo (T-13/T-14)

Los 4 jefes iniciales ya están en el catálogo (`catalog/bosses/`). HP calibrado con el simulador (D-16); los dos nuevos aliados por jefe (Potenciador y Debilitador) completan las 6 categorías. Mazo de jefe: como en el juego oficial (es físico: lo llevan los jugadores). Composición sugerida para empezar: 10 cartas con 5 de ranura 1, 3 de ranura 2 y 2 de ranura 3; objetivo (todos / uno elegido / uno al azar) repartido como prefieras, **pero anótalo**.

| Jefe | Nv | HP | Ataques (ranura 1 / 2 / 3) | Máx. ataques/turno | Invocación (invocación segura) |
|---|---|---|---|---|---|
| Onix (Túnel Roca) | 1 | 2300 | 30 / 60 / 120 | 2 | cada 1150 HP perdidos |
| Manectric (Ruta 110) | 2 | 2600 | 40 / 80 / 160 | 3 | cada 867 HP perdidos |
| Kingdra (Islas Remolino) | 3 | 3700 | 60 / 100 / 200 | 4 | cada 925 HP perdidos |
| Arceus (Sala Origen) | 4 | 3800 | 40 / 100 / 240 | 5 | cada 760 HP perdidos |

Efectos de los ataques del jefe (D-14):

- **Onix**: Trampa Rocas (30): Durante el próximo turno de los jugadores, el Pokémon Defensor no puede retirarse.; Lanzarrocas (60); Doble filo (120): Onix se hace 30 puntos de daño a sí mismo.
- **Manectric**: Onda trueno (40): Lanza una moneda. Si sale cara, el Pokémon Defensor pasa a estar paralizado.; Colmillo rayo (80): Durante el próximo turno de los jugadores, el Pokémon Defensor no puede atacar.; Trueno (160)
- **Kingdra**: Ciclón (60): El daño de este ataque no se ve afectado por ningún efecto en el Pokémon Activo rival.; Pulso Dragón (100); Hidrobomba (200)
- **Arceus**: Danza Espada (40): Este ataque hace 30 puntos de daño más por cada ataque que Arceus haya usado antes en este turno.; Castigo (100): Si el Pokémon Defensor no tiene contadores de daño, este ataque hace 50 puntos de daño más.; Sentencia (240): Pon 1 contador de daño sobre todos los Pokémon en juego (menos Arceus).

**Aliados (D-13, D-16):** al cruzar un umbral de invocación (siempre «segura», sin moneda) un dado de 4 caras elige el slot libre y un dado de 6 elige la categoría (1 Daño · 2 Tanque · 3 Cura · 4 Control · 5 Potenciador · 6 Debilitador). Repite la tirada si sale un slot o una categoría ocupados; sin slot libre no hay invocación. El aliado ataca al entrar y al final de cada turno del jefe. **No hay bloqueo de slot:** el jugador puede ignorar a su aliado y dañar al jefe (salvo con Bronzong, que obliga a atacarle). El daño que sobra sobre el HP de un aliado se pierde.

### Onix (Nv1, 2300 HP)

| Categoría | Aliado | HP | Ataque | Habilidad |
|---|---|---|---|---|
| Daño | Machop | 70 | **Puño Incremento** 20: Lanza dos monedas: este ataque hace 20 puntos de daño por cada cara. | — |
| Tanque | Geodude | 90 | — | **Rizo Defensa**: Mientras Geodude esté en juego, el jefe y los aliados reciben 10 puntos de daño menos por los ataques de los jugadores. |
| Cura | Zubat | 50 | **Chupavidas** 10: Cura 10 puntos de daño al jefe y a los aliados. | — |
| Control | Rhyhorn | 100 | — | **Tormenta de arena**: Mientras Rhyhorn esté en juego, durante el chequeo Pokémon, los Pokémon activos de los jugadores reciben 10 puntos de daño. |
| Potenciador | Cubone | 60 | — | **Foco Energía**: Cada vez que el jefe vaya a atacar, lanza una moneda. Si sale cara, el ataque hace 10 puntos de daño más. |
| Debilitador | Haunter | 80 | — | **Rencor**: Los Pokémon de los jugadores no pueden usar el mismo ataque 2 turnos seguidos. |

### Manectric (Nv2, 2600 HP)

| Categoría | Aliado | HP | Ataque | Habilidad |
|---|---|---|---|---|
| Daño | Plusle | 80 | **Chispazo** 30: Este ataque también hace 30 puntos de daño a los Pokémon adyacentes al jugador objetivo. | — |
| Tanque | Minun | 90 | **Bola Voltio** 10 | **Moflete Estático**: Si este Pokémon queda fuera de combate por el daño de uno de los ataques de los jugadores, el Pokémon atacante pasa a estar Paralizado. |
| Cura | Oddish | 60 | — | **Drenadoras**: Cuando Oddish entra en juego y durante el chequeo Pokémon, pon un contador de daño en todos los Pokémon Activos. El jefe se cura 10 HP por cada contador puesto (lo cura la app; los contadores los pone la mesa). |
| Control | Gulpin | 100 | — | **Tóxico**: Cuando Gulpin entra en juego y al principio de cada turno del jefe, el Pokémon frente a Gulpin pasa a estar Envenenado. |
| Potenciador | Poochyena | 70 | — | **Aullido**: Los ataques del jefe hacen 20 puntos de daño más (lo suma la app). |
| Debilitador | Zigzagoon | 50 | — | **Gruñido**: Los ataques de los jugadores hacen 10 puntos de daño menos (lo aplica la app). |

### Kingdra (Nv3, 3700 HP)

| Categoría | Aliado | HP | Ataque | Habilidad |
|---|---|---|---|---|
| Daño | Krabby | 70 | **Martillazo** 30: Lanza dos monedas: si sale cara en alguna de ellas, este ataque hace 50 puntos de daño más. | — |
| Tanque | Seel | 100 | — | **Velo Sagrado**: Evita que el jefe y los aliados sufran efectos de estado. Al entrar, el jefe pierde los que tuviera (lo aplica la app). |
| Cura | Golbat | 80 | **Chupavidas** 30: Cura 30 puntos de daño al jefe y a los aliados. | **Allanamiento**: Los ataques de Golbat no se ven afectados por ningún efecto en el Pokémon Activo del rival. |
| Control | Tentacruel | 90 | — | **Constricción**: Mientras Tentacruel esté en juego, los jugadores no pueden cambiar el Pokémon Activo por uno de la Banca. |
| Potenciador | Horsea | 60 | — | **Agilidad**: Mientras Horsea esté en juego, el primer ataque del jefe en cada turno hace 30 puntos de daño más (lo suma la app). |
| Debilitador | Magikarp | 50 | — | **Bote**: Cada vez que Magikarp va a recibir daño, se lanza una moneda: si sale cara, se evita ese daño (lo tira la app al atacarlo). |

### Arceus (Nv4, 3800 HP)

| Categoría | Aliado | HP | Ataque | Habilidad |
|---|---|---|---|---|
| Daño | Medicham | 90 | **Puño Dinámico** 70: El Pokémon Defensor queda Confundido. Si el Pokémon Defensor ya tenía un estado especial, este ataque hace 70 puntos de daño más. | **Energía Pura**: Los ataques de Medicham no se ven afectados por ningún efecto en el Pokémon Activo rival. |
| Tanque | Bronzong | 100 | — | **Bloqueo**: Mientras Bronzong esté en juego, los jugadores solo pueden atacarle a él (o pasar el turno), y recibe 100 puntos de daño menos de cada ataque (lo aplica la app). |
| Cura | Chingling | 50 | — | **Deseo**: Al entrar, se lanzan 10 monedas por el jefe (100 HP por cada cara) y una moneda por cada aliado y por cada Pokémon de los jugadores (cara: se curan 100 puntos de daño). Lo tira la app. |
| Control | Nosepass | 60 | — | **Fijar Blanco**: Cuando Nosepass entra en juego, la primera moneda que lance cada jugador a partir de ese momento será cruz. Aunque Nosepass sea derrotado, el efecto sigue aplicado. (Lo aplican los jugadores en la mesa.) |
| Potenciador | Solrock | 70 | **Envite Ígneo** 10: Cada vez que Solrock usa este ataque, hace 10 puntos de daño más y gana 10 HP máximos (y 10 HP actuales). | — |
| Debilitador | Lunatone | 80 | **Fuerza Lunar** 10: El rival lanza una moneda: si sale cruz, el siguiente ataque de ese Pokémon hace 30 puntos de daño menos. | — |

Si el mazo sugerido da una partida claramente demasiado fácil o difícil, no lo ajustes sobre la marcha: anótalo y cambia una sola cosa en la partida siguiente.

## 5. Qué medir en cada partida

**Imprescindible (las incógnitas del GDD §9):**
- Vida real de los Pokémon de los jugadores (HP de cada carta) y el daño de su mejor ataque. Compáralo con la hipótesis `60-100 + 0,6 × ataque`.
- Resultado, número de rondas y HP del jefe al final.
- Cuántos Pokémon cayeron y en qué rondas.
- Si el X obtenido dio el nivel esperado y cuántas veces hubo que discutir el número del mejor ataque (D-02).

**Reglas provisionales a observar:**
- X sin tope por ataque: ¿algún equipo supera 800 (Nv4) sin discutir el número?
- Cartas de ánimo: una por KO, máximo 3 distintas. ¿Hacen la partida más fácil de lo calibrado? ¿Alguna carta resulta rota?
- Veneno y quemadura del jefe (D-12): ¿importan o son ruido?
- Aliados: umbral, dado de slot y de categoría, y si cada aliado se siente útil o abusivo (Bloqueo de Bronzong, Deseo de Chingling, Envite Ígneo de Solrock).
- Aliados sin bloqueo de slot: ¿se ignora al aliado para dañar al jefe o se le ataca primero?

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
