# Partida rápida (antes «Partida libre»): estado real y pendientes (#587)

**Fecha:** 2026-11-28 · **Autor:** Calidad y soporte · **Versión:** master `74dbe6a` · **Solo diagnóstico:** no cambia código ni reglas.

**Decidido por Ayme el 28-11:** «Partida rápida» y «Partida libre» son lo mismo; en adelante se llama **«Partida rápida»**. Eso contesta la pregunta de la issue.

## Cómo lo he revisado (y lo que no)

**No he podido jugarla en la web** (sin Flutter en esta sesión, `pub.dev` bloqueado, el navegador no alcanza mi máquina). He revisado: el código de la app y del motor, los 6 controles del CI sobre master (todos en verde: motor, app, contrato, hoja de balance, simulador y web), los documentos (GDD, D-10, D-15, D-19, `flujo-app.md`, D-21) y he ejecutado el simulador de jefes (`sim/bin/sim_jefes.dart`). Lo que marco «sin jugar» necesita a alguien con la web.

## Estado real

| Parte | Estado | Evidencia |
|---|---|---|
| **Partida rápida en formato físico** (offline, sin puntos, un dispositivo, el host lo apunta todo) | **Hecha y completa en código:** preparación por jefe o por daño (D-15), turnos de jugadores y del jefe, aliados, cartas de ánimo, monedas y dados, abandonar (salir o rendirse), fin de partida con revancha, guardar y continuar, Pokédex de enemigos | Motor: 41 archivos de test; app: 35; CI de master en verde. **Sin jugar en pantalla** |
| **Jugar en sala** (un dispositivo por jugador, D-19) | **Hecha en código:** botón «Jugar en sala» en el inicio, crear o unirse con código, sala de espera, host autoritativo, desconexión (2 min), turno automático del jefe; el servidor tiene `salas.js` y `ws.js` | Tests de cliente, controlador y pantallas de sala, y del servidor. **Sin jugar con dos dispositivos** |
| **Formato «Digital»** del asistente «Nueva partida» | **Bloqueado:** la opción «Digital – Cartas y dados dentro de la app» sale apagada (`opcion-digital`, `bloqueada: true`). El formato digital como producto (cartas digitales, que dé puntos) **no existe** | `app/lib/pantallas/nueva_partida.dart`; `flujo-app.md` §1 bis y §8 |
| **Puntos de la partida rápida digital** | **Sin implementar:** solo la campaña da puntos; la física no los da; el servidor decide por el formato (`fisico` no, `digital` sí) | D-10, `flujo-app.md`; GDD §7 («pendiente de revisar», 2026-11-15) |
| **Tienda de puntos del menú** | **Hecha** (monedas y dados, #374); sobres y cartas sueltas no hay | `app/lib/tienda`; D-21 §2 |
| **«Mis cartas»** (Pokédex, cartas digitales) | **No existe** | `flujo-app.md` §6 |
| **Balance de los 4 jefes** | **Desviado** (simulador, 150 equipos × 60 partidas, 4 jugadores): Onix 66,0 / 69,9 / 53,2 % (solo dueño / ayuda / solo jefe) frente al objetivo de 75 %; Manectric 59,1 / 63,0 / 43,7 frente a 50 %; Kingdra 35,5 / 36,3 / 37,3 frente a 30 %; Arceus 18,2 / 18,0 / 25,0 frente a 15 %. **Cota optimista:** solo modela los aliados de Onix y sin veneno ni quemadura | Salida de `sim_jefes.dart` de hoy |
| **Activo y Banca** en el motor | **Pendiente conocido:** «el motor aún no distingue Activo y Banca» (GDD §3, D-05) | `incursiones_gdd.md` |
| **Issues abiertas de la Partida rápida** | **Ninguna.** Las 15 issues abiertas son de la campaña (Arte, Audio, Negocio, Calidad, Bugs) | Lista de issues de hoy |

**Dónde sale todavía «Partida libre»** (para el cambio de nombre): app, 2 textos del asistente (`nueva_partida.dart`), 1 comentario (`fin_partida.dart`) y 1 test (`pantallas_test.dart`); documentos: `flujo-app.md` (14), D-21 (15), D-20 (10), D-10 (3), GDD (2), `README.md`, `mapa-pantallas.md`, `campana-sonido.md` y `campana-wireframes-apaisados.md` (1 cada uno).

## Pendientes propuestos (por orden)

| # | Tarea | Sector | Depende de Ayme |
|---|---|---|---|
| 1 | **Cambiar el nombre a «Partida rápida»** en la app (2 textos, 1 comentario, 1 test) y en los documentos (unas 48 menciones en 11 archivos, con una fila en el GDD). Barata y ya decidida | Programación (app) y Diseño (documentos; Negocio en D-21) | No: ya lo ha decidido |
| 2 | **Jugarla de principio a fin en la web**, como se hizo con los 10 flujos de la campaña (#589): un guion de flujos de la Partida rápida (preparación por jefe y por daño, turnos, aliados, abandonar, fin, revancha, continuar) y una issue «Bugs» por fallo. Incluye **probar «Jugar en sala» con dos dispositivos** | Calidad con Bugs | Sí, para jugarla con él o con alguien con la web (yo no puedo ejecutarla) |
| 3 | **Calibrar el balance de los 4 jefes**: ampliar el simulador a los aliados de Manectric, Kingdra y Arceus y a veneno y quemadura, y proponer ajustes. Hoy Onix queda 5 a 9 puntos por debajo del objetivo y Kingdra y Arceus por encima | Calidad (simulador); Diseño (cartas) | Sí: confirmar que los objetivos 75 / 50 / 30 / 15 % siguen valiendo para la Partida rápida |
| 4 | **Decidir el formato digital**: qué son las «cartas y dados dentro de la app», qué se vende en la tienda (sobres, cartas sueltas, «Mis cartas»), cuántos puntos da y cómo se desbloquean los jefes (revisar el modelo de D-10 y GDD §7) | Diseño propone; Ayme decide; luego Programación y Arte | **Sí, es lo que más depende de él** |
| 5 | **Una sola entrada a jugar con varios dispositivos**: hoy hay un botón «Jugar en sala» en el inicio y a la vez una opción «Digital» apagada en «Nueva partida». Decidir si «Digital» pasa a llevar a la sala y qué hace mientras no haya cartas digitales | Diseño (propone) y Programación | Sí |

Fuera de la lista, por si se retoma: separar Activo y Banca en el motor (D-05) y actualizar la hoja de balance si se cambian los objetivos.

## Qué no he podido comprobar

- Que la Partida rápida física se juegue bien de principio a fin en la web.
- Que «Jugar en sala» funcione con dos dispositivos y con el servidor real.
- Que el catálogo de los 4 jefes (Onix, Manectric, Kingdra y Arceus) tenga todos los aliados descritos en D-13 y D-16 en el simulador (solo modela los de Onix).
