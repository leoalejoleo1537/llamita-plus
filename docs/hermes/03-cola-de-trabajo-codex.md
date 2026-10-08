# Cola de trabajo de Codex

Estado actual: **S2 REQUIERE DECISIÓN (2026-10-07)**. Data API, grants, RLS, RPC, regresión y sesiones reales pasaron, pero la auditoría manual reportada no aparece en la tabla privada: conteo posterior 0. **B3.2a y B3.2b permanecen PENDIENTES**, no activas.

Este archivo se utiliza como una cola explícita. Codex debe leerlo antes de cada ejecución programada.

## Reglas de lectura

- Si no existe una tarea marcada como `ACTIVA`, no modificar código ni base de datos.
- Ejecutar únicamente la tarea marcada como `ACTIVA`.
- Respetar el alcance, archivos permitidos y criterios de salida de esa tarea.
- Al finalizar, actualizar `04-bitacora-codex.md` y cambiar la tarea a `COMPLETADA`, `BLOQUEADA` o `REQUIERE DECISIÓN`.
- No activar por cuenta propia la tarea siguiente.
- No ejecutar SQL ni migraciones salvo que la tarea lo autorice explícitamente.
- Leer `docs/hermes/06-canal-hermes-codex.md` antes de comenzar y responder allí el resultado arquitectónico.

## Plantilla de tarea

### Tarea [ID] — [nombre]

- Estado: `PENDIENTE` | `ACTIVA` | `COMPLETADA` | `BLOQUEADA` | `REQUIERE DECISIÓN`
- Autorización: [quién y cuándo la aprobó]
- Objetivo:
- Contexto y documentos que leer:
- Alcance permitido:
- Fuera de alcance:
- Archivos o migraciones esperadas:
- Criterios de aceptación:
- Pruebas requeridas:
- Publicación: [sin push | push a master autorizado]
- Riesgos conocidos:

### Tarea S0 — Auditoría integral de seguridad y permisos

- Estado: **COMPLETADA (2026-10-07)**. La decisión de identidad quedó resuelta y S1 se ejecutó por autorización posterior.
- Autorización: Alejo activó S0 y ordenó no implementar correcciones todavía.
- Resultado: `docs/hermes/24-auditoria-integral-seguridad-permisos.md`.
- Identidad: dos usuarios Auth confirmados coinciden por correo con filas administrativas, pero `app_permisos` no tiene `auth.uid()`, clave foránea ni propietario. No existe metadata segura que permita identificar cuál es Alejo; se requiere designación privada de `propietario_raiz`.
- Hallazgos críticos: `app_permisos` es legible por anon y autoeditable; 36 tablas operativas tienen políticas `ALL true` para anon/auth; 40 funciones `SECURITY DEFINER` son ejecutables por anon, 36 con rutas de escritura y sin validación de sesión; Lama/caja y configuración quedan protegidos solo por UI.
- Contención existente: ledger `stock_internal`, áreas/asignaciones y puente Lama–Stock permanecen cerrados; triggers B2.3 bloquean escritores legacy en `central/plaza`; origen POS sigue `ninguno`, Fudo en prueba/cron apagado y Lama real apagado.
- Cambios ejecutados: exclusivamente documentación. No hubo SQL de escritura, migraciones, RPC/Edge operativos, cambios de código, datos, RLS, grants, usuarios o configuración.
- Decisión resuelta: Alejo identificó el UUID raíz exacto y aprobó recuperación externa mediante acceso de proyecto con MFA.
- Publicación: auditoría publicada; cierre técnico en el informe S1.

### Tarea S1 — Identidad raíz y gobierno seguro de permisos

- Estado: **COMPLETADA (2026-10-07)**.
- Autorización: Alejo confirmó el UUID del único propietario raíz y aprobó el diseño corregido tras el preflight final.
- Resultado: `docs/hermes/25-s1-identidad-raiz-gobierno-permisos.md`.
- Cambios: esquema privado `authz_internal`, singleton raíz, auditoría inmutable, `app_permisos.auth_uid`, DML directo revocado, lectura propia por RLS, lectura `service_role` conservada y tres RPC protegidas.
- Separación: `puede_ajustes` conserva administración operativa; solo pertenecer a `propietario_raiz` permite gobernar permisos. La segunda cuenta mantiene editar/Fudo/Ajustes, Lama apagado y cero bloqueos Fudo, sin administración de usuarios.
- Compatibilidad: `stock_transferir` conserva firmas y motor, pero consulta permisos efectivos por UUID. La Edge desplegada `fudo-deshacer-stock` mantiene su lectura mediante `service_role`; ninguna Edge se redesplegó ni se llamó a Fudo.
- Seguridad: raíz no degradable por RPC; anon sin lectura; authenticated solo su fila; `anon`, `authenticated` y `service_role` sin DML directo. Siete filas históricas sin Auth quedan inertes.
- Pruebas: roles raíz/administrador/común/anon/service role, auditoría, Data API, transferencia, conteos, advisors, `npm test` y `git diff --check`.
- Fases siguientes: las 36 tablas abiertas, RPC Lama/caja, Fudo operativo, recetas, logística y reportes siguen fuera de S1. No activar automáticamente.

### Tarea S2 — Verificación real de seguridad y regresión

