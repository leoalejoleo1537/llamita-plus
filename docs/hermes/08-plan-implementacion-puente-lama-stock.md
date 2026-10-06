# A3 — Plan de implementación del puente Llamita Lama → Llamita Stock

Fecha: 2026-10-06
Estado: **aprobado por bloques; A3.1–A3.4c completadas y A3.4d pendiente**
Proyecto autorizado: Llamita Plus (`iuryhsjucblmebdogewa`)

## Objetivo

Conectar el POS propio Llamita Lama con el inventario actual para que, al cerrar una mesa, todas sus líneas confirmadas y no anuladas produzcan consumos idempotentes según las recetas existentes.

Fudo permanece intacto durante A3. Las áreas operativas, Toteat y la migración a stock producto-área quedan fuera hasta validar el puente Lama → Stock.

## Regla operativa principal

**La mesa y la caja nunca dependen del éxito del inventario.**

- La mesa debe poder cerrarse y la venta debe quedar registrada para el arqueo aunque falte una receta o falle el motor de inventario.
- El cierre de mesa es el único disparador de inventario de Lama.
- El método de pago, pagos parciales, propina y cierre de caja no generan descuentos adicionales.
- Si inventario falla, el evento queda `sin_receta`, `pendiente` o `error`, visible y reprocesable.
- No se permite una receta aplicada parcialmente sin un resultado explícito.

## Flujo objetivo

```text
cuenta_cobrar / cuenta_cerrar
  → cerrar la cuenta y congelar la venta
  → registrar eventos idempotentes por línea
  → intentar aplicar receta al inventario
  → aplicado | sin_receta | pendiente | error
  → reintento seguro sin afectar caja ni volver a cerrar la mesa
```

La captura del evento debe ocurrir en la misma transacción del cierre. La aplicación de inventario no puede impedir que la cuenta quede cerrada: cualquier fallo se captura como estado recuperable.

## A3.1 — Cimientos, seguridad e idempotencia

Estado: **COMPLETADA — 2026-10-06**

### Alcance

- Verificar una vez más repositorio, proyecto Supabase y firmas reales antes de modificar.
- Revisar el changelog y documentación vigente de Supabase relevante para PostgreSQL, RLS, funciones y Data API.
- Crear una migración aditiva y reversible para las tablas mínimas del puente:
  - eventos de venta/inventario por línea;
  - aplicaciones por ingrediente;
  - restricciones, índices y claves de idempotencia.
- Diseñar estados como mínimo: `pendiente`, `prueba`, `aplicado`, `sin_receta`, `error`, `revertido`.
- Preparar campos para identidad canónica futura, referencia de origen, cuenta/línea Lama, snapshot de precio, snapshot de receta, error y trazabilidad.
- Habilitar RLS en toda tabla expuesta y evitar escritura directa desde el navegador. La mutación futura debe ocurrir por una frontera RPC controlada.
- Definir que la ausencia de configuración equivale a modo `apagado`; no insertar ni habilitar `real` en ninguna sede.
- Añadir pruebas SQL o automatizadas de constraints e idempotencia usando transacción revertida o datos sintéticos inequívocos y recuperables.

### Prohibiciones

- No modificar todavía `cuenta_cobrar`, `cuenta_cerrar`, `item_anular` ni el comportamiento de la UI.
- No tocar `productos.stock_actual`, lotes, recetas existentes ni datos de ventas.
- No modificar `fudo_procesar_item`, Edge Functions Fudo ni secretos.
- No activar el puente en modo `prueba` o `real`.
- No crear áreas de inventario.
- No consultar ni tocar Café del Desierto / Llamita Stock.

### Salida requerida

- Migración versionada en el repositorio y, si la conexión autorizada lo permite y las verificaciones pasan, aplicada únicamente a Llamita Plus.
- Pruebas de estructura, RLS, constraints e idempotencia.
- Documento con rollback explícito y confirmación de que ninguna venta o cantidad cambió.
- Bitácora actualizada y A3.1 marcada `COMPLETADA`, `BLOQUEADA` o `REQUIERE DECISIÓN`.
- No activar A3.2 automáticamente.

## A3.2 — Captura del cierre en modo apagado/prueba

