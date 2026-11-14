'use strict';
const test = require('node:test');
const assert = require('node:assert');
const express = require('express');
const { crearRouter, crearRepoMemoria } = require('../src');
const { ejemplo, conId } = require('./ayudas');

// App de prueba: la autenticación lee la cabecera x-usuario.
async function arrancar(opciones = {}) {
  let reloj = Date.parse('2026-11-06T10:00:00.000Z');
  const router = crearRouter({
    repo: crearRepoMemoria(),
    autenticar: (req, res, next) => {
      req.usuarioId = req.get('x-usuario') || undefined;
      next();
    },
    ahora: () => new Date((reloj += 1000)),
    ...opciones,
  });
  const app = express();
  app.use('/api/incursiones', router);
  const servidor = await new Promise((ok) => { const s = app.listen(0, () => ok(s)); });
  const base = `http://127.0.0.1:${servidor.address().port}/api/incursiones`;
  const llamar = async (metodo, ruta, { usuario, cuerpo, crudo } = {}) => {
    const r = await fetch(base + ruta, {
      method: metodo,
      headers: { 'content-type': 'application/json', ...(usuario ? { 'x-usuario': usuario } : {}) },
      body: crudo ?? (cuerpo === undefined ? undefined : JSON.stringify(cuerpo)),
    });
    return { estado: r.status, json: await r.json() };
  };
  return { llamar, cerrar: () => servidor.close() };
}

const ANA = 'usuario-ana';
const BEA = 'usuario-bea';

test('sin sesión se rechaza todo', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  for (const [m, r] of [['GET', '/partidas'], ['GET', '/me/puntos'], ['POST', '/partidas']]) {
    const res = await llamar(m, r);
    assert.strictEqual(res.estado, 401, `${m} ${r}`);
    assert.strictEqual(res.json.error, 'no_autenticado');
  }
});

test('guardar una partida abona los puntos y un reintento no los duplica', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const partida = ejemplo('validos', 'victoria-2-jugadores');

  const primera = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: partida });
  assert.strictEqual(primera.estado, 201);
  assert.strictEqual(primera.json.duplicada, false);
  assert.strictEqual(primera.json.tusPuntos, 1650);

  const reintento = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: partida });
  assert.strictEqual(reintento.estado, 200);
  assert.strictEqual(reintento.json.duplicada, true);
  assert.strictEqual(reintento.json.guardadaEn, primera.json.guardadaEn);

  const puntos = await llamar('GET', '/me/puntos', { usuario: ANA });
  assert.strictEqual(puntos.json.puntos, 1650);
  assert.strictEqual(puntos.json.partidas, 1);
});

test('el mismo partidaId con otro contenido es un conflicto', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const partida = ejemplo('validos', 'victoria-2-jugadores');
  await llamar('POST', '/partidas', { usuario: ANA, cuerpo: partida });
  const otra = structuredClone(partida);
  otra.creadaEn = '2030-01-01T00:00:00Z';
  const res = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: otra });
  assert.strictEqual(res.estado, 409);
  assert.strictEqual(res.json.error, 'partida_distinta');
});

test('rechaza lo que el esquema no admite', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  for (const nombre of ['evento-desconocido', 'dano-no-es-entero', 'falta-partida-id', 'campo-desconocido']) {
    const res = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: ejemplo('invalidos-estructura', nombre) });
    assert.strictEqual(res.estado, 400, nombre);
    assert.strictEqual(res.json.error, 'estructura_invalida', nombre);
    assert.ok(res.json.errores.length > 0, nombre);
  }
  const futura = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: ejemplo('invalidos-estructura', 'version-futura') });
  assert.strictEqual(futura.estado, 400);
  assert.strictEqual(futura.json.error, 'version_no_soportada');
  const malo = await llamar('POST', '/partidas', { usuario: ANA, crudo: '{no es json' });
  assert.strictEqual(malo.estado, 400);
  assert.strictEqual(malo.json.error, 'json_invalido');
});

test('una partida en curso no se guarda', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const partida = ejemplo('validos', 'en-curso-sin-resumen');
  const res = await llamar('POST', '/partidas', { usuario: partida.cuentas?.[0] ?? ANA, cuerpo: partida });
  assert.ok([403, 422].includes(res.estado), JSON.stringify(res.json));
  if (res.estado === 422) assert.match(res.json.motivos[0], /falta el resumen/);
});

