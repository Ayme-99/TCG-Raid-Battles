'use strict';
const fs = require('node:fs');
const path = require('node:path');
const express = require('express');
const Ajv2020 = require('ajv/dist/2020');
const addFormats = require('ajv-formats');

// Puntos de la campaña a la cuenta y tienda de la pantalla de inicio (#374,
// D-20 §5 y §6, D-21 §2). Los topes y el catálogo de la tienda son datos de
// `catalog/`; el esquema de los hitos, de `contrato/campana/`.

// En el monorepo están dos niveles arriba; al exportar el módulo viajan en
// `./contrato` y `./catalogo` (scripts/exportar.js).
function buscar(...relativa) {
  const opciones = [path.join(__dirname, '..', '..'), __dirname];
  const raiz = opciones.find((r) => fs.existsSync(path.join(r, ...relativa))) ?? opciones[0];
  return path.join(raiz, ...relativa);
}
const RUTA_ESQUEMA_HITOS = () => buscar('contrato', 'campana', 'hitos.v1.schema.json');
const RUTA_TOPES = () => {
  const enMonorepo = path.join(__dirname, '..', '..', 'catalog', 'campana', 'topes-puntos.json');
  return fs.existsSync(enMonorepo) ? enMonorepo : path.join(__dirname, 'catalogo', 'topes-puntos.json');
};
const RUTA_TIENDA = () => {
  const enMonorepo = path.join(__dirname, '..', '..', 'catalog', 'tienda', 'tienda.json');
  return fs.existsSync(enMonorepo) ? enMonorepo : path.join(__dirname, 'catalogo', 'tienda.json');
};

const leer = (ruta) => JSON.parse(fs.readFileSync(ruta, 'utf8'));

function crearValidadorHitos(ruta = RUTA_ESQUEMA_HITOS()) {
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  addFormats(ajv);
  const validar = ajv.compile(leer(ruta));
  return (cuerpo) => {
    if (validar(cuerpo)) return [];
    return (validar.errors || []).slice(0, 10).map((e) => ({
      ruta: e.instancePath || '/',
      mensaje: e.message,
    }));
  };
}

const cargarTopes = (ruta = RUTA_TOPES()) => leer(ruta).topes;
const cargarTienda = (ruta = RUTA_TIENDA()) => leer(ruta);

/**
 * Rutas POST /campana/hitos y GET /tienda. Se montan dentro de crearRouter,
 * después de la autenticación (req.cuentaId ya está puesto).
 */
function rutasHitosCampana({
  repo,
  ahora,
  error,
  validar = crearValidadorHitos(),
  topes = cargarTopes(),
  tienda = cargarTienda(),
}) {
  const router = express.Router();
  const asincrono = (fn) => (req, res, next) => fn(req, res).catch(next);

  // Abona los hitos nuevos. Idempotente por (cuenta, campaña, id).
  router.post('/campana/hitos', asincrono(async (req, res) => {
    const cuerpo = req.body;
    const errores = validar(cuerpo);
    if (errores.length > 0) {
      return error(res, 400, 'estructura_invalida', 'los hitos no cumplen el esquema', { errores });
    }
    const ids = cuerpo.hitos.map((h) => h.id);
    if (new Set(ids).size !== ids.length) {
      return error(res, 400, 'hito_repetido', 'el mismo id va dos veces en el envío');
    }
    const fuera = cuerpo.hitos
      .filter((h) => h.puntos > topes[h.tipo])
      .map((h) => ({ id: h.id, tipo: h.tipo, puntos: h.puntos, tope: topes[h.tipo] }));
    if (fuera.length > 0) {
      return error(res, 422, 'puntos_fuera_de_tope', 'hay hitos con más puntos que su tope', { hitos: fuera });
    }
    const r = await repo.abonarHitosCampana({
      cuentaId: req.cuentaId,
      campana: cuerpo.campana,
      hitos: cuerpo.hitos,
      abonadoEn: ahora().toISOString(),
    });
    if (r.distintos.length > 0) {
      return error(res, 409, 'hito_distinto', 'ya hay hitos con ese id y otros datos; no se ha abonado nada', {
        hitos: r.distintos,
      });
    }
    const { puntos } = await repo.puntosCampanaDe(req.cuentaId);
    return res.json({
      abonados: r.nuevos,
      repetidos: r.repetidos,
      puntosAbonados: cuerpo.hitos.filter((h) => r.nuevos.includes(h.id)).reduce((s, h) => s + h.puntos, 0),
      puntosCampana: puntos,
    });
  }));

  // Catálogo de la tienda de la pantalla de inicio (datos, D-21 §2.3).
  router.get('/tienda', (req, res) => res.json({ productos: tienda.productos }));

  return router;
}

module.exports = {
  rutasHitosCampana, crearValidadorHitos, cargarTopes, cargarTienda,
};
