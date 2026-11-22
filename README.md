# TCG-Raid-Battles

# Incursiones

Asistente de combate para **Incursiones**, un formato cooperativo casero de Pokémon TCG (estilo Raid Battle) para 1-4 jugadores. La app actúa como "Game Master" virtual: lleva el HP del jefe y el registro de la partida, mientras que las cartas y los contadores de daño de los jugadores viven físicamente en la mesa.

## Estado actual

🎮 **Partida completa jugable** en la app (Flutter: Web, Windows, Android), con motor, simulador de balance y backend:

- Estructura de turno completa (jugadores → jefe → repetir), con la mesa a pantalla completa y los controles flotantes.
- Cálculo automático del nivel del jefe según la potencia de los jugadores.
- 4 jefes en el catálogo (Onix, Manectric, Kingdra y Arceus), cada uno con 6 aliados.
- Condiciones de victoria/derrota, curación del jefe, estados, puntos y envío de resultados al servidor.

🗺️ **Modo campaña en construcción** (1 jugador, combates 1 contra 1 por Kanto; diseño en [D-20](./docs/D-20-modo-campana.md)). Hecho, de momento solo en motor, catálogo y simulador:

- Motor de combate 1 contra 1 (energía, acciones, tabla de tipos) e IA rival determinista.
- Catálogo de campaña: 22 Pokémon, 6 zonas, el jefe Pikachu y la región de Kanto, con sus esquemas de validación.
- Evolución, XP y cartas ex en el esquema y el motor; baremo de PS y daños con la escala real del TCG.
- Modelo de ruta por nodos con el primer tramo (Pueblo Paleta → Ciudad Plateada).
- Simulador de combates de campaña (`sim/bin/sim_campana.dart`).

Falta: las pantallas en la app, la captura, el guardado de la partida y la llamada de aliados del jefe.

Pendiente además: playtests en papel (los valores de balance salen del simulador), el formato digital, las salas multi-dispositivo (en pruebas, aparcadas) y el resto del [tablero](https://github.com/users/Ayme-99/projects/10). El diseño de juego está en el [Game Design Document](./incursiones_gdd.md).

## Planteamiento técnico

Monorepo: motor, simulador, app y backend viven en este repo.

- `engine/`: motor de partida en Dart puro (sin Flutter), con estado inmutable y registro de eventos. El combate de campaña vive en `engine/lib/src/campana/`.
- `sim/`: simulador Monte Carlo para validar el balance de cada jefe y de los combates de campaña.
- `catalog/`: catálogo de jefes y de la campaña (Pokémon, zonas, regiones) en JSON (datos, no código) y sus esquemas de validación.
- `balance/`: tablas de la fórmula de poder (CSV) e informes del simulador.
- `app/`: app Flutter independiente (no integrada en el Deck Tracker), pensada para "tablet en medio de la mesa".
- `server/`: backend Node (`/api/incursiones/*`), exportado como router para montarlo en el backend de Deck Tracker y reutilizar su despliegue en Render sin acoplar modelos de datos.
- `docs/`: decisiones de diseño (D-01 a D-20), notas de playtest y bocetos de interfaz.

## Documentación

- [`incursiones_gdd.md`](./incursiones_gdd.md) — Game Design Document (fuente de verdad del diseño de juego)
- [`docs/`](./docs) — playtests y diseño de interfaz
- [`docs/D-20-modo-campana.md`](./docs/D-20-modo-campana.md) — diseño del modo campaña
- [`docs/DEPENDENCIAS.md`](./docs/DEPENDENCIAS.md) — qué hay que tocar en otro sitio cuando cambias algo (catálogo, contrato, balance, servidor externo)
- Tablero de trabajo: [GitHub Project #10](https://github.com/users/Ayme-99/projects/10)
