# server/

Backend de Incursiones: el namespace `/api/incursiones/*`. Guarda las partidas terminadas, abona los puntos a las cuentas y los consulta.

Es un **módulo Express** (no un servidor): `crearRouter(...)` devuelve un router que se monta en el backend de Deck Tracker, y reutiliza su despliegue, su base de datos y su autenticación. Vive en este repo (monorepo con `engine/` y `app/`).

## Qué valida

1. **Estructura**, con el esquema de la versión que declara el registro (1 a 7; [`../contrato/`](../contrato/README.md)): `400 estructura_invalida` o `400 version_no_soportada`. Las versiones conviven y el registro se guarda tal cual llegó.
2. **Que el usuario juega en la partida**: su cuenta debe estar en `cuentas` (`403 no_participas`).
3. **Coherencia del resumen** (`src/coherencia.js`): el nivel y el jefe son los del registro, el resultado cuadra con el daño y el abandono, `puntosTotal` sale de la fórmula de D-10, el reparto por puesto y los abonos cuadran con las cuentas y, en la versión 2, las aplicaciones de estados de cada jugador (se recuentan a partir de los eventos) y su bono de D-12 (`422 resumen_incoherente`, con la lista de motivos).
4. **Que las cuentas existen** (`422 cuenta_desconocida`).

**No ejecuta las reglas del juego.** El servidor se fía de que los eventos son una partida legal; solo detecta resúmenes que no cuadran. Si hiciera falta más (los puntos desbloquean jefes), habría que reproducir el log en el servidor: portar el motor a JS o ejecutar Dart. Queda como decisión aparte.

## Endpoints

Todos requieren sesión. Los errores tienen la forma `{ "error": "codigo", "mensaje": "...", ... }`.

| Método y ruta | Qué hace |
|---|---|
| `POST /partidas` | Guarda una partida terminada (el registro completo del contrato, con `resumen`). Es **idempotente** por `partidaId`: `201` la primera vez, `200` con `duplicada: true` si llega otra vez igual (no suma puntos de nuevo), `409 partida_distinta` si el id ya existe con otro contenido. Responde `tusPuntos` (reparto más bono). |
| `GET /partidas?limite=20&despues=<cursor>` | Historial de la cuenta, de la más reciente a la más antigua. `limite` de 1 a 50. Devuelve `partidas` (resumen de cada una con `miPuesto` y `misPuntos`) y `siguiente` (cursor, `null` en la última página). |
| `GET /partidas/:id` | El registro completo de una partida. `404` si no existe o si la cuenta no jugó en ella. |
| `GET /me/puntos` | `puntos` acumulados (solo lo abonado; no se gastan), `partidas` jugadas y, por nivel, `coste`, `alcanzado` y `faltan` para desbloquear jefe nuevo. |

Los invitados ocupan puesto en el reparto pero no cobran ni el reparto ni el bono (D-10, D-11, D-12). A una cuenta se le abona `puntos + bonoEstados` de cada partida; el bono queda fuera de `puntosTotal`.

## Datos

Dos colecciones, el modelo de D-10 §5 (`src/repoMongo.js`):

- `incursiones_partidas`: una por partida (`_id` = `partidaId`), con el registro completo y los datos del resumen.
- `incursiones_partida_jugadores`: una por asiento, con lo que se abona. Índice único `(partidaId, asiento)`.

Los totales de una cuenta **se calculan sumando sus filas**, nunca se guardan, así que un reintento no puede sumar dos veces. Si un intento se corta entre las dos colecciones, el reintento completa las filas que faltan.

## Montaje en Deck Tracker

```js
const { crearRouter, crearRepoMongo } = require('./incursiones/server/src');

const repo = crearRepoMongo(mongoose.connection.db); // o el Db del driver nativo
await repo.asegurarIndices(); // una vez al arrancar

app.use('/api/incursiones', crearRouter({
  repo,
  autenticar: verificarJwt,                  // el middleware que ya usa Deck Tracker
  usuarioDe: (req) => String(req.user.id),   // de dónde sale el id de cuenta
  existenCuentas: async (ids) => {           // ids que no existen
    const hay = await User.find({ _id: { $in: ids } }).distinct('_id');
    const set = new Set(hay.map(String));
    return ids.filter((id) => !set.has(id));
  },
}));
```

El router incluye `express.json` (límite de 1 MB). `express` es una dependencia del host; aquí solo se usa en los tests. Los esquemas se leen de `../contrato/partida.vN.schema.json` (una por versión): al montarlo, hay que llevar esa carpeta (`crearValidador(carpeta)` acepta otra ruta) o pasar un `validar` propio.

## Tests

```
cd server
npm ci
npm test                                   # los de MongoDB se saltan
MONGO_URL=mongodb://localhost:27017 npm test   # también contra una base real
```

El CI ejecuta todo con un MongoDB 7. Las mismas pruebas de repositorio valen para el de memoria y el de MongoDB (`test/repo.test.js`).
