# D-21 · Modo campaña: tienda de puntos, Pokédex «Mis cartas» y comunicación

Estado: **PROPUESTA para que Ayme confirme** (2026-11-23). Es un documento del sector **Negocio y comunidad**; no toca código. Cubre las issues **#387** (tienda), **#388** (Pokédex «Mis cartas») y **#390** (tutorial y comunicación). **#389** (propiedad intelectual) está cerrada y aquí solo se cita (§1.3).

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
| 5 | Qué cuesta dentro de la campaña pagar con puntos | Intercambio 500 y hacerse ex 1.500. | §2.5 |
| 6 | Qué es «Mis cartas» | Dos colecciones: **Campaña** (capturas) y **Formato digital** (tienda). Los jefes de campaña van en «Enemigos». | §3.1 |
| 7 | Qué se registra al capturar | La carta, la fecha, la zona y la Ball; cuenta aunque el Pokémon acabe en el PC y aunque luego evolucione. | §3.3 |
| 8 | Relación con las cartas físicas | Misma imagen y misma numeración, sin escaneo ni canje. Un código de canje queda como idea futura, no se decide ahora. | §3.5 |
| 9 | Bono de primera captura (opcional) | +50 puntos por carta nueva. Puedes decir que no. | §3.6 |
| 10 | Cómo se presenta el modo campaña al grupo | Tres fases: Ayme solo, 2 o 3 probadores, grupo entero; con el mensaje de §4.3. | §4 |

## 1. Marco común

### 1.1 Qué es cada cosa

El modo campaña maneja **cuatro cifras** que se parecen y que un jugador nuevo va a confundir. Esta tabla es la definición oficial y debe usarse tal cual en la app, en el tutorial y en los mensajes al grupo.

| Cifra | Qué es | Se gana con | Se gasta en | Dónde vive |
|---|---|---|---|---|
| **Energía** | Fichas del combate, de 0 a 10 | Se recupera sola (+1 por turno; Cargar da +1 más) | Atacar | Solo dentro de un combate |
| **XP** | Reserva común para evolucionar | Derrotar Pokémon (10, 20 o 30 según categoría) | Evolucionar, fuera de combate | La partida de campaña |
| **Dinero** | La «cartera» de la campaña | Vencer a entrenadores y líderes | Pokéballs, Pociones, Repelentes (centro Pokémon) | La partida de campaña |
| **Puntos** | La moneda del juego, compartida con las incursiones | Combates, medallas y jefes de la campaña; partida libre digital | La tienda de la pantalla de inicio; intercambio y ex dentro de la campaña (§2.5) | La **cuenta** |

**PROPUESTA (decisión 1): separación total entre dinero y puntos.**

- El **dinero** es local y se acaba con la campaña. Compra **consumibles** (los precios ya decididos: Pokéball 200, Super Ball 600, Ultra Ball 1.200, Poción 300, Repelente 350).
- Los **puntos** pertenecen a la cuenta y duran. Compran **colección y cosmética**.
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

### 2.5 Pagar con puntos dentro de la campaña

D-20 §10.6 deja **solo dos usos** de los puntos dentro de la campaña: la evolución por **intercambio** (Kadabra, Haunter, Machoke, Graveler) y **hacerse ex** un Pokémon que no evoluciona (Onix). La XP no los usa.

**PROPUESTA (decisión 5):** intercambio **500** puntos, hacerse ex **1.500** puntos.

Aviso importante: Ayme escribió que «cuántos puntos da cada cosa es irrelevante salvo que haya compras con puntos dentro de la campaña». **Estas dos compras hacen que sí importe**, así que las cifras de abono (100, 200, 1.000, 1.500) dejan de ser provisionales a la ligera. Antes de cerrarlas, Calidad debería simular cuántos puntos tiene un jugador cuando llega a su primer intercambio o a su primer ex. Mientras no haya cartas evolucionadas ni ex en el catálogo, nada de esto es urgente.

## 3. #388 · Pokédex «Mis cartas»

### 3.1 Qué es y qué muestra

La Pokédex tiene dos categorías (`flujo-app.md` §6): **Enemigos** (existe) y **Mis cartas** (no existe). Hay tres documentos que dicen cosas distintas de «Mis cartas», y conviene ordenarlos:

- `flujo-app.md` §6: son las cartas **del formato digital** conseguidas en la tienda.
- D-20 §1: las cartas de campaña **no se usan** en la partida libre.
- El texto de la issue #388: «las cartas conseguidas en la campaña».

**PROPUESTA (decisión 6):** «Mis cartas» tiene **dos colecciones**, con un selector arriba.

| Colección | Qué contiene | Cómo se consigue | Se usa en |
|---|---|---|---|
| **Campaña** | Los Pokémon de la serie 001/150 (Mew, 151/150) | Capturando y evolucionando en la campaña | Solo la campaña |
| **Formato digital** | Las cartas que se usarán en la partida libre digital | Tienda (sobres y cartas sueltas) | Partida libre digital |

