# Prompts de Flux para los fondos de escena (modo campaña, primer tramo)

Versión apaisada 16:9 (PC como plataforma principal, decisión de Ayme del 2026-11-24). Sustituye a la versión vertical 390×844.

## Cómo usarlos

1. **Tamaño:** 1920×1088 (16:9). Es el máximo que admite Klein (lado de 256 a 1920).
2. **Sin imagen de guía.** Con la guía vectorial a menos de 512 px, Flux reinterpretaba demasiado. Funciona mejor un prompt solo de texto, **corto en objetos y claro en tamaños**: si no se dice cuánto mide algo, Flux lo hace enorme (árboles, farolas, plazas).
3. **Seed fija** para comparar variantes (`1`, `2`, `3`…) y apuntar la buena. Modelo Klein 9B si hay cuota.
4. **Flujo de las escenas:** se entra **por abajo** y se sale **por arriba** (lo anterior queda abajo, lo siguiente arriba, D-20 §4). Las salidas laterales se piden en el prompt de cada escena.
5. **Márgenes de interfaz:** la barra de recursos tapa el 7 % superior y el equipo tapa el 17 % inferior. Lo importante (arcos, puertas, hierba alta) va **entre el 10 % y el 80 % de la altura**.
6. **Sin personajes ni criaturas** en el fondo: los sprites se pintan encima. Dejar claros «huecos» donde irán.
7. **Un cambio cada vez.** Si hay que retocar, subir la imagen buena como imagen de referencia con una sola frase («Keep everything exactly as it is, except …»). Los prompts largos con muchas correcciones estropean lo que ya estaba bien.
8. **Sin marcas.** Los prompts no nombran videojuegos ni franquicias.
9. Flux no usa prompt negativo: lo que no se quiere se redacta en positivo.
10. **Zonas pulsables:** se calculan **sobre la imagen elegida**, no sobre una guía (Flux mueve las cosas). Un `*.zonas.json` por escena, en píxeles y relativas 0–1.

## Cabecera de estilo (pegar al principio de todos los exteriores)

Es la del prompt que dio la imagen de Pueblo Paleta que se eligió el 2026-11-24. La luz está puesta como salió en esa imagen (sombras hacia abajo a la izquierda) para que todas las escenas coincidan.

```
Top-down three-quarter bird's-eye view of a small cartoon-realistic adventure game map scene, painterly stylized realism with soft cel-shaded lighting, bright saturated storybook colors, thick clean outlines, hand-painted textures on grass, sand and stone. Horizontal widescreen composition. A clean image with no lettering, no UI, no characters, no people, no creatures, no logos. Strictly a ground view from above, no sky, no haze. Morning sun from the upper right, soft short shadows falling to the lower left. Keep the top and bottom edges of the image simple ground, without important objects. Everything is small in scale: houses are small, every tree is small and round, no taller than a house, lamps and signposts are no taller than a door.
```

## 1. Pueblo Paleta (inicio: elegir inicial)

Zonas: laboratorio (puerta pulsable), arco a la Ruta 1 (arriba), casas decorativas. Ya hay imagen elegida (2026-11-24) y sus zonas en `pueblo-paleta-flux.zonas.json`.

```
[cabecera de estilo] A peaceful seaside hamlet with four small houses on a flat green meadow.
Left of center: the largest building, a cream-colored research laboratory about twice as wide as any other house, with a teal tiled roof, a small white observatory dome with a thin antenna on top, two windows and a brown double door with a small canopy and two flower pots.
Far left, lower: a small cottage with an orange tiled roof and a yellow mailbox.
Right, upper: a small house with a blue tiled roof.
Right, lower: a small house with a rose-red tiled roof.
A small, flat, round patch of packed sand at the bottom center, level with the ground, about as wide as one house. One sandy dirt path winds up the center of the image to a wooden arch gateway at the top center-right, placed well below the top edge. A short narrow path leads to the door of each house. No other paths and no paths leaving the image.
A few small round trees, small round bushes and two slim street lamps around the meadow.
Calm, welcoming, morning mood.
```

## 2. Ruta 1 (bifurcación: dos hierbas altas)

Zonas: entrada abajo, **dos manchas de hierba alta separadas** (Pidgey y Rattata), salida arriba hacia Ciudad Verde.

```
[cabecera de estilo] A gentle countryside trail on open rolling meadow. A wide light-brown dirt path enters from the bottom center and forks into a left branch and a right branch around a small grassy island, and the two branches rejoin and continue to the top center, where the path ends at a small wooden gate placed well below the top edge. On the left branch and on the right branch, one clearly separated patch of tall dark-green grass each, about one sixth of the image wide, easy to recognize as tall wild grass. Small round trees at the borders, a few wooden fence posts, scattered small wildflowers, low stone-edged ledges. Lots of empty clear ground around the grass patches. Open and friendly mood.
```

## 3. Ciudad Verde (exterior, con la entrada al centro)

Zonas: edificio del centro Pokémon (puerta pulsable), entrada abajo (Ruta 1), salida a la **Ruta 22** (izquierda) y a la **Ruta 2** (arriba).

```
[cabecera de estilo] A small town with green-roofed houses on a cobblestone square. At the center a clearly larger clinic building with a bright red roof, white walls, a big white cross sign above a wide glass double door with a small awning. Four small houses with green tiled roofs around it, neat hedges, flower planters, a small round fountain, small round trees at the borders. A paved street enters from the bottom center, and leaves on the left edge (a dirt path) and at the top center (a stone-paved path). Fresh, friendly town mood.
```

