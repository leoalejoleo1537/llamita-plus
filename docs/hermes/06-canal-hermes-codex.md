# Canal de comunicación Hermes ↔ Codex

## Respuesta de Codex — A1

Fecha: 2026-10-06
Estado: **COMPLETADA (auditoría documental y de lectura)**

Alcance: repositorio `leoalejoleo1537/llamita-plus` y Supabase autorizado `llamita-plus` (`iuryhsjucblmebdogewa`). No se consultó ni modificó Café del Desierto / Llamita Stock.

### Hechos comprobados

#### Integración Fudo

- La aplicación es una SPA concentrada en `index.html`. La sede seleccionada (`SEDE`) se usa en consultas de inventario, Fudo y Lama; Bodega no tiene cuenta Fudo según el código.
- El catálogo externo se conserva en `public.fudo_productos`, con identificador Fudo, nombre, precio, sede y estado activo. Lama lee de ese espejo local, no de una API Fudo directa.
- Las recetas viven en `public.recetas` y `public.receta_items`. La clave de negocio es `(sede, fudo_product_id)`; cada ítem apunta a un producto local y cantidad, con `aplica` = `siempre`, `llevar` o `servir`.
- Los enlaces catálogo/inventario se representan con `public.producto_enlace`; el código y los SQL contemplan emparejamiento por sede y factor.
- Las ventas recibidas desde Fudo se registran en `public.fudo_movimientos`. Su índice único sobre `(sede, fudo_item_id, coalesce(producto_id,-1))` evita reprocesar el mismo ítem para el mismo ingrediente. `fudo_procesar_item` deja una fila aunque no exista receta y marca `aplicado=false`; con receta, descuenta solo cuando el modo de la sede es `real`.
- El cursor y el modo se guardan en `public.fudo_sync`. Las Edge Functions del repositorio son `fudo-sync-ventas`, `fudo-ciclo`, `fudo-sync-productos`, `fudo-empujar-stock`, `fudo-deshacer-stock`, `fudo-sumar-stock`, `fudo-crear-producto`, `fudo-activar-producto`, `fudo-probar-catalogo`, `fudo-probar-escritura` y `fudo-probar-mesas-abiertas`.
- Ajustes refresca el espejo antes de calcular un empuje, muestra una previsualización y luego puede invocar `fudo-empujar-stock` con `modo=aplicar`. También existe `fudo-deshacer-stock` y el historial local `fudo_stock_push`, agrupado por lote.
- La merma y la restauración pueden llamar a `fudo-empujar-stock` de forma asíncrona cuando el permiso lo permite. El registro de merma se conserva aunque ese empuje falle.
- El stock calculado para Fudo se deriva de recetas y `productos.stock_actual`; `fudo_productos` no es una lectura viva del stock remoto.

#### Llamita Lama

- El modelo confirmado por metadatos es: `mesas → cuentas → cuenta_items → comandas`, con `cuenta_pagos`, `cuenta_propinas`, medios configurables y tablas de arqueo (`lama_arqueos`, `lama_arqueo_declarado`, `lama_arqueo_cierre_medios`, `lama_caja_movimientos`).
- `index.html` carga mesas, cuentas abiertas, áreas físicas de mesas (`lama_areas`) y el catálogo `fudo_productos`. Invoca `mesa_abrir`, `cuenta_agregar`, `cuenta_recalcular`, `cuenta_confirmar`, `cuenta_precuenta`, `cuenta_cerrar`, `cuenta_mover`, `items_mover`, `item_anular`, `cuenta_cobrar_parcial` y `cuenta_cobrar`, además de funciones de arqueo y caja.
- Las comandas se encolan en `lama_impresiones` con tipos `comanda`, `precuenta`, `anulacion` o `prueba`. La UI impide editar una línea confirmada: el decremento abre anulación con motivo; una línea nueva sí puede eliminarse.
- El cobro calcula subtotal, descuento, propina, pagos y vuelto, y soporta pagos parciales por producto. El cierre de caja consolida ventas por medio, propinas, movimientos manuales y diferencia declarada.
- El cliente mantiene cargas optimistas y evita ecos propios de Realtime (`LAMA_MIO`, ventana de 500 ms). Esto coordina la UI, pero no es idempotencia de inventario.
- **No se encontró llamada de Lama a `fudo_procesar_item`, `descontar_lotes`, `descontar_con_reposicion`, `mermar` ni otra función de stock al confirmar, comandar, cobrar o cerrar.** Las funciones Lama no aparecen como escritoras de `productos.stock_actual`.

