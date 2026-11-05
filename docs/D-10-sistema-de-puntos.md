# D-10 · Sistema de puntos

Estado: **propuesta para validar** (2026-11-05). Issue #10.

## 1. Qué decidió Ayme

- Los puntos son **solo por equipo**: un único contador común del grupo, no hay puntos individuales.
- Los puntos **no son una puntuación competitiva**. Sirven para **desbloquear jefes nuevos**.
- D-10 incluye las reglas y el **modelo de datos del guardado**.

## 2. Reglas propuestas

1. **Equipo**: el grupo que juega junto. Tiene un total de puntos acumulado. La identidad exacta del equipo depende de D-11.
2. **Cuándo se ganan puntos**: solo al ganar una partida. Una derrota da 0 (no hay puntos de participación).
3. **Cuántos**: dependen del nivel del jefe, ver `balance/tablas/puntos_niveles.csv`: Nv1 = 1, Nv2 = 2, Nv3 = 3, Nv4 = 5.
   Los valores siguen la dificultad medida en D-03 (victoria objetivo 75 / 50 / 30 / 15 %): así los puntos esperados por intento quedan parecidos entre niveles y no compensa jugar siempre el nivel más fácil ni el más difícil.
4. **No dependen** del número de jugadores ni del jefe concreto, solo del nivel.
5. **Desbloqueo**: los 7 jefes de lanzamiento están disponibles desde el principio. Cada jefe nuevo (añadido por actualización) tiene un coste en puntos, ver `balance/tablas/desbloqueo_jefes.csv`.
6. **Los puntos no se gastan**: se compara el total acumulado con el coste. Un jefe desbloqueado no se vuelve a bloquear.

## 3. Ejemplo numérico

Un equipo juega 6 partidas: gana Nv1, Nv1, Nv2, Nv2, pierde Nv3, gana Nv3.
Puntos = 1 + 1 + 2 + 2 + 0 + 3 = 9. Con 9 puntos desbloquea el jefe extra de Nv1 (5 puntos). El de Nv2 (12) queda a 3 puntos.

## 4. Modelo de datos del guardado

Se guarda el **registro de partidas** y los puntos se **calculan** a partir de él (el total no se guarda como dato primario). Así se puede recalcular si cambia la tabla de puntos y no hay dobles contabilizaciones.

| Colección | Campos |
|---|---|
| `equipos` | `_id`, `nombre`, `creado` (la identidad real, D-11) |
| `partidas` | `_id`, `equipo_id`, `fecha`, `jefe_id`, `nivel`, `jugadores` (nº), `resultado` (victoria/derrota), `puntos` (copia al cerrar la partida) |
| `desbloqueos` | `equipo_id`, `jefe_id`, `fecha`, `puntos_en_ese_momento` |

- Los puntos de una partida se calculan al terminarla con la tabla vigente y se guardan en `partidas.puntos`, para que cambios futuros de la tabla no reescriban el historial.
- El total del equipo = suma de `partidas.puntos`.
- Un jefe está disponible si es de lanzamiento o existe en `desbloqueos`. El desbloqueo se crea automáticamente al cruzar el umbral.
- Una partida se guarda **una sola vez** (clave `_id` generada por el cliente), para que reintentos de red no sumen dos veces.

## 5. Preguntas abiertas

- **D-11**: qué es un equipo (cuenta compartida, código de grupo o dispositivo). Mientras no se decida, `equipo_id` es un identificador opaco.
- **Costes de desbloqueo**: los valores del CSV son un ejemplo. Dependen de cuántos jefes extra se publiquen y de cada cuánto.
- **Partidas con pocos jugadores**: se proponen los mismos puntos. Confirmar si se quiere distinguir.
- **Derrotas**: se propone 0. Si se quiere suavizar el avance, se puede dar 1 punto por derrota.
