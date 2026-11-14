# D-16 · Aliados con 6 categorías

Estado: **cerrada** (2026-11-08). Issue #116. Propuesta de Ayme; nada de esto está en el motor, el contrato ni el catálogo.

Amplía D-13: cada jefe pasa de 4 a **6 aliados, uno por categoría**, para que dos partidas contra el mismo jefe se parezcan menos entre sí. D-04 (slots, bloqueo, ayuda, objetivo del aliado, exceso de daño, umbrales) y el resto de D-13 no cambian.

> **T-70:** los textos, PS y ataques vigentes de cada aliado son los de las cartas del set y están en [`CARTAS.md`](./CARTAS.md) y en el catálogo. Lo que sigue es la decisión original y puede no coincidir con las cartas actuales.

## 1. Las 6 categorías

| Categoría | Qué hace | A quién afecta | Hoy |
|---|---|---|---|
| **Curandero** | Cura PS de otros, quita estados, da curación | Jefe y aliados | Cura (D-13) |
| **Tanque** | Absorbe daño, protege a los aliados, dificulta que los jugadores dañen al jefe | Jefe y aliados | Tanque (D-13) |
| **Daño** | Ataca fuerte; amenaza directa para los jugadores | Jugadores | Daño (D-13) |
| **Control** | Paraliza, duerme, confunde o limita las acciones de los jugadores | Jugadores | el Pícaro, con otro nombre |
| **Potenciador** | Mejora al jefe o a los aliados: más daño, defensa o velocidad | Jefe y aliados | nuevo |
| **Debilitador** | Reduce el daño, la defensa o las capacidades de los jugadores; les quita ventajas | Jugadores | nuevo |

Ejemplos de Ayme: Blissey (Curandero), Steelix (Tanque), Garchomp (Daño), Amoonguss (Control), Ninetales (Potenciador), Absol (Debilitador).

Potenciador y Debilitador se distinguen por a quién afectan: el primero mejora a los aliados y al jefe (sube el daño de Arceus); el segundo empeora a los jugadores (baja el daño de los jugadores). Pueden combinarse: un Potenciador sube el daño de Arceus mientras un Debilitador baja la defensa de los jugadores.

## 2. Qué cambia en las reglas

- **Dado de categoría: d6** en lugar de d4. No se repite una categoría ya en uso.
- Hay como mucho **4 aliados vivos** (un slot por jugador), así que en la mesa nunca están las 6 a la vez y siempre queda una categoría libre mientras haya slot libre.
- Cada jefe que invoca tiene **6 aliados** en su ficha. Un jefe que invoca una sola vez (Onix) solo usa 1 de sus 6 por partida: la variedad viene de cuál sale.
- La regla de reparto de D-13 se mantiene: **lo que cambia la vida o el daño del jefe y de los aliados lo resuelve el programa; lo que afecta a los Pokémon de los jugadores lo aplican los jugadores**, salvo los efectos que la app ya sabe aplicar (D-14).

## 3. Cómo se resolvería cada categoría (propuesta)

| Categoría | Lo aplica el programa | Lo aplican los jugadores |
|---|---|---|
| Curandero | Curar al jefe al final de su turno (`cura-jefe-N`, ya hecho); curar a un aliado; quitar veneno o quemadura al jefe (D-12) | — |
| Tanque | Reducir el daño que recibe el jefe (`tanque-jefe-N`, ya hecho); escudo: HP extra que absorbe daño antes que el jefe | — |
| Daño | Su ataque (ya existe) | Daño en la mesa a sus Pokémon (como hoy) |
| Control | Efectos de D-14 sobre un jugador, con duración, que la app ya muestra y renueva (`sinAtaque`, `sinRetirada`, `paralizarDefensor`); moneda lanzada por la app | Estados que la app no modela (dormir, confundir) |
| Potenciador | **Sumar N al daño de los ataques del jefe y/o de los aliados** mientras viva: la app lo suma al daño que propone al registrar el ataque | — |
| Debilitador | Reducir el daño de **un jugador concreto** (ver pregunta 2) | Quitar ventajas de la mesa (cartas, energías, cartas de ánimo) |

