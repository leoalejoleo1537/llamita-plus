# S2 — verificación real de seguridad y regresión

Fecha: 2026-10-08

Estado: **COMPLETADA**

Repositorio: `leoalejoleo1537/llamita-plus`

Supabase: `llamita-plus` (`iuryhsjucblmebdogewa`)

## Resultado ejecutivo

La protección instalada por S1 pasó las pruebas directas anónimas de Data API, las comprobaciones de grants/RLS/RPC y las pruebas transaccionales de roles. No se encontró una ruta de elevación en `app_permisos` ni una regresión en las lecturas operativas ensayadas.

La automatización inicial no dispuso de contraseñas, access tokens ni refresh tokens de las dos cuentas existentes, por lo que no fabricó JWT ni alteró Auth. Alejo completó después la prueba manual con sesiones reales de ambas cuentas, sin compartir credenciales, tokens ni secretos. La prueba persistente final confirmó dos auditorías inmutables y cerró la contradicción inicial.

No se ejecutaron migraciones ni cambios de código, esquema o permisos. Las únicas filas persistentes nuevas son las dos auditorías exigidas como evidencia.

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

Los conteos operativos permanecen idénticos a S1: 1.437 productos; stock 15.438; 431 movimientos; 42 lotes; 59 cuentas; 30 pagos; 2 movimientos de caja; 0 eventos Lama–Stock; 15.357 movimientos Fudo; 9 filas de permisos y 0 transferencias. La auditoría contiene 2 filas, ambas creadas intencionalmente por la prueba persistente final.

Fudo permanece en modo prueba con cron apagado. Lama real continúa apagado y su configuración está vacía. El origen POS sigue `ninguno` para las cuatro claves registradas. Bodega y el ledger conservaron sus lecturas. No hubo contacto con Fudo remoto.

## Prueba manual con sesiones reales

Alejo confirmó la ejecución manual:

- cuenta raíz: login correcto, acceso a administración, lectura global, otorgamiento y revocación correctos, con auditoría generada;
- cuenta operativa: login y operación normal correctos, administración global no disponible, modificación directa y autoelevación rechazadas;
- no se compartieron contraseñas, JWT ni secretos.

La comprobación de solo lectura inmediatamente posterior devolvió `0` filas en `authz_internal.permisos_auditoria`, aunque el ensayo manual reportó una auditoría generada. Una concesión y revocación persistentes deberían dejar registros inmutables incluso cuando las capacidades terminen restauradas. La cuenta operativa sí quedó con sus capacidades esperadas: editar/Fudo/Ajustes habilitados, Lama apagado y cero bloqueos Fudo.

Esta discrepancia se mantuvo como criterio crítico hasta ejecutar la prueba persistente descrita al final. B3.2a no se activa automáticamente.

## Investigación de la auditoría

La inspección de las definiciones instaladas confirmó:

- `authz_internal.permisos_auditoria` pertenece a `postgres`, tiene RLS habilitada y forzada, cero políticas y grants únicamente para `postgres`;
- `anon`, `authenticated` y `service_role` no pueden leerla directamente;
- el conteo de cero fue ejecutado como rol privilegiado `postgres`, por lo que las filas no están ocultas por RLS;
- el trigger `permisos_auditoria_inmutable` se ejecuta antes de UPDATE o DELETE y siempre lanza `42501`; no bloquea INSERT;
- `permisos_actualizar(...)` es `SECURITY DEFINER`, pertenece a `postgres`, fija `search_path=''` e inserta `estado_anterior`, `estado_nuevo`, actor, objetivo, acción y fecha inmediatamente después del UPDATE de `app_permisos`;
- el cambio y su auditoría están en la misma transacción. Un COMMIT conserva ambos; un error o ROLLBACK elimina ambos;
- las pruebas automatizadas S1/S2 terminaron explícitamente con `ROLLBACK`, por lo que sus filas temporales debían desaparecer;
- la segunda cuenta conserva los valores originales, pero eso por sí solo no demuestra una concesión/revocación: una restauración exitosa habría dejado dos filas inmutables.

Los logs de Data API posteriores a la instalación de S1 contienen un único POST a `/rest/v1/rpc/permisos_actualizar`, correspondiente a la prueba anónima automatizada, con HTTP 401. No hay una llamada autenticada exitosa registrada. Por tanto, la causa del conteo cero es que no hubo una ejecución persistente confirmada de la RPC: las ejecuciones SQL fueron revertidas y la acción manual reportada no alcanzó ese endpoint con éxito.

## Probe controlado solicitado

No se ejecutó ninguna escritura. Fallaron dos precondiciones antes de llamar la RPC:

1. El entorno no dispone del access token o refresh token de la sesión raíz real. La existencia de una fila en `auth.sessions` no permite reconstruir ni extraer un token reutilizable, y no se fabricaron JWT ni se cambiaron credenciales.
2. La definición instalada admite únicamente `boton`, `ficha`, `todo`, `reparto`, `merma`, `crear`, `apagar` y `deshacer` en `fudo_bloqueos`. El valor solicitado `s2-audit-probe` produciría `22023: Existe un bloqueo Fudo desconocido` antes del UPDATE y del INSERT de auditoría.

Usar otro bloqueo habría cambiado el caso aprobado; ampliar la lista requeriría una migración prohibida; simular el JWT no sería una sesión raíz real. Conforme a la regla de detención, en ese momento S2 siguió `REQUIERE DECISIÓN`. La situación fue resuelta posteriormente mediante el valor válido `boton` y una sesión Auth real.

## Cierre persistente de la auditoría

Alejo, autenticado como propietario raíz real, ejecutó desde la interfaz las dos operaciones aprobadas mediante `permisos_actualizar`:

1. `fudo_bloqueos: [] → ["boton"]`.
2. `fudo_bloqueos: ["boton"] → []`.

Los logs de Data API registran ambas llamadas reales con HTTP 200, a las 17:27:26 y 17:29:23 UTC del 2026-10-08. No fueron consultas SQL ni transacciones revertidas. La consulta privilegiada de servidor confirmó que `authz_internal.permisos_auditoria` conserva las filas 7 y 8, ambas con el propietario raíz como actor, la segunda cuenta como objetivo, acción `actualizar_permisos`, fecha y los estados anterior/nuevo esperados.

La cuenta operativa terminó exactamente con:

- `puede_editar=true`;
- `puede_fudo=true`;
- `puede_ajustes=true`;
- `puede_lama=false`;
- `fudo_bloqueos=[]`.

No cambiaron productos, stock, lotes, movimientos, ventas, caja, eventos Lama, movimientos Fudo ni áreas. No hubo llamada a Fudo remoto. Con esta evidencia persistente, S2 queda **COMPLETADA**.

No se accedió ni modificó Café del Desierto / Llamita Stock.
