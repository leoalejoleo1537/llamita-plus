# S0 — auditoría integral de seguridad y permisos

Fecha: 2026-10-07
Estado: **REQUIERE DECISIÓN**
Repositorio: `leoalejoleo1537/llamita-plus`
Supabase auditado: `llamita-plus`, ref `iuryhsjucblmebdogewa`

## 1. Resultado ejecutivo

La auditoría es suficiente para diseñar S1, pero no para fijar su identidad raíz. Existen dos usuarios Auth confirmados y ambos coinciden por correo con filas de `app_permisos` que tienen capacidades administrativas. No hay columna `auth.uid()`, clave foránea, metadata segura, marca de propietario ni otra evidencia que permita afirmar cuál corresponde a Alejo. Por esa razón S0 queda `REQUIERE DECISIÓN`.

No se ejecutó ninguna escritura. Las conclusiones provienen de catálogos PostgreSQL, definiciones instaladas, advisors, metadatos de Edge Functions desplegadas y código local.

### Hallazgos ordenados por gravedad

1. **Crítico — autorización autoeditable y datos personales legibles sin sesión.** `app_permisos` permite `SELECT` a `anon`; expone correos, nombres y capacidades. `anon` puede actualizar cualquier fila y cualquier columna mediante una política `USING true / WITH CHECK true`. `authenticated` además puede insertar filas con `WITH CHECK true`. Un usuario autenticado puede crearse una fila cuyo valor por defecto ya concede `puede_editar=true` y `puede_fudo=true`, o modificar `puede_ajustes`, `puede_lama` y los demás campos. No existe vínculo con `auth.uid()`.
2. **Crítico — escritura anónima transversal.** Treinta y seis tablas operativas tienen una política `ALL` para `anon, authenticated` con `USING true` y `WITH CHECK true`. Incluyen Ajustes, mesas, cuentas, pagos, propinas, caja, arqueos, comandas, movimientos, repartos, recetas y configuración Fudo. El login y los botones ocultos son controles de interfaz, no autorización de base.
3. **Crítico — RPC privilegiados anónimos.** Cuarenta funciones `SECURITY DEFINER` son ejecutables por `anon`; 36 contienen rutas de escritura y ninguna de esas 40 comprueba sesión mediante `auth.uid()`/JWT. Cubren cobros, cierres, descuentos, anulaciones, arqueos, stock legacy, mermas, entradas, repartos, restauraciones y fusiones. Muchos reciben `p_quien`, que el llamador puede falsificar.
4. **Alto — Lama comercial queda abierto aunque su pestaña esté oculta.** `puede_lama` solo decide visibilidad en `index.html`. Las tablas Lama principales aceptan `ALL` de `anon`, y sus RPC comerciales privilegiados también son anónimos. Es posible alterar mesas, comandas, cuentas, pagos, caja y arqueos sin pasar por la pestaña.
5. **Alto — protección parcial del inventario.** Los triggers de B2.3 bloquean escritores legacy para `central` y `plaza`, y el ledger `stock_internal` está cerrado. Esto evita parte del daño de stock en las sedes migradas, pero no protege datos comerciales ni sedes históricas. `angamos` y `bodega` mantienen rutas legacy modificables. `productos` sigue permitiendo lectura, inserción y actualización anónimas; el trigger protege el saldo migrado, no todos los campos de la ficha.
6. **Alto, hoy contenido — Edge Functions Fudo como proxy privilegiado.** Las seis funciones desplegadas usan credenciales server-side y comprueban el origen POS. Todas están `verify_jwt=true`, pero varias no exigen una capacidad de usuario dentro de la función; `fudo-empujar-stock` y `fudo-sumar-stock` incluso contemplan continuar como “equipo (sin sesión)”. `fudo-deshacer-stock` sí consulta `puede_fudo`, pero esa fuente es autoeditable. El riesgo remoto está contenido hoy porque todas las sedes tienen origen `ninguno`, Fudo está en `prueba` con cron apagado y el guard rechaza antes de escribir.
7. **Alto — configuración operativa abierta.** `ajustes` y `fudo_sync` aceptan `ALL` de `anon`. Cualquier cliente puede cambiar modo demostración, interruptores y estado/cursor de sincronización. El trigger de origen impide activar Fudo real en el estado actual, pero no protege el resto de la configuración.
8. **Medio — vistas con privilegio del propietario.** `dias_de_historial`, `dias_de_historial_auto` y `gemelos_propuestos` no tienen `security_invoker`; son legibles por `anon` y los advisors las marcan como `security_definer_view`.
9. **Medio — superficie SQL insegura adicional.** Dos funciones privilegiadas de franquicia no fijan `search_path`; los advisors encuentran diez funciones con `search_path` mutable. Hay grants de tabla excesivos para `anon`/`authenticated`, incluso privilegios que la API REST no expone como operación ordinaria. La protección de contraseñas filtradas de Supabase Auth está desactivada.

