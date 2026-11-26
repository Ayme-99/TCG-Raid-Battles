# Cartas del tramo 2 contra la tabla de D-20 §4

Fecha: 2026-11-26 · Issues: #380 y #513 · Solo informe: no se decide nada ni se edita D-20.

**Qué se ha comparado.** Las imágenes de `app/assets/campana/cartas/` (clefairy, clefairy-jefe, paras, jigglypuff, ekans, horsea, shellder, staryu, starmie), leídas carta a carta, contra la tabla «Tabla de cartas del tramo 2» de D-20 §4 en master. Los JSON de catálogo de estas cartas **aún no existen** (tarea 25, #513): la comprobación es contra la imagen, no contra el JSON.

## Resultado: sin diferencias

Las nueve cartas coinciden con la tabla en todo lo que se ve en la imagen.

| Carta | N.º | PS | Tipo | Debilidad | Retirada | Ataques (coste y daño) | ¿Coincide? |
|---|---|---:|---|---|---:|---|---|
| Clefairy jefe | 02/20 | 120 | Psíquico | Oscuridad ×2 | 0 | Muro Mágico (habilidad) · Doble Bofetón (2, 20+) | Sí |
| Clefairy | 035/150 | 60 | Psíquico | Oscuridad ×2 | 0 | Muro Mágico · Doble Bofetón (2, 20+) | Sí |
| Paras | 046/150 | 50 | Planta | Fuego ×2 | 0 | Absorber (1, 20; cura 10) · Paralizador (2, 0) | Sí |
| Jigglypuff | 039/150 | 70 | Normal | Lucha ×2 | 0 | Canto (1, 0) · Doble Bofetón (2, 20+) | Sí |
| Ekans | 023/150 | 60 | Oscuridad | Lucha ×2 | 0 | Constricción (2, 10) · Mordisco (2, 30) | Sí |
| Horsea | 116/150 | 50 | Agua | Eléctrico ×2 | 0 | Pantalla de Humo (2, 0) · Pistola Agua (2, 20) | Sí |
| Shellder | 090/150 | 60 | Agua | Eléctrico ×2 | 0 | Refugio (1, 0) · Torbellino (2, 10) | Sí |
| Staryu | 120/150 | 60 | Agua | Eléctrico ×2 | 0 | Pistola Agua (2, 20), un solo ataque | Sí |
| Starmie | 121/150 | 110 (Fase 1) | Agua | Eléctrico ×2 | 1 | Rayo Confuso (1, 0) · Rapidez (2, 50) | Sí |

Los textos de los efectos coinciden con los de la tabla (`curaAlAtacar` de Paras, `duermeDefensor` de Canto, `apresaDefensor` de Constricción y Torbellino, `ignoraFallo` de Rapidez, `sinDanoIndirecto` de Muro Mágico). Los que la tabla dice «igual que» otra carta son idénticos a los del catálogo actual:
- **Refugio de Shellder** = el de Wartortle (`reduceDanoPropio` 10, mismo texto).
- **Pantalla de Humo de Horsea** = el de Charmeleon.
- **Pistola Agua de Horsea y Staryu** = el de Slowpoke (2 energías, 20).
- **Rayo Confuso de Starmie** = el texto de Supersónico de Zubat.

## Lo que la imagen no dice
No aparece en las cartas y no se ha podido comprobar: la **categoría de captura** y la XP (Común, Intermedio, Fuerte), el dinero de los entrenadores y los nombres de los efectos del motor. Eso lo fija el JSON cuando se cree (#513).
