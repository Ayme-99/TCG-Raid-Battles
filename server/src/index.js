'use strict';
const { crearRouter } = require('./router');
const { crearRepoMemoria } = require('./repoMemoria');
const { crearRepoMongo } = require('./repoMongo');
const { crearValidador } = require('./esquema');
const { crearSalas } = require('./salas');
const { montarSalas } = require('./ws');
const { crearValidadorGuardado } = require('./guardadoCampana');
const { crearValidadorHitos, cargarTopes, cargarTienda } = require('./hitosCampana');

module.exports = {
  crearRouter, crearRepoMemoria, crearRepoMongo, crearValidador, crearSalas, montarSalas,
  crearValidadorGuardado, crearValidadorHitos, cargarTopes, cargarTienda,
};
