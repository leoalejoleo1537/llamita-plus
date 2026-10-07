# B2.3.1 — Blindaje de conectores POS y origen activo por sede

**Fecha:** 2026-10-07
**Estado:** COMPLETADA; ningún POS quedó activo.
**Repositorio:** `leoalejoleo1537/llamita-plus`
**Supabase:** Llamita Plus `iuryhsjucblmebdogewa`
**Siguiente bloque:** B2.4 queda PENDIENTE, no activado.

## 1. Diagnóstico de configuración vigente

La inspección del esquema instalado encontró:

- `public.fudo_sync`: sede, modo de Fudo, cursor y estado de corrida; no define el origen POS único.
- `public.lama_stock_config`: sede y modo de Lama; no define el origen POS único.
- `public.ajustes`: `clave`, `sede`, `valor` booleano y auditoría; son flags, no una selección de proveedor.
- `public.app_permisos`: incluye `puede_ajustes` y `puede_fudo`, pero no autoriza cambios de la configuración privada del libro.

No había tabla ni RPC existentes que representaran una sola fuente POS de inventario por sede. La selección queda guardada en la relación privada nueva `stock_internal.origen_pos`:

| Sede | Origen inicial | Restricción |
| --- | --- | --- |
| `plaza` | `ninguno` | Admite `fudo`, `lama`, `toteat`, `ninguno` o `prueba`; solo un valor por sede. `prueba` no habilita escritura. |
| `central` | `ninguno` | Solo acepta `ninguno`; Bodega no opera como POS de ventas. |
| `angamos` | `ninguno` | Archivada; no acepta un origen activo. |
| `bodega` | `ninguno` | Clave histórica independiente; no acepta un origen activo. |

Una clave primaria en `sede` hace imposible almacenar dos selecciones para una misma sede. `CHECK` impide seleccionar proveedores para central, angamos o bodega histórica.

## 2. Seguridad de la configuración

`stock_internal.origen_pos` tiene RLS y política restrictiva de denegación. Se revocaron permisos de `PUBLIC`, `anon`, `authenticated` y `service_role` sobre la tabla y el esquema; la API no puede leerla ni modificarla directamente.

`public.stock_pos_origen_permitido(p_sede,p_origen)` es una función `SECURITY DEFINER` de comprobación, con `search_path` vacío y `EXECUTE` solo para `service_role`. La función interna `stock_internal.origen_pos_es` no tiene ejecución para roles API. En la comprobación SQL final: helper público `anon=false`, `authenticated=false`, `service_role=true`; tabla interna sin permisos de lectura/escritura para los tres roles.

No se creó un RPC para cambiar el origen ni se dio mutación a navegador o servicio. Un selector futuro debe pasar por un endpoint/RPC backend que autentique a la persona y verifique `app_permisos.puede_ajustes`, luego cambie la fila dentro de una operación auditada. El permiso existente no se interpreta como acceso directo a la tabla. Si se requiere delegación más limitada que Ajustes, debe aprobarse una capacidad administrativa dedicada.

## 3. Protecciones Fudo y Lama

### Fudo

- Se añadió una guarda al `pg_get_functiondef` real instalado de `public.fudo_procesar_item`; abortaba la migración si la firma/cuerpo esperado no coincidía. Ante ausencia de Fudo como origen, rechaza antes de leer o modificar `fudo_sync`, crear eventos o invocar descuentos.
- Se revocó `EXECUTE` de `PUBLIC`, `anon` y `authenticated` a `fudo_procesar_item`; solo `service_role` puede llamarla. La Edge Function autorizada sigue pudiendo usarla.
- Un trigger en `public.fudo_movimientos` rechaza cualquier inserción o cambio relevante si Fudo no es el origen activo, incluso si se llama directamente al DML.
- Las seis Edge Functions que procesan ventas o hacen escrituras/reversiones en inventario ejecutan la comprobación antes de comunicarse con Fudo o modificar datos comerciales. Si el RPC de autorización no está disponible, responden cerrado (503); si Fudo no es origen, responden 409.
- `fudo-ciclo` valida el origen antes de llamar a sync de ventas o al empuje. `fudo-sync-ventas` también valida por sí misma, para cubrir invocación directa.

### Lama

- Un trigger de `lama_stock_config` rechaza `modo='real'` si el origen por sede no es `lama`.
- Se añadió una comprobación al `pg_get_functiondef` instalado de `lama_stock_aplicar_evento(uuid)` antes de procesar ingredientes reales. Un evento capturado en modo real no se aplica si Lama dejó de ser el origen activo.
- Un trigger de `lama_stock_aplicaciones` bloquea estados `pendiente/aplicado` para un evento real sin origen Lama. Los marcadores `error` quedan permitidos para la ruta de error controlada.
- Se conserva además el bloqueo general de modo real de B2.3 para las sedes migradas. Esta fase no activa el modo real ni crea configuración de Lama.

Toteat solo aparece como valor reservado de la restricción en `plaza`; no se implementó ni se desplegó conector Toteat.

## 4. Edge Functions desplegadas

Antes de desplegar, Supabase listó cero Edge Functions. Se desplegaron seis versiones iniciales en `ACTIVE`, todas con `verify_jwt=true` y release marker `2026-10-07-b2.3.1`:

