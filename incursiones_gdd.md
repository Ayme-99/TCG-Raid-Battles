# Incursiones — Game Design Document

**Versión:** 1.15 (especificación del motor)
**Formato base:** Pokémon TCG — Raid Battle cooperativo, con soporte virtual como "Game Master"
**Jugadores:** 1-4 (pensado para 3-4), cooperativo, físico (cartas y contadores en mesa) + asistente virtual para cálculos y registro

Este documento es la fuente de verdad del diseño. Recoge todas las decisiones cerradas (D-01 a D-16, salvo D-15, que sigue en diseño) y marca en §9 lo que sigue siendo provisional hasta los playtests (T-17). El detalle y la justificación de cada decisión están en `docs/`.

---

## 1. Concepto y objetivo

Formato cooperativo de Pokémon TCG en el que 1-4 jugadores se enfrentan juntos a un **jefe** controlado por el sistema (nunca por un jugador humano). El asistente virtual actúa como **Game Master**: no simula el juego, solo lleva el HP del jefe, registra lo que ocurre y comprueba condiciones de fin de partida. Todo lo demás (cartas, contadores de daño de los Pokémon de los jugadores) vive físicamente en la mesa.

**Objetivo del jugador:** derrotar al jefe reduciendo su HP a 0 antes de que todos los jugadores se queden sin Pokémon en juego.

Reglas base heredadas del Raid Battle oficial: solo cartas de Pokémon (sin Entrenador ni Energía), los ataques no tienen coste de Energía, no hay mazo del que robar, el texto de un ataque se aplica si se puede hacer y se ignora si no (el daño que depende de Energía hace solo su daño base), y cada jugador solo puede usar un ataque GX por partida.

---

## 2. Setup de partida

Orden (detalle en `docs/D-01-setup.md`):

1. Cada jugador elige **2 Pokémon** (1 Activo + 1 Banca), de cualquier carta del formato. Son 2 en todos los niveles.
2. Cada jugador introduce a mano el daño de su mejor ataque; el asistente calcula **X** (ver abajo).
3. El asistente muestra el **nivel** según X y lo fija. Los Pokémon ya no se pueden cambiar.
4. Se elige el **jefe** del catálogo de ese nivel, a mano o al azar.
5. Empieza la partida.

| Parámetro | Regla |
|---|---|
| **X** | Suma, de todos los jugadores, del daño del mejor ataque de cada jugador (un solo valor por jugador: el mayor entre sus 2 Pokémon). Se calcula una sola vez, en el setup. |
| Qué número cuenta (`docs/D-02-dano-maximo.md`) | Cada jugador lo introduce a mano y todos lo ven y lo comprueban con la carta física. La mesa acuerda el número caso a caso, **sin tope** (hay cartas de más de 200 de daño). Daño fijo: el impreso. Daño por Energía: solo el base impreso. Los modificadores de la partida no cuentan. |
| **Nivel** | `X ≤ 400` → Nv1 · `400 < X ≤ 600` → Nv2 · `600 < X ≤ 800` → Nv3 · `X > 800` → Nv4. El valor límite pertenece al nivel de abajo (media máxima por jugador con 4: 100 / 150 / 200 en Nv1-3). Un X menor de 250 se juega como Nv1 (no hay nivel inferior). |
| **Jefe** | Elegido a mano o al azar dentro del nivel. Es una **carta fija** del catálogo: tiene su propio HP y sus propios ataques; no se escala con los jugadores. El asistente conoce el HP y el daño de cada ataque y computa solo los efectos «de programa» (D-14: autodaño, daño por ataques previos del turno, daño a los aliados); el resto lo aplican los jugadores en la mesa. **Criterio de nivel**: Nv1 Pokémon Básicos, Nv2 Pokémon de Fase 1 que no evolucionan más, Nv3 Pokémon de Fase 2, Nv4 Pokémon Míticos y Legendarios. Lanzamiento: 4 jefes, uno por nivel (Onix Nv1, Manectric Nv2, Kingdra Nv3, Arceus Nv4), todos disponibles desde el principio; el catálogo crecerá con más jefes. |
| **HP del jefe** | El de su carta. HP de los jefes del catálogo, calibrados con el simulador (con sus 6 aliados, D-16) para un objetivo de victoria de 75 / 50 / 30 / 15 %: **Onix 2300 / Manectric 2600 / Kingdra 3700 / Arceus 3800** en Nv1 / Nv2 / Nv3 / Nv4 (T-71: son los PS de las cartas; la calibración de T-68 daba 2200 / 2700 / 3800 / 3900). La referencia anterior sin aliados (2382 / 4313 / 4411 / 5205) sigue en `balance/tablas/niveles.csv`. Cada jefe debe cumplir la regla de poder de `docs/D-03-sistema-de-poder.md`. |
| Ataques del jefe por nivel | Nv1 30/60/120 · Nv2 40/80/160 · Nv3 60/100/200 · Nv4 80/120/240. Los ataques salen de la baraja de ataques del jefe («Ataque X contra jugador Y», como el juego oficial), que también fija el máximo de ataques por turno. |
| Menos de 4 jugadores | No se añaden parejas extra. El nivel se autoajusta con X, y los slots de aliados bajan con el número de jugadores (§4.4). |

