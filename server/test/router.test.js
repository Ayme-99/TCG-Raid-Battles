'use strict';
const test = require('node:test');
const assert = require('node:assert');
const express = require('express');
const { crearRouter, crearRepoMemoria } = require('../src');
const { ejemplo, conId } = require('./ayudas');

// App de prueba: la autenticación lee la cabecera x-usuario.
async function arrancar(opciones = {}) {
  let reloj = Date.parse('2026-11-06T10:00:00.000Z');
  const router = crearRouter({
    repo: crearRepoMemoria(),
    autenticar: (req, res, next) => {
      req.usuarioId = req.get('x-usuario') || undefined;
      next();
    },
    ahora: () => new Date((reloj += 1000)),
    ...opciones,
  });
  const app = express();
  app.use('/api/incursiones', router);
  const servidor = await new Promise((ok) => { const s = app.listen(0, () => ok(s)); });
  const base = `http://127.0.0.1:${servidor.address().port}/api/incursiones`;
  const llamar = async (metodo, ruta, { usuario, cuerpo, crudo } = {}) => {
    const r = await fetch(base + ruta, {
      method: metodo,
      headers: { 'content-type': 'application/json', ...(usuario ? { 'x-usuario': usuario } : {}) },
      body: crudo ?? (cuerpo === undefined ? undefined : JSON.stringify(cuerpo)),
    });
    return { estado: r.status, json: await r.json() };
  };
  return { llamar, cerrar: () => servidor.close() };
}

const ANA = 'usuario-ana';
const BEA = 'usuario-bea';

test('sin sesión se rechaza todo', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  for (const [m, r] of [['GET', '/partidas'], ['GET', '/me/puntos'], ['POST', '/partidas']]) {
    const res = await llamar(m, r);
    assert.strictEqual(res.estado, 401, `${m} ${r}`);
    assert.strictEqual(res.json.error, 'no_autenticado');
  }
});

test('guardar una partida abona los puntos y un reintento no los duplica', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const partida = ejemplo('validos', 'victoria-2-jugadores');

  const primera = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: partida });
  assert.strictEqual(primera.estado, 201);
  assert.strictEqual(primera.json.duplicada, false);
  assert.strictEqual(primera.json.tusPuntos, 1650);

  const reintento = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: partida });
  assert.strictEqual(reintento.estado, 200);
  assert.strictEqual(reintento.json.duplicada, true);
  assert.strictEqual(reintento.json.guardadaEn, primera.json.guardadaEn);

  const puntos = await llamar('GET', '/me/puntos', { usuario: ANA });
  assert.strictEqual(puntos.json.puntos, 1650);
  assert.strictEqual(puntos.json.partidas, 1);
});

test('el mismo partidaId con otro contenido es un conflicto', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const partida = ejemplo('validos', 'victoria-2-jugadores');
  await llamar('POST', '/partidas', { usuario: ANA, cuerpo: partida });
  const otra = structuredClone(partida);
  otra.creadaEn = '2030-01-01T00:00:00Z';
  const res = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: otra });
  assert.strictEqual(res.estado, 409);
  assert.strictEqual(res.json.error, 'partida_distinta');
});

test('rechaza lo que el esquema no admite', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  for (const nombre of ['evento-desconocido', 'dano-no-es-entero', 'falta-partida-id', 'campo-desconocido']) {
    const res = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: ejemplo('invalidos-estructura', nombre) });
    assert.strictEqual(res.estado, 400, nombre);
    assert.strictEqual(res.json.error, 'estructura_invalida', nombre);
    assert.ok(res.json.errores.length > 0, nombre);
  }
  const futura = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: ejemplo('invalidos-estructura', 'version-futura') });
  assert.strictEqual(futura.estado, 400);
  assert.strictEqual(futura.json.error, 'version_no_soportada');
  const malo = await llamar('POST', '/partidas', { usuario: ANA, crudo: '{no es json' });
  assert.strictEqual(malo.estado, 400);
  assert.strictEqual(malo.json.error, 'json_invalido');
});

test('una partida en curso no se guarda', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const partida = ejemplo('validos', 'en-curso-sin-resumen');
  const res = await llamar('POST', '/partidas', { usuario: partida.cuentas?.[0] ?? ANA, cuerpo: partida });
  assert.ok([403, 422].includes(res.estado), JSON.stringify(res.json));
  if (res.estado === 422) assert.match(res.json.motivos[0], /falta el resumen/);
});

