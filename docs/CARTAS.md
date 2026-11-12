# Cartas del set TCG-Raids (28)

Las cartas las crea Ayme en PokeCardMaker (set «TCG-Raids»). Esta tabla es lo que hay en el catálogo (`catalog/bosses/*.json`), que es lo que usa la app, y dice **qué hace la app y qué hace la mesa** con cada carta. Se numeran por bloques de 7: el jefe y sus 6 aliados.

La app lleva al jefe y a sus aliados (vida, curas, reducciones, monedas del bando del jefe). Lo que cae sobre los Pokémon de los jugadores (daño, contadores, Condiciones Especiales) lo aplican ellos en la mesa; la app lo recuerda en el momento en que toca.

Diferencias con las cartas impresas a día de hoy (T-70):

- **PS de los jefes**: las cartas dicen Onix 2300, Manectric 2600, Kingdra 3700 y Arceus 3800; el catálogo mantiene 2200 / 2700 / 3800 / 3900 (la calibración de T-68). Pendiente de que Ayme decida cuál manda.
- **Lunatone (28/28)** todavía no tiene carta: el catálogo conserva la versión anterior.
- **Bote (Magikarp)**: la carta dice que la moneda la lanza el jugador atacante; la app la lanza por él.

## Onix — Nv1, Túnel Roca

| Nº | Carta | PS | Ataque | Habilidad | Lo hace la app | Lo hace la mesa |
|---|---|---|---|---|---|---|
| 01 | **Onix** (jefe) | 2200 | **Trampa Rocas** 30: Durante el próximo turno de los jugadores el Pokémon Defensor no puede retirarse. · **Lanzarrocas** 60 · **Doble Filo** 120: Este Pokémon también se hace 30 puntos de daño a sí mismo. | — | Trampa Rocas: apunta que el Defensor no puede retirarse y se lo recuerda en su turno. Doble Filo: resta los 30 a Onix. | El daño a los Pokémon. |
| 02 | Machop (Daño) | 70 | **Puño Incremento** 20×: Lanza 2 monedas. Este ataque hace 20 puntos de daño por cada cara. | — | Tira las 2 monedas y dice el daño. | El daño al Pokémon. |
| 03 | Geodude (Tanque) | 90 | — | **Rizo Defensa**: Mientras este Pokémon esté en juego, los ataques de los jugadores hacen 10 puntos de daño menos al jefe y a los aliados. | Resta 10 a cada ataque que apunten los jugadores (al jefe y a los aliados) y lo avisa en el turno. | Nada: se apunta el daño de la carta. |
| 04 | Zubat (Curandero) | 50 | **Chupavidas** 10: Cura 10 puntos de daño al jefe y a los aliados. | — | Cura 10 al jefe y a los aliados cada vez que ataca. | El daño al Pokémon. |
| 05 | Rhyhorn (Control) | 100 | — | **Tormenta de Arena**: Mientras este Pokémon esté en juego, durante el Chequeo Pokémon, pon 1 contador de daño en cada Pokémon Activo de los jugadores. | Pide el Chequeo Pokémon antes de terminar el turno del jefe. | Poner 1 contador en cada Pokémon Activo. |
| 06 | Cubone (Potenciador) | 60 | — | **Foco Energía**: Mientras este Pokémon esté en juego, cada vez que el jefe vaya a atacar, lanza 1 moneda. Si sale cara, ese ataque hace 10 puntos de daño más. | Tira la moneda en cada ataque del jefe y suma 10 si sale cara. | Nada. |
| 07 | Haunter (Debilitador) | 80 | — | **Rencor**: Mientras este Pokémon esté en juego, los Pokémon de los jugadores no pueden usar el mismo ataque en 2 turnos seguidos. | Lo recuerda en el turno de cada jugador. | No repetir ataque en 2 turnos seguidos. |

## Manectric — Nv2, Ruta 110

