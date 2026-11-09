# D-02 · Daño máximo para calcular X

Estado: decidido (2026-11-05). Issue #14.

## 1. Qué es X

X = suma, de todos los jugadores, del **daño máximo** del mejor ataque de sus 2 Pokémon (el más alto de los dos cuenta como el de ese jugador). Es la definición oficial (D-03 §3). X se calcula una sola vez en el setup (D-01).

## 2. Quién lo introduce

**Cada jugador introduce a mano el número de su mejor ataque** en el asistente. Todos los jugadores ven los números en pantalla y pueden compararlos con la carta física en la mesa antes de confirmar. El asistente no necesita un catálogo de cartas.

- El asistente muestra, por jugador, sus 2 Pokémon y el número elegido, y la suma X.
- Hasta que no se confirma el setup, cualquiera puede corregir su número. Tras confirmar, ya no se cambia (D-01).

## 3. Qué número cuenta

La mesa acuerda el número de cada jugador, **sin tope** (hay cartas de más de 200 de daño; con tope, Nv4 sería inalcanzable). La app solo recibe un entero por jugador, nunca negativo, y no interpreta el texto de la carta.

Criterio para llegar al acuerdo:

| Caso | Número |
|---|---|
| Daño fijo («120») | el impreso |
| «30+» / «50×» sin tope claro | el impreso, o el valor que acuerde la mesa |
| Daño por contadores de daño o premios («20× por contador») | el valor que acuerde la mesa, por ejemplo con los contadores a media vida (HP ÷ 20 contadores) |
| Daño por Energía (en la partida no hay Energía) | solo el base impreso (Max Burst de Rayquaza VMAX = 20) |
| Bonus fijo condicional («+20 si…») | la mesa decide si se suma |
| «No puede atacar el próximo turno» | el daño impreso (la penalización se aplica en la partida, no en X) |

Los modificadores de la partida (habilidades, cartas de ánimo, debilidad) **no** cuentan para X.

## 4. Anti-manipulación

- Los 2 Pokémon declarados en el setup son los que se juegan, y quedan fijados al ver el nivel (D-01).
- El resto de la mesa puede comprobar la carta física antes de confirmar.
- No hay verificación técnica: el formato es cooperativo.

## 5. Casos límite

- **Un jugador introduce 0** (Pokémon sin ataque con daño): vale; cuenta 0.
- **Desacuerdo en la mesa**: se usa el número impreso en la carta.
- **Número mayor de 200**: vale tal cual (antes se recortaba a 200; con X > 800 para Nv4 el tope lo haría inalcanzable).
- **Mesa que usa máximos teóricos más altos que el base**: X sube y el nivel puede subir. La calibración del simulador (D-03 §8.4) usa el daño base, así que los niveles quedan algo más duros de lo medido. Se revisa en T-17 (playtests).

## 6. Cambios en otros documentos

- `incursiones_gdd.md` → v0.9: D-02 fuera de §7, nota sobre X en la sección de setup.
- `docs/D-01-setup.md`: la referencia a D-02 apunta a este documento.
