# D-08 · Orden de comprobación del fin de partida con daño fuera de turno

Estado: **cerrada** en lo que sigue hasta «Propuesta abierta». Issue #45.

## Problema

La victoria y la derrota se comprueban tras cada daño al jefe y tras cada KO, pero hay daño fuera del turno normal: el retroceso de un ataque y los estados alterados (veneno, quemadura). Un mismo efecto puede dejar al jefe a 0 HP y eliminar al último Pokémon de la mesa. Hay que fijar qué cuenta.

## Decisiones

1. **Si el jefe cae, gana la victoria.** El daño al jefe se resuelve antes que el retroceso o cualquier efecto sobre los propios Pokémon. Si el jefe llega a 0 HP, la partida termina en victoria y el KO que viniera después ya no cuenta. Es el mismo orden del juego de cartas (primero el defensor, luego el atacante).
2. **El fin de partida se evalúa tras cada evento registrado**, como hasta ahora. No hay un «cierre de chequeo» que agrupe efectos.
3. **El daño al jefe fuera de turno** (veneno o quemadura que han puesto los jugadores) se registra como daño del jugador que lo causó, con el evento de turno que ya existe. Cuenta para sus puntos. No hay evento nuevo.

## Cómo lo garantiza el motor

- Registrar un evento pone la partida en `terminada` en cuanto se cumple una condición, y a partir de ahí **cualquier evento se rechaza** con `ReglaIncumplida`. La primera condición que se registra es la única que cuenta: no existe una partida que acabe a la vez en victoria y derrota.
- El motor no puede saber qué pasó «a la vez» en la mesa. El orden lo marca el orden en que se registran los eventos, y la regla para la mesa es: **primero se registra el daño al jefe, después los KO de los jugadores.** El asistente puede recordarlo en la pantalla de registro.
- Con esa regla, retroceso que mata al último Pokémon al mismo tiempo que el jefe cae → se registra el daño (victoria) y el KO ya no se acepta.

## Tabla de resolución

| Situación en la mesa | Se registra primero | Resultado |
|---|---|---|
| Ataque deja al jefe a 0 y el retroceso elimina al último Pokémon | Daño al jefe | Victoria |
| Veneno o quemadura dejan al jefe a 0 y otro efecto elimina al último Pokémon | Daño al jefe | Victoria |
| El último Pokémon cae y el jefe sigue con HP | KO | Derrota |
| El jefe cae después de que el último Pokémon ya haya caído | (ya terminó) | Derrota |

## Propuesta abierta: veneno y quemadura como estado

Comentario de Ayme durante esta decisión, pendiente de confirmar antes de llevarlo al GDD (hoy §4.3 dice que el asistente no modela los estados):

- Los estados se llevarían en el asistente como un estado del Pokémon.
- La **quemadura** tira la moneda al final del turno, como en el juego real.
- El **veneno** es permanente y se contabiliza de forma automática.

Falta decidir si esto vale solo para el jefe o también para los Pokémon de los jugadores, quién tira la moneda en el asistente y cómo se atribuye el daño de un estado a un jugador para los puntos. Cuando se confirme, se abre como decisión aparte (propuesta: D-12) y se implementa en el motor.
