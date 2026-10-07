# B2.2 — Auditoría de fuente única y bloqueo de migración

Fecha: 2026-10-07
Estado: **REQUIERE DECISIÓN**. Se activó y auditó B2.2, pero no se implementó un saldo por área ni se migraron cantidades.

## 1. Identidad y límites

- Repositorio: `leoalejoleo1537/llamita-plus`.
- Remoto `origin`: `https://github.com/leoalejoleo1537/llamita-plus.git`.
- Rama local: `work`; estaba sincronizada con `origin/master` en `60e83c68a4fa24dff461576c6ccd30b00323ba7c`.
- Supabase confirmado por metadatos: proyecto `llamita-plus`, ref `iuryhsjucblmebdogewa`, estado `ACTIVE_HEALTHY`, PostgreSQL 17.6.
- Solo se usó ese proyecto de Supabase. No se accedió a Café del Desierto / Llamita Stock.
- La cola autorizó únicamente B2.2. B2.3 (interfaz y formularios) queda pendiente.

La revisión de la base fue de solo lectura. No se ejecutó migración, RPC de escritura, `INSERT`, `UPDATE` ni `DELETE`; tampoco se modificó código de aplicación o dato alguno.

## 2. Estado vigente comprobado

`public.productos.stock_actual` sigue siendo la cantidad consolidada y usada por la aplicación. Los saldos de `plaza` son:

| Medida | Conteo/suma |
|---|---:|
| Productos globales | 1.437 |
| `stock_actual` global | 15.438,00 |
| Productos de `plaza` | 329 |
| `stock_actual` de `plaza` | 4.566,20 |
| Movimientos globales / de `plaza` | 431 / 25 |
| Lotes globales / asociados a productos de `plaza` | 42 / 9 |
| Repartos globales / con destino `plaza` | 361 / 148 |
| Recetas globales / de `plaza` | 396 / 195 |
| Permisos globales (`app_permisos`) | 9 |
| Filas de `producto_area_asignacion` | 0 |

`areas_operativas` contiene las cuatro áreas confirmadas solo para `plaza`: Cocina fría, Cocina caliente, Barra y Cafetería. `producto_area_asignacion` no tiene columna de cantidad y hoy solo acepta `asignado` o `sin_asignar`, con una relación por producto/sede; sus restricciones actuales no permiten una distribución cuantitativa de un producto entre varias áreas.

Los lotes son detalle del saldo actual, no stock adicional: globalmente 31 productos con lote suman 304,00, coincidente con el saldo de esos productos. En `plaza`, 6 productos con lotes suman 36,00, con cero diferencias frente a `stock_actual`. `producto_lotes` no contiene sede ni área; las 9 filas de `plaza` no se pueden distribuir con trazabilidad por ubicación sin una decisión de modelo.

La clasificación de simulación de B2.1 (18 Barra, 42 Cafetería, 19 Cocina caliente, 17 Cocina fría y 233 Sin asignar) es heurística de categoría. No está persistida y no prueba dónde se encuentran físicamente las unidades. No se convirtió en una instrucción de movimiento físico ni se usó para editar cantidades.

## 3. Escritores auditados

### Aplicación

- El control de stock en la fila escribe `productos.stock_actual` mediante `saveFields()` (`index.html`, alrededor de líneas 11924–11934); la tabla también ofrece edición directa del valor (`index.html`, alrededor de líneas 11720–11728).
- El formulario de producto existente persiste `stock_actual` junto con otros campos (`index.html`, alrededor de líneas 12890–12910).
- El alta de producto inserta `stock_actual` (`index.html`, alrededor de línea 13049).
- La gestión de fechas reemplaza lotes con una secuencia de borrado e inserción directa en `producto_lotes` (`index.html`, alrededor de líneas 12920–12930); el trigger recalcula después el saldo global.
- Los lectores de inventario, críticos, exportaciones, historial, repartos, ajustes y reportes consumen `stock_actual` en numerosos lugares de `index.html`. También esperan `stock_min` y `stock_max` en el producto, no por área.

### Base de datos instalada

Se consultaron firmas y cuerpos instalados con `pg_get_functiondef`/`pg_get_function_identity_arguments`; no se tomaron funciones históricas de archivos SQL como autoridad. El catálogo identifica las siguientes rutas de escritura o delegación del stock actual:

