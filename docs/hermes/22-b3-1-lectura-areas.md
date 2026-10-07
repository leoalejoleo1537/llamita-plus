# B3.1 — interfaz de lectura y navegación por áreas

Fecha: 2026-10-07
Estado: **COMPLETADA**. B3.2 queda **PENDIENTE**, no activada.

## Entorno y alcance

- Repositorio: `leoalejoleo1537/llamita-plus`, remoto oficial; rama de trabajo `work`.
- Supabase: `llamita-plus`, ref `iuryhsjucblmebdogewa`, proyecto `ACTIVE_HEALTHY`, PostgreSQL 17.6.1.166.
- Se trabajó en lectura de inventario de `plaza` y en mantener el renderer ya existente de `central` (Bodega).
- No se consultó ni modificó Café del Desierto / Llamita Stock.
- No se habilitaron botones de transferencia ni se llamó `stock_transferir`. No se modificaron productos, existencias, lotes, movimientos, transferencias, recetas, POS ni datos comerciales.

## Navegación y comportamiento

La entrada actual de Inventario en `plaza` presenta seis opciones: Cocina fría, Cocina caliente, Barra, Cafetería, Sin asignar y Todas las áreas. Las tarjetas muestran productos con saldo, unidades y el estado “Críticos · sin mínimos configurados”; no calculan críticos como cero.

Al abrir un área, la misma pantalla muestra `Inventario · [Área]`, búsqueda y filtro de tipo acotados a esa ubicación, lista de productos con saldo positivo y control “Todas las áreas” para volver. Si no hay saldo, la vista se muestra vacía sin productos de otras ubicaciones. Sin asignar se explica como el stock inicial de Local 1 pendiente de distribución.

“Todas las áreas” agrupa por identidad maestra de producto y muestra una cantidad por ubicación, incluyendo cero para que la separación sea explícita. Cada cantidad permite abrir el producto filtrado en la ubicación correspondiente. Bodega (`central`) conserva el flujo y renderer existente y no se mezcla en los totales de Local 1.

La ruta UI es un estado local de navegación: `areaActual=null` para portada, un código estable para el área, y `__todas__` para global. No se agregaron rutas URL ni otra pantalla duplicada.

## Consulta y seguridad

Se aplicaron en Supabase Llamita Plus:

- `20261007174518 b3_1_lectura_inventario_areas`
- `20261007174626 b3_1_include_inactive_stock_products`

`public.stock_leer_areas()` es la entrada de solo lectura, `SECURITY INVOKER`, `search_path` vacío y `EXECUTE` solo para `authenticated`. Llama al helper `stock_internal.leer_existencias_areas_plaza()`, `SECURITY DEFINER`, `search_path` vacío, que exige `auth.uid()` y limita el resultado a las ubicaciones activas de `plaza`. El helper incluye metadatos del producto y calcula cantidades exclusivamente desde `stock_internal.existencias`; conserva productos inactivos cuando aún tienen saldo positivo. Ni la función pública ni el helper hacen referencia a `productos.stock_actual`.

Comprobación de permisos ejecutada: anon no puede ejecutar ninguna función; authenticated puede ejecutar ambas; service_role no puede ejecutarlas; anon/authenticated/service_role no tienen INSERT en movimientos; authenticated no tiene UPDATE sobre ubicaciones. El esquema privado sigue requiriendo USAGE para que authenticated llame al helper concedido, sin grants de DML sobre las tablas internas. La consulta RPC sin sesión fue rechazada con `28000 Se requiere una sesión autenticada`.

Los advisors de Supabase se revisaron. Informan otros problemas preexistentes de seguridad y rendimiento en distintas tablas/funciones del proyecto (incluidos SECURITY DEFINER legacy, tablas RLS sin políticas permisivas y claves foráneas no indexadas). No son hallazgos nuevos de estas funciones; este bloque no cambió políticas ni permisos ajenos al alcance. Revisar el reporte completo de advisors como tarea de seguridad separada.

## Conciliación observada

Consulta autenticada simulada dentro de `BEGIN ... ROLLBACK` sobre la RPC:

| Ubicación de Local 1 | Productos con saldo | Unidades |
|---|---:|---:|
| Barra | 0 | 0,00 |
| Cafetería | 0 | 0,00 |
| Cocina caliente | 0 | 0,00 |
| Cocina fría | 0 | 0,00 |
| Sin asignar | 255 | 4.566,20 |

