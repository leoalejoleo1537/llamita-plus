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

## 2026-10-06 — A3.4b: prueba sintética E2E Lama–Stock completada

- Estado: **COMPLETADA**; A3.4c queda pendiente y no fue activada.
- Repositorio confirmado: `leoalejoleo1537/llamita-plus`, proyecto Supabase `llamita-plus` (`iuryhsjucblmebdogewa`).
- No se modificó código de aplicación ni se aplicó una migración. La prueba se ejecutó exclusivamente dentro de `BEGIN ... ROLLBACK` usando productos, receta, cuenta, líneas, mesa, trigger y función temporales.
- Flujo verificado: `cuenta_agregar`, `cuenta_confirmar`, `cuenta_cerrar`, captura protegida, snapshot de receta, procesamiento `prueba`, aplicaciones por ingrediente, idempotencia, reintento y error intermedio.
- La receta temporal de dos ingredientes produjo dos aplicaciones esperadas con delta total `-6` para una línea de cantidad `2`. Cambiar la receta viva después de capturar no cambió el snapshot.
- Se forzó un error en el segundo ingrediente. La cuenta quedó `cerrada` y conservó total comercial `250`; el evento quedó `error` y no dejó aplicaciones parcialmente aplicadas. El reintento pasó a `prueba`; un segundo reintento no duplicó aplicaciones. Un fallo del motor de stock no impidió cerrar la mesa ni registrar sus datos comerciales.
- Conteos antes y después: cuentas `59`, líneas `88`, recetas `396`, ítems de receta `514`, productos `1437`, suma `productos.stock_actual` `15438.00`, comandas persistentes `50`; `lama_stock_config`, eventos, aplicaciones y capturas `0` en ambos cortes.
- Todos los artefactos sintéticos se revirtieron. No se activó modo real, no cambió stock persistente y no se accedió a Café del Desierto/Llamita Stock.
- Evidencia: `docs/hermes/11-pruebas-a3-4b.md`.

## 2026-10-06 — A3.4c: prueba controlada Lama en modo prueba completada

- Estado: **COMPLETADA**; A3.4d queda pendiente y no fue activada.
- Proyecto verificado: Supabase `llamita-plus` (`iuryhsjucblmebdogewa`). Repositorio: `leoalejoleo1537/llamita-plus`.
- Se ejecutó una única transacción `BEGIN ... ROLLBACK` con sede, mesa, cuenta, productos y receta sintéticos. Se reprodujo el camino que usa Lama mediante `cuenta_agregar`, `cuenta_confirmar` y `cuenta_cerrar`.
- IDs observados dentro de la transacción: cuenta `990301`; evento `646d4cb3-5124-4410-ab40-4dbd89a68b6c`; aplicaciones `2a419ca9-56bf-49b8-8bea-71645f3f10dd` y `a9bea2ef-19c9-4f25-82c8-07f4b49fa33d`.
- El evento quedó en modo/estado `prueba`; hubo dos aplicaciones por ingrediente. Dos ejecuciones posteriores de `lama_stock_aplicar_evento` devolvieron las mismas dos aplicaciones y no generaron duplicados.
- La cuenta quedó `cerrada`, el stock sintético permaneció en `10` por producto y el modo real nunca se habilitó.
- Conteos pre/post: cuentas 59, líneas 88, productos 1437, recetas 396, ítems de receta 514, comandas 50, suma de stock 15438; configuración, eventos, aplicaciones y capturas 0 tras el rollback.
- Los IDs son efímeros y fueron revertidos. No se usaron ventas reales, no se tocó Fudo, no se implementaron áreas y no se accedió a Café del Desierto/Llamita Stock.
- Procedimiento manual: `docs/hermes/12-prueba-manual-a3-4c.md`.


## 2026-10-07 — Bloque 0: auditoría de áreas, sedes y Bodega

- Estado: **COMPLETADO — solo lectura y documentación**. B1 queda pendiente y no activa.
- Repositorio: `leoalejoleo1537/llamita-plus`, remoto correcto, rama local `work`. Proyecto confirmado por metadatos: Supabase `llamita-plus` (`iuryhsjucblmebdogewa`, PostgreSQL 17.6).
- Archivo nuevo: `docs/hermes/13-auditoria-areas-sedes-bodega.md`. Se actualizaron `01-plan-areas-operativas.md`, `03-cola-de-trabajo-codex.md`, `05-decisiones-pendientes.md` y este canal/bitácora.
- Hechos clave: 1,437 productos en cuatro claves de sede (`plaza`, `angamos`, `central`, `bodega`) y stock agregado 15,438.00; Bodega activa es `central`; `bodega` queda como conjunto histórico. No hay tabla de inventario por área. Las áreas de `lama_areas` pertenecen al plano de mesas. Lotes no tienen ubicación y su suma coincide con el agregado actual por producto.
- Se documentaron rutas de escritura, trigger de lotes, Fudo/Lama, recepción/repartos, mermas, mínimos/máximos, RLS/permisos, opción arquitectónica, conciliación, archivo de Local 2, Bodega y clonación futura.
- Consultas/verificaciones: `git status`, `git remote -v`, `git branch --show-current`, lecturas `rg`/`sed`, metadatos Supabase, listado de tablas, `SELECT`, `information_schema` y `pg_catalog`; no se llamó RPC ni función de escritura.
- Verificaciones: `git diff --check` satisfactorio. No se ejecutaron pruebas de aplicación: no hubo cambios de código.
- Cambios de aplicación, esquema y datos: **ninguno**. Sin SQL de escritura, migración o inserción/actualización/borrado. No se accedió a Café del Desierto / Llamita Stock.
- Riesgos/decisiones pendientes: fuente única y corte coordinado de escritores; seguridad por sede/área; ubicación temporal sin asignar; transferencia Bodega→área atómica con lote; compatibilidad de proyección.
- Publicación autorizada: exclusivamente documentación de Bloque 0 a `master`, después de revisión de diff y `git diff --check`.

