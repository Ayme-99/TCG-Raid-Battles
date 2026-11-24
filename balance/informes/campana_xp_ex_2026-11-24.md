# Modo campaña: ritmo de XP y cartas ex al llegar a la Liga (#451)

Fecha: 2026-11-24 · Herramienta: `sim/bin/sim_campana_ex.dart` · Datos: `campana_xp_ex_2026-11-24.csv` y `.txt` (salida completa)

Objetivo fijado por Ayme el 2026-11-24: **12 ex o más** entre equipo y PC al llegar a la Liga (D-20 §2.1, D-21 §2.5).

## Resumen

1. **Que se llegue a 12 ex depende de un dato que hoy no existe: cuánta XP da cada tramo.** Solo existe el tramo 1. Medido en el catálogo, su ruta principal da **180 XP** (sin los desvíos opcionales). Si los otros siete tramos se parecen, la ruta suma unos **1.440 XP** y salen **16 ex** (el máximo con los 16 Pokémon posibles), sobrando margen. Con los **~100 XP por tramo** (700–900 en total) de la estimación de Diseño salen **10 ex** en el mejor caso: falta el objetivo.
2. **La estimación de 700–900 XP parece contar solo hasta antes del líder.** Antes de Brock hay 130 XP (Ruta 1 y 2: 20; dos Cazabichos: 60; Pikachu: 30; Entrenador Joven: 20) y Brock suma 50 más (Geodude 20 y Onix 30). Ocho tramos de ~110 dan 880. Si cada líder aporta algo parecido a Brock, la cuenta correcta está más cerca de 1.200 a 1.400 que de 800. Es una hipótesis: hay que confirmarla con el diseño real de los tramos 2 a 8 (tarea 11).
3. **Fijar `xpEvolucion` en 80 en vez de 110 es la palanca que más pesa.** Con ~100 XP por tramo, pasa de 7 a 10 ex (política «barata») y de 4 a 7 (política «por orden»). Con 180 XP por tramo, de 13 a 16 y de 11 a 16.
4. **Repetir salvajes cubre el hueco, pero cuesta más combates con 110.** Con ~100 XP por tramo y `xpEvolucion` 80 hacen falta de **8 a 16 combates** repetidos (política barata, 160 XP extra) o de **18 a 36** (política por orden, 360 XP). Con 110 hacen falta de **24 a 48** o de **36 a 72**. D-20 estimaba 25 a 40.
5. **Las medallas mínimas de los ex importan menos que la XP, salvo por el pico de la 4.ª medalla.** Con la opción A (4/4/5) los primeros ex llegan con la 4.ª medalla; con B y C ya se hacen ex con la 3.ª. Solo C pone ex de Fase 2 (270 a 340 PS) con la 4.ª medalla.
6. **El dinero no es el límite si se compran pocas Pociones.** Las piedras y las Pokéballs caben con 0 Pociones; con 6 Pociones por tramo el equipo se queda en 9 ex.

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

Reglas de D-20 que sí aplica: Caterpie y Weedle cuestan 50 XP y el inicial 70 (§10.6); las demás evoluciones, `xpEvo` (80 u 110); intercambio gratis (Golem y Machamp); piedra ex de premio por medalla y a 2.000 de dinero; Pikachu y Onix son Básico ex (0 XP); medallas mínimas de la tabla de §10.11; el ex pide medallas de su tipo y no menos que su última fase normal.

Dos políticas del jugador: **barata** = completa primero las líneas que menos XP cuestan (cota superior de ex); **por orden** = evoluciona en el orden en que captura, sin saltarse ninguna (se parece más a jugar sin plan).

## 1. XP de la ruta principal, sin repetir salvajes

| Escenario | Por tramo | Total |
|---|---|---|
| Estimación de Diseño | ~100 | 800 |
| Como el tramo 1 (medido) | 180 | 1.440 |
| Creciente (rivales más fuertes) | 180 a 360 | 2.160 |

