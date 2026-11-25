#!/usr/bin/env node
'use strict';

// Copia el módulo del servidor y los esquemas del contrato a una carpeta de
// otro repo (el backend de TCGMasters). Uso:
//   node server/scripts/exportar.js ../TCGMasters-server/src/modules/tcg-raid-battles
// Solo toca los archivos del módulo y `contrato/`; no borra nada más del
// destino (allí vive, por ejemplo, `montar.js`, que es del host).
const fs = require('node:fs');
const path = require('node:path');

const RAIZ = path.join(__dirname, '..', '..');
const ORIGEN_SRC = path.join(RAIZ, 'server', 'src');
const ORIGEN_CONTRATO = path.join(RAIZ, 'contrato');
const ORIGEN_CATALOGO = path.join(RAIZ, 'catalog');

function exportar(destino) {
  fs.mkdirSync(path.join(destino, 'contrato'), { recursive: true });
  const copiados = [];
  for (const nombre of fs.readdirSync(ORIGEN_SRC).filter((f) => f.endsWith('.js')).sort()) {
    fs.copyFileSync(path.join(ORIGEN_SRC, nombre), path.join(destino, nombre));
    copiados.push(nombre);
  }
  for (const nombre of fs.readdirSync(ORIGEN_CONTRATO).filter((f) => /^partida\.v\d+\.schema\.json$/.test(f)).sort()) {
    fs.copyFileSync(path.join(ORIGEN_CONTRATO, nombre), path.join(destino, 'contrato', nombre));
    copiados.push(`contrato/${nombre}`);
  }
  // Esquema del protocolo de sala (T-78), que carga src/protocoloSala.js.
  fs.mkdirSync(path.join(destino, 'contrato', 'sala'), { recursive: true });
  fs.copyFileSync(
    path.join(ORIGEN_CONTRATO, 'sala', 'sala.v1.schema.json'),
    path.join(destino, 'contrato', 'sala', 'sala.v1.schema.json'),
  );
  copiados.push('contrato/sala/sala.v1.schema.json');
  // Esquemas de la campaña con la cuenta (guardado #478 e hitos #374), que
  // cargan src/guardadoCampana.js y src/hitosCampana.js.
  fs.mkdirSync(path.join(destino, 'contrato', 'campana'), { recursive: true });
  for (const nombre of fs.readdirSync(path.join(ORIGEN_CONTRATO, 'campana')).filter((f) => f.endsWith('.schema.json')).sort()) {
    fs.copyFileSync(path.join(ORIGEN_CONTRATO, 'campana', nombre), path.join(destino, 'contrato', 'campana', nombre));
    copiados.push(`contrato/campana/${nombre}`);
  }
  // Datos de los hitos y la tienda (#374), que carga src/hitosCampana.js.
  fs.mkdirSync(path.join(destino, 'catalogo'), { recursive: true });
  for (const [origen, nombre] of [
    [path.join(ORIGEN_CATALOGO, 'campana', 'topes-puntos.json'), 'topes-puntos.json'],
    [path.join(ORIGEN_CATALOGO, 'tienda', 'tienda.json'), 'tienda.json'],
  ]) {
    fs.copyFileSync(origen, path.join(destino, 'catalogo', nombre));
    copiados.push(`catalogo/${nombre}`);
  }
  fs.writeFileSync(
    path.join(destino, 'ORIGEN.md'),
    [
      '# Módulo de Incursiones',
      '',
      'Estos archivos (todo menos `montar.js`) **no se editan aquí**: vienen de',
      'https://github.com/Ayme-99/TCG-Raid-Battles (`server/` y `contrato/`) y se',
      'regeneran con `node server/scripts/exportar.js <esta carpeta>`.',
      '',
    ].join('\n'),
  );
  return copiados;
}

if (require.main === module) {
  const destino = process.argv[2];
  if (!destino) {
    console.error('Uso: node server/scripts/exportar.js <carpeta de destino>');
    process.exit(1);
  }
  const copiados = exportar(path.resolve(destino));
  console.log(`Exportados ${copiados.length} archivos a ${destino}`);
}

module.exports = { exportar };
