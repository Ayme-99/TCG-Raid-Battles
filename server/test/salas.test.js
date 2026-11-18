'use strict';
const test = require('node:test');
const assert = require('node:assert');
const http = require('node:http');
const express = require('express');
const WebSocket = require('ws');
const { crearRouter, crearRepoMemoria, crearSalas, montarSalas } = require('../src');
const { ALFABETO } = require('../src/salas');

const EVENTO = { tipo: 'turnoJugador', jugador: 1, dano: 120 };
const EVENTO_B = { tipo: 'turnoJugador', jugador: 2, dano: 40 };

// --- lógica de salas (sin red) ---------------------------------------
test('el código tiene 5 caracteres sin letras ambiguas y es único entre las vivas', () => {
  const salas = crearSalas();
  const codigos = new Set();
  for (let i = 0; i < 300; i++) {
    const r = salas.crear(`c${i}`, `n${i}`);
    assert.match(r.sala.codigo, /^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{5}$/);
    codigos.add(r.sala.codigo);
  }
  assert.strictEqual(codigos.size, 300);
  assert.ok(![...'01ILO'].some((c) => ALFABETO.includes(c)));
});

test('si el código ya está vivo se genera otro', () => {
  const cola = ['AAAAA', 'AAAAA', 'BBBBB'];
  const salas = crearSalas({ generarCodigo: () => cola.shift() });
  assert.strictEqual(salas.crear('a', 'Ana').sala.codigo, 'AAAAA');
  assert.strictEqual(salas.crear('b', 'Bea').sala.codigo, 'BBBBB');
});

test('una cuenta solo puede estar en una sala viva', () => {
  const salas = crearSalas();
  const { sala } = salas.crear('a', 'Ana');
  assert.deepStrictEqual(salas.crear('a', 'Ana'), { ok: false, error: 'yaEnSala', codigo: sala.codigo });
  salas.cerrar(sala);
  assert.ok(salas.crear('a', 'Ana').ok);
});

test('hasta 4 jugadores, el host es el asiento 0 y la sala llena pasa a completa', () => {
  const salas = crearSalas();
  const { sala } = salas.crear('a', 'Ana');
  for (const [i, c] of ['b', 'c', 'd'].entries()) {
    const r = salas.entrar(sala.codigo, c, c);
    assert.strictEqual(r.jugador.asiento, i + 1);
  }
  assert.strictEqual(sala.estado, 'completa');
  assert.strictEqual(salas.entrar(sala.codigo, 'e', 'e').error, 'salaLlena');
  assert.strictEqual(salas.entrar('ZZZZZ', 'e', 'e').error, 'salaNoExiste');
});

test('al quitar a alguien los asientos vuelven a ser seguidos', () => {
  const salas = crearSalas();
  const { sala } = salas.crear('a', 'Ana');
  for (const c of ['b', 'c', 'd']) salas.entrar(sala.codigo, c, c);
  salas.quitar(sala, 'b');
  assert.deepStrictEqual(sala.jugadores.map((j) => [j.cuentaId, j.asiento]), [['a', 0], ['c', 1], ['d', 2]]);
  assert.strictEqual(sala.estado, 'abierta');
});

test('empezada la sala solo vuelve a entrar quien ya estaba', () => {
  const salas = crearSalas();
  const { sala } = salas.crear('a', 'Ana');
  salas.entrar(sala.codigo, 'b', 'Bea');
  assert.ok(salas.empezar(sala, 'p-1', '2026-11-18T22:00:00.000Z').ok);
  assert.strictEqual(salas.entrar(sala.codigo, 'c', 'Cai').error, 'salaCerrada');
  assert.strictEqual(salas.entrar(sala.codigo, 'b', 'Bea').nuevo, false);
  assert.strictEqual(salas.empezar(sala, 'p-2', '2026-11-18T22:00:00.000Z').error, 'salaCerrada');
});

