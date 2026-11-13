# catalog/

> Antes de cambiar un jefe o el esquema, mira [`docs/DEPENDENCIAS.md`](../docs/DEPENDENCIAS.md): hay copias en la app y en la hoja de balance.

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
    { "nombre": "Barrido", "dano": 60, "efecto": { "tipo": "contadorATodos", "valor": 1, "texto": "Pon 1 contador de daño en todos los Pokémon en juego" } },
    { "nombre": "Embestida", "dano": 120 }
  ],
  "invocacion": {
    "cadaHp": 300,
    "tirada": "moneda",
    "aliados": { "danio": {}, "tanque": {}, "cura": {}, "control": {} }
  }
}
```

- `ataques`: exactamente 3; la posición es la ranura (1 a 3). El objetivo de cada ataque no se guarda en el catálogo: sale de la carta de la baraja de ataques del jefe («Ataque X contra jugador Y», D-13 §7). `efecto` es opcional (D-14): `{tipo, texto, valor?, duracion?, conMoneda?}`. `tipo` es uno de los tipos del motor (`TipoEfectoAtaque`, ver `contrato/README.md`), `texto` es lo que lee la mesa, `valor` y `duracion` son enteros ≥ 1 y `conMoneda` indica que el ataque lanza moneda (la lanza la app y guarda el resultado en el evento).
- `invocacion` es opcional: un jefe sin ella nunca invoca (D-04 §7.1). Si está, el jefe llama a un aliado al terminar su primer turno y después cada `cadaHp` HP perdidos (T-71; máximo nivel + 1 llamadas, cada umbral una vez); `tirada` es cómo se tira (`moneda`, por defecto, o `segura`: sin moneda, cada intento invoca si hay slot libre).
- `aliados`: **uno por categoría** (`danio`, `tanque`, `cura`, `control`, `potenciador`, `debilitador`; D-13 y D-16). Las 6 son obligatorias. Cada aliado lleva `nombre`, `hp` y, si los tiene, `ataque` (`nombre`, `dano` y `texto`; un ataque sin daño, como Tóxico, lleva `dano` 0) y `habilidadNombre` + `habilidad`. Los textos son los de la carta, tal cual.
- `numero` (jefe y aliados) es el número de la carta en el set (01/28 → 1); la tabla completa está en `docs/CARTAS.md`.
- Recordatorios para la mesa (T-70), todos opcionales: `avisoAlEntrar` (lo que hay que hacer cuando el aliado entra; la app lo enseña con un «Hecho»), `avisoChequeo` (lo que hay que hacer en cada Chequeo Pokémon; la app lo pide antes de terminar el turno del jefe), `avisoTurno` (regla que se recuerda en el turno de cada jugador mientras el aliado está en juego o, si su efecto es permanente, el resto de la partida), `avisoAliadoCaido` y `avisoAlCaer` (cuando los jugadores derrotan a un aliado). En el ataque, `ignoraEfectos` recuerda que el daño no se ve afectado por los efectos del Defensor.
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
4. Genera su informe de simulación: `cd sim && dart run bin/sim_jefes.dart` (escribe `balance/informes/jefes_aliados.csv`).
5. El CI valida el esquema, que el `id` coincida con el nombre del archivo, que el índice liste exactamente los jefes de `bosses/` y que los scripts existan.
