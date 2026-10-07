# Decisión arquitectónica — libro de existencias por ubicación

Fecha de aprobación: 2026-10-07
Aprobada por: Alejo
Estado: **decisión aprobada; implementación no activada**. B2.2 se cierra como `REQUIERE DECISIÓN RESUELTA`. B2.3 queda pendiente.

## 1. Fuente futura de verdad

La autoridad futura será un **libro de existencias por ubicación**, no varios campos editables de stock. Cada saldo se identifica conceptualmente por:

- producto;
- sede;
- ubicación;
- lote, cuando corresponda.

El diseño físico de tablas, ledger de movimientos, saldo derivado, funciones y permisos se define al activar el bloque de implementación correspondiente. Este documento no crea esquema ni habilita escrituras.

`productos.stock_actual` se conservará como proyección de compatibilidad de solo lectura, derivada de los saldos por ubicación de ese producto y sede. No puede permanecer editable como segundo saldo. Las lecturas antiguas solo pueden seguir funcionando mientras esa proyección sea unidireccional y se concilie con el libro.

## 2. Ubicaciones iniciales

| Sede | Ubicación | Papel |
|---|---|---|
| `central` | Bodega central | Punto normal de recepción, conteo y origen logístico de repartos. |
| `plaza` | Sin asignar | Existencia de Local 1 aún no distribuida o contada por área. |
| `plaza` | Cocina fría | Ubicación operativa. |
| `plaza` | Cocina caliente | Ubicación operativa. |
| `plaza` | Barra | Ubicación operativa. |
| `plaza` | Cafetería | Ubicación operativa. |

Sin asignar es una ubicación lógica de inventario para `plaza`; no significa cero stock ni una quinta área física. Bodega central es ubicación logística en la sede `central`, no un área de preparación de Local 1. Las claves de sede `angamos` y `bodega` no se reutilizan.

Un producto puede habilitarse para más de un área, pero habilitarlo no crea cantidad. Cada cantidad física queda contabilizada una sola vez. Para distribuir existencias entre áreas se registra explícitamente una o más transferencias con salida y entrada balanceadas.

## 3. Flujo Bodega → área

1. Todo producto físico nuevo se recibe primero en Bodega central. Bodega sigue siendo el lugar normal de recepción, conteo y origen de reparto.
2. Al preparar un reparto hacia Local 1 se selecciona un destino explícito: Cocina fría, Cocina caliente, Barra o Cafetería.
3. Al confirmar, el sistema registra una única transferencia atómica: reduce la ubicación de origen en Bodega e incrementa la ubicación de destino en `plaza` por la misma cantidad. Si cualquiera de los dos lados falla, ninguno queda aplicado.
4. El registro conserva producto, cantidad, usuario, fecha y lote cuando exista; mantiene claves de idempotencia para reintentos y su traza no depende solo del saldo agregado.
5. Una distribución posterior desde Sin asignar se registra con el mismo principio de transferencia. Las primeras distribuciones aprobadas por esta política llevan procedencia `simulacion`; las reglas por nombre solo proponen destino y no escriben asignaciones automáticamente.

La transferencia entre sedes debe respetar las identidades de producto que existan en cada catálogo. La implementación debe resolver esa relación usando los enlaces vigentes y probar la conciliación antes de descontar; no debe asumir IDs iguales entre Bodega y Local 1.

## 4. Módulo global de mermas y consultas

- Las mermas se mantienen en un único módulo global.
- Cada merma debe identificar la ubicación/área donde ocurrió la pérdida y reducir solo ese saldo.
- Los registros históricos sin ubicación no se reasignan retroactivamente.
- Críticos, reportes y búsqueda se agregan o filtran por área/ubicación. La vista global agrupa el mismo producto y expone su distribución, sin contar una unidad dos veces.
- Los mínimos y máximos futuros pertenecen a la combinación producto/ubicación y no pueden confundirse con los límites globales actuales.

## 5. Migración inicial aprobada (futura, aún no ejecutada)

La carga inicial no aplica heurísticas históricas:

- Todo saldo actual de productos de `central` se representa en Bodega central.
- Todo saldo actual de productos de `plaza` se representa en Sin asignar de Local 1.
- Los lotes actuales asociados a productos de `plaza` comienzan en Sin asignar. No se inventa una ubicación de área histórica.
- Los lotes asociados a productos de `central` acompañan el saldo de Bodega central conservando su identidad y vencimiento.
- `angamos` conserva su historia y no se migra en esta fase.
- La clave histórica `bodega` conserva su historia y no se migra en esta fase.
- No se ejecuta clasificación histórica automática. Las reglas de nombre/categoría solo sugieren una futura transferencia revisable.
- La conciliación inicial debe ser exacta por producto, sede, ubicación y lote, además de global por sede. No se cambia el total de stock ni se suman los lotes de nuevo encima del saldo que representan.

La aprobación fija el destino inicial de la migración; no constituye autorización para ejecutarla en este cambio documental.

## 6. Proyección de compatibilidad `productos.stock_actual`

