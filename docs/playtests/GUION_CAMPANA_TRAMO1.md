# Guion de playtest: modo campaña, primer tramo (#385)

Objetivo: comprobar con la app si lo que mide el simulador (`balance/informes/campana_partida_2026-11-23.md`) se siente igual: Brock ≈ 76–98 % si se captura en Ruta 1 y se vuelve a la tienda; Pikachu jefe como segundo muro (sobre todo con Squirtle).

Anota cada partida en una copia de `PLANTILLA.md`. Juega cada inicial al menos 2 veces.

## Partida 1: «como lo haría un jugador normal» (con cada inicial)
1. Elige inicial. Anota: ¿se entiende qué hace cada botón?
2. Ruta 1: captura lo que puedas con 0 Pokéballs. **Anota si el juego deja claro que no hay Balls y qué hacer.** (Esperado: no puedes capturar hasta la tienda.)
3. Ciudad Verde: compra Pokéballs. Anota cuántas y qué quedó de dinero.
4. Vuelve a Ruta 1/2 a capturar. Anota cuántos intentos y qué probabilidad percibes.
5. Bosque Verde (2 Cazabichos), Pikachu jefe, Entrenador Joven, Brock.
6. En cada combate anota: ¿ganaste? turnos, PS que te quedan, si curaste.

## Partida 2: «sin capturar en Ruta 1»
Ve directo a Ciudad Verde con el inicial. Anota dónde te atascas (el simulador espera: Bulbasaur y Squirtle no pasan de Cazabichos/Pikachu; Charmander llega a Brock y gana ≈ 50 %).

## Qué probar
- Evolucionar el inicial a 0 medallas (¿se entiende? ¿gasta 70 XP de la reserva?). Anota PS al evolucionar (deben quedar 10).
- Evolucionar Metapod/Kakuna (50 XP).
- Retroceder a un centro y curar gratis; volver a Brock.
- Perder: ¿vuelves a la última cura con el equipo curado?
- Pikachu jefe: captura asegurada (1 Ball, una vez). La conversación `aviso-pikachu` cura una sola vez.
- Reintentar un combate de salvajes (XP y captura, sin dinero).

## Qué anotar siempre
Inicial, equipo al entrar a Brock, Pokéballs y Pociones comprados, derrotas por combate, tiempo total, y cualquier momento «no sé qué hacer». Marca los números que parezcan mal (daño, PS, probabilidad de captura, dinero).

## Señales de alarma
- Ganas a Brock a la primera con cualquier equipo (demasiado fácil).
- Más de 3 derrotas ante Pikachu jefe con Squirtle (esperado ≈ 35 % de fallo a la primera).
- No entender que hay que volver a la tienda.

## Fase 0 (D-21 §4.4): Ayme solo, medir la duración

Juega el tramo entero seguido, sin pausas largas, y apunta:

| Dato | Anota |
|---|---|
| Hora de inicio y de fin | |
| Minutos totales (sin pausas) | |
| Minutos hasta el primer combate acabado | |
| Minutos hasta llegar a Ciudad Verde | |
| Minutos hasta Brock | |
| Combates jugados (incluidos los repetidos) | |
| Derrotas | |
| Bloqueos (sitio donde no pudiste seguir) | |

Referencia del simulador: ≈18 combates de ≈12 turnos por recorrido. La fase 0 se da por buena cuando el tramo se completa sin bloqueos y se conoce la duración. Pasa a la fase 1 (2 o 3 amigos, uno cada vez, tú mirando sin ayudar y apuntando en `PLANTILLA.md`).
