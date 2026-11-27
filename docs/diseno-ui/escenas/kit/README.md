# Kit de escenas en vector (Arte)

Sprites sueltos y un compositor, para que lo que sale en varias pantallas se vea siempre igual y las zonas pulsables salgan solas.

- `generar_sprites.py` (con `vec.py`): genera `sprites/*.svg` y `sprites.json` (tamaño, ancla de la base y zonas de cada sprite).
- `componer.py escenas/<id>.escena.json`: lista de objetos + caminos → `render/<id>.svg`, `.png` (1920×1088) y `.zonas.json`.
- Una escena es una lista de `{sprite, x, y, escala, flip, id, acciones}`; `(x, y)` es la base centrada del sprite. Los caminos son trazos con material (`tierra`, `piedra`, `hierba`).

## Inventario de sprites

| Sprite | Para qué | Estado | Escenas |
|---|---|---|---|
| `laboratorio` | Laboratorio del Profesor (puerta + edificio) | nuevo | Pueblo Paleta |
| `casa-jugador` | Casa del jugador, tejado naranja | nuevo | Pueblo Paleta |
| `casa-pequena-azul` / `-roja` / `-verde` | Casas de vecinos (variantes de color) | nuevo; la verde ya existía como dibujo en la base de Ciudad Verde | Pueblo Paleta (azul, roja); Ciudad Verde (verde) |
| `buzon` | Buzón de la casa del jugador | nuevo | Pueblo Paleta |
| `farola` | Farola de calle | nuevo; ya existía como dibujo en las bases anteriores | Pueblo Paleta, Ciudad Verde |
| `arbol-1` | Árbol redondo | nuevo; ya existía como dibujo | todas |
| `arbusto`, `mata-hierba` | Relleno | nuevos | todas |
| `arbol-2` | Conífera (segundo tipo de árbol) | nuevo | Ruta 1, Ruta 22 |
| `hierba-alta-grande` / `-media` | Mancha de hierba alta, zona de combate (`combate` + Pokémon) | nuevos | Ruta 1 (grande), Ruta 22 (media) |
| `valla`, `roca` | Decoración de ruta | nuevos | Ruta 1 (`roca` también en Ruta 22) |
| `puente` | Puente de piedra cenital sobre el río | nuevo | Ruta 22 |
| `portico` | Pórtico de piedra, salida de ruta (zona `puerta` → `ir`) | nuevo | Ruta 22 |

Materiales de camino: `tierra`, `piedra`, `hierba` y `agua` (río, con brillos) (en `componer.py`).

## Por hacer según vayamos montando escenas
`centro-pokemon`, `tienda`, `casa-grande`, `cartel-ruta`, `fuente`, `banco`, `gimnasio`, `entrada-bosque`.

## Nota de estilo
Las escenas finales de Pueblo Paleta y Ruta 1 que hay en `app/assets/campana/escenas/` son pintadas (Flux). Este kit es vector: si pasa a ser el aspecto definitivo, habrá que volver a montar esas dos con el kit.