test('solo guarda quien figura en las cuentas de la partida', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const res = await llamar('POST', '/partidas', { usuario: 'usuario-intruso', cuerpo: ejemplo('validos', 'victoria-2-jugadores') });
  assert.strictEqual(res.estado, 403);
  assert.strictEqual(res.json.error, 'no_participas');
});

test('rechaza un resumen incoherente con sus motivos', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const partida = ejemplo('validos', 'victoria-2-jugadores');
  partida.resumen.jugadores[0].puntos = 2500; // se lleva más de lo que le toca
  const res = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: partida });
  assert.strictEqual(res.estado, 422);
  assert.strictEqual(res.json.error, 'resumen_incoherente');
  assert.match(res.json.motivos.join(), /puntos deberían ser 1650/);
  const guardadas = await llamar('GET', '/partidas', { usuario: ANA });
  assert.deepStrictEqual(guardadas.json.partidas, []);
});

test('rechaza cuentas que no existen', async (t) => {
  const { llamar, cerrar } = await arrancar({ existenCuentas: async (ids) => ids.filter((i) => i !== ANA) });
  t.after(cerrar);
  const partida = ejemplo('validos', 'derrota-con-aliado-y-abandono'); // Ana y Bea
  const res = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: partida });
  assert.strictEqual(res.estado, 422);
  assert.strictEqual(res.json.error, 'cuenta_desconocida');
  assert.deepStrictEqual(res.json.cuentas, [BEA]);
});

test('cada cuenta cobra solo su parte', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  await llamar('POST', '/partidas', { usuario: BEA, cuerpo: ejemplo('validos', 'derrota-con-aliado-y-abandono') });
  const ana = await llamar('GET', '/me/puntos', { usuario: ANA });
  const bea = await llamar('GET', '/me/puntos', { usuario: BEA });
  assert.strictEqual(ana.json.puntos, 182);
  assert.strictEqual(bea.json.puntos, 121); // Cris era invitada: sus 148 no se abonan
  assert.deepStrictEqual(ana.json.niveles[0], { nivel: 1, coste: 10000, alcanzado: false, faltan: 9818 });
});

test('historial paginado, de la más reciente a la más antigua', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const base = ejemplo('validos', 'victoria-2-jugadores');
  for (const id of ['p1', 'p2', 'p3']) {
    const res = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: conId(base, id) });
    assert.strictEqual(res.estado, 201);
  }
  const pag1 = await llamar('GET', '/partidas?limite=2', { usuario: ANA });
  assert.deepStrictEqual(pag1.json.partidas.map((p) => p.partidaId), ['p3', 'p2']);
  assert.ok(pag1.json.siguiente);
  const pag2 = await llamar('GET', `/partidas?limite=2&despues=${pag1.json.siguiente}`, { usuario: ANA });
  assert.deepStrictEqual(pag2.json.partidas.map((p) => p.partidaId), ['p1']);
  assert.strictEqual(pag2.json.siguiente, null);
  assert.deepStrictEqual(
    { nivel: pag2.json.partidas[0].nivel, miPuesto: pag2.json.partidas[0].miPuesto, misPuntos: pag2.json.partidas[0].misPuntos },
    { nivel: 1, miPuesto: 1, misPuntos: 1650 },
  );
  for (const q of ['limite=0', 'limite=51', 'limite=x', 'despues=basura']) {
    const res = await llamar('GET', `/partidas?${q}`, { usuario: ANA });
    assert.strictEqual(res.estado, 400, q);
  }
});

test('el detalle de una partida es solo para quien jugó en ella', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const partida = ejemplo('validos', 'victoria-2-jugadores');
  await llamar('POST', '/partidas', { usuario: ANA, cuerpo: partida });
  const propia = await llamar('GET', `/partidas/${partida.partidaId}`, { usuario: ANA });
  assert.strictEqual(propia.estado, 200);
  assert.deepStrictEqual(propia.json.registro, partida);
  const ajena = await llamar('GET', `/partidas/${partida.partidaId}`, { usuario: BEA });
  assert.strictEqual(ajena.estado, 404);
  const noExiste = await llamar('GET', '/partidas/nada', { usuario: ANA });
  assert.strictEqual(noExiste.estado, 404);
});