| Función | ID de despliegue | Versión Supabase | Verificación de fuente |
| --- | --- | ---: | --- |
| `fudo-ciclo` | `4fae4f58-5e9f-47d1-8113-103208e5776a` | 1 | helper y marker presentes |
| `fudo-sync-ventas` | `9cfafef5-407d-478e-b7e2-1ab27132ef0e` | 1 | helper y marker presentes |
| `fudo-empujar-stock` | `6a7919ce-450e-49af-ab97-85de7e2b60ea` | 1 | helper y marker presentes |
| `fudo-deshacer-stock` | `98c990df-1ee4-4308-bfe8-97b2648193e9` | 1 | helper y marker presentes |
| `fudo-sumar-stock` | `a5577132-a602-47e2-b9eb-33633db845e1` | 1 | helper y marker presentes |
| `fudo-probar-escritura` | `fe32f2f7-93cd-4fd5-9924-9e1ef24f50b2` | 1 | helper y marker presentes |

Las seis fuentes fueron recuperadas tras desplegar; Supabase confirmó `ACTIVE`, `verify_jwt=true`, marker y referencia a `stock_pos_origen_permitido` en cada archivo. Una llamada HTTP sin JWT a `fudo-sync-ventas` devolvió `401 UNAUTHORIZED_NO_AUTH_HEADER` antes de entrar al handler. No se invocó ningún endpoint con credenciales de Fudo ni se hizo una llamada de escritura a Fudo.

## 5. Pruebas e integridad

`sql/2026-10-b2-3-1-pruebas-origen-pos.sql` corrió en `BEGIN ... ROLLBACK`; terminó sin errores. Probó:

- `plaza` en `ninguno` y en `prueba`: Fudo y Lama no reciben permiso de escritura.
- Una segunda configuración para `plaza` falla por unicidad.
- Intentar asignar Fudo a `central`, Lama a `angamos` o Toteat a `bodega` falla por `CHECK`.
- Llamada directa a `fudo_procesar_item` y DML directo de un movimiento Fudo fallan por origen inactivo.
- Activar Lama en real en `plaza` falla antes de crear configuración.
- Ejecución SQL como `service_role` al helper devuelve `false` para Fudo y Lama en `plaza`.
- ACL de helper, RPC de Fudo y tabla interna; presencia de las guardas instaladas en las funciones Fudo/Lama.

Conteos y estado persistente verificados después de las pruebas:

| Medida | Estado final |
| --- | ---: |
| Configuración POS | 4 filas, todas `ninguno` |
| `fudo_sync` de `plaza` | `prueba`, cron apagado |
| `lama_stock_config` | 0 filas |
| Productos / stock agregado | 1.437 / 15.438,00 |
| Movimientos legacy | 431 |
| `fudo_movimientos` | 15.357 |

No hubo cambios en stock, lotes, ventas, movimientos, Fudo remoto, recetas ni datos comerciales. El estado de `angamos` sigue archivado; `bodega` sigue histórica.

La migración aplicada fue `20261007162948 b2_3_1_pos_origin_guard`; fuente versionada: `supabase/migrations/20261007162700_b2_3_1_pos_origin_guard.sql`. La suite `npm test`, compilación/sintaxis Edge con esbuild y `git diff --check` pasaron. Las comprobaciones de advisors no encontraron avisos nuevos asociados al origen POS; permanecen hallazgos previos en vistas/funciones y tablas ajenas a esta migración.

## 6. Riesgos y límites operativos

- Ningún POS está activo. Los flujos de inventario de Fudo y Lama deben permanecer detenidos hasta que una decisión administrativa cambie el origen y una fase posterior adapte al libro los escritores que B2.3 mantiene bloqueados.
- La tabla todavía no tiene selector ni ruta de modificación administrativa; cambiarla requiere migración/operación backend revisada. La UI de Ajustes no puede hacerlo.
- Fudo sigue en modo prueba y cron apagado para `plaza`. Aunque la fila de origen permitiera Fudo en el futuro, este hecho por sí solo no levanta las protecciones de stock de B2.3.
- Se desplegaron únicamente los seis endpoints POS relacionados con procesamiento/escritura de inventario. Los endpoints de catálogo Fudo no se desplegaron como parte de este bloque.
- El rechazo HTTP de endpoint se comprobó sin JWT; la ruta con JWT llegó hasta la verificación de origen en pruebas de código/SQL, pero no se usó una sesión real ni credenciales Fudo para evitar efectos comerciales/remotos.

No se accedió a Café del Desierto / Llamita Stock. B2.4 continúa pendiente y no se activó automáticamente.

## 7. Archivos

- Migración: `supabase/migrations/20261007162700_b2_3_1_pos_origin_guard.sql`.
- Prueba: `sql/2026-10-b2-3-1-pruebas-origen-pos.sql`.
- Edge Functions: `supabase/functions/fudo-ciclo/index.ts`, `fudo-sync-ventas/index.ts`, `fudo-empujar-stock/index.ts`, `fudo-deshacer-stock/index.ts`, `fudo-sumar-stock/index.ts`, `fudo-probar-escritura/index.ts`.
- Hermes: cola `03`, bitácora `04`, canal `06`, plan `01` y este resultado.
