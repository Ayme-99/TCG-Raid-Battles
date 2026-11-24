# Prompts de Flux para los fondos de escena (modo campaña, primer tramo)

## Cómo usarlos

1. **Flux no respeta bien las posiciones.** Para que las zonas pulsables caigan donde toca, usa mi escena vectorial como guía de composición: img2img con ruido de 0,55–0,65 o ControlNet (canny o depth) con el SVG exportado a PNG. Así el camino, la puerta y la hierba quedan en su sitio y Flux solo aporta la textura y el detalle.
2. **Tamaño de generación:** 704×1536 px (proporción 0,458, casi la del móvil 390×844). Después se reduce a 390×844 o a 780×1688 para pantallas nítidas.
3. **Sin personajes ni criaturas en el fondo.** Entrenadores, Pokémon y el resto van como sprites encima. Cada prompt reserva «huecos» claros donde irán.
4. **Márgenes de interfaz.** La barra de recursos tapa el 7 % superior y el equipo tapa el 17 % inferior: lo importante va entre el 8 % y el 82 % de la altura.
5. **Coherencia entre escenas:** misma cabecera de estilo en todos, misma semilla base, misma hora del día y misma paleta. Genera varias y elige la que más encaje con las demás.
6. **Sin marcas.** Los prompts no nombran videojuegos ni franquicias, para que el resultado sea un fondo original.

Flux no usa prompt negativo: lo que no quieres se redacta en positivo («sin texto» → «a clean image with no lettering»).

## Cabecera de estilo (pegar al principio de todos)

```
Top-down three-quarter bird's-eye view of a small cartoon-realistic adventure game map scene, painterly stylized realism with soft cel-shaded lighting, bright saturated storybook colors, thick clean shapes, sunny late-morning light with soft long shadows falling to the lower right, hand-painted textures on grass, dirt and stone, rich small details, a cozy playful video-game feel. Vertical portrait composition. A clean image with no lettering, no UI, no characters, no creatures, no people, no logos.
```

## 1. Pueblo Paleta (inicio: elegir inicial)

Zonas: laboratorio (arriba a la izquierda, puerta pulsable), camino que sale por arriba a la derecha hacia la Ruta 1, casas decorativas.

```
[cabecera de estilo] A tiny peaceful seaside hamlet. At the upper left a large cream-colored research laboratory with a teal roof and a small white observatory dome, a clearly visible brown double door facing the viewer. Two small cottages, one with an orange roof lower left, one with a blue roof on the right, white picket fences and flower beds with pink, yellow and purple flowers. A sandy dirt path runs from a small round plaza near the bottom up the right side of the image and ends at a wooden arch gateway at the top right. A yellow mailbox, a street lamp, round bushy trees framing the edges. The bottom fifth of the image shows a sandy shore and calm blue sea. Calm, welcoming, morning mood.
```

## 2. Ruta 1 (bifurcación: dos hierbas altas)

Zonas: dos manchas de hierba alta bien separadas (una a cada lado del camino), salida arriba (Ciudad Verde queda arriba) y entrada abajo.

```
[cabecera de estilo] A gentle countryside trail that splits in two around a small grassy island. A wide light-brown dirt path enters from the bottom center and forks into a left branch and a right branch that rejoin at the top center. On the left branch and on the right branch, one large clearly separated patch of tall dark-green grass each, with swaying blades, about a fifth of the image wide, easy to recognize as tall wild grass. Low stone-edged ledges, a few wooden fence posts, scattered wildflowers, light rolling hills, young trees at the borders. Open and friendly mood, lots of empty clear ground around the grass patches.
```

## 3. Ciudad Verde (con su centro)

Zonas: edificio del centro de curación (puerta pulsable), salidas arriba y abajo.

```
[cabecera de estilo] A small green-roofed town seen from above. A prominent medical clinic building near the middle with a bright red roof, white walls, a big white cross sign over a wide glass double door facing the viewer, and a small awning. Around it neat houses with green roofs, paved cobblestone streets forming a cross, flower planters, wooden benches, a small fountain, trimmed hedges and round trees at the edges. Streets exit at the top center and bottom center. Fresh, friendly town mood.
```