test('solo guarda quien figura en las cuentas de la partida', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const res = await llamar('POST', '/partidas', { usuario: 'usuario-intruso', cuerpo: ejemplo('validos', 'victoria-2-jugadores') });
  assert.strictEqual(res.estado, 403);
  assert.strictEqual(res.json.error, 'no_participas');
});

test('rechaza un resumen incoherente con sus motivos', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const partida = ejemplo('validos', 'victoria-2-jugadores');
  partida.resumen.jugadores[0].puntos = 2500; // se lleva más de lo que le toca
  const res = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: partida });
  assert.strictEqual(res.estado, 422);
  assert.strictEqual(res.json.error, 'resumen_incoherente');
  assert.match(res.json.motivos.join(), /puntos deberían ser 1650/);
  const guardadas = await llamar('GET', '/partidas', { usuario: ANA });
  assert.deepStrictEqual(guardadas.json.partidas, []);
});

test('rechaza cuentas que no existen', async (t) => {
  const { llamar, cerrar } = await arrancar({ existenCuentas: async (ids) => ids.filter((i) => i !== ANA) });
  t.after(cerrar);
  const partida = ejemplo('validos', 'derrota-con-aliado-y-abandono'); // Ana y Bea
  const res = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: partida });
  assert.strictEqual(res.estado, 422);
  assert.strictEqual(res.json.error, 'cuenta_desconocida');
  assert.deepStrictEqual(res.json.cuentas, [BEA]);
});

test('cada cuenta cobra solo su parte', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  await llamar('POST', '/partidas', { usuario: BEA, cuerpo: ejemplo('validos', 'derrota-con-aliado-y-abandono') });
  const ana = await llamar('GET', '/me/puntos', { usuario: ANA });
  const bea = await llamar('GET', '/me/puntos', { usuario: BEA });
  assert.strictEqual(ana.json.puntos, 182);
  assert.strictEqual(bea.json.puntos, 121); // Cris era invitada: sus 148 no se abonan
  assert.deepStrictEqual(ana.json.niveles[0], { nivel: 1, coste: 10000, alcanzado: false, faltan: 9818 });
});

test('historial paginado, de la más reciente a la más antigua', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const base = ejemplo('validos', 'victoria-2-jugadores');
  for (const id of ['p1', 'p2', 'p3']) {
    const res = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: conId(base, id) });
    assert.strictEqual(res.estado, 201);
  }
  const pag1 = await llamar('GET', '/partidas?limite=2', { usuario: ANA });
  assert.deepStrictEqual(pag1.json.partidas.map((p) => p.partidaId), ['p3', 'p2']);
  assert.ok(pag1.json.siguiente);
  const pag2 = await llamar('GET', `/partidas?limite=2&despues=${pag1.json.siguiente}`, { usuario: ANA });
  assert.deepStrictEqual(pag2.json.partidas.map((p) => p.partidaId), ['p1']);
  assert.strictEqual(pag2.json.siguiente, null);
  assert.deepStrictEqual(
    { nivel: pag2.json.partidas[0].nivel, miPuesto: pag2.json.partidas[0].miPuesto, misPuntos: pag2.json.partidas[0].misPuntos },
    { nivel: 1, miPuesto: 1, misPuntos: 1650 },
  );
  for (const q of ['limite=0', 'limite=51', 'limite=x', 'despues=basura']) {
    const res = await llamar('GET', `/partidas?${q}`, { usuario: ANA });
    assert.strictEqual(res.estado, 400, q);
  }
});

test('el detalle de una partida es solo para quien jugó en ella', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const partida = ejemplo('validos', 'victoria-2-jugadores');
  await llamar('POST', '/partidas', { usuario: ANA, cuerpo: partida });
  const propia = await llamar('GET', `/partidas/${partida.partidaId}`, { usuario: ANA });
  assert.strictEqual(propia.estado, 200);
  assert.deepStrictEqual(propia.json.registro, partida);
  const ajena = await llamar('GET', `/partidas/${partida.partidaId}`, { usuario: BEA });
  assert.strictEqual(ajena.estado, 404);
  const noExiste = await llamar('GET', '/partidas/nada', { usuario: ANA });
  assert.strictEqual(noExiste.estado, 404);
});

