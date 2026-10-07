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

## 2026-10-07 — S2: verificación de seguridad y regresión

- Estado: **REQUIERE DECISIÓN**. No se halló escalamiento en las rutas probadas, pero faltó evidencia con sesiones GoTrue reales de ambas cuentas.
- Data API anónima rechazó SELECT, INSERT, UPDATE, cambio de `auth_uid`, DELETE y las RPC administrativas. TRUNCATE está revocado para los tres roles API.
- Pruebas `BEGIN ... ROLLBACK`: raíz, administrador operativo, usuario común, auditoría inmutable, RLS propia, DML denegado, `stock_transferir`, áreas, Bodega y lectura Fudo pasaron.
- Las RPC S1 conservan `SECURITY DEFINER`, `search_path=''`, nombres calificados, comprobación de `auth.uid()` y ACL correcta. No hay políticas abiertas nuevas en `app_permisos`.
- `npm test` pasó; Chromium no está instalado. Advisors conservan los hallazgos globales heredados de S0, fuera de S2.
- Conteos post prueba iguales: 1.437 productos, stock 15.438, 431 movimientos, 42 lotes, 59 cuentas, 30 pagos, caja 2, Lama–Stock 0, Fudo 15.357, auditorías 0 y transferencias 0.
- No hubo migraciones, código funcional, cambios persistentes, llamadas a Fudo remoto ni acceso a Café del Desierto. Informe 26 y plan 27.

## 2026-10-07 — S1: identidad raíz y gobierno seguro de permisos

- Estado: **COMPLETADA**. Alejo confirmó el UUID raíz exacto; Supabase verificó que existe, está confirmado y no es anónimo.
- Migraciones aplicadas solo en `llamita-plus` (`iuryhsjucblmebdogewa`): identidad/gobierno de permisos e índices FK de auditoría.
- `authz_internal` contiene singleton raíz, auditoría inmutable y foto privada pre-S1. `app_permisos` queda vinculada por `auth_uid`; dos cuentas vinculadas y siete filas históricas inertes.
- Segunda cuenta: editar/Fudo/Ajustes habilitados, Lama apagado y cero bloqueos Fudo; conserva administración operativa, sin gobierno de permisos.
- Seguridad: anon sin lectura; authenticated solo su fila por RLS; service role conserva SELECT; los tres carecen de DML. RPC raíz con `SECURITY DEFINER`, `search_path=''`, `auth.uid()` y ACL explícita.
- Interfaz: carga propia por RPC; panel de personas y permisos individuales Fudo exclusivo del propietario raíz. No se crean usuarios Auth desde la app.
- Compatibilidad: `stock_transferir` conserva firmas y motor; consulta capacidad efectiva por UUID. La Edge que lee permisos conserva SELECT. Sin despliegue ni invocación Fudo.
- Pruebas transaccionales por cinco roles, degradación raíz, auditoría, Data API, transferencia y Edge-read pasaron. `npm test` pasó; navegador omitido por falta de Chromium.
- Conteos operativos pre/post idénticos: productos 1.437, stock 15.438,00, movimientos 431, lotes 42, cuentas 59, pagos 30, caja 2, Lama–Stock 0 y Fudo movimientos 15.357.
- Informe: `docs/hermes/25-s1-identidad-raiz-gobierno-permisos.md`. Fases posteriores de seguridad quedan pendientes y no activadas.

## 2026-10-07 — S0: auditoría integral de seguridad y permisos

