# Modo campaña: primer tramo y Brock con las reglas de master (#409)

Fecha: 2026-11-23 · Herramienta nueva: `sim/bin/sim_campana_partida.dart` · Datos: `balance/informes/campana_partida_2026-11-23/`

Sustituye al informe #383 (Brock 0–7 %), que se midió antes de la captura por probabilidad, el dinero, la reserva de XP y la evolución por medalla.

## Resumen

1. **Brock ya no es el problema si el jugador vuelve a la tienda tras Ruta 1.** Con Ruta 1 capturando y 5 Pokéballs, Brock se gana a la primera el **76 % (Bulbasaur), 98 % (Charmander) y 98 % (Squirtle)**, entre los que llegan a él. El tramo entero sin perder ningún combate sale en 51 / 72 / 47 %. Con reintentos (gratis salvo tiempo) el 89 / 95 / 83 % acaba ganando a Brock.
2. **El segundo muro es Pikachu jefe**, sobre todo para Squirtle: 88 / 96 / **65 %** a la primera. Es la causa de casi todas las derrotas de Squirtle (250 de 1.500 recorridos se rinden ahí).
3. **El resultado depende de capturar en Ruta 1.** Sin capturas en Ruta 1 (política A, solo se compran Pokéballs y se llega con el inicial) Brock cae al **0 % (Bulbasaur y Squirtle) y 50 % (Charmander)**. Con Ruta 1 y 5 Pokéballs sube al 76–98 %. El número de cuerpos capturados importa más que cualquier otro parámetro: es el problema «cuerpos contra energía» (Brock pone 2 Pokémon y Onix quita 1 energía).
4. **Techo antes de Brock: 100 %** con 3 Pokémon (inicial + Spearow/Pikachu u otros). Con 2 Pokémon: 84 % sin evolución del inicial (Spearow + Mankey) y 100 % con evolución (Ivysaur/Wartortle + Spearow o Pikachu; Charmeleon solo 84 %). Con solo el inicial: 0 % (Squirtle evolucionado 13 %). El diseño es ganable: la dificultad está en el camino, no en el techo.
5. Palanca propuesta: ver más abajo. No hace falta tocar cartas.

## Reglas simuladas

- Capturas con Ball: 1 Ball por lanzamiento, probabilidad según categoría; Pikachu jefe captura asegurada (una vez).
- Dinero: 1.000 de salida; Cazabichos 200 ×2, Entrenador Joven 260, Brock 1.400. Antes de Brock hay 1.000 + 400 + 260 = 1.660 → **8 Balls** como máximo. Pokéball 200, Poción 300. La IA gasta en Ciudad Verde todo en Pokéballs (5); el barrido `bolas` (abajo) confirma que comprar menos nunca ayuda.
- Reserva común de XP: 10/20/30 por categoría; Metapod y Kakuna evolucionan a 50 XP; el inicial a 70 XP. Los iniciales evolucionan a 0 medallas.
- Curación: gratis en los centros; al perder se vuelve a la última cura con el equipo curado. `retroceder` permite volver a cualquier nodo visitado.
- IA en los dos bandos. Sin límite de turnos en el motor: los empates cuentan como derrota.
- Políticas: **A** = Ruta 1 sin Balls; **B** = Ruta 1 con captura, 0 Balls hasta la primera tienda y luego se vuelve atrás (la regla pedida); **C** = B más Ruta 22.

## Tasa de victoria por combate (a la primera, entre los que llegan), política B, sin evolución del inicial

| Combate | Bulbasaur | Charmander | Squirtle |
|---|---|---|---|
| Ruta 1: Pidgey | 100 % | 100 % | 100 % |
| Ruta 1: Rattata | 87,9 % | 100 % | 75,5 % |
| Ruta 2: Weedle / Caterpie | 100 % | 100 % | 100 % |
| Bosque Verde: Cazabichos 1 | 85,9 % | 99,8 % | 89,2 % |
| Bosque Verde: Cazabichos 2 | 86,2 % | 99,9 % | 91,5 % |
| Pikachu jefe | 87,8 % | 96,0 % | 65,2 % |
| Gimnasio: Entrenador Joven | 87,9 % | 76,4 % | 83,0 % |
| **Brock** | **76,6 %** | **97,9 %** | **98,0 %** |