| Ruta instalada | Relación con el saldo vigente |
|---|---|
| `mermar` / `deshacer_merma` | Descuenta o repone `productos.stock_actual`, o cambia `producto_lotes` y deja que el trigger recalcule. |
| `registrar_entrada` / `deshacer_entrada` | Entrada y reversa escriben stock de productos de Bodega; la reversa no es un simple borrado de movimiento. |
| `reparto_recibir` / `reparto_descontar_bodega` / `reparto_deshacer` | Cambian productos o lotes de destino/origen; la operación usa más de un camino y maneja reversa. |
| `fudo_procesar_item` | En modo real delega en `descontar_lotes` o `descontar_con_reposicion`; el primer camino consume lotes y el segundo escribe el saldo. |
| `descontar_lotes` / `descontar_con_reposicion` | FIFO sobre lotes o descuento de `productos.stock_actual`. El primer camino no debe descontarse manualmente por segunda vez. |
| `lama_stock_aplicar_evento` | En modo real delega en esos mismos caminos. No se activó el modo real durante esta auditoría. |
| `fusionar_productos` / `deshacer_fusion` | Suma, pone en cero, mueve lotes y restaura los valores previos de productos fusionados. |
| `restaurar_sede` / `deshacer_restauracion` | Restaura filas de producto desde historial y puede volver a escribir cantidades antiguas. |
| `franquicia_linea_lista` | Descuenta productos en `central` y registra movimiento. |
| `crear_producto_enlazado` | Crea productos y contempla el stock inicial en los productos enlazados. |
| `sync_stock_desde_lotes` | Trigger instalado `trg_sync_stock_lotes`, ejecutado tras insertar/actualizar/eliminar lotes, reescribe `productos.stock_actual` desde la suma de lotes. |

Fudo, Lama y franquicia no se ejecutaron. Se leyeron definiciones del catálogo; no se invocó ninguna ruta de escritura.

## 4. Bloqueo: no hay corte seguro sin adaptación coordinada

Crear y poblar otra tabla de cantidades mientras siguen habilitadas estas rutas dejaría dos valores editables para las unidades de `plaza`. Conservar `productos.stock_actual` como writable permitiría que una edición directa, una reversa, una venta, una merma, la recepción de un reparto o el trigger cambien el saldo sin reflejar el área. Hacer un trigger espejo bidireccional no elimina el problema: agrega orden de precedencia, riesgo de ciclos y carreras.

La alternativa de mantener el nuevo saldo como autoridad y dejar `stock_actual` de solo lectura/proyección necesita un corte coordinado: sustituir las escrituras directas de la app, adaptar los RPC instalados y resolver cómo se sirven las lecturas que hoy piden el campo en `productos`. En el esquema actual `productos` es una tabla expuesta con políticas de lectura/escritura amplias para `anon`, `authenticated` y `PUBLIC`; la compatibilidad no se puede garantizar con una migración aislada de datos.

Hay dos bloqueos adicionales:

1. **Lotes:** 9 lotes asociados a productos de `plaza` no tienen ubicación. Dejarlos globales mientras se reparten productos entre áreas no permite saber qué área consumiría cada vencimiento; copiar cada lote por área duplicaría unidades. Debe decidirse y modelarse la distribución de lotes antes de migrar ese stock.
2. **Asignación inicial:** las reglas de simulación clasifican nombres/tipos, no ubicación física. El stock de un producto con clasificación clara se podría asignar íntegro a una sola área solo si se confirma que ese traslado representa el conteo real. El estado Sin asignar debe conservar una cantidad global única, no copiar el saldo completo a cada área.

Por estos motivos se detuvo la migración, tal como exige B2.2 si un escritor no puede adaptarse con seguridad. El bloqueo no significa que la arquitectura por área sea inviable; significa que debe implementarse como una transición coordinada en una fase reautorizada.

## 5. Recomendación de fuente única y decisiones requeridas

Recomendación para el diseño a aprobar: un ledger/saldo por ubicación para `plaza` como autoridad única; `productos.stock_actual` deja de ser editable para esa sede y se conserva solo como agregado de compatibilidad de lectura durante una transición acotada. Los demás nodos mantienen su autoridad actual hasta un corte separado. El agregado de compatibilidad no puede aceptar escrituras ni convertirse en una segunda autoridad.

