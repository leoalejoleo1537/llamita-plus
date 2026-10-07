# B2.3 — bloqueo antes del corte del libro por ubicación

Fecha: 2026-10-07
Estado: **REQUIERE DECISIÓN**. La auditoría se detuvo antes de crear el libro o migrar saldos. B2.4 permanece **PENDIENTE**, no activa.

## 1. Alcance y conclusión

Alejo activó únicamente B2.3 para implementar el libro de existencias y el corte coordinado de escritores. Se verificó que el destino de datos y la decisión arquitectónica coinciden con los documentos Hermes. Sin embargo, no es seguro activar la nueva fuente mientras continúan disponibles escrituras directas y funciones heredadas sobre `productos.stock_actual` y los lotes.

La condición de salida de esta ejecución ordena detenerse si todos los escritores no pueden adaptarse o bloquearse sin dejar una fuente doble. Por ello no se aplicó DDL, migración de apertura, función, trigger, política, cambio de permisos ni modificación de datos. El resultado no es un libro implementado: la fuente vigente continúa siendo `productos.stock_actual`.

## 2. Entorno verificado

- Repositorio: `leoalejoleo1537/llamita-plus`.
- Remoto `origin`: `https://github.com/leoalejoleo1537/llamita-plus.git`.
- Rama de trabajo: `work`; al iniciar, HEAD y `origin/master` eran `aaa428fe05d81191dcf58976e515518a688e6fe2`.
- Supabase: proyecto `llamita-plus`, ref `iuryhsjucblmebdogewa`, estado `ACTIVE_HEALTHY`, PostgreSQL 17.6.
- No se accedió a Café del Desierto / Llamita Stock.

## 3. Hallazgos comprobados de escritores

La auditoría combinó lectura del código, políticas y grants instalados, catálogo de funciones/trigger y consultas de solo lectura. Los caminos que impiden declarar un corte coordinado son:

| Camino | Evidencia / efecto | Riesgo para el corte |
|---|---|---|
| Edición directa desde la aplicación | `index.html` guarda `productos.stock_actual` en edición de fila, formulario de producto y alta de producto. | El cliente puede escribir el saldo agregado directamente en los contextos que se desean migrar. |
| Reemplazo de lotes desde la aplicación | El formulario elimina e inserta filas de `producto_lotes`. | El flujo de lotes sigue siendo un escritor alternativo y no incluye ubicación. |
| DML vía Data API | Las tablas `productos`, `producto_lotes` y `movimientos` tienen políticas permisivas de escritura y grants DML amplios a `anon` y `authenticated`. | La protección solo en la interfaz no impediría escrituras API directas. Revocar DML indiscriminadamente también puede romper operaciones comerciales y edición de campos no relacionados con saldo. |
| Trigger de lotes | `trg_sync_stock_lotes` ejecuta `sync_stock_desde_lotes()` después de INSERT/UPDATE/DELETE en `producto_lotes`; la función recalcula `productos.stock_actual`. | Un cambio de lote vuelve a escribir el agregado y competiría con el libro o produciría doble descuento. |
| RPC de inventario | Entre las funciones instaladas con rutas de escritura están `registrar_entrada`, `deshacer_entrada`, `mermar`, `deshacer_merma`, `descontar_con_reposicion`, `reparto_descontar_bodega`, `reparto_recibir`, `reparto_deshacer`, `restaurar_sede`, `deshacer_restauracion`, `fusionar_productos`, `deshacer_fusion`, `crear_producto_enlazado` y `franquicia_linea_lista`. | Cambiar o bloquearlas exige conservar atomicidad, auditoría, reversas y compatibilidad de las sedes históricas no migradas. |
| Fudo | El procesamiento existente puede delegar descuentos al FIFO de lotes o a `descontar_con_reposicion`. | No se debe permitir que una configuración futura escriba silenciosamente en el modelo antiguo. Hace falta adaptar el contrato o bloquear la ruta para `central`/`plaza` antes del corte. |
| Lama–Stock | El motor existente puede aplicar descuentos, pero el modo real debe seguir apagado; hay que garantizar que no alcance una escritura antigua para estas sedes. | Debe probarse el bloqueo/adaptación en el borde de ejecución aunque el modo real esté apagado. |
| Repartos, restauraciones y fusiones | Hay funciones de reversa y operaciones que modifican stock y/o lotes, además de datos de movimiento e historial. | Una interrupción a mitad de operación puede dejar inconsistencias comerciales. No se probaron escrituras destructivas para demostrar un bloqueo. |

Las llamadas SECURITY DEFINER encontradas requieren una revisión individual de permisos y alcance por sede; un bloqueo solo en RLS no necesariamente las detiene. Los helpers existentes de trigger y las funciones invocadas indirectamente también deben quedar cubiertos.

## 4. Datos y conciliación de referencia

Las consultas de apertura y cierre fueron de solo lectura; ningún escritor se ejecutó durante la auditoría. Los valores permanecieron iguales:

