# Modo campaña: mejoras de interfaz (escenas, feedback y combate)

**Propuesta de Diseño, 2026-11-28 (#588, prioritaria).** Solo propuesta: no cambia reglas ni D-20 §10. Lo que necesita elección de Ayme lleva **🔶 Decisión de Ayme** y una opción recomendada. Entradas: playtest del 25-11 (#385, #386), `pantalla_combate.dart` (853 líneas), wireframes apaisados (#470, `campana-wireframes-apaisados.md`), D-20 §10.7, el bug del combate a 1280×720 (#592) y las escenas de #415. La campaña es **solo horizontal** (§10.7).

## Lista ordenada por impacto

Impacto = cuántas veces por partida se ve × cuánto confunde si falta. Dirección convierte cada fila en una issue de su sector. «Tamaño»: S = un día o menos, M = unos días, L = más.

| # | Mejora | Sector | Depende de | Tamaño |
|---|---|---|---|---|
| 1 | **Combate apaisado que cabe en 1280×720**, con los avisos de relevo y de victoria siempre visibles (#592; disposición abajo) 🔶 D1 | Programación | Nada | L |
| 2 | **Daño y curación al instante**: número flotante sobre el activo y barra de vida que baja | Programación (Audio: sonido de golpe) | 1 | M |
| 3 | **Turno del rival legible**: pausa corta y una frase por acción | Programación 🔶 D4 | 1 | S |
| 4 | **Botón apagado con su motivo, siempre** (combate, mapa, tienda, equipo) | Programación (Diseño: tabla de motivos) | Nada | S |
| 5 | **Estados alterados con icono y regla** (Dormido, Apresado…) y aviso cuando cambian | Programación y Arte (iconos) | 1 | M |
| 6 | **Rótulos de puertas legibles y «por qué está bloqueado»** | Programación | Nada | S |
| 7 | **Escenas que faltan** (tramo 1 y tramo 2) e interior del centro | Arte | #415 | L |
| 8 | **Resultado del combate**: XP y dinero ganados, y derrota con el sitio al que vuelves | Programación (Arte: iconos ya hechos) | 1 | M |
| 9 | **Captura con la moneda**: la Ball cae cara o cruz, y «se ha escapado» | Programación (Arte: moneda; Audio) | Nada | M |
| 10 | **Evolución**: pantalla corta con los PS antes y después 🔶 D3 | Programación y Arte | #571, #570 | M |
| 11 | **Sonidos del combate y del mapa** (lista P0 de `campana-sonido.md` §5) | Audio | 2, 8, 9 | M |

Orden de arranque que recomiendo: **1 con 4 y 6 a la vez** (arreglan el bug y los dos fallos que Ayme vio jugando), luego 2 y 3 (son la mayor parte de la sensación de «juego»), después el resto.

## 1. Escenas

Lo que falta para que cada nodo se vea terminado:

- **Escenas por pintar.** Tramo 1 (#415): pila de Arte sin fusionar (#539 a #550); entregadas Pueblo Paleta y Ruta 1. Tramo 2: Ruta 3, Ruta 4, Ciudad Celeste, gimnasio de Celeste, Ruta 24 y Monte Moon (#561 a #566, sin fusionar). Hasta que lleguen, la app pinta el marcador. Falta el **interior del Centro Pokémon**.
- **Rótulos de las puertas** (fila 6). Hoy el nombre va en una línea dentro de una zona del 10 % del ancho y se encoge, con el icono, hasta ser ilegible. Regla de diseño: el nombre **parte en dos líneas**, **nunca baja de 14 px lógicos** y el icono **no se encoge** con él (el arreglo técnico ya lo propuso Programación en #385).
- **Por qué está bloqueado** (fila 6). Al tocar una zona apagada sale **una línea de motivo** en un cartel inferior de la escena (tinta sobre crema, unos 2 s). Ejemplos: «Necesitas la Medalla Roca», «Primero elige a tu inicial», «Termina la captura». Es el mismo mecanismo que la fila 4: **nada apagado sin motivo**.
- **Centro, tienda y PC.** La escena del centro es la del mapa (mostrador, estantería, PC). La **tienda** ya es una hoja; le falta el icono de cada objeto. El **PC** sigue sin wireframe propio: pendiente de Diseño y de Arte.

## 2. Feedback

Lo que el jugador no sabe hoy que ha pasado. Todo cabe en **un lenguaje común**: número o icono sobre lo afectado, una línea de texto en la banda de jugada y, si hace falta, un sonido.

| Qué ha pasado | Cómo se ve | Sonido (Audio) | Fila |
|---|---|---|---|
| Daño | Número rojo flotante (−30) sobre el activo, la barra baja en unos 0,4 s y el activo parpadea una vez | Golpe | 2 |
| Curación | Número verde (+20) y la barra sube | Cura | 2 |
| Estado nuevo | Icono en la chapa y una línea («Staryu está dormido») | Aviso de estado | 5 |
| Estado que termina o se comprueba | Una línea por moneda («Cruz: sigue dormido», «Cara: se despierta») | Moneda | 5 |
| Fin de combate | Panel con «+20 XP · +300 ₽» y, tras una derrota, «Vuelves al Centro Pokémon de Ciudad Verde» | Victoria o derrota | 8 |
| Captura | La Ball cae y la moneda gira: «¡X capturado!» o «¡Se ha escapado!» | Captura | 9 |
| Evolución | Pantalla de unos 2 s (omisible con un toque): carta nueva y PS antes y después | Evolución | 10 |
| Botón apagado | Toque sobre él y sale el **motivo** en una línea | Error suave | 4 |

Estados que existen hoy en el motor y necesitan **icono y una línea de regla** (Arte los dibuja, Programación los pone): Envenenado, Drenado, Paralizado, Dormido, Apresado, Confundido, «puede fallar» (Pantalla de Humo), «pega −N», «recibe +N», «recibe −N» y «racha ×N». Al **mantener pulsada** una chapa sale su regla («Dormido: no puede atacar ni retirarse; una moneda por turno»).

Animaciones: **sencillas y cortas** (menos de 0,5 s cada una), y el juego **no espera** a que terminen para aceptar el siguiente toque, para no frenar el combate ni los tests. Audio: en `campana-sonido.md` ya están el tema de combate, victoria, derrota, monedas, captura, ataque, daño, debilitado y error; esta tabla solo dice **en qué momento** suena cada uno. **Pregunta para Audio**, no decidida aquí: qué suena en el estado alterado y en la evolución, que no están en la lista P0.

## 3. Pantalla de combate

### Qué ve el jugador hoy

El tapete es **una columna de 640 px como máximo dentro de un scroll** (`ConstrainedBox(maxWidth: 640)` y `SingleChildScrollView`). En 1280×720 la banca propia, el aviso «Tu Pokémon ha caído» y «¡Victoria! Continuar» quedan **debajo del borde** (#592). La hoja de acciones se abre al tocar el activo. La última jugada es **una línea** y el registro entero, otra hoja. Los estados son chapas de texto.

### Propuesta de disposición a 1280×720 (#592)

Es la estructura del wireframe I (tu lado a la izquierda, el rival a la derecha, banca encima de cada activo), con medidas. **Sin scroll**: todo cabe y todo lo que hay que tocar está siempre en pantalla.

```
 1280 × 720 (16:9; en otras proporciones, franjas a los lados)
+------------------------------------------------------------------------------+
| dinero · Balls · Pociones · medallas · XP                              58 px |
+---------------------------------------+--+-----------------------------------+
| TU BANCA   [ ][ ][ ][ ][ ]    100 px  |  |  BANCA RIVAL  [ ][ ][ ][ ][ ]     |
+---------------------------------------+  +-----------------------------------+
| [carta  ]  Wartortle        280 px    |VS|  Staryu         [carta  ]         |
| [190×266]  PS ▓▓▓▓░ 80/110            |  |  PS ▓▓▓░░ 40/60  [190×266]        |
| [       ]  energía ●●○○  [Dormido]    |  |  energía ●○○     [Confundido]     |
+---------------------------------------+--+-----------------------------------+
| Última jugada: «Staryu usa Pistola Agua: −30»  ·  (toca: registro)     56 px |
+------------------------------------------------------------------------------+
| [Ataque 1 · coste · daño] [Ataque 2] [Cargar +1] [Poción] [Cuerda] [Cambiar]  |
|                                                                       130 px |
+------------------------------------------------------------------------------+
```

- **Alturas:** 58 + 100 + 280 + 56 + 130 = **624 px**, y quedan unos 96 px para los márgenes de 8 a 12 px. Sin tapar nada, sin scroll.
- **Banca y activo:** miniaturas de 60×84 con barra de vida; la carta del activo mide 190×266 (la imagen es 480×670). Todo se calcula con **proporciones**, no con píxeles fijos: el combate **escala** con la ventana como las escenas.
- **Banda «última jugada»** de 2 líneas, a todo el ancho; tocarla abre el registro completo en una hoja lateral.
- **Los avisos nunca quedan fuera:** «Tu Pokémon ha caído. Toca a uno de tu banca» ocupa la banda de jugada (dorado) y **parpadea la banca propia**; «¡Victoria!» y «Derrota» **sustituyen a la barra de acciones** y llevan el botón **Continuar** grande y el resultado (fila 8).
- **Turno del rival:** la barra de acciones se apaga y dice «Turno de Staryu…»; el activo rival se resalta mientras actúa (fila 3).
- **Móvil horizontal (667×375 y 844×390):** el mismo diseño escalado. Las miniaturas de banca miden unos 31×44 px y **su zona pulsable se ensancha a 48×48** (regla común de los wireframes); el texto no baja de 14 px lógicos. Programación lo prueba a **1280×720, 844×390 y 667×375**, con la prueba de #592 (la banca y el aviso se tocan sin desplazarse).

### 🔶 D1. Cómo se eligen las acciones (Decisión de Ayme)

| Opción | Qué es | Coste | Riesgo |
|---|---|---|---|
| **A (recomendada)** | **Barra fija abajo** con las acciones siempre visibles (como en el dibujo); no hace falta tocar el activo | Cambia el wireframe I (la hoja deja de salir al tocar el activo) | Seis botones en una fila en móvil: caben a 667×375 con 48 px de alto mínimo |
| B | **Hoja al tocar tu activo**, como en #470, pero como panel inferior de 130 px que no tapa a los activos | Cambio mínimo | Un toque más por turno, y el tutorial depende de ese toque |

### Otras decisiones de este bloque

- 🔶 **D2. Registro.** **A (recomendada):** dos líneas visibles y el registro entero en una hoja. B: panel lateral permanente (no cabe en 1280×720 sin encoger los activos).
- 🔶 **D3. Evolución.** **A (recomendada):** pantalla propia de unos 2 s, omisible con un toque, con la carta nueva y los PS antes y después (la regla del 28-11: 40/60 pasa a 80/110). B: solo una línea en la hoja del equipo.
- 🔶 **D4. Ritmo del turno rival.** **A (recomendada):** pausa de unos 0,6 s por acción del rival, para que se lea qué hace. B: instantáneo y todo en el registro. La A suma unos 4 s a un combate de 12 turnos (el rival actúa unas 6 veces); Calidad lo puede medir en la 2.ª partida de Ayme (#385).

### Qué se mantiene

PS y barras (verde, naranja y roja), energía en fichas de 0 a 10, estados como chapas, Poción que no gasta turno, Cuerda Huida, tutorial de la Ruta 1 y confirmación de cambio: **no cambian**. Los objetos (Poción y Cuerda Huida) pasan a la barra de acciones y la hoja de «¿A quién curas?» sigue igual.

## Qué no cubre este documento

La pantalla de **equipo** y el **centro** ya están hechos y no se rediseñan aquí; solo reciben la tabla de motivos (fila 4) y la pantalla de evolución (fila 10). El PC necesita un wireframe propio (apartado 1). El **tutorial** sigue como está.
