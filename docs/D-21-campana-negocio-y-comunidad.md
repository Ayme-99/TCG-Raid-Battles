# D-21 · Modo campaña: tienda de puntos, Pokédex «Mis cartas» y comunicación

Estado: **PROPUESTA para que Ayme confirme**, actualizada el 2026-11-23 y el 2026-11-24 con sus decisiones. Lo que Ayme ya ha cerrado va marcado como **Decidido** y lo que sigue sin cerrar, como **PROPUESTA**. Es un documento del sector **Negocio y comunidad**; no toca código. Cubre las issues **#387** (tienda), **#388** (Pokédex «Mis cartas») y **#390** (tutorial y comunicación). **#389** (propiedad intelectual) está cerrada y aquí solo se cita (§1.3).

Cómo leerlo:

- Todo lo que lleva la etiqueta **PROPUESTA** no está decidido. Las cifras son un punto de partida razonado, no una decisión.
- Lo ya decidido por Ayme se cita con su origen (D-20, D-10, `flujo-app.md`) y no se discute.
- Cuando Ayme confirme, Diseño traslada lo aprobado al registro de decisiones de D-20 (§5 de este documento dice qué toca).

## 0. Decisiones que se piden a Ayme

| Nº | Decisión | Propuesta | Dónde |
|---|---|---|---|
| 1 | ¿Qué es cada moneda? Puntos (cuenta) frente a dinero (campaña) | Se separan del todo: el dinero compra consumibles dentro de una campaña; los puntos compran colección y cosmética fuera. Ningún objeto se vende por las dos vías. | §1.1 |
| 2 | Los puntos se gastan (D-20) pero D-10 dice que no se gastan | Dos contadores: **puntos ganados** (total histórico, para desbloquear jefes) y **saldo** (lo gastable). | §1.2 |
| 3 | Catálogo de la tienda al lanzar | Solo **monedas y dados** (cosmética). Sobres y cartas sueltas esperan a que existan cartas del formato digital. Las campañas y los jefes **no** se venden. | §2.2 |
| 4 | Precios | Moneda de serie 800, temática 2.000; dados de serie 1.500, temáticos 3.000; sobre 1.000; carta suelta 200 / 400 / 800 / 2.000 según rareza. | §2.3 |
| 5 | **Decidido el 2026-11-24:** los puntos no se usan en la campaña, el intercambio es **gratis**, hacerse ex es la **piedra ex** a **2.000 de dinero**, el dinero por tramo sube (+300 por tramo) y hay 3 piedras de premio. El objetivo es un equipo de 6 ex y más en el PC. | Pendiente: cuántos ex en el PC, qué medallas dan piedra y la lista de excepciones (Pikachu, Eevee). | §2.5 |
| 6 | Qué es «Mis cartas» | **Decidido:** las cartas de campaña solo valen en campaña; la tienda traerá cartas para las partidas rápidas digitales. Dos colecciones, y los jefes de campaña van en «Enemigos». | §3.1 |
| 7 | Qué se registra al capturar | **Decidido:** por ahora solo la carta. Cuenta aunque el Pokémon acabe en el PC y aunque luego evolucione. | §3.3 |
| 8 | Relación con las cartas físicas | Misma imagen y misma numeración, sin escaneo ni canje; reglas de reimpresión y de uso privado. El código de canje queda como idea futura. | §3.5 |
| 9 | Bono de primera captura (opcional) | +50 puntos por carta nueva. Puedes decir que no. | §3.6 |
| 10 | Cómo se presenta el modo campaña al grupo | Tres fases: Ayme solo, 2 o 3 probadores, grupo entero; con el mensaje de §4.3. | §4 |
| 11 | Sesión en la campaña | **Decidido:** la sesión es obligatoria para jugar el modo campaña. Se propone guardar la partida también en la cuenta (§6). | §4.3, §6 |

## 1. Marco común

### 1.1 Qué es cada cosa

El modo campaña maneja **cuatro cifras** que se parecen y que un jugador nuevo va a confundir. Esta tabla es la definición oficial y debe usarse tal cual en la app, en el tutorial y en los mensajes al grupo.

**Decidido por Ayme (2026-11-23)**, con sus palabras:

| Cifra | Definición | Se gana con | Se gasta en | Dónde vive |
|---|---|---|---|---|
| **Energía** | Limita la capacidad de atacar durante un combate | Se recupera sola (+1 por turno; Cargar da +1 más) | Atacar | Solo dentro de un combate |
| **XP** | Cantidad necesaria para evolucionar un Pokémon | Derrotar Pokémon (10, 20 o 30 según categoría) | Evolucionar, fuera de combate | La partida de campaña |
| **Dinero** | Recompensa monetaria al ganar combates contra entrenadores; sirve para comprar objetos | Vencer a entrenadores y líderes | Objetos del centro Pokémon, incluida la piedra ex (§2.5) | La partida de campaña |
| **Puntos** | **No tienen utilidad dentro de la campaña.** Pasan a la cuenta al conseguir medallas o avanzar en la historia, y sirven para comprar cosas en el menú de la app | Combates, medallas y jefes de la campaña; partida libre digital | La tienda de la pantalla de inicio | La **cuenta** |