test('no se puede empezar con un solo jugador', () => {
  const salas = crearSalas();
  const { sala } = salas.crear('a', 'Ana');
  assert.strictEqual(salas.empezar(sala, 'p-1', '2026-11-18T22:00:00.000Z').error, 'pocosJugadores');
  assert.strictEqual(sala.estado, 'abierta');
  salas.entrar(sala.codigo, 'b', 'Bea');
  assert.ok(salas.empezar(sala, 'p-1', '2026-11-18T22:00:00.000Z').ok);
});

test('el registro exige el seq siguiente', () => {
  const salas = crearSalas();
  const { sala } = salas.crear('a', 'Ana');
  assert.strictEqual(salas.registrar(sala, 1, EVENTO).error, 'salaCerrada');
  salas.entrar(sala.codigo, 'b', 'Bea');
  salas.empezar(sala, 'p-1', '2026-11-18T22:00:00.000Z');
  assert.strictEqual(salas.registrar(sala, 2, EVENTO).error, 'seqFueraDeOrden');
  assert.ok(salas.registrar(sala, 1, EVENTO).ok);
  assert.strictEqual(salas.registrar(sala, 1, EVENTO).error, 'seqFueraDeOrden');
});

// --- POST /salas y WebSocket ----------------------------------------
async function arrancar(opciones = {}) {
  const salas = crearSalas();
  const app = express();
  app.use('/api/incursiones', crearRouter({
    repo: crearRepoMemoria(),
    autenticar: (req, res, next) => { req.usuarioId = req.get('x-usuario') || undefined; next(); },
    nombreDe: (req) => `Nombre ${req.cuentaId}`,
    salas,
  }));
  const servidor = http.createServer(app);
  await new Promise((ok) => servidor.listen(0, ok));
  const ws = montarSalas({
    servidor,
    salas,
    verificarToken: async (token) => (token.startsWith('tok-')
      ? { cuentaId: token.slice(4), nombre: `Nombre ${token.slice(4)}` }
      : null),
    esperaHolaMs: 300,
    ...opciones,
  });
  const puerto = servidor.address().port;
  const abiertos = [];
  const crearSala = async (usuario) => {
    const r = await fetch(`http://127.0.0.1:${puerto}/api/incursiones/salas`, {
      method: 'POST', headers: { 'x-usuario': usuario },
    });
    return { estado: r.status, json: await r.json() };
  };
  // Cliente de pruebas: guarda lo que llega y deja esperar un mensaje por tipo.
  const conectar = async ({ autoPong = false } = {}) => {
    const s = new WebSocket(`ws://127.0.0.1:${puerto}/api/incursiones/ws`);
    const recibidos = [];
    const espera = [];
    s.on('message', (d) => {
      const m = JSON.parse(d.toString());
      recibidos.push(m);
      if (autoPong && m.tipo === 'ping') s.send(JSON.stringify({ tipo: 'pong' }));
      for (const e of [...espera]) if (e.ok(m)) { espera.splice(espera.indexOf(e), 1); e.res(m); }
    });
    const cierre = new Promise((res) => s.on('close', (codigo) => res(codigo)));
    await new Promise((res, rej) => { s.on('open', res); s.on('error', rej); });
    abiertos.push(s);
    return {
      s, recibidos, cierre,
      mandar: (m) => s.send(typeof m === 'string' ? m : JSON.stringify(m)),
      siguiente: (tipo, cond = () => true) => {
        const ya = recibidos.find((m) => m.tipo === tipo && cond(m) && !m.__visto);
        if (ya) { ya.__visto = true; return Promise.resolve(ya); }
        return new Promise((res, rej) => {
          const t = setTimeout(() => rej(new Error(`no llegó ${tipo}; llegó ${JSON.stringify(recibidos)}`)), 2000);
          espera.push({ ok: (m) => m.tipo === tipo && cond(m), res: (m) => { clearTimeout(t); m.__visto = true; res(m); } });
        });
      },
    };
  };
  const cerrar = async () => {
    for (const s of abiertos) s.terminate();
    await ws.cerrar();
    await new Promise((ok) => servidor.close(ok));
  };
  return { salas, crearSala, conectar, cerrar };
}

