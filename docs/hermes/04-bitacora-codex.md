# Bitácora de Codex

## 2026-10-06 — Inicialización del entorno

- Estado: entorno documental creado.
- Repositorio: `leoalejoleo1537/llamita-plus`.
- Rama objetivo: `master`.
- Cambios de aplicación: ninguno.
- Cambios de base de datos: ninguno.
- Tareas activas: ninguna.
- Próximo hito: preparar el plan de arquitectura por áreas operativas y someterlo a revisión antes de activarlo.
- Esta entrada describe el estado inicial del documento; la activación y el resultado posterior de B1 quedan anotados abajo.

Las futuras entradas deben incluir fase, commit, archivos tocados, pruebas, resultado y riesgos pendientes.

## 2026-10-06 - Canal de comunicación Hermes/Codex y activación de A1

- Estado: **A1 ACTIVA**, auditoría documental y técnica de solo lectura.
- Se creó `docs/hermes/06-canal-hermes-codex.md` como canal compartido de contexto, decisiones, preguntas y respuesta arquitectónica.
- Se actualizó `03-cola-de-trabajo-codex.md` para que Codex lea el canal antes de trabajar y responda allí el resultado.
- Se actualizó `docs/hermes/README.md` para incluir el canal.
- Cambios de aplicación: ninguno.
- Cambios de esquema y datos: ninguno.
- Publicación de esta actualización documental: autorizada a `master`.
- Siguiente paso: ejecutar la auditoría A1 y completar el canal con hechos comprobados sobre Fudo, Lama, Ajustes y los escritores de stock.

## 2026-10-06 — B1: verificación, detenida por decisiones pendientes

- Estado: **REQUIERE DECISIÓN**. Solo se hizo inspección de lectura; no se ejecutó migración ni se insertaron o actualizaron datos.
- Commit base inspeccionado: `c5cc8d6` (`origin/master`). Rama local `work`, igual a `origin/master`; árbol limpio después del fast-forward solicitado.
- Alcance: se verificaron los documentos Hermes, código de inventario y esquema activo del proyecto Supabase `llamita-plus` (`iuryhsjucblmebdogewa`). No se consultó ni modificó Café del Desierto / Llamita Stock.
- Archivos de esta actualización: `docs/hermes/03-cola-de-trabajo-codex.md`, `docs/hermes/04-bitacora-codex.md`, `docs/hermes/05-decisiones-pendientes.md`.
- Migraciones ejecutadas: ninguna. Datos creados o modificados: ninguno. Pruebas de aplicación: no ejecutadas; no hubo cambios de código ni modelo que probar. Se ejecutaron consultas `SELECT` y lecturas de metadatos únicamente en el proyecto verificado.
- Resultado: no se encontró una sede o rama de demostración aislada. El interruptor global `modo_demostracion` está activo, pero la documentación y el código muestran que solo filtra pantallas; no separa los datos. Las sedes `plaza`, `angamos`, `central` y la clave antigua `bodega` tienen productos y registros existentes. No se usarán para sembrar áreas sin una decisión explícita.
- Riesgo arquitectónico: `productos.stock_actual` es el stock vigente, editable desde la app y usado por RPC de ventas, entradas, mermas, repartos, restauraciones y por el trigger que suma `producto_lotes`. Una tabla de stock por área no puede convertirse en fuente paralela. Se requiere definir un corte que adapte todos esos caminos o posponer las cantidades por área hasta un corte coordinado.
- Siguiente paso: resolver las dos decisiones nuevas registradas en `05-decisiones-pendientes.md`. B2 permanece sin activar. No se hizo push de código ni de migración; se publicará solo la actualización documental del estado bloqueado para evitar que otra ventana repita B1.

## 2026-10-06 - A1: auditoría Fudo y Llamita Lama completada

