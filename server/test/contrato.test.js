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
const ajv = new Ajv2020({ allErrors: true, strict: true });
addFormats(ajv);
const validar = ajv.compile(
  JSON.parse(fs.readFileSync(path.join(contrato, 'partida.v1.schema.json'), 'utf8')),
);

function ejemplos(carpeta) {
  const dir = path.join(contrato, 'ejemplos', carpeta);
  return fs.readdirSync(dir).filter((f) => f.endsWith('.json')).map((f) => ({
    nombre: f,
    json: JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8')),
  }));
}

for (const { nombre, json } of ejemplos('validos')) {
  test(`válido: ${nombre}`, () => {
    assert.ok(validar(json), JSON.stringify(validar.errors));
  });
}

for (const { nombre, json } of ejemplos('invalidos-estructura')) {
  test(`inválido de estructura: ${nombre}`, () => {
    assert.strictEqual(validar(json), false);
  });
}

// Estos ejemplos tienen la estructura correcta: los rechaza el motor porque
// rompen las reglas del juego, no el esquema.
for (const { nombre, json } of ejemplos('invalidos-reglas')) {
  test(`estructura válida, reglas incumplidas: ${nombre}`, () => {
    assert.ok(validar(json), JSON.stringify(validar.errors));
  });
}
