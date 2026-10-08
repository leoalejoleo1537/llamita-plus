# Plan de endurecimiento de seguridad

Fecha de actualización: 2026-10-08

## Estado

- S0: **COMPLETADA**, auditoría base.
- S1: **COMPLETADA**, identidad raíz y gobierno de `app_permisos`.
- S2: **COMPLETADA**, sesiones reales y dos auditorías persistentes corroboradas.
- B3.2a: pendiente y no activa.
- Cierre de tablas/RPC heredadas: pendiente y no activo.

## Criterio de salida de S2

Las dos cuentas existentes probaron mediante login real el gobierno exclusivo de la raíz, el rechazo del administrador operativo y la operación normal. El propietario ejecutó con el valor admitido `boton` una concesión y su restauración mediante la RPC protegida. Los logs muestran dos llamadas HTTP 200 y la tabla privada conserva dos filas inmutables con los estados anterior y nuevo. La cuenta operativa terminó restaurada exactamente y no se compartieron credenciales, JWT ni refresh tokens.

## Fases posteriores separadas

1. Permisos y Ajustes: S1 implementado; sesiones reales y auditoría persistente verificadas en S2.
2. Lama y caja: inventariar cada RPC/tabla, reemplazar actor declarativo por `auth.uid()`, probar realtime y cierres antes de revocar acceso legacy.
3. Funciones privilegiadas: revisar las 40 funciones anónimas una por una; revocar o convertir a invoker con pruebas de regresión por dominio.
4. Productos y recetas: retirar DML abierto sin romper el ledger ni los triggers de corte.
5. Logística y stock legacy: adaptar entradas, mermas, repartos, restauraciones y fusiones a operaciones autorizadas.
6. Reportes y vistas: migrar vistas privilegiadas a `security_invoker` o revocar exposición.
7. Fudo: mantener origen POS, modo prueba y cron apagado hasta definir capacidades server-side por UUID y probar las Edge con sesión real.

Cada fase requiere activación independiente, conteos pre/post, pruebas transaccionales, advisors y rollback. No se cerrarán las 36 tablas ni las rutas comerciales en una sola migración.
