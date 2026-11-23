# Modo campaña: kit de interfaz (primer tramo)

Arte de la interfaz del modo campaña (Pueblo Paleta → Brock). La estructura de las pantallas es la de los wireframes ya cerrados (tableros D, I, J y M); aquí solo se fija el acabado visual.

Lienzo de trabajo (kit y pantallas de combate de muestra): https://claude.ai/artifact/X1g6QDJp8cnZg9CtWb71Df

Los archivos propios están en `app/assets/campana/ui/` y los sprites ajenos, aislados, en `app/assets/campana/sprites_ajenos/` (ver «Aviso de derechos»).

## Dirección de estilo

Colorido de videojuego, la mesa como tapete y «no es una app, es un juego». Contorno morado oscuro grueso, relieve de caramelo y tapete verde con borde dorado. Tipografía Fredoka.

| Color | Valor |
|---|---|
| Tinta | `#2a1d3a` |
| Crema | `#fff4d6` |
| Dorado | `#ffc83d` |
| Naranja | `#ff7a45` |
| Azul | `#5a8cf0` |
| Verde vida | `#5bd16b` |
| Rojo | `#e5484d` |
| Tapete | `#1f7a52` |

## Contenido

**Arte propio (SVG vectorial, original):**
`tapete_combate`, `vida_alta` / `vida_media` / `vida_baja`, `boton_ataque` / `boton_cargar` / `boton_cambiar` / `boton_secundario`, `hoja_fondo`, `barra_recursos_fondo`, `icono_dinero`, `icono_xp`, y dos criaturas de relleno (`relleno_criatura_a`, `relleno_criatura_b`) para maquetar mientras no estén los sprites definitivos.

Los SVG no llevan texto: nombres, PS y costes los pinta la app.

**Sprites ajenos (PNG), todos en `app/assets/campana/sprites_ajenos/`:**
- `iconos_tipo/`: 10 iconos de tipo del TCG, de 20×20 px (se ven bien entre 20 y 28 px).
- `energia/energia_arcoiris.png`: la ficha de energía, 20×20 px. Se muestra a tamaño nativo; la vacía es la misma imagen en gris oscuro apagado.
- `objetos/`: `bola_poke`, `bola_super`, `bola_ultra`, `bola_master`, `pocion`, `superpocion`, `hiperpocion`, `repelente`, `superrepelente` y `repelente_maximo`, de 160×160 px.

Los sprites de Pokémon, medallas y personajes que lleguen después irán también en esa carpeta.

## Decisiones cerradas

- **Fuente de sprites:** todos los sprites de objetos y Pokémon serán de Pokémon Escarlata y Púrpura (EP). En WikiDex el patrón de búsqueda es «Nombre EP.png» (objetos de 160×160, Pokémon de unos 250×250).
- **Tipos de la campaña → icono:** bicho → planta, volador → incoloro, veneno → oscuridad, tierra → lucha, hielo → agua, roca → lucha, fantasma → oscuridad, normal → incoloro. Los tipos del motor se guardan con su tipo real; el icono es solo presentación. La lista de tipos del motor cambia al aplicar #404 (salen `bicho`, `volador`, `veneno`, `fantasma` e `hielo`, y entra `metal`, cuyo icono falta), por lo que no se cuenta aquí.
- **Medallas:** las de Pokémon: Let's Go, Pikachu! y Let's Go, Eevee! (LGPE), decididas por Ayme el 2026-11-22. Sprites en WikiDex: https://www.wikidex.net/wiki/Categor%C3%ADa:Sprites_de_medallas_de_Kanto
- **Energía:** fichas de 0 a 10 (no barra).
- **Miniatura de banca:** la imagen de la carta en pequeño (60×84 px) con una barra de vida fina encima. La carta ya lleva su tipo, así que no hay borde de color. Debilitado: gris oscuro.
- **Carta completa:** siempre es la imagen exportada de PokeCardMaker; no se dibuja ningún marco de carta.
- **Bolas y pociones:** Super Ball con la 1.ª medalla y Ultra Ball con 5, según el wireframe del Centro (tablero M).