## 2. Identidad y fuente de permisos

### Auth real

- `auth.users` tiene dos usuarios, ambos confirmados; no hay usuarios anónimos Auth.
- No se leyeron ni publicaron correos, UUID, tokens, contraseñas o metadata con valores personales.
- `raw_app_meta_data` solo contiene claves estándar de proveedor; no hay `role`, `owner` ni `propietario`.
- `is_super_admin` no está activo en ninguna cuenta.
- `raw_user_meta_data` no se usa como autorización. Solo se observó la clave estándar `email_verified`; conforme a la documentación vigente, no debe utilizarse para permisos.

### `app_permisos`

La tabla tiene como única clave primaria `correo text`. No contiene `user_id`, `uid`, `auth_uid`, sede ni clave foránea a `auth.users`.

Columnas funcionales: `correo`, `nombre`, `puede_fudo`, `puede_editar`, `creado_por`, `created_at`, `puede_ajustes`, `fudo_bloqueos` y `puede_lama`. Los valores por defecto son especialmente relevantes: `puede_fudo=true`, `puede_editar=true`, `puede_ajustes=false` y `puede_lama=false`.

Hay nueve filas y nueve correos distintos. Dos filas coinciden por correo con los dos usuarios Auth; siete no tienen usuario Auth actual. No existen duplicados por correo normalizado ni filas vacías. La distribución anonimizada es:

| Relación con Auth | editar | Fudo | Ajustes | Lama | Filas |
|---|---:|---:|---:|---:|---:|
| Coincide por correo | sí | sí | sí | no | 1 |
| Coincide por correo | sí | sí | sí | sí | 1 |
| Sin usuario Auth actual | sí | sí | sí | no | 4 |
| Sin usuario Auth actual | sí | no | no | no | 3 |

No existe propietario, administrador separado ni operador verificable en base. La interfaz interpreta los booleanos como capacidades globales. El código intenta leer una propiedad `sede`, pero esa columna no existe, por lo que hoy los permisos son globales. El nombre visible del usuario se toma de metadata o del correo; las operaciones registran el parámetro `NOMBRE`/`p_quien`, no una identidad comprobada por el servidor.

### Cómo escala un cliente

- `anon` puede leer todas las filas y actualizar una fila existente, incluido su correo y todos los booleanos.
- `authenticated` puede insertar una fila con su correo y recibe por defecto `puede_editar` y `puede_fudo`; luego puede actualizar cualquier fila.
- Las funciones que validan `puede_editar` o `puede_fudo` heredan este problema. Esto afecta `stock_transferir` y `fudo-deshacer-stock`, aunque ambas sí comprueban primero una sesión real.
- La pantalla “Quién entra a Ajustes” escribe directamente en `app_permisos`. Sus reglas “no quitarte a ti mismo” y “no dejar cero administradores” existen solo en JavaScript y pueden omitirse llamando la API.

## 3. RLS, políticas, grants y exposición

`public` es el esquema usado por la Data API en la aplicación y está demostrado por las llamadas del cliente. La configuración de esquemas expuestos no fue legible mediante `current_setting`, por lo que no se infiere una lista de Dashboard. `stock_internal` no tiene grants de tabla para `PUBLIC`, `anon`, `authenticated` o `service_role`, usa políticas restrictivas y no es llamado directamente por el navegador; se clasifica como interno. `auth` no es consumido por la Data API de la aplicación.