Así ni se mezclan las cartas que no valen en la partida libre con las que sí, ni se pierde la intención de la issue. La colección **Formato digital** queda vacía y oculta hasta que existan esas cartas.

**Los jefes de campaña (serie NN/20) van en «Enemigos»**, no en «Mis cartas»: son rivales. Se les aplica la regla que ya tiene Enemigos (**gris** = enfrentado, **color** = derrotado, **silueta** = nunca visto). Al capturar a un jefe se obtiene la **carta normal** del Pokémon (Pikachu 025/150), que sí va a «Mis cartas».

### 3.2 Estados de una carta

Misma idea que Enemigos, para que el jugador no aprenda dos lenguajes.

| Estado | Cuándo | Cómo se ve |
|---|---|---|
| **Silueta** | Nunca la ha visto | Silueta con su número |
| **Vista** | Ha empezado un combate contra ese Pokémon, o lo ha visto en una evolución, pero no la tiene | Carta en gris |
| **Conseguida** | La ha capturado, ha evolucionado hasta ella o la ha elegido como inicial | Carta a todo color |

- La carta es **siempre la imagen exportada de PokeCardMaker** (decisión de arte de Ayme, `campana-arte-interfaz.md`): la app no dibuja marcos.
- Solo aparecen huecos de las cartas que **ya existen en el catálogo** (hoy 22). Enseñar 150 siluetas de cartas que no existen sería ruido. Un contador dice «Conseguidas 14 de 22» y, aparte, «nuevas cartas con cada actualización».
- Se ordena por **número de la Pokédex**, no por el número impreso (D-20 §11).
- **Detalle al pulsar:** la carta grande, fecha y sitio de la primera captura, cuántas veces la ha capturado, su línea de evolución con el estado de cada paso y en qué zonas aparece (la zona solo se enseña cuando la carta ya está **vista**, para no fastidiar el descubrimiento).

### 3.3 Qué se registra al capturar

**PROPUESTA (decisión 7).** Por cada carta, se guarda:

| Dato | Para qué |
|---|---|
| `idCarta` | Identifica la carta |
| `estado` (vista / conseguida) | Pintar la rejilla |
| `primeraVez` (fecha UTC) | El detalle de la carta |
| `zona` y `ball` de la primera captura | El detalle de la carta |
| `capturas` (número) | El detalle de la carta |

Reglas de cuándo se registra:

1. **Al acertar la Ball**, antes de elegir hueco: da igual que el Pokémon acabe en el equipo o en el PC. Con el equipo lleno nada se pierde (D-20 §2), así que el registro tampoco.
2. **Aunque la carta se sustituya al evolucionar.** La evolución sustituye a la carta anterior (D-20 §2.1), pero la anterior **sigue conseguida** y la nueva queda **conseguida** también. «Mis cartas» es el historial de lo que se ha tenido, no del equipo actual.
3. **El inicial cuenta** como conseguido al elegirlo.
4. **Un jefe capturado** registra la **carta normal**, no la del jefe (D-20 §4, Jefes).
5. **Una carta ex** es una entrada propia (D-20 §2.1): Raichu ex no es Raichu. Ojo: la Pokédex de **Enemigos** usa `idCarta`, que unifica «Kingdra ex» y «Kingdra»; en «Mis cartas» **no** debe hacerse, o una carta ex quedaría conseguida sin tenerla.
6. **Repetir un salvaje** y capturarlo otra vez suma a `capturas`, sin cambiar el resto.

**La colección es de la cuenta, no de la partida.** Una campaña nueva empieza con el equipo vacío, pero «Mis cartas» conserva todo. Se guarda en el dispositivo y se sincroniza al iniciar sesión, igual que la Pokédex de Enemigos (`flujo-app.md` §6).

### 3.4 Qué no hace

- **No se registran cartas físicas oficiales** de Pokémon TCG (las que se usan en la partida libre física): no hay escaneo ni reconocimiento.
- **No se vende nada que no se haya capturado** en la colección **Campaña**: esa colección solo se llena jugando.
- **No hay colecciones ajenas:** no se ven las cartas de otros jugadores hasta que existan amigos (`flujo-app.md` §7).

### 3.5 Relación con las cartas físicas

Ayme ha creado e impreso las cartas de campaña (las 22 actuales, 001/150 y la serie NN/20). La relación queda así:

**PROPUESTA (decisión 8):**

- **Misma carta, mismo arte, misma numeración.** La carta digital de «Mis cartas» es la imagen de la carta física. Un jugador con la carta impresa en la mano reconoce la que ve en la app.
- **No hay vínculo técnico:** tener la carta impresa no desbloquea la digital, ni al revés. Cada jugador consigue la suya jugando.
- **Idea futura, sin decidir:** un **código de canje** impreso en la carta física que desbloquee su copia digital (útil para regalar una carta a un amigo). No encaja todavía: exige servidor, control de usos y un criterio contra el reparto de cartas sin jugar. Se anota para cuando el formato digital esté consolidado.
- **Dependencia para Arte y Diseño:** la numeración impresa de Nidoran♂ es 029/150 y la de la Pokédex es 032 (D-20 §8, 13). Hay que resolverlo **antes** de enseñar el número en «Mis cartas».

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