## 2026-10-06 — B1: administración segura de sedes y nodos

- Estado: **COMPLETADA**. Se ejecutó solo B1; B2 (áreas y stock por área) permanece pendiente y no activa.
- Repositorio confirmado: `leoalejoleo1537/llamita-plus`, remoto oficial `origin`; la rama local es `work`, el destino solicitado es `master`.
- Proyecto Supabase confirmado antes de escribir: `llamita-plus`, ref `iuryhsjucblmebdogewa`, `ACTIVE_HEALTHY`. No se accedió a Café del Desierto / Llamita Stock.
- Migración aplicada: `b1_sede_registro` (`sql/2026-10-b1-registro-sedes.sql`). Se creó `public.sede_registro`, con clave estable, nombre visible, tipo y estado. RLS activado; clientes `anon` y `authenticated` solo tienen SELECT. INSERT/UPDATE/DELETE directos y EXECUTE del trigger interno se comprobaron revocados.
- Resultado: `plaza` Local 1 activa; `angamos` Local 2 archivada; `central` Bodega activa/logística; `bodega` histórica separada y archivada. La app oculta y rechaza Local 2; Bodega conserva sus rutas y destinos nuevos a Local 1. No se creó CRUD en Ajustes porque los permisos globales existentes no son una autorización segura para ese cambio.
- Conteos antes/después idénticos: productos 1,437; stock agregado 15,438.00; movimientos 431; repartos 361; líneas 2,040; lotes 42; permisos globales 9. `angamos`: 351 productos, 2,764.20 stock, 3 movimientos, 168 repartos, 533 líneas, 19 lotes (suma de lotes 134), historial 4,717, historial automático 13,062. `central`: 349 productos, 4,750.50 stock. Clave histórica `bodega`: 408 productos, 3,357.10 stock. No cambió ningún dato operativo.
- Pruebas: `npm test` pasó; `node pruebas/sedes-seguras.mjs` pasó; sintaxis JavaScript embebido válida; `git diff --check` pasó. Casos visuales de navegador se omitieron porque no hay navegador instalado.
- Advisors: no hay nuevo aviso para `sede_registro`; siguen seis tablas preexistentes RLS sin política, tres vistas SECURITY DEFINER, diez funciones con search_path mutable y avisos sobre funciones SECURITY DEFINER heredadas. Alertas de rendimiento existentes no apuntan a la tabla nueva.
- Riesgo pendiente: las guardas impiden entrar accidentalmente por la interfaz, pero no aíslan ni bloquean escrituras API/RPC directas sobre filas históricas de `angamos`; las políticas operativas heredadas siguen siendo permisivas. `app_permisos` no tiene permisos por sede.
- Archivos: `index.html`, `pruebas/sedes-seguras.mjs`, `sql/2026-10-b1-registro-sedes.sql`, `sql/2026-10-b1-registro-sedes.rollback.sql`, `docs/hermes/01-plan-areas-operativas.md`, `docs/hermes/03-cola-de-trabajo-codex.md`, `docs/hermes/06-canal-hermes-codex.md` y `docs/hermes/14-b1-registro-sedes-resultados.md`.
- Publicación: commit `36d71a3` enviado a `master` con `git push origin HEAD:master`; push verificado contra `origin/master`.

## 2026-10-07 — B2.1: cimientos del modelo de áreas operativas

