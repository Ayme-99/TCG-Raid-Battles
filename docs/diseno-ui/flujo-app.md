# Flujo de la app (T-58, #231)

Flujo de producto de extremo a extremo: desde que se abre la app hasta que acaba una partida y se juega otra o se cierra. Aprobado por Ayme el 2026-11-15. Lo que aún no existe va marcado como **TODO** (no se diseña todavía).

## 1. Mapa

```
Abrir app
└─ Pantalla de inicio
   ├─ Bloque «Partida rápida»  [Nueva] [Continuar]
   │  ├─ Formato físico (siempre offline, sin puntos)
   │  │  ├─ Elegir jefe → la app recomienda el daño total del equipo → daño por jugador
   │  │  └─ Insertar daño por jugador → lista de jefes de ese nivel
   │  └─ Formato digital (solo online, da puntos): TODO
   ├─ Bloque «Campaña»  [Nueva] [Continuar]
   │  └─ Modo campaña (individual, 1 contra 1, ajeno a la partida rápida): ver D-20
   ├─ Pokédex
   │  ├─ Enemigos: jefes y aliados enfrentados, por expansión
   │  └─ Mis cartas (formato digital, vía tienda): TODO
   ├─ Tienda (monedas, dados, sobres y cartas sueltas, con los puntos de la campaña y de la partida rápida digital): TODO
   └─ Iniciar sesión
      ├─ Perfil
      ├─ Historial (partidas rápidas)
      └─ Amigos
```

## 1 bis. Formatos y puntos (decidido el 2026-11-15)

| | Formato físico | Formato digital |
|---|---|---|
| **Partida rápida** | **Siempre offline.** El host pone los nombres de los jugadores. **No da puntos.** | **Solo online.** Cada jugador usa las cartas que tiene desbloqueadas. **Da puntos** (la moneda del juego). |
| **Modo campaña** | No existe | **Individual, 1 contra 1.** Juego de Pokémon propio (energía, rutas, captura, medallas); **no** entrega cartas a la partida rápida. **Da puntos.** Diseño en [D-20](../D-20-modo-campana.md). |

- Los **puntos** son la moneda del juego (los dan la campaña y la partida rápida digital): sirven para comprar en una **tienda** (nueva, en la pantalla de inicio) monedas, dados, **sobres** y cartas sueltas del formato digital, y así ampliar la Pokédex. *Corregido el 2026-11-21: antes decía que la campaña entregaba las cartas de la partida rápida.*
- El **servidor** decide si una partida da puntos por su **formato** (`fisico` no, `digital` sí), que viaja en el registro (contrato v13).
- **Jugador 1** (el host) empieza siempre con su **nickname** si ha iniciado sesión, y se puede cambiar antes de entrar en la partida. Sin sesión se queda «Jugador 1».
- El formato digital aún no existe: no se diseña hasta que lo pidamos.

## 2. Pantalla de inicio

- **Dos bloques** (decidido por Ayme el 2026-11-28, D-20 §10.1): **Partida rápida** y **Campaña**. Cada uno tiene su botón **Nueva** y su botón **Continuar** (este solo está activo si hay una partida a medias de ese bloque; hoy la app la retoma sola al abrirse y pasa a ser una elección). Elegir el bloque sustituye al antiguo paso «Modo de juego» del asistente: **Nueva** de Partida rápida va directo a la elección de formato.
- Accesos a **Pokédex** y a **Cuenta** (iniciar sesión o, con sesión, perfil, historial y amigos).
- **Cuándo hace falta sesión** (decidido el 2026-11-25, D-20 §10.1; #390): solo la **partida rápida en formato físico** va **sin cuenta**: sin sesión se juega igual y los demás jugadores cuentan como invitados. **El modo campaña, el formato digital y la tienda exigen sesión**, y la **partida de campaña se guarda también en la cuenta**. Sin sesión, esos accesos llevan a **iniciar sesión y vuelven al acceso elegido** (confirmado por Ayme el 2026-11-25).

## 3. Preparación de una partida rápida en formato físico (offline)

Dos caminos, que son los modos de preparación de D-15:

| Camino | Pasos | Modo |
|---|---|---|
| Elegir jefe | jugadores → jefe → la tarjeta muestra el daño total recomendado → daño por jugador (aviso si no encaja, sin bloquear) | `jefe` (#106) |
| Insertar daño | jugadores → daño por jugador → el daño da el nivel → lista de jefes de ese nivel (hoy uno por nivel) | `equipo` (actual) |

La escena de llegada del jefe (#222) iría entre la elección y el primer turno, si se aprueba.

## 4. Durante la partida

Deshacer y rehacer, cuenta y envíos siguen en la barra flotante. **Abandonar** abre dos opciones:

- **Salir:** guarda la partida tal como está y vuelve al inicio. Aparecerá como **Continuar**.
- **Rendirse:** da la partida por perdida y pasa a la pantalla de fin de partida.

## 5. Fin de partida

Resultado, cómo ha ido cada jugador y guardado de resultados. **El formato físico no da puntos**, así que no se enseñan. Tres salidas:

- **Revancha:** mismos jugadores y equipo; vuelve al paso de elegir jefe de la misma vía.
- **Nueva partida:** vuelve a la elección de formato de la Partida rápida.
- **Volver al inicio.**

Si los resultados no se han guardado, cualquiera de las salidas pide confirmar antes de descartarlos (como hoy en «Nueva partida»).

## 6. Pokédex

Tiene **dos categorías**: **Mis cartas** y **Enemigos**. Por ahora solo existe **Enemigos**.

- **Enemigos:** jefes y aliados enfrentados, agrupados por expansión (de salida solo hay una).
- **Mis cartas:** las cartas del formato digital conseguidas en la tienda (sobres y cartas sueltas). **TODO.**
- Lo de la **partida rápida en formato físico** se guarda **en el dispositivo** y funciona sin sesión; al **iniciar sesión se sincroniza** con la cuenta y se actualiza.
- Lo que viene de la **campaña**, del **formato digital** y de la **tienda** (los jefes de campaña de «Enemigos» y «Mis cartas») **exige sesión** y se guarda en la cuenta (D-20 §10.1, D-21 §3.1).

## 7. Cuenta

Perfil, historial (partidas rápidas) y amigos exigen sesión y servidor. Hoy el servidor solo recibe el resultado final de cada partida: el historial se apoya en eso; los amigos y la sincronización del Pokédex necesitan modelo nuevo.

## 8. Fuera de alcance por ahora

Formato digital (campaña individual y partida rápida online), tienda de sobres, «Mis cartas», partida multi-dispositivo (#158, necesaria para la partida rápida digital) y modo por sobres.

## 9. Tareas derivadas

Ver las issues T-59 a T-64 enlazadas desde #231.