- Estado: **COMPLETADA** en modo plan y solo lectura.
- Repositorio: `leoalejoleo1537/llamita-plus`, rama `work`, sincronizada con `origin/master` mediante fast-forward. Proyecto Supabase verificado: `llamita-plus` (`iuryhsjucblmebdogewa`), `ACTIVE_HEALTHY`.
- Archivos de auditoría: `docs/hermes/06-canal-hermes-codex.md`; se actualizó también esta bitácora y el estado de A1 en `03-cola-de-trabajo-codex.md`.
- Hallazgos: Fudo tiene catálogo espejo, recetas, `fudo_procesar_item`, modo prueba/real, idempotencia por ítem y empujes manuales protegidos por Ajustes. Lama tiene mesas, comandas, cobros parciales, anulaciones, impresión y arqueos, pero no llama al motor de inventario ni escribe `productos.stock_actual`.
- Contrato recomendado: evento común con `event_id`, `source`, `source_sale_id`, `source_line_id`, sede, fecha, estado, referencia de producto/proveedor, cantidad, fulfillment y versión de receta; deduplicación y compensación de anulaciones en un único motor.
- Consultas: inspección `rg`/`sed`/`find`/`wc`, metadatos Supabase de solo lectura (`get_project`, `list_tables`, `list_edge_functions`, `list_migrations`, `list_branches`) y `git diff --check`. No se ejecutó SQL, RPC, migración, Edge Function ni prueba de aplicación.
- Frontera de datos: no se consultó ni modificó Café del Desierto / Llamita Stock; no se insertó, actualizó ni borró ningún dato.
- Riesgos pendientes: decisión del momento de descuento de Lama, anulaciones y consumos internos; múltiples escritores de stock; falta de identificador universal y adaptador Toteat.
- Siguiente paso: resolver las decisiones del contrato común. Mantener B1 y cualquier puente Lama→inventario sin activar.

## 2026-10-06 - A2: regla de descuento de Lama aclarada

- Decisión de Alejo: una mesa de Lama descuenta inventario al **cerrarse**. Deben descontarse todas sus líneas confirmadas, con independencia de que el pago sea efectivo, tarjeta, parcial, cortesía o ya se haya registrado antes.
- Aclaración: pago, propina, medio de pago y cierre de caja no son disparadores separados de inventario. El evento de consumo es el cierre de mesa.
- Consecuencia para A2: el contrato debe modelar cierre idempotente y una compensación explícita si una línea cerrada se anula posteriormente. No se modificó código, esquema ni datos.

## 2026-10-06 - A2: contrato común de venta, receta e inventario

- Estado: **COMPLETADA como diseño documental**; la implementación queda pendiente de decisiones explícitas.
- Repositorio: `leoalejoleo1537/llamita-plus`, rama `work`, sincronizada por fast-forward con `origin/master` antes de comenzar. No se consultó ni modificó Café del Desierto / Llamita Stock.
- Archivo nuevo: `docs/hermes/07-contrato-comun-inventario.md`.
- Canal actualizado: `docs/hermes/06-canal-hermes-codex.md` con la respuesta arquitectónica A2.
- Diseño: producto canónico Llamita, enlaces Fudo/Toteat, precio independiente con snapshot, receta versionada, `SaleEvent`, ledger inmutable, idempotencia por proveedor y compensaciones sin borrado.
- Regla Lama: el cierre de mesa emite un consumo único de todas las líneas confirmadas; pagos parciales, propinas, medios y arqueo no son disparadores adicionales. Las anulaciones previas no consumen; las posteriores generan compensación.
- Transición: fases de inventario de escritores, identidad/proyección, ledger con área opcional, corte coordinado de todos los escritores, activación por sede y retiro de compatibilidad. No se crea una segunda fuente editable.
- Pruebas definidas: reintentos, timeouts, anulaciones, pagos parciales, recetas/precios históricos, FIFO, Fudo/Toteat y conciliación producto-área. No se ejecutan pruebas de aplicación en una fase documental.
- Verificaciones: `git fetch origin master`, `git merge --ff-only origin/master`, lectura de cola/bitácora/canal/decisiones y `git diff --check`. No se ejecutó SQL, RPC, migración, Edge Function ni mutación de datos.
- Cambios de código, esquema y datos: **ninguno**.
- Siguiente paso: obtener las decisiones de Alejo listadas en el contrato antes de activar cualquier implementación o B1.

## 2026-10-06 — A3.1: cimientos del puente Lama → Stock aplicados

- Estado: **COMPLETADA**. Se ejecutó únicamente A3.1; A3.2 permanece pendiente y no fue activada.
- Repositorio confirmado: `leoalejoleo1537/llamita-plus`, rama `work`, remoto `origin` correcto y fast-forward a `origin/master` antes de trabajar.
- Proyecto confirmado: Supabase `llamita-plus`, ref `iuryhsjucblmebdogewa`, `ACTIVE_HEALTHY`.
- Migración aplicada: `a3_1_cimientos_lama_stock`; archivo `sql/2026-10-a3-1-cimientos-lama-stock.sql`.
- Tablas nuevas: `lama_stock_config`, `lama_stock_eventos`, `lama_stock_aplicaciones`. Incluyen estados `pendiente`, `prueba`, `aplicado`, `sin_receta`, `error`, `revertido`, snapshots, trazabilidad, reversa e idempotencia.
- Seguridad: RLS activo; sin políticas ni privilegios de tabla para `anon`/`authenticated`; no hay funciones ni triggers nuevos. La configuración quedó sin filas y el modo efectivo permanece apagado.
- Pruebas: firmas reales de `cuenta_cobrar` y `cuenta_cerrar` verificadas y no modificadas; colisiones `lama_stock_*` ausentes antes de aplicar; índices/constraints/RLS/grants comprobados después; prueba de duplicado de evento y aplicación rechazada dentro de transacción revertida.
- Integridad: pre/post cuentas 59, líneas 88, recetas 396, ítems de receta 514, productos 1.437 y stock total 15.438. Nuevas tablas: 0 filas. No cambiaron ventas, recetas, productos, lotes ni cantidades de stock.
- Documentación Supabase consultada: guía vigente de Row Level Security y changelog público; se verificó PostgreSQL 17.6 y disponibilidad de `gen_random_uuid()` antes de aplicar.
- Rollback preparado: `sql/2026-10-a3-1-cimientos-lama-stock.rollback.sql`; protegido para abortar si las tablas contienen filas. No ejecutado.
- Frontera de datos: no se accedió a Café del Desierto / Llamita Stock.