| Métrica | Inicio / cierre |
|---|---:|
| Productos globales | 1.437 |
| `stock_actual` global | 15.438,00 |
| Productos `central` | 349 |
| `stock_actual` de `central` | 4.750,50 |
| Productos `plaza` | 329 |
| `stock_actual` de `plaza` | 4.566,20 |
| Lotes asociados a productos `central` | 2 filas / 96,00 unidades |
| Productos `central` con lote | 1; diferencias lote vs. `stock_actual`: 0 |
| Lotes asociados a productos `plaza` | 9 filas / 36,00 unidades |
| Productos `plaza` con lote | 6; diferencias lote vs. `stock_actual`: 0 |
| Movimientos | 431 total; 403 `central`; 25 `plaza` |
| Repartos | 361 |
| Recetas / líneas de receta | 396 / 514 |
| Permisos de aplicación (`app_permisos`) | 9 |
| Asignaciones preparatorias producto-área | 0 |
| `lama_areas` | 5 |

La suma de lotes describe parte del saldo del producto: no debe agregarse una segunda vez al saldo de apertura. Los números por sede muestran que `angamos` (351 productos, 2.764,20) y la clave histórica `bodega` (408, 3.357,10) siguen fuera del alcance; no fueron migradas. No se calcularon conteos pre/post de una migración porque no hubo migración.

## 5. Modelo y comportamiento resultantes

- No se crearon tabla de saldos, libro de movimientos, vista de proyección ni funciones atómicas nuevas.
- No se migró `central` a Bodega central ni `plaza` a Sin asignar.
- No se crearon saldos en Cocina fría, Cocina caliente, Barra o Cafetería.
- `productos.stock_actual` permanece como autoridad editable actual; **no** es todavía una proyección de compatibilidad ni lectura solamente.
- No se cambió ubicación, cantidad o vencimiento de lotes.
- No se alteraron movimientos, repartos, recetas, permisos ni configuración de Lama/Fudo.

## 6. Decisiones y precondiciones para reanudar B2.3

Antes de volver a activar la escritura de apertura, debe existir un plan de corte revisable que identifique por nombre y firma instalada cada ruta de escritura, incluido el SQL real de las funciones, y escoja explícitamente para cada una:

1. Adaptar a una operación interna atómica del libro; o
2. bloquear para `central`/`plaza` con rechazo explícito antes de modificar cualquier movimiento, lote, pago, cierre o historial relacionado.

El plan debe además especificar cómo se conservan las operaciones de `angamos` y `bodega`, cómo se protegen campos de producto que no son stock al retirar permisos DML amplios, cómo se desacopla el trigger de lotes sin perder compatibilidad, y cómo Fudo y Lama reciben un error/resultado explícito. La reactivación necesita pruebas de permisos reales y regresión con rollback antes de migrar saldos.

La migración aprobada en el documento 17 continúa siendo el destino si el corte se resuelve: saldo actual de `central` a Bodega central; saldo de `plaza` a Sin asignar; conservar los lotes dentro de esos saldos; no migrar `angamos` ni la clave `bodega`; no clasificar automáticamente.

## 7. Pruebas y verificaciones

- Verificación del repositorio, remoto, rama y SHA local/remoto.
- Verificación de identidad/estado del proyecto Supabase.
- Consultas SELECT de conteos globales y por sede, stock agregado, cantidades y distribución de lotes, movimientos, repartos, recetas, permisos y tablas de áreas.
- Revisión de políticas/grants, firmas/privilegios de funciones instaladas, trigger y referencias de escritores en la aplicación.
- Conciliación observada de lotes contra productos para `central` y `plaza`: sin diferencias por producto; lotes no sumados de nuevo.
- `git diff --check` se ejecuta para esta actualización documental antes de publicar.

No se ejecutaron pruebas de esquema, permisos por intento de escritura, migración, transferencia ni regresión de aplicación: no existió implementación que probar y provocar escrituras para ensayar fallos habría sido incompatible con el bloqueo de seguridad. La autorización de esta ejecución tampoco permite transformar estos ensayos en mutaciones persistentes.

## 8. Rollback

No hay migración ni cambio de datos de B2.3 que revertir en esta ejecución. No se prepara un rollback SQL vacío o destructivo.

Para una futura implementación, antes de que existan operaciones posteriores en el libro, la apertura puede revertirse solo si se demuestra que las filas/movimientos corresponden exclusivamente a esa apertura, se restaura primero una ruta única de escritura y se vuelve a conciliar producto por producto. Una vez existan transferencias u operaciones posteriores, no se borran: la reversión será compensatoria y auditada, con los movimientos de apertura conservados y una conciliación documentada.

## 9. Archivos Hermes y siguiente fase

Se actualizan el plan, la cola, la bitácora y este canal; se corrige en el documento 17 la referencia antigua que llamaba B2.3 a la interfaz. Este resultado es el documento número 18 disponible. No se modificó código, SQL, esquema o datos.

**B2.4 — existencias por áreas operativas: PENDIENTE, no activar automáticamente.** La interfaz de áreas queda para una fase UX posterior, después de completar B2.3 y B2.4.