Las áreas físicas comienzan sin existencias. El total RPC de `plaza` coincide con `stock_internal.existencias` de `plaza`: 4.566,20; Bodega (`central`) queda fuera. No hubo escritura en esta lectura.

Conteos SELECT al cierre: productos 1.437 (329 plaza); libro plaza 4.566,20 y central 4.750,50; 408 movimientos del libro; 0 transferencias; 42 lotes; 514 líneas de receta. El reporte anterior B2.4 registra el mismo baseline tras rollback; esta fase no ejecutó DML ni alteró esos datos.

## Pruebas y limitaciones

- Consulta RPC como `authenticated` con claims sintéticos, dentro de transacción revertida; devolvió exactamente las cinco ubicaciones permitidas.
- Conciliación RPC-libro sin diferencia; cuatro áreas físicas en cero; Sin asignar con 255 productos y 4.566,20 unidades.
- Permisos de funciones y ausencia de DML directo comprobados mediante `has_function_privilege` y `has_table_privilege`.
- Intento de consulta sin sesión rechazado.
- `node pruebas/pantalla-sana.mjs`, `node --check pruebas/inventario-areas.mjs`, `npm test` y `git diff --check` ejecutados. Los checks estáticos pasaron. Las pruebas que requieren Chromium se omitieron porque este entorno no tiene navegador instalado.
- Las cantidades y el buscador se validaron además con la consulta de base; la navegación DOM completa en escritorio/móvil queda pendiente de ejecución visual manual.

### Procedimiento manual de verificación visual

1. Abrir Llamita Plus con una sesión autenticada y elegir Local 1 (`plaza`).
2. En Inventario, confirmar seis tarjetas y que las cuatro áreas físicas indiquen 0 productos, 0 unidades y “sin mínimos configurados”.
3. Abrir Sin asignar; verificar la nota de stock pendiente de distribución y una lista de productos con saldo.
4. Abrir Cafetería y buscar “leche”; al inicio debe mostrarse vacío porque el saldo inicial continúa en Sin asignar. Repetir en Barra; no deben aparecer productos de otras ubicaciones.
5. Volver a Todas las áreas; confirmar que cada producto tenga cantidades separadas por ubicación y que un enlace abra el mismo producto dentro de esa área.
6. Cambiar a Bodega (`central`); confirmar que conserva la interfaz de Inventario anterior y no muestra el navegador de áreas.
7. En DevTools, revisar que solo se invoque `stock_leer_areas` para la pantalla de áreas, no `stock_transferir`, y que no haya errores de consola.
8. Repetir en ventana angosta/móvil: tarjetas a dos columnas, navegación visible y sin scroll horizontal.

## Archivos y rollback

- `index.html`: portada y estados de lectura; renderer de Bodega preservado.
- `supabase/migrations/20261007174518_b3_1_lectura_inventario_areas.sql`
- `supabase/migrations/20261007174626_b3_1_include_inactive_stock_products.sql`
- `sql/2026-10-b3-1-pruebas-lectura-areas.sql`
- `sql/2026-10-b3-1-lectura-areas.rollback.sql`
- `pruebas/inventario-areas.mjs`
- Cola, bitácora, canal Hermes y plan de áreas actualizados.

Rollback preparado en `sql/2026-10-b3-1-lectura-areas.rollback.sql`: elimina únicamente ambas funciones de lectura y no toca saldos ni otras tablas. Si la UI se revierte por código, volverá a la experiencia anterior de Inventario para `plaza`; no hay datos que compensar.

## Riesgos y siguiente fase

- Sin mínimos por área, no se muestran críticos; configurarlos no forma parte de B3.1.
- Los usuarios con acceso a la RPC pueden leer producto y saldo de todas las ubicaciones iniciales de `plaza`; la autorización por área/usuario aún no existe. La RPC restringe la sede de forma fija y no entrega `central`.
- No hay prueba visual automatizada ni revisión de consola por falta de Chromium; ejecutar el procedimiento manual antes de demo.
- B3.2 permanece pendiente: no se activa ni se introduce edición, asignación o transferencia visual en este bloque.

No hubo acceso a Café del Desierto / Llamita Stock. No se cambiaron saldos, productos, movimientos, lotes, transferencias, recetas, permisos ni ventas.

Commit de implementación y migraciones publicado en `master`: `2a9c8c2` (`feat: add read-only inventory area navigation`).
