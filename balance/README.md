# balance/

Todo lo que sirve para equilibrar los jefes. **Fuente de verdad: archivos de texto versionados**, no una hoja externa.

- `tablas/*.csv`: tablas de la fórmula de poder (HP, daño esperado, rangos por nivel). Se editan en VS Code
  con la extensión Rainbow CSV (colorea columnas y permite consultas) o en Excel/LibreOffice, y se guardan como CSV.
- `informes/`: salida del simulador (`sim/`) por jefe y número de jugadores.

El simulador lee estas tablas, así que cambiar un CSV y volver a simular es todo el ciclo de balance.
