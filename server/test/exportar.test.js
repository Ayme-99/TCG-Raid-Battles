'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { exportar } = require('../scripts/exportar');

test('el módulo exportado funciona fuera del monorepo', () => {
  // Dentro de server/ para que `ajv` se resuelva desde su node_modules.
  const destino = fs.mkdtempSync(path.join(__dirname, '..', 'exportado-prueba-'));
  try {
    const copiados = exportar(destino);
    assert.ok(copiados.includes('router.js'));
    assert.ok(copiados.includes('contrato/partida.v2.schema.json'));
    assert.ok(copiados.includes('contrato/sala/sala.v1.schema.json'));
    assert.ok(copiados.includes('ws.js') && copiados.includes('salas.js'));
    // Se carga desde la copia y encuentra los esquemas de ./contrato.
    const { crearValidador } = require(path.join(destino, 'esquema.js'));
    const validar = crearValidador();
    const errores = validar({ version: 2 });
    // El validador del protocolo de sala también encuentra su esquema.
    const { crearValidadorSala } = require(path.join(destino, 'protocoloSala.js'));
    assert.deepStrictEqual(crearValidadorSala()({ tipo: 'ping' }).errores, []);
    assert.ok(errores.length > 0, 'un registro vacío no cumple el esquema');
  } finally {
    fs.rmSync(destino, { recursive: true, force: true });
  }
});