- Estado: **REQUIERE DECISIÓN**. El mapa técnico está completo para diseñar S1, pero no existe una identidad verificable de propietario raíz.
- Entorno: repositorio `leoalejoleo1537/llamita-plus`, rama `work`, sincronizado con `origin/master`; Supabase `llamita-plus` ref `iuryhsjucblmebdogewa`, `ACTIVE_HEALTHY`, PostgreSQL 17.6.1.166.
- Identidad anonimizada: 2 usuarios Auth confirmados, 0 anónimos; 9 filas de `app_permisos`, 2 coincidentes por correo y 7 sin usuario Auth actual. Ambas cuentas reales tienen capacidades administrativas. No hay UID/FK/propietario ni rol seguro en app metadata.
- Hallazgos: lectura anónima y autoedición de `app_permisos`; 36 tablas `public` con políticas abiertas `ALL`; 40 funciones `SECURITY DEFINER` ejecutables por anon, 36 con escritura y ninguna de esas 40 con chequeo de sesión; Lama, caja, Ajustes, recetas y logística dependen principalmente de controles del cliente.
- Controles que sí existen: `stock_internal` cerrado; áreas/asignaciones cerradas; puente Lama–Stock sin acceso de navegador; triggers de corte protegen stock/lotes/escritores legacy para `central/plaza`; POS en `ninguno`, Fudo prueba/cron apagado y Lama real apagado.
- Edge: se leyeron metadatos y fuentes de las seis funciones desplegadas sin invocarlas. Todas tienen JWT y guard de origen POS; varias no exigen capacidad de usuario confiable y usan service role únicamente en servidor.
- Advisors: 40 funciones definer anónimas, 3 vistas definer, 10 funciones con search path mutable, 8 tablas RLS sin política y protección de contraseñas filtradas desactivada.
- Trabajo ejecutado: consultas SELECT/catálogos, advisors, lectura de código y documentación. Sin migraciones, DML, RPC operativos, Edge invocadas, cambios de código funcional, RLS, grants, usuarios, datos o configuración.
- Informe: `docs/hermes/24-auditoria-integral-seguridad-permisos.md`. S1 no activa; B3.2a continúa requiere decisión y B3.2b pendiente.
- Decisión: Alejo debe designar privadamente cuál cuenta Auth es el `propietario_raiz` y aprobar el procedimiento de recuperación.
- No se accedió a Café del Desierto / Llamita Stock.

## 2026-10-07 — B3.2a: bloqueo de autorización documentado

- Estado: **REQUIERE DECISIÓN**. Alejo activó B3.2a; la ejecución se detuvo antes de modificar código o base de datos al comprobar que `app_permisos.puede_ajustes` no es una fuente confiable con las políticas instaladas.
- Repositorio: `leoalejoleo1537/llamita-plus`, rama `work`, remoto `origin` oficial. Supabase verificado: `llamita-plus`, ref `iuryhsjucblmebdogewa`, estado `ACTIVE_HEALTHY`, PostgreSQL 17.6.1.166.
- Evidencia de solo lectura: políticas de `public.app_permisos`: `INSERT authenticated WITH CHECK true`; `UPDATE authenticated USING true WITH CHECK true`; y `UPDATE anon,authenticated USING true WITH CHECK true`. Grants directos amplios para anon y authenticated incluyen INSERT, UPDATE, DELETE y TRUNCATE. La tabla contiene 9 filas, 6 con `puede_ajustes=true`; estos valores no prueban quién está autorizado mientras las políticas permitan que el cliente los cambie.
- Resultado: no se agregaron secciones de Ajustes, edición de área, asignación preferida ni creación por área. No se aplicó SQL/migración, no se cambió permiso alguno ni se insertaron datos sintéticos. Sin cambios en productos, stock, lotes, movimientos, transferencias, recetas o datos comerciales.
- Decisión solicitada: definir/autorizar un endurecimiento de la administración de `app_permisos` que tenga bootstrap confiable y permita proteger sus escrituras mediante backend, o designar otra fuente de autorización confiable. La propuesta y sus límites están en `docs/hermes/23-b3-2a-bloqueo-autorizacion.md`.
- B3.2b permanece **PENDIENTE**, no activa. No se accedió a Café del Desierto / Llamita Stock.
- Verificación documental: `git diff --check` pasó. No se ejecutaron pruebas de aplicación/DB porque no hubo implementación ni cambios de esquema.
- Publicación de documentación del bloqueo: autorizada a `master` por la solicitud original; commit pendiente.

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

## 2026-10-07 — Decisión aprobada: libro de existencias por ubicación