## 2026-10-06 — A3.2: captura protegida del cierre Lama completada

- Estado: **COMPLETADA**; A3.3 no fue activada.
- Preflight: repositorio `leoalejoleo1537/llamita-plus`, rama `work`, fast-forward a `origin/master`; Supabase `llamita-plus` (`iuryhsjucblmebdogewa`).
- Definiciones instaladas obtenidas con `pg_get_functiondef`: `cuenta_cobrar(bigint,text,text,text,numeric,jsonb,jsonb)` y `cuenta_cerrar(bigint,text)`. Las firmas se conservaron y su comportamiento comercial se mantuvo; solo se añadió una llamada protegida posterior al cierre.
- Migraciones aplicadas: `a3_2_captura_cierre_lama` y `a3_2_restrict_captura_execute`.
- Implementación: `lama_stock_capturas`, `lama_stock_capturar_cuenta(bigint)` y llamadas desde ambos cierres. En apagado no hay eventos; en prueba se congelan cantidad, precio y snapshot de receta; líneas anuladas se excluyen; sin receta queda `sin_receta`; mesa vacía deja captura con cero eventos; reintentos no duplican.
- Seguridad: helper `SECURITY DEFINER`, `search_path` controlado y EXECUTE revocado explícitamente para `public`, `anon`, `authenticated` y `service_role`.
- Pruebas revertidas: apagado; receta existente; sin receta; línea anulada; mesa vacía; doble cierre/reintento; `cuenta_cobrar` con pago parcial, propina y descuento; error forzado mediante trigger temporal. Todas pasaron y terminaron con `ROLLBACK`.
- Error forzado: la captura quedó en estado `error` con diagnóstico y la cuenta quedó `cerrada`; pagos/caja no se revirtieron.
- Integridad pre/post: cuentas 59, líneas 88, recetas 396, ítems de receta 514, productos 1.437 y stock total 15.438; tablas A3.2 quedaron en cero filas tras pruebas revertidas. No cambió ninguna cantidad de stock ni se creó aplicación.
- Archivos: migración, hardening, rollback y documentación Hermes. No se modificaron UI, Fudo, recetas, productos ni lotes.

## 2026-10-06 - Activación de A3.1

- Decisión de negocio: una mesa y su importe cierran y alimentan caja aunque inventario falle; el evento de stock queda pendiente, sin receta o con error y se reprocesa después.
- Plan nuevo: `docs/hermes/08-plan-implementacion-puente-lama-stock.md`, dividido en A3.1–A3.4.
- Estado: solo **A3.1 ACTIVA**. Autoriza cimientos aditivos, RLS, constraints, idempotencia y pruebas; no autoriza conectar cierres ni modificar stock.
- A3.2–A3.4 y B1 continúan pendientes. No hubo cambios de aplicación, SQL ejecutado ni datos en esta activación documental.

## 2026-10-06 - Revisión de A3.1 y activación de A3.2

- Revisión de Hermes: las tablas A3.1 son aditivas; RLS está activo sin políticas abiertas; `anon` y `authenticated` no tienen privilegios directos; los modos nacen apagados y la idempotencia está respaldada por índices únicos.
- A3.2 queda **ACTIVA** para capturar cierres en modo apagado/prueba, sin escribir stock.
- Requisito añadido: persistir el estado de captura por cuenta y aislar cualquier excepción del puente para que venta, pago y cierre de caja permanezcan válidos.
- A3.3, A3.4 y B1 continúan pendientes. Esta activación solo cambia documentación.

## 2026-10-06 - Revisión de A3.2 y activación de A3.3

