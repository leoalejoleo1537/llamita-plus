# B2.3 — Corte coordinado al libro de existencias por ubicación

**Fecha:** 2026-10-07
**Estado:** COMPLETADO para `central` (Bodega) y `plaza` (Local 1).
**Proyecto:** Supabase Llamita Plus, `iuryhsjucblmebdogewa`.
**Repositorio:** `leoalejoleo1537/llamita-plus`.
**Siguiente bloque:** B2.4 queda PENDIENTE; no fue activado.

## Alcance y decisión

Alejo autorizó el corte coordinado y temporal de `central` y `plaza`. La autoridad de cantidades para ambas sedes pasa al libro privado por ubicación. La migración de apertura coloca `central` en Bodega central y `plaza` en Sin asignar. No hace clasificación histórica automática. No migra `angamos` ni la clave histórica independiente `bodega`.

Las ubicaciones físicas Cocina fría, Cocina caliente, Barra y Cafetería se registraron para `plaza`, pero permanecen con saldo cero. B2.3 no entrega interfaz de transferencia ni habilita aún la operación cotidiana de stock en estas áreas.

## Modelo instalado

El esquema `stock_internal` no está expuesto a clientes. Tiene RLS habilitado, una política restrictiva de denegación en sus tablas, y no otorga `USAGE` ni mutación directa a `PUBLIC`, `anon`, `authenticated` o `service_role`.

| Relación | Uso |
| --- | --- |
| `stock_internal.ubicaciones` | Catálogo sede/código/nombre, enlazado a área cuando corresponde. |
| `stock_internal.movimientos` | Libro inmutable por producto, sede, ubicación y lote; cantidad con signo, tipo, fecha, actor, referencia y clave idempotente. |
| `stock_internal.aperturas` | Referencia de migración, conteos anterior/posterior y actor/sistema. |
| `stock_internal.transferencias` | Referencia común, producto lógico origen/destino, ubicaciones, lote, cantidad e idempotencia. |
| `stock_internal.permiso_proyeccion` | Permiso transaccional interno para refrescar la proyección de compatibilidad. |
| `stock_internal.existencias` | Vista agregada de movimientos por producto/sede/ubicación/lote. |

Los triggers mantienen `productos.stock_actual` como proyección protegida. Una mutación directa del saldo en `central` o `plaza` falla; una modificación originada por el libro requiere un permiso interno de la transacción. Un producto de esas sedes se crea con saldo cero. No se permite cambiarlo de sede ni borrarlo mediante los caminos protegidos.

Las aperturas persistentes son movimientos `apertura_migracion` idempotentes. Los lotes legados conservan su producto, cantidad y vencimiento, pero quedan congelados en las sedes cortadas mientras no exista un escritor de lotes que opere contra el libro. Se tratan como detalle y no se suman nuevamente al agregado. El disparador histórico que recalculaba el saldo desde `producto_lotes` queda neutralizado para las sedes migradas; la conducta legada de las otras sedes se conserva.

## Escritores y protección del corte

| Camino | Estado en `central` / `plaza` |
| --- | --- |
| Edición directa de `productos.stock_actual` | Rechazada por trigger; la UI deshabilita el campo y explica el corte. |
| Alta de producto con saldo inicial distinto de cero | Rechazada; el saldo de alta se fuerza a cero. |
| Lotes y sincronización lote→agregado | Mutación bloqueada; trigger histórico no reescribe la proyección para sedes migradas. |
| Movimientos legacy | Inserción bloqueada. |
| Entradas y ajustes por RPC heredados | Rechazados antes de escribir en el modelo antiguo. |
| Mermas y reversas heredadas | Rechazadas para las sedes cortadas. |
| Repartos, líneas y deshacer reparto | Bloqueados para las sedes cortadas; no se deja movimiento comercial parcial. |
| Restauraciones y fusiones | Bloqueadas para las sedes cortadas. |
| Cambio/borrado de producto migrado | Bloqueado para evitar cambiar el dueño del saldo. |
| Fudo modo real / aplicar movimiento | Bloqueado por trigger de configuración y de aplicación. El inventario remoto no se tocó. |
| Lama–Stock real | Continúa bloqueado; `lama_stock_config` quedó vacía. |

