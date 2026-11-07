# D-14 · Efectos en los ataques del jefe

Estado: **borrador** (2026-11-07). Issue #102. Los efectos de cada jefe se cierran uno a uno con Ayme; aquí solo está Onix.

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

## Tipos de efecto (primera lista)

| Tipo | Clase | Valor | Duración | Texto en la app |
|---|---|---|---|---|
| `sin_retirada` | jugador | — | turnos | El Pokémon Defensor no puede retirarse |
| `sin_ataque` | jugador | — | turnos | El Pokémon Defensor no puede atacar |
| `autodano` | programa | HP | — | El jefe se hace N puntos de daño |

Se irán añadiendo (daño a cada Activo, daño a la Banca, moneda) según los jefes.

## Onix (Nv1)

| Ataque | Nombre | Daño | Efecto |
|---|---|---|---|
| 1 | Trampa Rocas | 30 | `sin_retirada`, `duracion: 1` |
| 2 | Lanzarrocas | 60 | Ninguno |
| 3 | Doble filo | 120 | `autodano`, `valor: 30` |

## Pendiente

- Cerrar los efectos de Manectric, Kingdra y Arceus.
- Pregunta abierta: cómo se combinan varios efectos activos a la vez (distintos tipos, o el mismo tipo repetido).
- Después: motor y contrato v5, catálogo y app, simulador y recalibrado de HP.