---

## 3. Estructura de turno

```
INICIO
  └─ Setup (§2): 2 Pokémon por jugador → X → nivel → jefe
      └─ TURNO DE JUGADORES (bucle)
            Orden de actuación cada ronda:
              1º) Jugadores cuyo Pokémon activo cayó KO y siguen en juego
                  (se sientan el turno: solo roban carta de ánimo)
              2º) Resto de jugadores, por orden de asiento (J1..J4)
            Por cada jugador activo, en ese orden:
              - Juega su turno (ataques sin coste de energía)
              - Ataca al jefe, o a cualquier aliado (cualquier jugador
                puede atacar a cualquier aliado)
              - Un jugador con aliado vivo en su slot puede ignorarlo y
                dañar al jefe (el aliado le ataca igualmente); solo el
                Bloqueo de un aliado concreto obliga a atacarle
              - Introduce a mano el daño hecho al jefe; el asistente lo resta
              - Si HP del jefe ≤ 0 → FIN: VICTORIA (inmediata)
      └─ TURNO DEL JEFE
            - La app roba por el jefe una carta de su mazo de 20 cartas de ataque
              (animación) y muestra el ataque (1/2/3) y el jugador atacado:
                · Si la carta dice «Roba una carta más», se roba otra, hasta el
                  máximo de ataques del nivel (Nv1: 2, Nv2: 3, Nv3 y Nv4: 4)
                · Una carta que apunta a un jugador que no juega o está
                  eliminado se descarta sin efecto y se roba otra
                · Si el mazo se agota, se baraja el descarte
            - Si la carta cura al jefe: sube su HP sin pasar del HP máximo
            - Al final de su turno, cada aliado vivo usa su único ataque
              contra el dueño de su slot (si está eliminado, contra un
              jugador activo al azar), incluidos los que ya atacaron al
              entrar durante el turno de jugadores
            - Los jugadores aplican el daño a sus Pokémon en mesa
            - Si un Pokémon cae KO, se registra en el asistente
            - Si un jugador se queda sin Pokémon → queda ELIMINADO
            - Si TODOS los jugadores están eliminados → FIN: DERROTA
            - Si no, vuelve al TURNO DE JUGADORES
FIN (VICTORIA / DERROTA)
  └─ Se calculan los puntos y se guarda la partida (§7)
```

---

## 4. Reglas detalladas

> **Qué gestiona la app y qué se resuelve en la mesa.** La app lleva la cuenta del jefe y de sus aliados: su HP, el daño que reciben y los ataques que hacen. Los Pokémon de los jugadores (sus cartas, contadores de daño, ataques y efectos) se gestionan en la mesa; a la app solo le llega el daño que hacen al jefe y los KO. La baraja de ataques del jefe es física: la app no tiene sus cartas, solo registra cada ataque que sale. Los aliados invocados también los lleva la app (HP y bloqueo), aunque los efectos de sus habilidades los aplique el jugador o un script según la carta (D-13).

