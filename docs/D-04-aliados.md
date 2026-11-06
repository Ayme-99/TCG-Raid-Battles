# D-04 · Slots de aliados

Estado: decidido (2026-11-05). Issue #16. Invocación, entrada y exceso de daño: 2026-11-06, issue #31.

## 1. Slots

- Hay **un slot por jugador**. Con 4 jugadores, 4 slots; con 3, 3 slots; con 2, 2 slots.
- Cada slot admite como máximo **1 aliado**.
- Un aliado solo se coloca en el **slot de un jugador activo (no eliminado) que no tenga ya un aliado**. Lo elige la mesa entre los slots libres. Si no hay ninguno libre, no hay invocación y no se tira ningún dado (§7).

## 2. Bloqueo y ayuda entre jugadores

Mientras un jugador tiene un aliado vivo en su slot, ese jugador debe debilitarlo antes de poder dañar al jefe (regla del GDD). El resto de jugadores puede seguir dañando al jefe con normalidad.

**Cualquier jugador activo puede atacar a cualquier aliado**, no solo al de su slot. Así el equipo puede colaborar para quitar cuanto antes los aliados que molestan a un compañero. Atacar a un aliado es opcional y sustituye al ataque contra el jefe en ese turno.

## 3. Objetivo del ataque del aliado

**El aliado ataca al dueño de su slot**, tanto al entrar como al final del turno del jefe, salvo que el texto de su ataque o habilidad diga otra cosa.

Si el dueño del slot está eliminado, se tira entre los jugadores activos y ataca al que salga:

| Jugadores activos | Tirada |
|---|---|
| 2 | moneda |
| 3 | dado de 3 caras |
| 4 | dado de 4 caras |

Con un solo jugador activo no hay tirada: ataca a ese jugador. El jugador de la mesa introduce a mano el resultado y el daño, igual que con el jefe. El asistente no computa las habilidades (GDD §4.4).

## 4. Jugador eliminado

Cuando un jugador queda eliminado:

- Deja de contar en la tirada del objetivo y como posible slot donde invocar nuevos aliados.
- Si tenía un aliado vivo en su slot, **el aliado sigue vivo y sigue atacando** (objetivo al azar entre los activos, §3). Ya no bloquea a nadie, porque su dueño no puede dañar al jefe, pero los jugadores activos pueden atacarlo para eliminar su amenaza (regla de §2).

## 5. Casos límite

- **Un solo jugador activo** (los demás eliminados): no hay tirada; el aliado ataca a ese jugador.
- **El aliado cae mientras su dueño está eliminado**: el slot queda libre, pero como el jugador está eliminado no se puede invocar ahí.
- **Todos los slots activos ocupados**: la invocación no tiene efecto.

## 6. Exceso de daño (D-07)

Atacar a un aliado sustituye el ataque contra el jefe. Si el daño supera la vida que le queda al aliado, **el exceso se pierde**: no pasa al jefe ni a otro aliado. El daño hecho a aliados no cuenta para los puntos (D-10).

## 7. Cómo y cuándo se invoca un aliado

La invocación no depende del texto de las cartas del jefe (todos tienen 3 ataques y, si fuera una carta, podría no salir nunca) y **no todos los jefes tienen que invocar**.

### 7.1 Qué define cada jefe

Cada jefe declara en su ficha del catálogo (T-13):

- **Cada cuántos HP perdidos** hay un intento de invocación.
- **Cómo se tira** el intento (por defecto, una moneda: cara = invoca).
- **Su lista de aliados** posibles.

Un jefe sin estos datos nunca invoca. Ejemplo ilustrativo (no es un jefe real): *Palkia, 3000 HP, un intento cada 600 HP perdidos, moneda y, si sale cara, d4 para elegir el slot*.

### 7.2 Cuándo se intenta

- Un intento ocurre **en el momento en que el HP del jefe cruza un umbral**, normalmente durante el turno de un jugador. El aliado puede entrar sobre un jugador que todavía no ha actuado y empezar a bloquearlo.
- **Cada umbral cuenta una sola vez por partida**: si el jefe se cura y vuelve a cruzarlo, no hay intento nuevo. Con Palkia, como mucho cuatro intentos por partida (a 2400, 1800, 1200 y 600).
- Si un golpe cruza varios umbrales (p. ej. 1200 de daño con umbral cada 600), hay **un intento por umbral**, uno tras otro, y por tanto puede entrar más de un aliado en el mismo turno.
- El golpe que deja al jefe a 0 HP termina la partida y no genera intentos.

### 7.3 Cómo se resuelve un intento

1. Se tira la moneda del jefe. Si no sale cara, no hay aliado.
2. Si sale cara y hay algún slot libre (§1), se tira un dado del tamaño del número de slots de la mesa (moneda con 2, d3 con 3, d4 con 4) para elegir el slot. **Si el slot que sale está ocupado o su jugador está eliminado, se repite la tirada** hasta que salga uno libre. Así todos los slots libres tienen la misma probabilidad. Si no queda ninguno libre, no se tira y el intento se pierde.
3. El aliado se elige al azar de la lista del jefe y se coloca en el slot.

### 7.4 Qué hace el aliado al entrar

- Usa su **ataque y/o su habilidad** de inmediato contra el dueño del slot (§3), salvo que su texto diga otra cosa.
- **No vuelve a atacar hasta el final del turno del jefe**, cuando atacan todos los aliados vivos. Un aliado que entra durante el turno de jugadores ataca al entrar y otra vez al final del turno del jefe.
- Su habilidad, si la tiene, es **pasiva**: una vez en juego se mantiene mientras el aliado siga en el combate. No hay habilidades activas por ahora. Se resuelve en la mesa y el asistente solo la registra.
- Hay aliados **sin ataque** (solo habilidad).

### 7.5 Datos de un aliado (catálogo)

`nombre`, `hp`, `ataque` (nombre y daño, o ninguno) y `habilidad` (texto, o ninguna). La vida es variable según su papel.

Ejemplos de partida, **todo propuesta y sin definir**:

| Aliado | HP | Ataque | Habilidad |
|---|---|---|---|
| Rattata (cebo) | 60 | Placaje, 20 | — |
| Wobbuffet (tanque) | 110 | — | Pasiva tipo Contraataque o Manto Espejo |
| Cleffairy (curandera) | 80 | — | Deseo: cura al final del turno del jefe |

Un aliado curandero que cure al jefe interactúa con D-06 (curación ilimitada del jefe): el equipo puede eliminarlo, pero cuenta como una vía más de alargar la partida.

## 8. Cambios en otros documentos

- `incursiones_gdd.md` → v0.10: turno del jefe (invocación y objetivo del aliado), §6.2 y glosario.
- `incursiones_gdd.md` → v1.1: invocación por umbrales de HP del jefe, entrada del aliado, exceso de daño y valores provisionales.
- `docs/D-01-setup.md`: la referencia a D-04 apunta a este documento.
