# D-05 · Carta de ánimo, KO y promoción desde la banca

Estado: decidido (2026-11-05). Issue #18.

## 1. Qué es la carta de ánimo

El jugador cuyo Pokémon activo cae KO (y al que le queda otro Pokémon) **actúa primero en la ronda siguiente y roba una carta de ánimo (Cheer)**.

La base son las **5 cartas oficiales de Cheer**, que se resuelven en la mesa (el asistente no computa su efecto, solo puede registrar cuál salió):

1. Un Pokémon a elección hace doble daño este turno.
2. Cura 80 de daño a cada Pokémon de los jugadores.
3. Cura todo el daño de 1 Pokémon.
4. El jefe no puede jugar más de una carta el próximo turno.
5. Los ataques de todos los Pokémon de los jugadores hacen 50 más de daño este turno.

El sistema está abierto: según se desarrolle el juego se podrán añadir cartas y mecánicas nuevas.

Pendiente de playtest (T-17): el simulador no modela estos efectos (las curas y el +50 hacen la partida algo más fácil de lo calibrado), y se adopta de forma provisional el resto de la regla oficial (una carta por KO, máximo 3 cartas distintas por partida).

## 2. Pokémon KO: no revive

Un Pokémon que cae KO queda fuera de la partida. No se revive al final de la ronda, a diferencia del juego oficial: la carta de ánimo no revive. Es lo que asume la calibración del simulador (D-03): se pierde cuando caen todos los Pokémon de todos los jugadores.

## 3. Promoción desde la banca

Cada jugador lleva 2 Pokémon (1 activo + 1 banca, D-01). Cuando cae el activo:

- Si el jugador tiene Pokémon en la banca, **ese Pokémon pasa a ser el activo automáticamente**. No hay elección, porque solo hay uno.
- Si no le queda ninguno, el jugador queda **eliminado** y no recibe carta de ánimo.

Un jugador con un solo Pokémon vivo no tiene banca: si cae, queda eliminado.

## 4. Orden de turno

Cada ronda actúa primero cualquier jugador cuyo Pokémon activo cayó KO desde su último turno (y que sigue en juego), y después el resto por orden de asiento.

- **Varios KO a la vez** (por ejemplo, un ataque del jefe «a todos»): los jugadores con prioridad actúan entre sí **por orden de asiento** (J1, J2, J3, J4), no por el orden en que cayeron.
- Un jugador solo gana la prioridad una vez por KO: si cae su Pokémon y el nuevo activo vuelve a caer en la misma ronda, no gana una segunda prioridad.
- Un jugador eliminado no actúa ni gana prioridad.

## 5. Casos límite

- **Ataque «a todos» que deja a un jugador sin ningún Pokémon**: el jugador queda eliminado y no tiene prioridad.
- **El aliado o el jefe manda el Pokémon activo a la banca** (habilidad, GDD §4.4): se resuelve en la mesa, sin KO y sin carta de ánimo.
- **Daño de Cheer**: las cartas de ánimo no hacen daño por sí mismas. El daño extra de «doble daño» y «+50» sale de los ataques del jugador, así que ya cuenta para él en D-10.

## 6. Cambios en otros documentos

- `incursiones_gdd.md` → v0.11: orden de turno, glosario y §7 (sin pregunta de revivir).
- `docs/D-03-sistema-de-poder.md` §3.4: el GDD no revive (decisión cerrada).
- `docs/D-10-sistema-de-puntos.md`: el daño extra de las cartas de ánimo cuenta para el jugador que ataca.
