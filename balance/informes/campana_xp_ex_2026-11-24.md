# Modo campaña: ritmo de XP y cartas ex al llegar a la Liga (#451)

Fecha: 2026-11-24 (actualizado tras el rebase sobre master con #454, #455 y #460) · Herramientas: `sim/bin/sim_campana_ex.dart` (cuentas de XP y ex) y `sim/bin/sim_campana_partida.dart --modo=pociones` (Brock con Pociones) · Datos: `campana_xp_ex_2026-11-24.csv` y `.txt` (salida completa)

Objetivo fijado por Ayme el 2026-11-24: **12 ex o más** entre equipo y PC al llegar a la Liga (D-20 §2.1, D-21 §2.5).

## Resumen

1. **Que se llegue a 12 ex depende de un dato que hoy no existe: cuánta XP da cada tramo.** Solo existe el tramo 1. Medido en el catálogo, su ruta principal da **180 XP** (sin los desvíos opcionales). Si los otros siete tramos se parecen, la ruta suma unos **1.440 XP** y salen **16 ex** (el máximo con los 16 Pokémon posibles), sobrando margen. Con los **~100 XP por tramo** (700–900 en total) de la estimación de Diseño salen **10 ex** en el mejor caso: falta el objetivo.
2. **La estimación de 700–900 XP parece contar solo hasta antes del líder.** Antes de Brock hay 130 XP (Ruta 1 y 2: 20; dos Cazabichos: 60; Pikachu: 30; Entrenador Joven: 20) y Brock suma 50 más (Geodude 20 y Onix 30). Ocho tramos de ~110 dan 880. Si cada líder aporta algo parecido a Brock, la cuenta correcta está más cerca de 1.200 a 1.400 que de 800. Es una hipótesis: hay que confirmarla con el diseño real de los tramos 2 a 8 (tarea 11).
3. **Fijar `xpEvolucion` en 80 en vez de 110 es la palanca que más pesa.** Con ~100 XP por tramo, pasa de 7 a 10 ex (política «barata») y de 4 a 7 (política «por orden»). Con 180 XP por tramo, de 13 a 16 y de 11 a 16.
4. **Repetir salvajes cubre el hueco, pero cuesta más combates con 110.** Con ~100 XP por tramo y `xpEvolucion` 80 hacen falta de **8 a 16 combates** repetidos (política barata, 160 XP extra) o de **18 a 36** (política por orden, 360 XP). Con 110 hacen falta de **24 a 48** o de **36 a 72**. D-20 estimaba 25 a 40.
5. **Las medallas de los ex, ya decididas en 2/3/4 (Básico ex 2, Fase 1 ex 3, Fase 2 ex 4; Onix ex a 2), no cambian el total en la Liga: solo adelantan los primeros ex.** El primero llega con la 2.ª medalla (Pikachu u Onix, 1 ex) y con la 3.ª ya hay 2 a 4. Esto sustituye al 4/4/5 con el que medí antes.
6. **Las Pociones en combate (sin gastar turno, sin límite por combate, #435) no dan ventaja que haga falta frenar en Brock, y cuestan ex si se compran muchas.** Con 5 Balls y el inicial evolucionado (70 XP, como en el juego) Brock sale a la primera en **99 / 97 / 100 %** (Bulbasaur / Charmander / Squirtle) **sin ninguna Poción**; con Poción, 99 / 98 / 100. Sin evolución (peor caso) sale 77 / 98 / 98 %, y **1 Poción lleva a Bulbasaur al 95 %**. Para llegar al 75 % no hace falta ninguna Poción. Cada Poción son 300 de dinero que no van a piedras ex: con 6 por tramo el equipo se queda en 9 ex.
7. **Con 1.000 de dinero inicial y la Poción a 300, Brock no queda trivial por culpa de las Pociones.** El muro del primer tramo es **llegar a Brock** (Pikachu con Squirtle sale 65 %), y ahí las Pociones no llegan (se compran en Plateada, después). Si Ayme quiere frenar la Poción de todos modos, el precio 500 o un límite de compra de 1 antes de Brock no cambian ninguna cifra de Brock, así que no hacen falta (sección 4).

## Qué es y qué no es esto

Es un **modelo de cuentas** (XP, medallas, piedras, dinero), no un simulador de combate. No mide si el equipo gana. Los tramos 2 a 8 no tienen rutas, rivales ni zonas, así que se parte de **supuestos explícitos** que el programa lista y que conviene discutir antes de fiarse de cifras exactas:

| Supuesto | Valor | Dónde se cambia |
|---|---|---|
| XP de la ruta principal por tramo | 100 (Diseño), 180 (como el tramo 1) y creciente de 180 a 360 | `esc` en `main` |
| Reglas de XP | 10 / 20 / 30 por Pokémon rival según categoría; `pokemonPorEntrenador` 2; los aliados caídos de los jefes no cuentan | D-20 §10.6 |
| Tramo en el que se captura cada Pokémon | Orden de los juegos de Kanto (por contrastar con Serebii y Bulbapedia, #384) | `catalogo()` |
| Capturas | Siempre se consiguen; coste esperado en Pokéballs = 200 / probabilidad de la categoría | `correr()` |
| 16 Pokémon posibles | Inicial, Caterpie, Weedle, Pidgey, Rattata, Pikachu, Spearow, Zubat, Sandshrew, Mankey, Geodude, Diglett, Machop, Onix, Cubone y Slowpoke | `catalogo()` |
| Fuera del cómputo | Nidoran♀ y ♂ (Nidoqueen y Nidoking piden Piedra Lunar, que no existe) y Eevee (sin zona) | `excluidos` |
| Evaluación | Al acabar cada tramo, con una medalla más; la piedra de premio de la medalla se puede usar ya | `correr()` |
| Dinero | 1.000 de salida y 2.060 a 3.110 por tramo (D-20 §10.6) | `dineroTramo` |

Reglas de D-20 que sí aplica: Caterpie y Weedle cuestan 50 XP y el inicial 70 (§10.6); las demás evoluciones, `xpEvo` (80 u 110); intercambio gratis (Golem y Machamp); piedra ex de premio por medalla y a 2.000 de dinero, a la venta desde la 2.ª medalla (#447); Pikachu y Onix son Básico ex (0 XP); **medallas mínimas de los ex 2/3/4 (Básico ex 2, Fase 1 ex 3, Fase 2 ex 4; Onix ex a 2)**, decididas el 2026-11-24 (D-20 §10.11, #454, #460); el ex pide medallas de su tipo y no menos que su última fase normal. Las Pociones no cambian la XP: solo gastan dinero (sección 5).

Dos políticas del jugador: **barata** = completa primero las líneas que menos XP cuestan (cota superior de ex); **por orden** = evoluciona en el orden en que captura, sin saltarse ninguna (se parece más a jugar sin plan).

## 1. XP de la ruta principal, sin repetir salvajes

| Escenario | Por tramo | Total |
|---|---|---|
| Estimación de Diseño | ~100 | 800 |
| Como el tramo 1 (medido) | 180 | 1.440 |
| Creciente (rivales más fuertes) | 180 a 360 | 2.160 |

Tramo 1 (catálogo): Ruta 1 10 · Ruta 2 10 · dos Cazabichos de 2 Pokémon, media 15 cada Pokémon (Caterpie y Weedle 10, Metapod y Kakuna 20) = 60 · Pikachu 30 · Entrenador Joven (Diglett y Sandshrew) 20 · Brock (Geodude 20 y Onix 30) 50 = **180**, igual que el «unos 180 tras Brock» de D-20 §10.6. Los desvíos opcionales (Ruta 22 y Ruta 2 norte) suman 10 cada uno y no se cuentan.

## 2. Ex al llegar a la Liga (medallas 2/3/4, inicial Bulbasaur)

| XP de la ruta | `xpEvo` | Política | **Ex** | De Fase 2 | XP gastada | Piedras compradas |
|---|---|---|---|---|---|---|
| ~100 por tramo (800) | 80 | barata | **10** | 3 | 740 | 2 |
| ~100 por tramo | 80 | por orden | **7** | 4 | 730 | 0 |
| ~100 por tramo | 110 | barata | **7** | 3 | 720 | 0 |
| ~100 por tramo | 110 | por orden | **4** | 4 | 720 | 0 |
| 180 por tramo (1.440) | 80 | barata y por orden | **16** | 6 | 1.370 | 8 |
| 180 por tramo | 110 | barata | **13** | 5 | 1.380 | 5 |
| 180 por tramo | 110 | por orden | **11** | 5 | 1.380 | 3 |
| Creciente (2.160) | 80 | ambas | **16** | 6 | 1.370 | 8 |
| Creciente | 110 | ambas | **16** | 6 | 1.820 | 8 |

Con ~100 XP por tramo el equipo gasta unos 740 XP y se queda sin XP, no sin piedras: tiene 8 de premio y compra 2 o ninguna. Con 180 el límite pasa a ser el número de Pokémon capturados (16).

**Comprobación cruzada con D-20:** el ejemplo de Diseño (12 Pokémon con tres líneas de tres fases) cuesta 1.050 XP con `xpEvo` 80 y 1.380 con 110, de acuerdo con su «unos 1.100 a 1.300».

## 3. Repetir salvajes: cuánto hace falta para llegar a 12 ex

XP extra por tramo que hay que añadir hasta llegar a 12 ex, y su equivalencia en combates repetidos según la XP por combate (10 = Común, 20 = Intermedio):

| XP de la ruta | `xpEvo` | Política | Extra total | Combates a 10 XP | a 15 | a 20 |
|---|---|---|---|---|---|---|
| ~100 por tramo | 80 | barata | 160 | 16 | 11 | 8 |
| ~100 por tramo | 80 | por orden | 360 | 36 | 24 | 18 |
| ~100 por tramo | 110 | barata | 480 | 48 | 32 | 24 |
| ~100 por tramo | 110 | por orden | 720 | 72 | 48 | 36 |
| 180 por tramo | 80 | cualquiera | 0 | 0 | 0 | 0 |
| 180 por tramo | 110 | por orden | 80 | 8 | 6 | 4 |

Los combates son totales en toda la campaña, no por tramo. Repetir salvajes solo aburre si se concentra: repartidos por los ocho tramos son de 1 a 9 combates por tramo.

## 4. Medallas mínimas de los ex (2/3/4) y Brock con Pociones

### 4.1 Medallas de los ex

Ex hechos tras cada medalla (1 a 8), política barata y `xpEvo` 80. La fila **D 2/3/4** es la decidida; A, B y C son las propuestas antiguas, solo para comparar:

| Opción | Ruta de 180 XP | De ellos Fase 2 | Ruta de ~100 XP | De ellos Fase 2 |
|---|---|---|---|---|
| A 4/4/5 (antigua) | 0 0 0 6 8 11 13 16 | 0 0 0 0 2 3 4 6 | 0 0 0 3 7 8 9 10 | 0 0 0 0 2 2 2 3 |
| B 3/4/5 (antigua) | 0 0 2 6 8 11 13 16 | 0 0 0 0 2 3 4 6 | 0 0 2 3 7 8 9 10 | 0 0 0 0 2 2 2 3 |
| C 3/3/4 (antigua) | 0 0 4 6 8 11 13 16 | 0 0 0 2 2 3 4 6 | 0 0 2 5 7 8 9 10 | 0 0 0 2 2 2 2 3 |
| **D 2/3/4 (decidida)** | **0 1 4 6 8 11 13 16** | 0 0 0 2 2 3 4 6 | **0 1 2 5 7 8 9 10** | 0 0 0 2 2 2 2 3 |

- El total en la Liga no cambia (16 y 10): lo fija la XP. D solo **adelanta** los primeros ex: 1 con la 2.ª medalla (Pikachu u Onix, Básico ex), 2 a 4 con la 3.ª y 5 a 6 con la 4.ª.
- Con la ruta de ~100 XP, D da 1 ex con la 2.ª medalla y 2 con la 3.ª; con 180 XP, 4 con la 3.ª. Los ex de 330 PS (Fase 2) llegan con la 4.ª medalla (2 ex).

### 4.2 Brock (#409) con Pociones: primer intento

Simulador de partida completa con el catálogo de master (Ivysaur, Charmeleon y Wartortle reales, #455). 1.500 recorridos por inicial, política B de equipo, 5 Pokéballs, Ruta 1 con capturas, retroceder al último centro. La Poción cura 20 PS, no gasta turno, no tiene límite por combate; el simulador la usa cuando los PS del activo bajan del 50 % (la IA y el motor reales aún no la tienen: es la tarea 20, #458).

| Inicial | Pociones | Sin evolución del inicial (peor caso): Brock a la 1.ª | Con evolución a 70 XP: Brock a la 1.ª |
|---|---|---|---|
| Bulbasaur | 0 | 76,6 % | 98,9 % |
| Bulbasaur | 1 | **95,0 %** | 98,9 % |
| Charmander | 0 | 97,9 % | 96,5 % |
| Charmander | 1 | 97,9 % | 98,3 % |
| Squirtle | 0 | 98,0 % | 100 % |
| Squirtle | 2 | 100 % | 100 % |

(«Brock a la 1.ª» es entre quienes llegan a Brock; llegan el 97 / 97 / 85 % sin evolución y el 99,7 / 100 / 91 % con ella.)

- **Cuántas Pociones hacen falta para llegar al 75 %: ninguna.** Con 5 Balls Brock ya está en 77 / 98 / 98 % sin evolución y en 99 / 97 / 100 % con ella.
- **1 Poción basta** para llevar al peor caso (Bulbasaur sin evolución) a 95 %; la 2.ª y la 3.ª no cambian nada. Con la evolución, ninguna Poción suma más de 2 puntos.
- **¿Queda trivial con 1.000 de dinero inicial y la Poción a 300?** Brock ya lo estaba antes de Pociones (≥ 97 % con evolución, 5 Balls); las Pociones no añaden casi nada. Lo que sí limita es el dinero: antes de Brock hay unos 1.660 y 5 Balls cuestan 1.000, así que solo caben **2 Pociones**; todo el dinero inicial en Pociones (3) deja **0 Balls y Brock 0 %**. Las Pociones se compran en Plateada, después de Pikachu y del Entrenador Joven, así que **no ayudan en los muros reales del tramo** (Pikachu con Squirtle 65 %; con evolución, 68 %).
- **Las Balls pesan más que las Pociones.** Cambiar 1 Ball por 1 Poción empeora el tramo: con 4 Balls + 2 Pociones, Bulbasaur sin evolución sube a 89 % en Brock (71 % sin Pociones) pero llegar y ganar se queda en 80 %; con 3 Balls + 3 Pociones, a 73 % en Brock y 53 % en llegar y ganar; con 2 Balls, 0 % (casi nadie llega).

### 4.3 Palancas de la Poción (5 Balls, hasta 3 Pociones)

Brock a la 1.ª, Bulbasaur sin evolución (el caso sensible) con 0 / 1 / 2 / 3 Pociones:

| Palanca | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| Cura 10 PS | 76,3 | 76,3 | 94,9 | 94,9 |
| **Cura 20 PS (D-20)** | 76,6 | 95,0 | 95,0 | 95,0 |
| Cura 30 PS | 76,3 | 94,9 | 94,9 | 94,9 |
| Precio 500 | 76,3 | 94,9 | 94,9 | 94,9 |
| Precio 700 | 76,3 | 76,3 | 76,3 | 76,3 (no se compra ninguna) |
| Límite 1 por combate | 76,3 | 94,9 | 94,9 | 94,9 |

- Curar 10 en lugar de 20 retrasa el efecto a 2 Pociones; curar 30 solo mejora a Squirtle (98 → 100 %).
- **Precio 500 y límite por combate no cambian Brock**: con 5 Balls ya solo se compra una Poción o dos, y se usa una por partida. Solo a **700** la Poción deja de comprarse.
- **No propongo precio ni límite**: Brock no queda trivial por las Pociones, y el reto del primer tramo lo fijan Pikachu y las Balls. Dirección puede repetir la pregunta en los gimnasios 2 y siguientes, donde sí habrá más dinero para Pociones.

## 5. Dinero: piedras junto a Pokéballs y Pociones

Con la ruta de 180 XP, `xpEvo` 80, medallas 2/3/4 y política barata. Una Poción cuesta 300; en el tramo 1 se gasta de 1 a 2 por partida (Brock, medido en 4.2):

| Pociones por tramo | Ex en la Liga | Piedras compradas | Dinero final |
|---|---|---|---|
| 0 | 16 | 8 | 609 |
| 2 (600) | 13 | 5 | 1.809 |
| 4 (1.200) | 11 | 3 | 1.009 |
| 6 (1.800) | 9 | 1 | 209 |

Capturar las 16 especies con Pokéball cuesta unas **25 Pokéballs (5.071 de dinero)** de media, o sea, unos 630 por tramo. Dinero total: 20.680 más 1.000 de salida. D-21 suponía 1.000 a 1.500 por tramo entre Pokéballs y Pociones: con ~630 en Pokéballs quedan de 370 a 870 para Pociones, es decir, de 1 a 3 por tramo, y el equipo llega a **13 a 16 ex** (ruta de 180 XP) o **10** (ruta de ~100: con 100 XP lo que limita es la XP y las Pociones no cuestan ex hasta 4 por tramo). Más allá de 4 Pociones por tramo, las piedras compradas se quedan en 3 o menos y el objetivo de 12 ya depende del dinero.

## 6. Por inicial y qué ex salen

Los tres iniciales dan el mismo resultado (10 ex con ~100 XP por tramo y 16 con 180). Con ~100 XP por tramo, `xpEvo` 80 y política barata, se quedan **sin ex** el inicial (le faltan 150 XP), Pidgey (160), Diglett, Machop, Cubone y Slowpoke (80 cada uno): el equipo «bonito» (los iniciales y los de tres fases) es el que cuesta más XP y queda atrás.

## 7. Palanca: XP propia en los rivales de los tramos 5 a 8

Con la ruta de ~100 XP por tramo, XP extra por tramo (solo en los tramos 5 a 8) hasta llegar a 12 ex:

| `xpEvo` | Política | Extra por tramo (5 a 8) | Total |
|---|---|---|---|
| 80 | barata | 30 | 120 |
| 80 | por orden | 85 | 340 |
| 110 | barata | 120 | 480 |
| 110 | por orden | 175 | 700 |

## Palancas, de menos a más coste para Ayme

No hace falta ninguna si los tramos 2 a 8 se parecen al 1. Si salen unos 100 XP por tramo:

1. **Repetir salvajes.** Sin coste de datos: con `xpEvo` 80 bastan de 8 a 36 combates en toda la campaña.
2. **`xpEvolucion` de las fases siguientes en 80 en lugar de 110.** Solo datos, al crear cada carta. Es la palanca que más pesa (de 7 a 10 ex con 100 XP por tramo). Con 110 y 100 XP por tramo, repetir salvajes pasa a ser de 24 a 72 combates y no basta con confiar en ello.
3. **XP propia en los rivales de los tramos 5 a 8** (campo `xp` de cada jefe o clase): de 30 a 175 por tramo según `xpEvo` y política. Es la más cara porque toca datos de varios rivales.

**Recomendación de Calidad:** fijar `xpEvolucion` en **80** para las fases siguientes (decisión de datos) y **volver a medir con la XP real** cuando existan los tramos 2 y 3. Con los supuestos de hoy, 80 deja 12 ex a un coste razonable en cualquiera de los dos ritmos; con 110 solo se cumple si los tramos dan unos 180 XP.

## Qué no cubre este informe

- No mide si un equipo con tantos ex hace fácil la Liga (objetivo del 25 %, D-20 §10.7): es otro encargo, y D-21 §2.5 lo señala.
- La Poción en el simulador es una política (usar bajo el 50 % de PS), no la IA real: Programación la hará en la tarea 20 (#458). Hay que repetir Brock cuando exista, y también los gimnasios siguientes, que aún no tienen datos.
- No hay datos de los tramos 2 a 8: la XP por tramo, los Pokémon de cada zona y las medallas mínimas reales de cada evolución cambiarán las cifras. Las zonas de los Pokémon siguen por contrastar (#384).
- Los aliados que llaman los jefes y los salvajes repetibles también dan XP y no entran en la ruta principal.
- No he medido el tiempo real de jugar 8 tramos.

## Reproducir

```
cd sim
dart run bin/sim_campana_ex.dart --csv=../balance/informes/campana_xp_ex_2026-11-24.csv
dart run bin/sim_campana_partida.dart --modo=pociones --partidas=1500 --ruta1=si --retroceder=si --balls=5 --pociones=3 [--evolucion-inicial=si] [--ps-pocion=N] [--precio-pocion=N] [--limite-pocion=N]
```
Datos crudos de Pociones en `campana_pociones_2026-11-24/` (`sinevo_*` y `conevo_*`).