La interfaz también oculta la capacidad de editar el saldo y detiene los formularios legacy relevantes. Los RPC/trigger en base son el control autoritativo; el cambio visual no reemplaza esos controles.

Las fuentes de las cinco Edge Functions Fudo relacionadas con stock ahora responden con bloqueo explícito para `central` y `plaza`; `fudo-ciclo` conserva el historial de ventas y omite el envío de stock para esas sedes. **Las Edge Functions no se desplegaron como parte de B2.3.** El control persistente de Supabase impide el escritor de stock antiguo en la configuración actual; cualquier despliegue futuro de las fuentes requiere validación/publicación separada. Fudo no recibió cambios remotos.

Contrato futuro documentado: Fudo podrá recibir una proyección de stock vendible calculada desde ubicaciones, pero no escribirá directamente `productos.stock_actual`. Una sede debe tener un solo POS de origen activo entre Fudo, Lama y Toteat; este bloque no habilitó descuentos reales ni diseñó descuentos dobles.

Para conservar identidad durante la transferencia sintética, el catálogo actual usa productos enlazados por sede con IDs numéricos distintos. La función interna valida la relación de `producto_enlace`, registra la pareja origen/destino, comparte cantidad, lote y referencia de transferencia y aplica la operación de forma atómica. Es una limitación de la identidad existente que una fase posterior debe mantener explícita.

## Migración y conciliación

Se aplicaron exclusivamente en Llamita Plus:

- `20261007152558 b2_3_libro_existencias_corte`
- `20261007152805 b2_3_indices_permisos_libro`

La primera crea catálogo, aperturas, movimientos, transferencia, vista, funciones internas, triggers y bloqueos legacy. La segunda agrega índices a claves foráneas nuevas y políticas restrictivas explícitas de denegación. El archivo SQL versionado del repositorio es `supabase/migrations/20261007145034_b2_3_libro_existencias_corte.sql`; el registro instalado en Supabase tiene el identificador de migración aplicado consignado arriba.

| Medida | Antes | Después |
| --- | ---: | ---: |
| Productos globales | 1.437 | 1.437 |
| Stock agregado global | 15.438,00 | 15.438,00 |
| `central`: productos / stock | 349 / 4.750,50 | 349 / 4.750,50 |
| `plaza`: productos / stock | 329 / 4.566,20 | 329 / 4.566,20 |
| `angamos`: productos / stock | 351 / 2.764,20 | 351 / 2.764,20 |
| `bodega` histórica: productos / stock | 408 / 3.357,10 | 408 / 3.357,10 |
| Lotes globales / cantidad | 42 / 304,00 | 42 / 304,00 |
| Movimientos legacy | 431 | 431 |
| Repartos / líneas | 361 / 2.040 | 361 / 2.040 |
| Recetas / líneas | 396 / 514 | 396 / 514 |
| Permisos por aplicación | 9 | 9 |
| `lama_stock_config` | 0 | 0 |

El libro contiene 408 movimientos de apertura por **9.316,70**: 150 productos de `central` por 4.750,50 y 258 de `plaza` por 4.566,20. La conciliación por producto y sede no detectó diferencias; el total del libro de apertura es exactamente la suma de ambos saldos anteriores. No es una segunda suma con los lotes: estos siguen siendo un detalle separado del saldo.

Las cuatro ubicaciones físicas de `plaza` tienen cero cantidad. La prueba también verificó que una existencia lógica de leche en Bodega y otra en Sin asignar se modelan como filas separadas por sede y ubicación.

## Pruebas ejecutadas