Las 54 tablas de `public` tienen RLS activado, pero 36 tienen una política abierta `ALL`; ocho no tienen políticas. Las siete tablas de `stock_internal` tienen RLS y políticas restrictivas `false`.

### Matriz por grupos de política efectiva

| Objetos | Política y grants observados | Acceso real | Clasificación |
|---|---|---|---|
| `app_permisos` | SELECT anon/auth `true`; INSERT auth `true`; UPDATE anon/auth `true`; grants amplios en todas las columnas | Lectura anónima y escritura insuficientemente restringida | **Crítico** |
| `ajustes`, `secciones`, `tareas`, `metas`, `meta_productos` | `ALL` anon/auth `true/true`; grants CRUD | Configuración y operación modificables sin sesión | **Crítico** |
| `mesas`, `comandas`, `cuentas`, `cuenta_items`, `cuenta_pagos`, `cuenta_pago_items`, `cuenta_propinas` | `ALL` anon/auth `true/true`; grants CRUD | Datos comerciales y cobros modificables sin sesión | **Crítico** |
| `lama_areas`, `lama_medios_pago`, `lama_motivos_anulacion`, `lama_motivos_descuento`, `lama_impresiones`, `lama_arqueos`, `lama_arqueo_declarado`, `lama_arqueo_cierre_medios`, `lama_caja_movimientos` | `ALL` anon/auth `true/true`; grants CRUD | Lama, caja y arqueo abiertos | **Crítico** |
| `productos` | SELECT `public=true`; INSERT anon/auth `true`; UPDATE public/auth `true`; grants de todas las columnas; sin política DELETE | Fichas y sedes modificables; trigger limita stock de sedes migradas | **Crítico/alto** |
| `movimientos`, `repartos`, `reparto_items`, `restauraciones`, `fusiones`, `envios_franquicia`, `envios_franquicia_items`, `producto_enlace` | `ALL` anon/auth `true/true` | Escritura abierta; triggers B2.3 bloquean parte de central/plaza | **Crítico/alto** |
| `recetas`, `receta_items` | `ALL` anon/auth `true/true` | Recetas modificables sin sesión | **Crítico** |
| `fudo_sync`, `fudo_categorias`, `fudo_no_lleva_receta`, `fudo_pospuestos` | `ALL` anon/auth `true/true` | Configuración y clasificación Fudo modificables | **Alto** |
| `fudo_pendientes` | SELECT/INSERT/DELETE para `public` y auth con `true` | Cola legible e insertable/borrable sin sesión | **Alto** |
| `fudo_movimientos`, `fudo_productos`, `fudo_stock_push`, `migraciones_aplicadas`, `sede_registro` | SELECT anon/auth `true`; sin política de escritura para cliente | Lectura pública; `sede_registro` es catálogo intencional, los demás contienen operación | Lectura pública con riesgo |
| `historial` | SELECT/INSERT/DELETE para `public` y auth `true`; sin UPDATE | Fotos manuales legibles, insertables y borrables | **Alto** |
| `historial_auto` | `ALL` anon/auth `true/true` | Respaldo automático editable/borrable | **Crítico** |
| `producto_lotes` | SELECT anon/auth; INSERT/UPDATE/DELETE anon/auth solo si el producto no es `central/plaza` | Sedes migradas protegidas; históricas abiertas | Mixto, **alto** |
| `areas_operativas`, `producto_area_asignacion` | RLS sin políticas y sin grants de cliente/service role | Cerradas a navegador | Escritura correctamente restringida |
| `lama_stock_eventos`, `lama_stock_aplicaciones`, `lama_stock_capturas`, `lama_stock_config` | RLS sin políticas; sin acceso anon/auth; service role conserva grants | Puente no accesible desde navegador | Interno protegido |
| `lama_stock_eventos_observabilidad` | vista `security_invoker`, sin SELECT cliente | Cerrada | Interno protegido |
| `limpiezas`, `receta_items_respaldo_20260809` | RLS sin políticas | Sin acceso por Data API pese a grants base | Cerradas por RLS |
| `stock_internal.*` (`aperturas`, `movimientos`, `transferencias`, `ubicaciones`, `lote_continuidad`, `origen_pos`, `permiso_proyeccion`) | sin grants; RLS restrictiva `false` | Sin DML directo; solo funciones internas autorizadas | Interno protegido |
| `stock_internal.existencias` | vista interna sin grants de cliente | Solo helpers autorizados | Interno protegido |
| vistas `dias_de_historial`, `dias_de_historial_auto`, `gemelos_propuestos` | SELECT anon/auth; sin `security_invoker` | Bypass de RLS del invocador | **Alto/medio** |

