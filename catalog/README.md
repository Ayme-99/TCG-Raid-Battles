# catalog/

Catálogo oficial de jefes. Los jefes son **datos**, no código: se añaden editando JSON.

- `schema/boss.schema.json`: esquema que valida cada jefe (**borrador**, se cierra en la tarjeta T-13).
- `bosses/*.json`: un archivo por jefe, con HP, ataques propios, tipo de objetivo y efectos.

Cada jefe nuevo debe pasar la validación del esquema y tener su informe de simulación en `balance/informes/`.