Estado: **COMPLETADA — 2026-10-06**

- Crear una única función interna para registrar el cierre Lama por `cuenta_id`.
- Integrarla en los dos caminos que pueden cerrar una cuenta: `cuenta_cobrar` y `cuenta_cerrar`.
- Capturar líneas confirmadas, no anuladas, con `cuenta_item.id` como identidad estable.
- Usar una clave determinista `lama:{sede}:{cuenta_id}:{cuenta_item_id}:cierre`.
- Congelar cantidad, precio, producto de origen y receta encontrada.
- Una mesa vacía no crea eventos.
- En modo `apagado`, conservar el comportamiento previo.
- En modo `prueba`, crear eventos y previsiones sin tocar stock.
- Un cierre repetido devuelve los eventos existentes.
- Si falta receta, cerrar la mesa y marcar el evento `sin_receta`.
- Si falla la captura mínima del evento, registrar un diagnóstico técnico; nunca caer silenciosamente a otro camino de cobro.

### Resultado A3.2

- Migraciones aplicadas: `a3_2_captura_cierre_lama` y `a3_2_restrict_captura_execute` en Supabase `llamita-plus`.
- Se creó `lama_stock_capturas` y la función interna `lama_stock_capturar_cuenta(bigint)`. Las funciones instaladas de `cuenta_cobrar` y `cuenta_cerrar` fueron leídas con `pg_get_functiondef`; se conservaron firmas y comportamiento, agregando únicamente la llamada protegida posterior al cierre.
- La captura es apagada por ausencia de configuración, de prueba en modo `prueba`, no genera aplicaciones, no escribe stock y no conecta Fudo.
- Rollback: `sql/2026-10-a3-2-captura-cierre-lama.rollback.sql`; restaura las funciones originales y elimina estructura A3.2 solo si no contiene filas.
- Pruebas ejecutadas y revertidas: apagado, receta, sin receta, anulación, mesa vacía, doble cierre, reintento, cobro con parcial/propina/descuento y error técnico forzado. Todas pasaron.
- No activar A3.3 hasta revisar los marcadores `error`/`sin_receta` y aprobar el motor de aplicación.
- Persistir por cuenta si la captura quedó `no_aplica`, `pendiente`, `capturada` o `error`, mediante una solución aditiva verificada por Codex. La venta y caja siguen siendo autoritativas.
- Proteger la captura con manejo de excepción: una falla técnica del subsistema de inventario no revierte pagos, importes ni el estado cerrado de la cuenta.

## A3.3 — Motor neutral y aplicación al stock actual

Estado: **COMPLETADA — 2026-10-06**

- Crear un motor independiente del POS que reciba `event_id`.
- Resolver ingredientes desde el snapshot congelado.
- Reutilizar de forma controlada los caminos actuales de lotes FIFO y descuento sin lotes.
- Registrar una aplicación por ingrediente con restricción única.
- En modo `prueba`, calcular sin escribir cantidades.
- En modo `real`, aplicar una sola vez a `productos.stock_actual` y lotes.
- Si una receta no puede aplicarse completa, revertir el intento de esa línea, conservar el evento y marcar `error`; no dejar ingredientes descontados a medias.
- El cierre de mesa y sus importes permanecen válidos aunque inventario falle.
- Corregir antes de aplicar: `ocurrido_at` representa el cierre de mesa (`cerrada_at`), mientras `agregado_at` queda como metadata de la línea.
- Implementar y probar modo real solo dentro de transacciones revertidas; ninguna sede queda activada persistentemente en A3.3.

### Resultado A3.3

