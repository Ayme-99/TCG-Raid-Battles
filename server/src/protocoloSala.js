'use strict';
const fs = require('node:fs');
const path = require('node:path');
const Ajv2020 = require('ajv/dist/2020');
const addFormats = require('ajv-formats');

// En el monorepo, `contrato/` está dos niveles arriba; al exportar el módulo
// viaja en `./contrato` (scripts/exportar.js).
const CARPETA_CONTRATO = [
  path.join(__dirname, '..', '..', 'contrato'),
  path.join(__dirname, 'contrato'),
].find((c) => fs.existsSync(path.join(c, 'sala', 'sala.v1.schema.json')))
  ?? path.join(__dirname, '..', '..', 'contrato');

const VERSION_PROTOCOLO = 1;

// Mensajes que acepta el servidor, por quién los manda.
const DE_CLIENTE = { hola: 'hola', proponer: 'proponerCliente', salir: 'salir', ping: 'ping', pong: 'pong' };
const DE_HOST = {
  aceptar: 'aceptar', rechazar: 'rechazar', empezar: 'empezar', echar: 'echar', registro: 'registro',
};

/**
 * Compila los mensajes del protocolo (contrato/sala/sala.v1.schema.json).
 * Devuelve (mensaje) → { tipo, errores }: `errores` vacío si el mensaje es uno
 * de los que el servidor recibe y está bien formado.
 */
function crearValidadorSala(carpeta = CARPETA_CONTRATO) {
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  addFormats(ajv);
  const leer = (...p) => JSON.parse(fs.readFileSync(path.join(carpeta, ...p), 'utf8'));
  ajv.addSchema(leer('partida.v13.schema.json'));
  const esquema = leer('sala', 'sala.v1.schema.json');
  ajv.addSchema(esquema);
  const por = (def) => ajv.getSchema(`${esquema.$id}#/$defs/${def}`);
  const validadores = new Map(
    [...Object.entries(DE_CLIENTE), ...Object.entries(DE_HOST)].map(([tipo, def]) => [tipo, por(def)]),
  );
  return (mensaje) => {
    const tipo = mensaje && typeof mensaje === 'object' ? mensaje.tipo : undefined;
    const validar = validadores.get(tipo);
    if (!validar) return { tipo: tipo ?? null, errores: ['tipo de mensaje desconocido'] };
    if (validar(mensaje)) return { tipo, errores: [] };
    return {
      tipo,
      errores: (validar.errors || []).slice(0, 5).map((e) => `${e.instancePath || '/'} ${e.message}`),
    };
  };
}

module.exports = { crearValidadorSala, VERSION_PROTOCOLO, DE_CLIENTE, DE_HOST };
