# Flujo de la app (T-58, #231)

Flujo de producto de extremo a extremo: desde que se abre la app hasta que acaba una partida y se juega otra o se cierra. Aprobado por Ayme el 2026-11-15. Lo que aún no existe va marcado como **TODO** (no se diseña todavía).

## 1. Mapa

```
Abrir app
└─ Pantalla de inicio
   ├─ Iniciar / Continuar partida
   │  └─ Modo de juego
   │     ├─ Partida libre
   │     │  ├─ Formato físico
   │     │  │  ├─ Elegir jefe → la app recomienda el daño total del equipo → daño por jugador
   │     │  │  └─ Insertar daño por jugador → lista de jefes de ese nivel
   │     │  └─ Formato digital: TODO
   │     └─ Modo campaña: TODO
   ├─ Pokédex
   │  ├─ Jefes y aliados enfrentados, por expansión
   │  └─ Cartas obtenidas (cuando haya campaña y formato digital): TODO
   └─ Iniciar sesión
      ├─ Perfil
      ├─ Historial (partidas libres)
      └─ Amigos
```

## 2. Pantalla de inicio

- Botón principal: **Nueva partida**, o **Continuar** si hay una a medias (hoy la app la retoma sola al abrirse; pasa a ser una elección).
- Accesos a **Pokédex** y a **Cuenta** (iniciar sesión o, con sesión, perfil, historial y amigos).
- La sesión nunca es obligatoria: sin ella se juega igual y los demás jugadores cuentan como invitados.

## 3. Preparación de una partida libre en formato físico

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

Resultado, puntos y guardado de resultados (como hoy), con tres salidas:

- **Revancha:** mismos jugadores y equipo; vuelve al paso de elegir jefe de la misma vía.
- **Nueva partida:** vuelve a la elección de modo.
- **Volver al inicio.**

Si los resultados no se han guardado, cualquiera de las salidas pide confirmar antes de descartarlos (como hoy en «Nueva partida»).

## 6. Pokédex

- Se guarda **en el dispositivo** y funciona sin sesión.
- Al **iniciar sesión se sincroniza** con la cuenta y se actualiza.
- Registra jefes y aliados enfrentados, agrupados por expansión (de salida solo hay una).

## 7. Cuenta

Perfil, historial (partidas libres) y amigos exigen sesión y servidor. Hoy el servidor solo recibe el resultado final de cada partida: el historial se apoya en eso; los amigos y la sincronización del Pokédex necesitan modelo nuevo.

## 8. Fuera de alcance por ahora

Formato digital, modo campaña, cartas obtenidas, partida multi-dispositivo (#158) y modo por sobres.

## 9. Tareas derivadas

Ver las issues T-59 a T-64 enlazadas desde #231.