- Estado: **REQUIERE DECISIÓN (2026-10-07)**.
- Autorización: Alejo activó S2 sobre el commit S1 `6e1c2c2`, sin migraciones ni cambios persistentes.
- Resultado: `docs/hermes/26-s2-pruebas-seguridad-regresion.md`.
- Pasó: Data API anónima real; grants, RLS y EXECUTE; funciones S1; pruebas transaccionales de raíz, administrador operativo y usuario común; auditoría inmutable; `stock_transferir`; áreas; Bodega; ledger; lectura server-side Fudo; conteos y suite local.
- Prueba manual: Alejo confirmó login real de ambas cuentas. La raíz pudo leer globalmente, otorgar/revocar y generar auditoría; la cuenta operativa funcionó normalmente y no pudo administrar, escribir permisos ni autoelevarse.
- Secretos: no se compartieron contraseñas, JWT ni claves; Auth no fue alterado para producir evidencia.
- Discrepancia crítica: la consulta posterior muestra cero filas de auditoría. La cuenta operativa quedó restaurada correctamente, pero S2 no se cierra hasta reproducir y corroborar una auditoría persistente.
- Investigación: la auditoría se inserta en la misma transacción que el cambio; las pruebas SQL anteriores hicieron ROLLBACK. Los logs solo muestran el probe anónimo HTTP 401 y ninguna llamada autenticada exitosa a la RPC.
- Probe solicitado no ejecutado: `s2-audit-probe` no pertenece al catálogo admitido por `permisos_actualizar` y el entorno no posee un token reutilizable de la sesión raíz. No se sustituyó el valor ni se simuló una sesión real.
- Estado operativo: Fudo en prueba/cron apagado, Lama real apagado, origen POS `ninguno`, stock y conteos intactos.
- Publicación: solo documentación y resultados. B3.2a no se activa.

### Bloque 0 — Auditoría de inventario por áreas, sedes y Bodega

- Estado: COMPLETADO (2026-10-07; solo lectura y documentación).
- Autorización: Alejo solicitó activar únicamente Bloque 0 mediante el texto adjunto.
- Resultado: `docs/hermes/13-auditoria-areas-sedes-bodega.md`; se actualizaron plan, canal, cola, bitácora y decisiones.
- Supabase verificado: Llamita Plus `iuryhsjucblmebdogewa`. Solo lecturas. Sin código, SQL de escritura, migraciones o datos modificados.
- Cierre: arquitectura actual, sedes, bodegas, lotes, escritores, reparto, mermas, Fudo, Lama, permisos y riesgos documentados. No activar B1 automáticamente.

### Bloque B1 — Administración segura de sedes y nodos

- Estado: COMPLETADO (2026-10-06; catálogo aditivo, archivo lógico de `angamos`, guardas de interfaz y verificaciones).
- Autorización: el usuario activó únicamente B1 y confirmó que `plaza` es Local 1 activa, `angamos` se archiva, `central` es Bodega activa y `bodega` histórica no se reutiliza.
- Resultado: `docs/hermes/14-b1-registro-sedes-resultados.md` y migración `b1_sede_registro` aplicada solo a Llamita Plus (`iuryhsjucblmebdogewa`).
- Cambios: registro `sede_registro` con clave estable, etiqueta, tipo y estado; Local 2 no se ofrece ni abre por rutas de la app; Local 1 y Bodega permanecen disponibles. El catálogo es de solo lectura para clientes.
- Límites: `app_permisos` no es un permiso por sede ni un control administrativo confiable. No se agregó editor de sedes a Ajustes; el esquema permite cambios controlados, pero el cliente no recibe privilegios de mutación. Las guardas protegen navegación accidental, no aíslan los datos en la API.
- Datos operativos: no se modificaron productos, stock, movimientos, repartos, lotes, vencimientos ni permisos existentes. Se conservaron los registros históricos de `angamos` y la clave `bodega`.
- B2 queda PENDIENTE. No crear áreas, existencias por área ni migrar stock en este bloque.

### Bloque B2 — Modelo de áreas y stock por área

- Estado general: **B2.1 COMPLETADO**; **B2.2 REQUIERE DECISIÓN RESUELTA**; **B2.3 COMPLETADO**; **B2.3.1 COMPLETADO**; **B2.4 COMPLETADO**. **B3.1 COMPLETADA**; **B3.2 PENDIENTE**, no activa.
- El libro por ubicación y el corte coordinado están implementados para `central` y `plaza`; controles de acceso por área y operaciones de stock por área quedan para fases futuras. Local 1 no es aislamiento técnico.
- Objetivo restante: habilitar existencias por área sin duplicar `productos.stock_actual`, respetando lotes, transferencias, mermas, Fudo y Lama.
- B2.1 creó solo el catálogo aditivo de áreas de `plaza` y una relación preparatoria vacía. No asignó productos ni stock. Evidencia: `docs/hermes/15-b2-1-cimientos-areas.md`.
- Decisión aprobada: el libro de existencias por ubicación será la autoridad futura; Bodega central recibe stock; `plaza` inicia en Sin asignar; se prohíbe clasificación histórica automática; `productos.stock_actual` será proyección no editable. Detalle: `docs/hermes/17-decision-libro-existencias-ubicacion.md`.
- La ejecución inicial de B2.3 se detuvo ante los bloqueos descritos en el documento 18. La autorización posterior habilitó un corte coordinado que quedó completado; ver `docs/hermes/19-b2-3-corte-libro-ubicaciones.md`.
- B2.3 no creó saldos en áreas físicas. B2.4 posteriormente completó el motor de transferencias; la interfaz por áreas se ejecuta ahora en B3.1.

### Tarea B2.2 — Decisión arquitectónica del libro por ubicación