Los grants de tabla son más amplios que las políticas en casi todo `public`, incluidos DELETE/TRUNCATE para roles de API. RLS evita algunas operaciones fila a fila, pero no vuelve prudente esa concesión. PostgREST no ofrece TRUNCATE como operación REST ordinaria; se registra como privilegio excesivo, no como explotación probada por la aplicación.

## 4. Funciones SQL, triggers y rutas privilegiadas

### Funciones anónimas `SECURITY DEFINER`

Los advisors y `pg_proc` coinciden: 40 funciones privilegiadas pueden ejecutarse como `anon`; 36 presentan escritura y ninguna verifica sesión. Se agrupan así:

- Caja/arqueo: `arqueo_abrir`, `arqueo_cerrar`, `arqueo_declarar`, `arqueo_eliminar`, `arqueo_movimiento`.
- Mesas/ventas: `mesa_abrir`, `cuenta_agregar`, `cuenta_recalcular`, `cuenta_confirmar`, `cuenta_precuenta`, `cuenta_cerrar`, `cuenta_cobrar`, `cuenta_cobrar_parcial`, `cuenta_pago_parcial_deshacer`, `cuenta_mover`, `items_mover`, `item_anular`.
- Inventario legacy: `registrar_entrada`, `deshacer_entrada`, `mermar`, `deshacer_merma`, `descontar_lotes`, `descontar_con_reposicion`, `tomar_foto_inventario`, `restaurar_sede`, `deshacer_restauracion`, `crear_producto_enlazado`, `fusionar_productos`, `deshacer_fusion`.
- Repartos/franquicia: `reparto_descontar_bodega`, `reparto_recibir`, `reparto_rechazar`, `reparto_deshacer`, `reparto_cerrar`, `franquicia_linea_lista`, `franquicia_linea_no_hay`.
- Lecturas privilegiadas también anónimas: `fudo_stock_calculado`, `fudo_ultimo_empuje`, `historial_dias`, `ventas_por_dia`.

Todas ejecutan como propietario `postgres`. La mayoría fija `search_path=public`, que reduce secuestro de objetos pero mantiene un esquema expuesto. Las dos funciones de franquicia no fijan `search_path`. Los parámetros `p_quien` no se comparan con una sesión y no constituyen auditoría confiable.

### Rutas mejor protegidas

- `stock_leer_areas()` es invoker, solo `authenticated`; el helper interno comprueba sesión y limita a `plaza`.
- `stock_transferir()` es invoker, solo `authenticated`; el helper compara `auth.uid()`, rol, email JWT y actor, y exige `app_permisos.puede_editar`. La identidad de sesión es correcta, pero la capacidad es autoasignable mientras `app_permisos` siga abierta.
- La firma antigua de transferencia solo lanza error. El núcleo y las tablas del ledger no son ejecutables directamente.
- `fudo_procesar_item()` solo es ejecutable por `service_role` y está sujeto al guard de origen POS.
- Funciones `lama_stock_*`, `sync_stock_desde_lotes` y helpers de proyección no son ejecutables por `anon`/`authenticated`; el modo real sigue apagado.
- `stock_pos_origen_permitido()` solo es ejecutable por `service_role`. No hay endpoint de navegador para cambiar `stock_internal.origen_pos`.

### Triggers relevantes

Los triggers de B2.3/B2.3.1 protegen `productos.stock_actual`, lotes, movimientos legacy, repartos, restauraciones, fusiones y activación real Fudo/Lama para `central`/`plaza`. El ledger es inmutable, valida pares de transferencia y refresca la proyección. Esta defensa es material y se mantiene.

