# sim/

Simulador Monte Carlo por consola. Juega miles de partidas automáticas con el motor de `engine/`
y calcula la tasa de victoria por jefe y número de jugadores (1 a 4).

Lee los jefes de `catalog/bosses/` y las tablas de `balance/tablas/`, y escribe los informes en
`balance/informes/`. Ningún jefe se publica sin un informe aquí (tarjetas D-03 y T-14).

```
cd sim
dart pub get
dart run bin/sim.dart
```

## Simulador con cartas reales (D-03)

`bin/sim_cartas.dart` usa cartas reales (`balance/tablas/cartas_prueba.csv` y `ataques_prueba.csv`) y las
reglas de la hoja oficial de Raid Battle. Es el que debe usarse para calibrar los jefes de
`balance/tablas/niveles.csv`. `bin/sim.dart` es el modelo abstracto anterior y ya no está calibrado.

```
dart run bin/sim_cartas.dart              # mide con los HP de niveles.csv
dart run bin/sim_cartas.dart --calibrar   # busca el HP que da 75/50/30/15 %
```

## Jefes del catálogo con aliados (T-28, primera parte)

`bin/sim_jefes.dart` simula **cada jefe de `catalog/bosses/`** con su HP, sus ataques y su invocación de aliados (umbral, tirada, slot y categoría, ataque de entrada y de final de turno, Bloqueo de Bronzong y exceso de daño perdido). Mide tres políticas de los jugadores: `solo-jefe` (todos ignoran a los aliados y dañan al jefe, salvo que Bronzong obligue; el aliado sigue atacando a su dueño), `solo-dueno` (el dueño del slot ataca siempre a su aliado, la más dura) y `ayuda` (un jugador libre ataca al aliado de un compañero con probabilidad `--ayuda`, 0,5 por defecto, un supuesto sin datos de playtest). Escribe `balance/informes/jefes_aliados.csv`.

```
dart run bin/sim_jefes.dart
dart run bin/sim_jefes.dart --equipos=20 --partidas=20 --informe=/tmp/prueba.csv   # prueba rápida
dart run bin/sim_jefes.dart --calibrar   # busca el HP que da el objetivo (75/50/30/15 %)
```

