# TCG-Raid-Battles

# Incursiones

Asistente de combate para **Incursiones**, un formato cooperativo casero de Pokémon TCG (estilo Raid Battle) para 1-4 jugadores. La app actúa como "Game Master" virtual: lleva el HP del jefe y el registro de la partida, mientras que las cartas y los contadores de daño de los jugadores viven físicamente en la mesa.

## Estado actual

🎮 **Partida completa jugable** en la app (Flutter: Web, Windows, Android), con motor, simulador de balance y backend:

- Estructura de turno completa (jugadores → jefe → repetir), con la mesa a pantalla completa y los controles flotantes.
- Cálculo automático del nivel del jefe según la potencia de los jugadores.
- 4 jefes en el catálogo (Onix, Manectric, Kingdra y Arceus), cada uno con 6 aliados.
- Condiciones de victoria/derrota, curación del jefe, estados, puntos y envío de resultados al servidor.

🗺️ **Modo campaña (en construcción):** un juego de Pokémon para un jugador, ajeno a la partida libre, con combates 1 contra 1. Ya se puede jugar **el primer tramo de Kanto, de Pueblo Paleta a la Medalla Roca de Brock**, desde «Nueva partida → Modo campaña»:

- Motor de combate con energía, debilidades y resistencias, 10 efectos de ataque, una habilidad pasiva y azar con semilla, y una IA rival determinista.
- Mapa por nodos (inicio, combate, bifurcación, descanso, conversación, gimnasio y jefe), captura, equipo de 6 con PC, centro Pokémon con tienda, derrota que vuelve al último punto de curación y guardado en el dispositivo.
- Jefe Pikachu (serie de jefes NN/20) que llama a un aliado a mitad de combate.
- Catálogo de 22 Pokémon, 1 jefe y 6 zonas, y un simulador que mide el balance del tramo (informe en `balance/informes/`).

Pendiente de la campaña: ajustar el equilibrio de Brock, la Pokéball, la evolución con XP, el diseño visual definitivo de las pantallas, los puntos al servidor y el resto de zonas. El detalle y las decisiones están en [`docs/D-20-modo-campana.md`](./docs/D-20-modo-campana.md).

Pendiente del resto: playtests en papel (los valores de balance salen del simulador), el formato digital, las salas multi-dispositivo (en pruebas, aparcadas) y el resto del [tablero](https://github.com/users/Ayme-99/projects/10). El diseño de juego está en el [Game Design Document](./incursiones_gdd.md).

## Planteamiento técnico

Monorepo: motor, simulador, app y backend viven en este repo.

- `engine/`: motor de partida en Dart puro (sin Flutter), con estado inmutable y registro de eventos. Incluye el motor de la campaña (`engine/lib/src/campana/`).
- `sim/`: simuladores Monte Carlo: balance de cada jefe y de los combates de la campaña.
- `catalog/`: catálogo de jefes y de la campaña (Pokémon, jefes, zonas y regiones) en JSON, con sus esquemas de validación.
- `balance/`: tablas de la fórmula de poder (CSV) e informes del simulador.
- `app/`: app Flutter independiente (no integrada en el Deck Tracker), pensada para "tablet en medio de la mesa".
- `server/`: backend Node (`/api/incursiones/*`), exportado como router para montarlo en el backend de Deck Tracker y reutilizar su despliegue en Render sin acoplar modelos de datos.
- `docs/`: notas de playtest, bocetos de interfaz y el diseño de la campaña (D-20).

## Documentación

- [`incursiones_gdd.md`](./incursiones_gdd.md) — Game Design Document (fuente de verdad del diseño de juego)
- [`docs/D-20-modo-campana.md`](./docs/D-20-modo-campana.md) — diseño del modo campaña: estado, decisiones y catálogo
- [`docs/`](./docs) — playtests y diseño de interfaz
- [`docs/DEPENDENCIAS.md`](./docs/DEPENDENCIAS.md) — qué hay que tocar en otro sitio cuando cambias algo (catálogo, contrato, balance, servidor externo)
- Tablero de trabajo: [GitHub Project #10](https://github.com/users/Ayme-99/projects/10)
