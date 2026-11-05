# D-04 · Slots de aliados

Estado: decidido (2026-11-05). Issue #16.

## 1. Slots

- Hay **un slot por jugador**. Con 4 jugadores, 4 slots; con 3, 3 slots; con 2, 2 slots.
- Cada slot admite como máximo **1 aliado**.
- El jefe invoca un aliado solo en un **slot de un jugador activo (no eliminado) que no tenga ya un aliado**. Lo elige la mesa entre los slots libres. Si no hay ninguno libre, la invocación no tiene efecto.

## 2. Bloqueo

Mientras un jugador tiene un aliado vivo en su slot, ese jugador debe debilitarlo antes de poder dañar al jefe (regla del GDD sin cambios). El bloqueo solo afecta al jugador dueño del slot; el resto de jugadores puede seguir dañando al jefe con normalidad.

## 3. Objetivo del ataque del aliado

El aliado no ataca a su dueño por defecto: **cada vez que ataca, se tira un dado entre los jugadores activos y ataca al que salga**.

| Jugadores activos | Tirada |
|---|---|
| 2 | moneda |
| 3 | dado de 3 caras |
| 4 | dado de 4 caras |

El jugador de la mesa introduce a mano el resultado y el daño, igual que con el jefe. El aliado hace su único ataque; el asistente no computa su habilidad (GDD §6.2).

## 4. Jugador eliminado

Cuando un jugador queda eliminado:

- Deja de contar en la tirada del objetivo y en el número de slots donde se pueden invocar nuevos aliados.
- Si tenía un aliado vivo en su slot, **el aliado sigue vivo y sigue atacando** (objetivo al azar entre los activos), pero **ya no bloquea a nadie**, porque su dueño no puede dañar al jefe.
- Cualquier jugador activo puede, si quiere, atacar a ese aliado en lugar de al jefe, para eliminar su amenaza. No es obligatorio.

## 5. Casos límite

- **Un solo jugador activo** (los demás eliminados): no hay tirada; el aliado ataca a ese jugador.
- **El aliado cae mientras su dueño está eliminado**: el slot queda libre, pero como el jugador está eliminado no se puede invocar ahí.
- **Todos los slots activos ocupados**: la invocación no tiene efecto.

## 6. Cambios en otros documentos

- `incursiones_gdd.md` → v0.10: turno del jefe (invocación y objetivo del aliado), §6.2 y glosario.
- `docs/D-01-setup.md`: la referencia a D-04 apunta a este documento.
