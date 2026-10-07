# B3.2a — bloqueo de autorización para gestión de áreas

Fecha: 2026-10-07
Estado: **REQUIERE DECISIÓN**
Repositorio: `leoalejoleo1537/llamita-plus`
Supabase consultado: `llamita-plus`, ref `iuryhsjucblmebdogewa`

## Resultado

B3.2a se detuvo durante el preflight de seguridad, antes de modificar código o base de datos. El alcance solicitado necesita que las operaciones backend validen `app_permisos.puede_ajustes`. La política instalada permite modificar esa misma autorización desde el cliente, por lo que una comprobación de ese campo no es confiable.

## Hechos comprobados

Proyecto Supabase verificado por `get_project`: ref `iuryhsjucblmebdogewa`, nombre `llamita-plus`, `ACTIVE_HEALTHY`, PostgreSQL 17.6.1.166.

Consultas SELECT de solo lectura a `pg_policies` y `information_schema.role_table_grants`, limitadas a `public.app_permisos`, devolvieron:

| Operación/política | Roles | Condición instalada |
|---|---|---|
| `INSERT`, `app_permisos alta` | `authenticated` | `WITH CHECK true` |
| `UPDATE`, `app_permisos cambio` | `authenticated` | `USING true`, `WITH CHECK true` |
| `UPDATE`, `app_permisos escribir` | `anon`, `authenticated` | `USING true`, `WITH CHECK true` |
| `SELECT`, `app_permisos read` | `anon`, `authenticated` | `USING true` |

Los grants directos para `anon` y `authenticated` incluyen `INSERT`, `UPDATE`, `DELETE` y `TRUNCATE` (además de SELECT y privilegios de tabla adicionales). Un SELECT agregado, sin leer correos ni otros datos identificables, mostró nueve filas y seis con `puede_ajustes=true`. Esto solo describe los valores actuales: no establece quién los asignó ni vuelve confiables las políticas abiertas.

## Consecuencia de seguridad

Un usuario de cliente que no tenga autorización puede cambiar su propio registro de permisos o el de otra persona, sujeto a las columnas expuestas por la API. Por eso una función que solo consulte `app_permisos.puede_ajustes` permitiría autoescalamiento. Ocultar controles en el navegador o crear RPCs que repitan el mismo chequeo no corrige el problema.

La aplicación existente tiene gestión de permisos que depende del acceso directo a esa tabla; cambiar sus políticas sin diseñar y probar su flujo de reemplazo también podría romper la administración actual. No se debe endurecer a ciegas sin definir bootstrap, operación autorizada y compatibilidad del cliente.

## Decisión solicitada

Elegir y autorizar una fuente de autorización administrativa confiable antes de reanudar B3.2a. Propuesta recomendada para revisión:

1. Conservar `puede_ajustes` como permiso funcional existente, pero impedir que clientes sin ese permiso alteren filas o se autoasignen permisos.
2. Revocar DML directo innecesario a `anon`; sustituir las políticas abiertas por políticas mínimas y no recursivas, o por RPCs backend con validación equivalente.
3. Definir cómo se conserva el acceso de los administradores actuales durante el corte y cómo se recupera el acceso si no queda ningún administrador.
4. Revisar y adaptar la pantalla existente de administración de permisos para que use la ruta protegida; verificar que no dependa de los grants que se retiren.
5. Probar con sesiones sintéticas `anon`, usuario autenticado sin `puede_ajustes` y usuario autorizado: autoelevación denegada, cambios autorizados permitidos, y ausencia de DML directo desde navegador.
6. Recién después, crear las operaciones protegidas de áreas y asignaciones de B3.2a.

Alternativamente, Alejo puede aprobar otra autoridad verificable que no dependa de una tabla modificable por el mismo cliente. No se presume una identidad superadministradora, metadata JWT o rol nuevo.

## Trabajo no ejecutado

- No se modificó `index.html` ni ningún otro archivo de aplicación.
- No se ejecutó SQL de escritura ni migración.
- No se insertaron áreas, productos o asignaciones sintéticas.
- No se modificaron permisos ni datos; no hubo consultas o escrituras a otros proyectos.
- No se tocó stock, `productos.stock_actual`, lotes, movimientos, transferencias, recetas, POS, Lama, Fudo, ventas, caja ni datos comerciales.
- No se accedió a Café del Desierto / Llamita Stock.

Las comprobaciones solicitadas de creación/edición/archivo, lecturas dinámicas, conciliación y UI no se ejecutaron porque dependen de una autorización backend segura que no existe hoy. `git diff --check` se ejecuta sobre estos documentos antes de publicarlos; pruebas de aplicación no aplican a una detención documental.

## Estado Hermes y siguiente paso

- Cola: B3.2a `REQUIERE DECISIÓN`; B3.2b `PENDIENTE`, no activa.
- Plan: registra el mismo bloqueo y mantiene intacto el objetivo funcional, pospuesto hasta resolver permisos.
- Bitácora y canal: registran evidencia de solo lectura y ausencia de cambios.
- Al recibir una decisión, reactivar explícitamente B3.2a, resolver primero el control de `app_permisos` y ejecutar de nuevo todo su plan de pruebas. No iniciar B3.2b automáticamente.