**Lo que no se promete**: la tienda (aún no existe), la Liga, las cartas del formato digital, el tiempo que dura el primer tramo (sin medir hasta el primer playtest), ni que se pueda jugar sin cuenta si algún día los puntos lo exigen.

**Riesgos que hay que decir de entrada** (mejor sin sorpresas):

- **La partida se guarda en el dispositivo**, no en la cuenta. Si el amigo juega en la **web** y borra los datos del navegador, **pierde el progreso**. Hasta que haya sincronización, hay que avisarlo.
- **Hace falta cuenta de Deck Tracker** para entrar (en la app solo se inicia sesión; el registro se hace en Deck Tracker). Es la mayor fricción de la primera sesión.
- **No es un proyecto público.** Los sprites son de Nintendo y The Pokémon Company, tomados de Escarlata y Púrpura (#389): el enlace es para el grupo y no se reenvía ni se publica.

**Borrador del mensaje al grupo** (tono de grupo de WhatsApp, para que Ayme lo adapte):

> Ya se puede probar el **modo campaña** de Incursiones 🎮
> Es como un Pokémon de cartas para jugar **solo**: eliges inicial en Pueblo Paleta, recorres Kanto, capturas y llegas hasta la medalla de Brock. De momento solo ese tramo; el resto irá llegando.
> Lo que ganas se guarda como **puntos** en tu cuenta: servirán para la tienda y para desbloquear jefes de las incursiones.
> Ojo: es versión de prueba. Necesitas tu cuenta de Deck Tracker, y la partida se guarda **en tu dispositivo** (si juegas en la web y borras datos del navegador, la pierdes).
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
| D-20 §10 | Nuevas filas del registro con las decisiones 1 a 9 |
| D-10 §5 | Añadir el contador de **saldo** junto al de puntos ganados |
| `flujo-app.md` §6 | Definir las dos colecciones de «Mis cartas» y su relación con Enemigos |
| `docs/README.md` | Ya enlaza este documento |

**Para Programación** («Puntos al servidor y tienda», que #387 bloquea), en datos y sin escribir código aquí:

- El servidor guarda **puntos ganados** y **saldo** por cuenta, y un registro de compras (`compras`: cuenta, producto, precio, fecha) con clave generada por el cliente para que los reintentos no cobren dos veces, como en D-10.
- El catálogo de la tienda debe ser **datos** (`id`, familia, nombre, precio, requisitos), no constantes, para ajustar precios sin publicar app.
- «Mis cartas» necesita un registro por carta (§3.3), con clave en el dispositivo y sincronización al iniciar sesión.
- El servidor acepta lo que reporta el cliente con tope por hito (D-20 §6); los topes son los valores de §2.1.

**Para Diseño:** simulación de cuántos puntos hay al llegar al primer intercambio y al primer ex (§2.5); decidir los duplicados de sobre (§2.4); el momento exacto de cada texto de §4.5.

**Para Arte:** diseños de moneda y de dados (la clásica y la estándar ya existen); el estado «gris» de «Mis cartas» (el criterio visual de Enemigos ya existe); la pantalla de la tienda.

**Para Calidad y soporte:** fase 0 y fase 1 de §4.4, y medir la duración del primer tramo.

## 6. Preguntas abiertas

1. **¿Se puede jugar la campaña sin sesión?** `flujo-app.md` dice que la sesión nunca es obligatoria, pero los puntos van a la cuenta y hoy se guardan en el dispositivo sin enviarse. Hay que decidir si se juega sin cuenta con los puntos **en espera** (la app ya tiene una cola de envío) o si se pide cuenta. Cambia lo que dice el mensaje de §4.3.
2. **¿Qué pasa con los puntos de un invitado en la campaña?** D-10 dice que se pierden; en un modo de un solo jugador, la regla quizá deba ser otra.
3. **Tamaño del sobre y composición** (§2.4): son números míos.
4. **Rarezas de las cartas del formato digital:** se han usado las del proyecto (Común a Ultra rara) y pueden no ser las definitivas.

## 7. Fuentes

Documentos del repositorio: `docs/D-20-modo-campana.md` (§1, §2.1, §4, §5, §8, §10), `docs/D-10-sistema-de-puntos.md` (§1, §4, §5), `docs/diseno-ui/flujo-app.md` (§1 bis, §6, §8), `docs/diseno-ui/campana-arte-interfaz.md`, `docs/D-18-monedas.md`, `balance/informes/campana_calibrar_2026-11-22.md` y el código de `engine/lib/src/campana/partida.dart` (cifras de puntos, dinero y precios).