### 4.1 Pokémon, KO y eliminación

- Un Pokémon que cae KO **no revive**: queda fuera toda la partida.
- Cuando cae el Activo, la **Banca asciende automáticamente** (solo hay un Pokémon en la banca, no hay elección).
- Un jugador solo queda **eliminado** cuando no le queda ningún Pokémon en juego. El primer KO no lo elimina.
- Un jugador eliminado no actúa, no gana prioridad y no cuenta en las tiradas de objetivo.

### 4.2 Carta de ánimo (Cheer)

Detalle en `docs/D-05-carta-de-animo.md`.

- El jugador cuyo Pokémon activo cae KO (y al que le queda otro Pokémon) **se sienta su siguiente turno: no ataca ni se retira, solo roba una carta de ánimo** (la carta se roba en la mesa; la app no la gestiona, TODO). Si cae el último Pokémon, queda eliminado y no roba.
- Mientras está KO (desde la caída hasta el final de la ronda siguiente), **los ataques del jefe y de sus aliados contra él fallan**: la carta del jefe se descarta y se roba otra; el ataque del aliado se omite.
- Si todos los jugadores en juego están KO, el jefe no ataca ese turno. Un KO se sienta una sola vez, aunque caigan varios Pokémon.
- Las cartas son las **5 oficiales de Cheer** y se resuelven en la mesa (el asistente no computa su efecto, solo puede registrar cuál salió): doble daño a un Pokémon, curar 80 a cada Pokémon, curar todo a 1 Pokémon, el jefe solo juega una carta el próximo turno, +50 de daño a todos los Pokémon de los jugadores.
- El sistema está abierto a nuevas cartas y mecánicas según se desarrolle el juego.

### 4.3 Estados alterados

Dormido, paralizado, envenenado y quemado solo afectan al Pokémon Activo, nunca a la Banca. En los Pokémon de los jugadores se resuelven en la mesa; el asistente no los modela.

**Estados del jefe (D-12, `docs/D-12-estados-del-jefe.md`).** El asistente sí lleva el veneno y la quemadura del jefe. El **veneno** es permanente y hace 10 de daño en cada chequeo. La **quemadura** hace 20 y, después del daño, se tira una moneda automática: cara la quita, cruz la mantiene. El chequeo ocurre una vez por ronda, al cerrar el turno del jefe (después de los ataques de los aliados). Si deja al jefe a 0 HP, victoria. El daño de los estados baja el HP del jefe pero no se atribuye a ningún jugador; a cambio, quien aplica estados cobra un bono de puntos (§7).

### 4.4 Aliados del jefe

Detalle en `docs/D-04-aliados.md`.