// Entra con `hola` y espera el estado de la sala.
async function entrar(c, usuario, codigo, extra = {}) {
  c.mandar({ tipo: 'hola', protocolo: 1, token: `tok-${usuario}`, codigo, ...extra });
  return c.siguiente('sala');
}

test('POST /salas devuelve el código y una segunda sala de la misma cuenta da 409', async (t) => {
  const { crearSala, cerrar } = await arrancar();
  t.after(cerrar);
  const a = await crearSala('ana');
  assert.strictEqual(a.estado, 201);
  assert.match(a.json.codigo, /^[A-Z2-9]{5}$/);
  const b = await crearSala('ana');
  assert.strictEqual(b.estado, 409);
  assert.strictEqual(b.json.error, 'ya_en_sala');
  assert.strictEqual(b.json.codigo, a.json.codigo);
  const sin = await crearSala('');
  assert.strictEqual(sin.estado, 401);
});

test('entran los jugadores, todos ven la sala y el host es el asiento 0', async (t) => {
  const { crearSala, conectar, cerrar } = await arrancar();
  t.after(cerrar);
  const { json: { codigo } } = await crearSala('ana');
  const ana = await conectar();
  const sa = await entrar(ana, 'ana', codigo);
  assert.deepStrictEqual([sa.estado, sa.host, sa.tuAsiento, sa.ultimoSeq], ['abierta', 0, 0, 0]);
  const bea = await conectar();
  const sb = await entrar(bea, 'bea', codigo);
  assert.strictEqual(sb.tuAsiento, 1);
  assert.deepStrictEqual(sb.jugadores.map((j) => [j.asiento, j.nombre, j.conectado]),
    [[0, 'Nombre ana', true], [1, 'Nombre bea', true]]);
  const sa2 = await ana.siguiente('sala', (m) => m.jugadores.length === 2);
  assert.strictEqual(sa2.tuAsiento, 0);
});

test('errores al entrar: sesión, sala, protocolo y sala llena', async (t) => {
  const { crearSala, conectar, cerrar } = await arrancar();
  t.after(cerrar);
  const { json: { codigo } } = await crearSala('ana');

  const a = await conectar();
  a.mandar({ tipo: 'hola', protocolo: 1, token: 'malo', codigo });
  assert.strictEqual((await a.siguiente('error')).codigo, 'sesionNoValida');

  const b = await conectar();
  b.mandar({ tipo: 'hola', protocolo: 1, token: 'tok-bea', codigo: 'ZZZZZ' });
  assert.strictEqual((await b.siguiente('error')).codigo, 'salaNoExiste');

  const c = await conectar();
  c.mandar({ tipo: 'hola', protocolo: 2, token: 'tok-cai', codigo });
  assert.strictEqual((await c.siguiente('error')).codigo, 'protocoloNoSoportado');

  const d = await conectar();
  d.mandar({ tipo: 'ping' });
  assert.strictEqual((await d.siguiente('error')).codigo, 'mensajeNoValido');
  assert.strictEqual(await d.cierre, 1008);

  for (const u of ['ana', 'bea', 'cai', 'dai']) await entrar(await conectar(), u, codigo);
  const e = await conectar();
  e.mandar({ tipo: 'hola', protocolo: 1, token: 'tok-eva', codigo });
  assert.strictEqual((await e.siguiente('error')).codigo, 'salaLlena');
});

test('sin hola a tiempo se cierra la conexión', async (t) => {
  const { conectar, cerrar } = await arrancar();
  t.after(cerrar);
  const c = await conectar();
  assert.strictEqual(await c.cierre, 1008);
});

test('un mensaje que no es JSON o no cumple el esquema da error y no tira la conexión', async (t) => {
  const { crearSala, conectar, cerrar } = await arrancar();
  t.after(cerrar);
  const { json: { codigo } } = await crearSala('ana');
  const ana = await conectar();
  await entrar(ana, 'ana', codigo);
  ana.mandar('esto no es json');
  assert.strictEqual((await ana.siguiente('error')).codigo, 'mensajeNoValido');
  ana.mandar({ tipo: 'empezar', partidaId: 'p-1' });
  assert.strictEqual((await ana.siguiente('error')).codigo, 'mensajeNoValido');
  ana.mandar({ tipo: 'ping' });
  await ana.siguiente('pong');
});

