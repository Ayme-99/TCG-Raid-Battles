# Incursiones — Game Design Document

**Versión:** 0.9 (borrador de trabajo)
**Formato base:** Pokémon TCG — Raid Battle cooperativo, con soporte virtual como "Game Master"
**Jugadores:** 1-4, cooperativo, físico (cartas y contadores en mesa) + asistente virtual para cálculos y registro

---

## 1. Concepto y objetivo

Formato cooperativo de Pokémon TCG en el que 1-4 jugadores se enfrentan juntos a un **jefe** controlado por el sistema (nunca por un jugador humano). El asistente virtual actúa como **Game Master**: no simula el juego, solo lleva el HP del jefe, registra lo que ocurre y comprueba condiciones de fin de partida. Todo lo demás (cartas, mazos, contadores de daño de los Pokémon de los jugadores) vive físicamente en la mesa.

**Objetivo del jugador:** derrotar al jefe reduciendo su HP a 0 antes de que todos los jugadores se queden sin Pokémon en juego.

No existe mazo del que robar cartas — cada jugador participa con un número fijo de Pokémon (ver §2), y los ataques no requieren energías.

---

## 2. Setup de partida

| Parámetro | Quién lo decide | Notas |
|---|---|---|
| Nivel del jefe | **Calculado automáticamente** | X = suma, de todos los jugadores, del **ataque base más fuerte de cada jugador** (se cuenta un solo valor por jugador, el mayor entre sus Pokémon; igual que el juego oficial). `X < 400` → Nv1 · `400 ≤ X < 600` → Nv2 · `600 ≤ X < 800` → Nv3 · `X ≥ 800` → Nv4; un `X` menor de 250 se juega también como Nv1 (no hay nivel inferior). Detalle y justificación en `docs/D-03-sistema-de-poder.md` |
| Jefe | Elegido **a mano o al azar dentro del nivel calculado** | Catálogo oficial de jefes (datos versionados, se amplía con actualizaciones). Cada jefe es una **carta fija**: tiene su propio HP y sus propios ataques, y no se escalan según los jugadores. El nivel indica la dificultad, no un HP concreto: un jefe con poco HP y mucho daño también puede ser Nv3. Lanzamiento: 2 jefes en cada uno de Nv1-Nv3 y 1 en Nv4. El asistente conoce el HP y el daño de cada ataque, pero **no** computa los efectos de texto de sus ataques. |
| Nº de jugadores | Automático (según quién juega) | Contribuye al cálculo de X, pero no fija el HP del jefe directamente (ver fila siguiente). El formato está pensado para **3-4 jugadores**; con 1-2 es más difícil (decisión de diseño, v0.6) |
| HP del jefe | Fijo, el de su carta | No escala con el nº de jugadores ni con X. Referencia de HP por nivel (calibrada con el simulador para un objetivo de victoria de 75 / 50 / 30 / 15 %; recalibrada con cartas reales en D-03 §8.4): 2382 / 4313 / 4411 / 5205 en Nv1 / Nv2 / Nv3 / Nv4. Cada jefe debe cumplir la regla de poder de `docs/D-03-sistema-de-poder.md` |
| Nº de Pokémon por jugador | **Fijo: 2 en todos los niveles** | 1 Activo + 1 Banca. Como el juego oficial. Al no depender del nivel, no hay circularidad: cada jugador elige sus 2 Pokémon, se calcula X y de X sale el nivel. Orden del setup en `docs/D-01-setup.md` |

---

## 3. Estructura de turno

```
INICIO
  └─ Setup: X = suma del ataque base más fuerte de cada jugador
     → determina Nivel del jefe → se elige (a mano o al azar) una
     carta del catálogo de ese nivel → HP y ataques fijos de la carta
      └─ TURNO DE JUGADORES (bucle)
            Orden de actuación cada ronda:
              1º) Jugadores cuyo Pokémon activo acaba de recibir K.O.
                  (reciben carta de ánimo)
              2º) Resto de jugadores, en orden de asiento (J1, J2, J3, J4),
                  excluyendo a los que ya han actuado en el paso 1º
            Por cada jugador activo (no eliminado), en ese orden:
              - Juega su turno normal (sus Pokémon, ataques sin coste de energía)
              - Introduce manualmente el daño hecho al jefe
              - El asistente resta ese daño del HP del jefe
              - Si HP del jefe ≤ 0 → FIN: VICTORIA (inmediata, no
                hace falta esperar a que ataquen el resto)
            Cuando ya no quedan jugadores por atacar → pasa el turno
      └─ TURNO DEL JEFE
            - Se revela una carta del jefe (física, en la mesa)
            - El jugador indica al asistente: qué ranura de ataque
              fue (1/2/3 — solo etiqueta, sin efecto conocido),
              cuánto daño hace, y a quién va:
                · Todos los jugadores
                · Un jugador elegido
                · Un jugador al azar (se tira un dado físico;
                  el resultado se introduce a mano)
            - Si la carta invoca un aliado: se coloca en uno de los 4
              slots (uno por posición de jugador). No ataca este turno.
              A partir del turno del jefe siguiente, si sigue vivo,
              usa su único ataque (y su habilidad, si tiene) igual que
              el jefe: el jugador introduce daño/objetivo manualmente
            - Mientras un jugador tenga un aliado en su slot, los
              jugadores deben debilitarlo antes de poder dañar al jefe
            - El jefe puede curarse sin límite de nº de veces, pero
              nunca por encima de su HP máximo inicial
            - Los jugadores aplican el daño a sus Pokémon en mesa
              (fuera del asistente); los estados alterados
              (dormido/paralizado/veneno/quemado) solo afectan al
              Pokémon activo, nunca a la banca
            - Si un Pokémon de un jugador cae KO, se registra en el
              asistente (contador, no elimina al jugador todavía)
            - Si un jugador se queda sin Pokémon en juego (todos KO)
              → queda ELIMINADO de la partida
            - Si TODOS los jugadores están eliminados → FIN: DERROTA
            - Si no, vuelve al TURNO DE JUGADORES
FIN (VICTORIA / DERROTA)
  └─ Resultado enviado al backend (jefe, nº jugadores, victoria/derrota,
     turnos jugados) para estadísticas
```

