# Modo campaña: kit de interfaz (primer tramo)

Arte de la interfaz del modo campaña (Pueblo Paleta → Brock). La estructura de las pantallas es la de los wireframes ya cerrados (tableros D, I, J y M); aquí solo se fija el acabado visual.

Lienzo de trabajo (kit y pantallas de combate de muestra): https://claude.ai/artifact/X1g6QDJp8cnZg9CtWb71Df

Los archivos están en `app/assets/campana/ui/`.

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

**Sprites aportados por el autor (PNG):**
- `iconos_tipo/`: 10 iconos de tipo del TCG, de 20×20 px (se ven bien entre 20 y 28 px).
- `energia_arcoiris.png`: la ficha de energía, 20×20 px. Se muestra a tamaño nativo; la vacía es la misma imagen en gris oscuro apagado.
- `bola_poke`, `bola_super`, `bola_ultra`, `bola_master`: 160×160 px.
- `pocion`, `superpocion`, `hiperpocion`: 160×160 px.
- `repelente`, `superrepelente`, `repelente_maximo`: 160×160 px.

## Decisiones cerradas

- **Fuente de sprites:** todos los sprites de objetos y Pokémon serán de Pokémon Escarlata y Púrpura (EP). En WikiDex el patrón de búsqueda es «Nombre EP.png» (objetos de 160×160, Pokémon de unos 250×250).
- **Tipos de la campaña → icono:** bicho → planta, volador → incoloro, veneno → oscuridad, tierra → lucha, hielo → agua, roca → lucha, fantasma → oscuridad, normal → incoloro. Los 15 tipos del motor se guardan con su tipo real; el icono es solo presentación.
- **Energía:** fichas de 0 a 10 (no barra).
- **Miniatura de banca:** la imagen de la carta en pequeño (60×84 px) con una barra de vida fina encima. La carta ya lleva su tipo, así que no hay borde de color. Debilitado: gris oscuro.
- **Carta completa:** siempre es la imagen exportada de PokeCardMaker; no se dibuja ningún marco de carta.
- **Bolas y pociones:** Super Ball con la 1.ª medalla y Ultra Ball con 5, según el wireframe del Centro (tablero M).

## Pendiente

- Escenas: Pueblo Paleta, Ruta 1, Ciudad Verde (con su centro), Ruta 22, Ruta 2, Bosque Verde, Ruta 2 norte, Ciudad Plateada (con su centro) y gimnasio de Brock; interior del Centro Pokémon.
- Sprites de Pokémon (se subirán cuando esté el mapa), enfermera y entrenadores.
- Medallas y líderes de gimnasio: no existen en estilo EP; hay que elegir otra versión o un estilo propio.
- Pantalla del PC (sin wireframe todavía).
- Mayor resolución de los iconos de tipo y de la energía si se quieren más grandes de 28 px.

## Aviso de derechos

Los iconos de tipo, la energía, las bolas, las pociones y los repelentes son material de Nintendo / Game Freak / The Pokémon Company. El repositorio es público: antes de publicar la app hay que decidir si se sustituyen por arte propio.
