'use strict';
const fs = require('node:fs');
const path = require('node:path');

const contrato = path.join(__dirname, '..', '..', 'contrato', 'ejemplos');

function ejemplo(carpeta, nombre) {
  return JSON.parse(fs.readFileSync(path.join(contrato, carpeta, `${nombre}.json`), 'utf8'));
}

// Copia de un registro con otro partidaId.
function conId(registro, partidaId) {
  return { ...structuredClone(registro), partidaId };
}

module.exports = { ejemplo, conId };
