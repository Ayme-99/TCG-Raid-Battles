'use strict';
// Puntos de la campaña por hitos y tienda de la pantalla de inicio (#374):
// esquema de contrato/campana/hitos.v1.schema.json, datos de catalog/ y las
// rutas POST /campana/hitos y GET /tienda.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const express = require('express');
const Ajv2020 = require('ajv/dist/2020');
const {
  crearRouter, crearRepoMemoria, crearValidadorHitos, cargarTopes, cargarTienda,
} = require('../src');

const raiz = path.join(__dirname, '..', '..');
const leer = (...r) => JSON.parse(fs.readFileSync(path.join(raiz, ...r), 'utf8'));
const ejemplos = (carpeta) => {
  const dir = path.join(raiz, 'contrato', 'campana', 'ejemplos', 'hitos', carpeta);
  return fs.readdirSync(dir).filter((f) => f.endsWith('.json'))
    .map((f) => ({ nombre: f, json: JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8')) }));
};

test('el esquema de los hitos acepta los válidos y rechaza los inválidos', () => {
  const validar = crearValidadorHitos();
  for (const { nombre, json } of ejemplos('validos')) assert.deepStrictEqual(validar(json), [], nombre);
  const invalidos = ejemplos('invalidos');
  assert.ok(invalidos.length >= 4);
  for (const { nombre, json } of invalidos) assert.ok(validar(json).length > 0, nombre);
});

test('los datos de la tienda y de los topes cumplen su esquema', () => {
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  for (const [esquema, datos] of [
    [['catalog', 'schema', 'tienda.schema.json'], ['catalog', 'tienda', 'tienda.json']],
    [['catalog', 'schema', 'topes-puntos.schema.json'], ['catalog', 'campana', 'topes-puntos.json']],
  ]) {
    const validar = ajv.compile(leer(...esquema));
    assert.strictEqual(validar(leer(...datos)), true, JSON.stringify(validar.errors));
  }
  const ids = cargarTienda().productos.map((p) => p.id);
  assert.strictEqual(new Set(ids).size, ids.length, 'ids de producto repetidos');
});

test('los precios de la tienda son los de D-21 §2.3', () => {
  const precio = Object.fromEntries(cargarTienda().productos.map((p) => [p.id, p.precio]));
  assert.deepStrictEqual(precio, {
    'moneda-clasica': 0,
    'moneda-serie': 800,
    'moneda-tematica': 2000,
    'dados-estandar': 0,
    'dados-serie': 1500,
    'dados-tematicos': 3000,
    sobre: 1000,
    'carta-comun': 200,
    'carta-poco-comun': 400,
    'carta-rara': 800,
    'carta-ultra-rara': 2000,
  });
});

async function arrancar(opciones = {}) {
  const router = crearRouter({
    repo: crearRepoMemoria(),
    autenticar: (req, res, next) => {
      req.usuarioId = req.get('x-usuario') || undefined;
      next();
    },
    ahora: () => new Date('2026-11-25T10:00:00.000Z'),
    ...opciones,
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
const envio = (...hitos) => ({ version: 1, campana: 'kanto', hitos });
const salvaje = { id: 'ruta-1-pidgey', tipo: 'salvaje', puntos: 100 };
const jefe = { id: 'pikachu', tipo: 'jefe', puntos: 1000 };

test('sin sesión no se abonan hitos ni se ve la tienda', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  assert.strictEqual((await llamar('POST', '/campana/hitos', { cuerpo: envio(salvaje) })).estado, 401);
  assert.strictEqual((await llamar('GET', '/tienda')).estado, 401);
});

test('abona los hitos nuevos y un reenvío no suma dos veces', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const una = await llamar('POST', '/campana/hitos', { usuario: ANA, cuerpo: envio(salvaje, jefe) });
  assert.strictEqual(una.estado, 200);
  assert.deepStrictEqual(una.json.abonados, ['ruta-1-pidgey', 'pikachu']);
  assert.deepStrictEqual(una.json.repetidos, []);
  assert.strictEqual(una.json.puntosAbonados, 1100);
  assert.strictEqual(una.json.puntosCampana, 1100);

  const medalla = { id: 'medalla:roca', tipo: 'medalla', puntos: 1500 };
  const dos = await llamar('POST', '/campana/hitos', { usuario: ANA, cuerpo: envio(jefe, medalla) });
  assert.deepStrictEqual(dos.json.abonados, ['medalla:roca']);
  assert.deepStrictEqual(dos.json.repetidos, ['pikachu']);
  assert.strictEqual(dos.json.puntosAbonados, 1500);
  assert.strictEqual(dos.json.puntosCampana, 2600);

  // /me/puntos lo enseña aparte; los de incursiones no cambian.
  const me = await llamar('GET', '/me/puntos', { usuario: ANA });
  assert.strictEqual(me.json.puntosCampana, 2600);
  assert.strictEqual(me.json.puntos, 0);
  // Otra cuenta, el mismo id: se abona a ella.
  const bea = await llamar('POST', '/campana/hitos', { usuario: BEA, cuerpo: envio(jefe) });
  assert.deepStrictEqual(bea.json.abonados, ['pikachu']);
});

test('rechaza un hito por encima del tope de su tipo', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const tope = cargarTopes().salvaje;
  const r = await llamar('POST', '/campana/hitos', {
    usuario: ANA, cuerpo: envio(jefe, { ...salvaje, puntos: tope + 10 }),
  });
  assert.strictEqual(r.estado, 422);
  assert.strictEqual(r.json.error, 'puntos_fuera_de_tope');
  assert.deepStrictEqual(r.json.hitos, [{ id: 'ruta-1-pidgey', tipo: 'salvaje', puntos: tope + 10, tope }]);
  // No se abona ninguno del envío.
  assert.strictEqual((await llamar('GET', '/me/puntos', { usuario: ANA })).json.puntosCampana, 0);
});

test('el mismo id con otros datos es un conflicto y no abona nada', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  await llamar('POST', '/campana/hitos', { usuario: ANA, cuerpo: envio(salvaje) });
  const r = await llamar('POST', '/campana/hitos', {
    usuario: ANA, cuerpo: envio(jefe, { ...salvaje, puntos: 50 }),
  });
  assert.strictEqual(r.estado, 409);
  assert.strictEqual(r.json.error, 'hito_distinto');
  assert.deepStrictEqual(r.json.hitos, [{ id: 'ruta-1-pidgey', tipo: 'salvaje', puntos: 100 }]);
  assert.strictEqual((await llamar('GET', '/me/puntos', { usuario: ANA })).json.puntosCampana, 100);
});

test('rechaza un envío mal formado o con el mismo id dos veces', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const malo = await llamar('POST', '/campana/hitos', { usuario: ANA, cuerpo: { version: 1, hitos: [] } });
  assert.strictEqual(malo.estado, 400);
  assert.strictEqual(malo.json.error, 'estructura_invalida');
  const doble = await llamar('POST', '/campana/hitos', { usuario: ANA, cuerpo: envio(salvaje, salvaje) });
  assert.strictEqual(doble.estado, 400);
  assert.strictEqual(doble.json.error, 'hito_repetido');
});

test('GET /tienda devuelve el catálogo de datos', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const r = await llamar('GET', '/tienda', { usuario: ANA });
  assert.strictEqual(r.estado, 200);
  assert.deepStrictEqual(r.json.productos, cargarTienda().productos);
  // Sobres y cartas sueltas esperan a las cartas digitales (D-21 §2.2).
  const sobre = r.json.productos.find((p) => p.id === 'sobre');
  assert.strictEqual(sobre.disponible, false);
});