async function partida(t, jugadores = ['ana', 'bea'], opciones = {}, cliente = {}) {
  const ctx = await arrancar(opciones);
  t.after(ctx.cerrar);
  const { json: { codigo } } = await ctx.crearSala(jugadores[0]);
  const clientes = {};
  for (const u of jugadores) {
    clientes[u] = await ctx.conectar(cliente);
    await entrar(clientes[u], u, codigo);
  }
  clientes[jugadores[0]].mandar({ tipo: 'empezar', partidaId: 'p-1', creadaEn: '2026-11-18T22:00:00.000Z' });
  for (const u of jugadores) {
    const s = await clientes[u].siguiente('sala', (m) => m.estado === 'enCurso');
    assert.deepStrictEqual([s.partidaId, s.creadaEn], ['p-1', '2026-11-18T22:00:00.000Z']);
  }
  return { ...ctx, codigo, ...clientes };
}

test('el host solo no puede empezar la partida', async (t) => {
  const ctx = await arrancar();
  t.after(ctx.cerrar);
  const { json: { codigo } } = await ctx.crearSala('ana');
  const ana = await ctx.conectar(); await entrar(ana, 'ana', codigo);
  ana.mandar({ tipo: 'empezar', partidaId: 'p-1', creadaEn: '2026-11-18T22:00:00.000Z' });
  assert.strictEqual((await ana.siguiente('error')).codigo, 'mensajeNoValido');
});

test('solo el host puede empezar, echar y aceptar', async (t) => {
  const ctx = await arrancar();
  t.after(ctx.cerrar);
  const { json: { codigo } } = await ctx.crearSala('ana');
  const ana = await ctx.conectar(); await entrar(ana, 'ana', codigo);
  const bea = await ctx.conectar(); await entrar(bea, 'bea', codigo);
  for (const m of [
    { tipo: 'empezar', partidaId: 'p', creadaEn: '2026-11-18T22:00:00.000Z' },
    { tipo: 'echar', asiento: 0 },
    { tipo: 'aceptar', seq: 1, evento: EVENTO },
  ]) {
    bea.mandar(m);
    assert.strictEqual((await bea.siguiente('error')).codigo, 'noEsHost');
  }
});

test('proponer → host → aceptar: todos reciben el evento con su seq y el idMensaje', async (t) => {
  const p = await partida(t, ['ana', 'bea', 'cai']);
  p.bea.mandar({ tipo: 'proponer', idMensaje: 'm-1', evento: EVENTO });
  const prop = await p.ana.siguiente('proponer');
  assert.deepStrictEqual([prop.idMensaje, prop.asiento, prop.evento], ['m-1', 1, EVENTO]);
  p.ana.mandar({ tipo: 'aceptar', seq: 1, evento: EVENTO, idMensaje: 'm-1' });
  for (const u of ['ana', 'bea', 'cai']) {
    const e = await p[u].siguiente('evento');
    assert.deepStrictEqual([e.seq, e.evento, e.idMensaje], [1, EVENTO, 'm-1']);
  }
  // evento del propio host (sin idMensaje)
  p.ana.mandar({ tipo: 'aceptar', seq: 2, evento: EVENTO_B });
  const e2 = await p.cai.siguiente('evento', (m) => m.seq === 2);
  assert.strictEqual(e2.idMensaje, undefined);
});

test('un reintento con el mismo idMensaje no se reenvía al host ni se aplica dos veces', async (t) => {
  const p = await partida(t);
  p.bea.mandar({ tipo: 'proponer', idMensaje: 'm-1', evento: EVENTO });
  await p.ana.siguiente('proponer');
  p.bea.mandar({ tipo: 'proponer', idMensaje: 'm-1', evento: EVENTO }); // reintento pendiente
  p.ana.mandar({ tipo: 'aceptar', seq: 1, evento: EVENTO, idMensaje: 'm-1' });
  await p.bea.siguiente('evento');
  p.bea.mandar({ tipo: 'proponer', idMensaje: 'm-1', evento: EVENTO }); // reintento ya aceptado
  const otra = await p.bea.siguiente('evento');
  assert.strictEqual(otra.seq, 1);
  assert.strictEqual(p.ana.recibidos.filter((m) => m.tipo === 'proponer').length, 1);
  assert.strictEqual(p.ana.recibidos.filter((m) => m.tipo === 'evento').length, 1);
});