- Revisión de Hermes: la captura está aislada de caja, respeta modo apagado/prueba, conserva firmas y no escribe stock.
- Corrección requerida: futuros eventos usarán `cuentas.cerrada_at` como `ocurrido_at`; la hora de agregado de la línea será metadata.
- A3.3 queda **ACTIVA** para construir y probar el motor neutral. El camino real solo puede probarse dentro de transacciones revertidas; ninguna sede queda activada.
- Requisitos críticos: atomicidad por línea, snapshot inmutable, idempotencia y ausencia de doble escritura entre lotes y `stock_actual`.
- A3.4 y B1 permanecen pendientes. Esta activación solo modifica documentación.


## 2026-10-06 — A3.3: motor neutral y aplicación transaccional completada

- Estado: **COMPLETADA**; A3.4 no fue activada.
- Preflight: fast-forward a `origin/master`; repositorio `leoalejoleo1537/llamita-plus`; Supabase `llamita-plus` (`iuryhsjucblmebdogewa`).
- Firmas verificadas con `pg_get_functiondef`: `cuenta_cobrar(bigint,text,text,text,numeric,jsonb,jsonb)`, `cuenta_cerrar(bigint,text)`, `descontar_lotes(bigint,numeric)`, `descontar_con_reposicion(text,bigint,numeric)` y `sync_stock_desde_lotes()`. FIFO real: `trg_sync_stock_lotes` recalcula `productos.stock_actual` desde `producto_lotes`.
- Migraciones aplicadas: `a3_3_motor_neutral_lama_stock` y `a3_3_fulfillment_rules`.
- Corrección de captura: `ocurrido_at = cuentas.cerrada_at`; `cuenta_items.agregado_at` se conserva en `metadata`; mesa Lama usa `fulfillment = serve`.
- Motor: `lama_stock_aplicar_evento(uuid)`, solo snapshot de receta; aplicaciones por ingrediente con delta negativo, lote FIFO elegido, estado, clave idempotente y error. `siempre/servir/llevar` se traduce según `serve/takeaway`.
- Pruebas revertidas: modo prueba sin stock; real por `cuenta_cerrar`; sin lotes; FIFO; doble ejecución/reintento; timeout equivalente; error intermedio; insuficiencia según funciones instaladas; sin receta; receta modificada después de capturar; receta simple/múltiple.
- Atomicidad: el error forzado en el segundo ingrediente dejó cero aplicaciones aplicadas y conservó marcadores `error`; la cuenta/caja no se alteró.
- Seguridad: helper sin `EXECUTE` para `public`, `anon`, `authenticated` ni `service_role`; tablas A3 con RLS y sin grants directos al navegador. Advisors revisados: los avisos encontrados son preexistentes o el aviso esperado de RLS sin políticas en tablas internas.
- Integridad final: `lama_stock_config`, eventos, aplicaciones y capturas: 0; productos: 1.437; suma `stock_actual`: 15.438. Ningún stock persistente cambió y no se accedió a Café del Desierto/Llamita Stock.
- Rollback: `sql/2026-10-a3-3-motor-neutral-lama-stock.rollback.sql`.


## 2026-10-06 — A3.4a: observabilidad y reproceso seguro completada

- Estado: **COMPLETADA**; A3.4b permanece pendiente y no fue activada.
- Preflight: repositorio `leoalejoleo1537/llamita-plus`, rama `work` sincronizada con `origin/master`; Supabase `llamita-plus` (`iuryhsjucblmebdogewa`) activo. Se revisaron cola, bitácora, contrato A2 y plan vigente.
- Migración aplicada: `a3_4a_observabilidad_reproceso`.
- Observabilidad: vista interna `lama_stock_eventos_observabilidad` para consultar `pendiente`, `aplicado`, `error` y `sin_receta`, incluyendo diagnóstico y conteo de aplicaciones. `security_invoker` y sin SELECT para roles públicos.
- Reproceso: `lama_stock_reintentar_evento(uuid)` solo permite eventos `error` con `modo_efectivo = prueba`; usa el `event_id` y las claves A3.3. Eventos `sin_receta` y eventos `real` son rechazados.
- Seguridad: helper sin EXECUTE para `public`, `anon`, `authenticated` ni `service_role`; no se creó una RPC pública ni permisos de mutación.
- Pruebas revertidas: estados consultables, reproceso exitoso, doble reproceso idempotente, `sin_receta`, rechazo de modo real, permisos y suma de stock sin cambios.
- Integridad final: `lama_stock_config`, eventos y aplicaciones: 0; productos: 1.437; suma `stock_actual`: 15.438. No se modificaron cierres, ventas, Fudo, áreas ni Café del Desierto/Llamita Stock.
- Rollback: `sql/2026-10-a3-4a-observabilidad-reproceso.rollback.sql`.