Los triggers no autorizan al actor: limitan qué cambio puede persistir. Tampoco protegen mesas, cuentas, pagos, caja, recetas, Ajustes ni las sedes no migradas.

## 5. Edge Functions y secretos

Solo seis Edge Functions están desplegadas, todas `ACTIVE`, versión 1, `verify_jwt=true` y marker `2026-10-07-b2.3.1`:

| Función | Credencial/autoridad | Autorización interna | Riesgo actual |
|---|---|---|---|
| `fudo-ciclo` | service role y token de sistema en servidor | No comprueba permiso propio; delega; guard POS | Bloqueada hoy por origen `ninguno`; diseño depende de downstream |
| `fudo-sync-ventas` | service role + secretos Fudo | Guard POS; no permiso de persona | Cualquier llamador aceptado por gateway podría iniciar lectura si Fudo se activa |
| `fudo-empujar-stock` | service role + secretos Fudo | Guard POS; acepta sistema o etiqueta “equipo” si no obtiene usuario | Escritura remota latente sin capacidad de usuario confiable |
| `fudo-deshacer-stock` | service role + secretos Fudo | Sesión real + `puede_fudo` + guard POS | Sesión correcta, capacidad autoeditable |
| `fudo-sumar-stock` | service role + secretos Fudo | Guard POS; no capacidad de persona | Escritura remota latente si se activa Fudo |
| `fudo-probar-escritura` | credenciales server-side/Fudo | Sesión leída + guard POS | Función diagnóstica desplegada con capacidad remota; revisar en S1 |

No se ejecutó ninguna función ni llamada a Fudo. Los nombres de variables de secretos están en el código servidor; no se leyeron ni publicaron valores. La clave cliente es publicable y está embebida en `index.html`, como corresponde a un cliente Supabase; nunca se encontró `service_role` en el navegador.

Las fuentes locales de otras funciones Fudo existen, pero no aparecen en la lista desplegada. La UI invoca `fudo-activar-producto` y `fudo-sync-productos`; hoy hay una discrepancia entre código cliente/fuentes locales y despliegues observados.

Estado de contención al auditar: origen POS `ninguno` en `plaza`, `central`, `angamos` y `bodega`; Fudo `prueba` y cron apagado en sus dos filas; `lama_stock_config` vacía.

## 6. Rutas directas del cliente

El login usa Supabase Auth con correo/contraseña. Después, el cliente toma el correo de la sesión y busca una fila en `app_permisos`. Los booleanos solo muestran u ocultan UI. No hay enforcement general del lado servidor.

El cliente escribe directamente mediante Data API, entre otras, estas familias:

- permisos y configuración: `app_permisos`, `ajustes`, `secciones`, `fudo_sync`, `fudo_categorias`;
- productos e inventario legacy: `productos`, `producto_lotes`, `producto_enlace`, `historial`, `recetas`, `receta_items`;
- operación logística: `repartos`, `reparto_items`, `envios_franquicia`, `envios_franquicia_items`;
- Lama: `mesas`, `cuentas`, `cuenta_items`, `lama_areas`, `lama_impresiones`;
- metas/tareas: `metas`, `meta_productos`, `tareas`.

Además llama RPC de inventario, reparto, restauración, fusión, caja y Lama. `lamaLlamar(fn, args)` acepta nombres dinámicos de las funciones comerciales enumeradas arriba. Las verificaciones `PERMISOS.*` son controles de experiencia de usuario y pueden evitar accidentes normales, pero no accesos directos.

## 7. Mapa de acciones sensibles

