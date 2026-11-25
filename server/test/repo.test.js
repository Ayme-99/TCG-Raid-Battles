'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { crearRepoMemoria } = require('../src/repoMemoria');
const { crearRepoMongo } = require('../src/repoMongo');

function fila(partidaId, asiento, cuentaId, puntos, abonado, guardadaEn) {
  return { partidaId, asiento, cuentaId, puntos, abonado, guardadaEn, puesto: asiento + 1 };
}
const partida = (id, guardadaEn) => ({ partidaId: id, guardadaEn, registro: { cuentas: ['a', 'b'] } });

// Las mismas pruebas valen para cualquier repositorio.
function pruebasDeRepo(nombre, crear, opciones = {}) {
  test(`${nombre}: guardar es idempotente y no duplica filas`, opciones, async (t) => {
    const repo = await crear(t);
    const filas = [fila('p1', 0, 'a', 100, true, 't1'), fila('p1', 1, 'b', 50, true, 't1')];
    const una = await repo.guardarPartida({ partida: partida('p1', 't1'), jugadores: filas });
    const dos = await repo.guardarPartida({ partida: partida('p1', 't9'), jugadores: filas });
    assert.strictEqual(una.creada, true);
    assert.strictEqual(dos.creada, false);
    assert.strictEqual(dos.partida.guardadaEn, 't1'); // se conserva la primera
    assert.deepStrictEqual(await repo.puntosDe('a'), { puntos: 100, partidas: 1 });
  });

  test(`${nombre}: un reintento completa las filas que faltaban`, opciones, async (t) => {
    const repo = await crear(t);
    await repo.guardarPartida({ partida: partida('p1', 't1'), jugadores: [fila('p1', 0, 'a', 100, true, 't1')] });
    await repo.guardarPartida({
      partida: partida('p1', 't1'),
      jugadores: [fila('p1', 0, 'a', 100, true, 't1'), fila('p1', 1, 'b', 50, true, 't1')],
    });
    assert.deepStrictEqual(await repo.puntosDe('b'), { puntos: 50, partidas: 1 });
    assert.deepStrictEqual(await repo.puntosDe('a'), { puntos: 100, partidas: 1 });
  });

  test(`${nombre}: puntosDe suma solo lo abonado`, opciones, async (t) => {
    const repo = await crear(t);
    await repo.guardarPartida({ partida: partida('p1', 't1'), jugadores: [fila('p1', 0, 'a', 100, true, 't1')] });
    await repo.guardarPartida({ partida: partida('p2', 't2'), jugadores: [fila('p2', 0, 'a', 70, false, 't2')] });
    assert.deepStrictEqual(await repo.puntosDe('a'), { puntos: 100, partidas: 2 });
    assert.deepStrictEqual(await repo.puntosDe('nadie'), { puntos: 0, partidas: 0 });
  });

  test(`${nombre}: puntosDe suma también el bono de estados`, opciones, async (t) => {
    const repo = await crear(t);
    const conBono = { ...fila('p1', 0, 'a', 100, true, 't1'), bonoEstados: 30 };
    const invitado = { ...fila('p2', 0, 'a', 100, false, 't2'), bonoEstados: 60 };
    await repo.guardarPartida({ partida: partida('p1', 't1'), jugadores: [conBono] });
    await repo.guardarPartida({ partida: partida('p2', 't2'), jugadores: [invitado] });
    assert.deepStrictEqual(await repo.puntosDe('a'), { puntos: 130, partidas: 2 });
  });

  test(`${nombre}: obtenerPartida devuelve null si no existe`, opciones, async (t) => {
    const repo = await crear(t);
    assert.strictEqual(await repo.obtenerPartida('x'), null);
    await repo.guardarPartida({ partida: partida('p1', 't1'), jugadores: [fila('p1', 0, 'a', 1, true, 't1')] });
    assert.strictEqual((await repo.obtenerPartida('p1')).partidaId, 'p1');
  });

  test(`${nombre}: listar ordena por fecha y pagina con cursor`, opciones, async (t) => {
    const repo = await crear(t);
    for (const [id, t] of [['p1', 't1'], ['p2', 't2'], ['p3', 't3'], ['p4', 't3']]) {
      await repo.guardarPartida({ partida: partida(id, t), jugadores: [fila(id, 0, 'a', 1, true, t)] });
    }
    const ids = (filas) => filas.map((f) => f.partidaId);
    assert.deepStrictEqual(ids(await repo.listar('a', { limite: 10, antes: null })), ['p4', 'p3', 'p2', 'p1']);
    assert.deepStrictEqual(
      ids(await repo.listar('a', { limite: 10, antes: { guardadaEn: 't3', partidaId: 'p4' } })),
      ['p3', 'p2', 'p1'],
    );
    assert.deepStrictEqual(ids(await repo.listar('a', { limite: 1, antes: null })), ['p4']);
    assert.deepStrictEqual(ids(await repo.listar('b', { limite: 10, antes: null })), []);
  });

  test(`${nombre}: la partida de campaña se guarda por revisión (#478)`, opciones, async (t) => {
    const repo = await crear(t);
    const base = { cuentaId: 'a', campana: 'kanto', actualizadaEn: 't1' };
    assert.strictEqual(await repo.obtenerGuardadoCampana('a', 'kanto'), null);
    const una = await repo.guardarGuardadoCampana({ ...base, revisionBase: 0, partida: { dinero: 1 } });
    assert.strictEqual(una.ok, true);
    assert.strictEqual(una.guardado.revision, 1);
    const otra = await repo.guardarGuardadoCampana({ ...base, revisionBase: 0, partida: { dinero: 2 } });
    assert.strictEqual(otra.ok, false);
    assert.deepStrictEqual(otra.actual.partida, { dinero: 1 });
    const dos = await repo.guardarGuardadoCampana({ ...base, revisionBase: 1, partida: { dinero: 3 }, actualizadaEn: 't2' });
    assert.strictEqual(dos.ok, true);
    assert.strictEqual(dos.guardado.revision, 2);
    const vieja = await repo.guardarGuardadoCampana({ ...base, revisionBase: 1, partida: { dinero: 4 } });
    assert.strictEqual(vieja.ok, false);
    assert.strictEqual(vieja.actual.revision, 2);
    const leida = await repo.obtenerGuardadoCampana('a', 'kanto');
    assert.deepStrictEqual(leida, {
      cuentaId: 'a', campana: 'kanto', revision: 2, actualizadaEn: 't2', partida: { dinero: 3 },
    });
    assert.strictEqual(await repo.obtenerGuardadoCampana('b', 'kanto'), null);
    const sinNada = await repo.guardarGuardadoCampana({ ...base, cuentaId: 'b', revisionBase: 4, partida: {} });
    assert.deepStrictEqual(sinNada, { ok: false, actual: null });
  });

  test(`${nombre}: los hitos de campaña se abonan una vez por id (#374)`, opciones, async (t) => {
    const repo = await crear(t);
    const base = { cuentaId: 'a', campana: 'kanto', partida: 'p1', abonadoEn: 't1' };
    const h1 = { id: 'ruta-1-pidgey', tipo: 'salvaje', puntos: 100 };
    const h2 = { id: 'pikachu', tipo: 'jefe', puntos: 1000 };
    assert.deepStrictEqual(await repo.puntosCampanaDe('a'), { puntos: 0, hitos: 0 });
    assert.deepStrictEqual(await repo.abonarHitosCampana({ ...base, hitos: [h1] }),
      { nuevos: ['ruta-1-pidgey'], repetidos: [], distintos: [] });
    assert.deepStrictEqual(await repo.abonarHitosCampana({ ...base, hitos: [h1, h2] }),
      { nuevos: ['pikachu'], repetidos: ['ruta-1-pidgey'], distintos: [] });
    assert.deepStrictEqual(await repo.puntosCampanaDe('a'), { puntos: 1100, hitos: 2 });
    const otro = await repo.abonarHitosCampana({ ...base, hitos: [{ ...h1, puntos: 90 }, { id: 'x', tipo: 'salvaje', puntos: 10 }] });
    assert.deepStrictEqual(otro, {
      nuevos: [], repetidos: [], distintos: [{ id: 'ruta-1-pidgey', tipo: 'salvaje', puntos: 100 }],
    });
    assert.deepStrictEqual(await repo.puntosCampanaDe('a'), { puntos: 1100, hitos: 2 });
    // Otra campaña u otra cuenta no chocan.
    await repo.abonarHitosCampana({ ...base, campana: 'johto', hitos: [h1] });
    await repo.abonarHitosCampana({ ...base, cuentaId: 'b', hitos: [h1] });
    assert.deepStrictEqual(await repo.puntosCampanaDe('a'), { puntos: 1200, hitos: 3 });
    assert.deepStrictEqual(await repo.puntosCampanaDe('b'), { puntos: 100, hitos: 1 });
    // Una partida nueva de la misma campaña los vuelve a dar (Ayme, 2026-11-25).
    assert.deepStrictEqual(await repo.abonarHitosCampana({ ...base, partida: 'p2', hitos: [h1, h2] }),
      { nuevos: ['ruta-1-pidgey', 'pikachu'], repetidos: [], distintos: [] });
    assert.deepStrictEqual(await repo.puntosCampanaDe('a'), { puntos: 2300, hitos: 5 });
  });
}

pruebasDeRepo('memoria', async () => crearRepoMemoria());

// Contra una base MongoDB real, solo si hay MONGO_URL (el CI levanta una).
const hayMongo = Boolean(process.env.MONGO_URL);
pruebasDeRepo(
  'mongo',
  async (t) => {
    const { MongoClient } = require('mongodb');
    const cliente = await MongoClient.connect(process.env.MONGO_URL);
    const db = cliente.db(`incursiones_test_${Date.now()}_${Math.floor(Math.random() * 1e6)}`);
    t.after(async () => {
      await db.dropDatabase();
      await cliente.close();
    });
    const repo = crearRepoMongo(db);
    await repo.asegurarIndices();
    return repo;
  },
  { skip: hayMongo ? false : 'sin MONGO_URL' },
);
