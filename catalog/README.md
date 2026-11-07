# catalog/

Catálogo oficial de jefes. Los jefes son **datos**, no código: se añaden editando JSON.

| Ruta | Qué es |
|---|---|
| `bosses/<id>.json` | Un archivo por jefe. El nombre del archivo es su `id`. |
| `catalogo.json` | Índice: la `version` del catálogo y la lista de ids de `bosses/`. |
| `schema/boss.schema.json` | Esquema de un jefe (formato 1). |
| `schema/catalogo.schema.json` | Esquema del índice. |
| `ejemplos/validos/`, `ejemplos/invalidos/` | Jefes de ejemplo (no son jefes reales ni llevan números de juego) que los tests usan para comprobar el esquema. |

## Un jefe

```json
{
  "formato": 1,
  "id": "ejemplo-nv1",
  "nombre": "Jefe de ejemplo",
  "nivel": 1,
  "hp": 1000,
  "ataques": [
    { "nombre": "Golpe", "dano": 30 },
    { "nombre": "Barrido", "dano": 60, "efecto": "Daña a todos los Pokémon activos" },
    { "nombre": "Embestida", "dano": 120 }
  ],
  "invocacion": {
    "cadaHp": 300,
    "tirada": "moneda",
    "aliados": { "danio": {}, "barrera": {}, "cura": {}, "picaro": {} }
  }
}
```

- `ataques`: exactamente 3; la posición es la ranura (1 a 3). El objetivo de cada ataque no se guarda en el catálogo: sale de la carta de la baraja de ataques del jefe («Ataque X contra jugador Y», D-13 §6). `efecto` es opcional.
- `invocacion` es opcional: un jefe sin ella nunca invoca (D-04 §7.1). Si está, `cadaHp` es cada cuántos HP perdidos hay un intento y `tirada` es cómo se tira (hoy solo `moneda`, que es el valor por defecto).
- `aliados`: **uno por categoría** (`danio`, `barrera`, `cura`, `picaro`), todas obligatorias (D-13). Cada aliado lleva `nombre`, `hp` y, si los tiene, `ataque` (`nombre` y `dano`) y `habilidad`.
- Quién aplica los efectos de la carta del aliado: `efectos` es `jugador` (por defecto) o `programa`. Con `programa` hay que indicar `scriptId`; con `jugador` no se admite. Un test del motor (`engine/test/catalogo_scripts_test.dart`) comprueba que ese script existe en el motor.

Ver `ejemplos/validos/jefe-con-aliados.json` para un jefe completo.

## Versionado y actualizaciones

- `formato` (en cada jefe) es la versión del **esquema**. Si el esquema cambia de forma que rompe los jefes existentes, sube a 2 y los jefes se migran.
- `version` (en `catalogo.json`) es la versión del **contenido**: sube en 1 con cada cambio del catálogo (jefe nuevo o modificado).
- El catálogo viaja **dentro de la app**: un jefe nuevo exige publicar una versión nueva de la app (decidido en T-13).

## Añadir un jefe

1. Crea `bosses/<id>.json` (el `id` en minúsculas, números y guiones).
2. Añade el id a `catalogo.json` y sube su `version`.
3. Si algún aliado usa `programa`, el script tiene que existir antes en el motor (`engine/lib/src/scripts_aliado.dart`).
4. Genera su informe de simulación en `balance/informes/`.
5. El CI valida el esquema, que el `id` coincida con el nombre del archivo, que el índice liste exactamente los jefes de `bosses/` y que los scripts existan.