---

## 4. Condiciones de fin de partida

| Condición | Resultado | Estado en el motor |
|---|---|---|
| HP del jefe llega a 0 | **Victoria** | Inmediata, se comprueba tras cada daño de jugador |
| Todos los jugadores eliminados (sin Pokémon en juego) | **Derrota** | Se comprueba tras cada KO registrado |

**Regla clave (corregida en desarrollo):** un jugador NO queda eliminado con el primer Pokémon KO — solo cuando **todos** sus Pokémon en juego han caído. Antes de esta corrección el motor eliminaba al jugador con el primer KO, lo cual era incorrecto.

---

## 5. Roles y responsabilidades (mesa física vs. asistente virtual)

| Elemento | Lo lleva... |
|---|---|
| Cartas de Pokémon de los jugadores | Física (mesa) |
| HP de los Pokémon de los jugadores | Física (contadores de daño en las cartas) |
| HP del jefe | **Asistente virtual** (único cálculo numérico automático de HP del jefe) |
| Aliados del jefe (HP, slot, si sigue vivo) | Asistente virtual (mecánica de Incursiones, pendiente de implementar) |
| Efecto de las habilidades de los aliados | Física — el asistente no las computa, solo puede registrar en el log qué habilidad se usó |
| Efecto de las cartas de ataque del jefe | Física — el asistente no las conoce, solo registra el resultado que le dicta el jugador |
| Objetivo aleatorio del ataque del jefe | Física (dado real) — el asistente solo registra el resultado |
| Estados alterados del Pokémon activo | Física (mesa) — el asistente no los modela |
| Registro/historial de partida | Asistente virtual |
| Resultado final (para stats) | Asistente virtual → backend |

---

## 6. Mecánicas confirmadas

### 6.1 — Alcance básico (v1, ya implementado en el motor)

- [x] Selección de jefe y nivel (carta fija del catálogo, sin escalado por nº de jugadores)
- [x] Turno de jugadores con daño manual, en el orden correcto (§3)
- [x] Victoria inmediata al llegar el jefe a 0 HP
- [x] Turno del jefe con ataque manual (ranura, daño, objetivo)
- [x] Objetivo aleatorio vía dado físico
- [x] Contador de Pokémon KO por jugador, con eliminación solo al agotarse todos
- [x] Derrota cuando todos los jugadores están eliminados
- [x] Sin mazo ni deck-out: nº fijo de Pokémon por jugador según nivel del jefe
- [x] Ataques sin coste de energía

### 6.2 — Mecánicas de Incursiones (diseño cerrado, pendiente de implementar)

- [x] Curación del jefe: sin límite de número de veces, nunca por encima de su HP máximo inicial
- [x] Invocación de aliados: máx. 4 (uno por slot/posición de jugador), un único ataque cada uno (algunos con habilidad), no atacan el turno en que son invocados, HP propio independiente del jefe
- [x] Habilidades de aliados: efectos como reducir el daño que recibe el jefe, aumentar el daño del jefe, o forzar a la banca al Pokémon atacante si golpea al aliado. Se resuelven físicamente en la mesa — **el asistente no las computa**, solo puede registrar en el log qué habilidad se activó si se le indica
- [x] Mientras un jugador tenga aliado en su slot, debe debilitarlo antes de dañar al jefe
- [x] Estados alterados (dormido/paralizado/veneno/quemado) solo afectan al Pokémon activo, nunca a la banca

---

## 7. Decisiones pendientes (a cerrar antes de seguir programando)

Reabierto en v0.6 al replantear el balance. Pendientes (tarjetas del tablero):

- **D-10** Sistema de puntos (qué puntúa, reparto y cómo se guarda).
- **D-03** Validar la tabla de niveles y el Nv4 propuesto (primer simulador hecho; falta medir la vida de los Pokémon en playtest, T-17).
- Regla de revivir respecto al oficial (ver `docs/D-03-sistema-de-poder.md` §3). La regla de derrota queda decidida: se pierde solo cuando todos los Pokémon de todos los jugadores han caído (no se adopta el límite oficial de 4 KO).