Una precisión de redacción: la XP **se mide en XP**, nunca en «puntos», aunque se hable de «lo necesario para evolucionar». Si en la app o en los mensajes la XP se llama «puntos», se confunde con los puntos de la cuenta, que es justo lo que este vocabulario quiere evitar.

**PROPUESTA (decisión 1): separación total entre dinero y puntos.**

- El **dinero** es local y se acaba con la campaña. Compra **objetos** (los precios ya decididos: Pokéball 200, Super Ball 600, Ultra Ball 1.200, Poción 300, Repelente 350) y la piedra ex (§2.5). El intercambio es gratis.
- Los **puntos** pertenecen a la cuenta y duran. Compran **colección y cosmética**, y **solo fuera de la campaña**.
- **Nada se vende por las dos vías.** Si los puntos pudieran comprar Pokéballs, el dinero perdería sentido y la campaña se resolvería «pagando». Si el dinero pudiera comprar cosmética, la tienda dejaría de ser un incentivo para jugar las incursiones.
- Esto responde a la pregunta abierta de D-20 §8 (5), «para qué sirve el dinero frente a los puntos».

### 1.2 Dos contadores de puntos

D-10 (§5) dice que «los puntos no se gastan»: el coste de desbloquear un jefe (10.000 a 40.000) se mide sobre el **total acumulado**. D-20 (§5) y `flujo-app.md` (§1 bis) dicen que los puntos **se gastan** en una tienda. Las dos cosas no caben con un solo número.

**PROPUESTA (decisión 2):** cada cuenta lleva dos contadores.

| Contador | Sube | Baja | Para qué sirve |
|---|---|---|---|
| **Puntos ganados** | Con cada abono de puntos | Nunca | Desbloquear jefes de la partida libre (D-10) |
| **Saldo** | Con cada abono de puntos | Con cada compra | Pagar en la tienda |

Así comprar un dado no retrasa el desbloqueo de un jefe, y no hay que elegir entre divertirse y progresar. El abono sigue las reglas de D-10 (solo cobra quien tiene cuenta; la parte de un invitado se pierde).

### 1.3 Reglas de negocio que se mantienen

