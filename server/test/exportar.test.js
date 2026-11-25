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
    assert.ok(copiados.includes('contrato/campana/guardado.v1.schema.json'));
    assert.ok(copiados.includes('guardadoCampana.js'));
    assert.ok(copiados.includes('hitosCampana.js'));
    assert.ok(copiados.includes('catalogo/tienda.json') && copiados.includes('catalogo/topes-puntos.json'));
    // Se carga desde la copia y encuentra los esquemas de ./contrato.
    const { crearValidador } = require(path.join(destino, 'esquema.js'));
    const validar = crearValidador();
    const errores = validar({ version: 2 });
    // El validador del protocolo de sala también encuentra su esquema.
    const { crearValidadorSala } = require(path.join(destino, 'protocoloSala.js'));
    assert.deepStrictEqual(crearValidadorSala()({ tipo: 'ping' }).errores, []);
    assert.ok(errores.length > 0, 'un registro vacío no cumple el esquema');
    // El del guardado de campaña también (#478).
    const { crearValidadorGuardado } = require(path.join(destino, 'guardadoCampana.js'));
    assert.ok(crearValidadorGuardado()({}).length > 0);
    // Los hitos y la tienda (#374) encuentran su esquema y sus datos.
    const hitos = require(path.join(destino, 'hitosCampana.js'));
    assert.ok(hitos.crearValidadorHitos()({}).length > 0);
    assert.strictEqual(hitos.cargarTopes().jefe > 0, true);
    assert.ok(hitos.cargarTienda().productos.length > 0);
    // Y las compras de la tienda (#374), su esquema.
    const tienda = require(path.join(destino, 'tienda.js'));
    assert.ok(tienda.crearValidadorCompra()({}).length > 0);
  } finally {
    fs.rmSync(destino, { recursive: true, force: true });
  }
});
