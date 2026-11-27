# Efectos del tramo 2 contra D-20 §3.6, con las cartas reales

**Fecha:** 2026-11-27 · **Autor:** Calidad y soporte · **Issue:** #386 · **Solo informe y una sonda en `sim/`**: no se decide nada ni se toca motor, cartas ni D-20.

Sonda: `sim/bin/sim_efectos_tramo2.dart` (2000 semillas por prueba, motor y catálogo de master, cartas reales de Starmie, Jigglypuff, Shellder, Ekans, Paras y Clefairy jefe). Salida completa: `campana_tramo2_2026-11-27/efectos_tramo2.txt`. Los tests del motor existentes usan cartas de prueba; esto comprueba lo mismo con las cartas que ya están en el catálogo. (En este entorno no se pueden ejecutar los tests del motor porque `pub` no descarga `test`; la sonda solo necesita el propio motor.)

## Resultado: todo coincide con D-20 §3.6

| Efecto | Qué dice §3.6 | Medido |
|---|---|---|
| **Rapidez de Starmie** (`ignoraFallo`, #535) | No lanza la moneda de Bofetón Lodo ni de Pantalla de Humo; la de Confundido sí | Con Bofetón Lodo y con Pantalla de Humo pega el **100 %**; con Confundido, el **50 %**. La semilla no avanza (no se lanza moneda). La IA elige Rapidez con Bofetón Lodo encima 200/200 veces |
| **Dormido** (Canto de Jigglypuff, #530) | Moneda en cada chequeo; no ataca ni cambia con Cambiar; sí cargar, Poción y Cuerda Huida; al banco se cura | Llega dormido a su turno el **25 %** (1 de cada 4, como dice §3.6); despierta en ≤2 chequeos el **75 %**; ataque y Cambiar dan error de regla; cargar, Poción y Cuerda Huida funcionan y la Cuerda lo deja despierto |
| **Apresado** (Torbellino de Shellder, Constricción de Ekans, #532) | No cambia salvo Cuerda Huida; 10 PS por chequeo; moneda de liberación; se cura al banco | Ataque más primer chequeo quitan **20 PS seguros** (10+10) en las dos cartas; sigue apresado el **50 %**; no puede cambiar, sí atacar y cargar; la Cuerda lo libera. **Contra Clefairy jefe (Muro Mágico) solo recibe el golpe de 10, sigue apresado el 50 % y la moneda se lanza igual**, como dice §3.6 |
| **Absorber de Paras** (`curaAlAtacar`, #533) | Tras su daño cura 10 sin pasar del máximo; cura igual al rematar y contra Muro Mágico; no cura si el ataque falla | 30→40 PS; con 50/50 se queda en 50; remata (35→45) y el combate termina; contra Clefairy jefe cura (30→40); con Bofetón Lodo cura el 50 % y no cura cuando falla (50 %) |
| **Muro Mágico de Clefairy jefe** | Bloquea veneno, Drenadoras y apresar | Comprobado con apresar (arriba) |

## Una observación (no es un fallo; decide Diseño o Ayme)

**Doble Bofetón de Clefairy jefe**: el JSON lleva `dano: 30` y `danoPorCaras: [20, 30, 40, 50]` con 3 monedas, y el texto de la carta dice «10 puntos más por cada cara». El daño real medido es 20 / 30 / 40 / 50 con 12,6 / 37,4 / 37,4 / 12,6 %, es decir, **35 de media**. D-20 §3.6 dice que el `dano` del JSON es el daño esperado y lo usa solo la IA y el baremo; aquí el esperado teórico es **35**, no 30. Para el jefe no cambia nada (la IA solo tiene ese ataque), pero conviene que el JSON y el texto de la tabla de D-20 §4 («20+») digan lo mismo. Lo mismo vale para Jigglypuff, que tiene el mismo ataque con `dano: 30`.

## Cómo repetirlo

```
cd sim && dart run bin/sim_efectos_tramo2.dart --semillas=2000
```
