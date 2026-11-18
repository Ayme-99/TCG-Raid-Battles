import 'package:incursiones_engine/incursiones_engine.dart';

import 'catalogo.dart';

/// Datos de la carta del jefe en la forma que pide el motor para componer su
/// turno entero (`turnoJefeAutomatico`, T-77). Un jefe del catálogo siempre
/// tiene tres ataques.
DatosJefe datosDeJefe(JefeCatalogo jefe) => DatosJefe(
      ataques: [
        for (final a in jefe.ataques)
          AtaqueJefeDatos(
            nombre: a.nombre,
            dano: a.dano,
            efecto: a.efecto == null
                ? null
                : EfectoAtaque(
                    tipo: a.efecto!.tipo,
                    valor: a.efecto!.valor,
                    duracion: a.efecto!.duracion,
                  ),
            efectoConMoneda: a.efecto?.conMoneda ?? false,
          ),
      ],
      invocacion: jefe.invocacion == null
          ? null
          : InvocacionDatos(
              segura: jefe.invocacion!.segura,
              aliados: {
                for (final e in jefe.invocacion!.aliados.entries)
                  e.key: _aliado(e.value),
              },
            ),
    );

AliadoDatos _aliado(AliadoCatalogo a) => AliadoDatos(
      categoria: a.categoria,
      nombre: a.nombre,
      hp: a.hp,
      ataqueNombre: a.ataqueNombre,
      ataqueDano: a.ataqueDano,
      habilidad: a.textoParaLaMesa,
      efectos: a.efectos,
      scriptId: a.scriptId,
      ataque: AtaqueAliadoDatos(
        monedas: a.ataqueMonedas,
        bonusMonedas: a.ataqueBonusMonedas,
        bonusCaras: a.ataqueBonusCaras ?? 1,
        bonusDano: a.ataqueBonusDano ?? 0,
        escalaPorUso: a.ataqueEscalaPorUso,
        danoExtraSiEstado: a.ataqueDanoExtraSiEstado,
        monedaRival: a.ataqueMonedaRival,
      ),
    );
