# Dependencias: qué tocar cuando cambias algo

El proyecto repite datos y reglas en varios sitios (Dart, Node, JSON, CSV, la app, otro repo). Este documento dice, para cada cambio, **qué más hay que cambiar** y **quién te avisa si se te olvida** (CI) o si **no te avisa nadie** (hay que hacerlo a mano).

**Regla de oro:** antes de cambiar un dato o una regla, busca su fila en la sección 1. Si no está, añádela en la misma PR en la que lo cambies.

Leyenda de la columna «Avisa»: ✅ un test del CI falla si se desincroniza · ⚠️ el CI lo comprueba solo en parte (se explica) · ❌ no lo comprueba nadie.

## 1. Mapa de dependencias

| Si cambias… | Hay que cambiar también… | Avisa |
|---|---|---|
| Un jefe en `catalog/bosses/*.json` (HP, ataques, aliados, invocación) | La copia de la app: `app/tool/sync_catalogo.sh` (copia a `app/assets/catalogo/`) | ✅ `app/test/catalogo_test.dart` (copia idéntica) |
| | El índice `catalog/catalogo.json`: sube su `version` en 1 (en cada cambio de contenido) | ❌ (solo comprueba que lista los jefes que existen) |
| | La hoja de balance: `python3 balance/scripts/generar_hoja.py`, recalcular con LibreOffice y subir `balance/hoja_balance.xlsx` | ✅ `balance/scripts/comprobar_hoja.py` (CI: «Hoja de balance al día») |
| | `docs/playtests/GUION.md` si cita ese jefe o sus aliados (escrito a mano) | ❌ |
| | `docs/CARTAS.md` (las 28 cartas del set: qué hace la app y qué la mesa con cada una) | ⚠️ `app/test/catalogo_test.dart` comprueba el número, el nombre y los PS de las 28 cartas; los textos no |
| Una **carta** en PokeCardMaker (texto, PS, ataque o habilidad) | El jefe en `catalog/bosses/*.json` (los textos se copian tal cual) y todo lo de la fila anterior | ❌ (las cartas viven fuera del repo) |
| Un **recordatorio** de una carta (`avisoAlEntrar`, `avisoChequeo`, `avisoTurno`, `avisoAliadoCaido`) | Nada más: la app los lee del catálogo (`app/lib/partida/recordatorios.dart`) | ✅ `app/test/recordatorios_test.dart` |
| | El informe de simulación del jefe: `cd sim && dart run bin/sim_jefes.dart` (escribe `balance/informes/jefes_aliados.csv`; el simulador lee HP, ataques y aliados del catálogo) | ⚠️ el CI solo comprueba que el simulador compila y arranca, no que el informe esté al día |
| Que un aliado use `programa` y su `scriptId` | El script en `engine/lib/src/scripts_aliado.dart` (`scriptsAliado`) **antes** que el jefe | ✅ `engine/test/catalogo_scripts_test.dart` |
| El esquema del jefe (`catalog/schema/boss.schema.json`) | El modelo de la app `app/lib/catalogo/catalogo.dart` (lee los campos a mano) | ⚠️ `catalogo_test.dart` falla si falta o cambia un campo que la app lee, pero **no** si añades un campo nuevo que la app ignora |
| | `catalog/README.md` (ejemplo y descripción de campos) y los ejemplos de `catalog/ejemplos/` | ✅ `server/test/catalogo.test.js` (ejemplos válidos e inválidos) |
| | El script de la hoja `balance/scripts/generar_hoja.py` si usa el campo | ❌ |
| | Si rompe los jefes existentes: sube `formato` y migra los jefes | ❌ |
| Una **categoría de aliado** (renombrar, añadir o quitar: `danio`, `tanque`, `cura`, `picaro`) | Engine: `enum CategoriaAliado` en `engine/lib/src/eventos.dart` | ✅ |
| | Contrato: **nueva versión** (ver sección 2) con el esquema, la migración y los ejemplos | ⚠️ ver sección 2 |
| | Catálogo: `boss.schema.json` (`required` y `properties` de `aliados`), ejemplos de `catalog/ejemplos/`, los jefes y `catalog/README.md` | ✅ |
| | App: etiqueta en `app/lib/pantallas/pendientes.dart` (`_etiquetaCategoria`) y `app/lib/catalogo/catalogo.dart` (usa `CategoriaAliado.values`) | ✅ `flutter analyze` falla si falta un caso del `switch` |
| | Hoja: lista `CATEGORIAS` de `balance/scripts/generar_hoja.py` | ❌ |
| | Docs: GDD (§4.4, glosario), `docs/D-13-aliados-por-categoria.md`, `docs/playtests/GUION.md` | ❌ |
| El **formato del registro de partida** (evento nuevo, campo nuevo, valor de un enum) | Checklist de la sección 2 | ⚠️ |
| Una **regla del juego** (turnos, KO, aliados, estados…) | El motor `engine/` y sus tests | ✅ |
| | El GDD `incursiones_gdd.md` (sube la versión, añade fila al historial) y el documento `docs/D-xx` de esa decisión | ❌ |
| | `docs/playtests/GUION.md` si la regla cambia cómo se juega en mesa | ❌ |
| | El simulador `sim/` si usa esa regla | ❌ |
| Las **tablas de balance** (`balance/tablas/niveles.csv`: X por nivel, HP y ataques de referencia) | `engine/lib/src/reglas.dart` (`maxXNivel1/2/3` = `x_min` del nivel siguiente − 1) | ✅ `engine/test/tablas_balance_test.dart` |
| | El GDD (§2: ataques por nivel; §9: valores provisionales) y `docs/D-03-sistema-de-poder.md` | ⚠️ `engine/test/tablas_balance_test.dart` comprueba los ataques por nivel del GDD §2 y de los jefes del catálogo; el resto no |
| | La hoja de balance (compara contra el «poder de referencia» de `niveles.csv`) | ✅ `balance/scripts/comprobar_hoja.py` (CI: «Hoja de balance al día») |
| Los **puntos** (`balance/tablas/puntos_niveles.csv`, `reparto_puntos.csv`) | `engine/lib/src/puntos.dart` (`topeVictoriaPorNivel`, `costeDesbloqueoPorNivel`, `repartoPorJugadores`) | ✅ `engine/test/tablas_balance_test.dart` (los valores están copiados, no se leen del CSV) |
| | `docs/D-10-sistema-de-puntos.md` y el GDD | ❌ |
| Una **versión nueva del contrato** | Servidor, app, repo de Deck Tracker (secciones 2 y 3) | ⚠️ |
| El **módulo del servidor** `server/src/` | Regenerar y desplegar en **TCGMasters-server** (sección 3) | ❌ (el repo externo no tiene CI) |