- **Un slot por jugador** (hasta 4; con 3 jugadores, 3 slots; con 2, 2). Un aliado como máximo por slot, solo en slots de jugadores activos.
- Un aliado tiene HP propio (independiente del jefe), a lo sumo un ataque y a veces una habilidad. Hay aliados sin ataque (solo habilidad) y las habilidades son **pasivas**: una vez en juego se mantienen mientras el aliado siga en el combate.
- **Llamada de aliados (estilo Pokémon dominante de Sol y Luna, T-69; corregida en T-71)**: la define cada jefe en su ficha (si llama o no y sus 6 aliados, uno por categoría: Daño, Tanque, Cura, Control, Potenciador y Debilitador, D-13 y D-16); un jefe sin esos datos nunca llama. El jefe llama a un aliado **cuando termina su turno por primera vez** (final de la ronda 1) y **después cada vez que su HP baja a un valor definido en su ficha** (`cadaHp` HP perdidos entre llamadas); cada umbral cuenta una sola vez aunque el jefe se cure, y los ya cruzados antes de la primera llamada se suman a ella. Llama como máximo **nivel + 1** veces por partida (2 a Nv1, 3 a Nv2, y así). La llamada **no depende de monedas, de objetos ni de estados**: siempre se hace. Después, un dado del tamaño del número de slots elige el slot (no se repite un slot ocupado ni de un jugador eliminado; si no hay slot libre, no hay aliado, y cuenta como llamada) y un d6 elige la categoría. Entra el aliado de esa categoría de la ficha del jefe y ataca al entrar; después ataca al final de cada turno del jefe.
- **Pícaro**: categoría de control (estados alterados, modificar fuerza, contadores de daño). Sus aliados son los únicos que atacan a la Banca.
- **Entrada**: al entrar, el aliado usa su ataque y/o su habilidad contra el dueño de su slot (salvo que su texto diga otra cosa) y no vuelve a atacar hasta el final del turno del jefe.
- **Exceso de daño**: si un jugador hace a un aliado más daño del que le queda, el exceso se pierde (no pasa al jefe ni a otro aliado).
- **Sin bloqueo de slot**: el aliado está obligado a atacar al dueño de su slot, pero este no está obligado a atacarle: puede ignorarlo y dañar al jefe. Solo una habilidad de Bloqueo (Bronzong de Arceus) obliga a todos a atacar a ese aliado.
- **Ayuda**: cualquier jugador activo puede atacar a cualquier aliado, opcionalmente y en lugar de atacar al jefe, para quitar los aliados que estorban a un compañero.
- **Objetivo del aliado**: el dueño de su slot, siempre. Si ese jugador está eliminado, se tira entre los jugadores activos (moneda / dado de 3 / dado de 4); con un solo jugador activo, ataca a ese jugador.
- Si el dueño de un slot queda eliminado, su aliado **sigue vivo y atacando**.
- Las **habilidades** de los aliados (reducir daño al jefe, aumentar el daño del jefe, forzar a la banca al atacante...) las aplica el **programa** o el **jugador** según indique la carta (D-13). Las del jugador se resuelven en la mesa y el asistente solo las registra.
- **Cierre del turno del jefe (T-70)**: después de los ataques del jefe atacan los aliados que tengan ataque, luego la mesa hace el **Chequeo Pokémon** (efectos de los aliados en juego, como Tormenta de Arena, y después los estados del jefe) y se termina el turno. Los KO que salgan de los ataques de los aliados o del chequeo cuentan como KO del turno del jefe. Qué aplica el programa y qué la mesa con cada carta está en `docs/CARTAS.md`.

### 4.5 Curación del jefe

El jefe puede curarse sin límite de veces, sin pasar nunca de su HP máximo inicial (D-06, `docs/D-06-curacion-del-jefe.md`).

- **No hay tope de rondas ni de curación.** Toda partida termina porque el jefe ataca en cada turno y los jugadores casi no pueden curarse (solo con cartas de ánimo), así que si el jefe se cura más de lo que le dañan, el equipo acaba perdiendo.
- Si la mesa no quiere seguir, **abandona** y cuenta como derrota (§5).
- El asistente registra la curación efectiva: lo que sube de verdad, sin pasar del máximo. Una curación a vida completa registra 0.
- Para los puntos solo cuenta la **vida perdida por el jefe** (HP máximo − HP actual), no el daño bruto (§7).

---

## 5. Condiciones de fin de partida

| Condición | Resultado | Cuándo se comprueba |
|---|---|---|
| HP del jefe llega a 0 | **Victoria** | Tras cada daño de un jugador (inmediata) |
| Todos los jugadores eliminados | **Derrota** | Tras cada KO registrado |
| La mesa abandona | **Derrota** | En cualquier momento de la partida en curso |

No existe el empate: o gana el equipo o pierde (abandonar cuenta como derrota).

**Orden de comprobación (D-08, `docs/D-08-orden-fin-de-partida.md`).** El fin de partida se evalúa tras cada evento registrado y la primera condición que se cumple termina la partida: a partir de ahí no se acepta ningún evento más, así que no puede acabar a la vez en victoria y derrota. Si un mismo efecto deja al jefe a 0 HP y elimina al último Pokémon de la mesa (retroceso, veneno, quemadura), **gana la victoria**: la mesa registra primero el daño al jefe y después los KO de los jugadores. El daño de veneno y quemadura sobre el jefe no se atribuye a ningún jugador (D-12).

Se pierde solo cuando todos los Pokémon de todos los jugadores han caído (8 KO con 4 jugadores). No se adopta el límite oficial de 4 KO.

