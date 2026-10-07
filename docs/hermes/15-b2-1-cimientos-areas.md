# B2.1 — Cimientos del modelo de áreas operativas

Fecha: 2026-10-07
Estado: **COMPLETADO**. B2.2 permanece **PENDIENTE** y no activa.

## Alcance ejecutado

Repositorio verificado: `leoalejoleo1537/llamita-plus`, remoto oficial `origin`; rama local `work`, sincronizada con `origin/master` antes de escribir. Supabase verificado por metadatos: proyecto `llamita-plus`, ref `iuryhsjucblmebdogewa`, `ACTIVE_HEALTHY`, PostgreSQL 17.6.

Se aplicaron `b2_1_cimientos_areas_operativas`, `b2_1_indices_fk_producto_area` y `b2_1_comentario_relacion_area`. Las áreas se relacionan con la clave estable de `public.sede_registro(codigo)`. La auditoría confirmó que `lama_areas` es el plano de mesas y no se reutilizó.

### Tablas y columnas

`public.areas_operativas`:

- `id uuid` — PK.
- `sede text` — FK a `sede_registro(codigo)`.
- `codigo text` — clave estable por sede.
- `nombre text` — etiqueta visible editable.
- `estado text` — `activa` o `archivada`.
- `orden integer`, `creado_at timestamptz`, `actualizado_at timestamptz`.
- Unicidad por `(sede,codigo)` y `(sede,nombre)`; código validado; `sin_asignar` reservado y no es área física.

`public.producto_area_asignacion` (relación preparatoria, sin filas):

- `id uuid` — PK.
- `sede text` — FK a `sede_registro(codigo)`.
- `producto_id bigint` — FK a `productos(id)`.
- `area_id uuid` — FK a `areas_operativas(id)`, nullable para estado sin asignar.
- `estado text` — `asignado` o `sin_asignar`.
- `origen text` — `manual` o `regla_confirmada`; `regla text` opcional.
- `creado_at timestamptz`, `actualizado_at timestamptz`.
- No tiene columnas de cantidad, existencia ni saldo.
- Check de coherencia entre estado y `area_id`, regla requerida si el origen es `regla_confirmada`, FK/contexto de sede verificado por trigger e índice único `(sede,producto_id)`.
- Índices de cobertura para las FK `producto_id` y `area_id`, además del índice de consulta `(sede,area_id)`.

La unicidad actual permite asignar un producto a un área como máximo. Esto evita que una futura consulta atribuya el stock completo del producto a varias áreas. Si B2.2 permite distribución física simultánea, deberá introducir cantidades explícitas por destino y retirar este límite dentro de una conciliación aprobada; esta tabla no puede usarse como saldo.

### Áreas creadas

| Sede | Código | Nombre | Estado |
|---|---|---|---|
| `plaza` | `cocina_fria` | Cocina fría | activa |
| `plaza` | `cocina_caliente` | Cocina caliente | activa |
| `plaza` | `barra` | Barra | activa |
| `plaza` | `cafeteria` | Cafetería | activa |

No hay áreas de `central`, `angamos` ni la clave histórica `bodega`. No se modificó `sede_registro`.

## Conciliación de simulación

El informe SELECT-only reproducible está en `sql/2026-10-b2-1-simulacion-clasificacion.sql`. Devuelve una fila por producto de `plaza`: identificador, nombre, rubro/tipo, stock actual, área propuesta, regla y stock hipotético atribuido. La clasificación es mutuamente exclusiva; cada producto recibe un destino como máximo. Los nombres combinados, embalajes y coincidencias insuficientes quedan en `Sin asignar`. No se insertó la clasificación en `producto_area_asignacion`.

| Destino propuesto | Productos únicos | Stock hipotético |
|---|---:|---:|
| Barra | 18 | 108,00 |
| Cafetería | 42 | 536,50 |
| Cocina caliente | 19 | 204,00 |
| Cocina fría | 17 | 17,50 |
| Sin asignar | 233 | 3.700,20 |
| **Total** | **329** | **4.566,20** |

Los 329 productos aparecen una sola vez (`count(distinct id) = count(*)`) y la suma simulada coincide con el stock actual de `plaza`. Los valores son una proyección del saldo actual completo a un destino hipotético, no existencias creadas ni una validación física. “Sin asignar” incluye elementos que requieren revisión y productos no cubiertos por las reglas solicitadas. Las reglas son propuestas, no historial operativo ni asignaciones autorizadas.

