# Mesa de trabajo Hermes / Codex

Esta carpeta es el espacio documental compartido entre Hermes (arquitectura, análisis y coordinación) y Codex (inspección, implementación, pruebas y publicación) para Llamita Plus.

## Alcance

- Este repositorio es el sandbox de Llamita Plus.
- Los documentos de esta carpeta describen decisiones y tareas para este repositorio.
- Café del Desierto / Llamita Stock es un sistema separado y queda fuera de alcance.
- La fuente operativa de tareas es `03-cola-de-trabajo-codex.md`.
- La trazabilidad de avances se registra en `04-bitacora-codex.md`.

## Flujo básico

1. Hermes prepara o actualiza un plan y lo deja en Markdown para revisión.
2. El usuario revisa y aprueba el plan o una fase concreta.
3. Hermes activa una sola tarea en la cola.
4. Codex lee las reglas y la tarea activa, inspecciona el código y la documentación, y trabaja únicamente en esa fase.
5. Codex ejecuta las pruebas pertinentes, actualiza la bitácora y deja un resumen claro.
6. La siguiente fase no se activa hasta revisar el resultado de la anterior.

## Documentos

- `00-reglas-operativas.md`: límites, seguridad, permisos y forma de trabajo.
- `03-cola-de-trabajo-codex.md`: tarea actualmente autorizada.
- `04-bitacora-codex.md`: historial de ejecuciones y resultados.
- `05-decisiones-pendientes.md`: decisiones que requieren confirmación.
- `06-canal-hermes-codex.md`: contexto arquitectónico, mensajes y respuesta de la auditoría.
- `07-contrato-comun-inventario.md`: contrato aprobado como base para ventas, recetas, eventos y ledger.
- `08-plan-implementacion-puente-lama-stock.md`: implementación por bloques del puente Lama → Stock.
- `skills/README.md`: cómo se almacenan playbooks y qué diferencia hay con una skill ejecutable.

- `01-plan-areas-operativas.md`: plan y fases de inventario por áreas.
- `13-auditoria-areas-sedes-bodega.md`: auditoría Bloque 0 de áreas, sedes, Bodega y escritores.