| Nº | Carta | PS | Ataque | Habilidad | Lo hace la app | Lo hace la mesa |
|---|---|---|---|---|---|---|
| 08 | **Manectric** (jefe) | 2700 | **Onda Trueno** 40: Lanza 1 moneda. Si sale cara, el Pokémon Defensor pasa a estar Paralizado. · **Colmillo Rayo** 80: Durante el próximo turno de los jugadores, el Pokémon Defensor no puede atacar. · **Trueno** 160 | — | Onda Trueno: tira la moneda y apunta la parálisis. Colmillo Rayo: apunta que el Defensor no puede atacar. Los dos se recuerdan en el turno del jugador. | El daño y las Condiciones Especiales de sus Pokémon. |
| 09 | Plusle (Daño) | 80 | **Chispazo** 30: Este ataque también hace 30 puntos de daño a los Pokémon Activos de los jugadores adyacentes al jugador objetivo. | — | Dice quiénes son los jugadores adyacentes. | 30 al objetivo y 30 al Activo de cada adyacente. |
| 10 | Minun (Tanque) | 90 | **Bola Voltio** 10 | **Moflete Estático**: Mientras Minun está en juego, cada vez que un Pokémon Aliado queda Fuera de Combate por el daño de un ataque de los jugadores, el Pokémon Atacante pasa a estar Paralizado. | Cuando un ataque deja fuera de combate a un aliado, apunta la parálisis del atacante y se la recuerda en su siguiente turno. | Poner Paralizado al Pokémon Atacante. |
| 11 | Oddish (Curandero) | 60 | — | **Drenadoras**: Cuando este Pokémon entra en juego y durante cada Chequeo Pokémon, pon 1 contador de daño en cada Pokémon Activo de los jugadores. Cura 10 puntos de daño al jefe por cada contador puesto. | Cura al jefe 10 por cada jugador en pie, al entrar y en cada chequeo, y pide poner los contadores. | Poner 1 contador en cada Pokémon Activo. |
| 12 | Gulpin (Control) | 100 | **Tóxico**: El Pokémon Defensor pasa a estar Envenenado. | — | Tóxico es su ataque (sin daño): lo usa al entrar y en cada turno del jefe, y la app dice a quién. | Poner Envenenado al Pokémon Defensor. |
| 13 | Poochyena (Potenciador) | 70 | — | **Aullido**: Mientras este Pokémon esté en juego, los ataques del jefe hacen 20 puntos de daño más. | Suma 20 a cada ataque del jefe. | Nada. |
| 14 | Zigzagoon (Debilitador) | 50 | — | **Gruñido**: Mientras este Pokémon esté en juego, los ataques de los jugadores hacen 10 puntos de daño menos al jefe y a los aliados. | Resta 10 a cada ataque que apunten los jugadores y lo avisa en el turno. | Nada: se apunta el daño de la carta. |

## Kingdra — Nv3, Islas Remolino

| Nº | Carta | PS | Ataque | Habilidad | Lo hace la app | Lo hace la mesa |
|---|---|---|---|---|---|---|
| 15 | **Kingdra** (jefe) | 3800 | **Ciclón** 60: El daño de este ataque no se ve afectado por ningún efecto en el Pokémon Defensor. · **Pulso Dragón** 100 · **Hidrobomba** 200 | — | Ciclón: recuerda que el daño ignora los efectos del Defensor. | El daño a los Pokémon. |
| 16 | Krabby (Daño) | 70 | **Martillazo** 30+: Lanza 2 monedas. Si al menos una sale cara, este ataque hace 50 puntos de daño más. | — | Tira las 2 monedas y suma 50 si sale alguna cara. | El daño al Pokémon. |
| 17 | Seel (Tanque) | 100 | — | **Velo Sagrado**: Mientras este Pokémon esté en juego, el jefe y los aliados no pueden pasar a estar afectados por Condiciones Especiales. Cuando este Pokémon entra en juego, les quita todas las Condiciones Especiales. | Quita el veneno y la quemadura del jefe al entrar y rechaza los nuevos mientras siga en juego. | No aplicar Condiciones Especiales al jefe ni a los aliados. |
| 18 | Golbat (Curandero) | 80 | **Chupavidas** 30: Cura 30 puntos de daño al jefe y a los aliados. | **Allanamiento**: El daño de los ataques de este Pokémon no se ve afectado por ningún efecto en el Pokémon Defensor. | Cura 30 al jefe y a los aliados cada vez que ataca; recuerda que el daño ignora efectos. | El daño al Pokémon, sin aplicar efectos del Defensor. |
| 19 | Tentacruel (Control) | 90 | — | **Constricción**: Mientras este Pokémon esté en juego, los jugadores no pueden cambiar su Pokémon Activo por uno de la Banca. | Lo recuerda en el turno de cada jugador. | No cambiar el Activo por uno de la Banca. |
| 20 | Horsea (Potenciador) | 60 | — | **Agilidad**: Mientras este Pokémon esté en juego, el primer ataque del jefe en cada turno del jefe hace 30 puntos de daño más. | Suma 30 al primer ataque del jefe de cada turno. | Nada. |
| 21 | Magikarp (Debilitador) | 50 | **Salpicadura** 10 | **Bote**: Cada vez que este Pokémon vaya a recibir daño de un ataque, el jugador atacante lanza 1 moneda. Si sale cara, se evita todo ese daño. | Tira la moneda de Bote por el jugador atacante: con cara, el ataque no le hace daño (el turno se gasta igual). | El daño de Salpicadura. |