- Estado: **REQUIERE DECISIÓN RESUELTA (2026-10-07)**; cerrada solo como decisión arquitectónica, no como implementación.
- Autorización: Alejo aprobó las reglas documentadas aquí. No activó ningún bloque de implementación.
- Decisión: fuente futura única = libro de existencias por producto/sede/ubicación/lote; Bodega `central` es el punto de entrada y origen logístico; saldos actuales de `central` migrarán a Bodega central y los de `plaza` a Sin asignar; lotes actuales de `plaza` también a Sin asignar; `angamos` y la clave histórica `bodega` no se migran; no habrá clasificación histórica automática; `productos.stock_actual` será solo proyección de compatibilidad y de solo lectura.
- Operación aprobada: reparto con destino de área explícito y atomicidad salida/entrada; mermas en un módulo global con área de ocurrencia; críticos, reportes y búsqueda calculados por área; recetas y Lama–Stock real siguen apagados hasta que el modelo funcione.
- Auditoría precedente: `docs/hermes/16-b2-2-auditoria-fuente-unica-stock.md`; decisión normativa: `docs/hermes/17-decision-libro-existencias-ubicacion.md`.
- Sin implementación: no se ejecutó SQL, migración, cambio de código ni modificación de datos. No se activan repartos por área, interfaz ni formularios.
- En el primer intento de B2.3, la ejecución quedó **REQUIERE DECISIÓN** antes de migrar; la autorización y cierre posteriores constan en la tarea B2.3 e informe 19. El informe 18 conserva el antecedente.

### Tarea B2.3 — Libro de existencias por ubicación y corte coordinado

- Estado: **COMPLETADA (2026-10-07)**. El bloqueo del primer intento (documento 18) fue resuelto por la autorización explícita posterior de Alejo.
- Autorización: Alejo activó únicamente el corte coordinado B2.3 para `central` y `plaza`, con migración inicial a Bodega central y Sin asignar de Local 1.
- Repositorio/proyecto verificados: `leoalejoleo1537/llamita-plus`; Supabase `llamita-plus`, ref `iuryhsjucblmebdogewa`.
- Resultado: ledger privado aditivo por sede/ubicación/producto/lote; aperturas idempotentes de `central` en Bodega central y `plaza` en Sin asignar; agregado `productos.stock_actual` protegido como proyección; rutas legacy no adaptadas bloqueadas explícitamente en estas sedes. `angamos` y `bodega` histórica conservan comportamiento.
- Migraciones aplicadas: `20261007152558 b2_3_libro_existencias_corte` y `20261007152805 b2_3_indices_permisos_libro`. Informe, rollback y pruebas: `docs/hermes/19-b2-3-corte-libro-ubicaciones.md` y `sql/2026-10-b2-3-*`.
- Validación: 1.437 productos y stock agregado 15.438,00 sin cambios; 408 aperturas en el libro, total 9.316,70; cuatro áreas físicas con saldo 0. Conteos de lotes, movimientos, repartos, recetas y permisos iguales antes/después. Pruebas de conciliación, RLS/grants, bloqueos, transferencia sintética e idempotencia pasaron en transacciones revertidas.
- Fudo: guardas añadidas en las fuentes Edge, no desplegadas; ningún cambio remoto de stock. Fudo plaza sigue en prueba/cron apagado. Lama real apagado y `lama_stock_config` vacía. No se consultó ni tocó Café del Desierto / Llamita Stock.
- En el cierre original de B2.3, B2.3.1 y B2.4 estaban pendientes; su estado actual se registra en sus entradas respectivas y en el encabezado de esta cola.

### Tarea B2.3.1 — Blindaje de conectores POS y origen activo por sede

- Estado: **COMPLETADA (2026-10-07)**. En el momento de cerrar B2.3.1, B2.4 estaba pendiente; posteriormente se completó según la entrada B2.4.
- Autorización: Alejo activó únicamente B2.3.1; no activar Fudo/Lama real ni abrir selector de Ajustes.
- Configuración comprobada: `fudo_sync` contiene modo/cursor de Fudo, `lama_stock_config` contiene modo de Lama y `ajustes` contiene flags booleanos; ninguna define un origen POS único. Se creó `stock_internal.origen_pos` en esquema privado. `plaza`, `central`, `angamos` y `bodega` quedan en `ninguno`.
- Migración aplicada: `20261007162948 b2_3_1_pos_origin_guard`; archivo fuente `supabase/migrations/20261007162700_b2_3_1_pos_origin_guard.sql`.
- Protecciones: helper verificador ejecutable solo por `service_role`; tabla sin grants directos y con RLS; `fudo_procesar_item` ya no es ejecutable desde navegador; triggers de eventos Fudo, config/aplicaciones Lama, y guardas del motor Lama. Modo `real` de Lama exige origen `lama` además de las condiciones previas.
- Edge Functions desplegadas activas, release marker `2026-10-07-b2.3.1`, `verify_jwt=true`: `fudo-ciclo`, `fudo-sync-ventas`, `fudo-empujar-stock`, `fudo-deshacer-stock`, `fudo-sumar-stock`, `fudo-probar-escritura`. La fuente desplegada fue consultada y contiene el verificador.
- Pruebas: `sql/2026-10-b2-3-1-pruebas-origen-pos.sql` con `BEGIN ... ROLLBACK`; RPC simulado como `service_role` devuelve false para Fudo/Lama en `plaza`; prueba endpoint sin JWT responde 401. Datos finales: origen `ninguno` en las cuatro sedes; `fudo_sync` de `plaza` sigue `prueba`/cron apagado; `lama_stock_config` 0; productos 1.437, stock 15.438,00, movimientos 431 y registros Fudo 15.357, sin cambios.
- Sin usuario administrador para cambiar la tabla ni permisos API directos. Un futuro selector debe usar una operación backend que valide `app_permisos.puede_ajustes`; si se requiere delegación más acotada, debe aprobarse una capacidad específica. Informe: `docs/hermes/20-b2-3-1-blindaje-origen-pos.md`.
- No hubo llamadas a Fudo, cambios de Fudo remoto, modo real, ventas, stock, recetas ni datos comerciales. Toteat solo quedó reservado. No activar B2.4 automáticamente.

### Tarea B2.4 — Motor seguro de transferencias entre ubicaciones