- Estado: **COMPLETADA**. B2.2 permanece pendiente y no se activó.
- Repositorio confirmado: `leoalejoleo1537/llamita-plus`, remoto `origin`; rama `work` al día con `origin/master`. Supabase confirmado por metadatos: `llamita-plus`, ref `iuryhsjucblmebdogewa`, `ACTIVE_HEALTHY`.
- Migraciones aplicadas: `b2_1_cimientos_areas_operativas`, `b2_1_indices_fk_producto_area` (cobertura de FK nuevas) y `b2_1_comentario_relacion_area` (descripción alineada con la unicidad por producto/sede).
- Tablas: `areas_operativas` con sede/código estable/nombre/estado/orden/fechas; `producto_area_asignacion` con sede/producto/área/estado/origen/regla/fechas, sin columna de cantidad. RLS activo, sin políticas ni permisos de tabla abiertos. No se otorgó acceso directo a `anon`, `authenticated` ni `service_role`.
- Áreas creadas solo en `plaza`: Cocina fría, Cocina caliente, Barra y Cafetería. Asignaciones persistidas: 0.
- Conciliación SELECT-only: 329 productos únicos de `plaza`; Barra 18/108,00; Cafetería 42/536,50; Cocina caliente 19/204,00; Cocina fría 17/17,50; Sin asignar 233/3.700,20. Cada producto aparece una vez y el total hipotético 4.566,20 reconcilia con stock actual de `plaza`. No se guardaron estas asignaciones.
- Conteos pre/post idénticos: productos 1.437; stock total 15.438,00; productos plaza 329; stock plaza 4.566,20; movimientos 431; repartos 361; líneas 2.040; lotes 42; recetas 396; ítems de receta 514; permisos 9; `lama_areas` 5. Las tablas nuevas no contienen saldos.
- Pruebas: `sql/2026-10-b2-1-pruebas-estructura.sql`, ejecutado transaccionalmente y revertido; validó áreas/sede, restricciones, trigger, unicidad, RLS, ausencia de grants/políticas y columnas de saldo. Advisor: sin FK desindexadas nuevas después de la corrección; quedan avisos intencionales de RLS sin políticas e índices aún no usados en una tabla vacía. `git diff --check` y revisión del diff al cierre.
- Archivos SQL: migración y rollback `sql/2026-10-b2-1-cimientos-areas-operativas[.rollback].sql`; conciliación `sql/2026-10-b2-1-simulacion-clasificacion.sql`; prueba `sql/2026-10-b2-1-pruebas-estructura.sql`. Resultado completo: `docs/hermes/15-b2-1-cimientos-areas.md`.
- Sin cambios en productos, stock, movimientos, repartos, lotes, recetas, permisos, `lama_areas`, `central`, `angamos` o `bodega`. No se accedió a Café del Desierto / Llamita Stock.
- Riesgo: clasificación por heurísticas descriptivas requiere revisión humana; la relación actual no modela distribución cuantitativa y no debe sumarse como stock. B2.2 debe decidir el destino de un producto repartido entre áreas, el corte de escritores y el control por sede.
- Rollback preparado, no ejecutado; aborta si hay asignaciones o catálogo distinto al estado inicial.

## 2026-10-07 — B2.2: auditoría de fuente única; requiere decisión

- Estado: **REQUIERE DECISIÓN**. B2.3 (interfaz y formularios) permanece pendiente y no se activó.
- Repositorio verificado: `leoalejoleo1537/llamita-plus`, remoto origin correcto, rama `work`, sincronizada con `origin/master` en `60e83c68a4fa24dff461576c6ccd30b00323ba7c`. Supabase verificado por metadatos: `llamita-plus`, ref `iuryhsjucblmebdogewa`, activo, PostgreSQL 17.6.
- Auditoría solo lectura: UI edita directamente `productos.stock_actual`, crea productos con saldo y reemplaza `producto_lotes`; el trigger `trg_sync_stock_lotes` recalcula el total. El catálogo instalado muestra escritores/delegados para mermas/reversa, entradas/reversa, repartos/reversa, Fudo, Lama, fusiones/reversa, restauraciones/reversa, franquicia y productos enlazados. Lectores, mínimos y máximos siguen usando saldo por producto.
- Modelo B2.1: las cuatro áreas existen solo para `plaza`; `producto_area_asignacion` tiene 0 filas, no almacena cantidad, su constraint solo permite estado asignado/sin asignar y hoy limita la relación a una fila por producto/sede. El lote carece de ubicación.
- Conteos inicio/cierre iguales: productos 1.437; stock total 15.438,00; plaza 329/4.566,20; movimientos 431/25; lotes 42/9; repartos 361/148 destino plaza; recetas 396/195. Asignaciones por área 0. Productos de plaza con lotes: 6, lotes suman 36,00 y no difieren de `stock_actual`.
- Decisión: no poblar saldos por área mientras continúen los escritores y la interfaz sobre `stock_actual`; eso crearía doble fuente editable. Recomendar ledger por ubicación como autoridad de `plaza` con agregado global de compatibilidad solo de lectura tras corte coordinado. Hace falta resolver adaptación de escritores/permisos, lotes por área y confirmación de la simulación como ubicación física.
- No hubo migración ni rollback SQL, RPC de escritura, cambios de código, SQL mutacional o cambios de datos. No se tocó `central`, `angamos`, `bodega` histórica ni áreas operativas. No se accedió a Café del Desierto / Llamita Stock.
- Informe: `docs/hermes/16-b2-2-auditoria-fuente-unica-stock.md`. `git diff --check` debe pasar antes de publicar documentación. B2.3 sigue pendiente.