test('rechazar se reenvía solo a quien propuso', async (t) => {
  const p = await partida(t, ['ana', 'bea', 'cai']);
  p.cai.mandar({ tipo: 'proponer', idMensaje: 'm-9', evento: EVENTO });
  await p.ana.siguiente('proponer');
  p.ana.mandar({ tipo: 'rechazar', idMensaje: 'm-9', motivo: 'no es tu turno' });
  const r = await p.cai.siguiente('rechazar');
  assert.deepStrictEqual([r.idMensaje, r.motivo], ['m-9', 'no es tu turno']);
  assert.ok(!p.bea.recibidos.some((m) => m.tipo === 'rechazar'));
  p.ana.mandar({ tipo: 'rechazar', idMensaje: 'm-9', motivo: 'otra vez' });
  assert.strictEqual((await p.ana.siguiente('error')).codigo, 'mensajeNoValido');
});

test('el host no puede saltarse el orden de seq ni proponer', async (t) => {
  const p = await partida(t);
  p.ana.mandar({ tipo: 'aceptar', seq: 2, evento: EVENTO });
  assert.strictEqual((await p.ana.siguiente('error')).codigo, 'mensajeNoValido');
  p.ana.mandar({ tipo: 'proponer', idMensaje: 'm-1', evento: EVENTO });
  assert.strictEqual((await p.ana.siguiente('error')).codigo, 'mensajeNoValido');
});

test('un evento mal formado se rechaza con el esquema del contrato', async (t) => {
  const p = await partida(t);
  p.bea.mandar({ tipo: 'proponer', idMensaje: 'm-1', evento: { tipo: 'noExiste' } });
  const e = await p.bea.siguiente('error');
  assert.deepStrictEqual([e.codigo, e.idMensaje], ['mensajeNoValido', 'm-1']);
});

test('quien reconecta con su sesión recupera el asiento y el registro desde ultimoSeq', async (t) => {
  const p = await partida(t, ['ana', 'bea']);
  p.ana.mandar({ tipo: 'aceptar', seq: 1, evento: EVENTO });
  p.ana.mandar({ tipo: 'aceptar', seq: 2, evento: EVENTO_B });
  await p.bea.siguiente('evento', (m) => m.seq === 2);
  p.bea.s.terminate();
  const caida = await p.ana.siguiente('sala', (m) => m.jugadores[1]?.conectado === false);
  assert.strictEqual(caida.estado, 'enCurso');
  p.ana.mandar({ tipo: 'aceptar', seq: 3, evento: EVENTO });

  const bea2 = await p.conectar();
  const s = await entrar(bea2, 'bea', p.codigo, { ultimoSeq: 1 });
  assert.deepStrictEqual([s.tuAsiento, s.ultimoSeq, s.estado], [1, 3, 'enCurso']);
  const r = await bea2.siguiente('registro');
  assert.deepStrictEqual([r.desdeSeq, r.eventos], [2, [EVENTO_B, EVENTO]]);

  const aldia = await p.conectar();
  await entrar(aldia, 'bea', p.codigo, { ultimoSeq: 3 }); // sustituye a la conexión anterior
  const r2 = await aldia.siguiente('registro');
  assert.deepStrictEqual([r2.desdeSeq, r2.eventos], [4, []]);
  assert.ok(await bea2.cierre);
});

test('empezada la partida no entra nadie nuevo', async (t) => {
  const p = await partida(t);
  const nuevo = await p.conectar();
  nuevo.mandar({ tipo: 'hola', protocolo: 1, token: 'tok-cai', codigo: p.codigo });
  assert.strictEqual((await nuevo.siguiente('error')).codigo, 'salaCerrada');
});