(1.500 recorridos por inicial, semilla fija. «Llegan» por casilla en el CSV: ~97 % llegan al gimnasio con Bulbasaur y Charmander, 85 % con Squirtle.)

## Tramo entero, por política (sin evolución del inicial)

| Política | Inicial | Sin perder ningún combate | Acaba ganando a Brock (con reintentos) | Derrotas por recorrido |
|---|---|---|---|---|
| A (sin Balls en Ruta 1) | Bulbasaur | 0 % | 0 % | 84,6 |
| A | Charmander | 13,9 % | 49,1 % | 43,2 |
| A | Squirtle | 0 % | 0 % | 82,6 |
| **B** | Bulbasaur | 51,8 % | 89,3 % | 9,8 |
| **B** | Charmander | 72,2 % | 94,9 % | 5,1 |
| **B** | Squirtle | 48,7 % | 83,3 % | 15,1 |
| C (con Ruta 22) | Bulbasaur | 59,9 % | 86,7 % | 11,9 |
| C | Charmander | 73,9 % | 91,7 % | 7,9 |
| C | Squirtle | 61,6 % | 92,3 % | 7,8 |

Sin poder volver a curar (`--retroceder=no`) Brock cae a 22 / 0 / 14 % (B): el Bosque Verde y el gimnasio se encadenan sin curar y los Cazabichos 2 quedan en 3 / 80 / 0 %. **Curar volviendo al centro es una regla de la que depende el balance**; hay que dejarla clara en la app.

## Con evolución opcional del inicial (política B)

| Inicial | Brock a la primera | Tramo sin perder | Gana Brock con reintentos |
|---|---|---|---|
| Ivysaur | 100 % | 69,9 % | 99,7 % |
| Charmeleon | 94,9 % | 94,5 % | 94,9 % |
| Wartortle | 100 % | 52,5 % | 91,0 % |

Las fichas de fase 1 están en el PR abierto #438 pero sus efectos nuevos no están en el motor; el simulador usa los efectos existentes más cercanos, así que es un **suelo**. Charmeleon queda por debajo de los otros dos en Brock (Geodude y Onix no son débiles al fuego: es resistencia, no un fallo de la herramienta).

## Barrido de Pokéballs compradas (política B, 800 recorridos)

| Balls | Bulbasaur gana Brock | Charmander | Squirtle |
|---|---|---|---|
| 0–1 | 0 % | 0 % | 0 % |
| 2 | 0 % | 0 % | 0 % |
| 3 | 49,5 % | 52,4 % | 46,9 % |
| 4 | 77,6 % | 82,6 % | 72,8 % |
| 5 | 89,4 % | 95,0 % | 83,0 % |

Con menos de 5 Pokéballs el tramo cae bruscamente: cada Ball de menos son ~10 puntos. El dinero de 1.000 cubre justo 5 Balls; no hay margen para Pociones antes de Brock.

## Palancas para Brock (de menos a más coste para Ayme)

Brock en B ya supera el 75 % para Charmander y Squirtle y roza el 76 % con Bulbasaur, así que **no hace falta tocarlo** si se mantiene la regla de volver a la tienda. Pero si se quiere margen, o si el playtest muestra que la gente no captura en Ruta 1 (política A, Brock 0–50 %), estas son las palancas medidas (800 recorridos, retroceder = sí):

