# Campaña: revisión de los 10 flujos (#589)

**Fecha:** 2026-11-28 · **Autor:** Calidad y soporte · **Versión:** master `74dbe6a` · **Solo informe y un guion en `sim/`**: no se cambia código ni reglas.

## Cómo se ha revisado (límite importante)

**No he podido jugar la app en la web.** En esta sesión no hay Flutter, `pub.dev` está bloqueado y el navegador no alcanza mi máquina, así que no puedo ejecutar `flutter run -d web-server`. En su lugar:

1. **Motor y catálogo reales de master, jugados con un guion** (`sim/bin/revision_flujos_campana.dart`, salida en `campana_flujos_2026-11-28/revision_flujos.txt`): cada flujo se juega con `PartidaCampana` y el combate con la IA, y se comprueba lo que dice D-20. Resultado: **0 fallos del motor en los flujos 1 a 8** salvo lo que recoge la issue #597.
2. **Lectura del código de la app** para lo que solo existe en pantalla (flujos 1, 9 y 10 y los textos).
3. **Lo que queda por jugar en la web** está marcado «sin jugar en pantalla» y se lista al final. Lo que ya están viendo jugando (#590, #591, #592) no se repite.

## Tabla

| # | Flujo | Resultado | Fallo o hueco | Sector |
|---|---|---|---|---|
| 1 | Inicio → Nueva campaña → inicial → mapa; Continuar | **Motor OK:** nueva partida en Pueblo Paleta con 1.000 de dinero; los tres iniciales entran con PS completos; no se puede avanzar sin inicial ni cambiarlo después; guardar y cargar funciona en cuatro momentos (tras el inicial, con un combate sin jugar, con captura pendiente); una partida de la versión 1 se carga; una versión desconocida se rechaza con mensaje; una partida con un Pokémon que ya no existe se detecta (`problemas`). **Pantalla (código):** hoy el inicio no tiene los botones «Nueva campaña» y «Continuar campaña»; se entra por «Nueva partida → Modo campaña» y la partida se retoma sola | #585 (ya abierta, Programación). **Texto desfasado «Al Gimnasio de Brock»** en la pantalla sin partida: #598. Sesión (#479): sin jugar en pantalla | Programación |
| 2 | Salvaje → captura → mapa | **OK.** Sin Pokéballs: «No te quedan de esas» y el panel dice «No te quedan Balls: este combate acaba sin captura» con «Seguir». Con Pokéballs, 60 tiradas con Común: 44 aciertos y 16 fallos (≈ 73 %, como el 75 % de D-20); tras fallar se puede volver a tirar mientras queden. Con la captura pendiente no se avanza; capturar con equipo lleno manda al PC al sustituido; la captura lograda no se puede dejar ir. Repetir un salvaje vencido da XP y captura, sin puntos ni dinero | Ninguno | — |
| 3 | Entrenador, gimnasio y jefe | **Entrenador OK** (dinero y XP, sin captura). **Aviso de Pikachu OK:** cura al equipo, fija el retorno y solo se puede oír una vez. **Pikachu jefe OK:** captura de su carta normal la primera vez y ninguna después. **Brock OK en lo demás:** medalla, piedra ex y dinero (1.400). **Fallo:** **el rival no empieza primero en los gimnasios**, aunque D-20 §10 lo decidió el 26-11 | **#597** | Programación |
| 4 | Derrota → punto de retorno | **OK.** Sin haber curado, vuelve a Pueblo Paleta; tras curar en Ciudad Verde, vuelve allí; perder contra Pikachu jefe vuelve al aviso (que cura); el equipo queda curado y se conservan XP, dinero, puntos, medallas y piedras ex; la pantalla lo explica («Vuelves al último sitio donde te curaste…»). **Hueco:** abandonar un combate a medias (cerrar la app) no cuesta nada: ni derrota ni objetos | **#600** (decide Diseño) | Diseño |
| 5 | Centro Pokémon | **OK.** Curar (equipo y PC) y volver a curar no falla; salir sin curar es posible y no cambia el retorno; comprar (Pokéballs, dinero insuficiente, cantidad 0, objeto que no vende); la piedra ex se vende solo desde la 2.ª medalla; PC: sacar, dejar, intercambiar, no dejar al último, no sacar con el equipo lleno, no usarlo fuera de un centro | Ninguno | — |
| 6 | Equipo: Poción, evolución, ex | **Poción OK** (+20, no pasa del máximo, no revive, error con PS llenos). **Evolución por XP OK** (gasta 70 de la reserva) pero **queda a 10 PS** (Squirtle 20/80 → Wartortle 10/110): es lo de #570 y #571 (decisión del 28-11: conservar el %, redondear arriba; el debilitado, a 10). **No medida**: esperar a que se fusione. Hacerse ex: no se puede probar (no hay carta ex en el catálogo); piedras de evolución: la Luna se recoge al llegar a `monte-moon` (una sola vez, se conserva al guardar); no se compran Trueno, Agua, Fuego ni Hoja hasta Azulona, que no está | Ninguno nuevo (#570, #571) | Programación, Diseño |
| 7 | Objetos en combate | **OK.** Poción en combate no gasta turno; Cuerda Huida cambia al activo y pasa el turno; la mochila descuenta lo usado al terminar el combate (Pociones 2 → 1, Cuerdas 1 → 0); el Repelente solo vale con un salvaje | Ninguno. Pantalla (hojas, botones): sin jugar | — |
| 8 | Bifurcaciones y vuelta atrás | **OK.** Solo se va a las salidas del nodo; con un combate pendiente no se avanza; se puede volver a un nodo ya visitado y elegir la otra rama; no a uno no visitado; un salvaje vencido se repite, un entrenador no. La Piedra Luna se coge al llegar a `monte-moon` y no se repone | Ninguno en el motor. En pantalla: #590 (`sale primero` marca a un caído) | Programación |
| 9 | Girar el móvil (#487) | **Código OK, sin jugar en pantalla:** `SoloHorizontal` tapa con «Gira el móvil» sin desmontar el hijo (el combate, lo comprado y la partida siguen); hojas y diálogos pasan por `mostrarHojaCampana`/`mostrarDialogoCampana`. **Hueco ya conocido:** en horizontal 1280×720 la banca y «Tu Pokémon ha caído» quedan fuera de pantalla | #592 (ya abierta) | Diseño, Programación |
| 10 | Puntos y tienda del menú | **Código OK, sin jugar en pantalla:** la campaña no gasta puntos (los precios son de dinero), solo suma `hitosPendientes`; la tienda del menú exige sesión. **Fallo:** «Empezar de nuevo» descarta los puntos de hitos aún no enviados (salvajes y entrenadores se envían con los jefes o al iniciar sesión) y el aviso no lo dice bien | **#599** | Programación, Diseño |

## Issues «Bugs» abiertas

- **#597** — el rival nunca empieza primero en los gimnasios (la regla del 26-11 no está implementada; Calidad midió que vale unos 26 puntos).
- **#598** — la pantalla sin partida dice «Al Gimnasio de Brock» y ya se llega a Misty.
- **#599** — «Empezar de nuevo» descarta los puntos aún no enviados a la cuenta.
- **#600** — salir de un combate a medias no cuesta nada (hueco de diseño).
- Ya existían y no se duplican: #590, #591, #592. Relacionadas: #585 (botones del inicio), #570 y #571 (PS al evolucionar), #588 (interfaz).

## Lo que queda por jugar en la web (para Bugs o Ayme)

1. Flujo 1: abrir la campaña con y sin sesión, con una partida en la cuenta y otra local (pantalla de conflicto `_ElegirPartida`), cerrar y volver a abrir.
2. Flujos 2, 5, 6 y 7: que los botones y hojas hagan lo que hace el motor (captura sin Balls, comprar, PC, Poción y Cuerda Huida en el combate real).
3. Flujo 9: girar el móvil con un combate en curso y con la hoja del equipo abierta.
4. Flujo 10: ganar un jefe con sesión y ver los puntos en la tienda del menú.
5. Evolución (#570): medirla en los flujos **solo cuando esté fusionado**, como pide Ayme.

## Cómo repetirlo

```
cd sim && dart run bin/revision_flujos_campana.dart
```
