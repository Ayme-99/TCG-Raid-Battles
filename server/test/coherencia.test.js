'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { comprobarCoherencia, abonos, aplicacionesContables } = require('../src/coherencia');
const { puntosTotales, repartir } = require('../src/puntos');
const { ejemplo } = require('./ayudas');

test('los ejemplos válidos con resumen son coherentes', () => {
  for (const nombre of ['victoria-2-jugadores', 'derrota-con-aliado-y-abandono']) {
    assert.deepStrictEqual(comprobarCoherencia(ejemplo('validos', nombre)), [], nombre);
  }
});

test('una partida en curso no se guarda', () => {
  const motivos = comprobarCoherencia(ejemplo('validos', 'en-curso-sin-resumen'));
  assert.match(motivos[0], /falta el resumen/);
});

test('puntos del equipo y reparto salen igual que en el motor', () => {
  assert.strictEqual(puntosTotales({ nivel: 1, hpJefe: 300, danoTotal: 300, resultado: 'victoria' }), 3000);
  assert.strictEqual(puntosTotales({ nivel: 1, hpJefe: 1000, danoTotal: 600, resultado: 'derrota' }), 451);
  assert.deepStrictEqual(repartir(451, 3), [182, 148, 121]);
  assert.deepStrictEqual(repartir(3000, 2), [1650, 1350]);
});

test('los invitados ocupan puesto pero no se abonan', () => {
  const filas = abonos(ejemplo('validos', 'victoria-2-jugadores'));
  assert.deepStrictEqual(
    filas.map((f) => [f.cuentaId, f.puntos, f.abonado]),
    [['usuario-ana', 1650, true], [null, 1350, false]],
  );
});

function alterar(nombre, cambio) {
  const r = ejemplo('validos', nombre);
  cambio(r);
  return comprobarCoherencia(r);
}

test('detecta resúmenes que no cuadran', () => {
  const v = 'victoria-2-jugadores';
  assert.match(alterar(v, (r) => { r.resumen.puntosTotal = 9999; }).join(), /puntosTotal debería ser 3000/);
  assert.match(alterar(v, (r) => { r.resumen.jugadores[0].puntos = 2000; }).join(), /puntos deberían ser 1650/);
  assert.match(alterar(v, (r) => { r.resumen.jugadores[0].porcentaje = 60; }).join(), /porcentaje/);
  assert.match(alterar(v, (r) => { r.resumen.jugadores[1].abonado = true; }).join(), /abonado debe ser false/);
  assert.match(alterar(v, (r) => { r.resumen.nivel = 2; }).join(), /nivel/);
  assert.match(alterar(v, (r) => { r.resumen.resultado = 'derrota'; }).join(), /derrota no puede dejar al jefe a 0 HP/);
  assert.match(alterar(v, (r) => { r.resumen.jugadores[1].asiento = 0; }).join(), /repetido/);
  assert.match(alterar(v, (r) => { r.resumen.jugadores[0].nombre = 'Otra'; }).join(), /nombre/);
  assert.match(alterar(v, (r) => { r.cuentas = ['usuario-ana', 'usuario-ana']; }).join(), /misma cuenta/);
  assert.match(alterar(v, (r) => { r.cuentas = ['usuario-ana']; }).join(), /cuentas tiene 1/);
  assert.match(alterar(v, (r) => { delete r.cuentas; }).join(), /faltan las cuentas/);
  assert.match(alterar('derrota-con-aliado-y-abandono', (r) => { r.resumen.resultado = 'victoria'; }).join(), /abandono/);
});

const { bonoEstados } = require('../src/puntos');

test('el bono de estados sale igual que en el motor', () => {
  const b = (nivel, n, resultado) => bonoEstados({ nivel, aplicaciones: n, resultado });
  assert.deepStrictEqual([0, 1, 2, 3, 9].map((n) => b(1, n, 'victoria')), [0, 30, 60, 90, 90]);
  assert.deepStrictEqual([1, 2, 3].map((n) => b(4, n, 'victoria')), [150, 300, 450]);
  assert.deepStrictEqual([1, 2, 3].map((n) => b(1, n, 'derrota')), [8, 15, 23]);
  assert.deepStrictEqual([1, 2, 3].map((n) => b(3, n, 'derrota')), [23, 45, 68]);
  assert.deepStrictEqual([1, 2, 3].map((n) => b(4, n, 'derrota')), [38, 75, 113]);
});