## Arceus — Nv4, Sala Origen

| Nº | Carta | PS | Ataque | Habilidad | Lo hace la app | Lo hace la mesa |
|---|---|---|---|---|---|---|
| 22 | **Arceus** (jefe) | 3900 | **Danza Espada** 40+: Este ataque hace 30 puntos de daño más por cada ataque que este Pokémon haya usado antes en este turno. · **Castigo** 100+: Si el Pokémon Defensor no tiene contadores de daño, este ataque hace 50 puntos de daño más. · **Sentencia** 240: Pon 1 contador de daño en cada uno de los demás Pokémon en juego. | — | Danza Espada: calcula el daño según los ataques previos del turno. Castigo: pregunta si el Defensor no tiene contadores y suma 50. Sentencia: pone 1 contador a cada aliado. | Sentencia: 1 contador en cada Pokémon de los jugadores (Activos y Banca). |
| 23 | Medicham (Daño) | 90 | **Puño Dinámico** 70+: El Pokémon Defensor pasa a estar Confundido. Si el Pokémon Defensor ya tenía una Condición Especial, este ataque hace 70 puntos de daño más. | **Energía Pura**: El daño de los ataques de este Pokémon no se ve afectado por ningún efecto en el Pokémon Defensor. | Pregunta si el Defensor ya tenía una Condición Especial y suma 70; recuerda que el daño ignora efectos. | Poner Confundido al Defensor. |
| 24 | Bronzong (Tanque) | 100 | — | **Bloqueo**: Mientras este Pokémon esté en juego, los jugadores solo pueden atacar a este Pokémon o pasar el turno, y los ataques de los jugadores le hacen 100 puntos de daño menos. | Solo deja atacar a Bronzong (o pasar con 0) y resta 100 a lo que reciba. | Nada: se apunta el daño de la carta. |
| 25 | Chingling (Curandero) | 50 | — | **Deseo**: Cuando este Pokémon entra en juego, lanza 10 monedas. Cura 100 puntos de daño al jefe por cada cara. Luego, cada aliado y cada Pokémon de los jugadores lanza 1 moneda: si sale cara, cura 100 puntos de daño a ese Pokémon. | Tira las 10 monedas del jefe y una por aliado, y cura. | Una moneda por cada Pokémon de los jugadores: con cara, cura 100. |
| 26 | Nosepass (Control) | 60 | — | **Fijar Blanco**: Cuando este Pokémon entra en juego, la primera moneda que lance cada jugador a partir de ese momento es cruz. Aunque este Pokémon quede Fuera de Combate, el efecto sigue aplicado. | Lo avisa al entrar y lo sigue recordando el resto de la partida (en el turno de cada jugador y cuando pide una moneda). | La primera moneda de cada jugador es cruz. |
| 27 | Solrock (Potenciador) | 70 | **Envite Ígneo** 10+: Este ataque hace 10 puntos de daño más por cada vez que este Pokémon lo haya usado. Cada vez que lo usa, este Pokémon gana 10 HP máximos. | — | Sube 10 el daño y 10 los PS de Solrock en cada uso. | El daño al Pokémon. |
| 28 | Lunatone (Debilitador) | 80 | **Fuerza Lunar** 10: El rival lanza una moneda: si sale cruz, el siguiente ataque de ese Pokémon hace 30 puntos de daño menos. | — | Pregunta el resultado de la moneda del rival; con cruz, resta 30 a su siguiente ataque. | Lanzar la moneda. |

## Cuándo salen los avisos

- **Al entrar un aliado**: aviso con botón «Hecho» si la mesa tiene que hacer algo (Drenadoras, Fijar Blanco, las monedas de Deseo). Si el aliado tiene ataque, lo usa al entrar.
- **En el turno de cada jugador**: lo que la app descuenta de su ataque, los efectos del jefe que le siguen afectando (no puede retirarse, no puede atacar, Paralizado) y las reglas de los aliados en juego (Rencor, Constricción, Velo Sagrado, Fijar Blanco).
- **Al cerrar el turno del jefe**, por este orden: atacan los aliados, la mesa hace el Chequeo Pokémon (Tormenta de Arena, Drenadoras) y se termina el turno. Los KO que salgan de esos pasos se marcan antes de terminar el turno, para que cuenten como KO del turno del jefe.
- **Cuando cae un aliado** por un ataque de los jugadores: el aviso de Moflete Estático.

## Mantener este documento

Las columnas de datos salen del catálogo; las dos últimas están escritas a mano. `app/test/catalogo_test.dart` comprueba que las 28 cartas están en el catálogo con su número y sus PS. Si cambia una carta, cambia el JSON, esta tabla y la sección 4 de `docs/playtests/GUION.md`.
