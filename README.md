# TCG-Raid-Battles

# Incursiones

Asistente de combate para **Incursiones**, un formato cooperativo casero de Pokémon TCG (estilo Raid Battle) para 1-4 jugadores. La app actúa como "Game Master" virtual: lleva el HP del jefe y el registro de la partida, mientras que las cartas y los contadores de daño de los jugadores viven físicamente en la mesa.

## Estado actual

🚧 **Fase de diseño.** Todavía no hay código de la app — este repo arranca con el [Game Design Document](./incursiones_gdd.md) cerrado, que recoge:

- Estructura de turno completa (jugadores → jefe → repetir)
- Cálculo automático del nivel del jefe según la potencia de los jugadores
- Condiciones de victoria/derrota
- Mecánicas de aliados invocados y curación del jefe
- Glosario de términos del formato

El desarrollo se retomará cuando termine [deck-tracker-app](#) / [deck-tracker-server](#) (proyecto hermano, en curso).

## Planteamiento técnico (decidido, pendiente de construir)

- App Flutter independiente (no integrada en el Deck Tracker), pensada para uso "tablet en medio de la mesa".
- Backend: namespace propio (`/api/incursiones/*`) dentro del backend Node ya existente de Deck Tracker, reutilizando despliegue en Render sin acoplar modelos de datos entre proyectos.
- Motor de partida: lógica pura en Dart (sin dependencia de Flutter Widgets), pensada para conectarse a cualquier gestor de estado.

## Documentación

- [`incursiones_gdd.md`](./incursiones_gdd.md) — Game Design Document (fuente de verdad del diseño de juego)