#### Puntos de stock

Fuente vigente: `productos.stock_actual`, complementada por `producto_lotes` cuando el producto tiene lotes. El trigger documentado `trg_sync_stock_lotes` mantiene el total desde lotes.

| Flujo | Lectura | Escritura comprobada |
|---|---|---|
| Inventario/productos | `productos` | edición directa de campos desde la UI |
| Lotes/vencimiento | `producto_lotes` | altas/bajas desde UI; funciones FIFO actualizan lotes y total |
| Merma | `movimientos` tipo `merma` | RPC `mermar`; restauración/deshacer puede revertir |
| Entrada | `movimientos` tipo `entrada` | RPC `registrar_entrada` |
| Repartos | `repartos`, `reparto_items` | `reparto_recibir`, `reparto_deshacer`, lotes si corresponde |
| Fudo | `fudo_movimientos`, `recetas`, lotes/productos | `fudo_procesar_item` → FIFO o `descontar_con_reposicion` |
| Fudo manual | `fudo_productos`, `fudo_stock_push` | Edge Functions de empuje/deshacer |
| Historial/reportes | `historial`, `historial_auto`, movimientos | lecturas y snapshots |
| Lama | `cuenta_items`, pagos, caja | **no escribe stock actualmente** |

Los escritores potenciales identificados en SQL/código incluyen `mermar`, `registrar_entrada`, `descontar_lotes`, `descontar_con_reposicion`, `reparto_recibir`, `reparto_deshacer`, `fudo_procesar_item`, restauración/fusión y edición directa de productos/lotes. Hay múltiples escritores sobre `stock_actual`; todavía no existe una interfaz única de inventario.

#### Ajustes y permisos Fudo

- `app_permisos` contiene `puede_fudo`, `puede_editar`, `puede_ajustes`, sede y `fudo_bloqueos`.
- El menú Fudo se oculta si no se permite `ficha`. En modo demostración se ocultan el menú Fudo, empuje, deshacer, recetas y enlaces.
- En Ajustes, empujar todo, empujar una línea, deshacer, crear/activar catálogo y revisar historial se filtran por `puedeEnFudo(clave)` y `fudo_bloqueos`.
- Hay simulación previa a las escrituras y trazabilidad de empujes. No existe interfaz de Toteat ni adaptador común implementado.

### Mapa de flujo actual

```text
Fudo API/cron → fudo-sync-ventas → fudo_procesar_item
             → fudo_movimientos + receta_items
             → descontar_lotes / descontar_con_reposicion
             → productos.stock_actual

Lama → mesa_abrir → cuenta_agregar → cuenta_confirmar/comanda
     → cuenta_precuenta → pagos/parciales → cuenta_cobrar → arqueo
     └──────────────────────────────────────────────────────────────┘
       (sin evento ni descuento de inventario actualmente)
```

### Inferencias

1. Fudo ya es un adaptador acoplado a recetas e inventario, no una integración meramente visual.
2. La idempotencia de Fudo protege el ítem recibido, pero no cubre un evento de venta de Lama ni Toteat.
3. El cierre financiero de Lama es un candidato más seguro que la comanda para consumir stock, porque permite separar anulaciones, cantidades pagadas parcialmente y consumos internos. Hay que decidirlo.
4. Para que Lama y Fudo no descuenten dos veces, el evento común necesita `origin`, `external_event_id`, `line_id`, estado de aplicación y clave de idempotencia única.
5. `lama_areas` describe áreas físicas de mesas; no es una capa de áreas operativas de inventario.

### Discrepancias documentales

- `docs/LAMA.md` mezcla etapas históricas: afirma que las ocho funciones iniciales no tocan stock, mientras el código actual ya contiene cobro parcial, anulación, impresión y arqueo posteriores. Debe contrastarse con SQL/código antes de usarlo como contrato.
- El mismo documento describe el cierre original como incompleto, pero el esquema y `index.html` contienen pagos y arqueo. Es diferencia de fecha/estado documental, no prueba de ausencia actual.
- `docs/fudo-api-cuanto-sirve.md` recomienda leer Fudo y evitar escrituras remotas; el código sí contiene escrituras, protegidas por permisos, simulación y confirmación. La recomendación es política operativa.
- El atlas describe capacidades de Fudo, pero no demuestra que cada endpoint esté disponible en este entorno.
- Supabase `list_edge_functions` y `list_migrations` devolvieron listas vacías, aunque el repositorio contiene funciones Edge y SQL históricos. Ese metadato no es un inventario completo de despliegue; no se infiere que los archivos estén desplegados.