- Alejo aprobó la arquitectura del inventario por ubicación documentada en `docs/hermes/17-decision-libro-existencias-ubicacion.md`.
- B2.2 queda **REQUIERE DECISIÓN RESUELTA** como fase de decisión; no queda implementada la fuente de stock. No se activó B2.3.
- Fuente futura única: libro por producto, sede, ubicación y lote cuando aplique. `productos.stock_actual` será una proyección de compatibilidad no editable.
- La migración inicial futura llevará todo `central` a Bodega central; todo `plaza` y sus lotes a Sin asignar; no migrará `angamos` ni la clave histórica `bodega`. No habrá clasificación histórica automática.
- Operación aprobada: nuevos productos físicos entran primero a Bodega; el reparto elige área y mueve stock atómicamente conservando producto, cantidad, usuario, fecha y lote; la merma global indica área; búsqueda, críticos y reportes calculan por área. Recetas y Lama–Stock real permanecen desactivados hasta que el modelo esté funcionando.
- Alcance de esta ejecución: actualizar documentación Hermes únicamente. Sin SQL, tablas, migraciones, código, operaciones ni cambios de datos. Café del Desierto / Llamita Stock no fue tocado.
- B2.3 (interfaz/formularios sobre el modelo implementado) queda **PENDIENTE**, no activado. El plan y el documento 17 describen sus precondiciones y criterios.

## 2026-10-07 — B2.3: corte del libro por ubicación detenido

- Estado: **REQUIERE DECISIÓN**; B2.4 queda **PENDIENTE**, no activada.
- Entorno: repositorio `leoalejoleo1537/llamita-plus`, remoto origin esperado, rama `work`, HEAD igual a `origin/master` al inicio (`aaa428fe05d81191dcf58976e515518a688e6fe2`). Supabase `llamita-plus`, ref `iuryhsjucblmebdogewa`, `ACTIVE_HEALTHY`, PostgreSQL 17.6.
- B2.3 se detuvo antes de cualquier cambio de base de datos/código: `productos.stock_actual` y `producto_lotes` conservan escritores de la interfaz, DML directo vía Data API con políticas/grants permisivos, un trigger de lotes que reescribe el agregado, RPC de inventario y rutas heredadas de Fudo y Lama. No se puede declarar que el saldo antiguo esté cortado ni bloquearlo con seguridad sin diseñar el alcance por sede y preservar operaciones relacionadas.
- Conteos SELECT de inicio/cierre: productos 1.437, stock global 15.438,00; `central` 349 / 4.750,50; `plaza` 329 / 4.566,20. Lotes: `central` 2 / 96,00, un producto con lotes y cero diferencias; `plaza` 9 / 36,00, seis productos con lotes y cero diferencias. Los lotes no se suman otra vez al stock.
- Otros conteos: movimientos 431 (403 central, 25 plaza), repartos 361, recetas 396, líneas de receta 514, permisos 9, asignaciones preparatorias producto-área 0, `lama_areas` 5. Sin escrituras no hay pre/post de migración; conteos inicio/cierre iguales. `angamos` y clave histórica `bodega` no se migraron.
- `productos.stock_actual` continúa como fuente editable vigente, no como proyección. No se crearon libro, ubicaciones con saldo ni distribución hacia áreas. No cambió lotes, producto, movimientos, repartos, recetas, permisos, Fudo ni Lama.
- Evidencia y matriz de bloqueos: `docs/hermes/18-b2-3-bloqueo-corte-libro-ubicaciones.md`. El documento 17 y plan 01 aclaran que la interfaz de áreas queda para UX posterior; B2.3 es el corte del libro.
- Consultas SELECT-only y catálogo de políticas, grants, funciones y trigger; no se probaron escrituras ni migraciones por ser inseguro y no existir implementación. `git diff --check` se ejecuta antes de publicar documentación.
- Sin cambios en Café del Desierto / Llamita Stock. B2.4 queda pendiente y no se activa automáticamente.

## 2026-10-07 — B2.3: corte coordinado y libro por ubicación completados

