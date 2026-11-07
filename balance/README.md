# balance/

Todo lo que sirve para equilibrar los jefes. **Fuente de verdad: archivos de texto versionados**, no una hoja externa.

- `tablas/*.csv`: tablas de la fórmula de poder (HP, daño esperado, rangos por nivel). Se editan en VS Code
  con la extensión Rainbow CSV (colorea columnas y permite consultas) o en Excel/LibreOffice, y se guardan como CSV.
- `informes/`: salida del simulador (`sim/`) por jefe y número de jugadores.

El simulador lee estas tablas, así que cambiar un CSV y volver a simular es todo el ciclo de balance.

## Hoja de balance de los jefes (T-31)

`hoja_balance.xlsx` resume los jefes del catálogo: HP, ataques, umbrales de invocación, aliados y su poder (HP × amenaza esperada) frente al de referencia del nivel. Es **solo de lectura**: el JSON de `catalog/` manda. Para cambiar una cifra, edita el JSON y regenera la hoja:

```
python3 balance/scripts/generar_hoja.py
```

Requiere `openpyxl`. Para que la hoja traiga valores calculados al abrirla en un visor sin fórmulas, recalcula con LibreOffice (`soffice --headless --convert-to xlsx`). La tolerancia del estado «OK/Revisar» (±25 %) es un supuesto editable en la pestaña `Leeme`.
