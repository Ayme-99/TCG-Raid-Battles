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