- Estado: **COMPLETADA** para `central` y `plaza`; B2.4 permanece **PENDIENTE**, no activa. El bloqueo del primer intento documentado arriba y en el informe 18 quedó resuelto por autorización explícita posterior de Alejo.
- Entorno: repositorio `leoalejoleo1537/llamita-plus`, remoto oficial; rama de trabajo `work`. Proyecto Supabase Llamita Plus `iuryhsjucblmebdogewa`, confirmado antes de aplicar cambios.
- Migraciones instaladas: `20261007152558 b2_3_libro_existencias_corte`; `20261007152805 b2_3_indices_permisos_libro`.
- Modelo: esquema privado `stock_internal`; catálogo `ubicaciones`; libro inmutable `movimientos`; `aperturas`; `transferencias`; `permiso_proyeccion`; vista `existencias`. RLS y políticas restrictivas de denegación; sin permisos directos a roles de aplicación.
- Apertura: 150 productos de `central` a Bodega central = 4.750,50; 258 de `plaza` a Sin asignar = 4.566,20. Libro: 408 aperturas/9.316,70. No hubo clasificación histórica y las cuatro ubicaciones físicas de `plaza` quedaron con saldo cero.
- Conteos pre/post: productos 1.437; stock total 15.438,00; `central` 349/4.750,50; `plaza` 329/4.566,20; `angamos` 351/2.764,20; `bodega` histórica 408/3.357,10; lotes 42/304,00; movimientos legacy 431; repartos/líneas 361/2.040; recetas/líneas 396/514; permisos 9; `lama_stock_config` 0. Todos iguales. Conciliación por producto/sede sin diferencias.
- Escritores: saldo directo, altas con saldo, lotes, trigger histórico de lotes y rutas legacy de movimientos, entradas, mermas, repartos/deshacer, restauraciones y fusiones bloqueados para `central`/`plaza`. `productos.stock_actual` queda como proyección protegida y se refresca solo con permiso interno transaccional. Otras sedes mantienen compatibilidad.
- Fudo: guardas añadidas a cinco fuentes Edge, que **no fueron desplegadas**; triggers bloquean modo real y aplicación en base. Ningún cambio remoto de Fudo. Plaza sigue en modo prueba y cron apagado. Lama real sigue apagado; configuración vacía.
- Pruebas: SQL sintético `BEGIN ... ROLLBACK` validó conciliación, lote sin doble suma, permisos, writers bloqueados, configuraciones reales bloqueadas, transferencia Bodega -12/Cafetería +12 con producto lógico/lote/referencia comunes, total conservado e idempotencia. Post-rollback no quedaron aplicaciones ni transferencias sintéticas. `npm test` exit 0; análisis esbuild de cinco fuentes Edge exit 0; `git diff --check` pasó. Pruebas visuales omitidas por ausencia de navegador.
- Seguridad/rendimiento: advisor ya no marca `stock_internal` como RLS sin política; se agregaron índices de FK faltantes. Permanecen avisos previos de vistas/tablas ajenas y avisos de índices nuevos aún no usados.
- Rollback técnico `sql/2026-10-b2-3-libro-existencias.rollback.sql`: aborta si hay operaciones posteriores; luego solo compensación auditada, sin borrar movimientos.
- Resultado detallado: `docs/hermes/19-b2-3-corte-libro-ubicaciones.md`. No se tocó Café del Desierto / Llamita Stock; no se cambió ningún stock persistente previo ni datos comerciales. B2.4 no se activó.

## 2026-10-07 — B2.3.1: blindaje de origen POS por sede

