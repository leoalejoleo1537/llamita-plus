# S2 — verificación real de seguridad y regresión

Fecha: 2026-10-07

Estado: **REQUIERE DECISIÓN**

Repositorio: `leoalejoleo1537/llamita-plus`

Supabase: `llamita-plus` (`iuryhsjucblmebdogewa`)

## Resultado ejecutivo

La protección instalada por S1 pasó las pruebas directas anónimas de Data API, las comprobaciones de grants/RLS/RPC y las pruebas transaccionales de roles. No se encontró una ruta de elevación en `app_permisos` ni una regresión en las lecturas operativas ensayadas.

La automatización inicial no dispuso de contraseñas, access tokens ni refresh tokens de las dos cuentas existentes, por lo que no fabricó JWT ni alteró Auth. Alejo completó después la prueba manual con sesiones reales de ambas cuentas, sin compartir credenciales, tokens ni secretos. Las rutas de sesión quedaron cubiertas, pero la comprobación posterior encontró una contradicción en la auditoría y S2 no puede cerrarse todavía.

No se ejecutaron migraciones ni cambios de código, esquema, permisos o datos persistentes.

## Pruebas ejecutadas

### Data API anónima real

Se utilizó exclusivamente la clave pública ya incluida en el cliente. No se imprimió ni documentó su valor.

| Ruta | Resultado |
|---|---|
| `GET app_permisos` | HTTP 401, permiso de tabla denegado |
| `POST app_permisos` | HTTP 401, permiso de tabla denegado |
| `PATCH` de capacidades | HTTP 401, permiso de tabla denegado |
| `PATCH auth_uid` | HTTP 401, permiso de tabla denegado |
| `DELETE app_permisos` | HTTP 401, permiso de tabla denegado |
| RPC `permisos_listar` | HTTP 401, EXECUTE denegado |
| RPC `permisos_actualizar` | HTTP 401, EXECUTE denegado |
| Edge `fudo-deshacer-stock` sin JWT | HTTP 401; no llegó a Fudo |

PostgREST no expone una operación TRUNCATE ordinaria. La comprobación efectiva de PostgreSQL confirma `TRUNCATE=false` para `anon`, `authenticated` y `service_role`.

Todas las escrituras anónimas fueron rechazadas antes de persistir. La fila ficticia utilizó una identidad inexistente y no quedó ningún registro.

### Roles y RPC dentro de transacción revertida

Un bloque `BEGIN ... ROLLBACK` validó:

- propietario raíz con capacidades efectivas completas;
- lectura propia y listado global del propietario;
- dos cambios temporales sobre la cuenta operativa y dos auditorías asociadas;
- rechazo de degradación del propietario;
- rechazo de UPDATE/DELETE sobre la auditoría;
- cuenta operativa con editar, Fudo y Ajustes habilitados, Lama apagado;
- RLS limitado a una sola fila propia;
- rechazo de listado global, INSERT, UPDATE, DELETE y TRUNCATE para la cuenta operativa;
- rechazo de modificar su propio `puede_ajustes`, elevar un tercero o modificar la raíz;
- usuario común sin capacidades y sin acceso administrativo;
- lectura `service_role` de las dos filas vinculadas que necesita Fudo;
- rollback total: auditoría persistente en cero y capacidades originales intactas.

Estas pruebas usan los UUID reales y las definiciones instaladas. El contexto JWT automatizado se inyectó de forma transaccional y fue complementado después por la prueba manual con sesiones GoTrue reales.

### Regresión operativa

- `stock_transferir`: la cuenta operativa supera la autorización y llega a la validación normal del motor; no se ejecutó una transferencia válida.
- Inventario por áreas: `stock_leer_areas()` devolvió datos como rol autenticado.
- Bodega: la lectura autenticada de productos `central` devolvió datos.
- Ledger: 150 filas y 4.750,5 unidades en Bodega; 258 filas y 4.566,2 unidades en Local 1; cero transferencias persistentes.
- Fudo: `service_role` conserva SELECT sobre `app_permisos`; la Edge rechaza ausencia de sesión y no se invocó ninguna operación remota.
- Login/carga de permisos: `permisos_mios()` devolvió el perfil esperado para ambos contextos transaccionales. La interfaz no pudo probarse con login real por falta de credenciales y navegador.
- `npm test`: pasó. Las pruebas que requieren Chromium se omitieron porque no hay navegador instalado.

## Grants, RLS y funciones

`app_permisos` mantiene:

| Rol | SELECT | INSERT | UPDATE | DELETE | TRUNCATE |
|---|---:|---:|---:|---:|---:|
| `anon` | no | no | no | no | no |
| `authenticated` | sí | no | no | no | no |
| `service_role` | sí | no | no | no | no |

Solo existe `app_permisos_lectura_propia`, SELECT para `authenticated`, con `auth_uid = (select auth.uid())`. No apareció una política abierta nueva.

`permisos_mios`, `permisos_listar` y `permisos_actualizar` siguen siendo `SECURITY DEFINER`, con `search_path=''`, objetos calificados y validación interna de `auth.uid()`. `PUBLIC`, `anon` y `service_role` no tienen EXECUTE; `authenticated` sí, y las dos operaciones administrativas vuelven a comprobar la tabla raíz privada.

## Advisors

Los advisors no atribuyen hallazgos nuevos a las tres RPC S1. Persisten los riesgos heredados y fuera del alcance autorizado:

- 40 funciones `SECURITY DEFINER` legacy ejecutables por `anon`;
- tres vistas con privilegios del creador;
- diez funciones con `search_path` mutable;
- políticas permisivas duplicadas y tablas operativas heredadas abiertas;
- tablas internas con RLS sin políticas, intencionalmente cerradas y sin grants.

Referencias: [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), [advisor de funciones anónimas](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable) y [advisor de vistas](https://supabase.com/docs/guides/database/database-linter?lint=0010_security_definer_view).

## Estado operativo posterior

Los conteos permanecen idénticos a S1: 1.437 productos; stock 15.438; 431 movimientos; 42 lotes; 59 cuentas; 30 pagos; 2 movimientos de caja; 0 eventos Lama–Stock; 15.357 movimientos Fudo; 9 filas de permisos; 0 auditorías y 0 transferencias.

Fudo permanece en modo prueba con cron apagado. Lama real continúa apagado y su configuración está vacía. El origen POS sigue `ninguno` para las cuatro claves registradas. Bodega y el ledger conservaron sus lecturas. No hubo contacto con Fudo remoto.

## Prueba manual con sesiones reales

Alejo confirmó la ejecución manual:

- cuenta raíz: login correcto, acceso a administración, lectura global, otorgamiento y revocación correctos, con auditoría generada;
- cuenta operativa: login y operación normal correctos, administración global no disponible, modificación directa y autoelevación rechazadas;
- no se compartieron contraseñas, JWT ni secretos.

La comprobación de solo lectura inmediatamente posterior devolvió `0` filas en `authz_internal.permisos_auditoria`, aunque el ensayo manual reportó una auditoría generada. Una concesión y revocación persistentes deberían dejar registros inmutables incluso cuando las capacidades terminen restauradas. La cuenta operativa sí quedó con sus capacidades esperadas: editar/Fudo/Ajustes habilitados, Lama apagado y cero bloqueos Fudo.

Esta discrepancia afecta un criterio crítico. S2 permanece `REQUIERE DECISIÓN` hasta reproducir una única modificación controlada y confirmar la fila auditada en la base. No se activa B3.2a ni ninguna fase siguiente.

No se accedió ni modificó Café del Desierto / Llamita Stock.
