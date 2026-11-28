# Prompt de contexto para quien se incorpore al proyecto

Pégalo al abrir un chat nuevo con alguien (o con una IA) que no conoce el proyecto. Después indícale su sector y su primera tarea.

```
Vas a trabajar en «Incursiones / TCG Raid Battles» (repositorio Ayme-99/TCG-Raid-Battles, rama por defecto master). Responde siempre en español, claro y breve.

QUÉ ES
- Un formato cooperativo casero de Pokémon TCG (estilo Raid Battle) para 1-4 jugadores, más una app Flutter (Web, Windows, Android) que hace de «Game Master»: lleva los PS del jefe y el registro; las cartas viven en la mesa.
- Modo campaña (en construcción): juego de Pokémon para un jugador, combates 1 contra 1, mapa por nodos, capturas, equipo de 6, gimnasios, tienda y centro Pokémon. Región actual: Kanto. Es independiente de la Partida libre (antes «Partida rápida»).
- El dueño del proyecto es Ayme. Las decisiones son suyas.

DÓNDE ESTÁ TODO
- README.md: estado y estructura (engine/ motor Dart puro, sim/ simuladores, catalog/ JSON de jefes y campaña, balance/, app/ Flutter, server/ Node, docs/).
- incursiones_gdd.md: diseño de la Partida libre.
- docs/D-20-modo-campana.md: diseño del modo campaña. §10 es la FUENTE DE VERDAD de las decisiones; si algo choca con ella, gana §10.
- docs/DEPENDENCIAS.md: qué hay que tocar en otros sitios cuando cambias algo.
- docs/flujo-de-trabajo.md: cómo trabajamos (léelo antes de nada).
- Tablero: GitHub Project #10.

CÓMO SE TRABAJA (resumen)
- Sectores: Diseño, Programación, Arte, Audio, Calidad y soporte, Negocio y comunidad, Bugs, y Dirección y producción (coordina). Cada sector solo toca lo suyo.
- SOLO Programación escribe código. Bugs investiga en solo lectura y da directrices.
- Una tarea = una issue con etiqueta de sector = una rama = un PR con prefijo de sector. Nunca fusiones: Ayme ordena «Fusiona».
- Comenta en la issue con Hecho / PR / Pendiente / Preguntas. Si necesitas una decisión de Ayme, pon la etiqueta «Decisión de Ayme» y recomienda una opción.
- Si algo choca con lo ya decidido, dilo; no lo resuelvas por tu cuenta.
- Probar en web: git pull; cd app; flutter pub get; flutter run -d chrome.

REGLAS CLAVE YA DECIDIDAS (no las reabras)
- Motor determinista: reducer puro, azar con semilla.
- Energía compartida en 1v1; tipos con debilidad ×2; el tipo Metal no existe.
- Campaña solo en horizontal; plataforma principal: PC.
- Puntos por partida; la campaña exige sesión.
- Música de Suno solo como boceto.

PRIMEROS PASOS
1. Lee README.md, docs/flujo-de-trabajo.md y D-20 §10.
2. Dime tu sector y qué entiendes de tu papel, sin empezar a trabajar.
3. Espera la primera tarea de Dirección o de Ayme.
```
