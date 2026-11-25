'use strict';
const fs = require('node:fs');
const path = require('node:path');
const express = require('express');
const Ajv2020 = require('ajv/dist/2020');
const { COSTE_DESBLOQUEO } = require('./puntos');
const { cargarTienda } = require('./hitosCampana');

// Compras en la tienda de puntos (#374, D-21 §1.2 y §2). Decidido por Ayme el
// 2026-11-25 (opción C): hay un solo total por cuenta, comprar lo baja, y un
// jefe ya desbloqueado no vuelve a bloquearse.

// En el monorepo el esquema está dos niveles arriba; al exportar el módulo
// viaja en `./contrato` (scripts/exportar.js).
const RUTA_ESQUEMA_COMPRA = () => {
  const opciones = [path.join(__dirname, '..', '..'), __dirname];
  const relativa = ['contrato', 'campana', 'compra.v1.schema.json'];
  const raiz = opciones.find((r) => fs.existsSync(path.join(r, ...relativa))) ?? opciones[0];
  return path.join(raiz, ...relativa);
};

// PROPUESTA (pendiente de Ayme en #374): una moneda o unos dados se compran una
// vez por cuenta; lo demás (sobres, cartas sueltas) se puede repetir.
const FAMILIAS_UNICAS = new Set(['monedas', 'dados']);

function crearValidadorCompra(ruta = RUTA_ESQUEMA_COMPRA()) {
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  const validar = ajv.compile(JSON.parse(fs.readFileSync(ruta, 'utf8')));
  return (cuerpo) => {
    if (validar(cuerpo)) return [];
    return (validar.errors || []).slice(0, 10).map((e) => ({
      ruta: e.instancePath || '/',
      mensaje: e.message,
    }));
  };
}

// Niveles de jefe que da un total de puntos.
const nivelesCon = (puntos) => Object.entries(COSTE_DESBLOQUEO)
  .filter(([, coste]) => puntos >= coste)
  .map(([nivel]) => Number(nivel));

/**
 * Puntos de la cuenta: lo ganado en incursiones y en la campaña, menos lo
 * gastado en la tienda. `niveles` dice qué jefes están desbloqueados: los que
 * llega a pagar el total de ahora y los que ya se desbloquearon antes de una
 * compra, que se quedan así para siempre.
 */
async function puntosDeCuenta(repo, cuentaId) {
  const incursiones = await repo.puntosDe(cuentaId);
  const campana = await repo.puntosCampanaDe(cuentaId);
  const tienda = await repo.tiendaDe(cuentaId);
  const ganados = incursiones.puntos + campana.puntos;
  const puntos = ganados - tienda.gastado;
  const desbloqueados = new Set(tienda.niveles);
  return {
    puntos,
    partidas: incursiones.partidas,
    puntosIncursiones: incursiones.puntos,
    puntosCampana: campana.puntos,
    puntosGastados: tienda.gastado,
    ganados,
    tienda,
    niveles: Object.entries(COSTE_DESBLOQUEO).map(([nivel, coste]) => {
      const alcanzado = puntos >= coste || desbloqueados.has(Number(nivel));
      return {
        nivel: Number(nivel),
        coste,
        alcanzado,
        faltan: alcanzado ? 0 : coste - puntos,
      };
    }),
  };
}

/**
 * Rutas POST /tienda/compras y GET /tienda/compras. Se montan dentro de
 * crearRouter, después de la autenticación (req.cuentaId ya está puesto).
 */
function rutasTienda({
  repo, ahora, error, validar = crearValidadorCompra(), tienda = cargarTienda(),
}) {
  const router = express.Router();
  const asincrono = (fn) => (req, res, next) => fn(req, res).catch(next);
  const productos = new Map(tienda.productos.map((p) => [p.id, p]));

  router.post('/tienda/compras', asincrono(async (req, res) => {
    const cuerpo = req.body;
    const errores = validar(cuerpo);
    if (errores.length > 0) {
      return error(res, 400, 'estructura_invalida', 'la compra no cumple el esquema', { errores });
    }
    const producto = productos.get(cuerpo.producto);
    if (!producto) return error(res, 404, 'producto_desconocido', 'la tienda no tiene ese producto');
    if (!producto.disponible) return error(res, 409, 'no_disponible', 'ese producto todavía no se vende');
    if (producto.precio <= 0) {
      return error(res, 422, 'producto_gratis', 'ese producto es gratis y ya lo tiene toda cuenta');
    }
    const antes = await puntosDeCuenta(repo, req.cuentaId);
    const r = await repo.comprarEnTienda({
      cuentaId: req.cuentaId,
      compra: cuerpo.compra,
      producto: producto.id,
      precio: producto.precio,
      unico: FAMILIAS_UNICAS.has(producto.familia),
      ganados: antes.ganados,
      // Lo desbloqueado con el total de antes de pagar se queda así.
      niveles: nivelesCon(antes.puntos),
      compradaEn: ahora().toISOString(),
    });
    if (!r.ok) {
      const mensajes = {
        compra_distinta: 'ya hay una compra con ese id y otro producto',
        ya_comprado: 'la cuenta ya tiene ese producto',
        puntos_insuficientes: 'no hay puntos suficientes',
      };
      const extra = r.motivo === 'puntos_insuficientes'
        ? { puntos: antes.puntos, precio: producto.precio }
        : {};
      return error(res, 409, r.motivo, mensajes[r.motivo], extra);
    }
    const despues = await puntosDeCuenta(repo, req.cuentaId);
    return res.status(r.repetida ? 200 : 201).json({
      compra: r.compra,
      repetida: r.repetida,
      puntos: despues.puntos,
      niveles: despues.niveles,
    });
  }));

  // Lo que la cuenta ha comprado.
  router.get('/tienda/compras', asincrono(async (req, res) => {
    const t = await repo.tiendaDe(req.cuentaId);
    return res.json({ productos: t.productos, compras: t.compras, puntosGastados: t.gastado });
  }));

  return router;
}

module.exports = {
  rutasTienda, crearValidadorCompra, puntosDeCuenta, FAMILIAS_UNICAS,
};