test('una partida v2 abona el reparto y el bono de estados', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const victoria = ejemplo('validos', 'victoria-por-estados', 2);
  const res = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: victoria });
  assert.strictEqual(res.estado, 201);
  assert.strictEqual(res.json.tusPuntos, 1650 + 30);
  const derrota = ejemplo('validos', 'derrota-con-veneno-y-abandono', 2);
  assert.strictEqual((await llamar('POST', '/partidas', { usuario: ANA, cuerpo: derrota })).json.tusPuntos, 114 + 8);

  const puntos = await llamar('GET', '/me/puntos', { usuario: ANA });
  assert.strictEqual(puntos.json.puntos, 1680 + 122);
  const lista = await llamar('GET', '/partidas', { usuario: ANA });
  const resumen = lista.json.partidas.find((p) => p.partidaId === victoria.partidaId);
  assert.strictEqual(resumen.misPuntos, 1650);
  assert.strictEqual(resumen.bonoEstados, 30);
});

test('un reintento de una partida v2 no suma el bono dos veces', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const partida = ejemplo('validos', 'victoria-por-estados', 2);
  await llamar('POST', '/partidas', { usuario: ANA, cuerpo: partida });
  const otra = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: partida });
  assert.strictEqual(otra.estado, 200);
  assert.strictEqual((await llamar('GET', '/me/puntos', { usuario: ANA })).json.puntos, 1680);
});

test('las partidas v1 y v2 conviven', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const v1 = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: ejemplo('validos', 'victoria-2-jugadores') });
  const v2 = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: ejemplo('validos', 'victoria-por-estados', 2) });
  assert.deepStrictEqual([v1.estado, v2.estado], [201, 201]);
  assert.strictEqual(v1.json.tusPuntos, 1650); // la v1 no tiene bono
  const detalle = await llamar('GET', '/partidas/ejemplo-victoria-2-jugadores', { usuario: ANA });
  assert.strictEqual(detalle.json.registro.version, 1); // se guarda tal cual llegó
});

test('rechaza un bono o unas aplicaciones manipulados', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const inflado = ejemplo('validos', 'victoria-por-estados', 2);
  inflado.resumen.jugadores[0].bonoEstados = 450;
  const a = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: inflado });
  assert.strictEqual(a.estado, 422);
  assert.match(a.json.motivos.join(), /bonoEstados debería ser 30/);

  const sinEstados = ejemplo('validos', 'victoria-por-estados', 2);
  sinEstados.eventos = sinEstados.eventos.filter((e) => e.tipo !== 'aplicarEstadoJefe');
  sinEstados.eventos.forEach((e) => { if (e.tipo === 'finTurnoJefe') delete e.monedaQuemadura; });
  const b = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: sinEstados });
  assert.strictEqual(b.estado, 422);
  assert.match(b.json.motivos.join(), /estadosAplicados debería ser 0/);
  assert.strictEqual((await llamar('GET', '/me/puntos', { usuario: ANA })).json.puntos, 0);
});

test('los ejemplos v2 inválidos de estructura se rechazan', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  for (const nombre of ['estado-desconocido', 'moneda-no-es-booleano']) {
    const res = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: ejemplo('invalidos-estructura', nombre, 2) });
    assert.strictEqual(res.estado, 400, nombre);
    assert.strictEqual(res.json.error, 'estructura_invalida', nombre);
  }
});

test('un resumen v1 con campos de la v2 no es válido', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const mezcla = ejemplo('validos', 'victoria-2-jugadores');
  mezcla.resumen.jugadores[0].bonoEstados = 30;
  const res = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: mezcla });
  assert.strictEqual(res.estado, 400);
});

// Una partida v1 con aliado, pasada a v3 (categoría en cada aliado y los dos
// campos de estados del resumen, que en la v1 no existían).
function v3ConAliado() {
  const partida = JSON.parse(JSON.stringify(ejemplo('validos', 'derrota-con-aliado-y-abandono')));
  partida.version = 3;
  partida.partidaId = 'ejemplo-v3-con-aliado';
  for (const e of partida.eventos) {
    if (e.tipo === 'aliadoInvocado') e.categoria = 'danio';
  }
  for (const j of partida.resumen.jugadores) {
    j.estadosAplicados = 0;
    j.bonoEstados = 0;
  }
  return partida;
}

test('una partida v3 con aliados por categoría se guarda tal cual llegó', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const partida = v3ConAliado();
  const res = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: partida });
  assert.strictEqual(res.estado, 201, JSON.stringify(res.json));
  const detalle = await llamar('GET', `/partidas/${partida.partidaId}`, { usuario: ANA });
  assert.strictEqual(detalle.json.registro.version, 3);
  assert.strictEqual(detalle.json.registro.eventos.find((e) => e.tipo === 'aliadoInvocado').categoria, 'danio');
});