---

## 6. Roles y responsabilidades (mesa física vs. asistente virtual)

| Elemento | Lo lleva... |
|---|---|
| Cartas de Pokémon de los jugadores y HP de sus Pokémon | Física (mesa, contadores de daño) |
| HP del jefe | **Asistente virtual** (único cálculo automático de HP) |
| Aliados del jefe (HP, slot, si sigue vivo) | Asistente virtual |
| Efecto de las habilidades de los aliados | Física: el asistente solo puede registrar en el log cuál se usó |
| Mazo de ataques del jefe (qué ataque y contra quién) | **Asistente virtual** (v1.11): baraja, roba y muestra la carta |
| Efecto de las cartas de ataque del jefe | Física: el asistente propone el daño del catálogo y registra el resultado |
| Cartas de ánimo (efecto) | Física: el asistente solo registra cuál salió |
| Objetivo aleatorio (ataque de aliados) | Física (dado o moneda real): el asistente registra el resultado |
| Estados alterados de los Pokémon de los jugadores | Física |
| Veneno y quemadura del jefe (D-12) | **Asistente virtual** (daño en el chequeo y moneda automática) |
| Registro / historial de partida | Asistente virtual |
| Puntos y desbloqueos | Asistente virtual → backend |

---

## 7. Puntos y desbloqueos

Detalle en `docs/D-10-sistema-de-puntos.md`. Cifras en `balance/tablas/`.

- Los puntos son **individuales**: cada partida genera un total para el equipo que se reparte según lo aportado en el combate (el daño hecho por la fuente de cada jugador: ataques, daño extra de las cartas de ánimo y aliados que invoca).
- **Victoria**: el total es el tope del nivel (3000 / 6000 / 9000 / 15000). **Derrota** (también al abandonar): `round(vida perdida por el jefe × Y ÷ 4) + 1`, con Y = tope del nivel ÷ HP del jefe (perder sin hacer nada da 1 punto).
- **Reparto**: 1 jugador 100 % · 2 jugadores 55 / 45 · 3 jugadores 40 / 33 / 27 · 4 jugadores 27 / 25 / 25 / 23 (los intermedios van primero a quien no perdió Pokémon, luego por daño; empate: menos Pokémon perdidos, luego al azar).
- **Desbloqueos**: los puntos de una cuenta se acumulan y no se gastan. Un jefe nuevo se desbloquea al llegar a su coste: Nv1 10 000 · Nv2 20 000 · Nv3 30 000 · Nv4 40 000. Los 4 jefes de lanzamiento están disponibles desde el principio.
- El daño hecho a los aliados no cuenta para los puntos.
- **Bono de estados** (D-12): cada jugador que aplica veneno o quemadura al jefe cobra un bono individual, fuera del total del equipo, `tope del nivel ÷ 100 × min(n, 3)` con `n` = veces que ha aplicado un estado que el jefe no tenía. En derrota (o abandono) se divide entre 4. No cambia los puestos. Los invitados no lo cobran.

---

## 8. Identidad, cuentas y conexión

Detalle en `docs/D-11-identidad-jugadores.md`.

- Las cuentas son **las mismas que las de Deck Tracker**. El backend de Incursiones valida esa sesión y guarda solo el id de usuario.
- El **host** necesita cuenta. Un jugador con cuenta se une desde su dispositivo por **código de sala, QR o enlace de invitación** y cobra sus puntos. Un **invitado** juega en el dispositivo del host con un nombre de mesa, ocupa su puesto en el reparto, pero su parte no se abona a nadie.
- Las filas de invitados se guardan en el historial sin abonar, para poder auditar el reparto.
- Se puede jugar **sin conexión** y guardar al reconectar (la partida lleva un id generado por el cliente para no duplicarse). Unirse con otra cuenta requiere conexión; sin red, solo el host cobra.
- El resultado de cada partida se envía al backend (jefe, nº de jugadores, victoria/derrota, turnos, daño por jugador).

---

## 9. Valores provisionales (a ajustar en los playtests, T-17)

