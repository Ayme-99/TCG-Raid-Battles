'use strict';

// Repositorio sobre MongoDB (driver nativo; con mongoose vale
// `mongoose.connection.db`). Modelo de datos de D-10 §5:
//   incursiones_partidas          una por partida, con el registro completo
//   incursiones_partida_jugadores una por asiento, con lo que se abona
// Los totales de una cuenta se calculan sumando sus filas, nunca se guardan:
// por eso un reintento no puede sumar dos veces.
const COLECCION_PARTIDAS = 'incursiones_partidas';
const COLECCION_JUGADORES = 'incursiones_partida_jugadores';
// Partida de campaña guardada en la cuenta (#478): una por cuenta y campaña,
// `_id` = `${cuentaId}:${campana}`.
const COLECCION_GUARDADOS_CAMPANA = 'incursiones_campana_partidas';

function crearRepoMongo(db) {
  const partidas = db.collection(COLECCION_PARTIDAS);
  const jugadores = db.collection(COLECCION_JUGADORES);
  const guardados = db.collection(COLECCION_GUARDADOS_CAMPANA);
  const sinId = (doc) => {
    if (!doc) return null;
    const { _id, ...resto } = doc;
    return resto;
  };

  return {
    // Llamar una vez al arrancar.
    async asegurarIndices() {
      await jugadores.createIndex({ partidaId: 1, asiento: 1 }, { unique: true });
      await jugadores.createIndex({ cuentaId: 1, guardadaEn: -1, partidaId: -1 });
    },

    async guardarPartida({ partida, jugadores: filas }) {
      let creada = true;
      try {
        await partidas.insertOne({ _id: partida.partidaId, ...partida });
      } catch (e) {
        if (e && e.code === 11000) creada = false;
        else throw e;
      }
      // Idempotente: si un intento anterior se cortó a medias, completa las
      // filas que falten sin tocar las que ya estaban.
      await jugadores.bulkWrite(
        filas.map((fila) => ({
          updateOne: {
            filter: { partidaId: fila.partidaId, asiento: fila.asiento },
            update: { $setOnInsert: fila },
            upsert: true,
          },
        })),
        { ordered: false },
      );
      const guardada = await partidas.findOne({ _id: partida.partidaId });
      const { _id, ...resto } = guardada;
      return { creada, partida: resto };
    },

    async obtenerPartida(partidaId) {
      const p = await partidas.findOne({ _id: partidaId });
      if (!p) return null;
      const { _id, ...resto } = p;
      return resto;
    },

    async listar(cuentaId, { limite, antes }) {
      const filtro = { cuentaId };
      if (antes) {
        filtro.$or = [
          { guardadaEn: { $lt: antes.guardadaEn } },
          { guardadaEn: antes.guardadaEn, partidaId: { $lt: antes.partidaId } },
        ];
      }
      const docs = await jugadores
        .find(filtro)
        .sort({ guardadaEn: -1, partidaId: -1 })
        .limit(limite)
        .toArray();
      return docs.map(({ _id, ...resto }) => resto);
    },

    async puntosDe(cuentaId) {
      const [r] = await jugadores
        .aggregate([
          { $match: { cuentaId } },
          {
            $group: {
              _id: null,
              puntos: {
                $sum: { $cond: ['$abonado', { $add: ['$puntos', { $ifNull: ['$bonoEstados', 0] }] }, 0] },
              },
              partidas: { $sum: 1 },
            },
          },
        ])
        .toArray();
      return { puntos: r ? r.puntos : 0, partidas: r ? r.partidas : 0 };
    },

    async obtenerGuardadoCampana(cuentaId, campana) {
      return sinId(await guardados.findOne({ _id: `${cuentaId}:${campana}` }));
    },

    // Atómico: la revisión va en el filtro, así dos dispositivos no se pisan.
    async guardarGuardadoCampana({ cuentaId, campana, revisionBase, partida, actualizadaEn }) {
      const _id = `${cuentaId}:${campana}`;
      const nuevo = { cuentaId, campana, revision: revisionBase + 1, actualizadaEn, partida };
      if (revisionBase === 0) {
        try {
          await guardados.insertOne({ _id, ...nuevo });
          return { ok: true, guardado: nuevo };
        } catch (e) {
          if (!(e && e.code === 11000)) throw e;
          return { ok: false, actual: sinId(await guardados.findOne({ _id })) };
        }
      }
      const hecho = await guardados.findOneAndUpdate(
        { _id, revision: revisionBase },
        { $set: nuevo },
        { returnDocument: 'after' },
      );
      if (hecho) return { ok: true, guardado: sinId(hecho) };
      return { ok: false, actual: sinId(await guardados.findOne({ _id })) };
    },
  };
}

module.exports = {
  crearRepoMongo, COLECCION_PARTIDAS, COLECCION_JUGADORES, COLECCION_GUARDADOS_CAMPANA,
};