## 4. Decisiones (2026-11-08)

1. **El Pícaro desaparece: pasa a llamarse Control.** Conserva lo suyo (estados alterados, fuerza, contadores de daño) y sigue siendo el **único que ataca a la Banca**. El Debilitador es una categoría nueva.
2. **Tanque y Debilitador se separan por a quién actúan:** el Tanque **protege al jefe** (y a su bando); el Debilitador **reduce a los jugadores** (a un jugador concreto o a sus recursos). La reducción global del daño al jefe (`tanque-jefe-N`) sigue siendo del Tanque.
3. **Potenciador: la app suma el bonus al daño del ataque** (del jefe y/o de los aliados) mientras viva, y **muestra el valor total** al registrar el ataque. El evento guarda el daño final, como con el Tanque. Si el Potenciador cae, deja de sumar.
4. **Los 6 aliados en todos los jefes.** 8 aliados nuevos con los 4 jefes actuales, 14 con los 7 de lanzamiento.
5. **El dado de categoría se muestra como un d6 animado** con la cara de cada aliado del jefe en un lado, para que el jugador vea cuál va a aparecer. Es presentación: el resultado lo decide la app (punto siguiente) y las caras de las categorías ya en uso no pueden salir.

## 4 bis. Probabilidad de cada categoría

**Dado uniforme (decidido):** el dado elige con igual probabilidad entre las categorías libres (1/6 cada una al empezar). No hay pesos por categoría. El simulador medirá la varianza según la categoría que sale; solo si fuera muy grande se reabriría.

## 5. Trabajo que implica (tareas aparte, tras cerrar este documento)