## 4. Ruta 22 (opcional, da puntos)

```
[cabecera de estilo] A wide open grassy plain with a shallow clear river crossing the middle from left to right and a small arched stone bridge over it. Rocky outcrops, scattered boulders, two or three patches of tall grass, a dirt path that comes in from the bottom, crosses the bridge and continues to a tall stone gateway at the top. Distant low mountains hinted at the top edge, wind-blown grass, a lonely, wide-open mood.
```

## 5. Ruta 2 sur (bifurcación: dos hierbas altas)

```
[cabecera de estilo] A forest-edge trail that forks in two. The wide dirt path enters from the bottom, splits around a thick bush hedge into a left and a right branch, and rejoins toward the top where tall dark trees begin to close in. One large, clearly separated patch of tall grass on each branch. Mossy rocks, ferns, a few wooden signposts without writing, fallen leaves, dappled light through tree canopy. Mysterious but still sunny.
```

## 6. Bosque Verde (serpenteante, hierba alta, entrenadores al acecho)

Zonas: camino serpenteante de abajo a arriba, 4–5 manchas de hierba alta, huecos para 2 entrenadores y un personaje de aviso, salida arriba, entrada abajo.

```
[cabecera de estilo] A dense, lush forest with a single winding dirt path that snakes in S-curves from the bottom center to the top center, leaving shallow clearings on either side. Huge round dark-green tree canopies seen from above, thick undergrowth, mushrooms and mossy logs, dappled sunlight spots on the ground. Four or five patches of tall grass along the path, each about a sixth of the image wide. Three small empty clearings beside the path, free of objects, left clean for characters to be placed. A glowing gap of brighter light at the top where the forest opens. Enclosed, slightly tense adventure mood.
```

## 7. Ruta 2 norte

```
[cabecera de estilo] The northern end of a forest trail opening up to a rocky hillside. A dirt path climbs from the bottom to the top center between a few tall trees and shrubs, one single patch of tall grass on the right side near the middle, rocky grey cliffs with small ledges and boulders starting at the top edge. Dry golden grass, scattered pebbles. Open, slightly dry mood.
```

## 8. Ciudad Plateada (con su centro y su gimnasio)

```
[cabecera de estilo] A small rocky mountain town of grey stone and warm brown tones, built on a plateau. A large stone gymnasium with a slate roof and a wide carved stone double door in the upper left, with a big smooth boulder emblem above it; a medical clinic with a bright red roof and a white cross sign over its door in the lower right. Dirt streets, stone walls, wooden barrels, small mining carts, scattered boulders, a few pine trees at the edges, sparse grass. Streets exit at the top center and bottom center. Sturdy, dry, mountain-town mood.
```

## 9. Gimnasio de Brock (interior)

```
[cabecera de estilo, pero interior] The interior of a rocky-themed battle gymnasium seen from above: a large oval arena floor of packed sandy earth surrounded by a low ring of stone blocks, big boulders and pillars at the corners, torches on the walls, a worn rug at the entrance at the bottom. Grey-brown stone walls, warm torchlight, dust motes. No people, no creatures. Heavy, solid, tense mood.
```

## 10. Interior del Centro Pokémon

Zonas: mostrador (arriba, curar), estantería (izquierda, tienda), ordenador (derecha, PC), puerta abajo.

```
[cabecera de estilo, pero interior] The interior of a bright, clean pink-and-white medical clinic lobby seen from above. At the top a long curved white reception counter with a glowing green healing machine on top. On the left a tall blue shelf full of colorful potions and bottles. On the right a desk with a computer terminal with a teal screen. A pink checkered floor with a soft rug, a round waiting bench, potted plants, large windows letting light in, a double door at the bottom. No people. Warm, safe, cozy mood.
```

## Después de generar

- Pásame las imágenes elegidas y las integro en las pantallas con la barra de recursos, las zonas pulsables y las miniaturas.
- Las coordenadas de las zonas (`*.zonas.json`) se mantienen si Flux respeta la guía de composición.
- Si algo queda fuera de sitio, se ajusta el rectángulo de la zona en el JSON, no la imagen.
