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

El desarrollo se retomará cuando termine [deck-tracker-app](#) / [TCGMasters-server](#) (proyecto hermano, en curso).

## Planteamiento técnico

Monorepo: motor, simulador, app y backend viven en este repo.

- `engine/`: motor de partida en Dart puro (sin Flutter), con estado inmutable y registro de eventos.
- `sim/`: simulador Monte Carlo para validar el balance de cada jefe.
- `catalog/`: catálogo de jefes en JSON (datos, no código) y su esquema de validación.
- `balance/`: tablas de la fórmula de poder (CSV) e informes del simulador.
- `app/`: app Flutter independiente (no integrada en el Deck Tracker), pensada para "tablet en medio de la mesa".
- `server/`: backend Node (`/api/incursiones/*`), exportado como router para montarlo en el backend de Deck Tracker y reutilizar su despliegue en Render sin acoplar modelos de datos.
- `docs/`: notas de playtest y bocetos de interfaz.

## Documentación

- [`incursiones_gdd.md`](./incursiones_gdd.md) — Game Design Document (fuente de verdad del diseño de juego)
- [`docs/`](./docs) — playtests y diseño de interfaz
- [`docs/DEPENDENCIAS.md`](./docs/DEPENDENCIAS.md) — qué hay que tocar en otro sitio cuando cambias algo (catálogo, contrato, balance, servidor externo)
- Tablero de trabajo: [GitHub Project #10](https://github.com/users/Ayme-99/projects/10)
