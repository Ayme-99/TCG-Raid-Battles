# Campaña, tramo 2 (Ruta 3 → Ciudad Celeste): medición de Clefairy jefe, Nadador Luis y Misty

**Fecha:** 2026-11-27 · **Autor:** Calidad y soporte · **Issues:** #386 (y #385 como contexto) · **Solo `sim/` e informe**: no toca cartas, catálogo, motor ni D-20.

## Qué se ha medido

El simulador de partida (`sim/bin/sim_campana_partida.dart`, el de #409) llegaba solo hasta Brock. Se le ha añadido `--hasta=misty`, que sigue el camino obligatorio del catálogo de master (#537): Ruta 3 (Spearow o Nidoran♂, Chica, Joven) → centro de Monte Moon → **Clefairy jefe** → Ruta 4 (Sandshrew o Rattata) → centro de Celeste → **Nadador Luis** → **Misty**. Se saltan los nodos opcionales (galería de Monte Moon, Ruta 24). Usa el motor, el catálogo y la IA reales, con Pociones de 300 y Pokéballs de 200 en los centros.

Línea base (la de #476/#505): `--ruta1=si --balls=5 --empieza=gimnasios` (D-20 §10: el rival empieza solo en gimnasios, Liga y Legendarios, así que Clefairy jefe lo empieza el jugador y Luis y Misty el rival), 1500 recorridos por inicial, semilla 1. «Primer intento» = victoria al primer intento entre los recorridos que llegan a ese combate. Objetivo de Ayme (§10): **75 %**.

## Resultado: el tramo 2 queda MUY por encima del 75 %

Primer intento, por inicial (Bulbasaur / Charmander / Squirtle). Con Pociones (2 al salir) y volviendo al centro a curar:

| Combate | Con evolución | Sin evolución |
|---|---|---|
| Brock (como referencia) | 98,2 / 91,6 / 100 % | 75,4 / 75,3 / 88,4 % |
| **Clefairy jefe** | 100 / 100 / 100 % | 99,8 / 99,9 / 99,8 % |
| **Nadador Luis** | 100 / 100 / 100 % | 100 / 100 / 100 % |
| **Misty** | 100 / 100 / 100 % | 100 / 100 / 100 % |

Distancia al 75 %: **+25 puntos** en los tres combates, con y sin evolución, con y sin Pociones (sin Pociones: Clefairy 99,8–100 %, Luis y Misty 100 %). Ninguno de los tres es difícil para quien ya ha pasado Brock. Con evolución, además, el equipo de Ruta 3 y 4 llega con 4–5 Pokémon.

Qué pasa si no se cura entre combates (`--retroceder=no`, sin volver a un centro): Luis sigue en 100 % y Misty en 99–100 %; el cuello de botella es Brock (con evolución y sin Pociones 44 / 13 / 5 %, sin evolución 0 %), no el tramo 2. Quien acaba ganando a Misty con reintentos: con evolución 99,6 / 99,6 / 89,9 %; sin evolución 88,9 / 95,2 / 83,8 %. Lo que se pierde por el camino se pierde antes (Pikachu jefe y Brock), no en el tramo 2.

## Por qué «en realista casi nadie pasa Brock»

El modo `realista` de `sim_campana.dart` (el que usó Programación) no tiene evolución, ni reintentos, ni Pociones, y el equipo sale de capturas al azar. Con 1000 recorridos (`realista.txt`): **Brock lo gana el 3,6 % de Bulbasaur, el 6,6 % de Charmander y el 21,2 % de Squirtle**, y por tanto casi nadie llega a Ruta 3. No es un fallo del tramo 2, es que ese modo no representa la partida: en el simulador de partida, que sí juega con las reglas reales (evolución a 70 XP, Pociones, volver al centro, reintentos), Brock queda en 98 / 92 / 100 % con evolución y 75 / 75 / 88 % sin ella. **Ese modo no sirve para medir el tramo 2**; el de partida sí.

## Qué recomienda Calidad (para que decida Ayme; no se toca nada)

1. **Brock es el combate difícil del arranque; el tramo 2 es fácil.** Si Ayme quiere que el 2.º tramo también ronde el 75 %, el hueco está en Clefairy jefe, Luis y Misty, no en Brock.
2. Para subir la dificultad lo normal sería mirar los PS y el ataque de Starmie, y Muro Mágico de Clefairy, que casi no pesa porque la IA del jugador no usa veneno. Si Ayme lo pide, se mide cualquier propuesta con `--hasta=misty` y se comparan los números.
3. Pendiente de medir con datos de Ayme: la 2.ª partida de #385 dirá si el humano rinde como la IA.

## Cómo repetirlo

```
cd sim
dart compile exe bin/sim_campana_partida.dart -o /tmp/simp
/tmp/simp --modo=tramo --hasta=misty --partidas=1500 --ruta1=si --balls=5 --empieza=gimnasios \
  --retroceder=si --pociones=2 --pociones-combate=si --pociones-en=todos --evolucion-inicial=si|no
```

Salidas completas en `campana_tramo2_2026-11-27/`: `partida_{si,no}evo_{centros,sinvolver}_{0,2}pociones.txt`, `nodos_sin_evolucion.txt` (duelos del equipo inicial sin evolución, solo contexto: ahí Misty da 0 %) y `realista.txt`.

## Límites

- La IA juega con equipo completo y sin errores; un jugador humano es más débil o más fuerte según el caso (por eso #385).
- Se saltan los nodos opcionales (más XP y capturas) y la Ruta 22.
- Las corridas con `--ruta1=no` y 0–1 Balls se descartaron: no son comparables con la línea base (Brock 0 %).
