# Contraste de #547, #554, #556 y #536 con D-20 (2026-11-27)

**Autor:** Calidad y soporte · **Issue:** #386 · Solo lectura de master (commit tras #556) y de D-20 §4, §9, §10.6 y §10.7. No se edita D-20.

## Resultado

Los cuatro PR coinciden con D-20 en lo decidido. Hay **una diferencia real** y **dos textos desfasados**.

| PR | Qué comprobé | Resultado |
|---|---|---|
| **#547** salvaje opcional en Rutas 3 y 4 | `kanto.json`: `ruta-3-final` → `ruta-3-salvaje` (opcional) o `centro-monte-moon`; `ruta-4-final` → `ruta-4-salvaje` o `centro-celeste`. Las zonas `ruta-3` y `ruta-4` incluyen Jigglypuff y Ekans. §4 filas 9 y 11, §4 tabla de zonas y fila de §10 (2026-11-27) | ✓ Coincide. Matiz: §4 filas 9 y 11 dicen «aquí sale Jigglypuff / Ekans», pero el nodo saca **al azar de toda la zona** (Ruta 3: Pidgey, Spearow, Nidoran♀, Nidoran♂, Mankey o Jigglypuff; Ruta 4: Rattata, Spearow, Sandshrew, Mankey o Ekans), así que Jigglypuff sale 1 de cada 6 y Ekans 1 de cada 5 veces. La fila de §10 lo dice bien; §4 se puede leer como «siempre sale». Mi simulador de partida salta los opcionales: con el catálogo nuevo da lo mismo que antes (Clefairy, Luis y Misty 100 %) |
| **#554** piedras evolutivas | `partida.dart`: Trueno, Agua, Fuego y Hoja a 2.100 desde la 4.ª medalla; Luna sin precio; piedra ex sigue a 2.000 desde la 2.ª. §4 (Partida), §9 fila 29, §10.6 y filas de §10 del 2026-11-27 | ✓ Coincide (2.100, 4.ª medalla, la Luna no se vende, se gasta una al evolucionar). **Texto desfasado:** el apartado de Pikachu y Raichu de D-20 (líneas «Raichu evoluciona con la Piedra Trueno, que todavía no se puede obtener» y «Piedra Trueno sigue siendo necesaria… hoy no se puede obtener») contradice la fila que lo da por decidido (se vende en Azulona a 2.100). **Pendiente conocido:** la Piedra Luna no está colocada en `kanto.json` (pregunta abierta en #546); hoy no se puede conseguir |
| **#556** zonas de Arte, Pueblo Paleta y Ciudad Verde | `pueblo-paleta`: laboratorio = `inicial`, camino de arriba → `ruta-1`; `ciudad-verde-salida`: centro → `ciudad-verde`, izquierda → `ruta-22`, arriba → `ruta-2`. Nota de §4 (Escenas) | ✓ Coincide con lo que dice §4 |
| **#536** Ruta 22 de Arte | Solo trae la escena vectorial y `ruta-22.zonas.json` (entrada abajo, hierba a la izquierda = combate, pórtico arriba → `ruta-2`) | **Diferencia:** el catálogo (`ruta-22` en `kanto.json`) sigue con las **zonas de marcador** (bordes izquierdo y derecho, hierba centrada), que no son las de Arte. D-20 §4 dice que Ruta 22 «no cambia» hasta #536; #536 ya está en master, así que toca copiar las zonas de Arte como se hizo con #501 (Ruta 1) y #556. Es de Programación |

## Filas 18 y 19 de D-20 §9

- **Fila 18 (XP y número de ex):** medida en `campana_xp_ex_2026-11-24.md` (§1 XP de la ruta principal, §3 repetir salvajes para llegar a 12 ex, §4.1 medallas de los ex 2/3/4). **Límite:** los tramos 2 a 8 son supuestos (el informe lo dice); solo el tramo 1 es XP medida. El tramo 2 ya existe en master, así que se puede actualizar con su XP real cuando Diseño quiera.
- **Fila 19 (repetir Brock con Pociones):** medida en `campana_xp_ex_2026-11-24.md` §4.2 (motor e IA reales, #465): **no hacen falta Pociones para llegar al 75 %** (Brock 77 / 98 / 98 % sin evolución y 99 / 97 / 100 % con ella con 5 Balls), y el dinero limita cuántas se pueden comprar. Repetida con la regla del rival que empieza en gimnasios en `campana_empieza_2026-11-26.md` (Brock con evolución 98,7 / 80,8 / 100 % sin Pociones; Charmander sube a 97,9 % con 1) y con el tramo 2 en `campana_tramo2_2026-11-27.md`.

Sí está medido en las dos filas; que las marque Diseño.

## Ya corregido por otros sectores

D-20 §9 filas 16, 17 y 26–28 y D-21 («hasta Brock») están al día tras mi aviso de esta mañana (#549, #542).
