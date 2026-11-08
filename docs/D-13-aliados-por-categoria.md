# D-13 · Aliados por categoría

Estado: **cerrada** (2026-11-06). Issue #70. Valores y aliados concretos provisionales hasta T-17.

Sustituye de D-04/D-07 el reparto de aliados por azar de una lista libre (D-04 §7.3, paso 3) y que las habilidades las resuelva siempre la mesa (D-04 §7.4 y §7.5). El resto de D-04 sigue igual: slots, bloqueo, ayuda, objetivo del aliado, exceso de daño y umbrales.

## 1. Los 4 aliados de un jefe

Cada jefe que invoca tiene **4 aliados, uno por categoría**: Daño, Tanque, Cura y Pícaro. Cada categoría está centrada en una manera distinta de molestar a los jugadores. Qué hace exactamente cada aliado lo define su carta (§3).

Cada jefe tiene sus **propios** 4 aliados. Ejemplo ilustrativo (no es un jefe real, ni sus números): Daño Rattata, Tanque Mr. Mime, Cura Chansey, Pícaro Scyther.

**Pícaro** es la categoría de **control**, la más versátil: aplica estados alterados, modifica la fuerza, pone contadores de daño, etc. Son los **únicos aliados que atacan a la Banca**; el resto solo afecta al Pokémon Activo.

## 2. Cómo se resuelve un intento de invocación

El umbral de HP, que cada umbral cuente una vez y la moneda **no cambian** (D-04 §7.1 y §7.2). Después de la moneda:

1. Si el jefe usa moneda, se tira: si no sale cara, no hay aliado. Los jefes con invocación **segura** (enmienda v1.7) no tiran moneda y este paso siempre sigue.
2. Si sale cara, el **dado de slot** (moneda con 2 slots, d3 con 3, d4 con 4) elige un slot libre de un jugador activo. **No se repite un slot ocupado ni de un jugador eliminado.**
3. El **dado de categoría** (d4) elige una de las 4 categorías. **No se repite una categoría que ya esté en uso** por un aliado vivo.
4. Entra el aliado de esa categoría que figura en la ficha del jefe, en ese slot.
5. Si **no hay slot libre, no hay invocación** y no se tira ningún dado.

En la app los dos dados eligen con la misma probabilidad entre los valores que quedan libres. En papel se consigue repitiendo la tirada cuando sale un valor ocupado.

Siempre queda una categoría libre cuando hay un slot libre: hay como mucho 4 aliados vivos y, si queda un slot libre, como mucho 3 están en juego. Un aliado que cae libera su slot (si su dueño sigue activo) y su categoría, y se puede volver a invocar.

## 3. Efectos de las cartas de aliado

Cada carta de aliado indica cómo se aplican sus efectos. Hay dos tipos de carta:

- **Los aplica el programa.** El efecto está implementado como un script en el código y la app lo ejecuta sola, igual que el veneno y la quemadura del jefe (D-12).
- **Los aplica el jugador.** El efecto está escrito en la carta y se resuelve en la mesa, como hasta ahora. El asistente solo lo registra.

Las habilidades siguen siendo **pasivas** (D-04 §7.4).

**Regla de reparto (enmienda 2026-11-08):** lo que cambia la vida del jefe lo resuelve el programa; lo que afecta a los Pokémon de los jugadores lo aplican los jugadores. Por eso los aliados de la categoría **Cura** llevan `efectos: programa` y un script `cura-jefe-N` (N = 20 / 30 / 40 / 50 según el jefe) que cura al jefe al final de su turno, antes del chequeo de estados (D-12) y sin pasar de su HP máximo. Cuenta como curación del jefe (`curacionJefe`). Los aliados de la categoría **Tanque** llevan `efectos: programa` y un script `tanque-jefe-N` (N = 10 / 20 / 30 / 40): mientras estén vivos, cada ataque de los jugadores hace N de daño menos al jefe (las reducciones se suman y un ataque no baja de 0). El jugador anota el daño de su ataque; el motor descuenta la reducción y solo cuenta como daño del jugador lo que de verdad resta HP al jefe.

## 4. Datos que hay que añadir

- La ficha del jefe en el catálogo (T-13) lista **un aliado por categoría**, en vez de una lista libre.
- Cada aliado del catálogo lleva su `categoria`, quién aplica sus efectos (`programa` o `jugador`) y, si es `programa`, el identificador del script.
- El registro de partida (contrato) tendrá que guardar la categoría del aliado invocado y los efectos aplicados por el programa. Cambia el contrato y el motor.

## 5. Cambios en otros documentos

- `incursiones_gdd.md` → v1.5: §4.4, glosario, valores provisionales (§9), índice de apoyo (§11) y este cambio en el historial.
- `docs/D-04-aliados.md`: aviso en §7 de lo que sustituye esta decisión.

## 6. Pendiente (tareas aparte, sin implementar todavía)

- Motor: dado de categoría, no repetir categoría, efectos con script.
- Contrato: nueva versión con la categoría y los efectos del programa.
- Catálogo (T-13): `categoria` por aliado y un aliado por categoría en cada jefe.
- App: mostrar la categoría del aliado y los efectos automáticos.
- Simulador: aún no modela aliados.

## 7. Baraja de ataques del jefe (enmienda, v1.6)

- El jefe no tiene mazo de aliados: tiene sus 4 aliados (§1) y una **baraja de ataques**, como el juego oficial. Cada carta dice «Ataque X contra jugador Y».
- El **máximo de ataques por turno** lo define esa baraja, no una cifra fija. La cifra 2/3/4/5 de las tablas de balance es solo un supuesto del simulador.
- Se mantiene la mecánica de robar cartas: el objetivo de cada ataque sale de la carta. No existe una regla de objetivo por ranura de ataque.
- **Qué lleva la app (v1.8):** el jefe y sus aliados (HP, daño recibido y ataques que hacen). Los Pokémon de los jugadores (cartas, contadores de daño, ataques y efectos) y la baraja de ataques del jefe se gestionan en la mesa; a la app solo le llegan el daño que los jugadores hacen al jefe y los KO, y cada ataque que sale se registra.
