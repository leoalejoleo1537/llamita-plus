# S1 — identidad raíz y gobierno seguro de permisos

Fecha: 2026-10-07

Estado: **COMPLETADA**

Repositorio: `leoalejoleo1537/llamita-plus`

Supabase: `llamita-plus` (`iuryhsjucblmebdogewa`)

## Resultado

S1 reemplaza la autorización autoeditable por una identidad raíz vinculada a `auth.uid()`. El UUID aprobado existe, está confirmado y no es anónimo. No se publica ningún correo completo en este informe.

`authz_internal.propietario_raiz` contiene una sola fila singleton. La pertenencia a esa tabla otorga capacidades efectivas completas mediante `permisos_mios()` y `permisos_listar()`, aunque los booleanos heredados sean distintos. No existe una RPC normal para cambiar, eliminar o degradar esa fila.

La segunda cuenta Auth conserva exactamente `puede_editar=true`, `puede_fudo=true`, `puede_ajustes=true`, `puede_lama=false` y `fudo_bloqueos={}`. Es administrador operativo y no puede listar ni modificar permisos.

## Modelo y permisos

Objetos creados:

- `authz_internal.propietario_raiz`: singleton privado con FK restrictiva a `auth.users`.
- `authz_internal.permisos_auditoria`: cambios inmutables, actor y objetivo por UUID, estados antes/después.
- `authz_internal.app_permisos_pre_s1`: foto privada para rollback técnico previo a actividad posterior.
- `public.app_permisos.auth_uid`: FK y unicidad por usuario Auth.

Las dos cuentas Auth actuales quedaron vinculadas mediante UUID explícitos. Las siete filas históricas sin cuenta Auth se conservan con `auth_uid=null`, todas sus capacidades apagadas y un constraint que impide capacidades sin identidad.

Grants finales de `app_permisos`:

| Rol | SELECT | INSERT/UPDATE/DELETE/TRUNCATE |
|---|---|---|
| `anon` | no | no |
| `authenticated` | sí, solo fila propia por RLS | no |
| `service_role` | sí, por compatibilidad con Edge | no |

La única política es `app_permisos_lectura_propia`, con `auth_uid = (select auth.uid())`. `service_role` conserva únicamente la lectura necesaria para `fudo-deshacer-stock`; su `BYPASSRLS` no le concede DML porque los grants fueron revocados.

## RPC y aplicación

- `permisos_mios()`: devuelve exclusivamente capacidades efectivas del usuario actual; la raíz recibe todo habilitado.
- `permisos_listar()`: solo la raíz puede listar cuentas Auth confirmadas.
- `permisos_actualizar(...)`: solo la raíz puede actualizar una cuenta Auth confirmada y no anónima. Rechaza como objetivo al propietario raíz y registra auditoría.

Las tres son `SECURITY DEFINER`, `search_path=''`, usan objetos calificados y validan internamente `auth.uid()` y el rol JWT. `EXECUTE` está denegado a `PUBLIC`, `anon` y `service_role`; `authenticated` puede invocarlas, pero las operaciones administrativas vuelven a comprobar el singleton raíz.

La interfaz carga permisos con `permisos_mios()`. “Personas y acceso” y los permisos por persona de Fudo solo aparecen para la raíz. `puede_ajustes` mantiene el acceso operativo a Ajustes sin otorgar gobierno de usuarios. La creación de cuentas Auth no se trasladó a la aplicación.

`stock_transferir` y su helper conservan firmas y lógica de inventario. Solo cambió el chequeo de capacidad para usar `permisos_mios()` ligado al UUID. La prueba demostró que la segunda cuenta supera autorización y llega a la validación normal del motor.

## Edge Functions

Las seis Edge desplegadas se inspeccionaron. Ninguna ejecuta DML sobre `app_permisos`. `fudo-deshacer-stock` realiza SELECT con `service_role`; la consulta equivalente continúa devolviendo las dos cuentas vinculadas con permiso Fudo. No se redesplegó ni invocó ninguna Edge y no se consultó Fudo remoto.

## Pruebas

`sql/2026-10-s1-pruebas-transaccionales.sql` ejecutó `BEGIN ... ROLLBACK` y verificó:

- singleton y UUID raíz exacto;
- capacidades completas de raíz;
- gestión y auditoría por raíz;
- rechazo de degradación de raíz;
- rechazo de listar/gestionar por administrador operativo;
- usuario común sin fila ni capacidad de elevación;
- anon sin lectura ni DML;
- authenticated con una sola fila propia y sin DML;
- service role con lectura y sin DML;
- continuidad del chequeo de `stock_transferir`;
- rollback sin auditoría ni cambio persistente de permisos.

Conteos pre/post idénticos: 1.437 productos; stock 15.438,00; 431 movimientos; 42 lotes; 59 cuentas; 30 pagos; 2 movimientos de caja; 0 eventos Lama–Stock; 15.357 movimientos Fudo; 9 filas de permisos. La auditoría quedó vacía porque todas las pruebas se revirtieron.

`npm test` pasó. Las pruebas que requieren Chromium se omitieron por falta de navegador instalado. `git diff --check` pasó. Los advisors no detectan funciones S1 anónimas ni `search_path` mutable; mantienen hallazgos globales de S0 fuera de alcance. Las tablas privadas sin políticas aparecen como información intencional: no tienen grants y RLS está forzada.

## Migraciones y rollback

Fuentes:

- `supabase/migrations/20261007215032_s1_identidad_raiz_gobierno_permisos.sql`
- `supabase/migrations/20261007215848_s1_indices_auditoria_permisos.sql`
- `sql/2026-10-s1-identidad-raiz-gobierno-permisos.rollback.sql`

Versiones instaladas en Supabase:

- `20261007215657_s1_identidad_raiz_gobierno_permisos`
- `20261007215900_s1_indices_auditoria_permisos`

El rollback técnico solo corre si `permisos_auditoria` sigue vacía. Restaura funciones, capacidades heredadas desde la foto privada, columna, grants y políticas previas; después del primer cambio real debe usarse recuperación compensatoria, no borrar auditoría. La recuperación del propietario es externa: acceso Supabase con MFA, verificación de UUID, transacción con lock, cambio del singleton y revocación de sesiones anteriores.

## Pendiente separado

S1 no cerró las otras 36 tablas, las 40 funciones privilegiadas heredadas, Lama, caja, recetas, Fudo operativo, productos, logística o reportes. Esas fases deben activarse y probarse por separado para evitar romper la aplicación.

No se accedió a Café del Desierto / Llamita Stock.