test('las partidas v1, v2, v3, v4, v5, v6, v7 y v8 conviven', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const v1 = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: ejemplo('validos', 'victoria-2-jugadores') });
  const v2 = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: ejemplo('validos', 'victoria-por-estados', 2) });
  const v3 = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: ejemplo('validos', 'derrota-con-veneno-y-abandono', 3) });
  const v4 = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: { ...ejemplo('validos', 'victoria-por-estados', 4), partidaId: 'ejemplo-v4-conviven' } });
  const v5 = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: { ...ejemplo('validos', 'victoria-por-estados', 5), partidaId: 'ejemplo-v5-conviven' } });
  const v6 = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: { ...ejemplo('validos', 'victoria-por-estados', 6), partidaId: 'ejemplo-v6-conviven' } });
  const v7 = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: { ...ejemplo('validos', 'victoria-por-estados', 7), partidaId: 'ejemplo-v7-conviven' } });
  const v8 = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: { ...ejemplo('validos', 'victoria-por-estados', 8), partidaId: 'ejemplo-v8-conviven' } });
  assert.deepStrictEqual([v1.estado, v2.estado, v3.estado, v4.estado, v5.estado, v6.estado, v7.estado, v8.estado], [201, 201, 201, 201, 201, 201, 201, 201]);
});

test('un aliado v3 sin categoría o con una desconocida se rechaza', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const sin = v3ConAliado();
  delete sin.eventos.find((e) => e.tipo === 'aliadoInvocado').categoria;
  const a = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: sin });
  assert.strictEqual(a.estado, 400);
  assert.strictEqual(a.json.error, 'estructura_invalida');

  const rara = v3ConAliado();
  rara.eventos.find((e) => e.tipo === 'aliadoInvocado').categoria = 'mago';
  const b = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: rara });
  assert.strictEqual(b.estado, 400);
});

test('el mensaje de versión no soportada lista las ocho versiones', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const res = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: { ...v3ConAliado(), version: 9 } });
  assert.strictEqual(res.estado, 400);
  assert.strictEqual(res.json.error, 'version_no_soportada');
  assert.match(res.json.mensaje ?? JSON.stringify(res.json), /1, 2, 3, 4, 5, 6, 7 y 8/);
});

// Igual que la v3, pero con la categoría ya renombrada a `tanque` (v4).
function v4ConAliado(categoria) {
  const partida = v3ConAliado();
  partida.version = 4;
  partida.partidaId = 'ejemplo-v4-con-aliado';
  partida.eventos.find((e) => e.tipo === 'aliadoInvocado').categoria = categoria;
  return partida;
}

test('una partida v4 con un aliado tanque se guarda; con `barrera` se rechaza', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const ok = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: v4ConAliado('tanque') });
  assert.strictEqual(ok.estado, 201, JSON.stringify(ok.json));
  const detalle = await llamar('GET', '/partidas/ejemplo-v4-con-aliado', { usuario: ANA });
  assert.strictEqual(detalle.json.registro.version, 4);
  const mala = v4ConAliado('barrera');
  mala.partidaId = 'ejemplo-v4-con-barrera';
  const res = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: mala });
  assert.strictEqual(res.estado, 400);
});

// Una partida v5 terminada con un ataque del jefe que lleva efecto (D-14).
function v5ConEfecto(efecto) {
  const partida = { ...ejemplo('validos', 'victoria-por-estados', 5), partidaId: 'ejemplo-v5-con-efecto' };
  partida.eventos = structuredClone(partida.eventos);
  const i = partida.eventos.findIndex((e) => e.tipo === 'finTurnoJefe');
  partida.eventos.splice(i, 0, { tipo: 'ataqueJefe', ranura: 1, dano: 30, jugador: 0, efecto });
  return partida;
}

test('una partida v5 con un efecto de ataque se guarda; con un efecto desconocido se rechaza', async (t) => {
  const { llamar, cerrar } = await arrancar();
  t.after(cerrar);
  const ok = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: v5ConEfecto({ tipo: 'sinRetirada', duracion: 1 }) });
  assert.strictEqual(ok.estado, 201, JSON.stringify(ok.json));
  const detalle = await llamar('GET', '/partidas/ejemplo-v5-con-efecto', { usuario: ANA });
  assert.strictEqual(detalle.json.registro.version, 5);
  const mala = v5ConEfecto({ tipo: 'bailar' });
  mala.partidaId = 'ejemplo-v5-con-efecto-malo';
  const res = await llamar('POST', '/partidas', { usuario: ANA, cuerpo: mala });
  assert.strictEqual(res.estado, 400);
  assert.strictEqual(res.json.error, 'estructura_invalida');
});