---

## 8. Glosario

- **Jefe (Boss):** Pokémon controlado por el sistema, sin jugador humano al mando.
- **Ranura de ataque (Attack slot):** Ataque 1/2/3 del jefe; el asistente solo conoce el número, no el efecto.
- **Carta de ánimo:** La recibe un jugador cuando su Pokémon activo acaba de caer KO; le da prioridad de actuación en la siguiente ronda.
- **Aliado:** Pokémon invocado por el jefe, uno por slot de jugador (máx. 4). Un único ataque, a veces con habilidad. No ataca el turno en que es invocado. Hay que debilitarlo antes de poder dañar al jefe desde esa posición.
- **Habilidad (de aliado):** Efecto pasivo que algunos aliados tienen (p. ej. reducir daño al jefe, aumentar daño del jefe, mandar a la banca al atacante). Se resuelve físicamente; el asistente no la computa.
- **KO (jugador):** Un Pokémon del jugador ha sido derrotado. No elimina al jugador hasta agotar todos sus Pokémon en juego (activo + banca).
- **Eliminado:** Jugador sin Pokémon en juego; deja de participar en turnos, pero la partida sigue si queda algún jugador activo.
- **Incursiones:** Mecánicas extendidas sobre el Raid Battle base (curación del jefe, invocación de aliados), en diseño.

---

## 9. Historial de cambios de este documento

| Fecha | Cambio |
|---|---|
| v0.1 | Primera versión: recoge el diagrama de flujo original, la corrección de la regla de KO, y las decisiones pendientes detectadas durante el desarrollo del motor base. |
| v0.2 | Eliminado el concepto de mazo y la condición de deck-out (no existen en este formato). Fijado que cada jugador participa con 2 o 3 Pokémon según el nivel del jefe (mapeo exacto pendiente, §7.6). Confirmado que los ataques no requieren energías. |
| v0.3 | Cerradas todas las preguntas de la v0.2: HP del jefe fijo por nivel (sin escalado por nº jugadores), orden de turno definido (cartas de ánimo primero), curación del jefe sin límite de veces pero topada al HP máximo, mecánica de aliados totalmente especificada (4 slots, un ataque, sin atacar el turno de invocación, HP propio), estados alterados solo en el Pokémon activo, y mapeo definitivo de Pokémon por nivel (2 en L1-L3, 3 en L4). Nueva pregunta abierta sobre dificultad con menos de 4 jugadores. |
| v0.4 | Cerrada la pregunta de dificultad con menos jugadores: el nivel del jefe ya no lo eligen los jugadores, se **calcula automáticamente** a partir de X = suma del daño máximo de cada Pokémon de todos los jugadores (`X<400`→Nv1, `400-599`→Nv2, `600-799`→Nv3, `≥800`→Nv4), lo que autoajusta el reto según cuántos/qué tan fuertes son los jugadores. Reordenada la sección de setup para reflejar que el nivel se calcula antes de elegir la carta del jefe. |
| v0.5 | Cerrada la última pregunta abierta (habilidades de aliados): son efectos resueltos físicamente en la mesa (reducir/aumentar daño del jefe, forzar banca al atacante, etc.), el asistente no las computa. **No quedan decisiones de diseño pendientes** para la v1 + Incursiones descritas en este documento. |
| v0.6 | Balance de jefes: X se calcula como en el juego oficial (ataque base más fuerte de cada jugador, no de cada Pokémon). El jefe es una carta fija de un catálogo oficial, elegida a mano o al azar dentro del nivel, con HP de referencia 1600/2200/3000 (oficial Nv1-Nv3) y ~3750 (propuesta Nv4). Lanzamiento con 7 jefes (2+2+2+1). Formato pensado para 3-4 jugadores. Se añade `docs/D-03-sistema-de-poder.md` (fórmula de poder: HP × amenaza ≈ 1,5 × X²) y se reabren decisiones de setup y puntos en §7. |
| v0.7 | Regla de derrota confirmada: solo se pierde cuando no queda ningún Pokémon en pie en toda la mesa (8 KO con 4 jugadores y 2 Pokémon). No se adopta el límite oficial de 4 KO. Primer simulador de balance en `sim/` y resultados en `docs/D-03-sistema-de-poder.md` §8. Objetivo de victoria 75 / 50 / 30 / 15 % y HP de referencia recalibrados a 1700 / 2400 / 3300 / 4400. |
| v0.8 | Setup sin circularidad (D-01): cada jugador usa 2 Pokémon en todos los niveles, incluido el Nv4 (como el juego oficial). Un X menor de 250 se juega como Nv1. HP de referencia por nivel recalibrado con cartas reales (D-03 §8.4). Se añade `docs/D-01-setup.md`. |
| v0.9 | D-02 cerrada: cada jugador introduce a mano el número de su mejor ataque, todos lo ven y lo comprueban con la carta física; qué número cuenta lo decide la mesa caso a caso (criterio recomendado en `docs/D-02-dano-maximo.md`). Los modificadores de la partida no cuentan para X. |
