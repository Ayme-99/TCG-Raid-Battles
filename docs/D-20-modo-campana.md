# D-20 · Modo campaña

Estado: **en desarrollo** (revisado el 2026-11-23). Issue #334 (diseño) y una issue por cada pieza (#336 a #356). Ayme va cerrando el diseño decisión a decisión; cada una queda en el [registro de §10](#10-registro-de-decisiones) con su fecha. **El código y los datos mandan**: este documento describe lo que hay y lo que falta.

| Pieza | Estado |
|---|---|
| Combate 1 contra 1: energía, acciones, debilidad y resistencia, doce efectos y una habilidad, azar con semilla, veneno (§3) | **Hecho** (#336, #350, #352) |
| IA rival determinista (§3.4) | **Hecho** (#338; ampliada en #350 y #352) |
| Catálogo: 22 Pokémon, 1 jefe, 6 zonas y la región de Kanto, con sus esquemas (§12) | **Hecho** (#340, #344, #346, #352, #354) |
| Simulador de combates (`sim/bin/sim_campana.dart`) | Hecho (#342); modos `nodos`, `tramo` y `realista` y **primer informe de calibrado** (#383): objetivo 75 %; con equipo realista el muro es Brock |
| Modelo de ruta por nodos y progreso del jugador (§4) | **Hecho** (#354) |
| Jefe que llama a un aliado a mitad de combate (§4, Jefes) | **Hecho** (#372) |
| Captura, equipo de 6 y PC, centro Pokémon (§2, §4) | **Primera versión hecha** (§4, Partida de campaña); falta la Pokéball |
| XP, evolución y cartas ex: modelo de datos (§2.1) | Hecho (#346); **reserva común de XP y evolución desde el equipo** hechas (#403): Caterpie → Metapod y Weedle → Kakuna; sin cartas ex ni fase 1 de los iniciales todavía |
| Guardado local del progreso (§6) | **Hecho** en el dispositivo (`PartidaCampana`, clave `campana_kanto`); sin sincronizar con la cuenta |
| Pantallas de la app (mapa, combate, equipo, centro Pokémon) | **Primera versión hecha**, sin diseño visual definitivo |
| Puntos al servidor y tienda con puntos | Pendiente (la tienda del centro usa dinero, §4 Partida de campaña) |

Para saber **por qué** algo es como es, mira el [registro de decisiones (§10)](#10-registro-de-decisiones); para crear una carta nueva, [§11](#11-cómo-se-crea-una-carta); para ver lo que hay hoy en el catálogo, [§12](#12-catálogo-actual).

## 1. Idea

La campaña es un **juego de Pokémon para un jugador**: eliges un inicial, recorres rutas, capturas Pokémon, descansas, ganas medallas y te enfrentas a un jefe con sus aliados. Es **ajena a la partida libre**: tiene sus propias criaturas, su propio combate y su propio motor. Lo único que comparte con las incursiones es el **catálogo de jefes** (nombres, mapas, aliados) y la **moneda del juego** (los puntos).

| | Partida libre | Modo campaña |
|---|---|---|
| Jugadores | 1 a 4 | 1 |
| Formato | físico (offline) o digital (online) | digital |
| Qué se juega | cartas reales (físico) o cartas digitales | Pokémon de campaña con PS, ataques y energía |
| Rival | el jefe, con su baraja de ataques | un Pokémon salvaje, un entrenador o un jefe con aliados |
| Da puntos | solo la digital | sí |

Decisiones de Ayme (2026-11-21): el modo es **1 contra 1** (2 contra 2 y 3 contra 3, en el futuro); las cartas de campaña **no** se usan en la partida libre; los puntos compran en la tienda monedas, dados, sobres y cartas sueltas del formato digital (y quizá campañas, aunque lo normal es que estén abiertas de primeras). Cuántos puntos da cada cosa es irrelevante salvo que la campaña tenga compras con puntos, y lo que sobre al terminarla se conserva.

## 2. Pokémon de campaña

Cada Pokémon es un registro del catálogo:

| Campo | Significado |
|---|---|
| `id`, `nombre`, `numero` | identidad |
| `tipo` | el tipo del Pokémon y de sus ataques |
| `debilidad`, `resistencia` | opcionales: tipo y valor (×2 y −30 de salida). Casi todas las cartas llevan debilidad y **solo unas pocas** resistencia, como en las cartas reales |
| `ps` | puntos de salud |
| `retirada` | coste de cambiarlo por otro; **0 (gratis)** de salida |
| `ataques` | 1 a 2 (como las cartas reales): `nombre`, `tipo`, `coste` (energía), `dano`, `efecto` opcional |
| `habilidad` | opcional: una habilidad pasiva (§3.6): `nombre`, `tipo`, `valor`, `texto` |
| `evoluciones` | lista (puede ser vacía): `a` (id) y cómo se consigue (ver 2.1) |
| `ex` | `true` si es una carta ex |
| `rareza` | cuánto cuesta encontrarlo en las rutas (**propuesto; todavía no existe en el esquema**) |
| imagen | no va en el JSON: es `app/assets/campana/cartas/<id>.webp` (480×670) |

- El equipo lleva **hasta 6 Pokémon: 1 activo y 5 en la banca** (decidido el 2026-11-21; es un parámetro). Los demás están en el **PC** (§4, Descanso). Un Pokémon capturado se une al equipo si hay hueco; si el equipo está lleno, la app pregunta si se **cambia por uno del equipo**, y el que se descarta (el capturado o el sustituido) **va al PC**: no se pierde ningún Pokémon.
- Los efectos de los ataques y las habilidades pasivas están en §3.6. Hoy hay **doce efectos y una habilidad**; cada carta nueva puede traer uno nuevo, y entonces se implementa en el motor, la IA, el esquema y los tests (§11).

### 2.1 Progresión: sin niveles, con XP y evolución

Decidido el 2026-11-21. **No hay niveles**: las cartas tienen siempre los mismos PS y daños; se mejora evolucionando.

- **Las victorias en combate dan puntos** (los mismos puntos del juego, §5).
- En un **centro Pokémon** (el nodo de descanso) se pueden **convertir puntos en XP** de un Pokémon del equipo. Cuántos puntos cuesta cada XP queda por equilibrar.
- Cada Pokémon necesita **N de XP** para evolucionar (`via: "xp"` y `xpEvolucion: N` en la carta; el campo se llamaba `xp` hasta #403), con `medallasMinimas` para la medalla que la desbloquea (§10.11, #414). Al llegar a N, puede evolucionar en un centro Pokémon, con un máximo de **un Pokémon por visita** (§4). **Sustituido el 2026-11-22** (§10.6): la XP es una reserva común y se evoluciona fuera de combate, desde el menú del equipo, sin límite por visita.
- **Objetos de evolución** (piedras…): se compran fuera de los centros Pokémon o se encuentran en las rutas (`via: "objeto"`, `objeto: "piedra-trueno"`).
- **Evolución por intercambio** (Kadabra, Haunter, Machoke, Graveler): cuesta **puntos**, por usar la máquina de intercambio (`via: "intercambio"`, `puntos: N`).
- **Cartas ex.** La **última fase de cada Pokémon es una carta ex**. Un Pokémon que no evoluciona (Onix…) puede hacerse ex **gastando puntos** (`via: "puntos"`, `puntos: N`), con el mismo proceso. Cada carta ex es una **entrada propia del catálogo** (`"ex": true`).
- **La carta evolucionada sustituye a la anterior** y recupera todos sus PS (**sustituido el 2026-11-22**, §10.6: queda con **10 PS**, también si estaba debilitado). Una forma evolucionada también puede aparecer salvaje en una zona si el catálogo la incluye, y entonces se captura aparte.
- Un Pokémon puede tener **varias** evoluciones (Eevee con sus piedras), por eso `evoluciones` es una lista.

Datos que hay que guardar en el progreso de campaña: la **reserva común de XP** (`xp` en la partida guardada, versión 2 desde #403; una partida de la versión 1 suma la XP que llevaba cada Pokémon).

## 3. Combate

**1 contra 1.** Cada bando tiene un Pokémon activo y el resto de su equipo en reserva. Gana quien deja sin Pokémon al otro.

### 3.1 Energía

Cada bando (jugador y «máquina») tiene una **reserva de energía de máximo 10**.

- Empieza en **10**.
- Cada ataque **gasta** su coste de la reserva. Si no hay energía suficiente, no se puede usar.
- Al **terminar su turno**, un bando **recupera 1** (decidido el 2026-11-21).

Ejemplo con un ataque de coste 3 usado todos los turnos: se puede atacar con `10, 8, 6, 4` de reserva y después queda en `2`, así que toca ahorrar (en cada turno se gastan 3 y se recupera 1 al terminar). Es una reserva y no un maná que sube por turno, y es lo que encaja con **una acción por turno**.

Los números (inicio, recuperación, máximo) son **parámetros** y se ajustan con el simulador.

### 3.2 Turno

Empieza el **jugador**. En su turno, un bando hace **una acción, y las tres gastan el turno**:

1. **Atacar** con el Pokémon activo (si le llega la energía).
2. **Cambiar** de Pokémon activo.
3. **Cargar:** no ataca y recupera **1 de energía más** de lo normal (2 en total ese turno), pensada para llegar al ataque grande. Sustituye a «Pasar» (decidido el 2026-11-21).

**Elegir el siguiente Pokémon** cuando cae el activo **no** gasta turno: su dueño lo elige y sigue su turno.

**Cambiar: turno o energía.** Se decidió que cambiar **gasta el turno**. La carta puede añadir además una **retirada con coste de energía** (el campo `retirada`; es 0 de salida, es decir, «retirada gratis»). Así, la retirada gratis significa que cambiar no cuesta energía, y un Pokémon pesado podría costar turno **y** energía. Si preferís que la retirada sea solo energía y no turno, es cambiar una línea del motor; queda a validar con el simulador.

### 3.3 Debilidades y resistencias

No hay una tabla de tipos global: **lo escribe cada carta**, como en el juego de cartas. Un Pokémon puede tener una **debilidad** (el daño de ese tipo se multiplica, ×2 de salida) y una **resistencia** (el daño de ese tipo baja, −30 de salida), o ninguna. Primero se aplica la debilidad y luego la resistencia, y el daño nunca baja de 0 (**sin suelo**, decidido el 2026-11-21). Cada Pokémon tiene **un solo tipo**. Los tipos siguen al TCG: **no hay tipo tierra ni roca**, esos Pokémon (Geodude, Onix, Diglett, Sandshrew, Cubone…) son de tipo **lucha** (decidido el 2026-11-21). Se añadió **oscuridad** el 2026-11-22 (Nidoran♀ y ♂ la llevan impresa). Los tipos que **no existen en el TCG** salieron del enum el 2026-11-22 (#404, §10.3): `veneno` y `fantasma` pasan a **oscuridad**, `bicho` a **planta**, `volador` a **normal** y `hielo` a **agua**; Zubat es ahora de oscuridad y su Ataque Ala es normal. Entra **metal**, que aún no lleva ninguna carta. El enum queda en normal, fuego, agua, planta, eléctrico, lucha, psíquico, oscuridad, dragón y metal. No existen las inmunidades. Si dos cartas se bloquean entre sí por resistencias, se corrige la carta, no el motor; el test «todos contra todos» lo detecta.

**Victoria:** gana el bando que deja sin Pokémon en pie al otro.

### 3.4 La «máquina»

El rival juega con **las mismas reglas** (la misma energía y las mismas debilidades y resistencias), de modo que los combates se igualan sin reglas asimétricas. Su decisión es **determinista** (`decidirAccion` en `engine/lib/src/campana/ia.dart`, #338), en este orden:

1. Si cae su activo, saca al relevo que no sea débil al rival, haga más daño y tenga más salud.
2. Si puede **rematar** al Pokémon rival, ataca con lo más barato que lo consiga.
3. Si su activo es **débil** a un ataque del rival, o no llega a ningún ataque, **cambia** a un relevo que no sea débil y sí pueda atacar (si le llega la energía de la retirada). Nunca cambia al jefe que espera a que caiga su aliado (§4, Jefes).
4. Si tiene un ataque que **envenena** y el rival no lo está ya, lo usa, aunque el golpe quede en 0 (el veneno quita PS en cada chequeo); no lo repite mientras siga envenenado (§3.6).
5. Si tiene un ataque que **reduce el daño del rival** (Gruñido) y compensa (evita más daño, en los golpes que el rival necesita para derribarlo, que el que haría atacando), lo usa; no lo repite mientras siga activo el mismo rival (§3.6).
6. Si tiene un ataque que **reduce el daño que recibe su activo** (Fortaleza, Rizo Defensa) y compensa con el mismo criterio, lo usa.
7. Si tiene un ataque que hace que el rival **reciba más daño** (Látigo) y lo derriba en menos golpes contando el turno que gasta, lo usa; no lo repite mientras siga activo el mismo rival.
8. Si tiene un ataque que **quita energía al rival** (Disparo Demora) y con ello el rival deja de poder dar un golpe mayor que el suyo, lo usa (§3.6).
9. Si con la carga extra podría **rematar** al turno siguiente un ataque que hoy no le llega, **carga**.
10. Ataca: con el de **más daño** si la reserva está llena (la energía sobrante se perdería) y, si no, con el de **más daño por energía gastada**.
11. Si no llega a nada, **carga**.

**Lo que la IA no valora** (a propósito): las monedas (decide con el daño base o el esperado, §3.6), el efecto de Doble Patada, el de Bofetón Lodo, ni el veneno al cambiar de Pokémon. Tampoco planea rachas (Rodar): encadena el ataque si hoy hace más daño que su alternativa. Quien pide la acción de un bando usa `EstadoCombate.actua`, no `turno`, porque tras un chequeo Pokémon puede tocarle elegir relevo al bando que no tiene el turno.

### 3.5 Baremo de PS y daños

Decidido el 2026-11-21. Los números salen de las **cartas reales del Standard 2026-27** (marcas H, I y J), de modo que las cartas de campaña se parezcan a las físicas.

**Escala real de referencia**
- Básico: 30–90 PS; los que evolucionan, en torno a 70. Fase 1: 90–130. Fase 2 sin ex: 150–190. Pokémon ex: 200–340.
- Un básico pega 10–30 con una energía y 30–50 con dos. Un ex de Fase 1 como Lucario ex (260 PS) pega 60 con dos energías y 160 con tres.
- La debilidad es ×2 y casi ninguna carta lleva resistencia.

**Baremo de campaña** (PS y daño por coste de energía)

| Fase | PS | Coste 1 | Coste 2 | Coste 3 | Coste 4 |
|---|---|---|---|---|---|
| Básico | 50–90 | 10–20 | 30–40 | 50–60 | — |
| Fase 1 | 90–130 | 20–30 | 50–60 | 80–100 | 110–130 |
| ex (línea de 2 fases o sin evolución) | 200–260 | 30–60 | 80–110 | 130–160 | 180–200 |
| ex (línea de 3 fases) | 270–340 | 40–60 | 90–120 | 150–190 | 220–300 |

**Reglas de calibración**
- El ataque de **coste 2** es el golpe principal: quita del 40 al 50 % de los PS de un rival de su misma fase, así que un duelo igualado dura unos 3 golpes. Con debilidad ×2 baja a 1–2.
- Los ataques de coste 3 y 4 matan en 2 golpes, pero vacían la reserva y obligan a Cargar o Cambiar.
- **1 a 2 ataques** por carta, con coste de 1 a 4. Pidgey y Weedle llevan uno.
- **Siempre un ataque de 20 o más, o con veneno** (decidido el 2026-11-21): así Gruñido (−10, §3.6) nunca deja a una carta sin poder hacer daño. Un ataque de coste 1 de 10 sí se anula, pero es el de relleno. El esquema y un test lo comprueban. Weedle lleva un único ataque de 10, que vale porque envenena.
- **Retirada:** 0–1 en los básicos, 1–2 en las fases evolucionadas, 2–3 en los pesados y los ex.
- **Jefes:** pueden salirse de la tabla en PS (Pikachu 100) pero hacen daño de su fase; un ataque que mate al inicial de un golpe no entra.
- **Resistencia (−30):** solo en pocas cartas (de salida solo Spearow; Geodude y Onix se imprimieron sin resistencia el 2026-11-22).
- Los números son **provisionales** hasta calibrarlos con el simulador (D-20 §9, tarea 4).

**Cartas del catálogo:** la tabla completa, generada desde los JSON, está en [§12](#12-catálogo-actual).

Evoluciones: Fase 1 de 90 a 110 PS (Ivysaur 110, Charmeleon 100, Wartortle 100, Pidgeotto 90, Nidorina 90, Nidorino 90, Graveler 110). ex de 3 fases de 270 a 340 (Venusaur 340, Charizard 330, Blastoise 330, Golem 330, Nidoqueen 310, Nidoking 310, Pidgeot 280, Butterfree 270, Beedrill 270). ex de 2 fases o sin evolución de 210 a 240 (Onix 240, Sandslash 230, Fearow 230, Raichu 220, Primeape 220, Raticate 210, Dugtrio 210). Heredan tipo, debilidad y resistencia de su base. Los rivales de zonas avanzadas tendrán que usar también cartas ex para que siga habiendo reto.

### 3.6 Efectos de ataque

Decidido el 2026-11-21. Un ataque puede llevar un `efecto` y entonces puede tener **0 de daño** (solo hace el efecto).

**`reduceDanoRival` (Gruñido de Bulbasaur):** «Mientras el Pokémon Defensor siga activo, sus ataques hacen 10 puntos menos de daño (antes de aplicar debilidad y resistencia). No se acumula.»
- Dura **todo el combate o hasta que ese Pokémon sale del puesto activo**, ya sea porque cae o porque su dueño lo cambia a la banca. Cambiar es la forma de quitárselo (gasta el turno y la retirada).
- Se resta **antes** de la debilidad y la resistencia, y el daño nunca baja de 0 (sin suelo).
- **No se acumula:** si el rival ya tiene una reducción igual o mayor, usarlo otra vez no hace nada. Cuenta la mayor.
- Es un estado del **bando afectado** (`BandoCombate.danoReducido`), que se pone a 0 al cambiar de activo.
- **Ninguna carta queda anulada:** todas llevan al menos un ataque de 20 o más (§3.5), de modo que Gruñido deja siempre un ataque de 10 como mínimo.
- La IA lo usa solo si compensa; contra un rival que pega poco (10 de daño) lo deja sin hacer daño; contra uno que pega fuerte no lo usa.
- **Por qué no se acumula** (a diferencia de los juegos, donde Gruñido llega a 6 etapas): allí cada etapa multiplica el daño y nunca llega a cero; aquí el daño es plano y no hay suelo, y como cuesta 1 de energía (que se recupera cada turno), tres usos anularían los ataques de coste 1 y 2. El efecto simétrico (Malicioso: «el Defensor recibe 10 más de daño») seguirá la misma regla.
- **`aumentaDanoRecibido` (Látigo de Squirtle):** «Mientras el Pokémon Defensor siga activo, recibe 10 puntos más de daño de los ataques (antes de aplicar debilidad y resistencia). No se acumula.» Es el efecto simétrico: mismas reglas (dura mientras ese Pokémon siga activo, se quita al cambiarlo o cuando cae, no se acumula) pero sobre el daño que **recibe**. Se suma antes de la debilidad y la resistencia; un ataque sin daño no gana el extra. Los dos efectos se combinan. Estado del bando afectado: `BandoCombate.danoExtra`.
- **`quitaEnergiaRival` (Disparo Demora de Caterpie):** «El rival pierde 1 de energía (si le queda alguna). No se acumula con nada: se aplica una vez, al usar el ataque.» Es instantáneo: baja la reserva del rival en `valor` (mínimo 0) en el momento de atacar y no deja estado, así que no hay nada que acumular ni que quitar al cambiar de Pokémon. Vale como ataque de 0 de daño (coste 1). La IA lo usa solo si con ello el rival deja de poder dar un golpe mayor que el que haría ella atacando.
- **`ganaEnergia` (Pulimento de Geodude):** «Tu bando recupera 2 de energía (hasta el máximo de 10).» Ataque de coste 1 y 0 de daño. Instantáneo, como `quitaEnergiaRival`: al usarlo, primero se paga el coste y después se suma `valor` a la reserva del propio bando, con tope en el máximo (`ParametrosCombate.energiaMaxima`, 10); no deja estado, así que no hay nada que acumular ni que quitar al cambiar de Pokémon. Si el ataque falla por Bofetón Lodo (cruz), no suma nada. Propuesto por Ayme el 2026-11-22 a partir de Pulimento de los juegos (sube la Velocidad dos niveles): la velocidad se traslada a la energía. **Ojo con el número:** como Cargar ya da 1 de energía extra (2 en total ese turno), Pulimento con coste 1 y `valor` 2 deja el mismo saldo que Cargar (−1 +2 +1); solo mejora a Cargar con `valor` 3. Ayme imprimió la carta con **2**; Calidad debe medir si aporta algo y, si no, se sube a 3 y se reimprime. Con la reserva llena (empieza en 10) no sirve de nada. **IA (tarea 14):** lo usa **en lugar de cargar** (cuando cargaría para rematar al turno siguiente o porque no llega a ningún ataque), y solo si la reserva no está llena, al activo le falta energía para alguno de sus ataques y acaba con al menos la misma energía que cargando. Con la reserva llena nunca lo usa.
- **`confundeDefensor` (Supersónico de Zubat e Hidropulso de Slowpoke):** lleva un campo `monedas` (1 por defecto): se lanzan esas monedas y, **si todas salen Cara**, el Pokémon Defensor pasa a estar Confundido. Supersónico (Zubat): «Lanza una moneda. Si sale Cara, el Pokémon Defensor pasa a estar Confundido» (coste 1, 0 de daño). Hidropulso (Slowpoke): «Lanza 2 monedas. Si en ambas sale Cara, el Pokémon Defensor pasa a estar Confundido» (coste 3, **40 de daño**, un 25 % de confundir). Decidido el 2026-11-23 (opción 2: efecto nuevo en vez de reimprimir la carta). En campaña **Confundido no es el estado del TCG**: reutiliza el estado de `monedaFalloRival` (`BandoCombate.cegado`), de modo que, con cara, en su próximo turno el Defensor, **si ataca**, lanza una moneda y con cruz ese ataque no hace nada (la energía se gasta igual). Dura **solo ese turno** y no se acumula; no hace daño al propio Pokémon. Con cruz en la moneda del ataque no pasa nada. La IA no lo tiene en cuenta (igual que Bofetón Lodo). **Hecho el 2026-11-23 (tarea 15):** en `_atacar`, después del daño y de las monedas del propio ataque, se lanzan las `monedas` con la semilla del combate y quedan en `ultimasMonedas`; si todas son cara, el Defensor queda con `BandoCombate.cegado`. `monedas` es 1 si no se pone y no puede ser 0. Simulador (duelos): Zubat 38,6 %, igual que antes, porque la IA no usa Supersónico (0 de daño); Slowpoke sube de 77,3 % a 87,5 % con Hidropulso.
- **`drenaDefensor` (Drenadoras de Ivysaur), nuevo y pendiente de implementar:** «Mientras el Pokémon Defensor siga en el Puesto Activo. Durante el Chequeo Pokémon pon 1 contador de daño sobre él. Si lo haces, tu Pokémon Activo se cura 10 puntos de vida.» Coste 2 y 0 de daño. Es el veneno (`envenenaDefensor`, 10 PS por chequeo, 20 por ronda, mientras siga activo, sin acumular) más una cura de 10 PS al **Pokémon activo de quien lo usó en ese momento** (no tiene por qué ser Ivysaur), hasta su máximo, y solo si el chequeo hizo daño. **Aviso de balance:** son unos 20 de daño y 20 de cura por ronda por 2 energías, más que el veneno de Kakuna (que además pega 10); Calidad debe medirlo y, si es excesivo, se limita la cura al primer chequeo o se baja a 5 PS (y se reimprime). Pendiente de motor, IA y simulador.
- **`paralizaDefensor` (Dragoaliento de Charmeleon), nuevo y pendiente de implementar:** «Lanza 3 monedas. Si sale Cara en al menos 2 de ellas, el Pokémon Defensor pasa a estar Paralizado.» Decidido el 2026-11-23 por Ayme: **Paralizado** = el Defensor **no puede atacar ni cambiar de Pokémon**, **solo durante su próximo turno** (se quita al acabarlo; no se acumula). Es un 50 % de salir; la Cuerda Huida (§10.6) permite cambiar aun así. Dragoaliento hace 50 de daño con coste 3. Pendiente de motor, IA y simulador.
- **`monedaFalloRival` permanente (Pantalla de Humo de Charmeleon):** «Mientras el Pokémon Defensor siga en el Puesto Activo. Cada vez que use un Ataque, lanza una moneda. Si sale Cruz el Ataque no se lleva a cabo.» Decidido el 2026-11-23 por Ayme: se queda la carta tal como está. Es el efecto de Bofetón Lodo (arriba) con una opción `mientrasActivo`: en vez de durar un turno, dura **mientras el Defensor siga activo** (se quita al cambiarlo o cuando cae). Criterio: el ataque que hace daño (Bofetón Lodo) dura un turno; el que **no hace daño** (Pantalla de Humo, como Gruñido o Fortaleza) dura mientras siga activo. Más fuerte que Gruñido; hay que medirlo con el simulador (si es demasiado, se sube el coste o se limita a dos turnos, y se reimprime).
- **`monedaDanoExtra` (Hiper Colmillo de Rattata):** «Lanza una moneda, si sale cara este ataque hace 20 puntos de daño más.» Decidido el 2026-11-21: **el azar entra en el motor**, pero sin perder el determinismo. `EstadoCombate.semilla` (generador Park-Miller, mismas cuentas en la VM y en web) avanza solo al lanzar una moneda, y el resultado queda en `EstadoCombate.ultimaMoneda` para que la interfaz lo muestre. El `dano` de la carta es el de **cruz**; con cara se le suma el extra al daño base, antes de reducciones, debilidad y resistencia. La semilla se elige al empezar el combate (`EstadoCombate.inicial(semilla: …)`); con la misma semilla y las mismas acciones el combate sale igual, así que los tests y el simulador siguen siendo reproducibles. La IA **cuenta solo el daño de cruz** (no apuesta a la moneda) al decidir.
- **Habilidades pasivas — `monedaDanoExtraAlAtacar` (Foco Energía de Mankey y de Machop):** «Mientras este Pokémon esté en el Puesto Activo. Cada vez que ataque, lanza una moneda. Si sale cara, ese ataque hace 20 puntos más.» Decidido el 2026-11-22. Es la primera **habilidad**: va en el campo `habilidad` de la carta (`PokemonCampana.habilidad`), no en un ataque, y actúa sola, sin gastar energía ni turno. En `_atacar` se lanza una moneda más con la semilla del combate (se suma a `ultimasMonedas` después de las del propio ataque) y con cara se suman 20 al daño base, antes de reducciones, debilidad y resistencia. Se acumula con la moneda de Golpe Kárate (hasta +40). La IA no cuenta esta moneda: decide con el daño base del ataque. Mankey queda en 70 PS, debilidad psíquico y retirada 1 (después 0, el 2026-11-23).
- **`repiteDanoAlDerribar` (Doble Patada de Nidoran♀):** «Si el Pokémon Defensor queda fuera de combate por el daño de este ataque, el nuevo Pokémon Defensor recibe de nuevo ese daño.» Decidido el 2026-11-21. Si el ataque derriba al activo rival y le quedan Pokémon, el motor guarda el ataque (`EstadoCombate.repetirDano`) y, **en cuanto el rival elige a su relevo**, ese relevo lo recibe otra vez, calculado contra **su propia** debilidad y resistencia. Se repite **una sola vez**: si el relevo también cae, no se encadena. Si era el último Pokémon, el combate termina por el primer golpe. La IA no lo tiene en cuenta.
- **Nuevo tipo `oscuridad`:** Nidoran♀ es de tipo oscuridad (los Pokémon de veneno pasan a este tipo en el TCG). Es otro paso para alinear los tipos con el TCG, junto con la decisión de que tierra y roca son lucha.
- **`monedasDano` (Ataque Furia de Spearow):** «Lanza 3 monedas. Con 1 cara, hace 20 puntos de daño; con 2 caras, 30; con 3 caras, 40; con 0 caras, 50.» Decidido el 2026-11-21. El ataque lanza `monedas` monedas con la semilla del combate (`EstadoCombate.ultimasMonedas` guarda todas, en orden, para mostrarlas) y hace el daño de `danoPorCaras[caras]`. El `dano` del JSON es el **daño esperado** (30: 50·1/8 + 20·3/8 + 30·3/8 + 40·1/8), que solo usa la IA y el baremo; el daño real sale de la tabla. Toda tirada hace 20 o más, así que cumple la regla del ataque de 20. La IA decide con el daño esperado, no con la tirada.
- **`danoPorRacha` (Rodar de Sandshrew):** decidido el 2026-11-21. El `dano` del ataque se multiplica por las **veces seguidas** que el Pokémon lo ha usado, contando la actual: 20, 40, 60… Se reinicia si usa **otro ataque**, **carga**, **cambia** de Pokémon o cae. Estado del bando que ataca: `ultimoAtaque` y `racha`. La IA ya cuenta el daño que haría ahora (con la racha), así que lo encadena cuando supera a su otro ataque. Rodar **no lleva moneda de precisión** (en los juegos puede fallar; aquí la racha solo se rompe si el Pokémon hace otra cosa). **Texto de la carta (decidido el 2026-11-22):** «empieza haciendo 20 de daño y hace 20 más por cada vez consecutiva que se use», que coincide con el efecto implementado (20, 40, 60…).
- **`monedaFalloRival` (Bofetón Lodo de Diglett):** «En su próximo turno, si el Pokémon Defensor ataca, lanza una moneda. Si sale cruz, ese ataque no hace nada (la energía se gasta igual).» Decidido el 2026-11-21. El ataque hace su daño y marca al rival (`BandoCombate.cegado`). En su siguiente turno, **si ataca**, se lanza la moneda con la semilla del combate: cara, el ataque funciona con normalidad; cruz, **no hace nada** (ni daño ni efectos) y gasta su energía y su turno. Dura **solo ese turno**, pase lo que pase en él: si carga, cambia de Pokémon o cae, se quita. No se acumula. La IA no lo tiene en cuenta (no sabe que va a fallar la mitad de las veces) y, al estar el azar en el motor, el resultado queda en `ultimaMoneda` para mostrarlo.
- **`reduceDanoPropio` (Fortaleza de Metapod):** «Mientras este Pokémon siga activo, recibe 10 puntos menos de daño de los ataques (antes de aplicar debilidad y resistencia). No se acumula.» Es el espejo de Gruñido, pero sobre uno mismo: se pone en el bando que ataca (`BandoCombate.proteccion`), dura mientras ese Pokémon siga activo y se quita al cambiarlo o cuando cae. Se combina con Látigo sumando (+10 y −10 se compensan; `extraRecibido`) y el daño nunca baja de 0. La IA la usa con el mismo criterio que Gruñido: solo si evita más daño, en los golpes que el rival necesita para derribarla, que el que haría atacando. **Rizo Defensa de Sandshrew lleva este mismo efecto** (Ayme lo eligió así en lugar de que doblara Rodar). **Fortaleza y Gruñido se suman** (decidido el 2026-11-22): −10 de cada uno sobre el mismo golpe, como hace el motor.
- **`envenenaDefensor` (Picotazo Veneno de Weedle):** «El Pokémon Defensor pasa a estar Envenenado.» Decidido el 2026-11-21: hay un **chequeo Pokémon cada vez que cambia el turno** (tras el turno de cualquiera de los dos), y en cada chequeo el activo envenenado pierde 10 PS; es decir, 20 por ronda. Va primero el bando que acaba de jugar. Dura mientras ese Pokémon siga activo (se quita al cambiarlo, o cuando cae), no se acumula, y el ataque que envenena ya sufre el primer chequeo al acabar su turno. Estado: `BandoCombate.veneno`. Si el veneno derriba a un activo, su dueño elige relevo; si era su último Pokémon, pierde y el combate termina (si el último Pokémon de quien acaba el turno cae por veneno, pierde él, aunque el otro también fuera a caer en ese mismo chequeo). Como en esa fase puede tener que elegir el bando que **no** tiene el turno, quien pide la acción usa `EstadoCombate.actua` (en lugar de `turno`) y `debenElegir`. La IA usa el ataque que envenena siempre que el rival no esté ya envenenado (aunque el golpe quede en 0 por Fortaleza o Gruñido) y no lo repite mientras siga envenenado; no valora el veneno al cambiar de Pokémon.
- **Regla de «siempre un ataque de 20 o más» (cambio 2026-11-21):** pasa a «un ataque de 20 o más, **o** un ataque con veneno», porque Gruñido no anula el veneno. Esquema y test actualizados. Weedle lleva un único ataque de 10 con veneno.

## 4. Mapa

La campaña inicial es **Kanto** (decidido el 2026-11-21) y la estructura del mapa es la **A, «Mapa de ruta»**: un camino de nodos por el que se avanza hacia delante (Ayme la eligió entre «ruta», «capítulos por jefe» y «misiones con estrellas»). La región se recorre por **zonas** (rutas, cuevas, ciudades), como en los juegos, y cada zona define qué Pokémon salvajes aparecen y qué entrenadores hay. El recorrido es un grafo de **nodos**:

| Nodo | Qué pasa |
|---|---|
| **Inicio** | Elegir un Pokémon inicial entre tres. Hoy: Bulbasaur, Charmander y Squirtle (las tres primeras cartas que hizo Ayme). |
| **Combate** | Contra un **Pokémon salvaje** (ruta) o un **entrenador** de una zona. Al derrotar a un salvaje se pregunta si se captura: si hay hueco se une al equipo, y si está lleno se elige a quién sustituir y el descartado va al PC (§2). |
| **Bifurcación** | Sin evento: se elige por qué camino seguir. Puede ofrecer un desvío opcional o dos combates entre los que elegir. |
| **Descanso** | El **centro Pokémon**: cura el equipo, da acceso al **PC** (guarda los Pokémon que no caben en el equipo y permite cambiarlos por los del equipo), permite **evolucionar 1 Pokémon** y comprar (qué se vende, por decidir). |
| **Conversación** | Sin combate: un personaje habla con el jugador (por ejemplo, le avisa de lo que viene) y, si el nodo lo dice, **cura al equipo**. Una conversación que cura es un **punto de curación**: al perder se vuelve a ella. No da acceso al PC ni a la tienda. Decidido el 2026-11-22 (§10.7). |
| **Gimnasio** | Combate contra el líder. Da una **medalla** y puntos. |
| **Jefe** | Un **Pokémon salvaje** con su carta de la serie NN/20 (§4, Jefes). Da muchos puntos. |
| **Liga** | Tras reunir todas las medallas. **Fase 2**; no hace falta un tipo de nodo propio: es una cadena de nodos de gimnasio seguidos (decidido el 2026-11-22, §10.7). |

Estructura de una región: `Inicio → rutas → jefe del tramo → descanso → gimnasio (medalla) → rutas → jefe del tramo → … → Liga` (más jefes en rutas clave y los 4 legendarios). Hay ramas: en una bifurcación se elige por qué ruta seguir.

### Modelo de la ruta

Decidido el 2026-11-22. Una región es un **grafo dirigido sin ciclos**. Se avanza por él y, desde el 2026-11-22, **también se puede retroceder** por nodos ya visitados (§10.7; antes era solo hacia delante) (`RegionCampana`, `engine/lib/src/campana/ruta.dart`; datos en `catalog/campana/regiones/<id>.json`, esquema `region-campana.schema.json`). Cada nodo (`NodoRuta`) lleva `id`, `tipo`, `nombre`, `salidas` y los datos propios de su tipo:

| Tipo | Datos | Salidas |
|---|---|---|
| `inicio` | `iniciales` (ids de Pokémon) | 1 |
| `combate` | `zona`, `rival` (`salvaje` o `entrenador`) y, con un entrenador, su `clase` en la zona; `pokemon` opcional (los Pokémon **fijos** del rival: uno si es salvaje, su equipo si es un entrenador; sin él, sale de la zona al llegar) | 1 |
| `bifurcacion` | — (no tiene evento: solo se elige camino) | 2 o más |
| `descanso` | — | 1 |
| `conversacion` | `personaje` (quién habla), `texto` (lista de líneas) y `cura` (si cura al equipo; `false` de salida) | 1 |
| `gimnasio` | `lider` (nombre y Pokémon) y `medalla` | 1, o 0 si es el final |
| `jefe` | `jefe` (id del archivo de `jefes/`) | 1, o 0 si es el final |

- **Reglas de estructura** (las comprueba `RegionCampana.problemas()` y un test): un solo `inicio`, sin entradas; las salidas existen y no se repiten; solo una bifurcación tiene varias salidas; sin ciclos; a todos los nodos se llega desde el inicio; **la región solo acaba en un gimnasio o un jefe** (nunca en un callejón sin salida); cada tipo lleva sus datos y no los de otro; un salvaje lleva como mucho un Pokémon fijo. Varios nodos pueden llevar al mismo (las ramas se juntan).
- **Nodos opcionales:** `opcional: true`, solo en un combate o un descanso. Es un desvío: siempre se puede llegar a todos los nodos obligatorios **sin pasar por ninguno opcional**, así que una bifurcación ofrece el desvío o seguir de largo (los dos caminos se juntan después).
- **Reglas de diseño** (un test las comprueba sobre los datos de Kanto, no son del motor): entre una medalla y la siguiente, y desde el inicio hasta la primera, hay **un jefe** y **al menos una bifurcación**. Ayme: «entre medallas de gimnasio tiene que haber 1 [jefe] y, en rutas clave, también».
- **Qué rival toca:** el nodo de combate dice la zona y si es salvaje o entrenador; si no fija el Pokémon, lo elige el combate con la semilla de la partida (tarea 6, captura). El gimnasio usa los Pokémon del líder en orden.
- **Cruce con el catálogo** (`problemasDeCatalogo`, también con test): los Pokémon, zonas, clases de entrenador y jefes que nombra un nodo existen, y un Pokémon fijo es de la zona (si es salvaje) o de la clase (si es de un entrenador).
- **Escenas** (#413; la pantalla se decidió el 2026-11-22, §10.7). Cada nodo lleva `escena` con una `imagen` (un id: la app busca `app/assets/campana/escenas/<imagen>.webp` y, mientras Arte no la entrega, pinta `marcador.svg`) y una lista de `zonas` pulsables. Cada zona es un rectángulo con `x`, `y`, `ancho` y `alto` **relativos a la imagen (0 a 1**, 0,0 arriba a la izquierda) y una `accion`: `ir` (un borde, con `destino`), `combate` (hierba alta, entrenador, líder o jefe), `inicial`, `hablar`, y en el centro `curar` (mostrador), `tienda` (estantería) y `pc`. Varios nodos pueden compartir imagen: Kanto usa **9** (pueblo-paleta, ruta-1, centro-pokemon, ciudad-verde, ruta-22, ruta-2, bosque-verde, ruta-2-norte y gimnasio-plateada). `problemasDeCatalogo` comprueba también, con `problemasDeEscenas`, que todo nodo tiene escena con imagen, que cada zona cabe en la imagen y tiene tamaño, que una zona `ir` lleva a un **nodo vecino** que existe (una salida o una entrada, para poder volver atrás, #412), que **cada salida tiene su zona** (así ningún nodo se queda sin acceso) y que están las acciones de su tipo (inicio: `inicial`; combate, gimnasio y jefe: `combate`; conversación: `hablar`; centro: `curar`, `tienda` y `pc`). Las coordenadas de hoy son de marcador: entradas en el borde izquierdo, salidas en el derecho y la acción en el centro; las cambian Arte y Diseño al ilustrar cada escena.

**Progreso** (`ProgresoRuta`, es lo que se guarda en el dispositivo, §6): nodo actual, si está resuelto, nodos superados, medallas, jefes derrotados y el inicial elegido; con `aJson`/`desdeJson`. Es inmutable y avanza con tres operaciones: `resolver` (da por hecho el nodo: elegir inicial, ganar el combate, usar el descanso; un gimnasio da su medalla y un jefe queda anotado como derrotado), `opciones` (a dónde se puede ir: nada hasta resolver) y `avanzar(destino)`, que solo admite una salida del nodo actual ya resuelto. Una bifurcación se da por resuelta al llegar. **Retroceso** (#412, decidido el 2026-11-22, §10.7): `retroceder(destino)` vuelve a cualquier nodo de `visitados` (los nodos en los que ya se ha estado, que se guardan; en una partida anterior, los superados y el actual). Un nodo superado se queda resuelto al volver o al pasar otra vez por él, así que sus combates no se repiten; la excepción son los **salvajes**: `repetir()` vuelve a abrir el combate de un salvaje ya ganado (`repitiendo` en el guardado). `puedeCapturarJefe` dice si el jefe se captura (solo la primera vez, §4 Jefes). Al perder se vuelve al último punto de curación (§10.2); aún sin implementar.

### Primer tramo: Pueblo Paleta → Ciudad Plateada

Recorrido que Ayme definió el 2026-11-21 y que recoge `catalog/campana/regiones/kanto.json` (corregido el 2026-11-22: la primera versión, #355, no lo seguía):

| # | Nodo | Qué pasa |
|---|---|---|
| 1 | **Pueblo Paleta** | Elegir inicial. |
| 2 | **Ruta 1** (bifurcación) | Hay que elegir entre un **Pidgey** y un **Rattata** salvajes. |
| 3 | **Ciudad Verde** | Centro Pokémon, de presentación. |
| 4 | **Ruta 22** (desvío **opcional**) | Un salvaje de la Ruta 22, que da puntos. |
| 5 | **Ruta 2 sur** (bifurcación) | Elegir entre un **Weedle** y un **Caterpie** salvajes. |
| 6 | **Bosque Verde** | Dos **Cazabichos**; justo antes del jefe, **otro Cazabichos avisa** sin combatir de que Pikachu se come la comida de los demás Pokémon y se ha hecho más fuerte, y **cura al equipo** (2026-11-22); después, el primer jefe, **Pikachu** (01/20). |
| 7 | **Ruta 2 norte** (bifurcación) | Un salvaje **opcional**, o seguir directo. |
| 8 | **Ciudad Plateada** | Centro Pokémon, y el **gimnasio**: el **Entrenador Joven** (Diglett y Sandshrew, como en los juegos) y **Brock** (Geodude y Onix), que da la medalla Roca. |

Zonas del catálogo: `ruta-1` (Pidgey, Rattata), `ruta-2` (Rattata, Pidgey, Caterpie, Weedle), `bosque-verde` (salvajes Caterpie, Weedle, Metapod, Kakuna y Pikachu; entrenadores Cazabichos), `ruta-22` (Rattata, Spearow, Nidoran♀, Nidoran♂, Mankey), `gimnasio-plateada` (sin salvajes; Entrenador Joven) y `tunel-roca`. Las listas de salvajes salen de los juegos (Rojo y Azul) y **están por contrastar con Serebii o Bulbapedia**.

### Reglas del recorrido

Decididas por Ayme el 2026-11-21 al definir el primer tramo:

- Los **PS se restauran al máximo entre combates**.
- Las **Pociones solo se usan fuera de combate**.
- **Derrotar Pokémon da XP** y se elige a quién se la das. (Ver la pregunta abierta de §8 sobre cómo encaja con la conversión de puntos en XP de §2.1.)
- Los **entrenadores dan dinero**: cada clase y cada líder lleva su cifra en el catálogo (§10.6).
- **Capturar es opcional** (quizá con Pokéball, por decidir).
- **Cada combate da puntos una sola vez.**

### Partida de campaña

Hecho el 2026-11-22 (tareas 6, 8 y 9, primera versión). `PartidaCampana` (`engine/lib/src/campana/partida.dart`) junta el progreso de la ruta, el **equipo** (con los PS actuales), la **reserva común de XP** (#403), el **PC**, los **puntos**, el **dinero**, la **mochila** y la semilla. Es inmutable, se guarda en JSON (con versión) y las cifras sin cerrar están todas en `ParametrosCampana`.

- **Rival de cada nodo:** el salvaje sale al azar de la zona con la semilla de la partida; un entrenador sin equipo fijo en el nodo saca **2** Pokémon de su lista (suposición); el gimnasio, los del líder en orden; el jefe, su carta NN/20 con su **llamada de aliado** (#372): el aliado entra en el combate, no se captura y no cuenta como rival derrotado para la XP si sigue en pie (si cae, suma la XP de su categoría). Si el nodo fija el Pokémon (`pokemon` en `kanto.json`), sale ese; si no, sale de la zona o de la clase de entrenador con la semilla.
- **PS entre combates:** el daño se arrastra de un combate a otro y la energía vuelve a 10 al empezar cada combate (decidido por Ayme el 2026-11-22). Solo cura el centro Pokémon o una Poción.
- **Captura:** al vencer a un salvaje, o a un jefe la primera vez (su carta normal, `pikachu-jefe` → `pikachu`), se ofrece capturarlo (decidido el 2026-11-22, §10.6; hecho en #368). `lanzarBall(ball)` gasta **1 Ball** salga lo que salga y tira la moneda con la semilla de la partida, que avanza (es determinista): cara si `semilla % 1000` es menor que la probabilidad en tanto por mil (`probabilidadCaptura`: Común 75/100/100 %, Intermedio 50/75/100 %, Fuerte 25/50/75 % y Jefe 12,5/25/50 % con Pokéball, Super Ball y Ultra Ball). Con cruz se vuelve a lanzar mientras queden Balls, sin tope; sin Balls, el combate acaba sin captura («Seguir»). La categoría es la de la carta del salvaje o, en un jefe, la de la carta del JSON del jefe (`pokemon.categoriaCaptura`) o Jefe si no la lleva; **Pikachu jefe** es Común con `capturaAsegurada` (cara siempre, pero gasta su Ball). En la **Ruta 1** se puede capturar, pero la mochila de salida no lleva Pokéballs: la primera tienda es el centro de Ciudad Verde, y desde allí se puede volver atrás a capturar (corregido el 2026-11-23, §10.9). El campo `captura` de la zona sigue existiendo (por defecto `true`), aunque hoy ninguna zona lo pone a `false`. Un jefe que se deja ir ya no se captura. Con cara, la partida guarda `capturaLograda` y queda elegir dónde va. Hay hueco: entra al equipo; equipo lleno: se elige a quién mandar al PC, o va al PC el capturado.
- **Derrota** (decidido el 2026-11-22): se vuelve al **último sitio donde se curó** el equipo (el inicio, el último centro Pokémon usado o la última conversación que curó, como el aviso antes de Pikachu; una Poción no cuenta), con el equipo curado. Se conserva lo ganado: capturas, puntos, dinero, XP y medallas. Los nodos de después que ya se ganaron no se repiten (#412; antes había que volver a pasarlos): se cruzan resueltos, y un salvaje solo se repite si el jugador quiere.
- **XP y dinero** (decidido el 2026-11-22): la XP se gana al derrotar Pokémon y va a una **reserva común** (§10.6, hecho en #403): cada rival derrotado suma la de su **categoría de captura** (`categoriaCaptura`: Común 10, Intermedio 20, Fuerte y Jefe 30; el jefe puede llevar `xp` propio, Pikachu jefe 30). Perder un combate no da XP. Desde el **menú del equipo** se evoluciona gastando de la reserva (`xpEvolucion`: 50 para Caterpie y Weedle) y el Pokémon queda con 10 PS, también si estaba debilitado. El **dinero** se gana al vencer a entrenadores y líderes, con la cifra de cada clase y de cada líder en el catálogo (`dinero` en la clase de la zona y en el `lider` del nodo; decidido el 2026-11-22, §10.6, hecho en #402): Cazabichos 200 cada uno, Entrenador Joven 260 y Brock 1.400. Los salvajes y los jefes no dan dinero. Se empieza con **1.000**. El catálogo avisa si un entrenador o un líder de la región no tiene `dinero`.
- **Tienda del centro Pokémon** (decidido el 2026-11-22, §10.6, hecho en #402): cada centro lista en su nodo lo que vende (`tienda`); en el primer tramo, **solo Pokéball (200) y Poción (300)**. Los precios son los de los juegos: Pokéball 200, Super Ball 600, Ultra Ball 1.200, Poción 300 y Repelente 350. La **Super Ball** pide además 1 medalla y la **Ultra Ball** 5, aunque el centro la liste. Poción: cura 20 PS a un Pokémon en pie, fuera de combate, sin revivir. Repelente (llega después del primer tramo): evita un combate contra un salvaje, sin puntos, XP ni captura. Las Balls ya se compran, pero capturar con ellas es #368. Curar en el centro es gratis y sin límite, también a los debilitados.
- **Puntos** (provisionales): salvaje 100, entrenador 200, jefe 1000 (la primera vez), medalla 1500. Se guardan en el dispositivo; todavía no se envían al servidor (tarea 10).
- **App:** «Nueva partida → Modo campaña» abre el mapa (`app/lib/campana/`). Pantallas: mapa con la ruta y el nodo actual, elección de inicial, combate (la máquina responde al momento y hay un registro de lo que pasa), captura, equipo (ordenar, Poción), centro Pokémon (curar, tienda, PC). La partida se guarda en el dispositivo tras cada cambio (`shared_preferences`, clave `campana_kanto`); un combate a medias no se guarda y, al volver, empieza de nuevo contra el mismo rival.

### Jefes

Decidido el 2026-11-21. Los jefes son **Pokémon salvajes**, no entrenadores: los líderes de gimnasio y el Alto Mando no son jefes y usan cartas normales (el Geodude y el Onix de Brock, por ejemplo). Tienen una **serie propia de 20 cartas, NN/20** (la carta de Pikachu lleva impreso 01/20), distinta de la 001/150 de los Pokémon:

- **01–08, uno por tramo**, entre una medalla y la siguiente (Pikachu es el primero, antes de Brock).
- **09–16, rutas clave.** Plazas abiertas: las que sobren se quedan libres sin renumerar.
- **17–20, los cuatro legendarios:** Articuno, Zapdos, Moltres y Mewtwo. Mew queda fuera (es la 151/150, secreta).

Lista propuesta (solo el total y Pikachu están cerrados; el resto puede cambiar): 01 Pikachu, 02 Clefairy, 03 Dugtrio, 04 Marowak, 05 Kangaskhan, 06 Lapras, 07 Muk, 08 Gyarados, 09 Snorlax, 10 Electrode, 11 Dodrio, 12 Golem, 13 Alakazam, 14 Aerodactyl, 15 Scyther, 16 Dragonite, 17 Articuno, 18 Zapdos, 19 Moltres, 20 Mewtwo.

**Combate:** es un 1 contra 1 con el mismo motor y la misma IA. **Capturable** (decidido el 2026-11-21): al derrotarlo se ofrece la carta **normal** del Pokémon (la 025/150 en el caso de Pikachu, con 60 PS), no la del jefe, con las mismas reglas de equipo y PC que cualquier captura (§2). **Solo se captura la primera vez**: si se repite el jefe, ya no se puede volver a capturar. **Los aliados que llama el jefe no se capturan.** Los puntos del jefe se dan solo la primera vez. Si lleva `llamaAliado`, la llamada va **en dos pasos** (decidido el 2026-11-22, §10.8). Al **llegar a `alBajarDePorcentaje`** de sus PS o bajar de él (Pikachu: 50 %; con 50 PS justos ya llama), el jefe **invoca** a un **aliado elegido al azar** con la semilla del combate (Pikachu: Weedle, Caterpie, Metapod o Kakuna), que aparece **en la banca**. Al **llegar a `alFrenteAlPorcentaje`** (Pikachu: 40 %), el jefe se retira a la banca y el aliado pasa al **puesto activo**. Así, unos ataques solo lo invocan y otros, los que cruzan los dos umbrales de un golpe, lo ponen delante directamente. Cuando el aliado cae, **vuelve el jefe con los PS que tenía**. Más detalles: cuenta **cualquier daño**, también el del veneno (se comprueba al acabar cada turno, tras el chequeo Pokémon); si el golpe lo deja a 0, no llama, porque ya está derrotado; llama **una sola vez por combate**; al retirarse **pierde todos sus efectos**, también los propios como Fortaleza (mientras el aliado solo espera en la banca, el jefe los conserva); el aliado juega con la misma energía del bando; ni el aliado que espera ni el jefe retirado pueden salir con «Cambiar»; y **se gana cuando cae el jefe**: aunque caiga el aliado no se gana, y si el jefe cae con el aliado en la banca, se gana igual. En el motor: `LlamadaEnCombate` (`EstadoCombate.inicial(llamadaRival: …)`, que se construye desde el catálogo con `llamadaEnCombate(jefe, pokemon)`), `EstadoCombate.aliado` (posición del aliado en el equipo rival, para que la captura lo excluya), `EstadoCombate.aliadoAlFrente` y `BandoCombate.enEspera`. El campo `alBajarDePorcentaje` conserva su nombre aunque basta con llegar; sin `alFrenteAlPorcentaje`, el aliado entra directamente al invocarlo. Los PS de los jefes pueden salirse de la tabla de §3.5, pero su daño es el de su fase. Los datos están en `catalog/campana/jefes/*.json`.

**Pikachu (01/20):** 100 PS, eléctrico, debilidad lucha ×2, sin resistencia, retirada 0. Ataque Rápido (1, 10) e Impactrueno (2, 30). Estimación de dificultad: unos 20 de daño por turno, de modo que el inicial aguanta 4–5 turnos; se calibrará con el simulador. La llamada de aliado está en el motor desde #372.

## 5. Puntos y tienda

- La campaña da puntos por **victoria en combate**, por **medalla** y por **jefe**, más una cantidad menor por ruta superada (las cifras son provisionales y se ajustan al final; solo importan si hay compras dentro de la campaña).
- Los puntos van a la **cuenta** (hace falta sesión) y se gastan en la **tienda** de la pantalla de inicio: monedas, dados, sobres y cartas sueltas del formato digital.
- Aparte de los puntos, los entrenadores dan **dinero** (decidido el 2026-11-21, sin más detalle): qué es, para qué sirve y cómo se relaciona con los puntos está por definir (§8).
- Compras dentro de la campaña (el descanso), la **XP de evolución** y la evolución por intercambio o a ex se pagan con los mismos puntos, y lo que sobra al terminar se conserva. Gastar puntos en evolucionar es renunciar a gastarlos en la tienda.

## 6. Cómo encaja en el proyecto

| Pieza | Propuesta |
|---|---|
| Motor | Librería `engine/lib/campana.dart` (código en `engine/lib/src/campana/`), con el mismo patrón que la partida: estado inmutable y reductor puro, `aplicarCombate(estado, acción)`. No toca el motor de las incursiones. **Hecho:** combate 1 contra 1 con energía, atacar, cambiar, cargar, elegir siguiente, debilidad y resistencia (#336); IA rival (#338); efectos, habilidades y azar con semilla (#350, #352); modelo de ruta y progreso (#354). Llamada de aliado del jefe (#372). **Pendiente:** captura y equipo, descanso. |
| Catálogo | `catalog/campana/`: `pokemon/*.json` (uno por Pokémon, con su número de la Pokédex), `zonas/*.json` (qué aparece en cada zona), `regiones/*.json` (el grafo de nodos de la ruta) y sus esquemas en `catalog/schema/`. El JSON manda, como con los jefes. |
| Simulador | `sim/` simula combates y rutas de campaña para equilibrar PS, costes de energía y la IA rival. |
| Guardado | Progreso de campaña (región, nodo, equipo, **PC**, jefes ya capturados, medallas, reserva de XP, puntos pendientes) **en el dispositivo**, sincronizado con la cuenta al iniciar sesión. Es un esquema **aparte** del contrato de partida. `ProgresoRuta` ya guarda lo de la ruta (nodo, superados, medallas, jefes derrotados, inicial) con `aJson`/`desdeJson`; `PartidaCampana` guarda además el equipo, el PC y la reserva de XP. |
| Servidor | Recibe los puntos ganados al terminar un jefe o una medalla. Al ser un solo jugador y coste 0, se acepta lo que reporta el cliente con un tope por hito (no hay competición). |
| App | Pantallas nuevas: mapa de región, combate, equipo, descanso y tienda. Reutiliza los fondos de mesa por mapa y los avisos. |

`flujo-app.md` se corrige en este mismo cambio: la campaña **ya no** entrega las cartas de la partida libre digital, y «Mis cartas» deja de depender de ella.

## 7. Primera entrega

**El primer set tendrá los 151 Pokémon de Kanto, pero se rellena por zonas:** de cada zona solo entran los Pokémon que aparecen en ella.

**Cambio de rumbo (2026-11-21):** la primera entrega iba a ser una zona suelta, el Túnel Roca con Onix de jefe. Ayme la sustituyó por **una porción vertical de Kanto: el primer tramo, de Pueblo Paleta a Ciudad Plateada** (§4), con los Pokémon que él crea a mano (§11), que además sirven para el simulador. Las cartas y la zona del **Túnel Roca** que ya estaban hechas (Zubat, Geodude, Machop, Onix, Cubone y Slowpoke) se mantienen en el catálogo; la zona todavía lista a Onix como jefe, lo que ya no cuadra con la decisión de que los jefes son salvajes de la serie NN/20, y cuándo entra en el recorrido está por decidir (§8).

Contenido de la primera entrega:

- Los tipos del motor, alineados con el TCG (§3.3; qué hacer con los que sobran está en §8).
- Esquema JSON de Pokémon, de jefe, de zona y de región, y su carga en el motor (**hecho**).
- Combate completo con energía, cambio de Pokémon, IA rival y victoria o derrota (**hecho**; al perder se vuelve al último punto de curación).
- El recorrido del primer tramo, con su jefe y su gimnasio (**hecho y jugable en la app**).
- Captura, equipo, PC y descanso (**primera versión hecha**, §4 Partida de campaña).
- Guardado local del progreso (**hecho**).

Fuera de la primera entrega: el resto de las zonas y los 151 completos, Liga, tienda, sincronización con la cuenta y los combates 2 contra 2 y 3 contra 3. (La llamada de aliado ya está, #372.)

## 8. Preguntas abiertas

Lo que **no** está decidido. En cuanto Ayme responde una, pasa a §10 con su fecha.

**Reglas del juego**

3. ~~Cómo se captura~~ **Decidido el 2026-11-22** (§10.6): Pokéball con moneda y categoría de captura.
4. **Qué se vende en el descanso.** En el primer tramo, solo Pokéball y Poción (§10.6); falta decidir el resto (Repelente, Super y Ultra Ball, objetos, Pokémon) para los tramos siguientes.
5. **Dinero.** Cerradas las cifras del primer tramo (§10.6); falta decidir para qué sirve el dinero frente a los puntos y las cifras de los tramos siguientes.
6. **Cifras de progresión.** La XP de cada rival y el coste de evolucionar a fase 1 están **decididos** (§10.6) y hechos en #403 (los puntos ya no se convierten en XP). Falta el `xpEvolucion` de las demás fases cuando tengan carta, y cuánto cuestan el intercambio y hacerse ex.
7. **Qué dan y qué cuestan las cartas ex** (más PS y ataques más fuertes, con otro coste de energía) y cuántas fases tiene cada cadena (por ejemplo, Machop → Machoke → Machamp ex). Todavía no hay ninguna carta evolucionada ni ex.
8. ~~Liga~~ **Decidida el 2026-11-22** (§10.7): cinco rivales seguidos, tres Pokémon cada uno, un centro solo a la entrada. Es fase 2; faltan las cartas de sus rivales y las cifras de dinero y puntos por rival.
9. **Combates 2 contra 2 y 3 contra 3.** Futuro, sin diseño.

**Tipos**

10. ~~Tipos que no existen en el TCG~~ **Decidido el 2026-11-22** (§10.3): `veneno` pasa a `oscuridad`, `bicho` a `planta`, `volador` a `normal`, `fantasma` a `oscuridad` y `hielo` a `agua`, y se añade `metal` al enum. **Hecho (#404).** Falta decidir el color y el icono de `metal` en la app (de momento lleva un gris provisional).

**Cartas y catálogo**

12. **Spearow.** Con 0 caras hace 50 (así lo dice la carta: la tirada peor es la que más daño hace). Se señaló como inusual y se dejó como está impreso.
13. **Nidoran♂.** Su carta lleva impreso 029/150, que es el número de la hembra; el catálogo guarda 32 (número de la Pokédex). Falta saber si se reimprime.
14. **Jefes 02 a 16.** La lista de §4 es una propuesta mía; solo está cerrado el total (20), el 01 (Pikachu) y los cuatro legendarios.
15. **Túnel Roca.** La zona sigue listando a Onix como jefe y no tiene sitio en el recorrido; hay que rehacerla (el jefe de la zona es un salvaje de la serie NN/20) y decidir en qué tramo entra.
16. **Listas de Pokémon por zona.** Las de Ruta 1, Ruta 2, Bosque Verde, Ruta 22 y el gimnasio de Ciudad Plateada salen de los juegos Rojo y Azul **por contrastar con Serebii o Bulbapedia**.
17. ~~Campo `rareza`~~ **Sustituido el 2026-11-22** (§10.6) por el campo `categoriaCaptura` (Común, Intermedio, Fuerte o Jefe), que aún no existe en el esquema ni en el motor (#368).
18. **Más Pokémon.** El tramo de Pueblo Paleta a Ciudad Plateada está completo (la lista de Ayme se acabó el 2026-11-22), pero los 151 y el resto de zonas no: la creación de cartas es manual y es el cuello de botella.

**Equilibrado y producto**

19. **Calibrar con el simulador.** (El plan B si Brock sale por debajo del objetivo es evolucionar un inicial antes de Brock, opcional, §10.6.) Objetivo fijado (75 %, §10.5) y medido en `balance/informes/campana_calibrar_2026-11-22.md` (#383): con un equipo realista (inicial + 3 capturas) las rutas, los Cazabichos, Pikachu y el Entrenador Joven pasan del 90 %, pero **Brock** se queda en el 0–7 % y el tramo entero en el 0–7 %; con la llamada de aliado (#393), Pikachu baja al 69–99 % con inicial + 3 y al 26–79 % con inicial + 2, porque el equipo llega tocado del Bosque Verde; solo con el inicial sale al 0 %. Falta que Ayme elija qué se ajusta (el informe propone palancas) y con qué cifras.
20. ~~Llamada de aliado~~ **Hecha (#372)**, con los detalles decididos el 2026-11-22 (§10.8). Decidido además que el jefe pierde **todos** sus efectos al irse a la banca, también los propios.
21. **Capacidad del PC.** Ilimitada por ahora; se revisará si hace falta un tope.
22. **Pantallas de la app** (mapa de región, combate, equipo, descanso) y **tienda**: sin diseño. Se propone hacer varias propuestas visuales antes de implementar (como en el resto de la app).
23. **Kanban.** Las tarjetas del GitHub Project (`users/Ayme-99/projects/10`) no se pueden comprobar ni mover desde las sesiones de trabajo (la API del proyecto está bloqueada), y las issues #334 a #354 siguen abiertas aunque su PR ya está fusionado.
24. **Medallas y líderes de gimnasio** (#416). Las medallas y los líderes de Kanto no existen en estilo Escarlata y Púrpura. **Decidido el 2026-11-22 por Ayme: las medallas serán las de Pokémon: Let's Go, Pikachu! y Let's Go, Eevee! (LGPE)**, de WikiDex: https://www.wikidex.net/wiki/Categor%C3%ADa:Sprites_de_medallas_de_Kanto (enlace para dárselo al artista). **Pendiente:** los líderes de gimnasio; **Ayme los mandará más adelante** (2026-11-22).
25. **Dormido.** No existe en campaña todavía (decisión de Ayme del 2026-11-23: dejarlo programado o programarlo cuando aparezca un Pokémon que lo cause). Hay que decidir cuál de las dos cosas (#436).
26. ~~Cuerda Huida: ¿gasta el turno?~~ **Decidido el 2026-11-23 por Ayme: sí gasta el turno** (como cambiar, §3.2) **y ahorra la energía de la retirada**. Se revisa con el simulador si resulta poco útil (#437). Falta decidir en qué tramo se vende.
27. **Pociones en combate.** Hoy solo se usan desde la pantalla de equipo; hay que decidir si también en combate (#435).

Resueltas (se dejan para no repetir la pregunta; los números de arriba no se renumeran): derrota → vuelves al último punto de curación; Fortaleza y Gruñido → se suman; texto de Rodar → 20 más por cada uso consecutivo; máximo de Pokémon en el equipo → 6; cuántos ataques → 1 a 2; PC → ilimitado por ahora; si las cartas de campaña valen en la partida libre → no; qué primer tramo → Pueblo Paleta a Ciudad Plateada; si los jefes son capturables → sí.

## 9. Tareas derivadas

Una issue por pieza; cada una se trabaja en su rama y su PR (el título del PR cita la issue). Las issues anteriores a #356 siguen abiertas aunque su trabajo esté fusionado (§8, pregunta 23).

| # | Tarea | Estado |
|---|---|---|
| 1 | Catálogo de campaña: esquema y primeros Pokémon (#340) | Hecho |
| 2 | Motor de combate 1 contra 1: energía, acciones, debilidades y resistencias (#336) | Hecho |
| 3 | IA rival determinista (#338) | Hecho |
| 4 | Simulador de combates de campaña (#342) y **primer equilibrado** (#383) | Simulador hecho; informe hecho; ajuste de cartas pendiente de decisión |
| 5 | Modelo de región y de nodos, y avance por el mapa (#354) | Hecho |
| 6 | Captura, equipo, PC y descanso | **Primera versión hecha** (§4, Partida de campaña); falta la Pokéball |
| 7 | Jefe con aliados (llamada a mitad de combate, #372) y medalla | Llamada hecha |
| 8 | Guardado de progreso de campaña en el dispositivo | Hecho (sin sincronizar con la cuenta) |
| 9 | Pantallas de la app: mapa, combate, equipo, descanso | **Primera versión hecha**, funcional y sin diseño visual definitivo |
| 10 | Puntos al servidor y tienda (después de la porción vertical) | Pendiente |
| 11 | Reponer el resto de Pokémon y zonas (Túnel Roca, Ciudad Plateada en adelante) | Pendiente |
| 12 | Tipos del TCG: `hielo`, `veneno`, `volador`, `bicho` y `fantasma` pasan a otros tipos y entra `metal` (§8, pregunta 10; §10.3) | Hecho (#404) |
| 13 | Pantalla del mapa como escenas interactivas (hierba alta, bordes y edificios pulsables) y retroceso entre escenas; sprites de EP, e interfaz y fondos propios (#365; §10.7); combate (tocar la carta activa y elegir acción) equipo (rejilla de cartas, PC aparte) y centro Pokémon (escena interactiva) (§10.7) | Decidido el 2026-11-22; pendiente de implementar. Wireframes cerrados; el acabado visual es del artista (§10.10) |
| 14 | **Pulimento de Geodude:** efecto `ganaEnergia` (esquema, motor, IA), actualizar `geodude.json` a la carta impresa (§10.5) y volver a medir a Brock con el simulador | Motor, IA, esquema y `geodude.json` **hechos**; la nueva medida de Brock queda para Calidad |
| 15 | **Supersónico de Zubat e Hidropulso de Slowpoke:** efecto `confundeDefensor` con campo `monedas` (esquema, motor, IA), actualizar `zubat.json` y `slowpoke.json` a sus cartas impresas (§10.5; el test «Zubat es de oscuridad y Ataque Ala es normal» cambia) y volver a medir con el simulador | **Hecho**: esquema, motor, `zubat.json` y `slowpoke.json`; la IA no lo usa (no se rompe). Duelos: Zubat 38,6 % (igual), Slowpoke 87,5 % (antes 77,3 %) |
| 16 | **Evoluciones de los iniciales:** efectos `drenaDefensor`, `paralizaDefensor` y la opción `mientrasActivo` de `monedaFalloRival` (esquema, motor, IA); `ivysaur.json`, `charmeleon.json` y `wartortle.json` a las cartas impresas (§10.5); `evoluciones` en Bulbasaur, Charmander y Squirtle (`via: xp`, `xpEvolucion` 70, `medallasMinimas` 0); y volver a medir con el simulador | Pendiente (#439) |

## 10. Registro de decisiones

Todo lo que Ayme ha decidido sobre el modo campaña, en orden temático y con su fecha. Si una decisión sustituye a otra, la antigua aparece en §10.9. «Dónde» dice qué documento, código o PR lo recoge. Lo que **no** está decidido está en §8.

### 10.1 Producto y alcance

| Fecha | Decisión | Dónde |
|---|---|---|
| 2026-11-21 | El modo campaña es un **juego de Pokémon para un jugador**, ajeno a la partida libre: sus Pokémon **no** se usan en las partidas rápidas, pero dan puntos para la tienda. (Resolvió la pregunta abierta de si las cartas de campaña valían en la partida libre digital.) | §1; `flujo-app.md` |
| 2026-11-21 | Estilo de juego «RPG»: cartas con PS, daño y costes de energía, retirada gratis de salida y un equipo de hasta X cartas. | §2 |
| 2026-11-21 | Estructura del mapa **A, «Mapa de ruta»** (camino de nodos por región), entre «ruta», «capítulos por jefe» y «misiones con estrellas». | §4 |
| 2026-11-21 | Combate **1 contra 1** por ahora; 2 contra 2 y 3 contra 3 quizá en el futuro. | §3, §8 |
| 2026-11-21 | La campaña inicial es **Kanto**; el Túnel Roca es solo una zona. El primer set tendrá los 151 Pokémon, pero cada zona incluye solo los que aparecen en ella. | §4, §7 |
| 2026-11-21 | **Cambio de rumbo:** en vez de una zona suelta (Túnel Roca con Onix), la primera entrega es una **porción vertical de Kanto, de Pueblo Paleta a Ciudad Plateada**, con los Pokémon que crea él a mano, que además sirven para el simulador. | §7 |
| 2026-11-21 | Los puntos de la campaña compran en la tienda monedas, dados, sobres y cartas sueltas del formato digital, y quizá campañas (lo normal es que estén abiertas de primeras). Cuántos puntos da cada cosa es irrelevante salvo que haya compras dentro de la campaña; lo que sobre al terminarla se conserva. | §5 |
| 2026-11-21 | Rechazó **robar energía** como mecánica (obligaría a los rivales a usar la misma para igualar los combates) y vio demasiado simple un «perfil de daño» como carta digital. | §3 |
| 2026-11-22 | **Arte y derechos (decisión de Ayme, #389).** Los **sprites de Pokémon, objetos y personajes son de Pokémon Escarlata y Púrpura (EP)**, tomados de WikiDex. Es un **proyecto personal, de uso privado para él y sus amigos, sin fines comerciales**. El repositorio sigue siendo **público** y los sprites van incluidos; **si GitHub o los titulares de los derechos piden retirarlos, Ayme los quita en cuanto se le avise.** El **arte propio** se limita a la **interfaz y los fondos de escena**. Las medallas son las de LGPE y los líderes están pendientes (§8, 24). Si hay que retirar los sprites, **hay un prompt en el chat del Director del juego que se encarga de borrarlos**. Esto no es una licencia: los derechos siguen siendo de sus titulares. | §4, §8; #389, #416 |

### 10.2 Combate y energía

| Fecha | Decisión | Dónde |
|---|---|---|
| 2026-11-21 | Reserva de energía de **máximo 10**, empieza en **10**, **+1 al terminar el turno** propio. Los números son parámetros del simulador. | §3.1; #336 |
| 2026-11-21 | **Una sola barra de energía por bando**, no una por Pokémon. | §3.1 |
| 2026-11-21 | Atacar, cambiar de Pokémon y cargar (antes, pasar) gastan **el turno**; **elegir al siguiente** cuando cae el activo no. Cambiar gasta turno (y la `retirada` puede costar además energía; 0 de salida). Dudaba entre turno y energía y se quedó con el turno. | §3.2; #336 |
| 2026-11-21 | La tercera acción pasa de **«Pasar» a «Cargar»**: recupera **1 de energía extra** (2 en total ese turno). Pasar le pareció anticlimático. La tienen también el jugador y la «máquina». | §3.2; #338 |
| 2026-11-21 | Empieza el jugador. Gana el bando que deja sin Pokémon al otro. | §3.2, §3.3 |
| 2026-11-21 | **Sin tabla de tipos global:** cada carta lleva su debilidad (×2) y su resistencia (−30). Primero la debilidad y después la resistencia. **Sin suelo de daño** (rechazó un mínimo): el daño puede quedar en 0. Sin inmunidades. | §3.3; #336 |
| 2026-11-21 | La **«máquina»** juega con **las mismas reglas** y decide de forma **determinista**. Le gustó cómo decide: remata si puede, cambia ante una debilidad y ataca por daño por energía. | §3.4; #338 |
| 2026-11-21 | Los **PS se restauran al máximo entre combates**; las **Pociones solo fuera de combate**. | §4 |
| 2026-11-22 | **Derrota:** al perder vuelves al **último punto donde te has curado** (centro Pokémon, zona de descanso…). No es lo mismo que curar fuera de combate (Pociones). | §4 |
| 2026-11-21 | **El azar entra en el motor** con una semilla (reproducible y con las mismas cuentas en la VM y en web). | §3.6 |
| 2026-11-21 | **Envenenado:** hace daño en cada **chequeo Pokémon**, es decir, cada vez que cambia el turno. | §3.6 |

### 10.3 Tipos

| Fecha | Decisión | Dónde |
|---|---|---|
| 2026-11-21 | Los tipos **siguen al TCG**: no hay tipo tierra ni roca, esos Pokémon (Geodude, Onix, Diglett, Sandshrew, Cubone) son de tipo **lucha**. | §3.3; #352 |
| 2026-11-22 | Se añade el tipo **oscuridad** (Nidoran♀ y ♂ lo llevan impreso). | §3.6; #352 |
| 2026-11-22 | **Tipos fuera del TCG:** `veneno` pasa a **oscuridad** (Zubat, que es el único dato real que cambia), `bicho` a **planta**, `volador` a **normal**, `fantasma` a **oscuridad** y `hielo` a **agua**. Esos cinco tipos desaparecen del enum. (`fantasma` pasaba a psíquico en la primera versión; Ayme lo cambió a oscuridad el 2026-11-22, §10.9.) | §3.3; #366, #404 |
| 2026-11-22 | **`metal` entra ya en el enum**, aunque no haya ninguna carta de ese tipo, por si se añaden Pokémon como Steelix, que no son de la primera generación. Falta decidir su color y su icono. No hay tabla de tipos global, así que no toca el motor. | §3.3; #366 |
| 2026-11-22 | **Revisión de huecos de la oscuridad** (#416). Con `oscuridad` cubriendo `veneno` y `fantasma`, el catálogo actual **no tiene huecos**: ninguna carta tiene debilidad ni resistencia a veneno o fantasma (las debilidades usadas son agua, fuego, planta, eléctrico, lucha y psíquico), y hay atacantes de oscuridad (Nidoran♀ y ♂ y, tras #404, Zubat). **La debilidad y la resistencia las escribe cada carta** (§3.3), así que no todos los Pokémon de oscuridad son débiles a lucha, igual que no todos los incoloros lo son (los pájaros son débiles al eléctrico). Por eso **Agatha y los fantasmas (Gastly, Haunter, Gengar) dependen de lo que lleve cada carta**; no hay una regla de tipo que los vuelva débiles a lucha (Ayme, 2026-11-22). **Avisos que siguen en pie:** (1) `lucha` ya agrupa lucha, tierra y roca (7 de los 22 Pokémon), así que si muchas cartas de oscuridad eligen lucha como debilidad, Calidad debería medir a Agatha; (2) hoy solo **Slowpoke** ataca con psíquico, así que la debilidad a psíquico de Machop y Mankey casi no se activa; (3) `zubat.json` (datos del catálogo; su carta aún no está hecha) ya es de `oscuridad` y su Ataque Ala es `normal` (#404). | §3.3; #404, #416 |

### 10.4 Efectos y habilidades de los ataques

Cada efecto se decidió al hacer la carta que lo lleva. Todos están en el motor, la IA, el esquema y los tests (§3.6).

| Fecha | Efecto (carta) | Decisión de Ayme |
|---|---|---|
| 2026-11-21 | `reduceDanoRival` (Gruñido, Bulbasaur) | «Los ataques del Pokémon Defensor hacen 10 puntos menos de daño» **durante todo el combate o hasta que el activo del rival pasa a la banca**. Un ataque con efecto puede tener 0 de daño. #350 |
| 2026-11-21 | Efectos de debilitar **no se acumulan** | A diferencia de los juegos. Aplica a Gruñido, Látigo y Fortaleza. Razón: el daño es plano y sin suelo, y tres usos anularían los ataques de coste 1 y 2. #350 |
| 2026-11-21 | `aumentaDanoRecibido` (Látigo, Squirtle) | «Recibe 10 más de daño.» Mismo trato que Gruñido. #350 |
| 2026-11-21 | `quitaEnergiaRival` (Disparo Demora, Caterpie) | No existe «velocidad» en el juego, así que el efecto es **«el rival pierde 1 de energía»**. #352 |
| 2026-11-21 | `monedaDanoExtra` (Hiper Colmillo, Rattata; después Golpe Kárate, Mankey) | Las **monedas valen** en los ataques (ej. «20+»: con cara, +20). #352 |
| 2026-11-21 | `reduceDanoPropio` (Fortaleza, Metapod y Kakuna; Rizo Defensa, Sandshrew) | «Mientras siga activo, recibe 10 menos de daño (antes de debilidad y resistencia), no se acumula.» **Se suma con Gruñido** (2026-11-22). #352 |
| 2026-11-21 | `envenenaDefensor` (Picotazo Veneno, Weedle, Kakuna, Nidoran♂) | Envenenado hace daño en cada chequeo Pokémon. Un ataque con veneno cuenta como el «ataque de 20 o más» obligatorio de la carta. #352 |
| 2026-11-21 | `monedaFalloRival` (Bofetón Lodo, Diglett) | «Ataque arena» adaptado: en el próximo turno del Defensor, si ataca lanza una moneda y con cruz el ataque no hace nada (la energía se gasta igual). #352 |
| 2026-11-21 | `danoPorRacha` (Rodar, Sandshrew) | Implementa la mecánica de los juegos: usos consecutivos que multiplican la potencia. Eligió **Rizo Defensa** y Rodar para Sandshrew. Texto de la carta (2026-11-22): empieza en 20 y suma 20 por cada uso consecutivo; la precisión sigue sin decidir. #352 |
| 2026-11-21/22 | `monedasDano` (Ataque Furia de Spearow y Nidoran♂, Golpes Furia de Nidoran♀) | Los golpes múltiples (2 a 5) se escriben con **3 monedas**: «con 1 cara, 20; con 2 caras, 30; con 3 caras, 40; con 0 caras, 50». El `dano` del JSON es el daño esperado, para la IA. #352 |
| 2026-11-21/22 | `repiteDanoAlDerribar` (Doble Patada, Nidoran♀, coste 3, 30) | «Si el Defensor queda fuera de combate por el daño de este ataque, el nuevo Defensor recibe de nuevo ese daño.» #352 |
| 2026-11-22 | `reduceDanoPropio` + `reduceDanoRival` | Fortaleza y Gruñido **se suman**. |
| 2026-11-22 | Habilidad `monedaDanoExtraAlAtacar` (Foco Energía, Mankey) | Primera **habilidad pasiva**: cada vez que ataca, lanza una moneda; con cara, +20 (el golpe crítico modelado con moneda). Se acumula con la moneda de Golpe Kárate. #352 |
| 2026-11-22 | `ganaEnergia` (Pulimento, Geodude) | «Tu bando recupera 2 de energía (hasta el máximo de 10).» Coste 1, 0 de daño. Sube la Velocidad de los juegos trasladada a la energía. Equivale a Cargar (−1 +2 +1); con 3 mejoraría a Cargar, pero Ayme imprimió la carta con 2. Coste antes que efecto; la IA lo usa en vez de cargar si le falta energía para su ataque grande y la reserva no está llena. Motor, IA, esquema y tests: tarea 14 (§9). |
| 2026-11-23 | `confundeDefensor` (Supersónico, Zubat) | «Lanza una moneda. Si sale Cara, el Pokémon Defensor pasa a estar Confundido.» Coste 1, 0 de daño. Efecto nuevo (opción 2), sin reimprimir la carta; Confundido reutiliza el estado de `monedaFalloRival`. Lleva `monedas` (1 en Supersónico, 2 en Hidropulso). **Hecho** (§9, 15): esquema, motor y JSON; la IA no lo usa. |
| 2026-11-23 | `drenaDefensor` (Drenadoras, Ivysaur) | Veneno (10 PS por chequeo) que cura 10 PS al Pokémon activo de quien lo usó. Pendiente de motor, IA y simulador; posible exceso de fuerza (§3.6). |
| 2026-11-23 | `paralizaDefensor` (Dragoaliento, Charmeleon) | **Paralizado: no puede atacar ni cambiar de Pokémon, solo durante su próximo turno.** 3 monedas, al menos 2 caras. Pendiente de motor, IA y simulador. |
| 2026-11-23 | `monedaFalloRival` con `mientrasActivo` (Pantalla de Humo, Charmeleon) | La carta se queda como está: el efecto de Bofetón Lodo, pero dura mientras el Defensor siga activo. Lo que hace daño dura un turno; lo que no, mientras siga activo. A medir con el simulador. |

### 10.5 Cartas y balance

| Fecha | Decisión | Dónde |
|---|---|---|
| 2026-11-21 | Los **daños** de los ataques son **múltiplos de 10** (el esquema exige lo mismo a los PS). | Esquema; #344 |
| 2026-11-21 | **Escala de PS y daños** de las cartas reales del TCG actual (Standard 2026-27): básicos 50–90 PS, Fase 1 90–130, ex 200–340. Se rehicieron los números con ella. | §3.5; #348 |
| 2026-11-21 | **1 a 2 ataques** por carta, coste de 1 a 4. | §3.5 |
| 2026-11-21 | **Toda carta lleva al menos un ataque de 20 o más** (o un ataque con veneno) para que Gruñido no la deje sin poder hacer daño. | §3.5; esquema y test |
| 2026-11-21 | Rechazó un suelo de daño mínimo y quiere que **muchos Pokémon no tengan resistencia**. | §3.3, §3.5 |
| 2026-11-21 | Las cartas se numeran **001/150** (Mew será 151/150, secreta). | §2 |
| 2026-11-21 | Las crea él, en PokeCardMaker (perfil «Aymedex»), a partir de ataques propuestos por otro chat desde WikiDex entre los que elige 1 o 2. Primeras del catálogo: Bulbasaur, Charmander y Squirtle. | §11 |
| 2026-11-22 | El tramo de Pueblo Paleta a Ciudad Plateada queda con todos sus Pokémon (se acabó la lista). | §12 |
| 2026-11-22 | **Geodude impreso (074/150):** lucha, 80 PS, debilidad agua ×2, **sin resistencia**, retirada 1. **Pulimento** (1: 0 de daño, `ganaEnergia` 2) y **Lanzarrocas** (3: 50). Sustituye a Placaje; `geodude.json` pasa a la carta impresa en la tarea 14 (valores provisionales hasta que Calidad los mida contra Brock). Lanzarrocas de 3 energías y 50 entra en el baremo de básico (§3.5) pero endurece a Brock; Calidad lo mide y, si es demasiado duro, baja a 40. | §12; imagen `geodude.webp` |
| 2026-11-22 | **Onix impreso (095/150, carta normal, no de jefe):** lucha, 110 PS, debilidad agua ×2, **sin resistencia**, retirada 1, **un solo ataque**: **Tumba Rocas** (3: 50, `quitaEnergiaRival` 1: «El rival pierde 1 energía (si le queda alguna)»). Sustituye a Atadura y Lanzarrocas; Tumba Rocas traslada a energía el «baja la Velocidad» de los juegos, sin motor nuevo. Los 110 PS salen del baremo de básico (50–90) como excepción del as de Brock; Calidad lo mide y, si Brock sale demasiado duro, se baja a 90 antes de imprimir de nuevo. | §12; imagen `onix.webp`; `onix.json` |
| 2026-11-22 | **Tasa de victoria objetivo: 75 %** por combate. No vale para la Liga, que tiene su propio objetivo del 25 % sobre toda la cadena (§10.7). | §8, 19; `balance/informes/campana_calibrar_2026-11-22.md`; #383 |
| 2026-11-23 | **Machop impreso (066/150) como Mankey:** mismos 70 PS, debilidad psíquico ×2 y sin resistencia, la **misma habilidad Foco Energía** y el **mismo ataque Golpe Kárate** (2: 30+, `monedaDanoExtra` 20). Retirada 0. Sustituye a Golpe Kárate sin efecto y a Patada Baja (3: 50) del catálogo. Mankey se reimprimió para corregir el texto de la habilidad («esté en el Puesto Activo. Cada vez que ataque…»). | §12; imágenes `machop.webp`, `mankey.webp` |
| 2026-11-23 | **Mankey: retirada 0.** La carta reimpresa lleva retirada 0 y Ayme la da por buena; sustituye a «retirada 1» (decidida el 2026-11-22). | §12; `mankey.json` |
| 2026-11-23 | **Cubone impreso (104/150):** lucha, 60 PS, **debilidad planta ×2** (antes agua), sin resistencia, retirada 0 y **un solo ataque**, **Hueso Palo** (2: 30, sin efecto). Sustituye a Garra y Golpe Hueso. | §12; imagen `cubone.webp` |
| 2026-11-23 | **Zubat impreso (041/150), con debilidad eléctrico ×2** (no lucha): oscuridad, 60 PS, sin resistencia, retirada 0; **Supersónico** (1: moneda, Confundido, `confundeDefensor`) y **Mordisco** (2: 30). Eligió eléctrico porque Zubat vuela y porque el Túnel Roca está lleno de rivales de lucha; además evita sumar otra carta de oscuridad débil a lucha (§10.3). Sustituye a Mordisco (1: 10) y Ataque Ala (2: 30). `zubat.json` sigue ya la carta (tarea 15). | §12; imagen `zubat.webp` |
| 2026-11-23 | **Slowpoke impreso (079/150):** agua, 80 PS, debilidad eléctrico ×2, sin resistencia, retirada 1; **Pistola Agua** (2: 20) y **Hidropulso** (3: 40; lanza 2 monedas y, si ambas son Cara, Confundido, `confundeDefensor` con `monedas` 2). Sustituye a Pistola Agua (1: 20) y Confusión (2: 30). Pistola Agua de coste 2 pega 20, por debajo del baremo de básico (30–40), pero como Burbuja de Squirtle; Hidropulso de 40 con coste 3 también, a cambio del efecto. `slowpoke.json` sigue ya la carta (tarea 15). | §12; imagen `slowpoke.webp` |
| 2026-11-23 | **Ivysaur, Charmeleon y Wartortle impresos** (002, 005 y 008/150, Fase 1): Ivysaur planta 110 PS, debilidad fuego ×2; Charmeleon fuego 100 PS, agua ×2; Wartortle agua 100 PS, eléctrico ×2; los tres sin resistencia y con retirada 1. **Ivysaur:** Drenadoras (2: 0, `drenaDefensor`) y Hoja Afilada (3: 50). **Charmeleon:** Pantalla de Humo (2: 0, `monedaFalloRival` con `mientrasActivo`) y Dragoaliento (3: 50, `paralizaDefensor`). **Wartortle:** Refugio (1: 0, `reduceDanoPropio` 10) e Hidropulso (3: 40, `confundeDefensor` con 2 monedas). Los ataques de coste 3 pegan entre 40 y 50, por debajo del baremo de fase 1 (80–100, §3.5); los efectos compensan una parte y el simulador debe confirmar que evolucionar compensa. Evolucionan a nivel de referencia 16, **0 medallas** y **70 XP** (§10.6, §10.11). | §12; imágenes `ivysaur.webp`, `charmeleon.webp`, `wartortle.webp` |

### 10.6 Equipo, captura y progresión

| Fecha | Decisión | Dónde |
|---|---|---|
| 2026-11-21 | El **jugador captura** al derrotar a un salvaje (se pregunta si se añade). Capturar es **opcional** (quizá con Pokéball, por decidir). | §2, §4 |
| 2026-11-21 | **Equipo de 6**: 1 activo y 5 en banca (parámetro). Si está lleno al capturar, se elige a quién sustituir y el descartado **va al PC**; no se pierde ninguno. | §2 |
| 2026-11-21 | El **PC** está en el centro Pokémon y es **ilimitado por ahora**. | §2, §4 |
| 2026-11-21 | **Sin niveles.** Las victorias dan puntos que en el centro Pokémon se convierten en **XP** de un Pokémon; cada uno necesita **N de XP** para evolucionar, con **un Pokémon por visita**. | §2.1; #346 |
| 2026-11-21 | Objetos de evolución (piedras): se compran fuera de los centros o se encuentran en las rutas. Evolución por **intercambio** (Haunter, Kadabra…): cuesta **puntos**. | §2.1 |
| 2026-11-21 | La **última fase de cada Pokémon es una carta ex**; uno que no evoluciona puede hacerse ex **gastando puntos**. Cada ex es una entrada propia del catálogo. La carta evolucionada **sustituye** a la anterior y recupera todos los PS. | §2.1 |
| 2026-11-21 | **Derrotar Pokémon da XP** y se elige a quién se la das. Cada combate da puntos **una sola vez**. Los entrenadores dan **dinero** (sin definir). | §4, §5 |
| 2026-11-22 | **Captura con Pokéball.** Tras derrotar a un salvaje, o a un jefe la primera vez, se captura tirando una moneda con la semilla de la partida. Cada tirada gasta 1 Ball (también si sale cara) y se puede reintentar mientras queden. Sin Pokéballs el combate acaba sin captura; un jefe no capturado la primera vez ya no se puede capturar. **Sin tope** de Pokéballs en la mochila: el límite lo pone el dinero. **Hecho (#368).** | §4, Partida de campaña; #361, #368 |
| 2026-11-22 | **Categoría de captura.** La probabilidad depende de la categoría del Pokémon y de la Ball (Pokéball / Super Ball / Ultra Ball): Común 75 / 100 / 100 %, Intermedio 50 / 75 / 100 %, Fuerte 25 / 50 / 75 %, Jefe 12,5 / 25 / 50 %. La categoría es un campo de cada carta y de cada jefe (`categoriaCaptura`). **Pikachu jefe** es Común con **captura asegurada** (la moneda sale siempre cara) por ser el tutorial. **Hecho (#368).** | #361, #368 |
| 2026-11-22 | **Asignación inicial de categorías.** Común: Pidgey, Rattata, Spearow, Nidoran♀, Nidoran♂, Caterpie, Weedle, Diglett, Sandshrew, Zubat, Cubone, Machop, Slowpoke y Pikachu. Intermedio: Metapod, Kakuna, Mankey y Geodude. Fuerte: Onix. Los iniciales no aplican. | #361 |
| 2026-11-22 | ~~La Ruta 1 no permite capturar~~ (corregido el 2026-11-23, §10.9): en la Ruta 1 **sí se puede capturar**, pero la primera tienda es el centro de Ciudad Verde y la mochila de salida lleva **0 Pokéballs**, así que la primera vez no hay con qué; luego se puede **volver atrás a capturar** (§10.7). | #361, #368 |
| 2026-11-22 | **Super Ball** se desbloquea con la 1ª medalla y **Ultra Ball** con 5 medallas. **Hecho (#402)** en la tienda. | #361 |
| 2026-11-22 | **Precios** (los de los juegos Rojo, Azul, Amarillo y FireRed/LeafGreen): Pokéball 200, Super Ball 600, Ultra Ball 1200, Poción 300 y Repelente 350. En el primer tramo la tienda vende **solo Pokéball y Poción**. **Hecho (#402)**: campo `tienda` en cada centro. | #362 |
| 2026-11-23 | **Cuerda Huida** (objeto de combate): **precio 550** (el de los juegos) y **usable en combate**; su efecto es cambiar el Pokémon activo por uno de la banca **sin pagar la retirada**, aunque esté Paralizado (y Dormido, cuando exista). **Gasta el turno y ahorra la energía de la retirada** (decidido por Ayme el 2026-11-23; #437). **Pendiente:** en qué tramo se vende. Hoy no hay objetos en combate: la Cuerda Huida sería el primero, y de ahí sale la pregunta de si las **Pociones** también (#435). | §8, 26 y 27; #435, #437 |
| 2026-11-22 | **Dinero.** Cada clase de entrenador y cada líder paga una cifra propia guardada en el catálogo (campo `dinero`), para ajustarlo a cada tramo. Referencia: al conseguir la 1ª medalla el jugador ha ganado unos **2.060** (en FireRed/LeafGreen son 2.064 solo con entrenadores). Primer tramo: Cazabichos 200 (×2), Entrenador Joven 260 y Brock 1.400. Dinero de salida: **1.000**. Los salvajes no dan dinero. **Hecho (#402).** | §5; #362 |
| 2026-11-22 | **Evoluciones del primer tramo.** Por ahora solo las que ya tienen carta en el catálogo: **Caterpie → Metapod** y **Weedle → Kakuna**, que se capturan en la Ruta 2 sur. Lo que da Brock (puntos) se guarda para evolucionar a uno más después. **Si Brock resulta muy difícil con ese equipo, se puede evolucionar también un inicial antes de Brock** (Bulbasaur, Charmander o Squirtle), lo que exige crear sus cartas de fase 1. Es **opcional, no obligatorio**, y se medirá con el simulador contra el objetivo del 75 % (§10.5). Las cifras de XP y de coste de evolución quedan por cerrar con cálculos (§8, 6). | #363 |
| 2026-11-22 | **Solo XP de combate para evolucionar, en una reserva común.** Cada combate suma XP a una **reserva** que se guarda; el jugador decide a qué Pokémon se la gasta y cuándo (en el centro Pokémon). La XP se gasta **entera para evolucionar**: no se puede dejar a medias ni repartir en parte. Los puntos no intervienen en la evolución (solo en la tienda de la cuenta y en el intercambio y hacerse ex, §10.6). | §2.1, §5; #363 |
| 2026-11-22 | **Cifras de XP.** Cada rival derrotado suma XP a la reserva (una sola vez, no por Pokémon): **10, 20 o 30 según su categoría de captura** (Común 10, Intermedio 20, Fuerte y Jefe 30; un jefe puede llevar `xp` propio en su JSON, y Pikachu jefe da 30). Coste de evolucionar a fase 1: **50 XP** para Caterpie → Metapod y Weedle → Kakuna (≈ 5 KO, la proporción de los juegos: nivel 7, unos 220–316 XP frente a unos 58 por KO), y **70 XP** para un inicial (**abaratado a propósito**: en los juegos serían ≈ 410, nivel 16, y no cabría antes de Brock). Con 10 XP por rival, la reserva era de 70–90 XP en Plateada y de 110–130 tras Brock; con la regla de 10, 20 o 30 es de unos **110 XP en Plateada (90–130) y unos 180 tras Brock (160–200)**, y **los costes se quedan en 50 y 70** (decidido el 2026-11-22): con ellos, casi siempre se puede evolucionar un inicial y un insecto antes de Brock, y Calidad medirá con el simulador si eso es demasiado fácil. Dato nuevo del catálogo: `xpEvolucion` en cada Pokémon que evoluciona. Las demás fases se fijan cuando tengan carta (referencia de los juegos: Metapod y Kakuna ≈ 110). Si el simulador dice que es demasiado fácil o difícil, se ajustan estas cifras. **Hecho (#403)**, salvo el `xpEvolucion` de los iniciales, que espera a sus cartas de fase 1. | §2.1; #363 |
| 2026-11-22 | **Centro Pokémon: curar es gratis y sin límite.** Cura a todo el equipo, incluidos los debilitados. No es el único sitio donde se cura sin Poción: los **NPC de los nodos de conversación** también pueden curar durante la historia (como el aviso antes de Pikachu, #395). | §4; #362 |
| 2026-11-22 | **Puntos de curación del primer tramo:** los que hay hoy (centro de Ciudad Verde, conversación antes de Pikachu y centro de Plateada). Si el simulador dice que Brock es demasiado difícil, se añade un NPC que cure (por ejemplo tras Pikachu o antes de Brock). | §4; #362 |
| 2026-11-22 | **PC:** el equipo y el PC se cambian **solo en un centro Pokémon**; los NPC de conversación, aunque curen, no dan acceso. Con el equipo lleno, capturar sigue obligando a elegir a quién mandar al PC (§10.6, 2026-11-21). | §2, §4; #362 |
| 2026-11-22 | **Evolucionar se hace fuera de combate, desde el menú del equipo,** tantas veces como dé la reserva de XP; no hace falta un centro ni hay límite por visita. La carta evolucionada sustituye a la anterior y el Pokémon queda con **10 PS siempre**, también si tenía más o estaba debilitado (**evolucionar revive a 10 PS**). Así evolucionar no es una curación: lo normal es hacerlo justo antes de curar en un centro. **Hecho (#403).** | §2.1; #362, #363 |
| 2026-11-22 | **Evolución por medalla.** Cada evolución se desbloquea con la **medalla que le corresponde según los juegos**; si faltan medallas, no se ofrece aunque haya XP, y el menú del equipo muestra el motivo («requiere N medallas»). Antes de Brock pueden evolucionar **Caterpie → Metapod**, **Weedle → Kakuna** y, **opcionalmente, el inicial**; no pueden Raticate, Pidgeotto ni Fearow. **La XP no tiene límite; el techo lo pone esta regla**, así que no hace falta recortar la XP de los salvajes repetibles (§10.7). Catálogo: campo `medallasMinimas` (entero) en la ficha de cada evolución. La tabla con las medallas mínimas está en §10.11, **confirmada por Ayme el 2026-11-22**. **Hecho (#414):** el motor no deja evolucionar sin las medallas y la hoja de la carta muestra «Requiere N medallas.»; una evolución sin `medallasMinimas` (por decidir) no limita. | §2.1, §10.11; #414, #416 |

### 10.7 Mapa y ruta

| Fecha | Decisión | Dónde |
|---|---|---|
| 2026-11-21 | **Recorrido del primer tramo:** Pueblo Paleta (elegir inicial) → Ruta 1 (bifurcación Pidgey/Rattata) → Ciudad Verde (centro Pokémon de presentación) → Ruta 22 (opcional, da puntos) → Ruta 2 sur (bifurcación Weedle/Caterpie) → Bosque Verde (2 Cazabichos y el jefe Pikachu) → Ruta 2 norte (salvaje opcional o directo) → Ciudad Plateada (centro Pokémon y gimnasio: Entrenador Joven y Brock). | §4 |
| 2026-11-21 | **Entre cada par de medallas hay 1 jefe** y más en rutas clave. | §4 |
| 2026-11-22 | **Modelo de ruta por nodos:** grafo de nodos (inicio, combate, bifurcación, descanso, gimnasio, jefe), nodos **opcionales** solo en combates y descansos, y progreso del jugador. Aceptó la propuesta con «sí, vamos a hacer el modelo de Ruta por nodos». | §4; #354 |
| 2026-11-22 | La región **solo acaba en un gimnasio o un jefe**; un nodo de combate puede fijar su Pokémon. (La primera versión de `kanto.json` no seguía el recorrido de arriba; se corrigió en #356, §10.9.) | §4; #356 |
| 2026-11-22 | Reglas de diseño de la región: **un jefe y al menos una bifurcación** entre medallas (y desde el inicio hasta la primera). | §4; test |
| 2026-11-22 | **Liga:** fase 2. | §4 |
| 2026-11-22 | **Liga: estructura.** Se abre con las 8 medallas. Son **cinco rivales** (Alto Mando y Campeón) con **tres Pokémon cada uno**, **sin descanso entre ellos**: **un centro Pokémon solo a la entrada**. Lo que importa es el **desgaste acumulado**: los PS y la energía de Pociones se arrastran de un rival al siguiente, y entre rivales solo se pueden gastar Pociones o evolucionar (que deja a 10 PS). No hace falta un tipo de nodo nuevo: es una cadena de nodos de gimnasio sin descanso entre ellos. Fase 2, pendiente de implementar. Texto reescrito el 2026-11-22 (#416): decía «15 combates seguidos». | §4; #367, #416 |
| 2026-11-22 | **Liga: derrota.** Al perder se vuelve al centro de la entrada y se **repiten todos los combates**, con el equipo curado y conservando capturas, XP, dinero y medallas; los puntos y el dinero de un combate se dan **una sola vez**. Es la regla de derrota que ya existe (§10.2). | §4; #367 |
| 2026-11-22 | **Liga: rivales.** Los de los juegos con los tipos pasados al TCG: Lorelei (agua), Bruno (lucha), Agatha (oscuridad), Lance (dragón) y el Campeón, que es el rival del jugador (equipo variado). Los líderes y el Alto Mando no son jefes: usan cartas normales (§10.8). | §4; #367 |
| 2026-11-22 | **Liga: recompensa.** Cada rival paga **dinero y puntos propios**, como un líder, y el Campeón más. Al vencerlo **termina la campaña** con una pantalla de final. Las cifras por rival se fijan al diseñar ese tramo. | §4, §5; #367 |
| 2026-11-22 | **Liga: dificultad.** Objetivo: **completar la Liga a la primera en un 25 %** (unos 4 intentos de media), medido por Calidad con el simulador **sobre la Liga entera**, con su desgaste acumulado, y no combate a combate. Sustituye al 75 % por combate (§10.5) solo para la Liga: ese 75 % no sirve como objetivo de una cadena de cinco rivales sin descanso. Texto reescrito el 2026-11-22 (#416); el objetivo del 25 % se mantiene. | §10.5; #367, #416 |
| 2026-11-22 | **Nodo «Conversación»** (nuevo tipo `conversacion`: hablar y, si lo dice, curar). En el Bosque Verde, **justo antes de Pikachu**, sale **siempre** un Cazabichos que avisa sin combatir de que Pikachu se come la comida de los demás y se ha hecho más fuerte, y cura al equipo. **Si pierdes contra Pikachu, vuelves a ese Cazabichos.** El texto lo propone Claude y Ayme lo aprueba. | §4; `kanto.json` (`aviso-pikachu`) |
| 2026-11-22 | **Pantalla del mapa: escenas interactivas** (propuesta D del lienzo de wireframes). Cada nodo es una **escena ilustrada** en la que se pulsa: la **hierba alta** lanza el combate salvaje, los **bordes** llevan al nodo siguiente o al anterior y los edificios o personajes abren el centro, el gimnasio o la conversación. Sustituye a la lista de nodos de la primera versión. Barra fija con dinero, Pokéballs y XP, y el equipo abajo. Los **sprites de Pokémon, objetos y personajes son de Pokémon Escarlata y Púrpura** y el **arte propio se limita a la interfaz y los fondos de escena** (decisión de arte y derechos de Ayme, #389, #416). Datos nuevos en el catálogo: imagen o escena por nodo y zonas pulsables con coordenadas. El motor no cambia. **Datos hechos (#413)**, con marcador hasta que lleguen las imágenes (§4, Escenas); la pantalla está pendiente. | §4, §9; #365 |
| 2026-11-22 | **Retroceder:** se puede volver a **cualquier escena ya visitada** (el grafo sigue sin ciclos; el jugador puede moverse hacia atrás). Sustituye a «solo hacia delante» (§10.9). **Hecho (#412)** en el motor y en la lista de la ruta de la app (se toca un nodo visitado). | §4; #365, #412 |
| 2026-11-22 | **Qué se puede repetir:** solo los **Pokémon salvajes**, para **capturarlos o ganar XP**. Los entrenadores, los gimnasios, los jefes y las conversaciones **no** se repiten (los que curan siguen sirviendo como punto de curación). Los salvajes **no dan dinero** (ya decidido), así que las Pokéballs siguen limitadas por el dinero. La **XP es ilimitada**, sin cambios de reglas; Calidad mide con el simulador el caso peor **sin entrenar** y cuántos combates de entrenamiento hacen falta para vencer a Brock, y **el techo lo pone la regla de evolución por medalla** (§10.6, #416), así que no se recorta la XP de los salvajes. Los **puntos** se dan una sola vez por combate (§4). **Hecho (#412):** repetir un salvaje da la XP de su categoría y se puede capturar, sin puntos ni dinero. | §4, §10.6; #365, #412 |
| 2026-11-22 | **Pantalla de combate (propuesta I del lienzo de wireframes).** Tapete con cuatro zonas marcadas: **banca rival, activo rival, tu activo y tu banca** (hasta 5 Pokémon cada una, con su vida; los caídos en gris y sin poder elegirse). Se **toca a tu Pokémon activo** y aparece la hoja de acciones (los dos ataques con su coste, y Cargar); se **toca un Pokémon de la banca** para cambiar, con aviso de que gasta el turno y confirmación. Energía de 0 a 10 como fichas, estados («pega −10») y registro de la última jugada a la vista. Inspirada en la distribución de TCG Live y Pocket (zonas y toque en la carta), sin copiar su arte. En los combates del tutorial (Ruta 1 y Pikachu) el primer toque va señalado con un destello. Arte propio, como el mapa. El motor no cambia. | §3, §9; #365 |
| 2026-11-22 | **Pantalla de equipo (propuesta J del lienzo de wireframes).** Rejilla de 2×3 cartas con nombre, PS y barra de vida; los caídos en gris y los huecos libres marcados. Arriba, la **XP de reserva** y las **Pociones**. Se **toca una carta** y sale la hoja con **Usar Poción** (+20 PS, no revive; quedan las que haya) y **Evolucionar** (si hay XP suficiente; deja al Pokémon a 10 PS). En un debilitado, la hoja avisa de que solo cura el centro Pokémon. Cambiar el equipo (ordenar, meter o sacar del PC) **solo en un centro Pokémon**, y el **PC es una pantalla aparte**, no una pestaña del equipo. El motor no cambia. | §2.1, §9; #365 |
| 2026-11-22 | **Centro Pokémon (propuesta M del lienzo de wireframes).** Escena interactiva como el mapa: el **mostrador** cura a todo el equipo (gratis, también a los debilitados), la **estantería** abre la tienda (en el primer tramo, Pokéball 200 y Poción 300; Super Ball con la 1.ª medalla y Ultra Ball con 5), el **PC** abre su pantalla aparte y la **puerta** vuelve al mapa. Muestra el equipo con su vida abajo y dinero y Pokéballs arriba. El motor no cambia. | §4, §5, §9; #365 |

### 10.8 Jefes

| Fecha | Decisión | Dónde |
|---|---|---|
| 2026-11-21 | Los jefes son **Pokémon salvajes**, no entrenadores; los líderes de gimnasio y el Alto Mando no son jefes. | §4 |
| 2026-11-21 | **Serie propia de 20 cartas, NN/20**: 1–8 uno por tramo entre medallas, 9–16 rutas clave, 17–20 los cuatro legendarios (Articuno, Zapdos, Moltres, Mewtwo; Mew fuera). Pikachu es el 01/20. | §4; #352 |
| 2026-11-21 | El jefe **llama a un aliado a mitad de combate**: al bajar de la mitad de PS se retira a la banca, entra el aliado y, cuando cae, vuelve el jefe con sus PS. Llama a **un solo aliado**. Pikachu: Weedle, Caterpie, Metapod o Kakuna. | §4 |
| 2026-11-21 | **Pikachu jefe:** 100 PS, eléctrico, debilidad lucha, Ataque Rápido 10 e Impactrueno 30. | §12; #352 |
| 2026-11-22 | **Llamada de aliado, detalles:** llama al **llegar** al porcentaje (con 50 PS justos de 100 ya llama), no solo al bajar de él; cuenta cualquier daño, también el veneno; una sola vez por combate; al retirarse el jefe pierde los estados negativos; aunque caiga el aliado, no se gana hasta que cae el jefe. Aceptó además que si el golpe lo deja a 0 no llama, que el aliado usa la energía del bando y que el jefe no vuelve con «Cambiar» mientras el aliado siga en pie. | §4, Jefes; #372 |
| 2026-11-22 | **Llamada en dos pasos:** al 50 % el jefe invoca al aliado, que aparece **en la banca**; al **40 %** el jefe se cambia y el aliado pasa al puesto activo, de modo que unos ataques solo lo invocan y otros lo ponen delante directamente. Al irse a la banca el jefe pierde **todos** los efectos, también Fortaleza y demás. Campo nuevo `alFrenteAlPorcentaje` (Pikachu: 40). | §4, Jefes; `pikachu-jefe.json`; #372 |
| 2026-11-21 | **El jefe es capturable** (sustituye a «no capturable»), con la carta **normal** del Pokémon (Pikachu 025/150, 60 PS, Látigo e Impactrueno 30). Solo la primera vez; **los aliados no se capturan**. | §4; #352 |

### 10.9 Decisiones sustituidas o corregidas

| Fecha | Antes | Ahora |
|---|---|---|
| 2026-11-23 | #368 leyó «la Ruta 1 no permite capturar» como una regla de la zona (`captura: false`). | No es una regla de la zona: en la Ruta 1 no se captura **la primera vez** porque no hay Pokéballs hasta la primera tienda (Ciudad Verde); después se puede volver a capturar (Ayme, 2026-11-23). La zona deja de llevar `captura: false`. |
| 2026-11-22 | La tabla de §10.11 (#417) puso los iniciales a **1 medalla**, por un error al fijarla. | Los iniciales evolucionan con **0 medallas**, así que pueden hacerlo antes de Brock; el plan B de §10.6 sigue vigente. Corregido el 2026-11-22 (#416). |
| 2026-11-22 | `fantasma` pasaba a **psíquico** (§10.3) y Agatha era de tipo psíquico. | `fantasma` pasa a **oscuridad**, igual que `veneno`, y Agatha es de tipo **oscuridad** (§10.3, §10.7; #416). |
| 2026-11-21 | La tercera acción era «Pasar». | «Cargar» (§10.2). |
| 2026-11-21 | Primera entrega: el Túnel Roca con Onix de jefe. | Porción vertical de Kanto de Pueblo Paleta a Ciudad Plateada (§10.1). La zona Túnel Roca y sus cartas se quedan en el catálogo (§8, 15). |
| 2026-11-21 | Los jefes eran **no capturables**. | Capturables la primera vez (§10.8). |
| 2026-11-21 | Los tipos incluían tierra y roca. | Son lucha, como en el TCG (§10.3). |
| 2026-11-21 | Los Pokémon de veneno eran de tipo veneno. | Nidoran es **oscuridad** (§10.3); el resto de tipos que no existen en el TCG se decide Pokémon a Pokémon (§8, 10). |
| 2026-11-21 | Los efectos de debilitar se acumulaban como en los juegos. | No se acumulan (§10.4). |
| 2026-11-21 | Regla de la carta: «un ataque de 20 o más». | «20 o más, **o** un ataque con veneno» (§10.5). |
| 2026-11-22 | #355 incluyó una versión de `kanto.json` que **no seguía** el recorrido que Ayme había definido el 2026-11-21: había una **Cueva Diglett** inventada (zona y nodo), un solo Cazabichos, Diglett y Sandshrew sin sitio, sin las bifurcaciones de la Ruta 1 y de la Ruta 2 sur y con Ciudad Verde sin su centro Pokémon. | Corregido en #356: sin Cueva Diglett; Diglett y Sandshrew son el Entrenador Joven del gimnasio; dos Cazabichos; Ruta 1 con bifurcación; centro en Ciudad Verde; Ruta 2 sur con bifurcación y Ruta 2 norte con un salvaje opcional. |
| 2026-11-22 | La tabla de §3.5 daba **debilidad agua** a Diglett y Sandshrew. | Las cartas dicen **planta**; el JSON manda (§12). |
| 2026-11-22 | Los tipos que no existen en el TCG se decidían «Pokémon a Pokémon» (§8, 10). | Tabla fija: `veneno` → oscuridad, `bicho` → planta, `volador` → normal, `fantasma` → oscuridad (primero fue psíquico, ver arriba), `hielo` → agua; y entra `metal` (§10.3). |
| 2026-11-22 | La XP iba **por Pokémon** (10 por rival a cada Pokémon que siguiera en pie) y las victorias daban **puntos que en el centro se convertían en XP** (§10.6, 2026-11-21). | La evolución usa **solo XP de combate**, en una **reserva común** que el jugador reparte; se gasta entera para evolucionar (§10.6). |
| 2026-11-22 | La evolución se hacía **en el centro Pokémon, un Pokémon por visita**, y la carta evolucionada **recuperaba todos los PS** (§10.6, 2026-11-21 y §2.1). | Se evoluciona **fuera de combate**, desde el menú del equipo, sin límite por visita, y el Pokémon **queda con 10 PS**, también si estaba debilitado (§10.6). |
| 2026-11-22 | La región se recorría **solo hacia delante** y no había combates repetibles. | Se puede **retroceder** a escenas visitadas y repetir **solo los salvajes** (§10.7). |
| 2026-11-22 | La primera versión de este registro (§10.7, mapa) decía que el arte sería **vectorial y propio, sin capturas de los juegos**. | Los **sprites de Pokémon, objetos y personajes son de Pokémon Escarlata y Púrpura** (uso privado, §10.1) y el arte propio queda para **interfaz y fondos de escena** (#416). |

### 10.10 Forma de trabajar

| Decisión | Detalle |
|---|---|
| **Una issue por pieza** y una rama y un PR por issue; el título del PR cita la issue. | Preferencia de Ayme para lo que está en el Kanban: crear la issue en la tarjeta y asignarla a la rama. |
| **No se fusiona hasta que él lo ordena** («Fusiona»), y puede pedir ajustes antes. Tras fusionar se puede seguir ajustando la misma pieza con un PR nuevo (lo preguntó antes de autorizar la primera fusión). | Tanda de cartas: «No fusiones aún, vamos a tener primero todos los Pokémon de este sprint». |
| **CI en cada PR:** Motor (`dart test`), App (`flutter test`), App web (build), Simulador, Contrato JSON y Hoja de balance. | Una rama sin PR no lanza el CI. |
| **Diseño y arte se reparten** (2026-11-22): el diseño cierra estructura, interacción y reglas de cada pantalla (wireframes del lienzo, §10.7); **las pantallas, ilustraciones, sprites e interfaz visual son tarea del artista**, que parte de esos wireframes. | Los colores y formas de los wireframes son marcadores de posición; solo el estilo «colorido tipo videojuego, mesa como tapete» es una dirección. |
| **El JSON manda** sobre este documento. | Si algo de §12 no coincide con `catalog/campana/`, vale el JSON. |

### 10.11 Evoluciones: medallas mínimas

**Tabla confirmada por Ayme el 2026-11-22** (#416), con los iniciales a **0 medallas**: pueden evolucionar antes de Brock. Los casos «por decidir» (piedra de Pikachu, Steelix) siguen abiertos. **Implementada en #414** con el campo `medallasMinimas` en cada evolución del catálogo (hoy solo Caterpie y Weedle, a 0; el resto se rellena al crear la carta de su evolución). Método: la medalla mínima es el número de medallas con las que, en los juegos, se suele alcanzar el **nivel de referencia** de la evolución (Brock tiene Pokémon de nivel 12 a 14, así que antes de la 1.ª medalla se está en torno a ese nivel). Los niveles son los de los juegos de Kanto (Rojo, Azul y FireRed/LeafGreen) y conviene **comprobarlos al implementar**. Ayme fijó dos puntos de partida, que la tabla respeta: antes de Brock solo hay las primeras fases de Caterpie y Weedle y, opcionalmente, el inicial.

**Catálogo actual**

| Evolución | Nivel de referencia | Medallas mínimas | Carta de la evolución | Nota |
|---|---|---|---|---|
| Caterpie → Metapod | 7 | **0** | En el catálogo | Antes de Brock (decidido). |
| Weedle → Kakuna | 7 | **0** | En el catálogo | Antes de Brock (decidido). |
| Metapod → Butterfree | 10 | **1** | Falta | En los juegos se alcanza antes de Brock, pero Ayme limita ese tramo a las primeras fases. |
| Kakuna → Beedrill | 10 | **1** | Falta | Igual que el anterior. |
| Bulbasaur → Ivysaur | 16 | **0** (opcional) | Impresa (2026-11-23; JSON en la tarea 16) | Es el «inicial opcional» y el plan B si Brock resulta demasiado difícil (§10.6). En los juegos serían 1 medalla. |
| Charmander → Charmeleon | 16 | **0** (opcional) | Impresa (2026-11-23; JSON en la tarea 16) | Es el «inicial opcional» y el plan B si Brock resulta demasiado difícil (§10.6). En los juegos serían 1 medalla. |
| Squirtle → Wartortle | 16 | **0** (opcional) | Impresa (2026-11-23; JSON en la tarea 16) | Es el «inicial opcional» y el plan B si Brock resulta demasiado difícil (§10.6). En los juegos serían 1 medalla. |

**Resto de Pokémon del catálogo** (primeras evoluciones, para que el campo esté completo cuando haya cartas)

| Evolución | Nivel de referencia | Medallas mínimas |
|---|---|---|
| Nidoran♀ → Nidorina, Nidoran♂ → Nidorino | 16 | 1 |
| Pidgey → Pidgeotto | 18 | 2 |
| Rattata → Raticate | 20 | 2 |
| Spearow → Fearow | 20 | 2 |
| Zubat → Golbat | 22 | 2 |
| Sandshrew → Sandslash | 22 | 2 |
| Geodude → Graveler | 25 | 3 |
| Diglett → Dugtrio | 26 | 3 |
| Machop → Machoke, Mankey → Primeape, Cubone → Marowak | 28 | 3 |
| Slowpoke → Slowbro | 37 | 5 |
| Pikachu → Raichu | Piedra Trueno | Por decidir: depende de cuándo se pueda comprar la piedra |
| Onix → Steelix | Intercambio con Revestimiento Metálico | Por decidir (no es de la primera generación, §10.3) |

Las terceras fases de los iniciales (nivel 32 y 36 en los juegos) serían 4 y 5 medallas si se hacen; no hay cartas todavía.

## 11. Cómo se crea una carta

El proceso que se ha seguido con las 22 cartas actuales (el cuello de botella es el paso 1, §8, 18).

1. **Ayme hace la carta.** Elige el Pokémon, pide a otro chat cuatro ataques propuestos desde WikiDex y se queda con **uno o dos**. La hace en PokeCardMaker (perfil «Aymedex»), con numeración **NNN/150** (los jefes, NN/20) y la ajusta al baremo de §3.5.
2. **Pasa la imagen** de la carta. De ella salen: número de la Pokédex, PS, tipo, debilidad, resistencia (si lleva), retirada, habilidad y, por cada ataque, nombre, coste, daño y texto.
3. **Se traduce a datos:** `catalog/campana/pokemon/<id>.json` (o `jefes/<id>.json`). El esquema (`catalog/schema/pokemon-campana.schema.json`) y los tests del catálogo (`engine/test/campana_catalogo_test.dart`) comprueban lo básico: PS múltiplos de 10 entre 30 y 340, 1 a 2 ataques, coste de 1 a 4, daños múltiplos de 10, **al menos un ataque de 20 o más o con veneno**, y que el `id` coincida con el nombre del archivo y el número no se repita. Hay además un test «todos contra todos» que juega todas las parejas con la IA y avisa si dos cartas se bloquean por resistencias (se corrige la carta, no el motor). Un ataque con `monedasDano` lleva en `dano` el daño **esperado**.
4. **La imagen** va a `app/assets/campana/cartas/<id>.webp` a **480×670** (la carpeta ya está declarada en `app/pubspec.yaml`).
5. **Si la carta trae un efecto nuevo**, hay que tocar el motor (`engine/lib/src/campana/combate.dart`), la IA (`ia.dart`), el esquema, el cargador (`catalogo.dart`) y los tests, y documentar el efecto en §3.6 con la decisión de Ayme. Si no, basta con el JSON, la imagen y su test.
6. **Si el texto impreso no coincide con el motor** (caso Sandshrew, §8, 11), se anota aquí en lugar de cambiar la carta sin decirlo.
7. **Un PR por tanda**, con la issue de la tanda en el título y un commit por carta; el CI tiene que pasar los 6 checks y Ayme da la orden de fusionar (§10.10).
8. **Se actualizan** la tabla de §12 y la numeración (los números de la Pokédex, no los impresos, ordenan el catálogo).

## 12. Catálogo actual

Generado a partir de `catalog/campana/` el 2026-11-22. Si algo de aquí no coincide con el JSON, manda el JSON.

### Pokémon (22)

| Nº | Id | Pokémon | Tipo | PS | Debilidad | Resistencia | Retirada | Habilidad | Ataques (coste: daño) | Categoría | Evoluciona | Imagen |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 001 | `bulbasaur` | Bulbasaur | planta | 90 | fuego | — | 0 | — | Gruñido (1: efecto `reduceDanoRival`); Placaje (2: 20) | — | — | sí |
| 004 | `charmander` | Charmander | fuego | 70 | agua | — | 0 | — | Gruñido (1: efecto `reduceDanoRival`); Ascuas (2: 30) | — | — | sí |
| 007 | `squirtle` | Squirtle | agua | 80 | electrico | — | 0 | — | Látigo (1: efecto `aumentaDanoRecibido`); Burbuja (2: 20) | — | — | sí |
| 010 | `caterpie` | Caterpie | planta | 50 | fuego | — | 0 | — | Disparo Demora (1: efecto `quitaEnergiaRival`); Placaje (2: 20) | Común | metapod (50 XP) | sí |
| 011 | `metapod` | Metapod | planta | 80 | fuego | — | 0 | — | Fortaleza (1: efecto `reduceDanoPropio`); Placaje (1: 20) | Intermedio | — | sí |
| 013 | `weedle` | Weedle | planta | 50 | fuego | — | 0 | — | Picotazo Veneno (2: 10 `envenenaDefensor`) | Común | kakuna (50 XP) | sí |
| 014 | `kakuna` | Kakuna | planta | 70 | fuego | — | 0 | — | Fortaleza (1: efecto `reduceDanoPropio`); Picotazo Veneno (2: 10 `envenenaDefensor`) | Intermedio | — | sí |
| 016 | `pidgey` | Pidgey | normal | 60 | electrico | — | 0 | — | Tornado (2: 30) | Común | — | sí |
| 019 | `rattata` | Rattata | normal | 60 | lucha | — | 0 | — | Ataque Rápido (1: 10); Hiper Colmillo (2: 20+ `monedaDanoExtra`) | Común | — | sí |
| 021 | `spearow` | Spearow | normal | 60 | electrico | lucha | 0 | — | Picotazo (1: 10); Ataque Furia (2: 30 esp. `monedasDano`) | Común | — | sí |
| 025 | `pikachu` | Pikachu | electrico | 60 | lucha | — | 0 | — | Látigo (1: efecto `aumentaDanoRecibido`); Impactrueno (2: 30) | Común | — | sí |
| 027 | `sandshrew` | Sandshrew | lucha | 70 | planta | — | 0 | — | Rizo Defensa (1: efecto `reduceDanoPropio`); Rodar (2: 20×racha `danoPorRacha`) | Común | — | sí |
| 029 | `nidoran-f` | Nidoran♀ | oscuridad | 60 | lucha | — | 0 | — | Golpes Furia (2: 30 esp. `monedasDano`); Doble Patada (3: 30 `repiteDanoAlDerribar`) | Común | — | sí |
| 032 | `nidoran-m` | Nidoran♂ | oscuridad | 60 | lucha | — | 0 | — | Picotazo veneno (1: 10 `envenenaDefensor`); Ataque Furia (2: 30 esp. `monedasDano`) | Común | — | sí |
| 041 | `zubat` | Zubat | oscuridad | 60 | electrico | — | 0 | — | Supersónico (1: efecto `confundeDefensor`); Mordisco (2: 30) | Común | — | sí |
| 050 | `diglett` | Diglett | lucha | 50 | planta | — | 0 | — | Arañazo (1: 10); Bofetón Lodo (2: 30 `monedaFalloRival`) | Común | — | sí |
| 056 | `mankey` | Mankey | lucha | 70 | psiquico | — | 0 | Foco Energía | Golpe Kárate (2: 30+ `monedaDanoExtra`) | Intermedio | — | sí |
| 066 | `machop` | Machop | lucha | 70 | psiquico | — | 0 | Foco Energía | Golpe Kárate (2: 30+ `monedaDanoExtra`) | Común | — | sí |
| 074 | `geodude` | Geodude | lucha | 80 | agua | — | 1 | — | Pulimento (1: efecto `ganaEnergia`); Lanzarrocas (3: 50) | Intermedio | — | sí |
| 079 | `slowpoke` | Slowpoke | agua | 80 | electrico | — | 1 | — | Pistola Agua (2: 20); Hidropulso (3: 40 `confundeDefensor` 2 monedas) | Común | — | sí |
| 095 | `onix` | Onix | lucha | 110 | agua | — | 1 | — | Tumba Rocas (3: 50, `quitaEnergiaRival`) | Fuerte | — | sí |
| 104 | `cubone` | Cubone | lucha | 60 | planta | — | 0 | — | Hueso Palo (2: 30) | Común | — | sí |

**Efectos y habilidades** (columna de ataques): `reduceDanoRival`, `aumentaDanoRecibido`, `quitaEnergiaRival`, `ganaEnergia`, `confundeDefensor`, `monedaDanoExtra`, `envenenaDefensor`, `reduceDanoPropio`, `monedaFalloRival`, `danoPorRacha`, `monedasDano` y `repiteDanoAlDerribar` (§3.6); `+` es una moneda que suma daño; `esp.` es el daño esperado de las tiradas. La única habilidad es `monedaDanoExtraAlAtacar` (Foco Energía, de Mankey y Machop).

Geodude ya sigue a su carta impresa (2026-11-22, tarea 14): Pulimento (1: `ganaEnergia` 2) y Lanzarrocas (3: 50), sin resistencia y con retirada 1; son valores provisionales hasta que Calidad los mida contra Brock. **Las 22 cartas ya están impresas** (2026-11-23). Las del Túnel Roca (Zubat, Machop, Onix, Cubone y Slowpoke) venían del primer catálogo (#340) con datos y sin carta. **Zubat y Slowpoke** siguen ya sus cartas desde la tarea 15 (2026-11-23), con `confundeDefensor` en Supersónico (1 moneda) e Hidropulso (2 monedas). Nidoran♂ guarda el número 32 de la Pokédex; su carta lleva impreso 029/150 (§8, 13).

### Jefes (1)

| Serie | Id | Pokémon | Tipo | PS | Debilidad | Ataques (coste: daño) | Llama a un aliado | XP |
|---|---|---|---|---|---|---|---|---|
| 01/20 | `pikachu-jefe` | Pikachu | electrico | 100 | lucha | Ataque Rápido (1: 10); Impactrueno (2: 30) | 50 % a la banca, 40 % al frente → weedle, caterpie, metapod, kakuna | 30 |

### Zonas

| Zona | Nombre | Salvajes | Entrenadores | Jefe |
|---|---|---|---|---|
| `bosque-verde` | Bosque Verde | caterpie, weedle, metapod, kakuna, pikachu | Cazabichos (weedle, caterpie, kakuna, metapod) | — |
| `gimnasio-plateada` | Gimnasio de Ciudad Plateada | — | Entrenador Joven (diglett, sandshrew) | — |
| `ruta-1` | Ruta 1 | pidgey, rattata | — | — |
| `ruta-2` | Ruta 2 | rattata, pidgey, caterpie, weedle | — | — |
| `ruta-22` | Ruta 22 | rattata, spearow, nidoran-f, nidoran-m, mankey | — | — |
| `tunel-roca` | Túnel Roca | zubat, geodude, machop, onix | PokéManiaco (cubone, slowpoke) | onix |

Las listas de Pokémon por zona están por contrastar con Serebii o Bulbapedia (§8, 16). La zona `tunel-roca` todavía lista a Onix como jefe, lo que ya no cuadra (§8, 15).

### Región de Kanto (`catalog/campana/regiones/kanto.json`, 18 nodos)

| Nodo | Tipo | Nombre | Datos | Salidas |
|---|---|---|---|---|
| `pueblo-paleta` | inicio | Pueblo Paleta | iniciales: bulbasaur, charmander, squirtle | `ruta-1` |
| `ruta-1` | bifurcacion | Ruta 1 | — | `ruta-1-pidgey`, `ruta-1-rattata` |
| `ruta-1-pidgey` | combate | Ruta 1: Pidgey | salvaje en `ruta-1`; fijo: pidgey | `ciudad-verde` |
| `ruta-1-rattata` | combate | Ruta 1: Rattata | salvaje en `ruta-1`; fijo: rattata | `ciudad-verde` |
| `ciudad-verde` | descanso | Centro Pokémon de Ciudad Verde | — | `ciudad-verde-salida` |
| `ciudad-verde-salida` | bifurcacion | Salida de Ciudad Verde | — | `ruta-22`, `ruta-2` |
| `ruta-22` | combate | Ruta 22 | salvaje en `ruta-22`; **opcional** | `ruta-2` |
| `ruta-2` | bifurcacion | Ruta 2 (sur) | — | `ruta-2-weedle`, `ruta-2-caterpie` |
| `ruta-2-weedle` | combate | Ruta 2: Weedle | salvaje en `ruta-2`; fijo: weedle | `cazabichos-1` |
| `ruta-2-caterpie` | combate | Ruta 2: Caterpie | salvaje en `ruta-2`; fijo: caterpie | `cazabichos-1` |
| `cazabichos-1` | combate | Bosque Verde: primer Cazabichos | entrenador en `bosque-verde`, clase Cazabichos | `cazabichos-2` |
| `cazabichos-2` | combate | Bosque Verde: segundo Cazabichos | entrenador en `bosque-verde`, clase Cazabichos | `aviso-pikachu` |
| `aviso-pikachu` | conversacion | Bosque Verde: un Cazabichos te avisa | Cazabichos; avisa de Pikachu y **cura** | `jefe-pikachu` |
| `jefe-pikachu` | jefe | Pikachu | jefe `pikachu-jefe` | `ruta-2-norte` |
| `ruta-2-norte` | bifurcacion | Ruta 2 (norte) | — | `ruta-2-norte-salvaje`, `centro-plateada` |
| `ruta-2-norte-salvaje` | combate | Ruta 2 (norte) | salvaje en `ruta-2`; **opcional** | `centro-plateada` |
| `centro-plateada` | descanso | Centro Pokémon de Ciudad Plateada | — | `gimnasio-joven` |
| `gimnasio-joven` | combate | Gimnasio: Entrenador Joven | entrenador en `gimnasio-plateada`, clase Entrenador Joven; fijo: diglett, sandshrew | `gimnasio-brock` |
| `gimnasio-brock` | gimnasio | Gimnasio de Ciudad Plateada | Brock (geodude, onix), medalla roca | (final) |

Con `RegionCampana.problemas()` y `problemasDeCatalogo` el motor comprueba la estructura y que todo lo que nombra un nodo existe en el catálogo (§4, Modelo de la ruta).
