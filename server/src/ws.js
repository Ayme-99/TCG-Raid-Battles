'use strict';
const { WebSocketServer } = require('ws');
const { crearValidadorSala, VERSION_PROTOCOLO } = require('./protocoloSala');

const RUTA_POR_DEFECTO = '/api/incursiones/ws';
const ESPERA_HOLA_MS = 10_000;
const INTERVALO_PING_MS = 10_000; // D-19 §D5
const CAIDA_MS = 25_000; // sin ningún mensaje en este tiempo, la conexión se da por caída
const VENTANA_MS = 120_000; // D-19 §D9: 2 minutos para volver
const MAX_BYTES = 256 * 1024;

const TEXTO_ERROR = {
  protocoloNoSoportado: `este servidor habla la versión ${VERSION_PROTOCOLO} del protocolo de sala; actualiza la app`,
  sesionNoValida: 'la sesión no es válida; inicia sesión de nuevo',
  salaNoExiste: 'no existe ninguna sala con ese código',
  salaLlena: 'la sala ya tiene 4 jugadores',
  salaCerrada: 'la partida ya ha empezado o la sala está cerrada',
  noEresDeLaSala: 'no formas parte de esta sala',
  noEsHost: 'solo el host puede hacer eso',
  mensajeNoValido: 'mensaje no válido',
};

/**
 * Monta el WebSocket de las salas sobre un servidor HTTP (D-19 §D5).
 *
 * @param {object} o
 * @param {import('node:http').Server} o.servidor  servidor HTTP del backend
 * @param {object} o.salas        resultado de crearSalas()
 * @param {Function} o.verificarToken async (token) → { cuentaId, nombre } | null
 * @param {string} [o.ruta]       ruta del upgrade
 * @param {number} [o.esperaHolaMs] tiempo máximo para recibir el `hola`
 * @param {number} [o.intervaloPingMs] cada cuánto manda `ping` (10 s)
 * @param {number} [o.caidaMs]    silencio tras el que se da por caída la conexión (25 s)
 * @param {number} [o.ventanaMs]  tiempo para volver tras caerse en partida (2 min)
 * @param {Function} [o.ahora]    () → Date, para `venceEn`
 * @param {Function} [o.validar]  validador de mensajes (para los tests)
 * @returns {{ cerrar: () => Promise<void> }}
 */
