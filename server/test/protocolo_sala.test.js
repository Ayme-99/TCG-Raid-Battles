// Comprueba que el esquema del protocolo de sala (contrato/sala/) acepta los
// ejemplos válidos y rechaza los inválidos. Los eventos van con el JSON del
// contrato del registro, así que se carga también ese esquema.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const Ajv2020 = require('ajv/dist/2020');
const addFormats = require('ajv-formats');

const contrato = path.join(__dirname, '..', '..', 'contrato');
const leer = (...partes) => JSON.parse(fs.readFileSync(path.join(contrato, ...partes), 'utf8'));

function compilar() {
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  addFormats(ajv);
  ajv.addSchema(leer('partida.v13.schema.json'));
  return ajv.compile(leer('sala', 'sala.v1.schema.json'));
}

function ejemplos(carpeta) {
  const dir = path.join(contrato, 'sala', 'ejemplos', carpeta);
  return fs.readdirSync(dir).filter((f) => f.endsWith('.json')).map((f) => ({
    nombre: f,
    json: leer('sala', 'ejemplos', carpeta, f),
  }));
}

const validar = compilar();

for (const { nombre, json } of ejemplos('validos')) {
  test(`mensaje válido: ${nombre}`, () => {
    assert.ok(validar(json), JSON.stringify(validar.errors));
  });
}

for (const { nombre, json } of ejemplos('invalidos-estructura')) {
  test(`mensaje inválido: ${nombre}`, () => {
    assert.strictEqual(validar(json), false);
  });
}

test('hay un ejemplo válido de cada mensaje del protocolo', () => {
  const tipos = new Set(ejemplos('validos').map(({ json }) => json.tipo));
  const esperados = [
    'hola', 'sala', 'proponer', 'aceptar', 'rechazar', 'evento',
    'jugadorDesconectado', 'jugadorVuelve', 'ventanaVencida',
    'partidaCancelada', 'registro', 'ping', 'pong', 'empezar', 'echar',
    'salir', 'error',
  ];
  for (const t of esperados) assert.ok(tipos.has(t), `falta un ejemplo de «${t}»`);
});

test('el esquema define los 18 mensajes (proponer tiene dos direcciones)', () => {
  const esquema = leer('sala', 'sala.v1.schema.json');
  assert.strictEqual(esquema.oneOf.length, 18);
});