- Estado: **COMPLETADA**. B2.4 continúa **PENDIENTE**, no activa. Entorno confirmado: repositorio oficial `leoalejoleo1537/llamita-plus`, proyecto Supabase `llamita-plus` (`iuryhsjucblmebdogewa`).
- Configuración previa verificada: `fudo_sync` solo tenía modo/cursor, `lama_stock_config` modo Lama y `ajustes` flags booleanos. Se creó `stock_internal.origen_pos`, una fila por sede con origen restringido. `plaza`, `central`, `angamos` y `bodega` quedaron `ninguno`.
- Migración aplicada `20261007162948 b2_3_1_pos_origin_guard`; fuente local `supabase/migrations/20261007162700_b2_3_1_pos_origin_guard.sql`.
- Backend: `public.stock_pos_origen_permitido` solo ejecutable por `service_role`; tabla interna sin grants; `fudo_procesar_item` cerrado a roles de navegador y protegido por origen; triggers bloquean DML de Fudo y real de Lama cuando el proveedor no coincide. La definición instalada del motor Lama exige origen Lama antes de aplicación real, además del bloqueo de modo actual.
- Edge desplegadas `ACTIVE`, v1, `verify_jwt=true`, marker `2026-10-07-b2.3.1`: ciclo, sync ventas, empujar stock, deshacer, sumar y probar escritura. Se recuperaron las seis fuentes desplegadas y se confirmó guard + marker. Invocación sin JWT devuelve 401.
- Pruebas transaccionales: estado `ninguno/prueba`, segundo POS duplicado, central/archivadas/histórica, RPC/Fudo DML, Lama real, ACL/RLS y helper bajo `SET LOCAL ROLE service_role`. Sin escrituras persistentes.
- Estado post: orígenes ninguno (4 filas); `plaza fudo_sync` prueba/cron false; Lama config 0; productos 1.437/stock 15.438; movimientos 431; fudo_movimientos 15.357. Fudo remoto no fue consultado ni modificado.
- `npm test`, esbuild, `git diff --check` y advisors ejecutados. Sin nuevos findings asociados a la configuración; avisos previos ajenos persisten. `docs/hermes/20-b2-3-1-blindaje-origen-pos.md` describe despliegues, permisos, pruebas y riesgos.
- No hay selector de Ajustes. Futuro endpoint debe verificar `app_permisos.puede_ajustes`; no se otorgó escritura a navegador/`service_role`. No se activó Fudo/Lama real, Toteat ni B2.4. No se accedió a Café del Desierto / Llamita Stock.

## 2026-10-07 — B2.4: motor seguro de transferencias entre ubicaciones

- Estado: **COMPLETADA**. B3 —interfaz de áreas— queda **PENDIENTE**, no activada. Se ejecutó solo en `leoalejoleo1537/llamita-plus`, Supabase `llamita-plus` ref `iuryhsjucblmebdogewa`. No se accedió a Café del Desierto / Llamita Stock.
- Migraciones verificadas en el historial remoto: `20261007165310 b2_4_transferencias_ubicaciones_seguras`, `20261007165656 b2_4_index_lote_continuidad_transferencia`, `20261007165826 b2_4_secure_transfer_entrypoint`.
- Motor: `stock_internal.transferencias` + pares de `stock_internal.movimientos` inmutables y balanceados. `public.stock_transferir` es `SECURITY INVOKER`; exige JWT autenticado, UID/email coincidentes y `app_permisos.puede_editar`. El helper privado repite validación y el núcleo queda reservado al propietario. No hay DML directo de tablas para `anon`, `authenticated` ni `service_role`.
- Rutas admitidas: Bodega central→área activa plaza con `producto_enlace` real factor 1; Sin asignar→área; área→área con mismo producto. No se comparan nombres ni se crean enlaces. Una referencia UUID serializa la llamada; payload repetido idéntico retorna resultado existente y payload diferente falla. Un constraint trigger diferido valida el par completo.
- Lotes: se conserva el ID canónico de `producto_lotes` y vencimiento en `stock_internal.lote_continuidad`, asociado al producto destino; no se crea lote de origen ficticio. Detalle legado sin lote solo puede reclasificarse si el saldo agregado alcanza para cubrirlo, mediante movimientos balanceados en la misma transacción.
- Pruebas ejecutadas desde `sql/2026-10-b2-4-pruebas-transferencias.sql`, todas dentro de `BEGIN ... ROLLBACK`: Bodega→Cafetería, Sin asignar→Barra, área→área, lote y sin lote, saldo insuficiente, producto sin enlace, repetición idempotente, fallo forzado entre movimientos, permiso insuficiente, llamada de usuario authenticated, ACL/RLS, par diferido y suma/no-negatividad. Sin Fudo remoto ni Lama real.
- Conteos post rollback: productos 1.437; `stock_actual` global 15.438,00; lotes 42; neto del libro 9.316,70; transferencias persistentes 0; continuidad nueva 0; clasificaciones persistentes 0; movimientos de transferencia persistentes 0; `fudo_movimientos` 15.357; movimientos legacy 431; configuraciones Lama real 0. Total global conservado y `stock_actual` coincide con la proyección del libro.
- Aclaración de proyección: `productos.stock_actual` no se modifica directamente por el motor. El trigger contable actualiza su proyección; en transferencias entre productos maestros distintos, los agregados individuales origen/destino cambian en sentidos opuestos, pero la suma global se conserva.
- Reversa: rollback técnico `sql/2026-10-b2-4-transferencias-ubicaciones.rollback.sql` aborta si ya hay actividad B2.4. Tras actividad persistida solo procede reversa compensatoria auditada; el campo `reversa_de` prepara el vínculo, pero aún no existe endpoint de reversa.
- Riesgos: writers cotidianos legacy permanecen bloqueados por B2.3; aún no hay UI de transferencia ni acceso para usuarios sin `puede_editar`; lotes históricos con discrepancia respecto del saldo agregado quedan bloqueados para revisión. Los índices recién creados pueden aparecer como no usados en advisors hasta que haya volumen de transferencias.
- Resultado detallado: `docs/hermes/21-b2-4-motor-transferencias-ubicaciones.md`. Se ejecutó `git diff --check`; B3 no se activa automáticamente.
## 2026-10-07 — B3.1: interfaz de lectura y navegación por áreas