| Acción | Ruta técnica actual | Autorización real | Riesgo | Recomendación S1 |
|---|---|---|---|---|
| Dar/cambiar permisos | Data API a `app_permisos` | anon UPDATE; auth INSERT/UPDATE, sin UID | Autoescalamiento y exposición de correos | Cerrar DML/lectura global; raíz por UID; RPC raíz auditada |
| Revocar permisos | UPDATE directo | Reglas de último admin solo en JS | Bloqueo o escalamiento deliberado | Invariante transaccional servidor y recuperación |
| Crear/editar/archivar productos | Data API `productos`; RPC enlazado | anon/auth; `puede_editar` solo UI | Alteración de catálogo; stock histórico | RPC por capacidad, sede y campos permitidos |
| Eliminar productos | Sin DELETE directo efectivo; fusiones/apagado | RPC anon privilegiada o UPDATE abierto | Borrado lógico/fusión no autorizada | RPC autenticada, auditoría y autorización por operación |
| Editar sedes | `sede_registro` | Solo lectura de cliente | Bajo | Mantener cerrada; endpoint raíz si se requiere |
| Editar áreas/asignaciones | Tablas cerradas; no UI | Sin ruta actual | Seguro hoy | Implementar después de S1 mediante RPC administrativa |
| Cambiar Ajustes | UPSERT `ajustes` | `ALL` anon/auth | Cualquiera cambia modo demo/Fudo/UI | RPC admin operativa; quitar DML directo |
| Transferencias del ledger | `stock_transferir` | sesión + email + `puede_editar` autoeditable | Escalamiento autenticado | Migrar chequeo a capacidad por UID confiable |
| Entradas/mermas/ajustes legacy | RPC definer + `movimientos` | anon; triggers bloquean sedes migradas | Sedes históricas y auditoría expuestas | RPC autenticada por sede; retirar funciones internas públicas |
| Modificar stock/lotes | `productos`, `producto_lotes`, RPC legacy | anon; guardas solo central/plaza | Stock histórico modificable | Prohibir DML directo; unificar escritores al ledger |
| Repartos/deshacer | tablas + RPC definer | anon; guardas parciales | Datos logísticos alterables | RPC autenticada, transición al motor nuevo |
| Activar origen POS | tabla interna | sin acceso cliente | Seguro hoy | Mantener interna; solo propietario raíz |
| Configurar/ejecutar Fudo | `fudo_sync`, Edge | config anon; Edge con guard, capacidades incompletas | Activación futura abriría proxy privilegiado | Separar sistema/usuario; capacidad por UID; mantener guard POS |
| Ejecutar Lama real | config/puente interno | puente cerrado y apagado | Bajo en stock | Mantener; corregir primero autorización comercial |
| Mesas/comandas | tablas + RPC definer | anon | Manipulación comercial | Capacidad Lama por sesión y sede |
| Cobros/descuentos/cierres | RPC `cuenta_*` | anon; actor declarativo | Fraude/integridad crítica | Requerir sesión, capacidad y auditor UID inmutable |
| Caja/arqueos | tablas + RPC `arqueo_*` | anon | Manipulación de caja | Capacidad específica y controles de cierre |
| Reportes/exportaciones | SELECT abierto en casi todo `public` | anon | Fuga de datos operativos/personales | Lectura autenticada por sede/capacidad; vistas invoker |

## 8. Arquitectura de transición propuesta para S1

No se incluye SQL ejecutable. La secuencia recomendada es:

1. **Decisión de identidad.** Alejo identifica por un canal privado cuál de los dos usuarios Auth confirmados es suyo. Registrar un único `propietario_raiz` por `auth.uid()`; nunca por correo, nombre o `user_metadata`.
2. **Fuente de autorización no editable por cliente.** Crear o adaptar una tabla cerrada que vincule `user_id uuid` con capacidades. El navegador no recibe INSERT/UPDATE/DELETE. Las siete filas sin usuario Auth quedan como invitaciones históricas o se archivan; no conceden capacidad hasta que exista una identidad Auth enlazada explícitamente.
3. **Separar gobierno y operación.** Solo `propietario_raiz` concede/revoca capacidades. `administrador_operativo` puede usar módulos autorizados, pero jamás modificar permisos ni dueño. Capacidades iniciales pueden mapear lo existente: inventario, áreas, Lama, Fudo, caja, reportes y Ajustes operativos.
4. **RPC mínima de gobierno.** Entrada autenticada, validación de `auth.uid()` contra raíz, `search_path` vacío, cuerpo interno fuera del esquema expuesto, EXECUTE explícito y auditoría inmutable de antes/después. No usar `SECURITY DEFINER` en `public` sin revocar PUBLIC.
5. **Corte de `app_permisos`.** Primero adaptar todas las lecturas y Edge Functions; después revocar DML y lectura anónima. Mantener una vista de compatibilidad solo si es invoker y entrega al usuario únicamente sus propias capacidades.
6. **Cerrar la superficie anónima por dominio.** Orden sugerido: permisos/Ajustes; Lama/caja; RPC definer; productos/recetas; logística/stock legacy; reportes. Cada corte debe tener inventario de clientes, pruebas de sesión y rollback documental.
7. **Edge Functions.** Distinguir llamadas de sistema mediante secreto interno de llamadas de persona mediante JWT; ambas validan además origen POS. Las llamadas personales comprueban capacidad por UID. Retirar funciones diagnósticas desplegadas cuando dejen de ser necesarias.
8. **Recuperación de emergencia.** Runbook fuera de la aplicación: acceso al proyecto Supabase con MFA, comprobación de identidad, transacción auditable que restaura exactamente un propietario raíz, rotación/revocación de sesiones si corresponde y verificación posterior. No crear llave maestra en el navegador.

