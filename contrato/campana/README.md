# Contrato de la campaña con la cuenta

Esquemas JSON (draft 2020-12) de lo que la app manda al servidor en el modo campaña. Son **aparte** del registro de partida de las incursiones (`../partida.v*.schema.json`), como dice D-20 §6.

| Archivo | Qué es |
|---|---|
| `guardado.v1.schema.json` | Cuerpo de `PUT /campana/partidas/:campana`: la partida de campaña guardada en la cuenta (#478). |
| `hitos.v1.schema.json` | Cuerpo de `POST /campana/hitos`: los hitos de la campaña que abonan puntos a la cuenta, con id único y tope por tipo (#374, D-20 §6). Ejemplos en `ejemplos/hitos/` (`server/test/campana_hitos.test.js`). |
| `compra.v1.schema.json` | Cuerpo de `POST /tienda/compras`: una compra en la tienda de puntos. Comprar baja el total de la cuenta, y los jefes ya desbloqueados siguen desbloqueados (#374, D-21 §1.2). Ejemplos en `ejemplos/compra/` (`server/test/tienda.test.js`). |
| `ejemplos/guardado/validos/`, `ejemplos/guardado/invalidos/` | Ejemplos que el esquema acepta y rechaza (`server/test/campana_guardado.test.js`). Los válidos los lee también el motor (`engine/test/campana_guardado_test.dart`), así que tienen la forma de `PartidaCampana.aJson()`. |

## Partida guardada en la cuenta (#478)

Decidido por Ayme el 2026-11-24 (#390): la partida de campaña se guarda también en la cuenta; la sesión es obligatoria para jugar la campaña.

```json
{ "version": 1, "revision": 0, "partida": { "version": 2, "progreso": { "...": "..." }, "...": "..." } }
```

- `partida` es `PartidaCampana.aJson()` tal cual. Si el motor sube su versión o añade un campo, hay que actualizar este esquema en el mismo PR.
- `revision` es la que el cliente leyó (`0` si no había). El servidor guarda con `revision + 1`; si la guardada es otra, responde `409 revision_distinta` con su copia, y la app decide.
- **El guardado nunca abona puntos.** Los puntos de la campaña van a la cuenta por los hitos (#374).