function montarSalas({
  servidor,
  salas,
  verificarToken,
  ruta = RUTA_POR_DEFECTO,
  esperaHolaMs = ESPERA_HOLA_MS,
  intervaloPingMs = INTERVALO_PING_MS,
  caidaMs = CAIDA_MS,
  ventanaMs = VENTANA_MS,
  ahora = () => new Date(),
  validar = crearValidadorSala(),
}) {
  if (!servidor || !salas || typeof verificarToken !== 'function') {
    throw new Error('montarSalas necesita servidor, salas y verificarToken');
  }
  const wss = new WebSocketServer({ server: servidor, path: ruta, maxPayload: MAX_BYTES });
  const conexiones = new Map(); // codigo → Map(cuentaId → ws)

  const enviar = (ws, mensaje) => {
    if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(mensaje));
  };
  const error = (ws, codigo, extra = {}) =>
    enviar(ws, { tipo: 'error', codigo, texto: TEXTO_ERROR[codigo], ...extra });
  const socketsDe = (sala) => conexiones.get(sala.codigo) ?? new Map();
  const socketDe = (sala, jugador) => socketsDe(sala).get(jugador.cuentaId);
  const difundir = (sala, mensaje) => {
    for (const ws of socketsDe(sala).values()) enviar(ws, mensaje);
  };

  const mensajeSala = (sala, jugador) => {
    const m = {
      tipo: 'sala',
      estado: sala.estado,
      host: salas.asientoHost(),
      tuAsiento: jugador.asiento,
      jugadores: sala.jugadores.map((j) => ({ asiento: j.asiento, nombre: j.nombre, conectado: j.conectado })),
      ultimoSeq: sala.eventos.length,
    };
    if (sala.partidaId !== undefined) { m.partidaId = sala.partidaId; m.creadaEn = sala.creadaEn; }
    return m;
  };
  const difundirSala = (sala) => {
    for (const j of sala.jugadores) {
      const ws = socketDe(sala, j);
      if (ws) enviar(ws, mensajeSala(sala, j));
    }
  };

  // Ventana de desconexión de un jugador (no host): lleva su temporizador.
  function pararVentana(jugador) {
    clearTimeout(jugador.temporizadorVentana);
    jugador.temporizadorVentana = null;
  }

  function abrirVentana(sala, jugador) {
    const venceEn = new Date(ahora().getTime() + ventanaMs).toISOString();
    pararVentana(jugador);
    jugador.temporizadorVentana = setTimeout(() => {
      jugador.temporizadorVentana = null;
      if (jugador.conectado || salas.obtener(sala.codigo) !== sala) return;
      jugador.vencido = true; // el host registra sus PokemonKo; no vuelve ni cobra (§D8)
      salas.marcarVencido(sala, jugador.asiento);
      const host = socketDe(sala, sala.jugadores[salas.asientoHost()]);
      if (host) enviar(host, { tipo: 'ventanaVencida', asiento: jugador.asiento });
      difundirSala(sala);
    }, ventanaMs);
    difundir(sala, { tipo: 'jugadorDesconectado', asiento: jugador.asiento, venceEn });
    difundirSala(sala);
  }

  function cancelar(sala, motivo, texto) {
    for (const j of sala.jugadores) pararVentana(j);
    difundir(sala, { tipo: 'partidaCancelada', motivo, ...(texto ? { texto } : {}) });
    const todos = [...socketsDe(sala).values()];
    conexiones.delete(sala.codigo);
    salas.cerrar(sala);
    for (const ws of todos) { ws.sala = null; ws.close(1000, motivo); }
  }

  // --- hola -----------------------------------------------------------
  async function alHola(ws, m) {
    let sesion = null;
    try { sesion = await verificarToken(m.token); } catch { sesion = null; }
    if (!sesion || typeof sesion.cuentaId !== 'string' || sesion.cuentaId === '') {
      error(ws, 'sesionNoValida'); ws.close(1008, 'sesionNoValida'); return;
    }
    if (ws.readyState !== ws.OPEN) return;
    const r = salas.entrar(m.codigo, sesion.cuentaId, sesion.nombre || sesion.cuentaId);
    if (r.ok && r.jugador.vencido) { // la ventana ya venció: el host le dio por KO
      error(ws, 'salaCerrada'); ws.close(1008, 'ventanaVencida'); return;
    }
    if (!r.ok) { error(ws, r.error === 'yaEnSala' ? 'salaCerrada' : r.error); ws.close(1008, r.error); return; }

    const { sala, jugador } = r;
    const mapa = conexiones.get(sala.codigo) ?? new Map();
    conexiones.set(sala.codigo, mapa);
    const anterior = mapa.get(jugador.cuentaId);
    mapa.set(jugador.cuentaId, ws);
    if (anterior && anterior !== ws) { anterior.sala = null; anterior.close(1000, 'reemplazada'); }
    const volvia = sala.estado === 'enCurso' && !jugador.conectado;
    jugador.conectado = true;
    pararVentana(jugador);
    ws.ultimaActividad = Date.now();
    ws.sala = sala; ws.jugador = jugador;
    clearTimeout(ws.temporizadorHola);

    enviar(ws, mensajeSala(sala, jugador));
    if (m.ultimoSeq !== undefined) {
      const desde = Math.min(m.ultimoSeq, sala.eventos.length) + 1;
      enviar(ws, { tipo: 'registro', desdeSeq: desde, eventos: sala.eventos.slice(desde - 1) });
    }
    for (const j of sala.jugadores) {
      const otro = socketDe(sala, j);
      if (otro && otro !== ws) enviar(otro, mensajeSala(sala, j));
    }
    if (volvia) {
      for (const otro of socketsDe(sala).values()) {
        if (otro !== ws) enviar(otro, { tipo: 'jugadorVuelve', asiento: jugador.asiento });
      }
    }
  }

  // --- mensajes de la sala ----------------------------------------------
  function alProponer(ws, m) {
    const { sala, jugador } = ws;
    if (sala.estado !== 'enCurso') return error(ws, 'salaCerrada', { idMensaje: m.idMensaje });
    if (jugador.asiento === salas.asientoHost()) {
      return error(ws, 'mensajeNoValido', { idMensaje: m.idMensaje }); // el host acepta sus propios eventos
    }
    const previa = sala.propuestas.get(m.idMensaje);
    if (previa) { // reintento: no se vuelve a aplicar
      if (previa.asiento !== jugador.asiento) return error(ws, 'mensajeNoValido', { idMensaje: m.idMensaje });
      if (previa.estado === 'aceptada') {
        enviar(ws, { tipo: 'evento', seq: previa.seq, evento: sala.eventos[previa.seq - 1], idMensaje: m.idMensaje });
      } else if (previa.estado === 'rechazada') {
        enviar(ws, { tipo: 'rechazar', idMensaje: m.idMensaje, motivo: previa.motivo });
      }
      return undefined;
    }
    const host = socketDe(sala, sala.jugadores[salas.asientoHost()]);
    if (!host) return error(ws, 'salaCerrada', { idMensaje: m.idMensaje });
    sala.propuestas.set(m.idMensaje, { asiento: jugador.asiento, estado: 'pendiente' });
    enviar(host, { tipo: 'proponer', idMensaje: m.idMensaje, asiento: jugador.asiento, evento: m.evento });
    return undefined;
  }

  function alAceptar(ws, m) {
    const { sala } = ws;
    const r = salas.registrar(sala, m.seq, m.evento, m.idMensaje);
    if (!r.ok) return error(ws, r.error === 'salaCerrada' ? 'salaCerrada' : 'mensajeNoValido');
    difundir(sala, {
      tipo: 'evento', seq: m.seq, evento: m.evento, ...(m.idMensaje !== undefined ? { idMensaje: m.idMensaje } : {}),
    });
    return undefined;
  }

  function alRechazar(ws, m) {
    const { sala } = ws;
    const p = sala.propuestas.get(m.idMensaje);
    if (!p || p.estado !== 'pendiente') return error(ws, 'mensajeNoValido', { idMensaje: m.idMensaje });
    p.estado = 'rechazada';
    p.motivo = m.motivo;
    const autor = sala.jugadores.find((j) => j.asiento === p.asiento);
    const destino = autor && socketDe(sala, autor);
    if (destino) enviar(destino, { tipo: 'rechazar', idMensaje: m.idMensaje, motivo: m.motivo });
    return undefined;
  }

  function alEmpezar(ws, m) {
    const { sala } = ws;
    const r = salas.empezar(sala, m.partidaId, m.creadaEn);
    if (!r.ok) return error(ws, r.error === 'pocosJugadores' ? 'mensajeNoValido' : 'salaCerrada');
    difundirSala(sala);
    return undefined;
  }

  function alEchar(ws, m) {
    const { sala } = ws;
    if (sala.estado === 'enCurso') return error(ws, 'salaCerrada');
    const objetivo = sala.jugadores.find((j) => j.asiento === m.asiento);
    if (!objetivo || objetivo.asiento === salas.asientoHost()) return error(ws, 'mensajeNoValido');
    const destino = socketDe(sala, objetivo);
    socketsDe(sala).delete(objetivo.cuentaId);
    salas.quitar(sala, objetivo.cuentaId);
    if (destino) { destino.sala = null; error(destino, 'noEresDeLaSala'); destino.close(1000, 'echado'); }
    difundirSala(sala);
    return undefined;
  }

  function alSalir(ws) {
    const { sala, jugador } = ws;
    if (sala.estado === 'enCurso') { ws.close(1000, 'salir'); return; } // equivale a desconectarse
    if (jugador.asiento === salas.asientoHost()) { cancelar(sala, 'hostCancelo'); return; }
    socketsDe(sala).delete(jugador.cuentaId);
    salas.quitar(sala, jugador.cuentaId);
    ws.sala = null;
    ws.close(1000, 'salir');
    difundirSala(sala);
  }

  function alCerrar(ws) {
    clearTimeout(ws.temporizadorHola);
    const { sala, jugador } = ws;
    if (!sala || socketDe(sala, jugador) !== ws) return; // ya sustituida o fuera de la sala
    if (jugador.asiento === salas.asientoHost()) {
      cancelar(sala, 'hostDesconectado');
      return;
    }
    if (sala.estado === 'enCurso') { // empieza la ventana de 2 minutos (D-19 §D9)
      jugador.conectado = false;
      socketsDe(sala).delete(jugador.cuentaId);
      abrirVentana(sala, jugador);
      return;
    }
    socketsDe(sala).delete(jugador.cuentaId);
    salas.quitar(sala, jugador.cuentaId);
    difundirSala(sala);
  }

  const SOLO_HOST = new Set(['aceptar', 'rechazar', 'empezar', 'echar', 'registro']);

  wss.on('connection', (ws) => {
    ws.sala = null;
    ws.temporizadorHola = setTimeout(() => {
      if (!ws.sala) { error(ws, 'mensajeNoValido'); ws.close(1008, 'sin hola'); }
    }, esperaHolaMs);
    ws.ultimaActividad = Date.now();
    let ocupado = Promise.resolve(); // procesa los mensajes de uno en uno, en orden

    ws.on('message', (datos) => {
      ws.ultimaActividad = Date.now(); // cualquier mensaje (no solo `pong`) cuenta como vivo
      ocupado = ocupado.then(async () => {
        let m;
        try { m = JSON.parse(datos.toString('utf8')); } catch { return error(ws, 'mensajeNoValido'); }
        if (!ws.sala) { // el primer mensaje tiene que ser el hola
          if (!m || m.tipo !== 'hola') { error(ws, 'mensajeNoValido'); ws.close(1008, 'sin hola'); return undefined; }
          if (m.protocolo !== VERSION_PROTOCOLO) {
            error(ws, 'protocoloNoSoportado'); ws.close(1008, 'protocolo'); return undefined;
          }
        }
        const { tipo, errores } = validar(m);
        if (errores.length > 0) return error(ws, 'mensajeNoValido', typeof m?.idMensaje === 'string' ? { idMensaje: m.idMensaje } : {});
        if (tipo === 'hola') return ws.sala ? error(ws, 'mensajeNoValido') : alHola(ws, m);
        if (tipo === 'ping') return enviar(ws, { tipo: 'pong' });
        if (tipo === 'pong') return undefined;
        if (SOLO_HOST.has(tipo) && ws.jugador.asiento !== salas.asientoHost()) return error(ws, 'noEsHost');
        switch (tipo) {
          case 'proponer': return alProponer(ws, m);
          case 'aceptar': return alAceptar(ws, m);
          case 'rechazar': return alRechazar(ws, m);
          case 'empezar': return alEmpezar(ws, m);
          case 'echar': return alEchar(ws, m);
          case 'salir': return alSalir(ws);
          default: return error(ws, 'mensajeNoValido'); // registro del host: aún no
        }
      }).catch(() => error(ws, 'mensajeNoValido'));
    });
    ws.on('close', () => { ocupado.then(() => alCerrar(ws)); });
    ws.on('error', () => {});
  });

  // Latido: `ping` cada intervalo; sin ningún mensaje en `caidaMs`, caída.
  const latido = setInterval(() => {
    const ya = Date.now();
    for (const ws of wss.clients) {
      if (!ws.sala) continue; // antes del hola manda el temporizador del hola
      if (ya - ws.ultimaActividad > caidaMs) ws.terminate();
      else enviar(ws, { tipo: 'ping' });
    }
  }, intervaloPingMs);
  latido.unref();

  return {
    cerrar: () => new Promise((resolve) => {
      clearInterval(latido);
      for (const { jugadores } of [...conexiones.keys()].map((c) => salas.obtener(c)).filter(Boolean)) {
        for (const j of jugadores) pararVentana(j);
      }
      for (const ws of wss.clients) ws.terminate();
      wss.close(() => resolve());
    }),
  };
}

module.exports = { montarSalas, RUTA_POR_DEFECTO };