## Pendiente

- Escenas: Pueblo Paleta, Ruta 1, Ciudad Verde (con su centro), Ruta 22, Ruta 2, Bosque Verde, Ruta 2 norte, Ciudad Plateada (con su centro) y gimnasio de Brock; interior del Centro Pokémon.
- Sprites de Pokémon (se subirán cuando esté el mapa), enfermera y entrenadores.
- Líderes de gimnasio: no existen en estilo EP; falta decidir si salen de LGPE o se representan de otra forma (D-20 §8, pregunta 24).
- Pantalla del PC (sin wireframe todavía).
- Mayor resolución de los iconos de tipo y de la energía si se quieren más grandes de 28 px.

## Estado de las tareas de Arte (2026-11-23)

| Issue | Estado |
|---|---|
| #415 escenas | Datos hechos (#413, #425; coordenadas de marcador). Arte: guía vectorial y zonas de Pueblo Paleta y prompts de Flux de las 9 escenas más el interior del centro en `escenas/`. Faltan las imágenes finales. Formato por decidir: la app lee `app/assets/campana/escenas/<imagen>.webp` (D-20 §4) y la tarea pedía SVG. |
| #378 fondos de zona | Cubierta por #415: el mapa pasó a escenas (D-20 §10.7). Propuesta: cerrar. |
| #379 iconos de nodo | Obsoleta con el mapa de escenas. Propuesta: cerrar, salvo que se quiera marcar el tipo de nodo en la lista de la ruta. |
| #408 metal | Icono hecho (`sprites_ajenos/iconos_tipo/metal.png`). Color propuesto abajo. |
| #376 cartas impresas | Completa: Zubat, Geodude, Machop, Onix, Cubone y Slowpoke tienen carta en `app/assets/campana/cartas/` y JSON. Solo queda la decisión del Túnel Roca (D-20 §8, 15), que no es de Arte. |
| #405, #406, #407 | En espera hasta que Ayme confirme el plan B de Brock (#409). Esquema abajo. |

### Color del tipo metal (#408)

Propuesta: `0xFF7E9AAE` (acero azulado). El gris provisional actual, `0xFF78909C`, se confunde con normal (`0xFF9E9E9E`) y oscuridad (`0xFF455A64`). El icono de EP es gris cálido, así que el acero azulado lo separa de normal en las fichas y en los botones de ataque. Cambio en `colorTipo` de `app/lib/campana/widgets_campana.dart`, que queda para Programación porque Arte no toca código.

### Esquema de las cartas de fase 1 (#405–#407)

No se crean hasta confirmación. Datos de D-20 §3: heredan tipo, debilidad y resistencia de su base.

| Carta | Base | PS |
|---|---|---|
| Ivysaur | Bulbasaur | 100 |
| Charmeleon | Charmander | 90 |
| Wartortle | Squirtle | 100 |

Ataques, retirada y número NN/150 los fija Ayme al diseñar la carta.

## Aviso de derechos

Los iconos de tipo, la energía, las bolas, las pociones, los repelentes y los sprites de Pokémon y personajes son material de Nintendo / Game Freak / The Pokémon Company, tomado de Pokémon Escarlata y Púrpura a través de WikiDex.

**Decisión de Ayme (2026-11-22, #389):** es un proyecto personal, de uso privado para él y sus amigos, sin fines comerciales. El repositorio sigue siendo público y los sprites de Pokémon Escarlata y Púrpura se incluyen en él. Si GitHub o los titulares de los derechos piden retirarlos, Ayme los quita en cuanto se le avise. Esto no es una licencia: los derechos siguen siendo de sus titulares.

**Aislamiento:** todo el material ajeno vive en `app/assets/campana/sprites_ajenos/` y se declara en `app/pubspec.yaml` con las líneas `assets/campana/sprites_ajenos/…`. Para retirarlo de una vez basta con borrar esa carpeta y esas líneas; el arte propio de `app/assets/campana/ui/` no depende de él.

El arte propio se limita a la interfaz y a los fondos de escena.
