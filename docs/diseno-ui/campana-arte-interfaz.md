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

## Pantallas implementadas (#373)

Estado el 2026-11-23. El código está en `app/lib/campana/`. Las claves (`Key`) son las que usan los tests de `app/test/`.

### Mapa (propuesta D, PR #440)

`escena_mapa.dart`: `EscenaInteractiva`, `BarraRecursos` y `ColoresCampana` (la paleta de arriba, compartida por todas las pantallas).

- **Escena:** proporción 16:9, contorno tinta de 3 px y esquinas redondeadas. Arriba lleva un cartel crema con el nombre del nodo.
- **Fondo:** `app/assets/campana/escenas/<imagen>.webp` si ya existe; si no, `marcador.svg`. Para estrenar un fondo basta con soltar el `.webp` con el id de `escena.imagen` del catálogo, sin tocar código.
- **Zonas pulsables:** salen del catálogo (`escena.zonas`, coordenadas relativas de 0 a 1). Una zona que se puede usar va en dorado translúcido con contorno tinta; una que todavía no, en blanco apagado. Mientras el fondo es el marcador, cada zona lleva un icono y un rótulo («Hierba alta», el nombre del nodo de destino, «Mostrador»…). Con el fondo definitivo solo queda el contorno.
- **Claves:** `zona-ir-<destino>` y `zona-<accion>` (`zona-combate`, `zona-inicial`, `zona-hablar`, `zona-curar`, `zona-tienda`, `zona-pc`) y `escena-<nodo>`.
- **Qué hace cada zona** (`estadoZona`):
  - `ir`: va hacia delante si el destino es una opción, o vuelve atrás si es un nodo ya visitado.
  - `combate`: empieza el combate, o repite un salvaje ya ganado.
  - `inicial`: abre una hoja con los iniciales.
  - `hablar`: conversa.
  - `curar`: cura al equipo.
  - `tienda` y `pc`: abren una hoja.
  - Con una captura a medias, todas están apagadas.
- **Barra de recursos** (`barra-recursos`): dinero (`ui/icono_dinero.svg`), Pokéballs (`sprites_ajenos/objetos/bola_poke.png`), XP (`ui/icono_xp.svg`) y medallas (icono del sistema hasta que lleguen las de LGPE).
- Debajo siguen, por ahora, el panel del nodo y el equipo de la primera versión. Se rehacen con las pantallas de equipo y centro.
- Los SVG se pintan con `flutter_svg`.

### Combate (propuesta I, PR #443)

`pantalla_combate.dart`.

- **Tapete:** verde `tapete` con borde dorado de 4 px. De arriba abajo: banca rival (`banca-rival`), activo rival (`activo-rival`), última jugada (`combate-ultima`), tu activo (`activo-jugador`) y tu banca (`banca-jugador`).
- **Activo:** la carta a 110 px de ancho, el nombre, una barra de vida gruesa (verde, naranja por debajo de la mitad y rojo por debajo de un cuarto), los PS, las fichas de energía y los estados como chapas naranjas. El rival tiene la carta a la derecha y tú a la izquierda.
- **Banca:** miniaturas de 60×84 con una barra de vida de 6 px encima (`banca-<bando>-<índice>`). Los caídos van oscurecidos y no se pueden tocar.
- **Energía:** 10 fichas `energia_arcoiris.png` a 20 px; las vacías, la misma imagen en gris oscuro apagado.
- **Acciones:**
  - Al tocar tu activo sale la hoja `hoja-acciones` con `ataque-<i>` (botón del color del tipo, con coste y daño) y `accion-cargar` (dorado).
  - Al tocar uno de tu banca sale la confirmación «gasta el turno» (`confirmar-cambio`). Cuando tu activo cae, tocar la banca elige el relevo.
- **Registro:** el entero se abre desde la última jugada o desde el botón de la barra (`combate-ver-registro`).
- **Tutorial** (combates de la Ruta 1 y Pikachu, `esCombateTutorial`): tu activo lleva un brillo dorado fijo y el aviso «Toca a tu Pokémon…» (`combate-tutorial`) hasta el primer toque. No es animado, para no frenar los tests.

### Pendiente

- Pantalla de **equipo** (propuesta J) y **centro Pokémon** (propuesta M) con el PC aparte: PR 3 y 4 de #373.
- Fuente **Fredoka** y los botones SVG del kit (`boton_*`, `hoja_fondo`, `vida_*`, `tapete_combate`). Hoy la mesa reproduce sus colores con widgets; el arte del kit se puede cambiar sin tocar la lógica.

## Pendiente

- Escenas: Pueblo Paleta, Ruta 1, Ciudad Verde (con su centro), Ruta 22, Ruta 2, Bosque Verde, Ruta 2 norte, Ciudad Plateada (con su centro) y gimnasio de Brock; interior del Centro Pokémon.
- Sprites de Pokémon (se subirán cuando esté el mapa), enfermera y entrenadores.
- Líderes de gimnasio: no existen en estilo EP; falta decidir si salen de LGPE o se representan de otra forma (D-20 §8, pregunta 24).
- Pantalla del PC (sin wireframe todavía).
- Mayor resolución de los iconos de tipo y de la energía si se quieren más grandes de 28 px.

## Aviso de derechos

Los iconos de tipo, la energía, las bolas, las pociones, los repelentes y los sprites de Pokémon y personajes son material de Nintendo / Game Freak / The Pokémon Company, tomado de Pokémon Escarlata y Púrpura a través de WikiDex.

**Decisión de Ayme (2026-11-22, #389):** es un proyecto personal, de uso privado para él y sus amigos, sin fines comerciales. El repositorio sigue siendo público y los sprites de Pokémon Escarlata y Púrpura se incluyen en él. Si GitHub o los titulares de los derechos piden retirarlos, Ayme los quita en cuanto se le avise. Esto no es una licencia: los derechos siguen siendo de sus titulares.

**Aislamiento:** todo el material ajeno vive en `app/assets/campana/sprites_ajenos/` y se declara en `app/pubspec.yaml` con las líneas `assets/campana/sprites_ajenos/…`. Para retirarlo de una vez basta con borrar esa carpeta y esas líneas; el arte propio de `app/assets/campana/ui/` no depende de él.

El arte propio se limita a la interfaz y a los fondos de escena.