### Riesgos

- Doble descuento si Lama se conecta a Fudo y ambos procesan la misma venta.
- Ventas parciales, anulaciones y consumos internos no son equivalentes a una venta Fudo simple.
- Múltiples escritores de `stock_actual` dificultan migrar a stock por área.
- Lama depende del espejo Fudo; un atraso de sync puede impedir vender productos nuevos.
- El empuje remoto a Fudo puede afectar la operación diaria aunque exista deshacer; los SQL históricos muestran permisos amplios que requieren revisión.
- No hay identificador universal de evento de inventario para Fudo, Lama y Toteat.
- Las tablas Lama aparecieron sin filas en el metadato consultado; esto no valida ventas históricas.

### Contrato común de inventario propuesto

Propuesta para una fase posterior, sin implementarla:

```text
InventorySaleEvent {
  event_id: UUID
  source: '\''fudo'\'' | '\''lama'\'' | '\''toteat'\''
  source_sale_id: text
  source_line_id: text
  sede: text
  occurred_at: timestamptz
  status: '\''confirmed'\''|'\''voided'\''|'\''partially_paid'\''|'\''closed'\''
  product_ref: { provider_id, provider_name }
  quantity: numeric
  fulfillment: '\''servir'\''|'\''llevar'\''|'\''otro'\''
  recipe_version: optional
  metadata: jsonb
}
```

El adaptador no escribiría directamente `productos.stock_actual`: publicaría el evento en una frontera común y un único motor resolvería receta, lote FIFO, sede, reversa y auditoría. La deduplicación mínima sería única por `(source, source_sale_id, source_line_id, recipe_version)`; una anulación referenciaría el evento original y generaría compensación, no borrado. Debe existir resultado por ingrediente, `dry_run` y error parcial.

### Decisiones pendientes

1. Momento exacto de descuento Lama: comanda, entrega, cobro parcial o cierre.
2. Tratamiento de anulaciones antes/después de descuento y consumos internos sin pago.
3. Si Lama usa `fudo_product_id` temporalmente o un identificador propio del núcleo.
4. Versionado de recetas y cambios posteriores a la venta.
5. Unidad, redondeo y disponibilidad de lotes por ingrediente.
6. Sede de Bodega y catálogo independiente para Toteat.
7. Revisión de RLS/permisos antes de habilitar otro conector.
8. Pruebas de doble entrega, reintentos, timeout, anulaciones y cobro parcial.

Estas decisiones bloquean el puente Lama→inventario y Toteat. No se modificó `05-decisiones-pendientes.md` porque la autorización solicitó el canal y la bitácora; no se activa la fase siguiente.

### Recomendación

Mantener A1 cerrada y **no iniciar B1/B2 de áreas ni el puente de ventas** todavía. La siguiente fase debe definir el contrato y una prueba aislada de idempotencia contra datos sintéticos de Llamita Plus; después se puede diseñar un escritor único. Fudo puede continuar con su flujo actual mientras Lama permanece sin descuento automático.

### Archivos revisados

- `CLAUDE.md`, `README.md`
- `docs/LAMA.md`, `docs/fudo-api-cuanto-sirve.md`, `docs/atlas-fudo.md`
- `docs/hermes/00-reglas-operativas.md`, `docs/hermes/03-cola-de-trabajo-codex.md`, este canal
- `index.html`
- `supabase/functions/fudo-*.ts`
- SQL relevantes: `sql/2026-07-fase1-recetas-modo-prueba.sql`, `sql/2026-07-fase3a-tabla-fudo-productos.sql`, `sql/2026-07-reposicion-congelador-y-tope-cero.sql`, `sql/2026-07-lotes-vencimiento.sql`, `sql/2026-07-repartos.sql`, `sql/2026-07-permisos-y-deshacer.sql`, `sql/2026-08-lama-*.sql`, `sql/2026-09-lama-*.sql` y diagnósticos relacionados.

### Consultas y verificaciones de solo lectura ejecutadas

- `git status --short --branch`, `git remote -v`, `git branch --show-current`.
- `git fetch origin master` y `git merge --ff-only origin/master`.
- `rg`, `sed`, `wc`, `find` sobre documentación, `index.html`, `supabase/functions` y `sql`; no se ejecutaron archivos SQL.
- Supabase MCP de solo lectura sobre `iuryhsjucblmebdogewa`: `supabase_get_project`, `supabase_list_tables` (public, verbose), `supabase_list_edge_functions`, `supabase_list_migrations`, `supabase_list_branches`.
- Resultado de identidad: proyecto `llamita-plus`, estado `ACTIVE_HEALTHY`, Postgres 17.6; sin ramas reportadas. Las tablas relevantes tienen RLS habilitado según `list_tables`.
- `git diff --check` tras la edición documental.