## 2. Checklist: subir la versión del contrato

Cualquier cambio del formato sube la versión (`contrato/README.md`, «Versionado»). Pasos, con el contrato v4 (PR #83), el v5 (efectos de ataque, D-14) el v6 (6 categorías de aliado, D-16) y el v7 (monedas de aliado) y el v8 (daño por efectos, T-59) como ejemplo:

1. **Esquema:** copia `contrato/partida.vN.schema.json` a `partida.vN+1.schema.json` y cambia `$id`, `version: { const: N+1 }` y lo que cambie. **No toques los esquemas antiguos**: hay partidas guardadas con ellos.
2. **Ejemplos:** copia `contrato/ejemplos/vN/` a `vN+1/` (`validos/`, `invalidos-estructura/`, `invalidos-reglas/`) y pon `"version": N+1`. Revisa que los ejemplos inválidos lo siguen siendo con el esquema nuevo (en la v4, un valor inválido de la v3 pasó a ser válido).
3. **Motor** (`engine/lib/src/registro.dart`): sube `versionRegistro`, añade la función de migración `_vNAVN+1` a `_migraciones` y adapta la lectura/escritura JSON. Una migración vieja **no debe usar los enums actuales** (usa literales, como `_categoriasV3`), o dejará de escribir el formato de su versión.
4. **Tests del motor** (`engine/test/registro_test.dart`): añade el grupo «ejemplos del contrato vN+1», adapta las migraciones esperadas y cambia los `expect(registro.version, …)`.
5. **Servidor** (`server/src/esquema.js`): añade la versión a `VERSIONES_SOPORTADAS` y cambia el esquema que busca `CARPETA_CONTRATO`.
6. **Tests del servidor:** añade la versión a las listas **escritas a mano** de `server/test/contrato.test.js` (el bucle `[1, 2, 3, 4, 5, 6]` y el mapa `validadores`) y a `server/test/router.test.js` (versión futura, lista de versiones, partida de la versión nueva). Si no la añades, el CI sigue en verde y esa versión queda sin probar.
7. **Documentación:** `contrato/README.md` (título, tabla de archivos, ejemplo, historial de versiones) y `server/README.md`.
8. **App:** no tiene número de versión propio; usa `versionRegistro` del motor. Revisa los textos y las pantallas que muestren el valor que haya cambiado.
9. **Servidor externo:** sección 3.
10. **Orden de publicación:** primero el servidor (acepta versiones viejas y nuevas), después la app. Al revés, la app enviaría partidas que el servidor aún rechaza.

## 3. Servidor en TCGMasters (otro repo)

`server/` de este repo se **copia** al repo `Ayme-99/TCGMasters-server` (`src/modules/tcg-raid-battles/`) y Render lo despliega al fusionar en `main`. Los archivos copiados **no se editan allí**; solo es de ese repo `montar.js` y sus tests.

1. Fusiona y comprueba el CI en este repo.
2. En una copia de `TCGMasters-server`, rama nueva desde `main`: `node <este repo>/server/scripts/exportar.js src/modules/tcg-raid-battles`. Copia los `.js` del módulo y los esquemas `partida.vN.schema.json`.
3. Si hay versión nueva del contrato: añade `tests/tcg-raid-battles/partida-vN.json` y sus tests en `tests/tcg-raid-battles/montar.test.js`.
4. `npx jest` en ese repo (**no tiene CI**: es la única comprobación) y PR.
5. Al fusionar, Render despliega. Comprueba que el servidor responde y guarda una partida desde la app.

Regla del proyecto: no se crean ramas, commits ni PRs en los repos de Deck Tracker sin permiso explícito de Ayme.

## 4. Datos copiados a mano en varios sitios

Estos datos viven duplicados. Los que llevan ✅ los compara `engine/test/tablas_balance_test.dart`; del resto no te avisa nadie. Si cambias uno, cambia todos:

| Dato | Dónde está |
|---|---|
| ✅ Límites de nivel por X (≤400 / ≤600 / ≤800) | `balance/tablas/niveles.csv` (`x_min`), `engine/lib/src/reglas.dart` (el GDD §2 no se comprueba) |
| ✅ Ataques de cada nivel (30/60/120 …) | `niveles.csv`, GDD §2, cada jefe del catálogo (un ataque de daño variable, «40+», lleva su daño base, que no pasa del de la tabla) |
| HP de referencia por nivel | `niveles.csv`, GDD §9, hoja de balance (se lee del CSV) |
| ✅ Puntos por victoria, coste de desbloqueo y reparto | `balance/tablas/*.csv`, `engine/lib/src/puntos.dart` (`docs/D-10-sistema-de-puntos.md` no se comprueba) |
| Objetivo de victoria por nivel (75/50/30/15 %) | GDD, `sim/bin/sim_cartas.dart` (`objetivo`) |
| Daño de veneno y quemadura (10 y 20) | `engine/lib/src/reglas.dart`, GDD §4.3, `docs/D-12-estados-del-jefe.md` |
| Jefes y aliados iniciales | `catalog/bosses/`, `app/assets/catalogo/` (✅), la hoja de balance (✅), `docs/playtests/GUION.md` (❌) |

## 5. Qué cubre el CI (y qué no)

El CI (`.github/workflows/ci.yml`) ejecuta: tests del motor (`dart test`), tests de Node del contrato, del servidor y del catálogo (`npm test`), `flutter analyze` + `flutter test` + `flutter build web` de la app, y que la hoja de balance esté al día con el catálogo y las tablas (`comprobar_hoja.py`).

**No** comprueba: el repo `TCGMasters-server`; los resultados del simulador (`sim/`: el CI solo comprueba que compila y arranca); los valores duplicados de la sección 4 sin ✅; que el GDD y los documentos `docs/` coincidan con el código; ni que las listas de versiones escritas a mano en los tests incluyan la versión nueva.

## 6. Mantener este documento

Cada vez que una PR añada una dependencia nueva (un dato copiado, un script que genera archivos, un repo externo), añade su fila en la sección 1 o 4 en la misma PR.