- Estado: **COMPLETADA (2026-10-07)**. B3 permanece **PENDIENTE**, no activa.
- Autorización: Alejo activó únicamente B2.4; no crear interfaz ni asignaciones automáticas.
- RPC público: `public.stock_transferir`, `SECURITY INVOKER`, solo `authenticated`; valida `auth.uid()`, claims de correo y `app_permisos.puede_editar`. El helper privado repite la validación antes de llamar al motor interno. Tablas internas siguen sin DML directo desde API o `service_role`.
- Alcance: Bodega central → área de Local 1 con enlace real de producto 1:1; Sin asignar → área; área → área conservando el producto. Bloquea bodegas/áreas inactivas, `angamos`, `bodega`, producto sin enlace, unidades no equivalentes y saldo insuficiente.
- Modelo: encabezado `stock_internal.transferencias` con referencia/idempotencia, actor, motivo y `reversa_de`; dos movimientos inmutables de salida/entrada con claves únicas y un trigger diferido que verifica par, cantidad, producto, ubicación, lote, actor y motivo.
- Lotes: `stock_internal.lote_continuidad` liga el ID canónico de `producto_lotes` al producto destino y conserva el vencimiento sin insertar lotes ficticios. La reclasificación legado→libro se permite solo cuando el lote tiene respaldo suficiente en el saldo sin lote, mediante movimientos compensados.
- Migraciones aplicadas (versiones confirmadas en Supabase): `20261007165310 b2_4_transferencias_ubicaciones_seguras`, `20261007165656 b2_4_index_lote_continuidad_transferencia`, `20261007165826 b2_4_secure_transfer_entrypoint` (ver informe 21 para archivos fuente).
- Pruebas: SQL transaccional `BEGIN ... ROLLBACK`: Bodega→Cafetería, Sin asignar→Barra, área→área, lote y vencimiento, sin lote, insuficiencia, falta de enlace, idempotencia, error entre salida/entrada, permisos bajo rol authenticated, RLS/ACL, conciliación, no negativos y conservación de la proyección global. Conteos post rollback idénticos.
- Estado posterior: 1.437 productos; `stock_actual` global 15.438,00; 42 lotes; libro 9.316,70; 0 transferencias persistentes, 0 relaciones de continuidad nuevas, 0 clasificaciones persistentes; 15.357 `fudo_movimientos`; 431 movimientos legacy; Lama real 0.
- Fudo remoto no fue contactado ni modificado. No se activó Lama, no se implementó interfaz ni se distribuyeron productos persistentes. Informe y rollback: `docs/hermes/21-b2-4-motor-transferencias-ubicaciones.md`, `sql/2026-10-b2-4-transferencias-ubicaciones.rollback.sql`.
- No activar B3 automáticamente.

### Bloque B3 — Interfaz de inventario por áreas

- Estado: EN CURSO POR SUBFASES. **B3.1 COMPLETADA**; **B3.2 PENDIENTE**, no activar automáticamente.
- El bloque B2.4 habilitó el motor, pero B3.1 es solo lectura y navegación: no llama a `stock_transferir`.

### Tarea B3.1 — Interfaz de lectura y navegación por áreas

- Estado: **COMPLETADA (2026-10-07)** por solicitud explícita de Alejo.
- Objetivo: convertir Inventario de `plaza` en portada de áreas, reutilizar la lista actual filtrada por área, mostrar Sin asignar y una vista global agrupada; mantener la interfaz de Bodega.
- Fuente autorizada: libro `stock_internal.existencias`; no usar `productos.stock_actual` para cifras de áreas. Sin mínimos por área, no calcular críticos.
- Lectura permitida: agregar RPC/view segura de solo lectura si hace falta; RLS y permisos mínimos; ningún DML directo ni acciones de transferencia.
- Fuera de alcance: botón de transferencias, asignaciones persistentes, mínimos/máximos, edición/alta de producto por área, mermas por área, Fudo/Lama reales, sedes históricas y Café del Desierto.
- Pruebas: portada 4 áreas+Sin asignar+Todas; áreas físicas inicialmente cero; stock inicial de plaza en Sin asignar; Bodega intacta; búsqueda aislada, global desglosada, sin escrituras, sintaxis/permisos/consulta y `git diff --check`.
- Resultado: `public.stock_leer_areas()` expone únicamente lectura autenticada de la vista de existencias del libro en `plaza`; portada, páginas filtradas y agrupación global implementadas. Las áreas físicas siguen en cero y Sin asignar presenta 4.566,20 unidades en 255 productos con saldo.
- Pruebas: función autenticada consultada dentro de transacción revertida; conciliación RPC/libro sin diferencias; ACL/RLS comprobados; `npm test`, validaciones estáticas y `git diff --check`. Sin navegador Chromium, por lo que la verificación visual queda con procedimiento manual en `docs/hermes/22-b3-1-lectura-areas.md`.
- Informe: `docs/hermes/22-b3-1-lectura-areas.md`. Migraciones: `20261007174518 b3_1_lectura_inventario_areas`, `20261007174626 b3_1_include_inactive_stock_products`.
- Sin escrituras a productos/stock, lotes, movimientos, transferencias, recetas, POS ni datos comerciales; no se habilitó `stock_transferir` desde UI. Bodega mantiene su interfaz. No se accedió a Café del Desierto / Llamita Stock.
- Publicación: implementación publicada en `master`, commit `2a9c8c2`. B3.2 queda PENDIENTE; no activarla automáticamente.

### Tarea B3.2a — Gestión de áreas y asignación preferida de productos

