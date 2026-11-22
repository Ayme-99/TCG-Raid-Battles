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

Reproducir: `cd sim && dart run bin/sim_campana.dart --modo=nodos --partidas=200` y `dart run bin/sim_campana.dart --modo=tramo --partidas=5000 [--entrenador=2]`. Los CSV están en `balance/informes/campana_nodos.csv` y `campana_tramo.csv`.

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

Hoy **nadie completa el tramo**: estamos a 75 puntos del objetivo. Capturando solo se pueden sumar 2 Pokémon (uno de la Ruta 1 y uno de la Ruta 2 sur), así que el equipo no pasa de 3.

## Pruebas aparte (sin cambiar el catálogo)

- **PS de Pikachu jefe** (1 contra 1, PS llenos): con 100 no gana ningún inicial; con 90 gana Charmander; con 80 o menos ganan Bulbasaur y Charmander. **Squirtle no gana ni con 50**: es débil a eléctrico (×2) y Pikachu lo derriba antes.
- **Equipo de 3 con los PS llenos** (inicial + Pidgey + Weedle) contra el gimnasio: el Entrenador Joven cae un 76 % de las veces con Bulbasaur o Charmander y un 25 % con Squirtle; **Brock, nunca** (0 %).

## Cosas que no cuadran con D-20 §3.5 (para que Ayme decida, no se han tocado)

- **Bulbasaur (Placaje) y Squirtle (Burbuja)** pegan 20 con coste 2; el baremo de un básico es 30–40. Charmander (Ascuas 30) sí está dentro, y es el inicial que mejor sale.
- **Caterpie (Placaje)** también lleva 20 con coste 2.
- **Onix** tiene 110 PS; el baremo de un básico es 50–90 (§3.5 permite salirse de la tabla solo a los jefes).
- **Kakuna** combina Fortaleza (−10) y veneno: contra un ataque de 20, el inicial pega 10 por golpe mientras se envenena, y por eso Bulbasaur y Squirtle no ganan nunca.

## Palancas posibles (Ayme elige)

1. Ajustar los ataques de coste 2 de Bulbasaur y Squirtle al baremo (30).
2. Bajar los PS o el daño de Pikachu jefe, o contar con que se le llegue con equipo (ojo: Squirtle tiene debilidad eléctrico).
3. Rebajar a Brock (PS de Onix dentro del baremo, o solo un Pokémon) o meter más capturas antes del gimnasio.
4. Más salvajes capturables antes de Pikachu (hoy solo hay 2) o un centro Pokémon antes del Bosque Verde.
5. Fijar cuántos Pokémon saca un Cazabichos y si Kakuna puede salir en el primero.
6. Parámetros de energía (`--energia-*`), que afectan a todos por igual.

Siguiente paso: cuando Ayme decida qué palanca y qué cifras, se aplica en un PR aparte y se vuelve a medir con estos dos modos.
