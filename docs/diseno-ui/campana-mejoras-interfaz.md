# Modo campaña: mejoras de interfaz (escenas, feedback y combate)

**Propuesta de Diseño, 2026-11-28 (#588, prioritaria).** Solo propuesta, salvo D1 a D4, que Ayme decidió y están registradas en D-20 §10.2. D1 a D4 **decididos por Ayme el 2026-11-28**; lo que sigue abierto lleva **🔶 Decisión de Ayme** y una opción recomendada. Entradas: playtest del 25-11 (#385, #386), `pantalla_combate.dart` (853 líneas), wireframes apaisados (#470, `campana-wireframes-apaisados.md`), D-20 §10.7, el bug del combate a 1280×720 (#592) y las escenas de #415. La campaña es **solo horizontal** (§10.7).

## Lista ordenada por impacto

Impacto = cuántas veces por partida se ve × cuánto confunde si falta. Dirección convierte cada fila en una issue de su sector. «Tamaño»: S = un día o menos, M = unos días, L = más.

| # | Mejora | Sector | Depende de | Tamaño |
|---|---|---|---|---|
| 1 | **Combate apaisado que cabe en 1280×720**, con los avisos de relevo y de victoria siempre visibles (#592; disposición abajo; D1 decidido) | Programación | Nada | L |
| 2 | **Daño y curación al instante**: número flotante sobre el activo y barra de vida que baja | Programación (Audio: sonido de golpe) | 1 | M |
| 3 | **Turno del rival legible**: pausa corta y una frase por acción | Programación (D4 decidido) | 1 | S |
| 4 | **Botón apagado con su motivo, siempre** (combate, mapa, tienda, equipo) | Programación (Diseño: tabla de motivos) | Nada | S |
| 5 | **Estados alterados con icono y regla** (Dormido, Apresado…) y aviso cuando cambian | Programación y Arte (iconos) | 1 | M |
| 6 | **Rótulos de puertas legibles y «por qué está bloqueado»** | Programación | Nada | S |
| 7 | **Escenas que faltan** (tramo 1 y tramo 2) e interior del centro | Arte | #415 | L |
| 8 | **Resultado del combate**: XP y dinero ganados, y derrota con el sitio al que vuelves | Programación (Arte: iconos ya hechos) | 1 | M |
| 9 | **Captura con la moneda**: la Ball cae cara o cruz, y «se ha escapado» | Programación (Arte: moneda; Audio) | Nada | M |
| 10 | **Evolución**: pantalla corta con los PS antes y después (D3 decidido) | Programación y Arte | #571, #570 | M |
| 12 | **Mochila con pestañas** (Objetos de combate, Pokéballs y Piedras; en combate abre en la primera): icono, pantalla y pestañas | Programación y Arte (icono) | 1 | M |
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

### Disposición a 1280×720 (#592) con lo decidido por Ayme el 2026-11-28

Es la estructura del wireframe I (tu lado a la izquierda, el rival a la derecha, banca encima de cada activo), con medidas. **Sin scroll**: todo cabe. **Ya no hay barra de acciones fija**: las acciones salen al tocar la carta del Activo (D1), y ese espacio se queda para que las cartas se vean más grandes.

```
 1280 × 720 (16:9; en otras proporciones, franjas a los lados)
+------------------------------------------------------------------------------+
| dinero · Balls · Pociones · medallas · XP                              58 px |
+---------------------------------------+--+-----------------------------------+
| TU BANCA   [ ][ ][ ][ ][ ]    110 px  |  |  BANCA RIVAL  [ ][ ][ ][ ][ ]     |
+---------------------------------------+  +-----------------------------------+
| [carta  ]  Wartortle        330 px    |VS|  Staryu         [carta  ]         |
| [230×321]  PS ▓▓▓▓░ 80/110            |  |  PS ▓▓▓░░ 40/60  [230×321]        |
| [       ]  energía ●●○○  [Dormido]    |  |  energía ●○○     [Confundido]     |
+---------------------------------------+--+-----------------------------------+
| Última jugada: «Staryu usa Pistola Agua: −30»  ·  (toca: registro)     64 px |
+------------------------------------------------------------------------------+
```

- **Alturas:** 58 + 110 + 330 + 64 = **562 px** de 720; quedan unos 150 px para márgenes y para el desplegable. La carta del activo sube de 190×266 a **230×321** (la imagen es 480×670). Todo se calcula con **proporciones**: el combate **escala** con la ventana, como las escenas.
- **Tocar la carta del Activo** (decidido por Ayme): la carta **se agranda** (o la cámara se acerca) hasta ocupar **una parte generosa de la pantalla**, como en el TCG Live o el TCG Pocket, para que **se lea**: unos 372×520 en 1280×720 (alto del 72 %), con el fondo atenuado. Junto a ella sale un **desplegable con los ataques y, debajo de ellos, CAMBIAR**. Tocar fuera la devuelve a su sitio.
- **Cambiar** (decidido por Ayme): CAMBIAR **ilumina** en la Banca los Pokémon que pueden entrar; se toca uno y **pasa al puesto Activo con una animación** (el activo y el de la Banca intercambian sitio). Cuando el Activo cae, tocar una carta de la Banca elige el relevo igual.
- **Tocar una carta de la Banca** (decidido por Ayme): se agranda igual, **solo la carta**, para leerla; sus ataques salen **impresos en la carta**, sin lista ni botones aparte, y no se pueden usar desde ahí. **Sin más desplegables** (Ayme: «no quiero que aparezca mucho más»).
- **Mochila** (decidido por Ayme): un **icono de mochila** abre el inventario con **pestañas**, como en los juegos originales. En combate **se abre por defecto en «Objetos de combate»** (Pociones y Cuerdas Huida, juntas); las otras pestañas son **Pokéballs** y **Piedras** (Trueno, Agua, Fuego, Hoja, Luna y la piedra ex; en combate **no sirven**, son un recordatorio del inventario). Aquí es donde se usan la Poción y la Cuerda Huida; la hoja «¿A quién curas?» y la de «¿Quién sale?» siguen igual.
- **Banda «última jugada»** de 2 líneas, a todo el ancho; tocarla abre el registro completo en una hoja (D2-A).
- **Los avisos nunca quedan fuera:** «Tu Pokémon ha caído. Toca a uno de tu banca» ocupa la banda de jugada (dorado) y **parpadea la banca propia**; «¡Victoria!» y «Derrota» salen como **panel central** con el botón **Continuar** y el resultado (fila 8).
- **Turno del rival:** el activo propio no se puede tocar, la banda dice «Turno de Staryu…» y el activo rival se resalta mientras actúa, con una pausa de unos 0,6 s por acción (D4-A).
- **Móvil horizontal (667×375 y 844×390):** el mismo diseño escalado. Las miniaturas de banca miden unos 31×44 px y **su zona pulsable se ensancha a 48×48** (regla común de los wireframes); el texto no baja de 14 px lógicos. Programación lo prueba a **1280×720, 844×390 y 667×375**, con la prueba de #592 (la banca y el aviso se tocan sin desplazarse).

### Decidido por Ayme el 2026-11-28

- **D1. Acciones del combate:** se tocan en las cartas, como se ha descrito arriba. **No hay barra fija.** Cambia el wireframe I de #470 («hoja de acciones abajo a todo lo ancho»). Los objetos van en la **Mochila**.
- **D2. Registro:** **A**: dos líneas visibles y el registro entero en una hoja.
- **D3. Evolución:** **A**: pantalla de unos 2 s, omisible con un toque, con la carta nueva y los PS antes y después (regla del 28-11: 40/60 pasa a 80/110).
- **D4. Ritmo del turno rival:** **A**: pausa de unos 0,6 s por acción; suma unos 4 s a un combate de 12 turnos (el rival actúa unas 6 veces). Calidad puede medirlo en la 2.ª partida de Ayme (#385).

### Detalles que D1 dejó abiertos: respondidos por Ayme el 2026-11-28

1. **Poción, Cuerda Huida y el resto de objetos:** en la **Mochila** (arriba), no en el desplegable.
2. **Cómo se cambia:** CAMBIAR bajo los ataques, se iluminan las opciones y se toca una (arriba).
3. **Carta agrandada de la Banca:** solo la carta, grande, sin más desplegables.

### 🔶 Lo que añado yo y Ayme confirma

1. **Cargar** (la tercera acción de §10.2) **va en el desplegable del Activo, junto a los ataques**, antes de CAMBIAR. Ayme no la nombró; es lo más corto. Alternativa: dentro de la Mochila (no la recomiendo: se usa casi cada turno).
2. **Sin ventana de confirmación al cambiar** (hoy sale «Cambiar gasta el turno y N de energía»): el coste se escribe **en el botón** («CAMBIAR · −1 energía · gasta el turno») y solo se iluminan los que se pueden pagar. Si Ayme prefiere la confirmación de hoy, se mantiene.
3. **Dónde está el icono de la Mochila:** **A (recomendada):** en la **barra superior**, fija en el combate y en el mapa (en el mapa es el mismo inventario, también como recordatorio). B: solo en el combate, junto al Activo propio.

### Qué se mantiene

PS y barras (verde, naranja y roja), energía en fichas de 0 a 10, estados como chapas, Poción que no gasta turno, Cuerda Huida (ahora en la Mochila), tutorial de la Ruta 1 (el brillo dorado en el activo pasa a ser la carta que hay que tocar) y confirmación de cambio: **no cambian**.

## Qué no cubre este documento

La pantalla de **equipo** y el **centro** ya están hechos y no se rediseñan aquí; solo reciben la tabla de motivos (fila 4) y la pantalla de evolución (fila 10). El PC necesita un wireframe propio (apartado 1). El **tutorial** sigue como está.
