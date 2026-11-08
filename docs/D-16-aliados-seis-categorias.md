# D-16 · Aliados con 6 categorías

Estado: **decisiones tomadas, falta cerrar la probabilidad de las categorías** (2026-11-08). Issue #116. Propuesta de Ayme; nada de esto está en el motor, el contrato ni el catálogo.

Amplía D-13: cada jefe pasa de 4 a **6 aliados, uno por categoría**, para que dos partidas contra el mismo jefe se parezcan menos entre sí. D-04 (slots, bloqueo, ayuda, objetivo del aliado, exceso de daño, umbrales) y el resto de D-13 no cambian.

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

## 4 bis. Pendiente: probabilidad de cada categoría

El dado elige hoy con **igual probabilidad entre las categorías libres** (1/6 cada una al empezar). La alternativa es dar más o menos peso a algunas (por ejemplo, que el aliado de Daño salga menos que el Curandero). Propuesta: mantener la probabilidad igual y medir en el simulador cuánto cambia el resultado según la categoría que sale; solo si la diferencia es grande se tocan los pesos.

## 5. Trabajo que implica (tareas aparte, tras cerrar este documento)

- **Motor:** `CategoriaAliado` con 6 valores, d6, scripts nuevos (daño de los aliados y del jefe con Potenciador, reducción por jugador, curación de aliados, escudo, efectos de Control con `EfectoActivo`).
- **Contrato v6:** el enum nuevo. Se hace junto con `modoPreparacion` (#106) para un solo salto de versión, con migración v5 → v6 (las partidas guardadas con `picaro` se leen como `control`).
- **Catálogo y esquema:** 6 aliados por jefe; 2 nuevos por jefe actual.
- **App:** chips y d6 animado con las caras de los aliados en el diálogo de invocación; el daño total del ataque con el bonus del Potenciador; etiquetas y avisos de los efectos nuevos.
- **Simulador y balance:** modelar las categorías nuevas y recalibrar HP y rangos de X. La calibración de hoy (4 categorías) quedaría obsoleta; conviene esperar a este diseño.
- **GDD:** §4.4, glosario, valores provisionales y D-13.
