'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const Ajv2020 = require('ajv/dist/2020');
const addFormats = require('ajv-formats');

const catalogo = path.join(__dirname, '..', '..', 'catalog');
const leer = (ruta) => JSON.parse(fs.readFileSync(ruta, 'utf8'));
const jsons = (carpeta) => fs.readdirSync(carpeta).filter((f) => f.endsWith('.json')).sort();

const ajv = new Ajv2020({ allErrors: true, strict: true, strictRequired: false });
addFormats(ajv);
const validarJefe = ajv.compile(leer(path.join(catalogo, 'schema', 'boss.schema.json')));
const validarIndice = ajv.compile(leer(path.join(catalogo, 'schema', 'catalogo.schema.json')));

test('los ejemplos válidos cumplen el esquema del jefe', () => {
  for (const f of jsons(path.join(catalogo, 'ejemplos', 'validos'))) {
    const jefe = leer(path.join(catalogo, 'ejemplos', 'validos', f));
    assert.strictEqual(validarJefe(jefe), true, `${f}: ${JSON.stringify(validarJefe.errors)}`);
  }
});

test('cada ejemplo inválido incumple el esquema del jefe', () => {
  const archivos = jsons(path.join(catalogo, 'ejemplos', 'invalidos'));
  assert.ok(archivos.length >= 8);
  for (const f of archivos) {
    const jefe = leer(path.join(catalogo, 'ejemplos', 'invalidos', f));
    assert.strictEqual(validarJefe(jefe), false, f);
  }
});

test('el índice cumple su esquema', () => {
  const indice = leer(path.join(catalogo, 'catalogo.json'));
  assert.strictEqual(validarIndice(indice), true, JSON.stringify(validarIndice.errors));
});

test('el catálogo es coherente: cada jefe cumple el esquema y está en el índice', () => {
  const indice = leer(path.join(catalogo, 'catalogo.json'));
  const archivos = jsons(path.join(catalogo, 'bosses'));
  const ids = [];
  for (const f of archivos) {
    const jefe = leer(path.join(catalogo, 'bosses', f));
    assert.strictEqual(validarJefe(jefe), true, `${f}: ${JSON.stringify(validarJefe.errors)}`);
    assert.strictEqual(`${jefe.id}.json`, f, `${f}: el id debe coincidir con el nombre del archivo`);
    ids.push(jefe.id);
  }
  assert.deepStrictEqual([...ids].sort(), [...indice.jefes].sort(),
    'catalogo.json debe listar exactamente los jefes de bosses/');
});
