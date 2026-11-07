# D-14 · Efectos en los ataques del jefe

Estado: **borrador** (2026-11-07). Issue #102. Los efectos de cada jefe se cierran uno a uno con Ayme; aquí están Onix, Manectric y Kingdra (salvo Hidrobomba).

## Motivación

Los jefes oficiales de Incursión Max llevan efectos en sus ataques (Dredanaw: el Defensor no puede atacar o retirarse el próximo turno; Pikachu: daño a cada Activo, autodaño). Los nuestros eran daño plano. Los ataques de Onix, Manectric y Kingdra coinciden con los de Dredanaw VMAX (30/60/120, 40/80/160, 60/100/200), pero sin sus efectos.

## Decisiones

1. **Cada ataque del catálogo puede llevar un `efecto` opcional**: `{ tipo, valor?, duracion? }`. Sin `efecto`, es daño plano.
2. **`AtaqueJefe` registra el efecto aplicado** (contrato **v5**, migración v4 → v5, servidor y deck-tracker-server; ver `docs/DEPENDENCIAS.md`).
3. **Dos clases de efecto**, como en D-13:
   - `programa`: lo aplica la app. Hoy, solo el autodaño del jefe (`autodano`).
   - `jugador`: lo aplican los jugadores en la mesa; la app lo muestra y lo recuerda mientras dura (`sin_retirada`, `sin_ataque`, y otros por definir).
4. **Duración** en turnos de los jugadores. «El próximo turno de los jugadores» es `duracion: 1`: el aviso se muestra hasta que termina ese turno.
5. **Autodaño (`autodano`)**: baja el HP del jefe en el momento del ataque. No se atribuye a ningún jugador (igual que los estados, D-12), pero cuenta para el daño total del equipo. Puede cruzar umbrales de invocación y, si deja al jefe a 0 HP, la partida termina en victoria.
6. **Orden del autodaño**: se aplica **después** del daño al jugador. Si cruza un umbral de invocación, el aliado entra y **ataca en ese momento** (de entrada, como cualquier aliado). Así, tras su propio autodaño, el jefe puede curarse con la entrada de un aliado de cura, o el aliado puede rematar al jugador que acaba de recibir el ataque.
7. **Combinación de efectos activos**: los efectos de **tipos distintos conviven** (la app muestra un aviso por tipo). Si se repite un tipo que ya está activo, **se renueva** su duración: sigue habiendo un solo aviso.
8. **Quién lanza la moneda**: si el efecto lo usa el jefe o uno de sus aliados, **la app lanza la moneda**, la registra en el evento (cara o cruz) y muestra el resultado (en Onda trueno: «cara, el Defensor queda paralizado» o «cruz, no pasa nada»). Las monedas de las cartas de los jugadores las lanzan ellos en la mesa, porque la app no gestiona sus ataques.

## Tipos de efecto (primera lista)

| Tipo | Clase | Valor | Duración | Texto en la app |
|---|---|---|---|---|
| `sin_retirada` | jugador | — | turnos | El Pokémon Defensor no puede retirarse |
| `sin_ataque` | jugador | — | turnos | El Pokémon Defensor no puede atacar |
| `ignora_efectos` | jugador | — | — | El daño de este ataque no se ve afectado por ningún efecto del Pokémon activo rival |
| `autodano` | programa | HP | — | El jefe se hace N puntos de daño |
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
| 3 | Hidrobomba | 200 | **Por replantear** (la idea «no usar Hidrobomba 2 veces seguidas en el mismo turno» queda en revisión) |

## Pendiente

- Cerrar el efecto de Hidrobomba (Kingdra) y los de Arceus.
- Idea aparte, fuera de esta tarea: un botón opcional «Lanzar moneda» como utilidad para los jugadores.
- Después: motor y contrato v5, catálogo y app, simulador y recalibrado de HP.
