# Calibrado del primer tramo de Kanto (#383)

Fecha: 2026-11-22. Objetivo de Ayme: **75 % de victorias**. Este informe **no cambia ninguna carta**: mide el catálogo tal como está (`catalog/campana/`, master tras #357) y señala dónde no se llega al objetivo. Qué se cambia, y con qué cifras, lo decide Ayme.

## Cómo se ha medido

`sim/bin/sim_campana.dart` tiene dos modos nuevos:

- **`--modo=nodos`**: cada inicial contra cada rival posible de cada combate de `regiones/kanto.json`, con los PS llenos, empieza el jugador, 200 semillas por emparejamiento. Un entrenador sin Pokémon fijos (los Cazabichos) se mide Pokémon a Pokémon de su clase.
- **`--modo=tramo`**: el tramo entero de seguido, 5000 recorridos por inicial. El daño se arrastra entre combates y la energía vuelve a 10 en cada uno (decisiones del 2026-11-22, #358), los centros Pokémon curan, las bifurcaciones se eligen al azar y los desvíos opcionales se saltan. Se gana si se llega al final sin perder ningún combate.

Límites (son de la medida, no reglas del juego):
- La IA juega también por el jugador. Una persona puede jugar algo mejor.
- **Pikachu jefe va sin la llamada de aliado** (#372 no está hecho). Con aliado será más difícil.
- Cuántos Pokémon saca un Cazabichos no está decidido: se mide con 1 (y abajo con 2 como comparación).
- La captura no está diseñada (#361). El tramo se mide de dos formas: **solo con el inicial** y **capturando todos los salvajes vencidos** (hasta 6, con los PS llenos). Son cotas inferior y superior.
- **`--modo=realista`**: el resultado 3, con un equipo de inicial + 2 o 3 capturas y la IA eligiendo el activo.

Reproducir: `cd sim && dart run bin/sim_campana.dart --modo=nodos --partidas=200` y `dart run bin/sim_campana.dart --modo=tramo --partidas=5000 [--entrenador=2]` y `dart run bin/sim_campana.dart --modo=realista --partidas=5000 --capturas=3 [--entrenador=2]`. Los CSV están en `balance/informes/campana_nodos.csv`, `campana_tramo.csv` y `campana_realista.csv`.

## Resultado 1: cada combate por separado (PS llenos)

| Combate | Bulbasaur | Charmander | Squirtle |
|---|---|---|---|
| Ruta 1: Pidgey | 100 % | 100 % | 100 % |
| Ruta 1: Rattata | 87,5 % | 100 % | 75 % |
| Ruta 22 (opcional): Rattata / Spearow / Nidoran♀ | 88–90 % | 100 % | 75–85 % |
| Ruta 22 (opcional): Nidoran♂ | **42 %** | 100 % | 75 % |
| Ruta 22 (opcional): Mankey | **0 %** | **6 %** | **0 %** |
| Ruta 2: Weedle / Caterpie | 100 % | 100 % | 100 % |
| Cazabichos: Weedle, Caterpie o Metapod | 100 % | 100 % | 100 % |
| Cazabichos: Kakuna | **0 %** | 100 % | **0 %** |
| Jefe Pikachu (sin aliado) | **0 %** | **0 %** | **0 %** |
| Gimnasio: Entrenador Joven (Diglett + Sandshrew) | **0 %** | **0 %** | **0 %** |
| Gimnasio: Brock (Geodude + Onix) | **0 %** | **0 %** | **0 %** |
| **Media de los obligatorios** | 65,8 % | 80,0 % | 65,0 % |

Los combates de ruta están en el objetivo o por encima. Los cuatro muros son Kakuna (para Bulbasaur y Squirtle), Pikachu, el Entrenador Joven y Brock, y Mankey en el desvío opcional.

## Resultado 2: el tramo entero de seguido

| Variante | Bulbasaur | Charmander | Squirtle | Dónde se pierde sobre todo |
|---|---|---|---|---|
| Solo el inicial, Cazabichos con 1 | 0 % | 0 % | 0 % | Bulbasaur y Squirtle, en los Cazabichos (Kakuna); Charmander, en Pikachu (100 %) |
| Capturando, Cazabichos con 1 | 0 % | 0 % | 0 % | Bulbasaur y Squirtle, en Pikachu (≈80 %); Charmander, en Brock (72 %) y el Entrenador Joven (28 %) |
| Solo el inicial, Cazabichos con 2 | 0 % | 0 % | 0 % | Cazabichos |
| Capturando, Cazabichos con 2 | 0 % | 0 % | 0 % | Cazabichos y Pikachu |

Solo con el inicial **nadie completa el tramo**, pero es un escenario irreal (en el juego se captura): el resultado 3 mide un equipo realista. Capturando solo se pueden sumar 2 Pokémon (uno de la Ruta 1 y uno de la Ruta 2 sur), así que el equipo no pasa de 3.

## Resultado 3: el tramo con un equipo realista (`--modo=realista`)

El inicial y 2 o 3 Pokémon distintos al azar entre los salvajes de las rutas del tramo (Caterpie, Mankey, Nidoran♀, Nidoran♂, Pidgey, Rattata, Spearow y Weedle), con los PS llenos desde el principio. La IA elige quién sale en cada combate con el mismo criterio que usa para sus relevos. El resto, como en el resultado 2. Sigue sin XP, Pociones ni evolución, porque no están diseñadas. 5000 recorridos por inicial y variante.

**Completan el tramo:**

| Equipo | Cazabichos con | Bulbasaur | Charmander | Squirtle |
|---|---|---|---|---|
| Inicial + 2 | 1 | 0 % | 0,2 % | 0,3 % |
| Inicial + 2 | 2 | 0 % | 0,2 % | 0,1 % |
| Inicial + 3 | 1 | 0 % | 5,7 % | 6,7 % |
| Inicial + 3 | 2 | 0 % | 5,2 % | 4,2 % |

**Victorias en cada combate entre los que llegan a él** (inicial + 3, Cazabichos con 1):

| Combate | Bulbasaur | Charmander | Squirtle |
|---|---|---|---|
| Rutas y Cazabichos | 100 % | 100 % | 100 % |
| Pikachu (sin aliado) | 97,6 % | 100 % | 97,2 % |
| Entrenador Joven | 97,0 % | 91,5 % | 96,0 % |
| **Brock** | **0 %** | **6,2 %** | **7,2 %** |

Con inicial + 2 y Cazabichos con 2, Pikachu baja al 37–59 % y el segundo Cazabichos al 28–89 %, porque **el daño se arrastra y no hay centro Pokémon entre el Bosque Verde y Pikachu**. Lo mismo pasa entre el Entrenador Joven y Brock, que van seguidos sin curar.

**Lectura:** con equipo, el muro claro es **Brock**. Pikachu y el Entrenador Joven solo fallan cuando el equipo llega tocado.

## Pruebas aparte (sin cambiar el catálogo)

Cifras para decidir, no propuestas. Equipos al azar, 2000 combates, la IA elige el activo.

**Brock contra inicial + 3 capturas con los PS llenos** (como si se curase justo antes):

| Brock | Bulbasaur | Charmander | Squirtle |
|---|---|---|---|
| Actual: Geodude 80 + Onix 110 | 24 % | 30 % | 30 % |
| Onix a 90 | 40 % | 42 % | 42 % |
| Onix a 80 | 52 % | 58 % | 58 % |
| Onix a 70 | 52 % | 59 % | 59 % |
| Geodude 60 + Onix 90 | 44 % | 42 % | 42 % |
| Solo Onix (110) | 59 % | 71 % | 73 % |
| Solo Geodude (80) | 100 % | 100 % | 100 % |

Ni con el equipo curado se llega al 75 % sin quitarle un Pokémon a Brock, y por la vía de bajar los PS de Onix no se pasa del 59 %. En el tramo real además llega el equipo tocado por el Entrenador Joven.

**Pikachu jefe contra inicial + 2 capturas con los PS llenos:** 99–100 % con 100, 90 u 80 PS. Su problema en el tramo es el daño que trae el equipo, no sus PS.

**Solo el inicial** (resultado 1, como referencia): Pikachu con 100 PS no cae con ningún inicial; con 90 cae con Charmander, con 80 o menos con Bulbasaur y Charmander, y **Squirtle no gana ni con 50** (débil a eléctrico). Inicial + Pidgey + Weedle contra el Entrenador Joven: 76 % con Bulbasaur o Charmander y 25 % con Squirtle.

## Cosas que no cuadran con D-20 §3.5 (para que Ayme decida, no se han tocado)

- **Bulbasaur (Placaje) y Squirtle (Burbuja)** pegan 20 con coste 2; el baremo de un básico es 30–40. Charmander (Ascuas 30) sí está dentro, y es el inicial que mejor sale.
- **Caterpie (Placaje)** también lleva 20 con coste 2.
- **Onix** tiene 110 PS; el baremo de un básico es 50–90 (§3.5 permite salirse de la tabla solo a los jefes).
- **Kakuna** combina Fortaleza (−10) y veneno: contra un ataque de 20, el inicial pega 10 por golpe mientras se envenena, y por eso Bulbasaur y Squirtle no ganan nunca.

## Palancas, de menos a más coste (Ayme elige con estas cifras)

1. **JSON de los rivales, sin reimprimir:** PS de los rivales (Onix, Geodude, Pikachu jefe), cuántos Pokémon lleva cada equipo (Brock con uno solo, el número de Pokémon de los Cazabichos) y si Kakuna puede salir en el primer Cazabichos.
2. **Recorrido** (también JSON): un centro Pokémon o un descanso entre el Bosque Verde y Pikachu, o entre el Entrenador Joven y Brock.
3. **Parámetros del motor** (`--energia-*`), sin tocar cartas, que afectan a todos por igual.
4. **Daño de los iniciales** (Placaje y Burbuja a 30): obliga a reimprimir, así que va al final.

Siguiente paso: cuando Ayme decida qué palanca y qué cifras, se aplica en un PR aparte y se vuelve a medir con estos modos.
