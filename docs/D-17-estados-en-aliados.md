# D-17 · Estados en los aliados (veneno y quemadura)

**Estado:** implementado (contrato v10, #196). Parte de lo decidido en D-16.

## Reglas

- Un ataque de los jugadores puede dejar a un **aliado** Envenenado o Quemado, igual que al jefe (D-12). La mesa lo registra con `aplicarEstadoAliado {jugador, slot, estado}`, en el turno de jugadores o en el del jefe.
- Si el aliado ya tiene ese estado no pasa nada y no cuenta. Si el slot está vacío, o Velo Sagrado está en juego, el motor rechaza el evento.
- **Chequeo al cerrar el turno del jefe**, después del chequeo del jefe y por orden de slot: veneno −10 HP, quemadura −20 HP (`danoVeneno`, `danoQuemadura`). El veneno es permanente. Por cada aliado quemado la mesa tira una moneda: cara, deja de estar quemado (tras aplicar el daño). Si el aliado llega a 0 HP sale de la mesa, su slot queda libre y suma a `aliadosDerrotados`.
- Este daño no se atribuye a ningún jugador ni baja los HP del jefe.
- **Velo Sagrado** también limpia los estados de todos los aliados al entrar y los bloquea mientras esté en juego.
- Las aplicaciones a aliados **cuentan para el bono de estados** (D-12: b × min(n, 3)) junto a las del jefe.
- Un aliado nuevo en un slot libre empieza sin estados.

## Contrato v10

- Evento nuevo `aplicarEstadoAliado`.
- `finTurnoJefe` admite `monedasQuemaduraAliados: [{slot, cara}]`, una por aliado quemado (ni más ni menos, sin repetir slots).
- El servidor recuenta las aplicaciones en `coherencia.js` con las mismas reglas.
- Los registros v9 se migran sumando solo la versión.

## Fuera de alcance

El simulador no modela estados en aliados.
