// Comprueba que el esquema del contrato (contrato/partida.v1.schema.json)
// acepta los ejemplos válidos y rechaza los inválidos de estructura. Es el
// mismo esquema con el que el backend validará las partidas que reciba.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const Ajv2020 = require('ajv/dist/2020');
const addFormats = require('ajv-formats');

const contrato = path.join(__dirname, '..', '..', 'contrato');

function compilar(version) {
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  addFormats(ajv);
  return ajv.compile(
    JSON.parse(fs.readFileSync(path.join(contrato, `partida.v${version}.schema.json`), 'utf8')),
  );
}

function ejemplos(version, carpeta) {
  const dir = path.join(contrato, 'ejemplos', `v${version}`, carpeta);
  return fs.readdirSync(dir).filter((f) => f.endsWith('.json')).map((f) => ({
    nombre: f,
    json: JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8')),
  }));
}

for (const version of [1, 2, 3, 4, 5, 6, 7, 8]) {
  const validar = compilar(version);

  for (const { nombre, json } of ejemplos(version, 'validos')) {
    test(`v${version} válido: ${nombre}`, () => {
      assert.ok(validar(json), JSON.stringify(validar.errors));
    });
  }

  for (const { nombre, json } of ejemplos(version, 'invalidos-estructura')) {
    test(`v${version} inválido de estructura: ${nombre}`, () => {
      assert.strictEqual(validar(json), false);
    });
  }

  // Estos ejemplos tienen la estructura correcta: los rechaza el motor porque
  // rompen las reglas del juego, no el esquema.
  for (const { nombre, json } of ejemplos(version, 'invalidos-reglas')) {
    test(`v${version} estructura válida, reglas incumplidas: ${nombre}`, () => {
      assert.ok(validar(json), JSON.stringify(validar.errors));
    });
  }
}

test('cada esquema solo acepta su versión', () => {
  const validadores = { 1: compilar(1), 2: compilar(2), 3: compilar(3), 4: compilar(4), 5: compilar(5), 6: compilar(6), 7: compilar(7), 8: compilar(8) };
  for (const version of [1, 2, 3, 4, 5, 6, 7, 8]) {
    for (const { json } of ejemplos(version, 'validos')) {
      for (const otra of [1, 2, 3, 4, 5, 6, 7, 8].filter((v) => v !== version)) {
        assert.strictEqual(validadores[otra](json), false);
      }
    }
  }
});