La proyección futura se deriva de la suma de las ubicaciones del producto dentro de una misma sede: `central` resume Bodega central; `plaza` resume Sin asignar y sus cuatro áreas. No incluye ni mezcla sedes archivadas o claves históricas.

Condiciones para habilitar la proyección:

- fuente de escritura única en el libro de ubicaciones;
- `stock_actual` no admite `INSERT`/`UPDATE` desde interfaz, API o funciones comerciales;
- todas las lecturas que deban distinguir áreas consultan el modelo por ubicación;
- lecturas antiguas solo ven un agregado calculado que no permite escribirlo de vuelta;
- trigger de lotes y todos los RPC/escritores existentes se adaptan sin doble descuento ni bypass;
- permisos RLS/API impiden cambiar saldos fuera de operaciones autorizadas.

No se eliminará `stock_actual` como parte de esta decisión. Un eventual retiro exige una fase y autorización posterior, una vez retirados sus consumidores.

## 7. Lotes y vencimientos

El lote es parte del identificador conceptual del saldo cuando corresponde. La migración de productos de `plaza` y sus lotes comienza en Sin asignar, preservando identidad y vencimiento. Las transferencias posteriores deben conservar el lote o registrar una distribución auditable de su cantidad; nunca duplicar la cantidad del lote en ubicaciones distintas.

Antes del corte se debe demostrar que FIFO, merma, reversas, entradas y transferencias actualizan el libro y los lotes una sola vez. El trigger actual que recalcula `productos.stock_actual` no puede seguir escribiendo una fuente competidora.

## 8. Recetas y Lama–Stock

Las recetas no descuentan existencias por área en esta etapa. Lama–Stock real y cualquier activación de receta permanecen apagados hasta que:

1. exista el libro por ubicación;
2. se hayan adaptado y probado sus escritores;
3. el consumo determine una ubicación de inventario inequívoca;
4. idempotencia, lotes y conciliación estén verificados.

La configuración actual de prueba de Lama no se cambia con esta decisión.

## 9. B2.3 — interfaz y formularios (pendiente)

**Estado: PENDIENTE; no activado.** Su implementación requiere activación explícita y que el backend/modelo de ubicación y sus adaptadores estén listos. Esta especificación no autoriza cambios de interfaz.

### Alcance previsto

- Portada de inventario con Bodega central, Sin asignar y las cuatro áreas iniciales.
- Páginas filtradas por ubicación y búsqueda global que agrupe producto con saldo por ubicación.
- Formularios sin escritura directa de `productos.stock_actual`; altas y ajustes llaman al backend autorizado.
- Selección de destino de área en el flujo de reparto desde Bodega.
- Módulo global de mermas que exige la ubicación/área de ocurrencia.
- Críticos, mínimos/máximos, reportes y búsqueda calculados por ubicación.
- Indicadores visibles de Sin asignar y trazabilidad de lote cuando corresponda.

### Criterios de salida

- Los saldos se muestran en la ubicación correcta; las unidades no aparecen en dos ubicaciones.
- Reparto indica origen y destino y no deja cambios parciales; reintento no duplica.
- Mermas solo reducen la ubicación elegida y guardan usuario, fecha, motivo y producto.
- Lote/vencimiento y reversa conservan la cantidad y la ubicación correcta.
- La vista global y los filtros por área concilian con el libro por producto/sede.
- No existe escritura desde los formularios a `stock_actual` ni acceso directo que eluda el backend.
- `angamos` y la clave `bodega` no aparecen como ubicaciones migradas; el acceso a sedes respeta sus estados.
- Pruebas de ruta, permisos, errores/reintentos, doble confirmación, datos vacíos y escritorio/móvil pasan.
- Recetas y Lama–Stock real permanecen apagados.

## 10. Rollback y conciliación requeridos

El futuro plan de migración debe incluir, antes de la primera escritura:

1. Snapshot inmutable de conteos y sumas por producto/sede, saldo global, lotes/vencimientos, movimientos, repartos, recetas y permisos.
2. Una migración idempotente y transaccional, o por lotes con checkpoint y conciliación; no puede duplicar saldo si se reintenta.
3. Reconciliación por producto: saldo previo de cada sede = suma de ubicaciones iniciales correspondientes; detalle de lotes = saldo que representan, sin sumar ambos como cantidades independientes.
4. Reconciliación global y por sede de productos, movimientos, repartos y lotes; `angamos` y `bodega` histórica deben quedar idénticas.
5. Prueba de transferencia atómica, error en origen/destino, reintento y rollback dentro de transacción antes de habilitar uso real.
6. Rollback de esquema que se detiene si hay transferencias operativas posteriores. No borrar movimientos nuevos: revertir movimientos con entradas compensatorias auditadas, luego restaurar la proyección/compatibilidad y validar conteos y cantidades.
7. Verificación posterior de que solo el libro acepta escritura y `productos.stock_actual` es lectura de compatibilidad.

No se escribió ni se preparó SQL en esta actualización documental. B2.2 se cierra como decisión resuelta; B2.3 queda pendiente.