- Migraciones aplicadas: `a3_3_motor_neutral_lama_stock` y `a3_3_fulfillment_rules`.
- `lama_stock_aplicar_evento(uuid)` es interno, usa `snapshot_receta` congelado, crea una aplicación por ingrediente con clave idempotente y conserva error por componente.
- En `prueba` genera deltas negativos esperados sin escribir stock. En `real` delega a `descontar_lotes` cuando hay lotes y a `descontar_con_reposicion` cuando no los hay; no hace un segundo `UPDATE` de `productos.stock_actual`.
- Una mesa Lama se captura como `fulfillment = serve`; se aplican `siempre` y `servir`. `llevar` se aplica únicamente a eventos `takeaway`.
- `ocurrido_at` usa `cuentas.cerrada_at`; `agregado_at` queda en metadata.
- Pruebas revertidas: receta simple/múltiple, prueba, real, sin lotes, FIFO, retry/timeout equivalente, error intermedio, insuficiencia, sin receta, receta cambiada después de capturar y reglas de fulfillment.
- Estado final verificado: configuración, eventos, aplicaciones y capturas en cero; productos 1.437; stock total 15.438. No se activó ninguna sede ni A3.4.
- Rollback: `sql/2026-10-a3-3-motor-neutral-lama-stock.rollback.sql`. Limitación conocida: `lama_stock_aplicaciones.lote_id` conserva el primer lote FIFO elegido cuando una aplicación atraviesa varios lotes; el saldo real sigue gobernado por el FIFO instalado.

## A3.4 — Observabilidad, pruebas E2E y reversas

Estado: **A3.4a COMPLETADA — A3.4b COMPLETADA — A3.4c COMPLETADA — A3.4d pendiente**

### A3.4a — Observabilidad y reproceso seguro en modo prueba

Estado: **COMPLETADA — 2026-10-06**

- Crear una consulta interna de eventos por estado: `pendiente`, `aplicado`, `error` y `sin_receta`.
- Mostrar conteo de aplicaciones por evento y diagnóstico, sin exponer las tablas al navegador.
- Crear un helper interno para reintentar únicamente eventos `error` cuyo `modo_efectivo` sea `prueba`.
- El reintento usa `event_id`, conserva la clave idempotente y delega en el motor A3.3.
- No habilitar sedes, modo real ni modificar stock persistente.
- Probar reintento, doble reintento, sin receta, evento aplicado y permisos.

#### Resultado A3.4a

- Migración aplicada: `a3_4a_observabilidad_reproceso`.
- Vista interna: `lama_stock_eventos_observabilidad`, con estados, errores y conteo de aplicaciones. Usa `security_invoker` y no tiene SELECT para `public`, `anon`, `authenticated` ni `service_role`.
- Helper interno: `lama_stock_reintentar_evento(uuid)`, limitado a eventos `error` en modo `prueba`; eventos `sin_receta` y `real` se rechazan.
- Pruebas revertidas: consulta de estados, reproceso, doble reproceso, rechazo de `sin_receta`, rechazo de `real`, permisos y no modificación de stock.
- Estado final: configuración, eventos y aplicaciones en cero; productos 1.437; stock total 15.438.
- Rollback: `sql/2026-10-a3-4a-observabilidad-reproceso.rollback.sql`.

### A3.4b — Prueba sintética E2E del flujo Lama–Stock

Estado: **COMPLETADA — 2026-10-06**

- Se ejecutó en Llamita Plus una única transacción `BEGIN ... ROLLBACK` con productos, receta, líneas, cuenta y mesa temporales.
- Se cubrió el flujo completo: agregado, confirmación, cierre, captura, snapshot, modo `prueba`, aplicaciones por ingrediente, idempotencia, reintento y error intermedio.
- La receta temporal de dos ingredientes generó dos aplicaciones esperadas con delta total `-6`. Un cambio posterior de la receta viva no modificó el snapshot.
- Un trigger temporal produjo un fallo en el ingrediente intermedio. La cuenta permaneció cerrada y su total comercial fue `250`; el evento quedó en `error`, sin aplicaciones parcialmente aplicadas. El reintento pasó a `prueba` y un segundo reintento no duplicó aplicaciones.
- Todos los artefactos sintéticos, incluidos trigger y función de fallo, fueron revertidos. No se activó modo real ni se modificó stock persistente.
- Conteos pre/post: cuentas `59`, líneas `88`, recetas `396`, ítems de receta `514`, productos `1437`, stock total `15438.00`, comandas `50`; configuración, eventos, aplicaciones y capturas `0` en ambos cortes.
- Evidencia: `docs/hermes/11-pruebas-a3-4b.md`.

### A3.4c — Prueba controlada de interfaz Lama en modo prueba

Estado: **COMPLETADA — 2026-10-06**