test('en el lobby: echar y salir liberan el asiento y los asientos quedan seguidos', async (t) => {
  const ctx = await arrancar();
  t.after(ctx.cerrar);
  const { json: { codigo } } = await ctx.crearSala('ana');
  const ana = await ctx.conectar(); await entrar(ana, 'ana', codigo);
  const bea = await ctx.conectar(); await entrar(bea, 'bea', codigo);
  const cai = await ctx.conectar(); await entrar(cai, 'cai', codigo);

  ana.mandar({ tipo: 'echar', asiento: 1 });
  assert.strictEqual((await bea.siguiente('error')).codigo, 'noEresDeLaSala');
  const s = await cai.siguiente('sala', (m) => m.jugadores.length === 2);
  assert.deepStrictEqual([s.tuAsiento, s.jugadores.map((j) => j.nombre)], [1, ['Nombre ana', 'Nombre cai']]);
  assert.ok(ctx.salas.crear('bea', 'Bea').ok, 'la cuenta echada queda libre');

  cai.mandar({ tipo: 'salir' });
  const s2 = await ana.siguiente('sala', (m) => m.jugadores.length === 1);
  assert.strictEqual(s2.estado, 'abierta');

  ana.mandar({ tipo: 'echar', asiento: 0 });
  assert.strictEqual((await ana.siguiente('error')).codigo, 'mensajeNoValido');
});

test('si el host sale o se cae se cancela la partida y se libera la sala', async (t) => {
  const p = await partida(t, ['ana', 'bea']);
  p.ana.s.terminate();
  const c = await p.bea.siguiente('partidaCancelada');
  assert.strictEqual(c.motivo, 'hostDesconectado');
  assert.strictEqual(p.salas.vivas(), 0);

  const ctx = await arrancar();
  t.after(ctx.cerrar);
  const { json: { codigo } } = await ctx.crearSala('ana');
  const ana = await ctx.conectar(); await entrar(ana, 'ana', codigo);
  const bea = await ctx.conectar(); await entrar(bea, 'bea', codigo);
  ana.mandar({ tipo: 'salir' });
  assert.strictEqual((await bea.siguiente('partidaCancelada')).motivo, 'hostCancelo');
  assert.strictEqual(ctx.salas.vivas(), 0);
});

// --- latidos y ventana de desconexión (D-19 §D5, §D9) ---------------
const RAPIDO = { intervaloPingMs: 40, caidaMs: 160, ventanaMs: 400 };

test('el servidor manda ping y quien contesta no se cae', async (t) => {
  const ctx = await arrancar(RAPIDO);
  t.after(ctx.cerrar);
  const { json: { codigo } } = await ctx.crearSala('ana');
  const ana = await ctx.conectar({ autoPong: true }); await entrar(ana, 'ana', codigo);
  const bea = await ctx.conectar({ autoPong: true }); await entrar(bea, 'bea', codigo);
  ana.mandar({ tipo: 'empezar', partidaId: 'p-1', creadaEn: '2026-11-18T22:00:00.000Z' });
  await bea.siguiente('sala', (m) => m.estado === 'enCurso');
  await bea.siguiente('ping');
  await new Promise((ok) => setTimeout(ok, 400));
  assert.ok(ana.recibidos.filter((m) => m.tipo === 'ping').length >= 3);
  assert.ok(ana.s.readyState === 1 && bea.s.readyState === 1, 'los que contestan siguen conectados');
  assert.ok(!bea.recibidos.some((m) => m.tipo === 'jugadorDesconectado'));
});

test('quien deja de dar señales se da por caído y todos reciben la cuenta atrás', async (t) => {
  const p = await partida(t, ['ana', 'bea'], RAPIDO);
  // ana contesta; bea no (el cliente de pruebas no contesta a los ping)
  p.ana.s.on('message', (d) => { if (JSON.parse(d).tipo === 'ping') p.ana.s.send('{"tipo":"pong"}'); });
  const d = await p.ana.siguiente('jugadorDesconectado');
  assert.strictEqual(d.asiento, 1);
  const falta = Date.parse(d.venceEn) - Date.now();
  assert.ok(falta > 0 && falta <= RAPIDO.ventanaMs, `venceEn en ${falta} ms`);
  assert.strictEqual(await p.bea.cierre, 1006);
});