- Estado: **REQUIERE DECISIÓN (2026-10-07)**. Se detuvo antes de modificar código o base de datos.
- Autorización: Alejo activó únicamente B3.2a mediante el texto adjunto. Esta actualización registra el bloqueo; no habilita B3.2b.
- Evidencia: en Supabase Llamita Plus `iuryhsjucblmebdogewa`, `public.app_permisos` tiene políticas `INSERT authenticated WITH CHECK true`, `UPDATE authenticated USING true WITH CHECK true`, y otra política `UPDATE anon,authenticated USING true WITH CHECK true`. Los roles `anon` y `authenticated` además conservan grants directos amplios, incluidos INSERT/UPDATE/DELETE/TRUNCATE. Por tanto cualquier cliente puede alterar `puede_ajustes`; las RPC futuras no pueden tratar ese campo como autorización confiable.
- Decisión requerida: autorizar el endurecimiento acotado de la administración de `app_permisos` para que solo una identidad con permiso administrativo previamente confiable pueda gestionarla, incluyendo el mecanismo de bootstrap y las RPC necesarias; o definir otra fuente confiable de autorización. No se debe construir CRUD de áreas/asignaciones hasta resolverlo.
- No se modificó: código, SQL, migraciones, datos, permisos, áreas, productos, stock, lotes, movimientos, transferencias, recetas, POS ni datos comerciales.
- Informe de bloqueo: `docs/hermes/23-b3-2a-bloqueo-autorizacion.md`.
- B3.2b (transferencias visuales) queda **PENDIENTE**, no activa.

### Tarea B3.2b — Transferencias visuales entre ubicaciones

- Estado: **PENDIENTE**, no activa. No ejecutar hasta activación explícita.
- Precondición: resolver primero el bloqueo de autorización de B3.2a y completar su cierre.
- Alcance reservado: interfaz que llame exclusivamente a `stock_transferir`; no editar saldos directamente.

### Tarea B2.1 — Cimientos del modelo de áreas operativas

- Estado: COMPLETADA (2026-10-07).
- Autorización: Alejo activó únicamente B2.1 en esta ejecución.
- Alcance ejecutado: crear `areas_operativas`; sembrar Cocina fría, Cocina caliente, Barra y Cafetería solo en `plaza`; crear relación preparatoria `producto_area_asignacion` sin cantidades; habilitar RLS y revocar privilegios directos de `PUBLIC`, `anon`, `authenticated` y `service_role`.
- Conciliación: consulta SELECT-only `sql/2026-10-b2-1-simulacion-clasificacion.sql`; cada producto recibe un destino propuesto como máximo y no se persiste clasificación.
- Pruebas: estructura, áreas exactas, integridad de sede, unicidad producto-sede, estado/área, clave estable, RLS, ausencia de grants/políticas y ausencia de columnas de saldo; prueba transaccional revertida.
- Migraciones: `b2_1_cimientos_areas_operativas`, `b2_1_indices_fk_producto_area` y `b2_1_comentario_relacion_area`.
- Resultado: 1.437 productos y stock global 15.438,00 sin cambios; `plaza` 329 productos y 4.566,20; asignaciones persistidas 0; no se tocó `lama_areas`.
- Rollback preparado: `sql/2026-10-b2-1-cimientos-areas-operativas.rollback.sql`; aborta si la relación dejó de estar vacía o el catálogo cambió.
- Publicación: commit y push a `master` autorizados si las verificaciones pasan. No activar B2.2.

### Tarea A1 - Auditoría de integración Fudo y Llamita Lama

- Estado: COMPLETADA
- Autorización: Alejo aprobó iniciar la primera parte del plan el 2026-10-06.
- Objetivo: auditar la integración Fudo ya existente, el módulo Llamita Lama y sus conexiones reales con recetas, ventas, caja e inventario antes de diseñar stock por áreas.
- Documentos obligatorios: `CLAUDE.md`, `README.md`, `docs/LAMA.md`, `docs/fudo-api-cuanto-sirve.md`, `docs/atlas-fudo.md`, `docs/hermes/00-reglas-operativas.md` y `docs/hermes/06-canal-hermes-codex.md`.
- Alcance permitido: lectura del repositorio; lectura del esquema autorizado de Llamita Plus; mapa de componentes, funciones, tablas, permisos, sincronizaciones y puntos de lectura/escritura; propuesta de contrato común.
- Fuera de alcance: cambios de código; SQL o migraciones; inserciones/actualizaciones/borrados; cambios de UI; activación de áreas; cambios en modo demostración; cualquier acceso a Café del Desierto.
- Criterios de aceptación: respuesta en `06-canal-hermes-codex.md`; bitácora actualizada; hechos e inferencias separados; Fudo existente distinguido de Lama futuro; función de pagos/caja separada de evento de inventario; riesgos y decisiones pendientes explícitos.
- Pruebas requeridas: solo consultas y verificaciones de lectura; `git diff --check`; no se requieren pruebas de aplicación porque no se modifica código.
- Publicación: push a `master` autorizado para esta actualización documental, sin cambios de aplicación, esquema ni datos.
- Riesgos conocidos: documentación histórica que podría no coincidir con el esquema vigente; funciones Fudo visibles solo bajo permisos; múltiples escritores de `productos.stock_actual`; ausencia de stock por área.
- Resultado (2026-10-06): auditoría documentada en `docs/hermes/06-canal-hermes-codex.md`. Se confirmó Fudo operativo con recetas, espejo, modo prueba/real e idempotencia por ítem; Lama tiene mesas, comandas, cobros, anulaciones y arqueos, pero todavía no descuenta inventario. Quedan decisiones sobre el momento de descuento, anulaciones, versionado de recetas y contrato común.
- Cambios en código, esquema y datos: ninguno. No activar B1 ni el puente Lama→inventario hasta resolver las decisiones pendientes.

### Tarea A2 - Contrato común: venta, receta e inventario

