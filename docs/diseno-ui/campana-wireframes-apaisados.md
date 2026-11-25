# Modo campaña: wireframes apaisados (PC y móvil horizontal)

Propuesta de Diseño (2026-11-25, #415), **por confirmar**. Sustituye a la disposición vertical (390×844) de los wireframes D, I, J y M de D-20 §10.7. La estructura de cada pantalla **no cambia**; solo se reparte en horizontal. Decisión de plataforma en D-20 §10.7 (2026-11-25).

## Reglas comunes

- **Lienzo 16:9** (1920×1088 en las escenas). En un móvil más ancho (19,5:9) sobran franjas laterales: el fondo se alarga y **todo lo pulsable queda dentro de una «zona segura» 16:9 centrada**, más el margen de la muesca.
- **Barra superior fija** (dinero, Pokéballs, Pociones, medallas, XP de reserva): una fila de 8 % de alto, igual en todas las pantallas.
- **Tamaño mínimo de lo pulsable: 48 × 48 px lógicos** en el móvil (en 667×375 equivale a 7 % del alto). Las zonas de escena ya son relativas 0–1.
- **Sin dependencia del ratón:** todo se hace con un toque o un clic; el ratón solo añade el resalte al pasar por encima.
- El texto no baja de 14 px lógicos en el móvil; en PC escala con la ventana.

## Mapa (propuesta D)

```
+--------------------------------------------------------------+
| $ 1.000   Ball 3   Poción 2   Medallas ●○○○○○○○   XP 70      |
+--------------------------------------------------------------+
|                                                              |
|   ESCENA 16:9 (hierba alta = combate salvaje,                |
|   bordes = nodo siguiente / anterior, edificios = centro,    |
|   gimnasio, conversación)                                    |
|                                                              |
|                                           [Equipo] [Registro]|
+--------------------------------------------------------------+
```

La escena ocupa todo; los botones **Equipo** y **Registro** flotan abajo a la derecha.

## Combate (propuesta I)

```
+--------------------------------------------------------------+
| barra superior                                               |
+----------------------+---------------------------------------+
| TU BANCA (5)         |  BANCA RIVAL (5)                      |
|  [ ][ ][ ][ ][ ]     |   [ ][ ][ ][ ][ ]                     |
+----------------------+---------------------------------------+
| TU ACTIVO            |  ACTIVO RIVAL                         |
|  nombre PS ▓▓▓░      |   nombre PS ▓▓░░                      |
|  energía ●●○         |   energía ●○○                         |
+----------------------+---------------------------------------+
| Hoja de acciones (al tocar tu activo): Ataque 1 · Ataque 2 · |
| Cargar · Usar Poción (no gasta turno)                        |
+--------------------------------------------------------------+
```

Tu lado a la izquierda y el rival a la derecha (en vertical estaban arriba y abajo). La hoja de acciones sale **abajo a todo lo ancho** y no tapa a los dos activos.

## Equipo (propuesta J)

```
+--------------------------------------------------------------+
| XP de reserva · Pociones                                     |
+--------------+--------------+--------------+-----------------+
| carta 1      | carta 2      | carta 3      |  Hoja al tocar: |
+--------------+--------------+--------------+  Usar Poción    |
| carta 4      | carta 5      | carta 6      |  Evolucionar    |
+--------------+--------------+--------------+  Hacerse ex     |
```

Rejilla de **3 × 2** (en vertical era 2 × 3) y la hoja de acciones **a la derecha**.

## Centro Pokémon (propuesta M) y PC

Escena interactiva como el mapa: mostrador (curar), estantería (tienda), PC (pantalla aparte) y puerta (volver). El **PC** usa una lista a la izquierda (todas las cartas) y el detalle de la carta elegida a la derecha, con **Pasar al equipo** y **Hacerse ex**.

## Móvil: ¿obligar a girar o adaptar?

| Opción | Qué es | Coste | Riesgo |
|---|---|---|---|
| **A. Obligar a girar** (recomendada) | La campaña **solo** se juega en horizontal. En vertical sale «Gira el móvil» y se bloquea la orientación al entrar. El resto de la app sigue en vertical. | Bajo: un solo diseño y un solo juego de escenas (16:9). | Unos pocos usuarios con el giro bloqueado en el sistema. |
| B. Adaptar | Un segundo diseño vertical y **escenas verticales (390×844)** además de las 16:9. | Alto: hay que rehacer las 9 escenas y las zonas, y mantener dos diseños. | Doble arte y doble prueba. |
| C. Mixto | En vertical se muestra la escena 16:9 reducida arriba y los paneles abajo. | Medio: sin arte nuevo, pero la escena es pequeña y las zonas pulsables también. | Zonas pulsables pequeñas. |

**Recomiendo A.** Es la que no duplica el arte. Se pide a Programación una pantalla de aviso y fijar la orientación horizontal al entrar en la campaña. Si Ayme prefiere B o C, cambian el coste y el calendario de Arte.
