'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { comprobarCoherencia, abonos } = require('../src/coherencia');
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