- Estado: COMPLETADA
- Autorización: Alejo aprobó iniciar A2 el 2026-10-06, después de revisar la auditoría A1.
- Objetivo: producir una especificación implementable para que Fudo existente, Llamita Lama y un futuro Toteat puedan entregar eventos al mismo motor de inventario, sin mezclar pagos/caja con consumo físico.
- Documentos obligatorios: `CLAUDE.md`, `docs/LAMA.md`, `docs/fudo-api-cuanto-sirve.md`, `docs/hermes/00-reglas-operativas.md`, `docs/hermes/05-decisiones-pendientes.md` y `docs/hermes/06-canal-hermes-codex.md`.
- Decisiones ya tomadas: el **cierre de mesa** de Lama es el único disparador de descuento de inventario de sus líneas; el método de pago, propina, cobro parcial o caja no cambian esa regla. La venta local debe tener identidad propia de Llamita; la receta histórica debe poder reconstruirse; por operación solo habrá un origen POS activo por sede (Fudo, Lama o Toteat), sin perjuicio de la deduplicación de reintentos dentro de cada origen; los precios deben tener su propio modelo y la línea vendida debe conservar el precio aplicado.
- Pregunta principal pendiente: definir el tratamiento exacto de confirmaciones/comandas previas al cierre, anulaciones antes y después del cierre, consumo interno y reversas.
- Alcance permitido: inspección de lectura adicional estrictamente necesaria; matriz de decisiones; modelo de eventos y estados; diseño de identidad de productos; diseño de receta versionada o instantánea; estrategia de deduplicación; plan de migración de `stock_actual` a stock por área; especificación de precios/instantánea de precio; actualización documental.
- Fuera de alcance: código de aplicación, SQL/migraciones, inserciones/actualizaciones/borrados, activación de conectores, cambio de modo demostración, creación de áreas, cambios en Café del Desierto.
- Entregables: `docs/hermes/07-contrato-comun-inventario.md` nuevo; respuesta/resumen en `06-canal-hermes-codex.md`; bitácora actualizada; propuesta de fases de implementación y criterios de prueba.
- Criterios de aceptación: separar hechos de decisiones; no plantear doble fuente de stock; definir comportamiento de reversa sin borrado histórico; explicar compatibilidad con Fudo existente y Toteat futuro; dejar las decisiones que sigan abiertas listas para que Alejo elija.
- Pruebas requeridas: verificaciones de lectura y `git diff --check`; no se requieren pruebas de aplicación.
- Publicación: push a `master` autorizado solo para documentación de A2. Sin cambios de aplicación, esquema ni datos.
- Resultado (2026-10-06): contrato documentado en `docs/hermes/07-contrato-comun-inventario.md`; canal y bitácora actualizados. Se fija cierre de mesa de Lama como disparador único, idempotencia por origen, receta/precio históricos y transición a ledger producto-área sin doble saldo.
- Pendientes: identidad canónica, permisos de reversa, consumos internos, snapshot de receta, errores parciales, unidades/redondeo y ventana de corte por sede. No activar B1 ni implementar el puente hasta aprobación.

### Tarea A3.1 - Cimientos del puente Lama → Stock

- Estado: COMPLETADA
- Autorización: Alejo aprobó iniciar los bloques A3 el 2026-10-06 y confirmó que la mesa/caja deben cerrar aunque falle inventario.
- Objetivo: crear únicamente la base aditiva, segura e idempotente para eventos y aplicaciones de inventario, sin conectarla todavía al cierre de mesas ni escribir stock.
- Documento obligatorio: `docs/hermes/08-plan-implementacion-puente-lama-stock.md` completo, además de las reglas, contrato A2 y documentación Lama/Fudo relevante.
- Alcance permitido: inspección final; documentación vigente de Supabase; migración versionada; tablas, constraints, índices, estados, RLS/permisos, pruebas de estructura e idempotencia; aplicación de la migración solo en Supabase Llamita Plus verificado si es segura.
- Fuera de alcance: cambios en UI; `cuenta_cobrar`, `cuenta_cerrar`, `item_anular`; escritura de stock; modificación de recetas/datos/ventas; funciones o secretos Fudo; áreas; Café del Desierto.
- Criterios de aceptación: esquema aditivo y reversible; modo efectivo apagado; sin mutación de ventas/stock; RLS y grants revisados; idempotencia probada; rollback documentado; pruebas y limitaciones registradas.
- Publicación: commit y push a `master` autorizados si las verificaciones pasan. No activar A3.2.
- Regla de detención: cualquier duda de identidad de repositorio/proyecto, firma existente, seguridad, colisión de nombres o migración no reversible cambia el estado a `REQUIERE DECISIÓN` sin ejecutar cambios.
- Resultado (2026-10-06): migración `a3_1_cimientos_lama_stock` aplicada únicamente en Supabase `llamita-plus`. Se crearon los cimientos aditivos con RLS, permisos directos revocados, modo efectivo apagado y claves únicas de idempotencia. Pruebas estructurales y transaccionales correctas; ventas, recetas, productos y stock sin cambios.
- Archivos: `sql/2026-10-a3-1-cimientos-lama-stock.sql` y rollback `sql/2026-10-a3-1-cimientos-lama-stock.rollback.sql`. No activar A3.2.

### Tarea A3.2 - Captura protegida del cierre Lama

