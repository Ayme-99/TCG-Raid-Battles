# server/

Backend Node de Incursiones (namespace `/api/incursiones/*`): guarda resultados de partidas y sirve el catálogo.

Vive en este repo (monorepo con `app/` y `engine/`). Se exporta como un router de Express para
montarlo en el backend de Deck Tracker y reutilizar su despliegue, sin acoplar modelos de datos.
Ver tarjeta T-04 / H-01.
