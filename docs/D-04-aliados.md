# D-04 · Slots de aliados

Estado: decidido (2026-11-05). Issue #16. Invocación y exceso de daño: 2026-11-06, issue #31.

## 1. Slots

- Hay **un slot por jugador**. Con 4 jugadores, 4 slots; con 3, 3 slots; con 2, 2 slots.
- Cada slot admite como máximo **1 aliado**.
- Un aliado solo se coloca en el **slot de un jugador activo (no eliminado) que no tenga ya un aliado**. Lo elige la mesa entre los slots libres. Si no hay ninguno libre, no hay invocación (y no se tira el dado de §7).

## 2. Bloqueo y ayuda entre jugadores

Mientras un jugador tiene un aliado vivo en su slot, ese jugador debe debilitarlo antes de poder dañar al jefe (regla del GDD). El resto de jugadores puede seguir dañando al jefe con normalidad.

**Cualquier jugador activo puede atacar a cualquier aliado**, no solo al de su slot. Así el equipo puede colaborar para quitar cuanto antes los aliados que molestan a un compañero. Atacar a un aliado es opcional y sustituye al ataque contra el jefe en ese turno.

## 3. Objetivo del ataque del aliado

El aliado no ataca a su dueño por defecto: **cada vez que ataca, se tira un dado entre los jugadores activos y ataca al que salga**.

| Jugadores activos | Tirada |
|---|---|
| 2 | moneda |
| 3 | dado de 3 caras |
| 4 | dado de 4 caras |

El jugador de la mesa introduce a mano el resultado y el daño, igual que con el jefe. El aliado hace su único ataque; el asistente no computa su habilidad (GDD §4.4).

## 4. Jugador eliminado

Cuando un jugador queda eliminado:

- Deja de contar en la tirada del objetivo y como posible slot donde invocar nuevos aliados.
- Si tenía un aliado vivo en su slot, **el aliado sigue vivo y sigue atacando** (objetivo al azar entre los activos). Ya no bloquea a nadie, porque su dueño no puede dañar al jefe, pero los jugadores activos pueden atacarlo para eliminar su amenaza (regla de §2).

## 5. Casos límite

- **Un solo jugador activo** (los demás eliminados): no hay tirada; el aliado ataca a ese jugador.
- **El aliado cae mientras su dueño está eliminado**: el slot queda libre, pero como el jugador está eliminado no se puede invocar ahí.
- **Todos los slots activos ocupados**: la invocación no tiene efecto.

## 6. Exceso de daño (D-07)

Atacar a un aliado sustituye el ataque contra el jefe. Si el daño supera la vida que le queda al aliado, **el exceso se pierde**: no pasa al jefe ni a otro aliado. El daño hecho a aliados no cuenta para los puntos (D-10).

## 7. Cómo y cuándo se invoca un aliado

Los 7 jefes tienen 3 ataques. Una carta de ataque con texto «invoca un aliado» fallaría si el jefe nunca la saca, y los jefes sin invocación dejarían la mecánica sin usar, así que **la invocación no depende del texto de las cartas**.

1. **Quién puede invocar.** Cada jefe del catálogo declara si invoca y con qué fuerza: un **umbral de invocación** de 0 a 3. Con 0 el jefe nunca invoca. No todos los jefes tienen que invocar.
2. **Cuándo.** Al **final del turno del jefe**, después de que el jefe y los aliados vivos hayan atacado: si el jefe puede invocar y hay al menos un slot libre (§1), se tira **un d6**. Si sale un número **menor o igual al umbral**, se invoca un aliado. Umbral 1 = 17 %, 2 = 33 %, 3 = 50 % por turno.
3. **Qué aliado.** Cada jefe tiene su **lista de aliados posibles**. La mesa elige uno al azar de esa lista (dado, baraja o por turnos), y lo coloca en el slot elegido según §1.
4. **Límite.** Como máximo **un aliado por turno del jefe**.
5. **El aliado recién invocado no ataca** hasta el turno siguiente del jefe (ya ocurre porque se invoca al final del turno).
6. **Cómo se registra.** El asistente guarda el resultado del dado, el slot y el nombre del aliado, y su vida; la mesa introduce a mano los resultados físicos, como en el resto del juego.

### Estadísticas orientativas de los aliados

Son cartas planas con **poca vida y un único ataque de poco daño**, pensadas para molestar y no para dar miedo. Referencia para el catálogo (T-13) y los playtests (T-17), todavía sin calibrar:

- Vida: entre el 5 % y el 10 % de la vida del jefe.
- Daño de su ataque: entre el 10 % y el 25 % del ataque más débil del jefe.

Valores provisionales (umbral por jefe, d6, límites de vida y daño): se ajustan en T-17.

## 8. Cambios en otros documentos

- `incursiones_gdd.md` → v0.10: turno del jefe (invocación y objetivo del aliado), §6.2 y glosario.
- `incursiones_gdd.md` → v1.1: invocación por dado al final del turno del jefe, exceso de daño y valores provisionales.
- `docs/D-01-setup.md`: la referencia a D-04 apunta a este documento.
