# Flujo de trabajo de Incursiones

Cómo se organiza el trabajo en el proyecto. Es la norma común de todos los sectores.

## Roles

- **Ayme** (dueño) decide. Nada se fusiona hasta que ordena «Fusiona».
- **Dirección y producción** gestiona las issues y el tablero, revisa los PR contra D-20 §10, enruta el trabajo y redacta los prompts de cada sector. No toca código.
- **Sectores:**
  - **Diseño:** reglas y documentos de diseño (D-xx).
  - **Programación:** único sector que escribe código (motor, app, servidor).
  - **Arte:** imágenes, escenas, cartas.
  - **Audio:** música y sonido.
  - **Calidad y soporte:** mediciones, playtests, simulaciones, revisión de flujos.
  - **Negocio y comunidad:** puntos, cuentas, tienda, comunicación.
  - **Bugs:** investiga fallos en solo lectura y da directrices a Programación o Diseño. No escribe código.

## Ciclo de una tarea

1. **Nace** como issue con la etiqueta de su sector. «Prioritaria» si toca antes que lo demás. «Decisión de Ayme» si falta una decisión suya.
2. **Dirección la enruta** y redacta el prompt para el chat del sector; Ayme lo pega allí.
3. **El sector trabaja** en una rama propia: una tarea = una rama = un PR, con prefijo de sector (`docs/`, `balance/`, `datos/`, etc.). No toca lo de otros sectores.
4. **Informa** con un comentario en la issue: Hecho / PR / Pendiente / Preguntas.
5. **Dirección revisa** el PR contra D-20 §10. Si choca con lo decidido, lo devuelve al sector.
6. **Ayme ordena «Fusiona»** y se fusiona. Nadie fusiona por su cuenta.
7. **Se verifica** el resultado (Calidad mide, Bugs comprueba en la web) y entonces se cierra la issue.

## Decisiones

- Las toma Ayme. Cada sector propone y recomienda, pero no decide reglas.
- Las decisiones cerradas se suben al repo en una rama con PR, sin fusionar hasta que Ayme lo ordene.
- Si algo choca con lo ya decidido, se dice en la issue; no se resuelve a ojo.
- **D-20 §10 es la fuente de verdad** del modo campaña.

## Fallos

1. Ayme describe el fallo: pasos, qué esperaba y qué pasó.
2. **Bugs** localiza la causa (solo lectura), dice si es error de código o regla mal escrita y pone gravedad: bloquea la partida / rompe una regla / molesta / cosmético.
3. Bugs da directrices concretas a Programación (o a Diseño si la regla es ambigua).
4. Programación corrige con un PR que dice «Refs #N», no «Closes».
5. Bugs verifica en la web y cierra la issue.
6. Los asuntos de balance no son bugs: Calidad mide y Ayme decide.

## Seguimiento

- Revisión diaria de solo lectura a las 08:17 (Europa/Madrid).
- Un comentario-resumen vivo en #589 con la tabla de fallos.
- Playtest en web (PowerShell, Windows): `git pull; cd app; flutter pub get; flutter run -d chrome`.

## Normas fijas

- Solo Programación escribe código.
- Los prompts de Flux llevan siempre la cabecera de estilo completa.
- La música de Suno solo se usa como boceto; lo generado en plan gratuito no se sube.