Tramo 1 (catálogo): Ruta 1 10 · Ruta 2 10 · dos Cazabichos de 2 Pokémon, media 15 cada Pokémon (Caterpie y Weedle 10, Metapod y Kakuna 20) = 60 · Pikachu 30 · Entrenador Joven (Diglett y Sandshrew) 20 · Brock (Geodude 20 y Onix 30) 50 = **180**, igual que el «unos 180 tras Brock» de D-20 §10.6. Los desvíos opcionales (Ruta 22 y Ruta 2 norte) suman 10 cada uno y no se cuentan.

## 2. Ex al llegar a la Liga (opción A 4/4/5, inicial Bulbasaur)

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

## 4. Medallas mínimas de los ex

Ex hechos tras cada medalla (1 a 8), con la política barata y `xpEvo` 80:

| Opción | Ruta de 180 XP | De ellos Fase 2 | Ruta de ~100 XP | De ellos Fase 2 |
|---|---|---|---|---|
| A 4/4/5 | 0 0 0 6 8 11 13 16 | 0 0 0 0 2 3 4 6 | 0 0 0 3 7 8 9 10 | 0 0 0 0 2 2 2 3 |
| B 3/4/5 | 0 0 2 6 8 11 13 16 | 0 0 0 0 2 3 4 6 | 0 0 2 3 7 8 9 10 | 0 0 0 0 2 2 2 3 |
| C 3/3/4 | 0 0 4 6 8 11 13 16 | 0 0 0 2 2 3 4 6 | 0 0 2 5 7 8 9 10 | 0 0 0 2 2 2 2 3 |

- La opción no cambia el total en la Liga (16 y 10 en los tres casos): solo **cuándo** aparece cada ex.
- **Los ex de 330 PS (Fase 2) no llegan antes de la 4.ª medalla con A ni con B, y solo C pone 2 en la 4.ª.** A es la que mejor protege el reto entre las medallas 3 y 4; con A la 4.ª medalla es un salto grande (de 0 a 6 ex con la ruta de 180 XP).
- Con B y C aparecen 2 a 4 ex ya con la 3.ª medalla, antes que en A.

## 5. Dinero: piedras junto a Pokéballs y Pociones

Con la ruta de 180 XP, `xpEvo` 80, opción A y política barata:

| Pociones por tramo | Ex en la Liga | Piedras compradas | Dinero final |
|---|---|---|---|
| 0 | 16 | 8 | 609 |
| 2 (600) | 13 | 5 | 1.809 |
| 4 (1.200) | 11 | 3 | 1.009 |
| 6 (1.800) | 9 | 1 | 209 |