`sql/2026-10-b2-3-pruebas-transaccionales.sql` se ejecutó íntegramente dentro de `BEGIN ... ROLLBACK` y revirtió todas las filas de prueba. `npm test` terminó con código cero. `esbuild` pudo analizar sintácticamente las cinco fuentes TypeScript de Edge Functions modificadas. `git diff --check` pasó antes del cierre.

La prueba transaccional cubrió:

- conteos, suma por sede y conciliación por producto/global;
- igualdad del detalle de lotes sin doble suma;
- bloqueo de `UPDATE productos.stock_actual`, RPC de merma/entrada, restauración, fusión, lote, movimiento legacy, reparto y línea de reparto;
- ausencia de acceso directo a las tablas internas y rechazo de modos/aplicaciones Fudo o Lama reales;
- transferencia sintética Bodega -12 y Cafetería +12, mismo producto lógico, lote y referencia, suma global conservada, reintento idempotente y reversión completa;
- permisos y protección de `productos.stock_actual` como proyección.

Después de rollback, la tabla de transferencias y las transferencias del libro siguen vacías; no quedaron filas sintéticas ni cambió ningún stock, lote, movimiento comercial, reparto, receta o permiso.

`npm test` informa que pruebas visuales de navegador se saltaron porque no hay navegador instalado en el entorno. No hubo inspección visual ni consola de navegador. Las funciones Edge no se desplegaron. Los advisors conservan avisos de rendimiento por índices recién creados aún no usados; las tablas son nuevas y el uso real comenzará cuando el flujo de B2.4/operaciones se implemente. Los avisos previos de seguridad en vistas públicas y otras tablas existentes no fueron introducidos por B2.3.

## Rollback y riesgos

El rollback técnico está en `sql/2026-10-b2-3-libro-existencias.rollback.sql`. Solo procede mientras no existan movimientos posteriores a las aperturas ni transferencias. Verifica esa condición y aborta antes de retirar controles si hay actividad. No borra registros posteriores. Si el libro ya tuvo operaciones, la vuelta requiere reversión compensatoria con trazabilidad y conciliación, nunca borrar movimientos reales para restaurar un saldo anterior.

Hasta que se implemente B2.4 o una fase de operaciones por ubicación:

- entradas, ajustes, mermas, repartos, movimientos manuales y manejo de lotes están pausados para `central` y `plaza`;
- el stock agregado sigue siendo visible como proyección compatible, pero no puede editarse;
- las Edge Functions Fudo actualizadas no se desplegaron; la protección de base bloquea la escritura antigua, pero la respuesta amigable del endpoint requiere desplegar y verificar esas funciones en una ejecución autorizada;
- no existe aislamiento técnico de datos entre Local 1 y otras sedes.

B2.4 debe diseñar operaciones de stock por ubicación y habilitar escrituras atómicas antes de reabrir estos flujos. No se activa automáticamente.

## Archivos de B2.3

- Migraciones: `supabase/migrations/20261007145034_b2_3_libro_existencias_corte.sql`, `supabase/migrations/20261007152735_b2_3_indices_permisos_libro.sql`.
- Pruebas: `sql/2026-10-b2-3-pruebas-transaccionales.sql`.
- Rollback: `sql/2026-10-b2-3-libro-existencias.rollback.sql`.
- UI: `index.html`.
- Guardas fuente de Fudo: `supabase/functions/fudo-ciclo/index.ts`, `fudo-deshacer-stock/index.ts`, `fudo-empujar-stock/index.ts`, `fudo-probar-escritura/index.ts`, `fudo-sumar-stock/index.ts`.
- Hermes: cola, bitácora, canal y plan de áreas.

No se accedió a Café del Desierto / Llamita Stock. No se alteró inventario remoto de Fudo, ventas, pagos, stock agregado previo, lotes, movimientos, repartos, recetas ni permisos existentes.