test('si vuelve antes de vencer: jugadorVuelve, su asiento y el registro; no vence nada', async (t) => {
  const p = await partida(t, ['ana', 'bea', 'cai'], { ...RAPIDO, ventanaMs: 600 }, { autoPong: true });
  p.ana.mandar({ tipo: 'aceptar', seq: 1, evento: EVENTO });
  await p.bea.siguiente('evento');
  p.bea.s.terminate();
  const d = await p.cai.siguiente('jugadorDesconectado');
  assert.strictEqual(d.asiento, 1);
  await p.ana.siguiente('jugadorDesconectado');
  p.ana.mandar({ tipo: 'aceptar', seq: 2, evento: EVENTO_B }); // la partida sigue mientras tanto

  const bea2 = await p.conectar({ autoPong: true });
  const s = await entrar(bea2, 'bea', p.codigo, { ultimoSeq: 1 });
  assert.deepStrictEqual([s.tuAsiento, s.jugadores[1].conectado], [1, true]);
  assert.deepStrictEqual((await bea2.siguiente('registro')).eventos, [EVENTO_B]);
  for (const o of [p.ana, p.cai]) assert.strictEqual((await o.siguiente('jugadorVuelve')).asiento, 1);
  assert.ok(!bea2.recibidos.some((m) => m.tipo === 'jugadorVuelve'));

  await new Promise((ok) => setTimeout(ok, 800)); // pasa la ventana: ya no debe vencer
  assert.ok(!p.ana.recibidos.some((m) => m.tipo === 'ventanaVencida'));
});

test('al vencer la ventana se avisa al host y ya no puede volver', async (t) => {
  const p = await partida(t, ['ana', 'bea', 'cai'], { ...RAPIDO, caidaMs: 10_000 }, { autoPong: true });
  p.bea.s.terminate();
  await p.ana.siguiente('jugadorDesconectado');
  const v = await p.ana.siguiente('ventanaVencida');
  assert.strictEqual(v.asiento, 1);
  assert.ok(!p.cai.recibidos.some((m) => m.tipo === 'ventanaVencida'), 'solo se avisa al host');
  const sala = p.salas.obtener(p.codigo);
  assert.strictEqual(sala.jugadores[1].vencido, true);
  assert.strictEqual(sala.jugadores[2].vencido, undefined);

  const tarde = await p.conectar();
  tarde.mandar({ tipo: 'hola', protocolo: 1, token: 'tok-bea', codigo: p.codigo });
  assert.strictEqual((await tarde.siguiente('error')).codigo, 'salaCerrada');
});

test('si se cae el host durante una ventana abierta se cancela y no vence nada después', async (t) => {
  const p = await partida(t, ['ana', 'bea', 'cai'], { ...RAPIDO, caidaMs: 10_000 }, { autoPong: true });
  p.bea.s.terminate();
  await p.cai.siguiente('jugadorDesconectado');
  p.ana.s.terminate();
  assert.strictEqual((await p.cai.siguiente('partidaCancelada')).motivo, 'hostDesconectado');
  await new Promise((ok) => setTimeout(ok, 600));
  assert.ok(!p.cai.recibidos.some((m) => m.tipo === 'ventanaVencida'));
  assert.strictEqual(p.salas.vivas(), 0);
});

test('en el lobby caerse es salir: no hay ventana', async (t) => {
  const ctx = await arrancar(RAPIDO);
  t.after(ctx.cerrar);
  const { json: { codigo } } = await ctx.crearSala('ana');
  const ana = await ctx.conectar({ autoPong: true }); await entrar(ana, 'ana', codigo);
  const bea = await ctx.conectar(); await entrar(bea, 'bea', codigo);
  bea.s.terminate();
  const s = await ana.siguiente('sala', (m) => m.jugadores.length === 1);
  assert.strictEqual(s.estado, 'abierta');
  assert.ok(!ana.recibidos.some((m) => m.tipo === 'jugadorDesconectado'));
});
