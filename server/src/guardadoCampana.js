'use strict';
const fs = require('node:fs');
const path = require('node:path');
const express = require('express');
const Ajv2020 = require('ajv/dist/2020');
const addFormats = require('ajv-formats');

// Partida de campaña guardada en la cuenta (#478; D-20 §6). Una por cuenta y
// campaña. El guardado nunca abona puntos: eso va por los hitos (#374).

// En el monorepo, `contrato/` está dos niveles arriba; al exportar el módulo
// viaja en `./contrato` (scripts/exportar.js).
const ESQUEMA = path.join('campana', 'guardado.v1.schema.json');
const CARPETA_CONTRATO = [
  path.join(__dirname, '..', '..', 'contrato'),
  path.join(__dirname, 'contrato'),
].find((c) => fs.existsSync(path.join(c, ESQUEMA)))
  ?? path.join(__dirname, '..', '..', 'contrato');

// Tamaño máximo de la partida serializada: de sobra para un PC muy lleno.
const TAMANO_MAXIMO = 256 * 1024;
const CAMPANA = /^[a-z0-9][a-z0-9-]{0,31}$/;

function crearValidadorGuardado(carpeta = CARPETA_CONTRATO) {
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  addFormats(ajv);
  const validar = ajv.compile(JSON.parse(fs.readFileSync(path.join(carpeta, ESQUEMA), 'utf8')));
  return (cuerpo) => {
    if (validar(cuerpo)) return [];
    return (validar.errors || []).slice(0, 10).map((e) => ({
      ruta: e.instancePath || '/',
      mensaje: e.message,
    }));
  };
}

const respuesta = (g) => ({
  campana: g.campana,
  revision: g.revision,
  actualizadaEn: g.actualizadaEn,
  partida: g.partida,
});

/**
 * Rutas /campana/partidas/:campana. Se montan dentro de crearRouter, después
 * de la autenticación (req.cuentaId ya está puesto).
 */
function rutasGuardadoCampana({ repo, ahora, error, validar = crearValidadorGuardado() }) {
  const router = express.Router();
  const asincrono = (fn) => (req, res, next) => fn(req, res).catch(next);

  router.get('/campana/partidas/:campana', asincrono(async (req, res) => {
    const { campana } = req.params;
    if (!CAMPANA.test(campana)) return error(res, 400, 'parametro_invalido', 'campaña no válida');
    const g = await repo.obtenerGuardadoCampana(req.cuentaId, campana);
    if (!g) return error(res, 404, 'sin_partida', 'esta cuenta no tiene partida guardada en esa campaña');
    return res.json(respuesta(g));
  }));

  router.put('/campana/partidas/:campana', asincrono(async (req, res) => {
    const { campana } = req.params;
    if (!CAMPANA.test(campana)) return error(res, 400, 'parametro_invalido', 'campaña no válida');
    const cuerpo = req.body;
    const errores = validar(cuerpo);
    if (errores.length > 0) {
      return error(res, 400, 'estructura_invalida', 'el guardado no cumple el esquema', { errores });
    }
    if (Buffer.byteLength(JSON.stringify(cuerpo.partida)) > TAMANO_MAXIMO) {
      return error(res, 413, 'cuerpo_demasiado_grande', 'la partida guardada supera 256 KB');
    }
    const r = await repo.guardarGuardadoCampana({
      cuentaId: req.cuentaId,
      campana,
      revisionBase: cuerpo.revision,
      partida: cuerpo.partida,
      actualizadaEn: ahora().toISOString(),
    });
    if (!r.ok) {
      return error(res, 409, 'revision_distinta', 'la partida del servidor ha cambiado desde que la leíste', {
        actual: r.actual ? respuesta(r.actual) : null,
      });
    }
    return res.json(respuesta(r.guardado));
  }));

  return router;
}

module.exports = { rutasGuardadoCampana, crearValidadorGuardado, TAMANO_MAXIMO };