Capturar las 16 especies con Pokéball cuesta unas **25 Pokéballs (5.071 de dinero)** de media, o sea, unos 630 por tramo. Dinero total: 20.680 más 1.000 de salida. D-21 suponía 1.000 a 1.500 por tramo entre Pokéballs y Pociones: con ~630 en Pokéballs quedan de 370 a 870 para Pociones, es decir, de 1 a 3 por tramo, y el equipo llega a **13 a 16 ex**. Más allá de 4 Pociones por tramo, las piedras compradas se quedan en 3 o menos y el objetivo de 12 ya depende del dinero.

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
- No hay datos de los tramos 2 a 8: la XP por tramo, los Pokémon de cada zona y las medallas mínimas reales de cada evolución cambiarán las cifras. Las zonas de los Pokémon siguen por contrastar (#384).
- Los aliados que llaman los jefes y los salvajes repetibles también dan XP y no entran en la ruta principal.
- No he medido el tiempo real de jugar 8 tramos.

## Reproducir

```
cd sim
dart run bin/sim_campana_ex.dart --csv=../balance/informes/campana_xp_ex_2026-11-24.csv
```

---

## Anexo (2026-11-24, petición de Ayme en #453): medallas D 2/3/4 y Pociones en combate (#435)

Simulador: `sim/bin/sim_campana_partida.dart --modo=pociones` (Pociones en combate: sin gastar turno, sin límite por combate, solo inventario; se usa cuando los PS del activo bajan del 50 %). Datos crudos en `balance/informes/campana_pociones_2026-11-24/`. 800 recorridos por casilla, política B, Ruta 1 con capturas, retroceder al último centro.

### A. Opción de medallas D (Onix y Pikachu ex a 2 medallas; resto 3 y 4)

| Opción | ex disponibles tras cada medalla (1 a 8), ruta 180 XP/tramo | Ídem, ruta ~100 XP/tramo |
|---|---|---|
| A 4/4/5 | 0 0 0 6 8 11 13 16 | 0 0 0 3 7 8 9 10 |
| B 3/4/5 | 0 0 2 6 8 11 13 16 | 0 0 2 3 7 8 9 10 |
| C 3/3/4 | 0 0 4 6 8 11 13 16 | 0 0 2 5 7 8 9 10 |
| **D 2/3/4** | **0 1 4 6 8 11 13 16** | 0 1 2 5 7 8 9 10 |

D adelanta el primer ex a la 2.ª medalla (1 ex) y no cambia el total al llegar a la Liga (16 con 180 XP/tramo; 10 con ~100). El límite sigue siendo la XP, no la opción de medallas.

### B. Brock con Pociones (Poción 20 PS, 300 de dinero)

Primer intento en Brock (5 Balls, 3 Pociones máximo, 800 recorridos):

| Inicial | Sin Poción | 1 Poción | 2 Pociones |
|---|---|---|---|
| Bulbasaur | 76,3 % | **94,7 %** | 94,7 % |
| Charmander | 98,2 % | 98,2 % | 98,6 % |
| Squirtle | 98,1 % | 98,1 % | 100 % |

- Con 5 Balls, Brock ya estaba en 76/98/98 % sin Pociones. **Una sola Poción** sube a Bulbasaur a ~95 %: el reto de Brock deja de estar «cerca del 75 %».
- La 2.ª Poción no aporta (Bulbasaur 94,7 → 94,7 %). Hacen falta **0 Pociones** para quedarse en el 75 % de Bulbasaur y **1** ya lo supera de sobra.
- Las Balls pesan más que las Pociones: con 4 Balls + 2 Pociones Brock da 89/93/95 %, pero la tasa de llegar baja a ~90 % y el reto global cae (Bulbasaur gana Brock ~80 %); con 3 Balls + 3 Pociones, Brock 72/72 % (Bulbasaur/Charmander) pero solo llega ~73 %; con 2 Balls, 0 % (no se llega a Brock).
- Con 1.000 iniciales y todo en Pociones (3), no quedan Balls y el recorrido no pasa de Pikachu: **no es trivial, es inviable**. El límite real no es la Poción a 300, es el presupuesto: antes de Brock hay ~1.660, y 5 Balls (1.000) dejan solo para 2 Pociones.
- Las Pociones se compran en Plateada, después de Pikachu y del Entrenador Joven, así que **no ayudan en esos dos combates**, que son los muros reales (Pikachu con Squirtle 65 %).

### C. Palancas (5 Balls, hasta 3 Pociones)

| Palanca | Efecto en Brock (Bulbasaur, 1 Poción) |
|---|---|
| Cura 10 PS | 76,3 % (sin efecto; la Poción no basta) |
| Cura 20 PS (actual) | 94,7 % |
| Cura 30 PS | 94,7 % (Squirtle 98,1 → 100 %) |
| Precio 300 / 400 / 500 | 1–3 Pociones: igual (la compra cabe, ~1 Poción/partida) |
| Precio 700 | 0 Pociones compradas: la palanca se apaga |
| Límite 1 por combate | igual que sin límite (se usa ~1 por partida) |

### D. Recomendación

La Poción a 300 y 20 PS **no hace trivial el reto** de Brock por dinero (el presupuesto manda), pero una sola Poción ya lo deja en ~95 % para Bulbasaur. Si Dirección quiere mantener a Brock cerca del 75 %:
1. **Precio 500** (mantiene 1 Poción/partida alcanzable, no se puede apilar 3 con 5 Balls), o
2. **Límite de compra: 1 Poción antes de Brock** (el límite por combate no sirve; el efecto está en cuántas se tienen).
Quedan sin medir (no están en el motor): Pociones en la IA real y efectos de evolución (#439).