## 9. Objetos a cambiar en S1 y riesgo de regresión

### Prioridad S1

- `app_permisos`, su UI en `index.html` y toda lectura de `PERMISOS`.
- Políticas/grants de `ajustes` y configuración administrativa.
- Los 40 RPC `SECURITY DEFINER` anónimos, empezando por `cuenta_*`, `arqueo_*`, `mesa_abrir`, `item_anular`, `items_mover` y funciones de stock/logística.
- Políticas de las 36 tablas `ALL true`.
- Las seis Edge Functions Fudo desplegadas y cualquier fuente local que se despliegue después.
- Vistas `dias_de_historial`, `dias_de_historial_auto`, `gemelos_propuestos`.
- `stock_transferir` y su helper solo para cambiar la fuente de capacidad; su motor y atomicidad no requieren rediseño.

### Riesgos de romper módulos

- La aplicación depende intensamente de DML directo; cerrar todo en una migración única rompería Inventario, Ajustes, Lama, repartos, recetas, tareas y metas.
- Realtime de Lama necesita que SELECT siga autorizado para el usuario correcto.
- Edge Functions usan `service_role`; revocar grants sin revisar sus consultas puede detener Fudo aunque el guard POS sea correcto.
- Los dos usuarios Auth actuales tienen capacidades amplias, mientras siete filas no tienen cuenta. Migrar por correo automáticamente convertiría registros históricos en autorizaciones futuras y no es aceptable.
- Los triggers B2.3 son una defensa independiente y deben permanecer durante toda la transición.
- La interfaz conserva permisos en memoria cuando falla una relectura. Tras S1, las operaciones sensibles deben revalidarse siempre en servidor; no depender de esa caché.

## 10. Consultas y verificaciones ejecutadas

Solo SELECT/catálogos:

- `information_schema.columns`, `pg_indexes`, `pg_constraint` para estructura de Auth y permisos.
- agregados anonimizados de `auth.users` y `app_permisos`, sin devolver identificadores.
- `pg_class`, `pg_namespace`, `pg_policy`/`pg_policies`, `has_table_privilege`, grants de tabla/columna.
- `pg_proc`, `has_function_privilege`, configuración, propietario y análisis de cuerpos instalados.
- `information_schema.triggers` y `pg_get_viewdef`.
- estado agregado de origen POS, Fudo y Lama Stock.
- listado y lectura de fuentes desplegadas de Edge Functions; no invocación.
- Supabase Security Advisors y documentación vigente de RLS/autorización.
- búsquedas locales de Data API, RPC, Edge, Auth y permisos en `index.html` y fuentes Fudo/Lama.

No se ejecutaron migraciones, DML, RPC operativos, Edge Functions ni pruebas de escritura. No se modificaron RLS, grants, usuarios, datos, configuración o código funcional. No se accedió, consultó, modificó ni infirió información de Café del Desierto / Llamita Stock.

## 11. Decisión pendiente

Alejo debe designar de forma privada cuál cuenta Auth existente corresponde al futuro `propietario_raiz` y aprobar el mecanismo de recuperación. Hasta entonces no se puede construir una migración S1 segura ni reanudar B3.2a. S1 y B3.2b no quedan activadas automáticamente.