## 4. Ruta 22 (opcional, un combate)

Zonas: entrada abajo, hierba alta (combate), salida arriba hacia la Ruta 2.

```
[cabecera de estilo] A wide open grassy plain with a shallow clear river running from left to right near the top third and a small arched stone bridge over it. A dirt path enters from the bottom, crosses the bridge and ends at a low stone gateway at the top, well below the top edge. One large patch of tall grass left of the path in the lower half. A few rocky outcrops and small boulders, a few small round trees, wind-blown grass. Lonely, wide-open mood.
```

## 5. Ruta 2 sur (bifurcación: dos hierbas altas)

Zonas: entrada abajo, dos hierbas altas (Weedle y Caterpie), salida arriba hacia el Bosque Verde.

```
[cabecera de estilo] A forest-edge trail that forks in two. A wide dirt path enters from the bottom, splits around a thick bush hedge into a left and a right branch, and rejoins toward the top where small dark trees begin to close in. One clearly separated patch of tall grass on each branch, about one sixth of the image wide. Mossy rocks, ferns, two wooden signposts without writing, fallen leaves, dappled light. Mysterious but still sunny.
```

## 6. Bosque Verde (serpenteante, hierba alta, entrenadores al acecho)

Zonas: camino que serpentea de abajo a arriba, 4 o 5 manchas de hierba alta, **tres claros** para dos Cazabichos y el personaje de aviso (más el jefe), salida arriba.

```
[cabecera de estilo] A dense lush forest seen from above with a single dirt path that snakes in S-curves from the bottom center to the top center. Round dark-green tree canopies, small and tightly packed along the edges, thick undergrowth, mushrooms and mossy logs, patches of dappled sunlight on the ground. Four patches of tall grass along the path, each about one sixth of the image wide. Three small empty clearings beside the path, free of any object, left clean for characters. A brighter gap in the trees at the top where the forest opens. Enclosed, slightly tense adventure mood.
```

## 7. Ruta 2 norte (un salvaje opcional)

Zonas: entrada abajo, una hierba alta, salida arriba hacia Ciudad Plateada.

```
[cabecera de estilo] The northern end of a forest trail opening up to a rocky hillside. A dirt path climbs from the bottom to the top center between a few small trees and shrubs, one single patch of tall grass on the right side near the middle, grey rocky cliffs with small ledges and boulders starting near the top edge. Dry golden grass, scattered pebbles. Open, slightly dry mood.
```

## 8. Gimnasio de Brock (interior; imagen `gimnasio-plateada`)

Zonas: puerta abajo (volver), plaza de combate al centro (Entrenador Joven y Brock).

```
Top-down three-quarter bird's-eye view of a small cartoon-realistic adventure game interior, painterly stylized realism with soft cel-shaded lighting, bright saturated storybook colors, thick clean outlines, hand-painted textures on stone and sand. Horizontal widescreen composition. A clean image with no lettering, no UI, no characters, no people, no creatures, no logos.
The interior of a rocky-themed battle gymnasium: a large oval arena floor of packed sandy earth at the center, surrounded by a low ring of stone blocks, big boulders and stone pillars at the corners, torches on the grey-brown stone walls, a worn rug at the entrance at the bottom center. Warm torchlight. Heavy, solid, tense mood.
```

## 9. Interior del Centro Pokémon (imagen `centro-pokemon`)

Zonas: mostrador (arriba, curar), estantería (izquierda, tienda), ordenador (derecha, PC), puerta abajo (salir).

```
Top-down three-quarter bird's-eye view of a small cartoon-realistic adventure game interior, painterly stylized realism with soft cel-shaded lighting, bright saturated storybook colors, thick clean outlines, hand-painted textures. Horizontal widescreen composition. A clean image with no lettering, no UI, no characters, no people, no creatures, no logos.
The interior of a bright, clean pink-and-white medical clinic lobby. At the top center a long curved white reception counter with a glowing green healing machine on it. On the left a tall blue shelf full of colorful potions and bottles. On the right a desk with a computer terminal with a teal screen. A pink checkered floor with a soft round rug, one round waiting bench, two potted plants, large windows letting in light, a double door at the bottom center. Warm, safe, cozy mood.
```

## Extra (fuera de las 9 imágenes del catálogo)

**Ciudad Plateada (exterior).** No hay imagen asignada en `kanto.json`: el centro de Plateada usa el interior (9) y el gimnasio su propio interior (8). Si se quiere un exterior, el prompt sería:

```
[cabecera de estilo] A small rocky mountain town of grey stone and warm brown tones on a plateau. A large stone gymnasium with a slate roof and a wide carved stone double door at the upper left, and a small clinic with a bright red roof and a white cross sign over its door at the lower right. Dirt streets, low stone walls, wooden barrels, a few small boulders and small pine trees at the edges, sparse grass. A street enters from the bottom center and a stone path leaves at the top center. Sturdy, dry, mountain-town mood.
```

## Después de generar

- Pásame la imagen elegida de cada escena y calculo sus zonas pulsables sobre ella (`*.zonas.json`, en píxeles y relativas 0–1) para el catálogo.
- Los retoques se piden de uno en uno, con la imagen buena como referencia.
