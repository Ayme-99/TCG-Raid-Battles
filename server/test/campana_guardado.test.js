'use strict';
// Partida de campaña guardada en la cuenta (#478): el esquema del contrato
// (contrato/campana/guardado.v1.schema.json) y las rutas
// GET/PUT /campana/partidas/:campana.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const express = require('express');
const { crearRouter, crearRepoMemoria, crearValidadorGuardado } = require('../src');

const ejemplos = path.join(__dirname, '..', '..', 'contrato', 'campana', 'ejemplos', 'guardado');
const leerEjemplos = (carpeta) => fs.readdirSync(path.join(ejemplos, carpeta))
  .filter((f) => f.endsWith('.json'))
  .map((f) => ({ nombre: f, json: JSON.parse(fs.readFileSync(path.join(ejemplos, carpeta, f), 'utf8')) }));

test('el esquema acepta los ejemplos válidos', () => {
  const validar = crearValidadorGuardado();
  const validos = leerEjemplos('validos');
  assert.ok(validos.length >= 2);
  for (const { nombre, json } of validos) {
    assert.deepStrictEqual(validar(json), [], nombre);
  }
});

test('el esquema rechaza cada ejemplo inválido', () => {
  const validar = crearValidadorGuardado();
  const invalidos = leerEjemplos('invalidos');
  assert.ok(invalidos.length >= 5);
  for (const { nombre, json } of invalidos) {
    assert.ok(validar(json).length > 0, nombre);
  }
});

async function arrancar() {
  let reloj = Date.parse('2026-11-25T10:00:00.000Z');
  const router = crearRouter({
    repo: crearRepoMemoria(),
    autenticar: (req, res, next) => {
      req.usuarioId = req.get('x-usuario') || undefined;
      next();
    },
    ahora: () => new Date((reloj += 1000)),
  });
  const app = express();
  app.use('/api/incursiones', router);
  const servidor = await new Promise((ok) => { const s = app.listen(0, () => ok(s)); });
  const base = `http://127.0.0.1:${servidor.address().port}/api/incursiones`;
  const llamar = async (metodo, ruta, { usuario, cuerpo } = {}) => {
    const r = await fetch(base + ruta, {
      method: metodo,
      headers: { 'content-type': 'application/json', ...(usuario ? { 'x-usuario': usuario } : {}) },
      body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
    });
    return { estado: r.status, json: await r.json() };
  };
  return { llamar, cerrar: () => servidor.close() };
}

const ANA = 'usuario-ana';
const BEA = 'usuario-bea';
const partida = leerEjemplos('validos').find((e) => e.nombre === 'primera-partida.json').json.partida;
const guardar = (revision, p = partida) => ({ version: 1, revision, partida: p });

test('sin sesión no se lee ni se guarda', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  assert.strictEqual((await llamar('GET', '/campana/partidas/kanto')).estado, 401);
  assert.strictEqual((await llamar('PUT', '/campana/partidas/kanto', { cuerpo: guardar(0) })).estado, 401);
});

test('guardar la primera vez, leerla y subir la revisión', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const vacia = await llamar('GET', '/campana/partidas/kanto', { usuario: ANA });
  assert.strictEqual(vacia.estado, 404);
  assert.strictEqual(vacia.json.error, 'sin_partida');

  const una = await llamar('PUT', '/campana/partidas/kanto', { usuario: ANA, cuerpo: guardar(0) });
  assert.strictEqual(una.estado, 200);
  assert.strictEqual(una.json.revision, 1);
  assert.strictEqual(una.json.campana, 'kanto');
  assert.deepStrictEqual(una.json.partida, partida);

  const leida = await llamar('GET', '/campana/partidas/kanto', { usuario: ANA });
  assert.strictEqual(leida.estado, 200);
  assert.strictEqual(leida.json.revision, 1);
  assert.deepStrictEqual(leida.json.partida, partida);

  const mas = { ...partida, dinero: 2000 };
  const dos = await llamar('PUT', '/campana/partidas/kanto', { usuario: ANA, cuerpo: guardar(1, mas) });
  assert.strictEqual(dos.estado, 200);
  assert.strictEqual(dos.json.revision, 2);
  assert.strictEqual(dos.json.partida.dinero, 2000);
});

test('con una revisión vieja responde 409 con la copia del servidor', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  await llamar('PUT', '/campana/partidas/kanto', { usuario: ANA, cuerpo: guardar(0) });
  await llamar('PUT', '/campana/partidas/kanto', { usuario: ANA, cuerpo: guardar(1, { ...partida, xp: 90 }) });
  // Otro dispositivo que leyó la revisión 1.
  const viejo = await llamar('PUT', '/campana/partidas/kanto', { usuario: ANA, cuerpo: guardar(1) });
  assert.strictEqual(viejo.estado, 409);
  assert.strictEqual(viejo.json.error, 'revision_distinta');
  assert.strictEqual(viejo.json.actual.revision, 2);
  assert.strictEqual(viejo.json.actual.partida.xp, 90);
  // Crear de nuevo (revisión 0) cuando ya hay una también choca.
  assert.strictEqual(
    (await llamar('PUT', '/campana/partidas/kanto', { usuario: ANA, cuerpo: guardar(0) })).estado, 409);
});

test('cada cuenta y cada campaña tienen su partida', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  await llamar('PUT', '/campana/partidas/kanto', { usuario: ANA, cuerpo: guardar(0) });
  assert.strictEqual((await llamar('GET', '/campana/partidas/kanto', { usuario: BEA })).estado, 404);
  assert.strictEqual((await llamar('GET', '/campana/partidas/johto', { usuario: ANA })).estado, 404);
  const bea = await llamar('PUT', '/campana/partidas/kanto', { usuario: BEA, cuerpo: guardar(0) });
  assert.strictEqual(bea.json.revision, 1);
});

test('rechaza un guardado que no cumple el esquema o una campaña mal escrita', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const malo = await llamar('PUT', '/campana/partidas/kanto', {
    usuario: ANA, cuerpo: guardar(0, { ...partida, dinero: -1 }),
  });
  assert.strictEqual(malo.estado, 400);
  assert.strictEqual(malo.json.error, 'estructura_invalida');
  assert.ok(malo.json.errores.length > 0);
  assert.strictEqual(
    (await llamar('GET', '/campana/partidas/Kanto!', { usuario: ANA })).estado, 400);
  // Nada se ha guardado.
  assert.strictEqual((await llamar('GET', '/campana/partidas/kanto', { usuario: ANA })).estado, 404);
});

test('guardar la partida no abona puntos a la cuenta', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  await llamar('PUT', '/campana/partidas/kanto', {
    usuario: ANA, cuerpo: guardar(0, { ...partida, puntos: 999999 }),
  });
  const puntos = await llamar('GET', '/me/puntos', { usuario: ANA });
  assert.strictEqual(puntos.json.puntos, 0);
});