- Estado: **COMPLETADA**. B3.2 queda **PENDIENTE**, no activa.
- Entorno confirmado: `leoalejoleo1537/llamita-plus`, remoto oficial, rama `work`; Supabase Llamita Plus `iuryhsjucblmebdogewa`, `ACTIVE_HEALTHY`, PostgreSQL 17.6.1.166.
- Se añadieron a `plaza` portada con seis tarjetas, lista filtrada de la ubicación y vista global con cantidades separadas por producto/ubicación. Sin asignar se describe como stock inicial pendiente de distribución. Áreas físicas muestran saldo cero y “sin mínimos configurados”; no se inventan críticos. Bodega sigue con su renderer anterior.
- Lectura: `public.stock_leer_areas()` (SECURITY INVOKER; `EXECUTE` solo authenticated) y helper `stock_internal.leer_existencias_areas_plaza()` (SECURITY DEFINER, search_path vacío, sesión obligatoria). Las cifras salen de `stock_internal.existencias`; ninguna función lee `productos.stock_actual`. El helper mantiene productos inactivos si aún tienen saldo positivo.
- Migraciones aplicadas exclusivamente en Llamita Plus: `20261007174518 b3_1_lectura_inventario_areas`, `20261007174626 b3_1_include_inactive_stock_products`.
- Resultado autenticado y conciliado: Barra, Cafetería, Cocina caliente y Cocina fría 0/0,00; Sin asignar 255 productos con saldo / 4.566,20; total RPC = libro de plaza. Conteos SELECT: productos 1.437 (plaza 329), central 4.750,50, movimientos del libro 408, transferencias 0, lotes 42 y líneas de receta 514. Sin DML ni cambios en conteos/datos comerciales.
- Seguridad: anon no ejecuta funciones; authenticated ejecuta RPC/helper; service_role no ejecuta; ningún rol de aplicación probado tiene INSERT de movimientos y authenticated no actualiza ubicaciones. Consulta sin sesión rechazada. Advisors Supabase muestran hallazgos globales preexistentes, separados del RPC nuevo; quedan documentados para revisión fuera de este bloque.
- Verificación: SQL autenticado dentro de `BEGIN ... ROLLBACK`, conciliación, privilegios, `node pruebas/pantalla-sana.mjs`, `node --check pruebas/inventario-areas.mjs`, `npm test`, `git diff --check`. Chromium no está instalado: los checks visuales automatizados se omiten; el informe 22 contiene pasos manuales desktop/móvil y revisión de consola.
- Rollback: `sql/2026-10-b3-1-lectura-areas.rollback.sql` elimina solo ambas funciones de lectura. Sin filas/saldos nuevos que revertir.
- Informe: `docs/hermes/22-b3-1-lectura-areas.md`. B3.2 sigue sin activar. No se accedió a Café del Desierto / Llamita Stock.
- Publicación de aplicación y migraciones: commit `2a9c8c2` enviado a `origin/master`.
