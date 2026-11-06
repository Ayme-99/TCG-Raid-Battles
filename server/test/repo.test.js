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