1. **Nunca dinero real.** Los puntos no se compran, ni la tienda se cobra con euros. Es un proyecto personal de uso privado (#389); cobrar, aunque fuera un euro, lo convertiría en otra cosa.
2. **Propiedad intelectual (#389, cerrada).** Uso privado para Ayme y sus amigos, repositorio público con los sprites de Escarlata y Púrpura incluidos; si GitHub o los titulares piden retirarlos, Ayme los quita. Esto condiciona la tienda: **no se venden sprites ni arte de terceros por separado**, solo arte propio (diseños de moneda y de dados).
3. **Sin transferencias** de puntos entre cuentas ni regalos, para que ningún atajo rompa los costes de desbloqueo.
4. **Compras definitivas**, sin reembolso, con el precio siempre visible antes de pagar.
5. **Probabilidades visibles** en los sobres, aunque sea entre amigos: abrir un sobre no debe parecer una ruleta.

## 2. #387 · La tienda

La tienda está en la **pantalla de inicio** (`flujo-app.md` §1) y exige sesión, porque los puntos viven en la cuenta.

### 2.1 Cuánto entra: referencias para poner precios

Cifras vigentes en el código (`ParametrosCampana`, provisionales): salvaje 100, entrenador 200, jefe 1.000 (solo la primera vez), medalla 1.500. Repetir un salvaje no da puntos.

**Primer tramo de Kanto (Pueblo Paleta → Brock), solo lo obligatorio:**

| Hito | Puntos | Acumulado |
|---|---|---|
| Ruta 1 (un salvaje) | 100 | 100 |
| Ruta 2 sur (un salvaje) | 100 | 200 |
| Dos Cazabichos | 400 | 600 |
| Jefe Pikachu | 1.000 | 1.600 |
| Entrenador Joven | 200 | 1.800 |
| Brock (medalla Roca) | 1.500 | **3.300** |

Con los dos desvíos opcionales (Ruta 22 y Ruta 2 norte) son **3.500**.

**Kanto completo** (extrapolación mía, a medir cuando haya más tramos): 8 medallas (12.000) y unos 16 jefes de tramo y de ruta (16.000), más los combates de ruta. Sale en el orden de **30.000 a 40.000 puntos**, sin contar la Liga.

**Partida libre digital** (D-10 §4): en un grupo de 4, un jugador cobra de media unos **600 a 1.100 puntos por partida** (el 25 % del equipo, que reparte 2.380 a 4.449 según el nivel).

Regla práctica que he usado: **un jugador debe poder comprar algo cada una o dos partidas**, y lo grande, cada pocas sesiones.

### 2.2 Catálogo

**PROPUESTA (decisión 3).** Cinco familias de producto. Las dos primeras pueden salir ya; las otras dependen de que Ayme cree las cartas del formato digital, que **todavía no existen** (`flujo-app.md` §8).

| Familia | Qué es | Disponible | Notas |
|---|---|---|---|
| **Monedas** | Diseños de moneda para las tiradas en mesa (D-18: `DisenoMoneda.deImagenes`, dos imágenes cuadradas más el canto) | **Al lanzar** | La moneda clásica es gratis y no se pierde |
| **Dados** | Juegos de dados 3D: tetraedro d4 (slot) y cubo d6 (categoría) con el mismo estilo | **Al lanzar** | Se compran en pareja; el estándar es gratis |
| **Sobres** | Sobre de cartas del formato digital | Cuando haya cartas digitales | Ver §2.4 |
| **Cartas sueltas** | Una carta concreta del formato digital | Cuando haya cartas digitales | Para completar huecos |
| **Campañas** | — | **No se venden** | Ver abajo |

Lo que **no** entra en la tienda, y por qué:

- **Campañas nuevas.** Ayme apuntó que «lo normal es que estén abiertas de primeras» (D-20 §5). **Recomiendo** abrir la siguiente al terminar la anterior, no pagarla: una campaña es contenido que el jugador espera tener, no un extra.
- **Jefes de la partida libre.** Se siguen desbloqueando con los **puntos ganados** (D-10), nunca con saldo.
- **Consumibles de campaña** (Pokéballs, Pociones, Repelentes): son del dinero (§1.1).
- **Sprites, medallas y cualquier arte ajeno** (§1.3).

### 2.3 Precios

**PROPUESTA (decisión 4).**

| Producto | Precio (puntos) | Lo que equivale a |
|---|---|---|
| Moneda clásica | 0 | Siempre disponible |
| Moneda de serie (color o metal) | **800** | Una partida libre (600 a 1.100) |
| Moneda temática (Onix, Manectric, Kingdra, Arceus, o un mapa) | **2.000** | Dos partidas libres |
| Dados estándar | 0 | Siempre disponibles |
| Juego de dados de serie | **1.500** | Casi la mitad de un primer tramo |
| Juego de dados temático | **3.000** | Un primer tramo completo |
| Sobre del formato digital | **1.000** | Una o dos partidas libres |
| Carta suelta: Común | **200** | |
| Carta suelta: Poco común | **400** | |
| Carta suelta: Rara | **800** | |
| Carta suelta: Ultra rara | **2.000** | |

**Por qué estas cifras:**

- Lo **barato** (800) se alcanza con una partida: la primera compra llega pronto y engancha.
- Lo **temático** (2.000 a 3.000) es el objetivo de varias partidas, y se nota que es especial.
- Al terminar el primer tramo (3.300) el jugador puede comprarse **tres sobres**, o **una moneda de serie y un juego de dados**. Tras el jefe Pikachu (1.600 acumulados) ya le llega para algo, de modo que la tienda se ve útil **antes de Brock**.
- Con la campaña completa (30.000 a 40.000) se llena una tienda sin vaciarla: nadie compra todo de golpe.
- Las cartas sueltas valen en total **más** que los sobres: ver §2.4.

Todas las cifras son **ajustables sin tocar la tienda**: viven en un catálogo de datos (§5).

### 2.4 Sobres

**PROPUESTA** (dependiente de que existan las cartas digitales):

- **5 cartas por sobre**: 3 Comunes, 1 Poco común y 1 ranura especial (Poco común 60 %, Rara 33 %, Ultra rara 7 %).
- Valor medio del contenido a precios de carta suelta: unos **1.640** puntos, frente a los 1.000 del sobre. Es decir, el sobre es la forma barata de coleccionar y la carta suelta es el **atajo caro** para completar lo que falta. Así los dos productos tienen sentido.
- Las rarezas son las del proyecto (Común, Poco común, Rara, Ultra rara). Los jefes se quedan fuera de los sobres.
- **Duplicados:** decisión abierta, sin propuesta firme. La opción más simple es que se queden en la colección (no hacen falta copias en el juego). Si Ayme quiere un incentivo, se pueden devolver como puntos (por ejemplo, un 25 % del precio de la carta suelta), pero eso crea un bucle de puntos que habría que simular.

### 2.5 Qué se paga dentro de la campaña: la piedra ex

**Decidido por Ayme:**

- **Los puntos no tienen utilidad dentro de la campaña** (2026-11-23). La tienda de puntos vive solo en el menú de la app.
- **El intercambio es gratis** (2026-11-24).
- **Hacerse ex es un objeto, la «piedra ex»** (2026-11-24). Ejemplo: Venusaur + piedra ex = Venusaur ex. La carta ex aplica **cuando el Pokémon ya no puede evolucionar más**. Excepciones por fandom: **Pikachu y Eevee** también pueden ser ex. Las cartas las crea Ayme a mano, así que no es un cuello de botella.
- **Objetivo de diseño: terminar la campaña con un equipo de 6 ex** y, además, más ex en el PC para tener un equipo polivalente. Al final los rivales serán cada vez más fuertes, así que las cartas de **más de 200 PS** son el objetivo.
- **Precio de la piedra ex: 2.000 de dinero** (propuesta de Negocio aceptada por Ayme el 2026-11-24).
- Ayme acepta también las dos medidas siguientes: el dinero por tramo sube hacia el final, y algunas piedras se dan de premio.

Esto sustituye a mi primera propuesta (intercambio 2.000 y hacerse ex 4.000) y a la recomendación de 4.000, que servía para un equipo con 1 o 2 ex y no para este objetivo.

**Qué falta, y es de Diseño:** la lista exacta de excepciones como Pikachu y Eevee (y cómo conviven con Raichu, que sería una carta ex por evolución) y si Pokémon de 3 fases como Venusaur necesitan la piedra para pasar a ex (lo que dice el ejemplo de Ayme). El cálculo de abajo supone que **sí**.

#### Por qué 2.000 con este objetivo

Un equipo de 6 ex más unos 4 ex en el PC (el 4 es una **suposición mía**, falta que Ayme diga cuántos) son **unas 10 piedras**. A 2.000, son 20.000 de dinero en piedras, más el gasto en Pokéballs y Pociones (supongo 1.000 a 1.500 por tramo, 8.000 a 12.000 en total, sin medir). Hace falta una campaña de **28.000 a 32.000** de dinero. Con ~2.060 por tramo (D-20 §10.6) salen solo unos 17.500, y de ahí solo unas 3 o 4 piedras.

Referencias: Ultra Ball 1.200 (con 5 medallas), piedra de evolución de los juegos ~2.100, Onix ex 240 PS frente a 110. A 3.000 o 4.000 el objetivo exigiría ×2,3 a ×3 el dinero actual por tramo, así que **2.000** es el precio que permite el objetivo.

#### Cómo se llega: dinero creciente y piedras de premio

Las dos medidas actúan a la vez.

**1. El dinero por tramo sube hacia el final** (Diseño fija la cifra de cada clase y de cada líder en el catálogo). Propongo **+300 por tramo**:

| Tramo | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Dinero ganado | 2.060 | 2.360 | 2.660 | 2.960 | 3.260 | 3.560 | 3.860 | 4.160 |

Suman **24.880** más 1.000 de salida. El tramo 1 es el que ya está en el catálogo. Es una guía, no una decisión: los tramos intermedios dependen de los entrenadores que Diseño ponga en cada uno.

**2. Tres piedras de premio** (gratis), por ejemplo con las medallas **4, 6 y 8**: una a mitad de campaña y otra al final, para que el equipo completo se note como un hito. Cada una ahorra 2.000.

**La cuenta cuadra:**

| Concepto | Valor |
|---|---|
| Piedras de premio | 3 |
| Piedras compradas | 7 (14.000) |
| Total de ex posibles | **10 (6 en el equipo y 4 en el PC)** |
| Gasto en Balls y Pociones | 8.000 a 12.000 |
| Dinero necesario | 22.000 a 26.000 |
| Dinero con la curva | 25.880 |

**El ritmo no se rompe.** A la 3.ª medalla, que es la mínima de Onix ex según Ayme, el dinero acumulado es de ~8.080. Restando 3.000 a 4.500 de consumibles, quedan de 3.600 a 5.100, es decir, **1 o 2 piedras**. Los ex siguen llegando poco a poco, y las medallas mínimas de cada Pokémon marcan el ritmo.

**Dónde se vende:** en la tienda del centro Pokémon, como la Super Ball y la Ultra Ball: aparece cuando se tienen las medallas mínimas del primer Pokémon que puede usarla. **Una piedra, un ex.**

#### Qué se espera medir (Calidad)

- Cuánto dinero lleva un jugador al llegar a cada piedra, con la curva propuesta. Todo parte de la suposición de ~2.060 por tramo y de mi estimación de gasto, **sin medir**.
- Con 6 ex de más de 200 PS como punto de partida, la **Liga** (objetivo del 25 %, D-20 §10.7) se calibra con ese poder, no con el de un equipo normal.
- Si con 10 ex posibles el equipo sale **demasiado fuerte**, la palanca es el dinero por tramo y el número de piedras de premio, no el precio.

**Qué implica para el trabajo de otros** (sin tocarlo aquí): el campo `puntos` del catálogo y del motor deja de tener sentido (el intercambio es gratis y hacerse ex es un objeto); lo recoge la tarea 17 (#447) de D-20. El objeto necesita su precio (2.000) y su medalla mínima.

## 3. #388 · Pokédex «Mis cartas»

### 3.1 Qué es y qué muestra

La Pokédex tiene dos categorías (`flujo-app.md` §6): **Enemigos** (existe) y **Mis cartas** (no existe). Hay tres documentos que dicen cosas distintas de «Mis cartas», y conviene ordenarlos:

- `flujo-app.md` §6: son las cartas **del formato digital** conseguidas en la tienda.
- D-20 §1: las cartas de campaña **no se usan** en la partida libre.
- El texto de la issue #388: «las cartas conseguidas en la campaña».

**Decidido por Ayme (2026-11-23):** las cartas conseguidas en la campaña se usan **solo en la campaña**, y en el futuro habrá cartas en la tienda del menú para las partidas rápidas en formato digital. Eso da razón a las tres lecturas a la vez, y deja «Mis cartas» así (la estructura concreta es **PROPUESTA**, decisión 6): **dos colecciones**, con un selector arriba.

| Colección | Qué contiene | Cómo se consigue | Se usa en |
|---|---|---|---|
| **Campaña** | Los Pokémon de la serie 001/150 (Mew, 151/150) | Capturando y evolucionando en la campaña | Solo la campaña |
| **Formato digital** | Las cartas que se usarán en la partida libre digital | Tienda (sobres y cartas sueltas) | Partida libre digital |

Así ni se mezclan las cartas que no valen en la partida libre con las que sí, ni se pierde la intención de la issue. La colección **Formato digital** queda oculta hasta que existan esas cartas: hoy solo se ve **Campaña**.

**Los jefes de campaña (serie NN/20) van en «Enemigos»**, no en «Mis cartas»: son rivales. Se les aplica la regla que ya tiene Enemigos (**gris** = enfrentado, **color** = derrotado, **silueta** = nunca visto). Al capturar a un jefe se obtiene la **carta normal** del Pokémon (Pikachu 025/150), que sí va a «Mis cartas».

### 3.2 Estados de una carta

Como el registro es **solo la carta** (§3.3), hay dos estados, y no tres como en Enemigos.

| Estado | Cuándo | Cómo se ve |
|---|---|---|
| **Silueta** | Aún no la tiene | Silueta con su número |
| **Conseguida** | La ha capturado, ha evolucionado hasta ella o la ha elegido como inicial | Carta a todo color |

El estado «vista» (gris), que sí existe en Enemigos, **no entra**: exigiría registrar los combates, y Ayme ha pedido registrar solo la carta. Se puede añadir más adelante sin migrar nada, porque lo que ya se guarda no cambia.

- La carta es **siempre la imagen exportada de PokeCardMaker** (decisión de arte de Ayme, `campana-arte-interfaz.md`): la app no dibuja marcos.
- Solo aparecen huecos de las cartas que **ya existen en el catálogo** (hoy 22). Enseñar 150 siluetas de cartas que no existen sería ruido. Un contador dice «Conseguidas 14 de 22» y, aparte, «nuevas cartas con cada actualización».
- Se ordena por **número de la Pokédex**, que coincide con el impreso (§3.5).
- **Detalle al pulsar:** la carta grande y su línea de evolución con el estado de cada paso, que sale del catálogo y de las cartas conseguidas, sin guardar nada más.

### 3.3 Qué se registra al capturar

**Decidido por Ayme (2026-11-23): por el momento, solo la carta.** El resto de reglas de esta sección las ha dado por buenas.

Dato guardado: **el `idCarta`** de cada carta conseguida. Nada más (ni fecha, ni zona, ni Ball, ni número de capturas).

Reglas de cuándo se registra:

1. **Al acertar la Ball**, antes de elegir hueco: da igual que el Pokémon acabe en el equipo o en el PC. Con el equipo lleno nada se pierde (D-20 §2), así que el registro tampoco.
2. **Aunque la carta se sustituya al evolucionar.** La evolución sustituye a la carta anterior (D-20 §2.1), pero la anterior **sigue conseguida** y la nueva queda **conseguida** también. «Mis cartas» es el historial de lo que se ha tenido, no del equipo actual.
3. **El inicial cuenta** como conseguido al elegirlo.
4. **Un jefe capturado** registra la **carta normal**, no la del jefe (D-20 §4, Jefes).
5. **Una carta ex** es una entrada propia (D-20 §2.1): Raichu ex no es Raichu. Ojo: la Pokédex de **Enemigos** usa `idCarta`, que unifica «Kingdra ex» y «Kingdra»; en «Mis cartas» **no** debe hacerse, o una carta ex quedaría conseguida sin tenerla.
6. **Capturar otra vez** una carta que ya se tiene no cambia nada.

**La colección es de la cuenta, no de la partida.** Una campaña nueva empieza con el equipo vacío, pero «Mis cartas» conserva todo. Se guarda en el dispositivo y se sincroniza al iniciar sesión, igual que la Pokédex de Enemigos (`flujo-app.md` §6). Como la sesión es obligatoria en la campaña (§4.3), la sincronización siempre puede ocurrir.

### 3.4 Qué no hace

- **No se registran cartas físicas oficiales** de Pokémon TCG (las que se usan en la partida libre física): no hay escaneo ni reconocimiento.
- **La colección Campaña no se compra**: solo se llena jugando.
- **No hay colecciones ajenas:** no se ven las cartas de otros jugadores hasta que existan amigos (`flujo-app.md` §7).

### 3.5 Relación con las cartas físicas

Ayme crea las cartas en PokeCardMaker y las imprime: las 22 actuales (serie 001/150) y la serie de jefes NN/20 ya están impresas. La carta física y la digital son **la misma carta**, y esto es lo que eso significa en la práctica.

**PROPUESTA (decisión 8), en cinco reglas:**

**1. La imagen manda y es la misma.** La carta de «Mis cartas» es la imagen exportada de PokeCardMaker (`app/assets/campana/cartas/<id>.webp`, 480×670), exactamente la que se imprime. Los datos del juego (`catalog/campana/pokemon/<id>.json`) salen de esa imagen (D-20 §11). Si la imagen y el JSON no coinciden, **se corrige el JSON**, no la carta, como ya se hizo con Cubone, Zubat y Slowpoke.

**2. Una reimpresión actualiza la digital en la misma entrega.** Pasó con Mankey (texto de la habilidad) y con Machop. Regla: cuando una carta se reimprime, la imagen del repositorio se cambia **en el mismo PR** que su JSON, y la impresa antigua queda **obsoleta**: ya no es la carta del juego. Así nunca hay dos versiones vivas a la vez. Para el grupo, basta con que Ayme avise «la carta de X se ha reimpreso» y se tire la vieja.

**3. La numeración es la de la Pokédex.** El número impreso (NNN/150) coincide con el número de la Pokédex de cada Pokémon (Nidoran♀ 029/150 y Nidoran♂ 032/150, ya corregido), y los jefes llevan su propia serie NN/20. En «Mis cartas» se enseña el número impreso y se ordena por él; no hay dos números. Mew será 151/150.

**4. Tener la carta física no da nada en la app, ni al revés.** No hay vínculo técnico, ni escaneo, ni reconocimiento. Cada jugador consigue su carta digital **jugando la campaña**. Regalar o cambiar una carta impresa entre amigos es cosa de la mesa y no mueve nada en la colección digital.

**5. Uso privado (#389).** Las impresiones son para el grupo. No se venden, ni se envían fuera de él, ni se publican las imágenes. Es una recomendación coherente con la decisión de Ayme, no una regla nueva.

**Idea futura, sin decidir: código de canje.** Un código impreso en la carta física que desbloquee su copia digital (por ejemplo, para regalar una carta). **No se hace ahora** porque:

- Exige servidor, control de usos (un código solo vale una vez) y un modelo de cuenta que hoy no existe.
- Choca con la regla de que la colección **Campaña** solo se llena jugando: el código sería un atajo.
- La colección **Formato digital**, que sí se compra, todavía no existe.

Condiciones para retomarla: que esté el formato digital y la tienda, y que Ayme quiera una forma de regalar cartas entre amigos. Una versión más ligera, sin riesgo, sería un **QR informativo** que lleve al detalle de la carta (sin desbloquear nada).

### 3.6 Bono de primera captura (opcional)

**PROPUESTA opcional (decisión 9):** +**50 puntos** la primera vez que se consigue una carta nueva. Con las 22 cartas actuales son 1.100 puntos de una sola vez. Motivo: capturar es opcional y cuesta Pokéballs, es decir, dinero; un pequeño premio alinea el incentivo con completar la colección. Riesgo: más puntos entran sin jugar combates, y las cifras de §2.5 pesan más. Mi recomendación es **no incluirlo al lanzar** y revisarlo con datos reales de uso.

## 4. #390 · Tutorial y comunicación

### 4.1 A quién y para qué

El público son **Ayme y su grupo de amigos**, que ya conocen las incursiones. No hay lanzamiento público (#389). El objetivo de la comunicación es que cada amigo:

1. Entienda en una frase qué es el modo campaña y en qué se diferencia de la partida libre.
2. Juegue su primer combate sin explicaciones aparte.
3. Sepa qué son los **puntos** y, sobre todo, no los confunda con el **dinero**.
4. Dé opinión útil.

### 4.2 Vocabulario único

Se usan siempre las mismas palabras (las de §1.1): **energía**, **XP**, **dinero**, **puntos**. «Cargar» (no «pasar»), «Centro Pokémon», «PC», «Ball». Los mensajes al grupo, el tutorial y la tienda no pueden llamar «monedas» al dinero ni «créditos» a los puntos.

### 4.3 Cómo presentar el modo campaña

**Tres ideas** (en este orden):

1. **Es el Pokémon de siempre, pero en cartas, y se juega solo.** Eliges un inicial, recorres Kanto, capturas y ganas la medalla de Brock. No hace falta mesa, ni cartas físicas, ni amigos.
2. **Es una versión de prueba.** Hoy llega de Pueblo Paleta a Brock. El resto de Kanto llega con actualizaciones.
3. **Lo que ganas sirve fuera.** Los puntos van a tu cuenta y se gastan en la tienda (cuando abra) y suman para desbloquear jefes de las incursiones.

**Lo que no se promete**: la tienda (aún no existe), la Liga, las cartas del formato digital, el tiempo que dura el primer tramo (sin medir hasta el primer playtest), ni que se pueda jugar sin cuenta (la campaña exige sesión).

**Riesgos que hay que decir de entrada** (mejor sin sorpresas):

- **La partida se guarda en el dispositivo**, no en la cuenta. Si el amigo juega en la **web** y borra los datos del navegador, **pierde el progreso**. Hasta que haya sincronización, hay que avisarlo.
- **La sesión es obligatoria** para jugar la campaña (**decidido por Ayme el 2026-11-23**). En la app solo se inicia sesión y el registro se hace en Deck Tracker, así que el amigo **debe tener ya su cuenta antes de empezar**. Es la mayor fricción de la primera sesión: conviene que se la cree antes de que le llegue el enlace.
- **No es un proyecto público.** Los sprites son de Nintendo y The Pokémon Company, tomados de Escarlata y Púrpura (#389): el enlace es para el grupo y no se reenvía ni se publica.

**Borrador del mensaje al grupo** (tono de grupo de WhatsApp, para que Ayme lo adapte):

> Ya se puede probar el **modo campaña** de Incursiones 🎮
> Es como un Pokémon de cartas para jugar **solo**: eliges inicial en Pueblo Paleta, recorres Kanto, capturas y llegas hasta la medalla de Brock. De momento solo ese tramo; el resto irá llegando.
> Lo que ganas se guarda como **puntos** en tu cuenta: servirán para la tienda y para desbloquear jefes de las incursiones.
> Ojo: es versión de prueba. Para jugar necesitas tu cuenta de Deck Tracker (créala antes), y la partida se guarda **en tu dispositivo** (si juegas en la web y borras datos del navegador, la pierdes).
> Enlace: [enlace]. Es solo para nosotros, no lo paséis fuera 🙏
> Decidme dónde os atascáis o qué no se entiende. Eso es lo más útil.

### 4.4 Plan en tres fases

| Fase | Quién | Qué se hace | Se pasa a la siguiente cuando |
|---|---|---|---|
| **0. Ayme solo** | Ayme | Juega el tramo entero y mide cuánto dura | El tramo se completa sin bloqueos y se conoce la duración |
| **1. Probadores** | 2 o 3 amigos cercanos | Una sesión cada uno, con Ayme mirando sin ayudar y apuntando en `docs/playtests/PLANTILLA.md` | Nadie se queda parado más de un minuto sin saber qué hacer |
| **2. Grupo entero** | Todos | Mensaje de §4.3 y un único canal para opiniones | — |

**Qué observar en la fase 1** (cinco preguntas, no un cuestionario):

1. ¿Toca el Pokémon sin que se lo digan?
2. ¿Entiende Cargar y cuándo usarlo?
3. ¿Entiende por qué no puede capturar en la Ruta 1?
4. Al acabar, ¿sabe decir qué son los puntos, el dinero y la XP?
5. ¿Qué es lo primero que pregunta?

### 4.5 El primer combate

El primer combate es en la **Ruta 1** (un Pidgey o un Rattata salvajes). Hay un dato clave: **la mochila de salida no lleva Pokéballs** (D-20 §10.9), de modo que **la primera victoria no ofrece captura**, y el jugador puede creer que capturar no existe.

**Principio:** se enseña **jugando**, una cosa a la vez y justo cuando hace falta. En el primer combate solo se explican **cuatro cosas**; el resto espera a su momento. Los destellos y la colocación los decide Diseño y los pinta Arte; aquí van los **mensajes**.

| Momento | Qué se enseña | Texto propuesto (una línea) |
|---|---|---|
| Al empezar | Tocar a tu Pokémon | «Toca a tu Pokémon para elegir qué hace.» |
| Al elegir el primer ataque | La energía | «Atacar gasta energía. Empiezas con 10 y recuperas 1 al acabar tu turno.» |
| En el segundo turno | Una acción por turno | «Cada turno haces una sola cosa: atacar, cambiar de Pokémon o Cargar.» |
| Cuando la energía no llega a un ataque (o al tercer turno) | Cargar | «Cargar no ataca, pero te da 1 energía extra.» |
| Al ganar | Qué has conseguido | «Has ganado puntos y XP. La XP sirve para evolucionar.» |
| Al ganar, sin Pokéballs | Por qué no hay captura | «No tienes Pokéballs. Cómpralas en el Centro Pokémon de Ciudad Verde; puedes volver aquí a capturar.» |

**Qué no se explica en el primer combate:** efectos y veneno, debilidades, evolución, la tienda, el PC y los puntos de cuenta. Si se mete todo, el jugador no retiene nada.

**Calendario de lo demás** (cuándo aparece cada concepto, siguiendo el recorrido de Kanto):

| Dónde | Qué se explica |
|---|---|
| Ciudad Verde (Centro Pokémon) | Curar es gratis; la tienda y las Pokéballs; el PC |
| Ruta 2 sur | Capturar: «Cada intento gasta una Pokéball, salga bien o mal» |
| Bosque Verde (Cazabichos) | El veneno y que los efectos quedan sobre el rival |
| Conversación antes de Pikachu | La **debilidad** (×2) y el aviso de que el jefe llama a un aliado |
| Pikachu | Cambiar de Pokémon cuesta el turno; el aliado del jefe |
| Menú del equipo | La XP y la evolución (solo cuando hay XP suficiente) |
| Pantalla de inicio | Los puntos y la tienda (solo cuando la tienda exista) |

El tutorial enlaza con la issue **#264** (tutorial «cuando la base del juego esté terminada») y con la decisión de Ayme de que el primer toque de los combates de la Ruta 1 y de Pikachu vaya señalado con un destello (D-20 §10.7, pantalla de combate).

### 4.6 Qué no hay que escribir todavía

- Nada sobre la **Liga** ni sobre campañas nuevas: no están diseñadas.
- Nada sobre **sobres** hasta que existan cartas digitales.
- Nada de **precios** de la tienda hasta que Ayme confirme §2.3.

## 5. Qué cambia en otros documentos y qué necesita cada sector

**Si Ayme confirma, Diseño traslada** (no se ha tocado D-20 en este cambio, para no pisar su trabajo):

| Documento | Cambio |
|---|---|
| D-20 §5 y §8 (4, 5) | Cerrar «qué se vende» y «dinero frente a puntos» con §1.1 y §2 |
| D-20 §2.1, §5 y §10.6 | Los puntos **no** se usan en la campaña (decidido). Intercambio **gratis** y hacerse ex con la **piedra ex** (decidido el 2026-11-24, ya recogido en el PR #448 de Diseño). Precio de la piedra: 2.000 (aceptado). Dinero por tramo creciente y 3 piedras de premio (§2.5) |
| D-20 §8 (13) | Nidoran♂ ya es 032/150: la pregunta se da por resuelta |
| D-20 §6 y `flujo-app.md` §2 | La sesión es obligatoria en el modo campaña (la regla general «nunca obligatoria» deja de valer ahí) |
| D-20 §10 | Nuevas filas del registro con las decisiones 1 a 9 |
| D-10 §5 | Añadir el contador de **saldo** junto al de puntos ganados |
| `flujo-app.md` §6 | Definir las dos colecciones de «Mis cartas» y su relación con Enemigos |
| `docs/README.md` | Ya enlaza este documento |

**Para Programación** («Puntos al servidor y tienda», que #387 bloquea), en datos y sin escribir código aquí:

- El servidor guarda **puntos ganados** y **saldo** por cuenta, y un registro de compras (`compras`: cuenta, producto, precio, fecha) con clave generada por el cliente para que los reintentos no cobren dos veces, como en D-10.
- El catálogo de la tienda debe ser **datos** (`id`, familia, nombre, precio, requisitos), no constantes, para ajustar precios sin publicar app.
- «Mis cartas» necesita un registro por carta (§3.3), con clave en el dispositivo y sincronización al iniciar sesión.
- El servidor acepta lo que reporta el cliente con tope por hito (D-20 §6); los topes son los valores de §2.1.

**Para Diseño y Calidad:** la curva de dinero por tramo, las medallas que dan piedra de premio y el alcance de la piedra (Pikachu, Eevee, Venusaur), y la simulación del dinero al llegar a cada piedra (§2.5); decidir los duplicados de sobre (§2.4); el momento exacto de cada texto de §4.5.

**Para Arte:** diseños de moneda y de dados (la clásica y la estándar ya existen); el estado «gris» de «Mis cartas» (el criterio visual de Enemigos ya existe); la pantalla de la tienda.

**Para Calidad y soporte:** fase 0 y fase 1 de §4.4, y medir la duración del primer tramo.

## 6. Preguntas abiertas

Resueltas el 2026-11-23: la sesión es obligatoria en la campaña, las cartas de campaña valen solo en campaña, solo se registra la carta, los puntos no se usan dentro de la campaña, y la carta de Nidoran♂ ya es la 032/150.

1. **¿Se guarda la partida de campaña también en la cuenta?** Como ya hay sesión obligatoria, sería natural y quitaría el riesgo de perder el progreso al borrar los datos del navegador (§4.3). Hoy se guarda solo en el dispositivo. Es una decisión de Diseño y Programación; yo propongo hacerlo.
2. **Tamaño del sobre y composición** (§2.4): son números míos.
3. **Rarezas de las cartas del formato digital:** se han usado las del proyecto (Común a Ultra rara) y pueden no ser las definitivas.
4. **Duplicados de sobre** (§2.4).

## 7. Fuentes

Documentos del repositorio: `docs/D-20-modo-campana.md` (§1, §2.1, §4, §5, §8, §10), `docs/D-10-sistema-de-puntos.md` (§1, §4, §5), `docs/diseno-ui/flujo-app.md` (§1 bis, §6, §8), `docs/diseno-ui/campana-arte-interfaz.md`, `docs/D-18-monedas.md`, `balance/informes/campana_calibrar_2026-11-22.md` y el código de `engine/lib/src/campana/partida.dart` (cifras de puntos, dinero y precios).