- Estado: COMPLETADA
- Autorización: Alejo aprobó continuar los bloques A3 después de completar A3.1; Hermes revisó la migración aplicada y no encontró un bloqueo para captura en modo apagado/prueba.
- Objetivo: hacer que los cierres de Lama creen eventos idempotentes y snapshots de sus líneas cuando el modo sea `prueba`, sin modificar stock y sin permitir que un fallo de inventario impida cerrar la mesa o registrar caja.
- Documentos obligatorios: `docs/hermes/08-plan-implementacion-puente-lama-stock.md`, contrato A2, reglas operativas, documentación Lama y resultado A3.1.
- Alcance permitido: migración aditiva; función interna de captura; integración conservando exactamente las firmas actuales de `cuenta_cobrar` y `cuenta_cerrar`; estado persistente de captura por cuenta; modo `apagado/prueba`; pruebas transaccionales y de aplicación; documentación.
- Regla transaccional: la venta, pagos y cierre de cuenta son autoritativos. La captura de inventario debe ejecutarse en un bloque protegido; receta faltante produce `sin_receta`, y una excepción técnica deja un marcador persistente `pendiente/error` sin revertir el cierre comercial.
- Modo apagado: ausencia de fila en `lama_stock_config` conserva exactamente el comportamiento actual y no crea eventos.
- Modo prueba: crea un evento por línea confirmada y no anulada, congela cantidad, precio y receta, pero no crea descuentos reales ni cambia productos/lotes.
- Idempotencia: cierre repetido, doble clic o timeout no duplican eventos. Cubrir ambos caminos reales: `cuenta_cobrar` y `cuenta_cerrar`; mesa vacía no genera eventos.
- Fuera de alcance: escritura de `productos.stock_actual`; aplicaciones reales; modo `real`; reversas; panel; Fudo/Edge Functions; áreas; Café del Desierto.
- Criterios de aceptación: pruebas de modo apagado, prueba, sin receta, receta existente, línea anulada, mesa vacía, cierre repetido y excepción de captura; conteos y suma de stock pre/post sin cambios; rollback documentado; RLS/grants revisados.
- Publicación: migración y código asociado pueden aplicarse exclusivamente a Llamita Plus y publicarse a `master` si todas las pruebas pasan. No activar A3.3.
- Regla de detención: si no puede garantizarse que una falla de captura deje cerrar y conservar caja, no modificar las funciones de cierre y marcar `REQUIERE DECISIÓN`.
- Resultado (2026-10-06): captura protegida aplicada únicamente en Llamita Plus. Se conservaron las firmas reales de `cuenta_cobrar` y `cuenta_cerrar`; ambos caminos llaman a una función interna solo después del cierre comercial. Modo apagado no crea eventos; modo prueba captura líneas confirmadas no anuladas; sin receta queda `sin_receta`; errores quedan persistidos sin bloquear mesa/caja.
- Migraciones: `a3_2_captura_cierre_lama` y endurecimiento `a3_2_restrict_captura_execute`. No se modifican stock, lotes, aplicaciones, Fudo ni interfaz. No activar A3.3.
- Rollback: `sql/2026-10-a3-2-captura-cierre-lama.rollback.sql`, restaura las definiciones pre-A3.2 y aborta si existen filas de captura/eventos.

### Tarea A3.3 - Motor neutral y aplicación al stock actual

- Estado: COMPLETADA
- Autorización: Alejo aprobó continuar los bloques A3; Hermes revisó las migraciones A3.2 y confirmó que caja/cierre quedan aislados del puente.
- Objetivo: implementar un motor idempotente por `event_id` que use el snapshot de receta, produzca aplicaciones por ingrediente y pueda operar en `prueba` o `real`, manteniendo `productos.stock_actual` como única cantidad vigente.
- Corrección previa obligatoria: en eventos Lama, `ocurrido_at` debe ser la hora de cierre `cuentas.cerrada_at`; `cuenta_items.agregado_at` puede conservarse en metadata. No existen eventos persistentes que migrar.
- Alcance permitido: migración aditiva/reversible; motor interno; ajuste compatible de captura para modo `real`; aplicaciones de prueba; escritura real al stock actual y lotes solo durante pruebas transaccionales revertidas; pruebas de atomicidad, idempotencia, FIFO, reglas `aplica` y error; documentación.
- Configuración: ninguna sede puede quedar persistentemente en `prueba` o `real` al terminar. La ausencia de configuración sigue equivalendo a `apagado`.
- Modo prueba: crear aplicaciones `prueba` con los deltas esperados, sin escribir productos, lotes ni movimientos reales.
- Modo real: capturar evento y aplicar una vez. Debe soportarse y probarse solo dentro de transacciones revertidas en A3.3; la activación persistente pertenece a A3.4.
- Atomicidad por línea: todos los ingredientes de una línea se aplican o ninguno. Un fallo revierte el intento de esa línea, marca el evento `error` y nunca revierte la mesa, venta, pagos o caja.
- Recetas: consumir exclusivamente el snapshot del evento; cambios posteriores en `recetas` no alteran el evento. Respetar `aplica` según fulfillment; documentar el valor utilizado para ventas Lama de mesa.
- Lotes: inspeccionar las funciones reales instaladas y reutilizar FIFO sin copiar firmas históricas. Evitar dos escrituras sobre `stock_actual` cuando el trigger de lotes ya lo recalcula.
- Seguridad: helpers internos sin `EXECUTE` para `PUBLIC`, `anon`, `authenticated` ni `service_role`; no exponer mutaciones directas de las tablas A3.
- Fuera de alcance: activar persistentemente el puente; panel/reproceso público; reversa administrativa; adaptar Fudo; áreas; catálogo canónico completo; Café del Desierto.
- Criterios de aceptación: pruebas transaccionales de receta simple/múltiple, modo prueba, modo real, doble ejecución, timeout simulado, insuficiencia/error intermedio, producto con/sin lotes, receta cambiada después de captura y `sin_receta`; conteos y stock pre/post idénticos tras rollback; advisors/seguridad revisados; rollback documentado.
- Publicación: migraciones y código pueden aplicarse exclusivamente a Llamita Plus y publicarse a `master` si pasan las pruebas. No activar A3.4.
- Regla de detención: si no puede garantizarse atomicidad por línea o evitar doble escritura lote/stock, detenerse en `REQUIERE DECISIÓN` sin activar modo real.

