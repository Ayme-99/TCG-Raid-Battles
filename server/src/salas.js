'use strict';
const crypto = require('node:crypto');

// Sin 0, 1, I, L ni O (D-19 §D7). Coincide con el patrón de contrato/sala.
const ALFABETO = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const LONGITUD_CODIGO = 5;
const MAX_JUGADORES = 4;

function codigoAleatorio() {
  let c = '';
  for (let i = 0; i < LONGITUD_CODIGO; i++) c += ALFABETO[crypto.randomInt(ALFABETO.length)];
  return c;
}

/**
 * Salas en memoria (D-19 §D6). Solo guarda el estado y el registro de eventos;
 * no sabe nada de WebSocket (eso está en ws.js), así que se prueba sin red.
 *
 * Una sala: { codigo, estado, jugadores: [{ asiento, cuentaId, nombre, conectado }],
 *             eventos: [], propuestas: Map(idMensaje → { asiento, estado, seq? }),
 *             partidaId?, creadaEn? }
 * `estado`: abierta → completa → enCurso (la cancelada/terminada se borra).
 */
function crearSalas({ generarCodigo = codigoAleatorio } = {}) {
  const salas = new Map(); // codigo → sala
  const salaDeCuenta = new Map(); // cuentaId → codigo

  const resultado = (ok, datos = {}) => ({ ok, ...datos });

  function crear(cuentaId, nombre) {
    const existente = salaDeCuenta.get(cuentaId);
    if (existente) return resultado(false, { error: 'yaEnSala', codigo: existente });
    let codigo;
    do codigo = generarCodigo(); while (salas.has(codigo));
    const sala = {
      codigo,
      estado: 'abierta',
      jugadores: [{ asiento: 0, cuentaId, nombre, conectado: false }],
      eventos: [],
      propuestas: new Map(),
    };
    salas.set(codigo, sala);
    salaDeCuenta.set(cuentaId, codigo);
    return resultado(true, { sala });
  }

  const obtener = (codigo) => salas.get(codigo) ?? null;
  const jugadorDe = (sala, cuentaId) => sala.jugadores.find((j) => j.cuentaId === cuentaId) ?? null;
  const asientoHost = () => 0;

  // Entra una cuenta (primer `hola`). Quien ya estaba recupera su asiento
  // aunque la sala esté cerrada (reconexión, D9); los demás solo si está abierta.
  function entrar(codigo, cuentaId, nombre) {
    const sala = salas.get(codigo);
    if (!sala) return resultado(false, { error: 'salaNoExiste' });
    const propio = jugadorDe(sala, cuentaId);
    if (propio) return resultado(true, { sala, jugador: propio, nuevo: false });
    if (salaDeCuenta.has(cuentaId)) return resultado(false, { error: 'yaEnSala', codigo: salaDeCuenta.get(cuentaId) });
    if (sala.estado === 'enCurso') return resultado(false, { error: 'salaCerrada' });
    if (sala.jugadores.length >= MAX_JUGADORES) return resultado(false, { error: 'salaLlena' });
    const jugador = { asiento: sala.jugadores.length, cuentaId, nombre, conectado: false };
    sala.jugadores.push(jugador);
    salaDeCuenta.set(cuentaId, codigo);
    if (sala.jugadores.length === MAX_JUGADORES) sala.estado = 'completa';
    return resultado(true, { sala, jugador, nuevo: true });
  }

  // Quita a un jugador en el lobby y reasigna los asientos para que sigan
  // siendo 0..n-1 (el motor los necesita seguidos).
  function quitar(sala, cuentaId) {
    sala.jugadores = sala.jugadores.filter((j) => j.cuentaId !== cuentaId);
    sala.jugadores.forEach((j, i) => { j.asiento = i; });
    salaDeCuenta.delete(cuentaId);
    if (sala.estado === 'completa') sala.estado = 'abierta';
  }

  function empezar(sala, partidaId, creadaEn) {
    if (sala.estado !== 'abierta' && sala.estado !== 'completa') return resultado(false, { error: 'salaCerrada' });
    sala.estado = 'enCurso';
    sala.partidaId = partidaId;
    sala.creadaEn = creadaEn;
    return resultado(true);
  }

  // Añade el evento aceptado por el host. `seq` debe ser el siguiente.
  function registrar(sala, seq, evento, idMensaje) {
    if (sala.estado !== 'enCurso') return resultado(false, { error: 'salaCerrada' });
    if (seq !== sala.eventos.length + 1) {
      return resultado(false, { error: 'seqFueraDeOrden', esperado: sala.eventos.length + 1 });
    }
    sala.eventos.push(evento);
    if (idMensaje !== undefined) {
      const p = sala.propuestas.get(idMensaje);
      if (p) { p.estado = 'aceptada'; p.seq = seq; }
    }
    return resultado(true);
  }

  // Borra la sala y libera a sus cuentas (cancelada o terminada).
  function cerrar(sala) {
    for (const j of sala.jugadores) salaDeCuenta.delete(j.cuentaId);
    salas.delete(sala.codigo);
  }

  const vivas = () => salas.size;

  return { crear, obtener, entrar, quitar, empezar, registrar, cerrar, jugadorDe, asientoHost, vivas };
}

module.exports = { crearSalas, ALFABETO, MAX_JUGADORES };
