# D-14 · Efectos en los ataques del jefe

Estado: **motor, contrato v5, catálogo y app hechos** (2026-11-07); simulador y recalibrado de HP pendientes. Issue #102. Los efectos de cada jefe se cierran uno a uno con Ayme; aquí están los 4 jefes iniciales.

## Motivación

Los jefes oficiales de Incursión Max llevan efectos en sus ataques (Dredanaw: el Defensor no puede atacar o retirarse el próximo turno; Pikachu: daño a cada Activo, autodaño). Los nuestros eran daño plano. Los ataques de Onix, Manectric y Kingdra coinciden con los de Dredanaw VMAX (30/60/120, 40/80/160, 60/100/200), pero sin sus efectos.

## Decisiones

1. **Cada ataque del catálogo puede llevar un `efecto` opcional**: `{ tipo, valor?, duracion? }`. Sin `efecto`, es daño plano.
2. **`AtaqueJefe` registra el efecto aplicado** (contrato **v5**, migración v4 → v5, servidor y TCGMasters-server; ver `docs/DEPENDENCIAS.md`).
3. **Dos clases de efecto**, como en D-13:
   - `programa`: lo aplica la app. Hoy, solo el autodaño del jefe (`autodano`).
   - `jugador`: lo aplican los jugadores en la mesa; la app lo muestra y lo recuerda mientras dura (`sin_retirada`, `sin_ataque`, y otros por definir).
4. **Duración** en turnos de los jugadores. «El próximo turno de los jugadores» es `duracion: 1`: el aviso se muestra hasta que termina ese turno.
5. **Autodaño (`autodano`)**: baja el HP del jefe en el momento del ataque. No se atribuye a ningún jugador (igual que los estados, D-12), pero cuenta para el daño total del equipo. Puede cruzar umbrales de invocación y, si deja al jefe a 0 HP, la partida termina en victoria.
6. **Orden del autodaño**: se aplica **después** del daño al jugador. Si cruza un umbral de invocación, el aliado entra y **ataca en ese momento** (de entrada, como cualquier aliado). Así, tras su propio autodaño, el jefe puede curarse con la entrada de un aliado de cura, o el aliado puede rematar al jugador que acaba de recibir el ataque.
7. **Combinación de efectos activos**: los efectos de **tipos distintos conviven** (la app muestra un aviso por tipo). Si se repite un tipo que ya está activo, **se renueva** su duración: sigue habiendo un solo aviso.
8. **Quién lanza la moneda**: si el efecto lo usa el jefe o uno de sus aliados, **la app lanza la moneda**, la registra en el evento (cara o cruz) y muestra el resultado (en Onda trueno: «cara, el Defensor queda paralizado» o «cruz, no pasa nada»). Las monedas de las cartas de los jugadores las lanzan ellos en la mesa, porque la app no gestiona sus ataques.

## Criterio de nivel de los jefes

Nv1 Pokémon Básicos (Onix), Nv2 Pokémon de Fase 1 que no evolucionan más (Manectric), Nv3 Pokémon de Fase 2 (Kingdra), Nv4 Pokémon Míticos y Legendarios (Arceus). Está también en el GDD (§2).

## Tipos de efecto (primera lista)

En el contrato v5 los tipos van en camelCase: `sinRetirada`, `sinAtaque`, `paralizarDefensor` (antes `estado_defensor`: la parálisis es el único estado y la moneda es un campo aparte), `ignoraEfectos`, `danoExtraSi`, `danoPorAtaquePrevio`, `contadorATodos`, `autodano`. Detalle en `contrato/README.md`.

| Tipo | Clase | Valor | Duración | Texto en la app |
|---|---|---|---|---|
| `sin_retirada` | jugador | — | turnos | El Pokémon Defensor no puede retirarse |
| `sin_ataque` | jugador | — | turnos | El Pokémon Defensor no puede atacar |
| `ignora_efectos` | jugador | — | — | El daño de este ataque no se ve afectado por ningún efecto del Pokémon activo rival |
| `dano_por_ataque_previo` | programa | HP por ataque | — | Este ataque hace N puntos de daño más por cada ataque que el jefe haya usado antes en este turno |
| `dano_extra_si` | jugador | HP, condición | — | Texto de la carta (p. ej. «si el Defensor no tiene contadores de daño, +50») |
| `contador_a_todos` | programa + jugador | contadores | — | Pon N contador(es) de daño sobre todos los Pokémon en juego (menos el jefe) |
| `autodano` | programa | HP | — | El jefe se hace N puntos de daño |
| `autodanoSiKo` | mesa | HP | jugador | Rebote (T-59): si el Defensor queda KO, el jefe se hace N puntos de daño, atribuidos al defensor. La app pregunta tras registrar el ataque y registra `pokemonKo` + `danoDeEfecto` |
| `estado_defensor` | jugador | estado (`paralizado`), `moneda` opcional | — | Lanza una moneda; si sale cara, el Pokémon Defensor pasa a estar paralizado |

Se irán añadiendo (daño a cada Activo, daño a la Banca, moneda) según los jefes.

## Onix (Nv1)

| Ataque | Nombre | Daño | Efecto |
|---|---|---|---|
| 1 | Trampa Rocas | 30 | `sin_retirada`, `duracion: 1` |
| 2 | Lanzarrocas | 60 | Ninguno |
| 3 | Doble filo | 120 | `autodano`, `valor: 30` |

## Manectric (Nv2)

| Ataque | Nombre | Daño | Efecto |
|---|---|---|---|
| 1 | Onda trueno | 40 | `estado_defensor`: `paralizado`, con `moneda` (cara = paralizado) |
| 2 | Colmillo rayo | 80 | `sin_ataque`, `duracion: 1` |
| 3 | Trueno | 160 | Ninguno |

## Kingdra (Nv3)

| Ataque | Nombre | Daño | Efecto |
|---|---|---|---|
| 1 | Ciclón | 60 | `ignora_efectos` |
| 2 | Pulso Dragón | 100 | Ninguno |
| 3 | Hidrobomba | 200 | Ninguno (daño plano; se descartó la restricción de no repetirla) |

## Arceus (Nv4)

| Ataque | Nombre | Daño | Efecto |
|---|---|---|---|
| 1 | Danza Espada | 40+ | `dano_por_ataque_previo`, `valor: 30`. Texto: «Este ataque hace 30 puntos de daño más por cada ataque que Arceus haya usado antes en este turno.» |
| 2 | Castigo | 100+ | `dano_extra_si` (condición: el Defensor no tiene contadores de daño, +50). Solo texto: los jugadores aplican el +50 en la mesa |
| 3 | Sentencia | 240 | `contador_a_todos`, `valor: 1` (10 de daño) |

- **Danza Espada**: la app conoce los ataques anteriores del turno (los registra), así que calcula ella el daño: 40, 70, 100, etc.
- **Sentencia**: los jugadores ponen el contador en sus Pokémon en la mesa. **Los aliados del jefe también lo reciben**: la app baja 10 HP a cada aliado vivo (`programa`) y, si alguno llega a 0, queda derrotado. Ese daño no se atribuye a ningún jugador.

## Pendiente

- Idea aparte, fuera de esta tarea: un botón opcional «Lanzar moneda» como utilidad para los jugadores.
- Después: simulador (modelar los efectos) y recalibrado de HP.