| Palanca | Coste para Ayme | Efecto en Brock (a la primera) |
|---|---|---|
| 0. Nada (base B) | — | 76 / 98 / 98 % |
| 1. JSON de rivales: Onix de 110 a **60 PS** | Editar `onix.json` (afecta a Onix jefe/otras zonas) | Política A: Bulbasaur y Charmander 100 %; política B: Bulbasaur 98,1 %, Squirtle 99,4 %; tramo entero B +6 puntos con reintentos |
| 2. JSON de rivales: Brock solo con Geodude | Editar `kanto.json` (líder con 1 Pokémon) | Política A: 100 % / 100 %; deja de ser un jefe de dos cuerpos |
| 3. Parámetros del simulador (energía +2/turno o inicial/max 12) | Cambio de motor, afecta a todos los combates | **Empeora**: Brock 0 % también para Charmander (la energía extra la aprovecha la IA rival) |
| 4. Curación extra | No medida: en B ya se cura gratis en centros; falta confirmar si hay centro entre Pikachu y Brock | — |
| 5. Daño de cartas impresas | Diseño (#438) | No medida; la fase 1 ya sube Brock a 94–100 % |

Recomendación: **no cambiar el JSON de Brock todavía**. Cambiar antes (a) que Ruta 1 permita capturar con la tienda cerca y (b) la dificultad de Pikachu jefe para Squirtle (65 %), que es el cuello de botella real. Si Ayme quiere ajustar algo en Pikachu, la palanca más barata es subir en su JSON el número de aliados que necesita o bajar sus PS; medirla con `--rival` es el siguiente paso.

## Qué se pide a otros departamentos

- **Diseño:** decidir si la regla «Ruta 1 permite capturar pero sin Balls, y luego se vuelve atrás» se explica en la app; sin ella el tramo es un 0–50 % para dos de los tres iniciales.
- **Programación:** el motor no tiene límite de turnos (los empates se cuentan como derrota en la simulación); conviene un tope con resultado definido. Y los efectos de las evoluciones del PR #438 para poder medir el techo real.
- **Arte/cartas:** nada por ahora.

## Limitaciones

- La IA de combate es determinista y simple; el reparto bimodal de Brock depende del Pokémon con que se sale. Un humano será mejor y peor a la vez.
- Evoluciones de fase 1 aproximadas (suelo).
- #384 (contraste con Serebii y Bulbapedia) **no se ha podido hacer** en esta sesión: la consulta web no fue aprobada. Pendiente.

## Reproducir

```
cd sim
dart run bin/sim_campana_partida.dart --modo=tramo --partidas=1500 --ruta1=si --retroceder=si
dart run bin/sim_campana_partida.dart --modo=bolas --partidas=800 --ruta1=si
dart run bin/sim_campana_partida.dart --modo=techo --fase1=si --partidas=1500
```

## Actualización 2026-11-24: tope de turnos (propuesta para Diseño) y duración del tramo

Pedido por Dirección: el tope va **solo en el simulador** (`--tope-turnos=N --al-tope=derrota|mas-ps`); el motor no se toca hasta que Diseño fije la regla del juego.

**Cuántos combates acaban así (1.000 recorridos por inicial, política B, retroceder = sí):**

| Dato | Valor |
|---|---|
| Combates jugados | 52.828 |
| Duración de los que terminan (turnos del motor) | mediana 12 · p95 19 · p99 26 · máximo 34 |
| Combates que no terminan (empate técnico) | **240 (0,5 %)** |
| En qué casillas | solo Bosque Verde: Cazabichos 1 (127) y Cazabichos 2 (113) |
| Política A (sin Balls en Ruta 1) | 612 de 227.034 (0,3 %), también solo en Cazabichos |

Son empates reales, no combates largos: con un tope de 60 turnos salen exactamente los mismos 240. Es el caso de Metapod/Kakuna (Fortaleza) contra un Pokémon sin daño suficiente. El combate natural más largo dura 34 turnos, así que un tope de **40 turnos** no cortaría ninguno que hoy termine.

**Qué debería pasar al llegar al tope (propuesta para Diseño, tres opciones):**

| Opción | Efecto medido |
|---|---|
| Cuenta como derrota (lo que hace hoy el simulador) | Es arbitrario: castiga al jugador por un empate que el rival también provoca |
| **Gana quien tenga más PS en pie** (el rival gana los empates) | De los 208 combates cortados, gana el jugador el 88 % (95 % en política A). El «tramo sin perder ningún combate» de Bulbasaur sube de 50,9 % a 56,3 %; el resto no cambia y Brock tampoco |
| Tablas: se repite el combate sin perder nada | No medido; no cambia el resultado del tramo, solo evita el bloqueo. Es la más fácil de explicar al jugador |

Recomendación de Calidad: **40 turnos y «gana quien tenga más PS en pie»**, o tablas si Diseño prefiere no decidir por PS. No hace falta tocar el motor para medirlo.

**Duración del primer tramo (D-21 §4.4, fase 0):** en el simulador, un recorrido completo juega unos **18 combates** (incluidos los repetidos tras perder) de unos 12 turnos cada uno. Es una referencia, no un tiempo real: la duración en minutos solo se mide jugando. En `docs/playtests/GUION_CAMPANA_TRAMO1.md` hay ahora una hoja para que Ayme apunte la suya (fase 0).