- Recorrer el flujo de la interfaz Lama mediante las funciones comerciales instaladas: agregar, confirmar y cerrar.
- Configurar temporalmente una sede sintética en `prueba`, capturar y aplicar el evento con snapshot de receta.
- Registrar IDs de cuenta, evento y aplicaciones; repetir la aplicación y comprobar idempotencia.
- Ejecutar todo dentro de `BEGIN ... ROLLBACK`; no habilitar `real`, no cambiar stock y dejar `lama_stock_config` vacía.
- Procedimiento manual documentado en `docs/hermes/12-prueba-manual-a3-4c.md`.
- Resultado: cuenta `990301`; evento `646d4cb3-5124-4410-ab40-4dbd89a68b6c`; aplicaciones `2a419ca9-56bf-49b8-8bea-71645f3f10dd` y `a9bea2ef-19c9-4f25-82c8-07f4b49fa33d`.

### A3.4d — Reversas y activación real

Estado: **PENDIENTE**

- Crear operación administrativa de reversa posterior al cierre.
- Generar aplicaciones compensatorias; no borrar eventos ni movimientos.
- Añadir panel en Ajustes para modo `apagado/prueba/real`, eventos pendientes, sin receta, errores y reproceso.
- Activar primero una sede/contexto de prueba en Llamita Plus.
- Conciliar stock esperado y real antes de cualquier activación adicional.
- No iniciar automáticamente desde A3.4c.

## Identidad y compatibilidad durante A3

- Lama puede seguir leyendo `fudo_productos` y guardando `fudo_product_id` durante esta transición.
- Los eventos nuevos deben reservar un campo canónico propio de Llamita y conservar la referencia externa.
- `cuenta_items.precio` se usa como snapshot histórico de precio en la primera versión.
- La receta existente se copia como snapshot al cerrar; no se modifica retroactivamente.
- La migración completa del catálogo canónico se hará después de validar el puente y antes de Toteat.

## Criterios globales de éxito

1. Cerrar una mesa siempre registra su venta y caja aunque inventario falle.
2. Repetir el cierre no duplica eventos ni descuentos.
3. Falta de receta queda visible y reprocesable.
4. Ningún ingrediente queda parcialmente descontado por un fallo intermedio.
5. Fudo continúa con su comportamiento actual durante A3.
6. `productos.stock_actual` sigue siendo la única cantidad vigente durante A3.
7. No se toca Café del Desierto / Llamita Stock.

### Resultado A3.1 — 2026-10-06

- Estado: **COMPLETADA**. Se aplicó exclusivamente la migración `a3_1_cimientos_lama_stock` en Supabase `llamita-plus` (`iuryhsjucblmebdogewa`).
- Archivo versionado: `sql/2026-10-a3-1-cimientos-lama-stock.sql`.
- Tablas creadas: `lama_stock_config`, `lama_stock_eventos`, `lama_stock_aplicaciones`.
- La configuración no tiene filas; la ausencia de configuración equivale a `apagado`. No se habilitó `prueba` ni `real`.
- RLS está activo en las tres tablas, sin políticas ni privilegios directos para `anon` o `authenticated`. La escritura futura deberá pasar por una frontera RPC controlada.
- Se verificaron constraints de estados, cantidades, reversas, origen Lama e índices únicos de evento y clave de idempotencia.
- Prueba idempotente ejecutada dentro de `BEGIN … ROLLBACK`: un duplicado de evento y un duplicado de aplicación fueron rechazados; no quedaron filas de prueba.
- Conteos pre/post sin cambios: cuentas 59, líneas 88, recetas 396, ítems de receta 514, productos 1.437, suma de `stock_actual` 15.438. Las tablas nuevas quedaron con cero filas.
- No se modificaron `cuenta_cobrar`, `cuenta_cerrar`, `item_anular`, ventas, recetas, productos, lotes, Fudo ni stock. No se activó A3.2.

#### Rollback

El rollback está preparado en `sql/2026-10-a3-1-cimientos-lama-stock.rollback.sql`. Solo permite eliminar las tablas si las tres están vacías; aborta si ya contienen eventos o aplicaciones. Debe ejecutarse en orden aplicaciones → eventos → configuración y únicamente antes de A3.2. No se ejecutó.