- **Motor:** `CategoriaAliado` con 6 valores, d6, scripts nuevos (daño de los aliados y del jefe con Potenciador, reducción por jugador, curación de aliados, escudo, efectos de Control con `EfectoActivo`).
- **Contrato v6** (hecho): el enum nuevo con migración v5 → v6 (las partidas guardadas con `picaro` se leen como `control`). `modoPreparacion` (#106) pasa a la v7.
- **Catálogo y esquema:** 6 aliados por jefe; 2 nuevos por jefe actual.
- **App:** chips y d6 animado con las caras de los aliados en el diálogo de invocación; el daño total del ataque con el bonus del Potenciador; etiquetas y avisos de los efectos nuevos.
- **Simulador y balance:** modelar las categorías nuevas y recalibrar HP y rangos de X. La calibración de hoy (4 categorías) quedaría obsoleta; conviene esperar a este diseño.
- **GDD:** §4.4, glosario, valores provisionales y D-13.

## 6. Estado de la implementación por jefe

**Onix (hecho, catálogo v4).** Mapa Túnel Roca; Machop (daño, «Puño Incremento» 20× con 2 monedas, que tira la app), Geodude (tanque, 90 HP, «Rizo Defensa»: −10 a los ataques de los jugadores contra el jefe y contra los aliados), Zubat (cura, «Chupavidas» 10: cura 10 al jefe y a todos los aliados), Rhyhorn (control, «Tormenta de arena»: la mesa aplica los 10 al chequeo Pokémon), Cubone (potenciador, «Foco Energía»: antes de cada ataque del jefe la app tira una moneda y, con cara, suma 10 al daño) y Haunter (debilitador, «Rencor»: la mesa aplica la restricción). Regla aplicada: lo que cambia vida o daño del jefe y los aliados lo resuelve el programa; lo que afecta a los Pokémon de los jugadores lo aplica la mesa con el recordatorio de la app. Manectric, Kingdra y Arceus siguen provisionales hasta recibir sus listas.

**Manectric (hecho, catálogo v5).** Mapa Ruta 110; vida y ataques no cambian. Plusle (daño, «Chispazo» 30; la app nombra a los jugadores adyacentes al objetivo, que reciben 30 por la mesa), Minun (tanque, 90 HP, «Bola Voltio» 10; «Moflete Estático», aura: mientras está en juego, cada vez que los jugadores derrotan con un ataque a cualquier aliado —él incluido—, la app recuerda que el Pokémon atacante queda Paralizado), Oddish (cura, «Drenadoras»: la app cura 10 al jefe por cada jugador no eliminado al entrar y al final del turno del jefe; la mesa pone los contadores), Gulpin (control, «Tóxico», lo aplica la mesa), Poochyena (potenciador, «Aullido»: +20 fijo a cada ataque del jefe, lo suma la app) y Zigzagoon (debilitador, «Gruñido»: −10 a los ataques de los jugadores contra el jefe y los aliados, lo aplica la app y se suma al Tanque). Kingdra y Arceus siguen provisionales.

**KO por el ataque de entrada (decidido).** Si el ataque de entrada de un aliado deja KO al Pokémon Activo de un jugador que todavía no ha actuado esa ronda, ese jugador pierde su turno: sube un Pokémon de la banca, que no ataca hasta la ronda siguiente. Ese turno perdido es el que se sienta por el KO (T-72): no se sienta también el de la ronda siguiente. El motor lo aplica solo a los KO registrados justo después del ataque de aliado; un KO normal no quita el turno.

**Kingdra (hecho, catálogo v6).** Mapa Islas Remolino; vida y ataques no cambian. Krabby (daño, «Martillazo» 30+: la app tira 2 monedas y, con alguna cara, suma 50), Seel (tanque, «Velo Sagrado»: mientras viva, la app rechaza aplicar estados al jefe y, al entrar, le quita los que tuviera; las aplicaciones ya contadas para el bono se conservan), Golbat (cura, «Chupavidas» 30 al jefe y a los aliados; «Allanamiento» lo aplica la mesa), Tentacruel (control, «Constricción»: no se cambia el Pokémon Activo, lo aplica la mesa), Horsea (potenciador, «Agilidad»: +30 al primer ataque del jefe de cada turno, lo suma la app) y Magikarp (debilitador, «Bote»: la app tira una moneda cada vez que un ataque de los jugadores va a dañarlo y, con cara, registra 0 de daño; el ataque gasta el turno). 

**Arceus (hecho, catálogo v7, contrato v7).** Mapa Sala Origen; vida y ataques no cambian. Medicham (daño, «Puño Dinámico» 70: Confunde, y suma 70 si el defensor ya tenía un estado, que responde la mesa; «Energía Pura» lo aplica la mesa), Bronzong (tanque, 100 HP, «Bloqueo»: los jugadores solo pueden atacarle o pasar el turno, y recibe 100 menos por ataque), Chingling (cura, 50 HP, «Deseo»: al entrar la app tira 10 monedas por el jefe, 100 HP por cara, y una por cada aliado, 100 por cara; cada jugador tira una por cada uno de sus Pokémon), Nosepass (control, 60 HP, «Fijar Blanco»: la primera moneda de cada jugador desde que entra es cruz, aunque Nosepass caiga; lo aplica la mesa), Solrock (potenciador, 70 HP, «Envite Ígneo» 10: cada uso hace 10 más y le da 10 HP máximos y actuales; la app cuenta los usos) y Lunatone (debilitador, 80 HP, «Fuerza Lunar» 10: el rival tira una moneda y con cruz su siguiente ataque hace 30 menos; la app registra la moneda). Los datos nuevos del evento (monedas) son el contrato v7.

**Sin bloqueo de slot (todos los jefes).** El aliado ataca siempre al dueño de su slot, pero este puede ignorarlo y dañar al jefe. Solo Bronzong obliga a atacar. Se prioriza entre dar al jefe y quitarse estorbos (D-04 §2).

**Las 6 categorías son obligatorias** en el catálogo y su esquema; los 4 jefes ya las tienen.

**Estados en los aliados (pendiente, D-17).** Los aliados también podrán quedar Envenenados o Quemados por un ataque de los jugadores. Decidido: lo lleva la app como en el jefe (D-12; daño en el chequeo al cerrar el turno del jefe), al atacar a un aliado se marca el estado aplicado, Velo Sagrado también los evita en los aliados y las aplicaciones cuentan para el bono de estados. Implica contrato v7 y va en una tarea aparte tras Arceus.