test('los ejemplos v2 son coherentes', () => {
  for (const nombre of ['victoria-por-estados', 'derrota-con-veneno-y-abandono']) {
    assert.deepStrictEqual(comprobarCoherencia(ejemplo('validos', nombre, 2)), [], nombre);
  }
});

test('los abonos v2 incluyen el bono y los invitados no lo cobran', () => {
  const filas = abonos(ejemplo('validos', 'victoria-por-estados', 2));
  assert.deepStrictEqual(
    filas.map((f) => [f.cuentaId, f.puntos, f.estadosAplicados, f.bonoEstados, f.abonado]),
    [['usuario-ana', 1650, 1, 30, true], [null, 1350, 2, 60, false]],
  );
});

function alterarV2(nombre, cambio) {
  const r = ejemplo('validos', nombre, 2);
  cambio(r);
  return comprobarCoherencia(r).join();
}

test('detecta bonos y aplicaciones que no cuadran', () => {
  const v = 'victoria-por-estados';
  assert.match(alterarV2(v, (r) => { r.resumen.jugadores[0].bonoEstados = 90; }), /bonoEstados debería ser 30, no 90/);
  assert.match(alterarV2(v, (r) => { r.resumen.jugadores[0].estadosAplicados = 3; }), /estadosAplicados debería ser 1, no 3/);
  assert.match(alterarV2(v, (r) => { r.resumen.jugadores[1].estadosAplicados = 1; }), /estadosAplicados debería ser 2, no 1/);
  // Quien no aplicó nada no puede cobrar bono.
  assert.match(
    alterarV2('derrota-con-veneno-y-abandono', (r) => { r.resumen.jugadores[0].estadosAplicados = 0; }),
    /estadosAplicados debería ser 1/,
  );
});

test('un estado que el jefe ya tenía no cuenta', () => {
  const r = ejemplo('validos', 'derrota-con-veneno-y-abandono', 2);
  r.eventos.splice(4, 0, { tipo: 'aplicarEstadoJefe', jugador: 0, estado: 'veneno' }); // repetido
  assert.deepStrictEqual(comprobarCoherencia(r), []);
});

test('una quemadura quitada por la moneda vuelve a contar; si se mantiene, no', () => {
  const r = ejemplo('validos', 'victoria-por-estados', 2);
  // Con la moneda en cruz la quemadura sigue puesta: la segunda aplicación no cuenta.
  r.eventos.find((e) => e.tipo === 'finTurnoJefe').monedaQuemadura = false;
  const motivos = comprobarCoherencia(r).join();
  assert.match(motivos, /estadosAplicados debería ser 1, no 2/);
});

test('las aplicaciones de estados a aliados cuentan (v10, D-17)', () => {
  const eventos = [
    { tipo: 'aliadoInvocado', slot: 1 },
    { tipo: 'aplicarEstadoAliado', jugador: 1, slot: 1, estado: 'veneno' },
    { tipo: 'aplicarEstadoAliado', jugador: 2, slot: 1, estado: 'veneno' }, // ya lo tenía
    { tipo: 'aplicarEstadoAliado', jugador: 0, slot: 1, estado: 'quemadura' },
    { tipo: 'finTurnoJefe', monedasQuemaduraAliados: [{ slot: 1, cara: true }] },
    { tipo: 'aplicarEstadoAliado', jugador: 2, slot: 1, estado: 'quemadura' }, // la cara la quitó
    { tipo: 'aliadoInvocado', slot: 1 }, // aliado nuevo, limpio
    { tipo: 'aplicarEstadoAliado', jugador: 2, slot: 1, estado: 'veneno' },
  ];
  assert.deepStrictEqual(aplicacionesContables(eventos, 3), [1, 1, 2]);
});