| Valor | Estado |
|---|---|
| HP del jefe (2300 / 2600 / 3700 / 3800) | Son los PS de las cartas (T-71); la calibración con el simulador y 32 cartas reales daba 2200 / 2700 / 3800 / 3900. Falta contrastar con playtests y recalibrar con la llamada de T-71 |
| Tope de 200 por ataque para X | Provisional |
| Cartas de ánimo: una por KO y máximo 3 cartas distintas por partida | Adoptado del juego oficial, sin confirmar |
| Efectos de las cartas de ánimo (curas, +50) | No están en el simulador: la partida real será algo más fácil que lo calibrado |
| Topes y costes de puntos (3000 / 6000 / 9000 / 15000; 10 000 a 40 000) | Calibrados para desbloquear en ≈ 17 / 22 / 29 / 36 partidas con un grupo de 4 |
| Invocación de aliados (umbral de HP, probabilidad y aliados por jefe; vida, daño y efectos de cada aliado y de cada categoría) | Todo propuesta sin calibrar; los aliados aún no están en el simulador |
| Jugar con 1-2 jugadores | Más difícil; se acepta |

---

## 10. Glosario

- **Jefe (Boss):** Pokémon controlado por el sistema, sin jugador humano al mando.
- **X:** suma del mejor ataque de cada jugador; fija el nivel del jefe.
- **Ranura de ataque (Attack slot):** Ataque 1/2/3 del jefe; el asistente solo conoce el número, no el efecto.
- **Carta de ánimo (Cheer):** carta que roba el jugador cuyo Pokémon activo cae KO; le da prioridad en la ronda siguiente y un efecto resuelto en la mesa.
- **Aliado:** Pokémon invocado por el jefe, uno por slot de jugador y de una de las 6 categorías (Daño, Tanque, Cura, Control, Potenciador, Debilitador). Un único ataque, a veces con habilidad.
- **Habilidad (de aliado):** efecto pasivo que algunos aliados tienen; se resuelve físicamente.
- **KO (jugador):** un Pokémon del jugador ha sido derrotado. No elimina al jugador hasta agotar todos sus Pokémon.
- **Eliminado:** jugador sin Pokémon en juego; deja de participar, pero la partida sigue si queda alguno activo.
- **Invitado:** jugador sin cuenta que juega en el dispositivo del host; no cobra puntos.
- **Incursiones:** mecánicas extendidas sobre el Raid Battle base (curación del jefe, aliados, puntos y desbloqueos).

---

## 11. Documentos de apoyo