- Resultado (2026-10-06): motor `lama_stock_aplicar_evento(uuid)` aplicado exclusivamente en Llamita Plus. Usa solo `snapshot_receta`, respeta `siempre/servir/llevar`, crea una aplicación por ingrediente y delega el descuento al FIFO instalado o al camino sin lotes.
- Migraciones: `a3_3_motor_neutral_lama_stock` y `a3_3_fulfillment_rules`. Captura corregida a `cuentas.cerrada_at`; `cuenta_items.agregado_at` queda en metadata.
- Pruebas: prueba sin stock; real con cierre, sin lotes y FIFO; reintento; timeout equivalente por repetición; error intermedio atómico; insuficiencia según funciones reales; sin receta; snapshot inmutable; reglas de fulfillment. Todas fueron transaccionales y revertidas.
- Estado final: `lama_stock_config` vacía, ningún stock persistente cambiado y A3.4 no activada. Rollback: `sql/2026-10-a3-3-motor-neutral-lama-stock.rollback.sql`.

### Tarea A3.4a - Observabilidad y reproceso seguro en modo prueba

- Estado: COMPLETADA
- Autorización: Alejo solicitó activar únicamente A3.4a después de completar A3.3.
- Objetivo: consultar eventos Lama por estado y reintentar eventos fallidos de forma idempotente sin habilitar modo real ni modificar el cierre comercial.
- Alcance permitido: vista interna de observabilidad; helper interno de reproceso restringido a eventos `error` en modo `prueba`; migración reversible; pruebas transaccionales.
- Fuera de alcance: modo real, stock persistente, reversas administrativas, áreas, Fudo, interfaz, cambios en `cuenta_cobrar`/`cuenta_cerrar`, A3.4b y Café del Desierto.
- Criterios de aceptación: consultar `pendiente`, `aplicado`, `error` y `sin_receta`; reintento idempotente; sin EXECUTE público; RLS y grants revisados; `lama_stock_config` vacía y stock sin cambios persistentes.
- Publicación: migración, rollback y documentación pueden publicarse a `master` si las pruebas pasan.
- Resultado (2026-10-06): vista interna `lama_stock_eventos_observabilidad` y helper `lama_stock_reintentar_evento(uuid)` aplicados en Llamita Plus. El reproceso solo acepta eventos `error` en modo `prueba`; no expone permisos a roles públicos y no altera stock.
- Pruebas transaccionales: estados consultables, reproceso, doble reproceso, `sin_receta`, rechazo de modo `real`, permisos y stock sin cambios. `lama_stock_config` quedó vacía.
- Rollback: `sql/2026-10-a3-4a-observabilidad-reproceso.rollback.sql`.

### Tarea A3.4b - Prueba sintética E2E del flujo Lama–Stock

- Estado: **COMPLETADA** — 2026-10-06.
- Se ejecutó exclusivamente una prueba sintética dentro de una transacción `BEGIN ... ROLLBACK`, usando cuentas, líneas, productos y receta temporales. No se usaron ventas reales ni quedaron filas persistentes.
- Flujo cubierto: `cuenta_agregar` → `cuenta_confirmar` → `cuenta_cerrar` → captura del evento → snapshot de receta → procesamiento en modo `prueba` → aplicaciones por ingrediente → idempotencia → reintento y error intermedio.
- La receta temporal tuvo dos ingredientes. Se verificó que el evento conserva el snapshot aunque la receta viva cambie después; las dos aplicaciones esperadas sumaron delta `-6` para una línea de cantidad `2`.
- Se forzó un error en el segundo ingrediente. La cuenta quedó `cerrada`, con total comercial `250`, mientras el evento quedó `error` y las aplicaciones quedaron marcadas con error. El reintento pasó a `prueba`; repetirlo no duplicó aplicaciones. Esto confirma que un fallo del motor de stock no impide cerrar la mesa ni registrar sus datos comerciales.
- Se verificó que el modo real no se activó, que no hubo escritura persistente de stock y que `lama_stock_config` quedó vacía.
- Conteos pre/post: cuentas `59`, líneas `88`, recetas `396`, ítems de receta `514`, productos `1437`, suma `productos.stock_actual` `15438.00`, comandas persistentes `50`; tablas de configuración, eventos, aplicaciones y capturas `0` antes y después.
- Evidencia detallada: `docs/hermes/11-pruebas-a3-4b.md`.
- No activar automáticamente A3.4c.

### Tarea A3.4c - Prueba controlada de interfaz Lama en modo prueba

- Estado: **COMPLETADA** — 2026-10-06.
- Autorización: Alejo solicitó activar únicamente A3.4c en modo `prueba` con datos sintéticos controlados.
- Objetivo: recorrer el camino que usa la interfaz de Lama (`cuenta_agregar` → `cuenta_confirmar` → `cuenta_cerrar`) y verificar captura, aplicación de evento e idempotencia sin modificar stock persistente.
- Alcance permitido: una sede temporalmente configurada en `prueba`, cuenta/mesa/productos/receta sintéticos, comprobación de IDs, reintento idempotente, `BEGIN ... ROLLBACK`, bitácora y procedimiento manual.
- Fuera de alcance: modo `real`, ventas reales, stock persistente, Fudo, áreas, Café del Desierto/Llamita Stock, reversas administrativas y cambios de cierre comercial.
- Criterios de aceptación: evento en modo `prueba`; aplicaciones por ingrediente; segundo procesamiento sin duplicados; stock y conteos pre/post idénticos; configuración vacía al finalizar.
- Publicación: documentación a `master` si la prueba pasa. No activar una tarea posterior.
- Resultado: transacción sintética aprobada; IDs y procedimiento quedaron documentados en `docs/hermes/12-prueba-manual-a3-4c.md`.

### Tarea A3.4d - Reversas y activación real

- Estado: **PENDIENTE**.
- Alcance futuro: reversas administrativas compensatorias, panel de operación y activación gradual; requiere decisión y pruebas separadas.
- No activar automáticamente desde A3.4c.