Antes de retomar hacen falta decisiones explícitas sobre:

1. Autorizar el ledger por área como fuente de `plaza` y el corte que vuelve el campo global una proyección no editable.
2. Autorizar la adaptación conjunta de todas las rutas enumeradas, incluidos permisos Data API/RLS, y definir cómo hacer el corte sin operaciones concurrentes parciales.
3. Determinar si los lotes se ubican por área desde la migración o permanecen como una capa global temporal que impide atribuir consumos por vencimiento hasta su conteo/distribución.
4. Confirmar que la asignación inicial sugerida por simulación equivale a ubicación física para los productos claros; los restantes conservan una sola cantidad en Sin asignar.
5. Definir mínimos y máximos por producto/área, que hoy solo existen en el producto global.

No se necesita borrar `productos.stock_actual` para realizar este corte. La compatibilidad debe seguir disponible como lectura hasta que sus consumidores se hayan adaptado; cualquier retiro posterior pertenece a otra decisión.

## 6. Conteos y conciliación

| Medida | Inicio de auditoría | Cierre de auditoría | Diferencia |
|---|---:|---:|---:|
| Productos globales | 1.437 | 1.437 | 0 |
| Stock global | 15.438,00 | 15.438,00 | 0 |
| Productos `plaza` | 329 | 329 | 0 |
| Stock `plaza` | 4.566,20 | 4.566,20 | 0 |
| Movimientos globales / `plaza` | 431 / 25 | 431 / 25 | 0 / 0 |
| Lotes globales / `plaza` | 42 / 9 | 42 / 9 | 0 / 0 |
| Repartos globales / destino `plaza` | 361 / 148 | 361 / 148 | 0 / 0 |
| Recetas globales / `plaza` | 396 / 195 | 396 / 195 | 0 / 0 |
| Asignaciones producto-área | 0 | 0 | 0 |

No hay conciliación antes/después de saldos por área porque no existe una tabla de saldo y no se migró stock. La identidad comprobada al cierre sigue siendo `productos.stock_actual` = fuente vigente. No se reporta una distribución espacial no observada como hecho.

## 7. Consultas y verificaciones de solo lectura

- `git status --short`, `git branch --show-current`, `git rev-parse HEAD`, `git rev-parse origin/master`, `git remote -v`.
- Metadatos de Supabase y listado de tablas/columnas expuestas de Llamita Plus.
- `SELECT` de conteos y sumas de productos globales/por sede; movimientos; lotes globales/por sede; repartos globales/destino; recetas globales/por sede; permisos; asignaciones.
- Comparación `producto_lotes` contra `productos.stock_actual` por producto, globalmente y para `plaza`.
- Lectura de `pg_trigger` y `pg_get_triggerdef` para `productos`, `producto_lotes` y las tablas de áreas.
- Lectura de `pg_get_function_identity_arguments`, `pg_get_functiondef`, catálogo de funciones que referencian `stock_actual`, restricciones, grants, RLS y `pg_policies`.
- Lectura de líneas relevantes de `index.html` y llamadas a RPC en `supabase/functions/`.
- Revisión de tablas y restricciones de B2.1; confirmadas cuatro áreas de `plaza`, cero asignaciones y ausencia de columna cantidad.

Las consultas usaron exclusivamente `SELECT`/catálogos. No se llamó a funciones RPC de operación. La consulta de PostgreSQL de versión solo observó metadatos del proyecto.

## 8. Pruebas, rollback y pendientes

- No se ejecutaron pruebas de migración, asignación múltiple, Sin asignar, mínimos/máximos, repetición ni rollback: no se creó un modelo de saldo que pudiera probarse sin simular una segunda fuente.
- Conteos verificados al inicio y al cierre de la auditoría; diferencias cero. No hubo mutaciones que requirieran rollback.
- No se preparó SQL de migración ni rollback porque el esquema objetivo requiere decisiones de fuente, compatibilidad y lote.
- `git diff --check` se ejecuta sobre la documentación resultante antes de publicar.
- B2.3 (interfaz y formularios) queda pendiente, sin activar.
- No se modificaron áreas, stock, productos, movimientos, lotes, repartos, recetas, permisos, Fudo, Lama, Central, Angamos ni la clave histórica `bodega`.
- No se accedió a Café del Desierto / Llamita Stock.
