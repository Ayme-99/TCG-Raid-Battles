'use strict';
// Compras en la tienda de puntos (#374, D-21 §1.2): un solo total por cuenta,
// comprar lo baja y un jefe ya desbloqueado no vuelve a bloquearse (opción C,
// decidida por Ayme el 2026-11-25).
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const express = require('express');
const { crearRouter, crearRepoMemoria, crearValidadorCompra } = require('../src');

const raiz = path.join(__dirname, '..', '..');
const ejemplos = (carpeta) => {
  const dir = path.join(raiz, 'contrato', 'campana', 'ejemplos', 'compra', carpeta);
  return fs.readdirSync(dir).filter((f) => f.endsWith('.json'))
    .map((f) => ({ nombre: f, json: JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8')) }));
};

const ANA = 'usuario-ana';
const BEA = 'usuario-bea';

// Abona a la cuenta [puntos] de campaña directamente en el repo.
async function conPuntos(repo, cuentaId, puntos, partida = 'p1') {
  await repo.abonarHitosCampana({
    cuentaId, campana: 'kanto', partida, abonadoEn: 't0',
    hitos: [{ id: `h-${puntos}`, tipo: 'medalla', puntos }],
  });
}

async function arrancar() {
  const repo = crearRepoMemoria();
  const router = crearRouter({
    repo,
    autenticar: (req, res, next) => {
      req.usuarioId = req.get('x-usuario') || undefined;
      next();
    },
    ahora: () => new Date('2026-11-25T10:00:00.000Z'),
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
  return { repo, llamar, cerrar: () => servidor.close() };
}

const compra = (producto, id = `c-${producto}`) => ({ version: 1, compra: id, producto });

test('el esquema de la compra acepta los válidos y rechaza los inválidos', () => {
  const validar = crearValidadorCompra();
  for (const { nombre, json } of ejemplos('validos')) assert.deepStrictEqual(validar(json), [], nombre);
  const invalidos = ejemplos('invalidos');
  assert.ok(invalidos.length >= 4);
  for (const { nombre, json } of invalidos) assert.ok(validar(json).length > 0, nombre);
});

test('sin sesión no se compra', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  assert.strictEqual((await llamar('POST', '/tienda/compras', { cuerpo: compra('moneda-serie') })).estado, 401);
  assert.strictEqual((await llamar('GET', '/tienda/compras')).estado, 401);
});

test('comprar baja el total y un reenvío no cobra dos veces', async (t) => {
  const { repo, llamar, cerrar } = await arrancar();
  t.after(cerrar);
  await conPuntos(repo, ANA, 1500);
  const una = await llamar('POST', '/tienda/compras', { usuario: ANA, cuerpo: compra('moneda-serie') });
  assert.strictEqual(una.estado, 201);
  assert.strictEqual(una.json.repetida, false);
  assert.strictEqual(una.json.puntos, 700);
  assert.deepStrictEqual(una.json.compra, {
    id: 'c-moneda-serie', producto: 'moneda-serie', precio: 800, compradaEn: '2026-11-25T10:00:00.000Z',
  });
  const otra = await llamar('POST', '/tienda/compras', { usuario: ANA, cuerpo: compra('moneda-serie') });
  assert.strictEqual(otra.estado, 200);
  assert.strictEqual(otra.json.repetida, true);
  assert.strictEqual(otra.json.puntos, 700);

  const me = await llamar('GET', '/me/puntos', { usuario: ANA });
  assert.strictEqual(me.json.puntos, 700);
  assert.strictEqual(me.json.puntosCampana, 1500);
  assert.strictEqual(me.json.puntosGastados, 800);
  const mias = await llamar('GET', '/tienda/compras', { usuario: ANA });
  assert.deepStrictEqual(mias.json.productos, ['moneda-serie']);
  assert.strictEqual(mias.json.compras.length, 1);
  // Bea no ha comprado nada.
  assert.deepStrictEqual((await llamar('GET', '/tienda/compras', { usuario: BEA })).json.productos, []);
});

test('sin puntos suficientes no se compra ni se cobra', async (t) => {
  const { repo, llamar, cerrar } = await arrancar();
  t.after(cerrar);
  await conPuntos(repo, ANA, 1000);
  const r = await llamar('POST', '/tienda/compras', { usuario: ANA, cuerpo: compra('dados-serie') });
  assert.strictEqual(r.estado, 409);
  assert.strictEqual(r.json.error, 'puntos_insuficientes');
  assert.strictEqual(r.json.puntos, 1000);
  assert.strictEqual(r.json.precio, 1500);
  assert.strictEqual((await llamar('GET', '/me/puntos', { usuario: ANA })).json.puntos, 1000);
});

test('rechaza productos desconocidos, gratis, no a la venta, repetidos y compras con otro producto', async (t) => {
  const { repo, llamar, cerrar } = await arrancar();
  t.after(cerrar);
  await conPuntos(repo, ANA, 9000);
  const pedir = (cuerpo) => llamar('POST', '/tienda/compras', { usuario: ANA, cuerpo });
  assert.strictEqual((await pedir({ version: 1 })).json.error, 'estructura_invalida');
  assert.strictEqual((await pedir(compra('no-existe'))).estado, 404);
  assert.strictEqual((await pedir(compra('moneda-clasica'))).json.error, 'producto_gratis');
  assert.strictEqual((await pedir(compra('sobre'))).json.error, 'no_disponible');
  assert.strictEqual((await pedir(compra('moneda-tematica', 'c-1'))).estado, 201);
  const distinta = await pedir(compra('dados-serie', 'c-1'));
  assert.strictEqual(distinta.estado, 409);
  assert.strictEqual(distinta.json.error, 'compra_distinta');
  // Una moneda o unos dados se compran una vez por cuenta (propuesta).
  const repetida = await pedir(compra('moneda-tematica', 'c-2'));
  assert.strictEqual(repetida.json.error, 'ya_comprado');
  assert.strictEqual((await llamar('GET', '/me/puntos', { usuario: ANA })).json.puntos, 7000);
});

test('un jefe desbloqueado sigue desbloqueado aunque la compra baje el total', async (t) => {
  const { repo, llamar, cerrar } = await arrancar();
  t.after(cerrar);
  await conPuntos(repo, ANA, 10500);
  const antes = (await llamar('GET', '/me/puntos', { usuario: ANA })).json.niveles;
  assert.deepStrictEqual(antes[0], { nivel: 1, coste: 10000, alcanzado: true, faltan: 0 });
  const r = await llamar('POST', '/tienda/compras', { usuario: ANA, cuerpo: compra('dados-tematicos') });
  assert.strictEqual(r.estado, 201);
  assert.strictEqual(r.json.puntos, 7500);
  const me = (await llamar('GET', '/me/puntos', { usuario: ANA })).json;
  assert.strictEqual(me.puntos, 7500);
  assert.deepStrictEqual(me.niveles[0], { nivel: 1, coste: 10000, alcanzado: true, faltan: 0 });
  // El siguiente se mide sobre el total de ahora: tarda más en llegar.
  assert.deepStrictEqual(me.niveles[1], { nivel: 2, coste: 20000, alcanzado: false, faltan: 12500 });
});