Las heurísticas siguen la solicitud: gaseosas identificables → Barra; café/té/leche común/tortas identificables → Cafetería; pan/pizza/sándwich → Cocina caliente; helados/ice/ingredientes dulces identificables → Cocina fría; resto → Sin asignar. El resultado muestra por producto qué regla aplicó y permite revisión posterior.

## Conteos y verificaciones

| Métrica | Antes | Después |
|---|---:|---:|
| Productos totales | 1.437 | 1.437 |
| `sum(productos.stock_actual)` | 15.438,00 | 15.438,00 |
| Productos de `plaza` | 329 | 329 |
| Stock de `plaza` | 4.566,20 | 4.566,20 |
| Productos `plaza` con stock no cero | 255 | 255 |
| Movimientos | 431 | 431 |
| Repartos | 361 | 361 |
| Líneas de repartos | 2.040 | 2.040 |
| Lotes | 42 | 42 |
| Recetas | 396 | 396 |
| Ítems de receta | 514 | 514 |
| Permisos de aplicación | 9 | 9 |
| `lama_areas` (plano de mesas) | 5 | 5 |
| Áreas operativas | no existía | 4, todas `plaza` |
| Asignaciones de productos | no existía | 0 |

Pruebas estructurales y transaccionales (script `sql/2026-10-b2-1-pruebas-estructura.sql`, ejecutado con `BEGIN ... ROLLBACK`): áreas exactas y sede; rechazo de producto/área cruzados; unicidad de producto/sede; coherencia de estado/área; reserva de `sin_asignar`; inmutabilidad de sede/código; RLS activo; sin políticas ni permisos de tabla para `anon`, `authenticated` y `service_role`; sin columnas de saldo. La prueba terminó en rollback; la tabla de asignaciones siguió vacía.

Advisors de Supabase: el aviso `RLS Enabled No Policy` incluye estas dos tablas, esperado porque son internas y sin acceso de cliente. El advisor de rendimiento encontró inicialmente las dos FK sin índice; se corrigió con `b2_1_indices_fk_producto_area`. En la revisión final ya no hay hallazgos de FK para estas tablas. Los índices nuevos aparecen como no usados porque la relación está vacía; se conservan para integridad y acceso futuro. Los demás avisos corresponden a objetos preexistentes.

No se modificaron productos, `stock_actual`, movimientos, repartos, lotes, recetas, permisos, `lama_areas`, Bodega (`central`), `angamos` ni `bodega`. Tampoco se creó información en Café del Desierto / Llamita Stock.

## Rollback y riesgos

Rollback preparado: `sql/2026-10-b2-1-cimientos-areas-operativas.rollback.sql`. Se detiene si faltan las tablas, si hay asignaciones persistidas, si el catálogo de `plaza` cambió de cuatro áreas o si existen áreas de otras sedes. En ese caso exige evaluación manual; no borra asignaciones ni áreas modificadas. No se ejecutó el rollback.

Riesgos y límites:

- La regla automática es una propuesta por nombre/rubro/tipo; los 233 productos Sin asignar y cualquier clasificación dudosa requieren revisión humana.
- `plaza` comparte proyecto y no es un entorno técnicamente aislado. Las nuevas tablas no ofrecen acceso directo desde cliente/API en este bloque.
- `productos.stock_actual` sigue siendo la única fuente de stock vigente. Los valores por área son proyecciones y no se deben sumar desde una relación.
- La asignación única por producto/sede deberá evolucionar si B2.2 implementa stock de un mismo producto distribuido entre varias áreas.
- No se implementó UI, CRUD de áreas, administración de permisos ni gestión de cantidades.

### Archivos relacionados

- Migración: `sql/2026-10-b2-1-cimientos-areas-operativas.sql`.
- Índices FK: `sql/2026-10-b2-1-indices-fk.sql`.
- Comentario de esquema: `sql/2026-10-b2-1-comentario-relacion-area.sql`.
- Rollback: `sql/2026-10-b2-1-cimientos-areas-operativas.rollback.sql`.
- Conciliación: `sql/2026-10-b2-1-simulacion-clasificacion.sql`.
- Pruebas: `sql/2026-10-b2-1-pruebas-estructura.sql`.
- Cola: `docs/hermes/03-cola-de-trabajo-codex.md`.
- Bitácora: `docs/hermes/04-bitacora-codex.md`.
- Canal: `docs/hermes/06-canal-hermes-codex.md`.
- Plan: `docs/hermes/01-plan-areas-operativas.md`.
