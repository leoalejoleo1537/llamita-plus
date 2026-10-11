# Bloque 1A — Inventario funcional por área y sección

**Fecha:** 2026-10-11

**Estado:** COMPLETADA

**Repositorio:** `leoalejoleo1537/llamita-plus`
**Supabase:** `llamita-plus` (`iuryhsjucblmebdogewa`)

## Resultado

Se implementó el contrato:

`Producto → Área → Sección física → mínimo/máximo`

La configuración no contiene cantidades. El saldo sigue calculándose exclusivamente desde `stock_internal.existencias`; `productos.stock_actual` no participa en la lectura nueva ni recibe escrituras desde este bloque.

## Modelo instalado

### `public.area_secciones`

- Pertenece a una única `areas_operativas` de `plaza`.
- Guarda código estable, nombre normalizado, orden, estado y bloque visual `am`/`pm`.
- Usa archivo lógico y actores/fechas de creación, modificación y archivo.
- No contiene stock, lote, movimiento ni ubicación de ledger.
- Tiene RLS activo, cero políticas abiertas y cero grants para `anon`, `authenticated` o `service_role`.

### `public.producto_area_asignacion`

- Se reutilizó la tabla existente; no se creó una segunda fuente de configuración.
- Admite una configuración por producto y área y el mismo producto en varias áreas.
- Añade `seccion_id`, `stock_min`, `stock_max`, `es_principal` y archivo lógico auditado.
- Impide una sección de otra área, secciones/áreas archivadas, límites negativos, máximo menor al mínimo y más de un área principal.
- `Sin asignar` conserva `area_id=NULL` y nunca se convierte en área o sección física.

No hubo migración automática desde `public.secciones`, `productos.rubro` ni reglas por nombre. La tabla de secciones nuevas quedó vacía. Las tres filas de configuración preexistentes se conservaron; la única asignada quedó principal para mantener compatibilidad.

## RPC y autorización

Se añadieron:

- `area_secciones_listar`
- `area_seccion_crear`
- `area_seccion_editar`
- `area_seccion_archivar`
- `producto_area_configuraciones_listar`
- `producto_area_configuracion_guardar`
- `producto_area_configuracion_archivar`
- `producto_plaza_crear_configurado`

Las lecturas exigen sesión autenticada. Crear/editar/archivar secciones exige `puede_ajustes`; configurar productos exige `puede_editar`. La validación usa la autorización S1 del lado servidor, nombres de esquema explícitos y `search_path=''`. `PUBLIC`, `anon` y `service_role` no tienen `EXECUTE` en las entradas nuevas.

`stock_leer_areas` cambió su forma de lectura: devuelve configuraciones activas aunque tengan saldo cero y agrega saldos físicos sin configuración. Ya no cruza cada producto con todas las ubicaciones. La fuente de cantidad es el ledger.

## Experiencia de inventario

- Al abrir un área se entra a un lugar de trabajo, no a Ajustes.
- Se conservan buscador y filtros con los valores reales de `productos.tipo`; no se inventaron grupos.
- La pantalla muestra productos configurados con cero como **Configurado · sin existencias**.
- Las secciones físicas son desplegables y se agrupan visualmente en AM/PM.
- La ficha histórica muestra saldo ledger de solo lectura, grupo histórico, área, sección y límites por área.
- Cambiar sección o límites no crea movimientos ni transfiere unidades.
- Ajustes administra las secciones físicas por área mediante RPC protegidas. Bodega conserva su interfaz legacy.

## Migraciones

- Remota `20261011181753 bloque_1a_inventario_area_seccion`; fuente `supabase/migrations/20261011143000_bloque_1a_inventario_area_seccion.sql`.
- Remota `20261011181901 bloque_1a_indice_seccion_area`; fuente `supabase/migrations/20261011182000_bloque_1a_indice_seccion_area.sql`.

La segunda migración cubre el FK compuesto `(seccion_id, area_id)` señalado por el advisor de rendimiento.

## Pruebas

`sql/2026-10-bloque-1a-pruebas-transaccionales.sql` ejecutó y revirtió:

- creación y duplicado normalizado de sección;
- AM/PM como metadata visual;
- mismo producto configurado en dos áreas;
- sección de área, mínimo/máximo y principal único;
- lectura de un configurado con saldo cero;
- cambio de configuración sin cambios de ledger;
- alta atómica de ficha/configuración con saldo cero y sin lote/movimiento;
- propietario raíz, administrador operativo, usuario común y anon;
- archivo de sección con confirmación;
- conservación de la firma/autorización de `stock_transferir`;
- conteos contables y comerciales.

También pasaron `npm test`, validación de sintaxis de los scripts inline y `git diff --check`. El entorno no tiene Chromium instalado; se deja como procedimiento manual abrir un área en escritorio y móvil, probar búsqueda/filtro, desplegar secciones, abrir la ficha y confirmar en Network que solo se llaman las RPC de lectura/configuración.

## Conteos pre/post

| Métrica | Antes | Después |
|---|---:|---:|
| Productos | 1.438 | 1.438 |
| Suma `productos.stock_actual` | 15.438,00 | 15.438,00 |
| Lotes | 42 | 42 |
| Movimientos legacy | 431 | 431 |
| Movimientos ledger | 408 | 408 |
| Suma ledger | 9.316,70 | 9.316,70 |
| Repartos | 361 | 361 |
| Recetas | 396 | 396 |
| Movimientos Fudo | 15.357 | 15.357 |
| Eventos Lama | 0 | 0 |
| Áreas | 5 | 5 |
| Configuraciones producto-área | 3 | 3 |
| Secciones físicas nuevas | 0 | 0 |

## Rollback y riesgos

Antes de uso real, el rollback técnico consiste en restaurar la lectura/RPC previas y retirar las columnas/tablas aditivas; debe abortar si ya existen secciones o múltiples configuraciones por producto. Después de uso real, no se deben borrar configuraciones: corresponde una reversión compensatoria que archive secciones/configuraciones y preserve actores/fechas.

Riesgos pendientes:

- falta validación visual en navegador real;
- la carga inicial y la resolución humana de rubros/secciones ambiguas siguen pendientes;
- ajustes auditados de cantidad, reparto, despacho y recepción no existen todavía;
- advisors heredados de otras tablas/RPC permanecen fuera de alcance; `area_secciones` sin políticas es intencional porque la tabla está cerrada y solo se usa mediante RPC.

No se modificaron Fudo, Lama, caja, recetas, lotes, movimientos, reparto, recepción, Bodega legacy ni Café del Desierto / Llamita Stock.
