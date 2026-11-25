# Modo campaña: sonido (primer tramo)

Estado: **propuesta del Departamento de Sonido, pendiente de que Ayme la apruebe** (2026-11-23; revisada el 2026-11-24 contra `master`, con el guion de playtest de #385 y las cartas nuevas de D-20). Cubre las issues #381 (música) y #382 (efectos) y fija qué hace falta antes del playtest #385. Es solo documentación: **no hay audio ni código en este cambio**.

Alcance: el primer tramo, de Pueblo Paleta a Brock (D-20 §4). Los combates, la captura, el centro Pokémon, la tienda y el equipo son los de D-20; si algo no coincide con el código o el catálogo, mandan ellos.

## 1. Reglas del audio

1. **Ningún audio de los juegos de Pokémon** (música, efectos ni gritos), ni descargado ni subido, ni siquiera como «provisional». Los sprites se decidieron aparte (D-20 §10.1, #389); el audio no entra en esa decisión.
2. **Las referencias se escuchan, no se copian.** Una pieza original no cita ninguna melodía reconocible de una referencia, ni como guiño.
3. **El repositorio es público.** Todo audio que se suba es original o lleva una licencia que permita redistribuirlo, y se anota en un registro de créditos (§6). Si una pieza de Ayme no cumple eso, no se sube (pregunta 2 de §5).
4. **Proyecto personal, sin fines comerciales** (D-20 §10.1): eso no cambia las reglas 1 a 3.

**Códigos de «Origen»** en las tablas:

| Código | Qué es |
|---|---|
| **O** | Original: compuesta, sintetizada o grabada por Ayme o su equipo. |
| **L** | De una librería con licencia libre que permita redistribuir (por ejemplo CC0). Se comprueba la licencia de **cada archivo** y se apunta en el registro. |
| **A** | Material que Ayme ya tiene (sus propias composiciones o grabaciones, o packs que ya posea). Solo se sube si la licencia lo permite; si no, queda fuera del repositorio. |

La columna dice la **primera opción** y, tras «→», el plan B.

## 2. Dirección sonora

Estilo visual ya fijado: colorido de videojuego y la mesa como tapete (`campana-arte-interfaz.md`). El sonido lo sigue:

- **Paleta de timbres:** marimba, ukelele, glockenspiel, pizzicato de cuerda, bajo de sintetizador suave y percusión de madera. Sin guitarras eléctricas saturadas ni orquesta épica.
- **Textura de mesa:** los efectos de objetos (moneda, Ball, medalla) suenan a **objeto sobre tapete de fieltro**: golpes secos y cálidos, sin reverb de sala grande. Es lo que distingue este juego de uno de consola.
- **Alegre aunque se pierda:** la derrota no es «fin de partida»; se vuelve al último punto de curación (D-20 §10.2). Tono de «uy», no de castigo.
- **Mezcla:** la música va unos 6 dB por debajo de los efectos, para que no tape el resultado de una moneda. Los niveles exactos se ajustan con los archivos reales; es un punto de partida.

## 3. Música (#381)

El simulador estima unos **18 combates de unos 12 turnos por recorrido** del tramo (guion de playtest, `GUION_CAMPANA_TRAMO1.md`), así que **la música de combate es la que más se oye**. Si un turno lleva de 5 a 10 s (estimación mía), un combate pasa del minuto y un bucle de 45 s se repetiría varias veces. Por eso los bucles de combate van de 60 a 90 s, con una intro de 2 a 4 s sin bucle que diga qué pieza es desde el principio, y se prefiere un segundo tema de combate salvaje antes que alargar uno solo (M-04b, P2). Los bucles de exploración van de 60 a 90 s. Un bucle debe poder repetirse sin que se note el salto: el final enlaza con el principio.

| ID | Pieza y dónde suena | Duración y bucle | Ambiente | Referencias (solo para escuchar) | Origen | Prio |
|---|---|---|---|---|---|---|
| M-01 | **Pueblo.** Pueblo Paleta, Ciudad Verde y el gimnasio de Ciudad Plateada (mientras no hay combate) | 60–90 s, bucle | Calma de mañana, hogar, un poco de nostalgia. 80–95 BPM, tono mayor, marimba y ukelele | Tema de Pueblo Paleta (Rojo/Azul) por la calma; Animal Crossing y Stardew Valley por el tono de pueblo | O → L | P1 |
| M-02 | **Ruta.** Ruta 1, Ruta 2, Ruta 22 y Ruta 2 norte | 60–90 s, bucle | Ir de paseo con ganas de aventura. 105–120 BPM, ritmo marcado de madera, melodía silbable | Tema de la Ruta 1 (Rojo/Azul) por la sensación de salir de casa | O → L | P1 |
| M-03 | **Bosque Verde.** Escena del bosque y del aviso de Pikachu (conversación) | 60–75 s, bucle | Lo mismo que M-02 pero más oscuro y lento: menos melodía, más cuerda a pizzicato. 85–100 BPM | Tema del Bosque Verde (Rojo/Azul) por la tensión suave | O (variante de M-02) → reutilizar M-02 | P2 |
| M-04 | **Combate salvaje.** Rutas y bosque; también el combate de la Ruta 1 (tutorial) | Intro 2–3 s + bucle 60–90 s | Energía alegre, sin amenaza. 140–150 BPM, ritmo sincopado, melodía corta que se queda | Tema de combate salvaje (Rojo/Azul) por la urgencia; Pokémon TCG Pocket por el tono ligero | O → L | **P0** (provisional) |
| M-05 | **Combate de entrenador.** Cazabichos y Entrenador Joven | Intro 2–3 s + bucle 60–90 s | Más serio que M-04: hay un rival que te ha visto. 145–155 BPM, bajo más presente, metales sintéticos | Tema de combate de entrenador (Rojo/Azul) | O → L | P1 |
| M-06 | **Jefe (Pikachu 01/20).** El resto de jefes NN/20 pueden reutilizarlo | Intro 3–4 s + bucle 60–90 s | Más grande y más peligroso, pero con humor: el jefe es un Pikachu que se come la comida de los demás. 150–160 BPM | Temas de combate contra jefes en juegos de plataformas; el tono del aviso del Cazabichos | O → L | P1 |
| M-07 | **Líder de gimnasio (Brock).** *Propuesta mía, no estaba en la lista* | Intro 3–4 s + bucle 60–75 s | Cima del primer tramo: rotundo, con peso (los Pokémon de Brock son de tipo lucha). 135–150 BPM, percusión grave | Tema de combate de líder (Rojo/Azul) | O → **reutilizar M-05** | P2 |
| M-08 | **Centro Pokémon**, con tienda y PC | 45–60 s, bucle | Refugio: amable, tranquilo, casi de nana. 70–85 BPM, glockenspiel y pads suaves | Tema del Centro Pokémon (Rojo/Azul); menús de tienda de juegos de granja | O → L | P1 |
| M-09 | **Victoria de combate.** Al ganar a un salvaje o un entrenador | 4–6 s, **sin bucle** | Fanfarria corta y alegre, que corte limpia | Fanfarria de victoria de los juegos de Pokémon por la duración | O → L | **P0** |
| M-10 | **Victoria de jefe o de gimnasio (medalla).** Cierra el tramo | 8–10 s, **sin bucle** | La más grande del tramo; deja sitio para el efecto de la medalla (E-18) | Igual que M-09, más larga | O → reutilizar M-09 | P1 |
| M-11 | **Derrota.** Al caer el último Pokémon | 4–5 s, **sin bucle** | «Uy»: descendente y blanda, sin dramatismo. Después se vuelve al último punto de curación | Jingles de «has fallado» de juegos de móvil, por la ligereza | O → L | **P0** |
| M-12 | **Pantalla de equipo** (y PC si no es la del centro) | 60 s, bucle | Tranquila, para pensar sin prisa. 75–90 BPM, base de M-08 con otro arreglo | La música de menús de Pokémon TCG Pocket | O → **mantener la música de la escena con volumen bajo** | P2 |

**Notas por pieza**

- **Combates:** una sola pieza provisional sirve para todos hasta que haya M-05 a M-07: es lo que cubre el P0. **M-04b** (un segundo tema salvaje, P2) es la primera ampliación si el playtest dice que cansa.
- **Jefe con aliado (Pikachu):** el aliado entra en dos pasos, al 50 % y al 40 % (D-20 §4, Jefes). Esos momentos los marca un efecto (E-15), no un cambio de música; si luego se quiere, M-06 puede tener una segunda capa que entre con el aliado (P2).
- **Victoria y derrota** no llevan bucle: la pantalla de resultado espera al jugador.
- **Final del tramo:** al ganar a Brock, la app dice que el recorrido acaba por ahora (D-20 §4); M-10 y E-18 son el cierre.

## 4. Efectos (#382)

La campaña usa mucho el azar (monedas de ataques y habilidades, hasta 3 monedas de golpe con Ataque Furia, y una moneda por cada Ball), así que **los efectos de moneda y de captura son los que más se repiten**. Cada uno lleva **2 o 3 variantes** para que no cansen, y deben poder sonar encadenados.

| ID | Efecto y cuándo | Duración | Ambiente | Referencias (solo para escuchar) | Origen | Prio |
|---|---|---|---|---|---|---|
| E-01 | **Tirar moneda.** La moneda sale al aire | 0,4–0,6 s | Tintineo metálico que sube | Moneda al aire de un juego de mesa | O (grabada con el móvil) → L | **P0** |
| E-02 | **Moneda cae y rueda** sobre el tapete | 0,6–1 s, 3 variantes | Golpe seco sobre fieltro, dos rebotes y un giro que se apaga | Moneda real sobre un tapete o una manta | O (grabada) → L | **P0** |
| E-03 | **Resultado Cara** | 0,3 s | Campanita brillante y corta: «sí» | Aviso de acierto de juegos de móvil | O (sintetizado) → L | **P0** |
| E-04 | **Resultado Cruz** | 0,3 s | Tono mate y bajo: «no» (sin ser un error, es solo mala suerte) | Aviso neutro de «no ha salido» | O (sintetizado) → L | **P0** |
| E-05 | **Lanzar Ball.** Al pulsar capturar | 0,5–0,8 s | Silbido de lanzamiento y golpe suave; 3 afinaciones (Pokéball, Super Ball y Ultra Ball: más agudo cuanto mejor) | Lanzamiento con pelota blanda | O (sintetizado) → L | **P0** (una sola afinación) |
| E-06 | **Captura lograda** | 2–3 s | Melodía corta y feliz: «¡capturado!» | Jingles de «objeto conseguido» | O → L | **P0** |
| E-07 | **Captura fallida.** Cruz: el Pokémon se escapa de la Ball y, si quedan Balls, se vuelve a lanzar | 0,6–1 s | Botecito y «plop» cómico, sin drama | Muelle o burbuja | O (sintetizado) → L | **P0** |
| E-08 | **Atacar.** Al usar un ataque; variantes por tipo | 0,4–0,7 s | Un silbido genérico y 7 variantes de tipo (ver abajo) | Efectos de golpe de juegos de lucha de estilo sencillo | O (sintetizado) → L | **P0** (solo el genérico), tipos P1 |
| E-09 | **Daño recibido** | 0,3 s, 3 intensidades | Golpe normal; **débil** (×2): golpe más fuerte con un «ding» de acierto; **resistido** o **0 de daño**: golpe apagado | Impactos de juegos de combate por turnos | O (sintetizado) → L | **P0** (solo el normal), el resto P1 |
| E-10 | **Pokémon debilitado** | 0,8–1,2 s | Descenso suave, como desinflarse | Globo que se deshincha, versión corta | O (sintetizado) → L | **P0** |
| E-11 | **Cambiar de Pokémon**, y usar la **Cuerda Huida** (cambia sin pagar la retirada; gasta el turno, D-20 §10) | 0,4–0,6 s | Cambio de carta: «fshh» de papel y un toque | Barajar o deslizar una carta | O (grabado) → L | P1 |
| E-12 | **Cargar** (energía +2) | 0,6–0,8 s | Subida chispeante que carga una ficha | Carga de energía de juegos arcade | O (sintetizado) → L | P1 |
| E-13 | **Estados y efectos de ataque.** Veneno (aplicar y chequeo), parálisis (Dragoaliento), drenaje (Drenadoras), bajar el daño del rival, subir el daño que recibe, quitar o ganar energía, confusión y fallo por moneda (Pantalla de Humo, Bofetón Lodo) | 0,3–0,5 s cada uno | Un motivo corto por familia: veneno (gorgoteo), parálisis (chisporroteo que se corta), drenaje (sorbo ascendente), bajada (descendente), subida (ascendente), energía (tic de ficha), confusión y fallo (zumbido) | Pitidos de estado de juegos de rol | O (sintetizado) → L | P2 |
| E-14 | **Ficha de energía** que se gasta o se recupera | 0,1 s | Clic seco | Ficha de plástico sobre madera | O (grabado) → L | P2 |
| E-15 | **Llamada de aliado del jefe** (50 %) y **aliado al frente** (40 %) | 1–1,5 s, 2 variantes | Pequeña fanfarria de «llega ayuda»; la del 40 %, más fuerte | Llegada de un personaje en una pelea de juego de mesa | O → L | P1 |
| E-16 | **Evolución.** Caterpie → Metapod, Weedle → Kakuna y los iniciales a 0 medallas (70 XP); el guion de #385 pide probarlas. Hacerse ex y el intercambio (D-20 §2.1) podrían llevar un remate propio más adelante | 3–5 s | Brillo que crece, estallido y melodía corta de remate | Escenas de transformación de dibujos; no la melodía de ningún juego | O → L | P1 |
| E-17 | **Curar.** Poción (fuera de combate) y mostrador del centro (todo el equipo) | Poción 0,8 s; centro 2–3 s | Destellos suaves; el del centro, con una melodía cortita y cálida. *Añadido por mí, no estaba en la lista* | Máquina de curación de un centro Pokémon (por la idea, no por la melodía) | O → L | P1 |
| E-18 | **Subir medalla.** Al ganar a Brock: la medalla se suma a las del jugador | 2–3 s (sobre M-10) | Brillo de metal y golpe de tapete; remata la fanfarria | Medalla que cae en una mesa | O (grabado + sintetizado) → L | P1 |
| E-19 | **Comprar.** Pagar en la tienda del centro, y más adelante el intercambio (2.000) y hacerse ex (4.000); también **ganar dinero** al vencer a un entrenador | 0,4 s; ganar dinero 0,6 s | Campanita de caja y un tic de monedas. **Debe sonar distinto de E-01 a E-04**: aquí es «tintineo de caja», allí «metal sobre fieltro», para que no se confundan | Caja registradora suave | O → L | P1 |
| E-20 | **Error o acción no permitida.** No hay energía, no quedan Balls, falta una medalla, no hay dinero (hoy la app los muestra como aviso) | 0,25 s | Bajo suave y corto: no regaña | Pitido de «no» de menús de móvil | O (sintetizado) → L | **P0** |
| E-21 | **Pulsar y navegar.** Tocar botones, abrir hojas, moverse entre escenas | 0,1–0,2 s | Clic de madera suave; un «paso» o un roce de hierba al ir a la hierba alta | Menús de juegos de mesa digitales | O (sintetizado) → L | P2 |

**Variantes de tipo para E-08.** Hoy el catálogo solo usa siete tipos: lucha (7 Pokémon), planta (5), oscuridad (3), normal (3), agua (2), fuego (1) y eléctrico (1). Psíquico, dragón y metal existen en el enum pero **ninguna carta los usa**, así que no hace falta sonido para ellos todavía. Orden sugerido: eléctrico (Pikachu, el jefe) y lucha (Brock y sus Pokémon) primero, luego planta, normal, agua, fuego y oscuridad.

## 5. Prioridades

Los niveles:

| Prio | Significado |
|---|---|
| **P0** | Antes del playtest #385. Valen **provisionales** hechos en minutos (sintetizados o grabados), sin pulir. |
| **P1** | Antes de enseñar el tramo a los amigos como juego «de verdad». |
| **P2** | Puede esperar: después de este tramo o cuando haya pantalla o animación a la que ajustarse. |

**Qué hace falta antes del playtest (P0):**

- **Música:** un único tema de combate provisional (M-04, sirve para todos los combates), la victoria (M-09) y la derrota (M-11).
- **Efectos:** moneda (E-01, E-02, E-03, E-04), captura (E-05, E-06, E-07), un ataque genérico (E-08), el daño normal (E-09), debilitado (E-10) y error (E-20).

Con eso el playtest ve y oye los puntos donde pasa algo que decide la partida: el azar de las monedas, el ciclo de captura con Balls que se agotan y el fin de cada combate. El guion de #385 pide anotar si el juego deja claro que no hay Balls en la Ruta 1: E-20 (error) ayuda a que se note. **Sin nada de esto el playtest también vale** para lo que persigue (fallos y balance, #385), tanto la fase 0 con Ayme solo como las siguientes; el sonido no lo bloquea. Si no llega a tiempo, se juega en silencio y se anota.

**Preguntas de audio para anotar en el playtest**, por si se hace con sonido:

1. ¿Se entiende Cara o Cruz sin mirar la pantalla?
2. ¿Cansa oír el mismo tema de combate varias veces seguidas?
3. ¿Algún sonido tapa a otro (música contra moneda, sobre todo)?

**Para después:** todo el P1 (música de escenas, combates de entrenador y jefe, centro, curar, evolución, medalla, comprar, cambiar y cargar, y las variantes de tipo) y el P2.

### Decisiones para Ayme

| # | Pregunta | Mi recomendación |
|---|---|---|
| 1 | ¿De dónde sale la música: la compones tú, la encargas o usamos librerías libres? | Para el P0, sintetizados rápidos y grabaciones propias (la moneda real sobre un tapete es la mejor pieza posible para este juego). Para el P1, composición propia o librerías libres, lo que te resulte más cómodo. Suno es la única herramienta que conoces y has probado (2026-11-25): ver «Suno: solo bocetos y pruebas», más abajo. |
| 2 | ¿Qué material propio tienes ya? ¿Se puede redistribuir? | Si no se puede, se usa en tu equipo pero no se sube (el repositorio es público). Eso necesita que Programación decida cómo cargarlo (§6). |
| 3 | ¿Brock merece un tema propio (M-07)? | No antes de que el resto esté: se reutiliza M-05. |
| 4 | ¿Se admite música o efectos generados con IA? | Sí, para bocetos y para piezas que se suban, con herramientas cuyos términos permitan redistribuir (Treblo, Stable Audio Open) y registrando herramienta, plan y fecha. No subir al repositorio lo hecho con el plan gratuito de Suno (ver «Suno: solo bocetos y pruebas»). Si se aprueba, se añade un código «IA» a los de origen. |
| 5 | ¿Gritos de Pokémon? | Fuera de alcance. No hay fuente propia y la regla 1 de §1 lo impide con los reales. Se puede volver a hablar si se quieren sonidos originales «tipo grito». |

### Suno: solo bocetos y pruebas (decidido el 2026-11-25)

Ayme dice que **Suno es la única herramienta de música que conoce y ha probado**. Hasta nuevo aviso **no se produce ninguna pieza**, y la issue #381 sigue con «Decisión de Ayme» hasta que confirme si tiene material propio redistribuible (pregunta 2).

**Reglas, mientras Suno sea la herramienta:**

1. **Suno sirve solo para bocetos y pruebas en el equipo de Ayme.**
2. **Lo hecho con el plan gratuito no se sube al repositorio público ni se enseña a amigos.** Ni como «provisional». El repositorio es público y subir un archivo es redistribuirlo. Según el centro de ayuda de Suno, en el plan gratuito la propiedad de la canción es de Suno y solo se permite un uso personal que no genere ingresos; la licencia comercial llega con un plan de pago y **no es retroactiva** para lo generado antes de suscribirse.
3. **Lo que se suba solo puede salir de un plan de pago activo,** generado **mientras** ese plan está activo y **tras revisar los términos vigentes de Suno** en ese momento (han cambiado más de una vez, y puede que cuente solo lo descargado desde Suno dentro de la cuota del plan).
4. **Registro de créditos:** cada fila de `CREDITOS-AUDIO.md` anota el **plan que había al generar la pieza** (Gratis, Pro o Premier), la fecha y la revisión de términos, porque de eso depende quién es el dueño.
5. **Prompts:** sin nombres de juegos, personajes ni artistas (regla 2 de §1). Se describe el ambiente, los instrumentos y los BPM de las tablas de §3.

**Qué cambia para las pruebas con amigos (#385):** con música de plan gratuito no se enseña la app. Si hace falta música en esas pruebas, o se juega en silencio (el sonido no bloquea el playtest, §5) o se genera con un plan de pago activo.

**Pendiente de Ayme:** ¿tiene material propio que se pueda redistribuir? (pregunta 2). Si lo tiene, puede cubrir el P0 sin pasar por Suno.

## 6. Entrega de los archivos

Propuesta, a falta de que Programación la acepte:

- **Dónde:** `app/assets/campana/audio/musica/` y `app/assets/campana/audio/efectos/`, separados de los sprites ajenos. Todo lo que haya ahí es original o de licencia libre (regla 3 de §1).
- **Nombres:** `mus_pueblo_loop`, `mus_combate_salvaje_intro`, `mus_combate_salvaje_loop`, `mus_victoria`, `sfx_moneda_cae_1`… Un prefijo, la pieza y, si hay variantes, un número. Sin tildes ni espacios.
- **Formato:** hay que decidirlo al elegir el paquete de audio de la app, porque la app también se compila para web (CI). Mi propuesta: **MP3 o AAC de 128 a 192 kbps** para la música y los efectos, que reproducen todos los navegadores. Ojo con los bucles: algunos formatos con pérdida añaden un hueco al final que se oye al repetir; si pasa, los bucles se exportan en otro formato o se recortan. Los originales sin comprimir (WAV, 48 kHz, 16 bits) se guardan **fuera** del repositorio, por tamaño.
- **Registro de créditos:** un `CREDITOS-AUDIO.md` en la misma carpeta, con una fila por archivo: nombre, origen (O, L o A), autor, licencia y enlace o fecha. Sin esa fila no se sube.

**Lo que pide a Programación** (no se hace aquí, hoy no hay nada de audio en `app/pubspec.yaml`):

- Un paquete de reproducción de audio y su declaración de assets.
- **Navegadores:** suelen bloquear el sonido hasta que el jugador toca la pantalla; la música de la primera escena debería empezar tras ese primer toque.
- Un control de **silencio y de volumen** en la app, y bajar la música un poco mientras suenan los efectos de moneda.
- Reproducir **varios efectos a la vez** (hasta 3 monedas seguidas, más una Ball) y las variantes al azar para que no se repitan.

## 7. Fuera de alcance

Gritos y voces de Pokémon, voces de personajes, doblaje, música del resto de Kanto (Liga, Túnel Roca y siguientes zonas), ambiente de fondo (viento, pájaros) y sonido de la partida libre. Se tratarán cuando haya pantallas y animaciones a las que ajustarse.
