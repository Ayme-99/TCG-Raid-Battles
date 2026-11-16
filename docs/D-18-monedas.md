# D-18 · Monedas del juego (T-73)

Cada moneda del juego, quién la lanza, dónde cae y qué queda registrado. Desde T-73 **todas** las monedas que lanza la app son la misma: se echan a suerte con el azar de la partida y **caen sobre la mesa**, como los dados (cámara incluida), enseñan lo que ha salido y solo entonces se registra el evento. No cambia ninguna regla ni el balance.

## Inventario

| # | Moneda | Quién la lanza | Cuántas | Cae… | Qué cambia | Qué queda registrado |
|---|---|---|---|---|---|---|
| 1 | **Llamada del jefe** (D-04 §7.3). Solo los jefes sin invocación segura; hoy los cuatro son seguros, así que no se lanza | App | 1 | ante los aliados | Cruz: no entra aliado | `SinInvocacion` (cruz) o `AliadoInvocado` (cara) |
| 2 | **Quemadura del jefe** (D-12) | App (antes la decían los jugadores) | 1 | ante el jefe | Cara: se quita la quemadura | `FinTurnoJefe.monedaQuemadura` |
| 3 | **Quemadura de cada aliado** (D-17) | App (antes la decían los jugadores) | 1 por aliado quemado | ante los aliados | Cara: se quita la quemadura | `FinTurnoJefe.monedasQuemaduraAliados` |
| 4 | **Ataque del jefe con moneda** (D-14: Onda Trueno de Manectric) | App | 1 | ante el jefe | Cara: se aplica el efecto | `AtaqueJefe.efecto.moneda` |
| 5 | **Potenciador** (Cubone, Foco Energía) | App | 1 por Potenciador con moneda, en cada ataque del jefe | ante el jefe | Cara: +10 al ataque | `AtaqueJefe.dano` (ya con el bonus) |
| 6 | **Puño Incremento** 20× (Machop) | App | 2 | ante los aliados | 20 de daño por cara | `AtaqueAliado.dano` |
| 7 | **Martillazo** 30+ (Krabby) | App | 2 | ante los aliados | Con alguna cara, +50 | `AtaqueAliado.dano` |
| 8 | **Deseo** (Chingling) | App | 10 + los aliados en mesa + 1 | ante los aliados | Cura al jefe y a los aliados | `AliadoInvocado.monedas` |
| 9 | **Bote** (Magikarp) | El jugador atacante, **la lanza la app** | 1 | ante el asiento del jugador | Cara: se evita todo el daño | `AtaqueAAliado.dano` (0 si cara) |
| 10 | **Fuerza Lunar** (Lunatone) | El jugador rival, **la lanza la app** | 1 | ante el asiento del rival | Cruz: −30 al siguiente ataque | `AtaqueAliado.moneda` |

**Fijar Blanco** (Nosepass) afecta a 9 y 10: la primera moneda de cada jugador es cruz y la lleva la mesa a mano. En ese caso la app **pregunta** qué ha salido, también sobre la mesa y no en un diálogo (`preguntarMoneda` → `TiradaMesa.pregunta`): la moneda cae ante el jugador, se queda de canto y junto a ella salen los avisos de Fijar Blanco y los botones Cara y Cruz; al elegir, gira hasta ese lado y enseña el resultado. No tiene tiempo límite.

Fuera de la app, porque no gestiona los ataques de los jugadores: las monedas de las cartas de los jugadores y las que lanzan ellos por cada uno de sus Pokémon con Deseo.

## Una sola forma de lanzar

- `lanzarMonedas(ref, cuantas:, lugar:, asiento:, leyenda:)` saca el azar en orden (una vez por moneda), enseña la tirada y devuelve el resultado de cada moneda cuando ya han parado. Todos los sitios de arriba la usan; el azar fijo de los tests da siempre lo mismo.
- Mientras cae una tirada, los botones que lanzan monedas se ignoran (no se lanza dos veces) y una segunda tirada espera a la primera. Si no hubiera mesa que la anime, la tirada se da por terminada sola: ninguna pantalla se queda esperando una moneda.
- **Registro**: el motor es determinista y solo reproduce lo registrado. Las monedas de las que depende una decisión (2, 3, 4, 8, 10) van en su evento; en las que solo importa el resultado (5, 6, 7, 9) va el daño final. El historial y «deshacer» dan lo mismo y **el contrato JSON no cambia**.

## La moneda y sus diseños

`DisenoMoneda` (en `app/lib/pantallas/moneda.dart`) dice cómo se ve: un widget para la cara, otro para la cruz y el color del canto. El juego pone el giro, el grosor, el brillo y la caída. `disenoMonedaProvider` es el diseño en uso y todas las monedas lo siguen.

- Clásica (`monedaClasica`): oro con una bola roja y blanca en la cara y una estrella de cuatro puntas (la «cruz») sobre azul noche en la cruz.
- **Monedas de la tienda**: un diseño nuevo es `DisenoMoneda.deImagenes(id, nombre, cara, cruz, canto)` con dos imágenes cuadradas y se registra en `disenosDeMoneda`. Falta guardar cuál ha elegido el jugador (con las compras).