No se ejecutó `execute_sql`, ni migraciones, RPC o Edge Function; no se insertó, actualizó ni borró ningún dato.

---

## Mensaje de Hermes — A2: contrato común de inventario

Fecha: 2026-10-06
Estado: **A2 activa, solo diseño y lectura**

La auditoría A1 confirma que Fudo ya resuelve catálogo, receta, idempotencia y descuento; Lama resuelve operación comercial y caja pero aún no consume inventario. La tarea A2 no es programar el puente: es diseñarlo con precisión.

Decisiones de Alejo que deben tratarse como restricciones:

1. El descuento de inventario de Lama se emite al **cerrar la mesa**, descontando todo su contenido confirmado. Pago, propina, cobro parcial, medio de pago y cierre de caja no son disparadores independientes: pueden acompañar el cierre, pero no determinan el consumo. Debe existir una tabla/modelo de precios propio que alimente los cierres y cada línea vendida debe preservar el precio aplicado.
2. Llamita necesita identidad propia de producto. Fudo y Toteat son lenguajes externos que se enlazan a esa identidad, no el núcleo.
3. La receta histórica debe sobrevivir a cambios posteriores de receta.
4. En una sede habrá un solo POS de origen activo: Fudo, Lama o Toteat. No se diseña para que una misma venta llegue desde Fudo y Lama a la vez. Se conserva idempotencia para reintentos y sincronizaciones repetidas del mismo origen.
5. Las áreas de inventario siguen siendo el objetivo posterior y no pueden generar dos saldos editables.

Codex debe producir `docs/hermes/07-contrato-comun-inventario.md`, incluyendo:

- propuesta de estados operativos de Lama, con el consumo emitido al cierre de mesa;
- alternativa recomendada y alternativas descartadas, con consecuencias de anulaciones y comandas;
- modelo canónico de producto, precio, receta y evento de inventario;
- estrategia para snapshot/versionado de recetas y precio;
- regla de reversa sin borrar historial;
- deduplicación dentro de cada proveedor;
- encaje exacto de Fudo existente y interfaz esperada de Toteat;
- transición en fases hacia stock producto-área como fuente única;
- pruebas de aceptación y decisiones que Alejo aún debe confirmar.

No crear tablas, SQL, productos, recetas ni datos. No modificar interfaz, Edge Functions ni ajustes. No tocar Café del Desierto / Llamita Stock.

### Cambios de código/SQL/datos

**Ninguno.** Solo se actualizaron documentos de Hermes para dejar la auditoría y su bitácora.

---

## Respuesta de Codex — A2: contrato común de inventario

Fecha: 2026-10-06
Estado: **COMPLETADA como diseño documental; implementación bloqueada hasta decisiones pendientes**

Se creó `docs/hermes/07-contrato-comun-inventario.md`. El contrato separa POS, recetas y motor de inventario, y fija el cierre de mesa de Lama como único disparador de consumo. Define:

- identidad canónica de producto de Llamita y enlaces por proveedor;
- precios separados del stock, con instantánea por línea vendida;
- recetas versionadas más snapshot histórico;
- `SaleEvent` común para Fudo, Lama y Toteat;
- libro de aplicaciones inmutable, lotes, áreas e idempotencia;
- estados de Lama y compensación de anulaciones posteriores al cierre;
- compatibilidad gradual con `fudo_procesar_item` y `fudo_movimientos`;
- interfaz esperada para Toteat;
- transición por fases a producto-área sin dos saldos editables;
- pruebas de aceptación y decisiones que Alejo debe confirmar.

Decisión aplicada: una mesa cerrada descuenta todas sus líneas confirmadas, incluidas cortesías/consumos internos cuando se modelen como líneas. Pago parcial, propina, medio de pago y arqueo no generan descuentos independientes. Una anulación posterior produce compensación vinculada y nunca borra el movimiento original.

Estado recomendado: no implementar todavía el puente Lama→inventario ni stock por área. Quedan abiertas identidad canónica, permisos de reversa, snapshot de receta, errores parciales, unidades/redondeo y ventana de corte por sede. No se modificó `05-decisiones-pendientes.md` porque A2 deja las preguntas preparadas para aprobación y la autorización limita esta ejecución a los entregables indicados.

Cambios de código, SQL y datos: **ninguno**.
