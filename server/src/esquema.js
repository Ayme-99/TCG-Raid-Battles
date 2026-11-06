'use strict';
const fs = require('node:fs');
const path = require('node:path');
const Ajv2020 = require('ajv/dist/2020');
const addFormats = require('ajv-formats');

const RUTA_POR_DEFECTO = path.join(__dirname, '..', '..', 'contrato', 'partida.v1.schema.json');

// Versión del registro que entiende este servidor (contrato/README.md).
const VERSION_SOPORTADA = 1;

// Compila el esquema del contrato. Devuelve (registro) → lista de errores
// (vacía si es válido).
function crearValidador(ruta = RUTA_POR_DEFECTO) {
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  addFormats(ajv);
  const validar = ajv.compile(JSON.parse(fs.readFileSync(ruta, 'utf8')));
  return (registro) => {
    if (validar(registro)) return [];
    return (validar.errors || []).slice(0, 10).map((e) => ({
      ruta: e.instancePath || '/',
      mensaje: e.message,
    }));
  };
}

module.exports = { crearValidador, VERSION_SOPORTADA };