Por defecto (T-72, #189; `--animo=LISTA` para cambiarlo, `--animo=no` para quitarlas) el jugador que se sienta por un KO roba una carta de ánimo (D-05): con `todas` o una lista de las 5 cartas oficiales (`1` doble daño a un Pokémon, `2` cura 80 a todos, `3` cura todo el daño del más dañado, `4` el jefe juega una sola carta, `5` +50 de daño a los ataques de los jugadores). Máximo 3 cartas distintas por partida. Se roba en la posición del jugador en el orden y los efectos «este turno» alcanzan a quien actúa después en esa ronda (el doble daño va al siguiente ataque con daño, no al mejor). Con `--animo=no` no se modelan, que es lo que asumían las calibraciones anteriores al 2026-11-14.

Opciones para probar partidas con menos jugadores (T-67): `--jugadores=N` (equipos de 1 a 4 jugadores; el mazo de ataques del jefe se adapta), `--mesa8` (se mantienen 8 Pokémon en mesa: 3 jugadores 3+3+2, 2 jugadores 4+4), `--mejor-primero` (cada jugador saca de Activo su mejor Pokémon) y `--menos-ataques=K` (quita K ataques por turno al jefe). El jefe roba sus ataques del mazo real de 20 cartas (`MazoAtaquesJefe` del motor).

Con `--desajuste` (D-15) mide cada jefe contra equipos de todos los niveles de X, para ver cuánto cae o sube la victoria fuera del rango del jefe (informe en `balance/informes/jefes_desajuste.csv`).

Con `--causas` añade una tabla que desglosa los intentos de invocación de cada jefe (media por partida): invocados, perdidos por falta de slot o de categoría, y umbrales que no llegaron a cruzarse porque la partida terminó antes.

Con `--calibrar` busca, por jefe, el mayor HP (en centenas) con el que la política `solo-dueno` llega al objetivo del nivel, manteniendo el mismo número de aliados (el `cadaHp` se reparte en tramos iguales), y escribe `balance/informes/jefes_aliados_calibrado.csv`.

**Modela los efectos de los ataques del jefe (D-14)** que lee del catálogo: daño variable (Danza Espada, Castigo), autodaño, contadores a todos, y que el Defensor no ataque o no se retire el siguiente turno (siempre 1 turno; `ignoraEfectos` no cuenta). **Modela los scripts de aliados que aplica el programa (D-13):** Tanque (`tanque-jefe-N`: los ataques de los jugadores hacen N de daño menos mientras viva) y Cura (`cura-jefe-N`: el jefe se cura N HP al final de su turno). También modela (D-16) Chupavidas (cura al jefe y a los aliados cada vez que ataca), Foco Energía (+N al ataque del jefe con moneda), los ataques de monedas («20×»), el Tanque sobre los aliados y, como si la mesa los aplicara siempre, «Tormenta de arena» (10 al activo de cada jugador en el chequeo) y «Rencor» (sin repetir ataque). Y los de Manectric: Drenadoras (contador de 10 en cada activo y el jefe se cura 10 por cada uno, al entrar y en el chequeo), Aullido (+20 a cada ataque del jefe), Gruñido (−10 a los ataques de los jugadores) y el daño de Chispazo a los adyacentes. **No modela** el veneno (tampoco el de Tóxico) ni la parálisis de Moflete Estático,  y la quemadura del jefe. Las cifras siguen siendo una cota optimista para los jugadores; la política `solo-dueno` es la más prudente. El CI compila el simulador y lanza una partida mínima, pero **no comprueba que los resultados sean razonables**: eso se mira al leer el informe.


> **T-71:** el jefe llama a su primer aliado al terminar su turno de la ronda 1 y a los siguientes cada vez que su HP baja a un umbral (`cadaHp` HP perdidos), hasta nivel + 1 llamadas en total y sin moneda. Los umbrales cruzados antes de la primera llamada se suman a ella. `tirada` del catálogo se ignora (salvo que `invocacion` exista).

## Combate de campaña (D-20)

`bin/sim_campana.dart` juega combates 1 contra 1 del modo campaña con el motor `engine/lib/campana.dart` y la IA rival en los dos bandos, con los Pokémon de `catalog/campana/`. No usa cartas ni imágenes, solo los datos (provisionales). Modo `duelos` (cada Pokémon contra cada uno, empezando cada bando), modo `empezar` (cuánto vale empezar primero: victorias del jugador empezando él o el rival, por categoría del rival; `--partidas=N` semillas por pareja, 20 por defecto; #451/#386), modo `equipos` (equipos aleatorios), modo `nodos` (cada inicial contra cada rival posible de cada combate de `regiones/kanto.json`, con los PS llenos) y modo `tramo` (el tramo entero de seguido con el daño arrastrado, solo con el inicial y capturando los salvajes vencidos; `--entrenador=N` fija cuántos Pokémon saca un entrenador sin Pokémon fijos) y modo `realista` (el tramo con el inicial y `--capturas` Pokémon de las rutas, eligiendo la IA el activo de cada combate). El objetivo es un **75 %** de victorias (#383, D-20 §10.5); el informe está en `balance/informes/campana_calibrar_2026-11-22.md`. Los jefes llevan su llamada de aliado (D-20 §4, Jefes); `--aliado=no` la quita para comparar (#393). Muestra victorias por Pokémon, turnos medios, la mezcla de acciones (atacar, cargar, cambiar) y la ventaja de empezar; la energía se puede cambiar con `--energia-inicial`, `--energia-maxima`, `--energia-turno` y `--energia-cargar`.

**XP y cartas ex hasta la Liga (#451).** `bin/sim_campana_ex.dart` es un modelo de cuentas, no un simulador de combate: lleva la reserva de XP, las medallas mínimas (D-20 §10.11), las piedras ex (una de premio por medalla y compradas a 2.000) y el dinero por tramo, con 16 Pokémon posibles. Solo existe el tramo 1 en el catálogo, así que los tramos 2 a 8 son supuestos que el propio programa lista. Se ejecuta sin opciones (`dart run bin/sim_campana_ex.dart --csv=ruta.csv`) e imprime las tablas del informe `balance/informes/campana_xp_ex_2026-11-24.md`.

**Partida completa del primer tramo (#409).** `bin/sim_campana_partida.dart` juega la partida entera con las reglas de master: captura por probabilidad con Ball (Común 75 %, Intermedio 50 %, Fuerte 25 %, Jefe 12,5 %), dinero (1.000 de salida, tienda de Ciudad Verde), reserva común de XP, evolución del inicial y de Metapod/Kakuna, curar volviendo a un centro y reintentar cuando se pierde. Modos: `tramo` (recorrido completo por inicial, con `--ruta1=si|no` para capturar en Ruta 1 y `--ruta22`), `bolas` (barrido de 0 a 5 Pokéballs compradas), `techo` (el mejor equipo posible de 1 a 6 Pokémon, con y sin evolución del inicial) y `equipo` (un equipo fijo contra Brock). `--tope-turnos=N` corta los combates que pasan de N turnos y `--al-tope=derrota|mas-ps` decide el resultado; al final del modo `tramo` informa de la duración de los combates y de cuántos acaban en tope. El catálogo de master ya trae la evolución de los iniciales (#455) y las cartas reales de Ivysaur, Charmeleon y Wartortle; `--evolucion-inicial=si` la activa. `--empieza=jugador|gimnasios|rival|rival-jefes` decide quién empieza cada combate en los modos `tramo`, `bolas` y `pociones` (por defecto el jugador; `rival-jefes`: el rival solo en Pikachu jefe y en los gimnasios). Modo `pociones`: Brock con Pociones en combate (sin gastar turno, sin límite por combate; `--ps-pocion`, `--precio-pocion`, `--limite-pocion`, `--balls`, `--pociones`). Usa la Poción de la IA real (`UsarPocion`, #465); `--pocion-politica=simulador` recupera la política antigua (curar bajo `--umbral-pocion` PS), solo para comparar, y `--limite-pocion=N` limita las Pociones disponibles en cada combate. El modo `tramo` informa de la XP ganada hasta Brock y con su recompensa. Los CSV salen en `balance/informes/`. Ejemplo: `dart run bin/sim_campana_partida.dart --modo=tramo --partidas=1500 --ruta1=si --retroceder=si`.

**Tramo 2 (#386).** `--hasta=misty` (modo `tramo`) sigue la partida después de Brock por el camino obligatorio del catálogo: Ruta 3, centro de Monte Moon, Clefairy jefe, Ruta 4, centro de Celeste, Nadador Luis y Misty, y añade cada combate a la tabla de «victorias a la primera» y la línea «acaba ganando a Misty». En los centros de Monte Moon y Celeste compra Pociones y Pokéballs (`--balls-tramo2=N`, 3 por defecto); al salir de Plateada vuelve a su centro a comprar con el dinero de Brock. Ejemplo: `dart run bin/sim_campana_partida.dart --modo=tramo --hasta=misty --partidas=1500 --ruta1=si --balls=5 --empieza=gimnasios --retroceder=si --pociones=2 --pociones-combate=si --pociones-en=todos --evolucion-inicial=si`. Informe: `balance/informes/campana_tramo2_2026-11-27.md`.

```
dart run bin/sim_campana.dart
dart run bin/sim_campana.dart --modo=equipos --tamano=3 --partidas=2000
dart run bin/sim_campana.dart --modo=nodos --partidas=200     # cada inicial contra cada rival del tramo
dart run bin/sim_campana.dart --modo=tramo --partidas=5000    # el tramo entero de seguido
dart run bin/sim_campana.dart --modo=realista --capturas=3   # el tramo con inicial + 3 capturas
```