| Documento | Contenido |
|---|---|
| `docs/D-01-setup.md` | Orden del setup, 2 Pokémon en todos los niveles, casos límite |
| `docs/D-02-dano-maximo.md` | Qué cuenta para X y quién lo introduce |
| `docs/D-03-sistema-de-poder.md` | Fórmula de poder, calibración y simulador |
| `contrato/README.md` | Formato JSON versionado del registro de partida (T-07) |
| `docs/D-06-curacion-del-jefe.md` | Curación del jefe, final de partida y daño para los puntos |
| `docs/D-04-aliados.md` | Slots, invocación, bloqueo y objetivo de los aliados |
| `docs/D-05-carta-de-animo.md` | Cheer, KO, promoción desde la banca |
| `docs/D-10-sistema-de-puntos.md` | Puntos, reparto, desbloqueos y modelo de datos |
| `docs/D-11-identidad-jugadores.md` | Cuentas, unirse a una partida, modo sin conexión |
| `docs/D-12-estados-del-jefe.md` | Veneno y quemadura del jefe, chequeo al cerrar la ronda y bono de puntos |
| `docs/D-13-aliados-por-categoria.md` | Aliados por categoría, invocación con dado de slot y de categoría, efectos del programa o del jugador |
| `docs/D-14-efectos-de-ataques-del-jefe.md` | Efectos de los ataques del jefe que computa el programa |
| `docs/D-15-modos-de-preparacion.md` | Modos de preparación: por equipo, por jefe (en diseño, #106) |
| `docs/D-16-aliados-seis-categorias.md` | Los aliados pasan de 4 a 6 categorías |

---

## 12. Historial de cambios de este documento

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
| v0.9 | D-02 cerrada: cada jugador introduce a mano el número de su mejor ataque, todos lo ven y lo comprueban con la carta física; qué número cuenta lo acuerda la mesa con un tope de 200 por ataque (criterio recomendado en `docs/D-02-dano-maximo.md`). Los modificadores de la partida no cuentan para X. |
| v0.10 | D-04 cerrada: un slot de aliado por jugador, invocación solo en slots de jugadores activos sin aliado, el aliado ataca a un jugador activo al azar (moneda o dado de 3/4 caras) y, si su dueño queda eliminado, sigue atacando pero ya no bloquea. Cualquier jugador activo puede atacar a cualquier aliado. Se añade `docs/D-04-aliados.md`. |
| v0.11 | D-05 cerrada: la carta de ánimo da prioridad de turno y un efecto de las 5 cartas oficiales de Cheer (resuelto en la mesa, ampliable), el Pokémon KO no revive, la banca asciende automáticamente (solo hay un Pokémon en la banca) y con varios KO a la vez se actúa por orden de asiento. Se añade `docs/D-05-carta-de-animo.md`. |
| v0.12 | D-11 cerrada: Incursiones usa las mismas cuentas que Deck Tracker (solo guarda el id de usuario), el host necesita cuenta, los demás jugadores se unen con su cuenta por código de sala, QR o enlace de invitación, los invitados se guardan con nombre de mesa sin abonar, y se puede jugar sin conexión y guardar al reconectar. Se añade `docs/D-11-identidad-jugadores.md`. |
| v1.0 | T-02: el GDD pasa a ser la especificación del motor. Consolida D-01, D-02, D-04, D-05, D-10 y D-11 en un solo documento sin contradicciones: se eliminan las secciones de decisiones pendientes y el estado «implementado» del motor (§6.1 antiguo), se añaden las reglas detalladas (§4), los puntos (§7), la identidad (§8), la tabla de valores provisionales (§9) y el índice de documentos de apoyo (§11). |
| v1.1 | D-07 cerrada: la invocación de aliados la define cada jefe (umbral de HP perdidos, moneda y dado de slot, lista de aliados); se intenta en cuanto el HP del jefe cruza un umbral, cada umbral una sola vez, y el aliado ataca al entrar y al final del turno del jefe contra el dueño de su slot. Las habilidades de aliados son pasivas. El exceso de daño a un aliado se pierde. Ver `docs/D-04-aliados.md` §3, §6 y §7. |
| v1.2 | D-06 cerrada: la curación del jefe sigue sin límite y sin tope de rondas (toda partida acaba por KO o abandono); abandonar cuenta como derrota y no existe el empate; los puntos de una derrota usan la vida perdida por el jefe (neto), no el daño bruto. Se añade `docs/D-06-curacion-del-jefe.md`. |
| v1.3 | D-08 cerrada: el fin de partida se evalúa tras cada evento registrado; si un efecto deja al jefe a 0 HP y elimina al último Pokémon de la mesa a la vez, gana la victoria (se registra primero el daño al jefe); el daño al jefe fuera de turno cuenta como daño del jugador que lo causó. Propuesta abierta: veneno y quemadura como estado en el asistente. |
| v1.4 | D-12 cerrada: el asistente lleva los estados del jefe (veneno permanente de 10, quemadura de 20 con moneda automática para quitarla) con chequeo al cerrar la ronda; su daño no se atribuye a ningún jugador y se sustituye por un bono individual de puntos de `tope ÷ 100 × min(n, 3)` (÷ 4 en derrota), fuera del total del equipo. Sustituye la decisión de D-08 sobre el daño de estados. |
| v1.5 | D-13 cerrada: cada jefe tiene 4 aliados, uno por categoría (Daño, Barrera, Cura, Pícaro). Tras la moneda, un dado elige el slot y otro la categoría sin repetir valores en uso. Cada carta de aliado indica si sus efectos los aplica el programa (con script) o el jugador. Se añade `docs/D-13-aliados-por-categoria.md`. |
| v1.6 | Enmienda a D-13: el máximo de ataques por turno lo define la baraja de ataques del jefe («Ataque X contra jugador Y»), no una cifra fija; Pícaro es la categoría de control y sus aliados son los únicos que atacan a la Banca; cada jefe tiene sus 4 aliados propios. |
| v1.7 | La categoría Barrera pasa a llamarse **Tanque** (contrato v4). Cada jefe puede invocar con moneda o de forma **segura** (sin moneda). Jefes iniciales: Onix (Nv1), Manectric (Nv2), Kingdra (Nv3) y Arceus (Nv4), con invocación segura en el 50 %, 66 %/33 %, 75/50/25 % y 80/60/40/20 % del HP. |
| v1.8 | Se deja escrito qué gestiona la app (el jefe y sus aliados: HP, daño recibido y ataques que hacen) y qué se resuelve en la mesa (Pokémon de los jugadores y baraja de ataques del jefe). |
| v1.9 | Criterio de nivel de los jefes (Nv1 Básicos, Nv2 Fase 1 que no evolucionan más, Nv3 Fase 2, Nv4 Míticos y Legendarios). Los ataques del jefe pasan a poder llevar efectos (D-14, contrato v5): la app computa solo los de programa. |
| v1.10 | Puesta al día del documento: D-16 (6 categorías de aliado: Daño, Tanque, Cura, Control, Potenciador y Debilitador; contrato v6), lanzamiento con 4 jefes (uno por nivel) en lugar de 7, y el índice de §11 con D-12, D-14, D-15 y D-16. D-15 (modos de preparación) sigue en diseño. |
| v1.11 | El jefe roba de un mazo de 20 cartas de ataque que lleva la app (las del PDF oficial de Incursión Max): cada carta dice el ataque, el jugador atacado y si se roba otra. Máximo de ataques por turno según el nivel (Nv1: 2, Nv2: 3, Nv3 y Nv4: 4). Las cartas que apuntan a un jugador que no juega o está eliminado se descartan. Deja de ser física la carta del jefe. HP de los jefes recalibrados con ese mazo (4 jugadores): Onix 2400 / Manectric 2700 / Kingdra 3800 / Arceus 3500. |
| v1.12 | Catálogo de prueba de 32 cartas (4 por tipo). Minun (Manectric): Moflete Estático pasa a ser un aura, mientras esté en juego, cada aliado derrotado por un ataque de los jugadores paraliza al Pokémon atacante. HP de los jefes recalibrados (4 jugadores): Onix 2200 / Manectric 2700 / Kingdra 3800 / Arceus 3900. |
| v1.13 | Llamada de aliados estilo Sol y Luna (T-69): el jefe llama a un aliado al empezar su segundo turno o el turno siguiente a que caiga el anterior, uno cada vez, máximo nivel + 1 llamadas, sin moneda ni umbrales de HP; los dados siguen eligiendo slot y categoría. Los HP de los jefes no cambian. |
| v1.14 | Las 28 cartas del set en el catálogo, con los textos de las cartas (T-70, `docs/CARTAS.md`): Tóxico (Gulpin) pasa a ser un ataque sin daño y Magikarp gana Salpicadura. Moflete Estático lo aplica el programa (el jugador que deja fuera de combate a un aliado queda Paralizado su siguiente turno) y Fijar Blanco queda apuntado el resto de la partida. Cierre del turno del jefe por pasos: ataques de los aliados, Chequeo Pokémon y fin. El asistente recuerda a la mesa, en su momento, lo que tiene que aplicar a sus Pokémon. Los HP de los jefes no cambian. |
| v1.15 | Corrige la llamada de aliados (T-71): el jefe llama a su primer aliado al terminar su primer turno y a los siguientes cuando su HP baja a los valores definidos en su ficha (`cadaHp`), hasta nivel + 1 llamadas; vuelven los umbrales de HP y se acaba el doble ataque de entrada en el mismo turno. HP de los jefes como en las cartas: Onix 2300 / Manectric 2600 / Kingdra 3700 / Arceus 3800. Las monedas que lanzan los jugadores (Bote, Fuerza Lunar) caen en la pantalla. |
