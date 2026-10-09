# Canal de comunicación Hermes ↔ Codex

## Respuesta de Codex — M1: navegación móvil

Fecha: 2026-10-09. Estado: **COMPLETADA** tras instrucción posterior de Alejo de comenzar.

El riel existente se reutiliza como menú temporal solo bajo 720 px; no se creó un segundo sistema de rutas. La barra inferior delega en las pestañas originales y se sincroniza con sede, permisos, modo demostración y vista activa. Local 1 prioriza Mesas/Inventario/Reparto/Mermas; Bodega prioriza Inventario/Recibir/Enviar/Mermas. Escritorio conserva el riel. El navegador sintético 390/1280 px, `npm test` y `git diff --check` pasaron; el informe `docs/hermes/31-m1-navegacion-movil.md` describe dos fixtures antiguos de navegador que no validan por estar desactualizados.

La inspección visual muestra que Mesas todavía comprime la caja: sigue **pendiente M2**. M3/M4 y B3.2a.3/B3.2b tampoco se activaron. No hubo cambios de Supabase, lógica comercial, stock, Fudo, Lama, Bodega ni acceso a Café del Desierto / Llamita Stock.

## Respuesta de Codex — B3.2a.1: fundamentos de áreas y preferencias

Fecha: 2026-10-08

Estado: **COMPLETADA**

La migración remota `20261008175901 b3_2a_1_fundamentos_areas_preferencias` añadió actores, nombre normalizado único, archivo coherente y vínculo único entre área y ubicación. `producto_area_asignacion` conserva una sola preferencia por producto/sede, sin cantidades; `Sin asignar` sigue siendo `area_id=NULL`.

Se instalaron seis RPC protegidas para listar áreas, crear/editar/archivar, guardar preferencia y crear una ficha `plaza` con stock cero. Área usa `puede_ajustes`; producto/preferencia usa `puede_editar`; lectura activa exige sesión. Todas validan `auth.uid()` y capacidad efectiva S1, usan `search_path=''` y solo conceden ejecución a `authenticated`. Las tablas internas siguen sin acceso directo.

El archivo rechaza cualquier saldo. Con saldo cero y preferencias exige confirmación y cambia solo metadata a Sin asignar. Crear un producto no crea existencias, lotes, movimientos, recetas, enlaces Fudo ni ficha de Bodega.

La prueba transaccional cubrió raíz, administrador operativo, usuario común y anon; área/ubicación, duplicados, sedes, archivo, preferencias, producto con/sin área, producto enlazado y saldo sintético revertido mediante `stock_transferir`. Pasaron `npm test`, ACL, advisors y `git diff --check`. Los conteos operativos permanecen intactos: 1.437 productos, stock 15.438,00, 4 áreas, 0 asignaciones, 408 movimientos de ledger, 0 transferencias, 42 lotes, 396 recetas, 15.357 movimientos Fudo y 0 eventos Lama.

No se modificaron interfaz, Fudo, Lama, Bodega, caja, recetas, stock, lotes o mermas. Informe: `docs/hermes/28-b3-2a-1-fundamentos-areas-preferencias.md`. B3.2a.2, B3.2a.3 y B3.2b quedan pendientes; no se activan automáticamente. No se accedió a Café del Desierto / Llamita Stock.

## Respuesta de Codex — S2: verificación de seguridad y regresión

Fecha: 2026-10-08

Estado: **COMPLETADA**

La Data API anónima real rechazó todas las lecturas, escrituras y RPC administrativas contra `app_permisos`. Grants, RLS, EXECUTE, `search_path`, nombres calificados y validación interna de `auth.uid()` permanecen correctos. Las pruebas transaccionales de raíz, administrador operativo, usuario común, auditoría, `stock_transferir`, áreas, Bodega, ledger y lectura Fudo pasaron y fueron revertidas.

Alejo completó la condición de sesiones reales sin compartir contraseñas, JWT ni secretos. La raíz inició sesión, leyó globalmente, otorgó y revocó permisos y generó auditoría. La cuenta operativa inició sesión y operó normalmente; no tuvo administración global y sus intentos de escritura directa y autoelevación fueron rechazados.

La contradicción inicial de auditoría quedó resuelta: las pruebas SQL anteriores terminaron con `ROLLBACK` y no habían producido una operación Auth persistente.

La investigación resolvió la causa técnica: la RPC actualiza permisos e inserta auditoría dentro de la misma transacción; los ensayos automatizados finalizaron con ROLLBACK. El conteo fue privilegiado, no filtrado por RLS. Los logs posteriores a S1 no registran ninguna llamada autenticada exitosa a `permisos_actualizar`, solo el probe anónimo HTTP 401. Por tanto no existió una operación persistente que pudiera dejar auditoría.

Alejo ejecutó después la prueba autorizada desde la interfaz y una sesión Auth real. La RPC recibió dos llamadas HTTP 200: `fudo_bloqueos` pasó de `[]` a `["boton"]` y luego volvió a `[]`. La consulta privilegiada confirmó las filas inmutables 7 y 8 con actor raíz, objetivo correcto, estados anterior/nuevo, acción y fecha. No fueron pruebas SQL revertidas.

La cuenta operativa terminó con `puede_editar=true`, `puede_fudo=true`, `puede_ajustes=true`, `puede_lama=false` y `fudo_bloqueos=[]`. Las dos filas de auditoría se conservaron como evidencia.

Fudo sigue en prueba con cron apagado; Lama real continúa apagado; origen POS `ninguno`; stock, lotes, movimientos, ventas y caja no cambiaron. Resultado: `docs/hermes/26-s2-pruebas-seguridad-regresion.md`. Plan actualizado: `docs/hermes/27-plan-endurecimiento-seguridad.md`. B3.2a permanece pendiente y no activa.

## Respuesta de Codex — S1: identidad raíz y gobierno de permisos

Fecha: 2026-10-07
Estado: **COMPLETADA**

El UUID confirmado por Alejo quedó como único `propietario_raiz` en un esquema privado. La raíz recibe capacidades completas por pertenencia al singleton y no existe RPC normal para cambiarla o degradarla. La segunda cuenta conserva editar, Fudo y Ajustes; Lama permanece apagado. `puede_ajustes` significa administración operativa y ya no permite gestionar usuarios.

`app_permisos` quedó vinculada por `auth_uid`. Anon perdió lectura y DML; authenticated solo lee su fila por RLS y no escribe; service role conserva SELECT por la Edge Fudo y perdió DML. Las siete filas históricas sin Auth quedaron inertes. La gestión normal usa RPC `SECURITY DEFINER`, `search_path` vacío, comprobación interna de `auth.uid()` y auditoría inmutable.

La interfaz usa RPC y reserva “Personas y acceso” a la raíz. `stock_transferir` conserva firma y motor, con chequeo por UUID. No se modificó ni invocó Fudo remoto, Lama, caja, recetas o inventario operativo. Conteos de productos, stock, movimientos, lotes, ventas, pagos, caja, Lama y Fudo permanecen iguales.

Las pruebas transaccionales de raíz, administrador operativo, usuario común, anon y service role pasaron; también `npm test`, advisors y `git diff --check`. Rollback y recuperación externa están documentados en `docs/hermes/25-s1-identidad-raiz-gobierno-permisos.md`.

Las fases siguientes de endurecimiento quedan pendientes y requieren activación separada.

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

## Respuesta de Codex — B1: administración segura de sedes y nodos

Fecha: 2026-10-06
Estado: **COMPLETADA**
Proyecto autorizado: Llamita Plus `iuryhsjucblmebdogewa` únicamente.

### Hechos confirmados antes de la migración

- No existía tabla `sedes` ni configuración persistente adecuada. `ajustes` almacena flags globales y no modela sedes.
- `app_permisos` tiene nueve filas globales, sin columna de sede. Las políticas abiertas de `app_permisos` no permiten usarla como permiso seguro para mutaciones de sedes desde la aplicación.
- Conteos de referencia previos al cambio están en `docs/hermes/14-b1-registro-sedes-resultados.md`: 1,437 productos, 431 movimientos, 361 repartos, 2,040 líneas y 42 lotes; `angamos` conserva 351 productos y 2,764.20 de stock agregado.
- `central` contiene rutas de Bodega para recepción, conteo y envíos; su identidad se conserva. La clave antigua `bodega` tiene 408 productos y permanece separada.

### Decisión de implementación

Se prepara `public.sede_registro` como catálogo de solo lectura para los roles de cliente. Conserva `codigo` estable, `nombre_visible`, `tipo` y `estado`. `plaza` y `central` quedan activas; `angamos` queda archivada; `bodega` histórica queda archivada. No se agregó CRUD de sedes a Ajustes porque no existe autorización confiable para decidir qué usuario puede cambiar ese catálogo.

La interfaz oculta Local 2, bloquea `pickSede` y revisa que la sede actual siga activa al navegar. Bodega mantiene sus pantallas; los nuevos envíos solo se ofrecen a Local 1 y un intento hacia Local 2 se rechaza. Esto protege el flujo de usuario frente a selecciones accidentales, pero no constituye aislamiento de datos por API: las políticas operativas heredadas siguen siendo un riesgo que debe resolverse aparte.

No se tocaron cantidades, productos, movimientos, lotes, repartos, recetas ni permisos existentes. No se implementó la clonación de sedes ni ningún elemento de B2 (áreas/stock por área). Los conteos post-migración fueron idénticos: 1,437 productos, 15,438.00 de stock agregado, 431 movimientos, 361 repartos, 2,040 líneas, 42 lotes y nueve permisos globales. `angamos` conserva 351 productos, 2,764.20 de stock, tres movimientos, 168 repartos, 533 líneas, 19 lotes y sus historiales (4,717 manuales y 13,062 automáticos). El catálogo quedó con cuatro filas y grants/política confirmados.

`npm test`, la prueba específica `pruebas/sedes-seguras.mjs`, análisis sintáctico y `git diff --check` pasaron; los casos de navegador se omitieron porque no hay navegador instalado. Los advisors no muestran un hallazgo nuevo para el catálogo; las advertencias operativas existentes se mantienen. Bitácora y detalle: `docs/hermes/14-b1-registro-sedes-resultados.md`.

**B2 queda PENDIENTE y no debe activarse automáticamente.**

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

## Respuesta de Codex - A2: contrato común de inventario

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

---

## Mensaje de Hermes — A3.1 activa

Fecha: 2026-10-06

Alejo aprobó comenzar la implementación por bloques y fijó esta regla: la mesa debe cerrarse y su venta debe alimentar el cierre de caja aunque la receta falte o el motor de inventario falle. El stock es el único subsistema que puede quedar pendiente; nunca debe bloquear el cierre comercial.

La tarea activa es exclusivamente A3.1 de `docs/hermes/08-plan-implementacion-puente-lama-stock.md`: crear cimientos aditivos, seguros e idempotentes, sin conectar aún el cierre ni escribir stock. No activar A3.2 al terminar.

---

## Mensaje de Hermes — A3.2 activa

Fecha: 2026-10-06

A3.1 fue revisada: esquema aditivo, RLS sin políticas abiertas, privilegios directos revocados, defaults apagados, claves únicas y rollback seguro mientras las tablas estén vacías.

A3.2 debe capturar los cierres en modo `prueba` sin escribir stock. La regla decisiva es que una excepción del puente nunca puede revertir ni impedir el cierre comercial. Debe quedar un marcador persistente por cuenta para detectar captura pendiente o fallida, además de los eventos `sin_receta`. Las firmas existentes de `cuenta_cobrar` y `cuenta_cerrar` no se cambian. No activar A3.3 al terminar.

---

## Mensaje de Hermes — A3.3 activa

Fecha: 2026-10-06

A3.2 fue revisada y mantiene caja/cierre aislados del puente. Antes de aplicar inventario debe corregirse la semántica temporal: `ocurrido_at` es `cuentas.cerrada_at`, no la hora de agregado de la línea. `agregado_at` puede viajar en metadata.

A3.3 implementará el motor neutral, aplicaciones de prueba y el camino real únicamente bajo pruebas transaccionales revertidas. Ninguna sede queda persistentemente activada. La atomicidad es por línea completa, se usa el snapshot capturado y se debe demostrar que lotes/trigger no producen doble escritura. No activar A3.4 al terminar.

---

## Respuesta de Codex — A3.1: cimientos aplicados

Fecha: 2026-10-06
Estado: **COMPLETADA**

### Identidad y preflight

- Repositorio confirmado: `leoalejoleo1537/llamita-plus`; rama `work`; remoto `origin` correcto; fast-forward a `origin/master` realizado.
- Supabase confirmado: `llamita-plus`, ref `iuryhsjucblmebdogewa`, estado `ACTIVE_HEALTHY`, PostgreSQL 17.6.
- No había colisión con `lama_stock_*` antes de la migración.
- Firmas comprobadas: `cuenta_cobrar(bigint,text,text,text,numeric,jsonb,jsonb)` y `cuenta_cerrar(bigint,text)`, ambas `SECURITY DEFINER`. Ninguna fue reemplazada ni modificada.
- Se consultó la documentación vigente de Supabase sobre RLS y el changelog público; `gen_random_uuid()` estaba disponible.

### Migración aplicada

`sql/2026-10-a3-1-cimientos-lama-stock.sql`, aplicada como migración `a3_1_cimientos_lama_stock` únicamente en Llamita Plus.

Creó:

- `lama_stock_config`: configuración futura; sin filas, por lo que el modo efectivo permanece `apagado`.
- `lama_stock_eventos`: evento por línea, snapshots de precio/receta, estados, referencias de cuenta, errores y clave única por origen/sede/venta/línea.
- `lama_stock_aplicaciones`: aplicaciones por ingrediente, estado, reversa vinculada y `clave_idempotencia` única.

Las tres tablas tienen RLS activo, no tienen políticas abiertas y no otorgan privilegios directos a `anon` ni `authenticated`. No se crearon funciones ni triggers y no existe ningún camino desde Lama hacia estas tablas todavía.

### Pruebas y límites

- `supabase_list_tables` confirmó columnas, constraints, FKs e identidad de las tablas nuevas.
- Consultas de estructura confirmaron RLS, índices únicos, ausencia de políticas y ausencia de triggers.
- `has_table_privilege` devolvió `false` para lectura/escritura de `anon` y `authenticated`.
- Transacción sintética con `BEGIN … ROLLBACK`: duplicar el mismo evento fue rechazado por `lama_stock_eventos_origen_linea_uq`; duplicar una aplicación fue rechazado por `lama_stock_aplicaciones_clave_idempotencia_key`.
- Conteos de integridad pre/post: cuentas 59, líneas 88, recetas 396, ítems de receta 514, productos 1.437, stock total 15.438. Tablas nuevas: cero filas.
- No se conectaron `cuenta_cobrar` ni `cuenta_cerrar`; no se escribió stock; no se modificaron ventas, recetas, productos, lotes ni Fudo; no se habilitó prueba/real; A3.2 no fue activada.

### Rollback y riesgos

Rollback preparado en `sql/2026-10-a3-1-cimientos-lama-stock.rollback.sql`. Comprueba que las tres tablas estén vacías y, solo entonces, elimina aplicaciones, eventos y configuración. No se ejecutó.

Riesgos pendientes: todavía no existe una frontera RPC para insertar eventos; la futura política de acceso debe mantener las tablas cerradas al navegador; los campos `area_id`/`lote_id` son preparatorios y no implican stock por área; la integración con el cierre y el motor de inventario queda para A3.2/A3.3.

Cambios de código, ventas, recetas, productos y datos operativos: **ninguno**. El único cambio remoto fue el DDL aditivo de A3.1 en Llamita Plus.

---

## Respuesta de Codex — A3.2: captura protegida del cierre Lama

Fecha: 2026-10-06
Estado: **COMPLETADA**

Se implementó exclusivamente A3.2. Las definiciones reales se obtuvieron con `pg_get_functiondef` antes de modificar y se conservaron sus firmas exactas:

- `cuenta_cobrar(bigint,text,text,text,numeric,jsonb,jsonb)` con sus siete parámetros efectivos y defaults instalados;
- `cuenta_cerrar(bigint,text)`.

La única extensión es una llamada protegida después de actualizar la cuenta a `cerrada`. Si la captura falla, el bloque `EXCEPTION` evita que falle el cierre comercial.

### Comportamiento

- Ausencia de configuración o modo `apagado`: comportamiento anterior, cero eventos y cero filas de captura.
- Modo `prueba`: una captura por cuenta y un evento por línea `confirmado` no anulada.
- El evento conserva cantidad, precio aplicado, producto de proveedor, cuenta/línea y snapshot JSON de receta.
- Sin receta: `estado = sin_receta`; la mesa se cierra normalmente.
- Mesa vacía: captura persistente con cero eventos.
- Segundo cierre o reintento: la clave `(source, sede, source_sale_id, source_line_id)` evita duplicados.
- Excepción técnica: captura `estado = error` y diagnóstico; cuenta, pagos, propina, descuentos y caja permanecen válidos.
- No se crean aplicaciones y no se escribe `productos.stock_actual` ni lotes.

### Seguridad y pruebas

La función interna `lama_stock_capturar_cuenta(bigint)` es `SECURITY DEFINER`, usa `search_path = public, pg_temp` y no es ejecutable por `public`, `anon`, `authenticated` ni `service_role`. Solo las funciones de cierre propietarias pueden invocarla.

Se aplicaron `a3_2_captura_cierre_lama` y `a3_2_restrict_captura_execute`. Las pruebas transaccionales cubrieron apagado, prueba, receta, ausencia de receta, anulación, mesa vacía, doble cierre, reintento, cobro con parcial/propina/descuento y error forzado con trigger temporal. Todas terminaron en `ROLLBACK`.

Conteos pre/post: cuentas 59, líneas 88, recetas 396, ítems de receta 514, productos 1.437 y stock total 15.438. Las tablas de captura/eventos/aplicaciones quedaron vacías tras las pruebas. No se modificó ninguna cantidad de stock.

Rollback: `sql/2026-10-a3-2-captura-cierre-lama.rollback.sql`; restaura las dos definiciones originales y aborta si hay filas A3.2.

No se implementó A3.3, no se habilitó modo real, no se modificó Fudo, interfaz, recetas, productos ni Café del Desierto / Llamita Stock.


---

## Respuesta de Codex — A3.3: motor neutral y aplicación al stock actual

Fecha: 2026-10-06
Estado: **COMPLETADA**

Se implementó únicamente A3.3 en `llamita-plus` (`iuryhsjucblmebdogewa`). Las firmas de cierre y de los caminos de stock se obtuvieron con `pg_get_functiondef`; no se copiaron firmas históricas.

### Diseño aplicado

- `lama_stock_aplicar_evento(uuid)` recibe solo `event_id` y lee exclusivamente `snapshot_receta`.
- Cada ingrediente elegible genera una fila en `lama_stock_aplicaciones` con producto, delta negativo, unidad, lote FIFO elegido cuando corresponde, estado, clave idempotente y error.
- `prueba` crea aplicaciones esperadas sin escribir productos, lotes ni movimientos reales.
- `real` delega en `descontar_lotes` si hay lotes y en `descontar_con_reposicion` si no hay lotes. El trigger instalado `trg_sync_stock_lotes` es quien recalcula `productos.stock_actual` después de cambios en lotes; no existe un segundo descuento manual.
- La mesa Lama se traduce a `fulfillment = serve`: se incluyen `siempre` y `servir`; `llevar` solo entra para `takeaway`.
- La captura usa `cuentas.cerrada_at` como `ocurrido_at` y conserva `cuenta_items.agregado_at` en metadata.

### Atomicidad e idempotencia

La aplicación real de una línea ocurre dentro de un bloque atómico. Un error en un ingrediente revierte los descuentos previos, marca el evento `error` y deja marcadores de error por ingrediente. Repetir un evento aplicado devuelve las aplicaciones existentes. Esto cubre el reintento posterior a un timeout después del commit.

### Verificaciones

Se probaron en transacciones revertidas: receta simple y múltiple, modo prueba, modo real con cierre de cuenta, producto sin lotes, FIFO, reintento, error intermedio, insuficiencia según el comportamiento instalado, producto sin receta, snapshot frente a cambio posterior de receta y reglas `siempre/servir/llevar`.

Advisors de Supabase fueron revisados. No aparece el helper A3.3 como función ejecutable por roles públicos. Los avisos restantes corresponden a funciones/views heredadas, índices/foreign keys existentes y el diseño intencional de tablas internas con RLS sin políticas y sin grants directos.

Estado remoto final: `lama_stock_config` vacía; eventos, aplicaciones y capturas vacíos; productos 1.437; suma de stock 15.438. Las pruebas reales fueron revertidas y no quedó ningún stock persistente modificado.

Migraciones: `a3_3_motor_neutral_lama_stock` y `a3_3_fulfillment_rules`. Rollback: `sql/2026-10-a3-3-motor-neutral-lama-stock.rollback.sql`. A3.4 queda pendiente y no se activó.


---

## Respuesta de Codex — A3.4a: observabilidad y reproceso seguro

Fecha: 2026-10-06
Estado: **COMPLETADA**

Se implementó exclusivamente A3.4a en Llamita Plus. No se habilitó modo real ni se modificó el cierre comercial.

- `lama_stock_eventos_observabilidad` permite consultar eventos `pendiente`, `aplicado`, `error` y `sin_receta`, junto con errores y conteos de aplicaciones. Es una vista interna `security_invoker`, sin permisos de lectura para el navegador.
- `lama_stock_reintentar_evento(uuid)` solo reprocesa eventos `error` con modo congelado `prueba`. `sin_receta` requiere corregir catálogo y `real` se rechaza explícitamente.
- El reproceso delega en `lama_stock_aplicar_evento`; repetirlo conserva la aplicación existente y no duplica.
- La migración no toca `cuenta_cobrar`, `cuenta_cerrar`, stock, lotes, movimientos, Fudo ni áreas.

Pruebas transaccionales revertidas: consulta de los cuatro estados, reproceso, doble reproceso, rechazo de sin receta, rechazo de real, permisos y stock sin cambios. Estado remoto final: `lama_stock_config` vacía, eventos y aplicaciones vacíos, productos 1.437 y stock total 15.438.

Migración: `a3_4a_observabilidad_reproceso`. Rollback: `sql/2026-10-a3-4a-observabilidad-reproceso.rollback.sql`. A3.4b continúa pendiente.

## Respuesta de Codex — A3.4b: prueba sintética E2E Lama–Stock

Fecha: 2026-10-06
Estado: **COMPLETADA**

Se ejecutó únicamente A3.4b en Llamita Plus (`iuryhsjucblmebdogewa`). No se utilizaron ventas reales ni se dejaron datos persistentes: toda la prueba corrió dentro de `BEGIN ... ROLLBACK`.

### Flujo y resultados

- Se crearon temporalmente productos, una receta de dos ingredientes, una mesa, una cuenta y sus líneas.
- Se ejecutó `cuenta_agregar`, `cuenta_confirmar` y `cuenta_cerrar`; el cierre creó la captura y el evento con snapshot de receta.
- El procesamiento en modo `prueba` creó una aplicación por ingrediente con delta total `-6` (cantidad de línea `2` por receta `2 + 1`).
- Se cambió la receta viva después de capturar y se confirmó que el snapshot permaneció inmutable.
- Un trigger temporal produjo un error en el segundo ingrediente. La cuenta permaneció cerrada y su total comercial fue `250`; el evento quedó `error`, sin descuento parcial. El reintento lo llevó a `prueba` y repetirlo no duplicó aplicaciones.
- Esto confirma expresamente que un fallo del motor de stock no bloquea el cierre de la mesa ni el registro de sus datos comerciales.

### Integridad y límites

Los conteos pre/post fueron idénticos: cuentas `59`, líneas `88`, recetas `396`, ítems de receta `514`, productos `1437`, suma de stock `15438.00` y comandas persistentes `50`. `lama_stock_config`, eventos, aplicaciones y capturas quedaron en `0` antes y después. No se activó modo real, no se modificó stock persistente, no se implementaron áreas, no se cambió Fudo y no se accedió a Café del Desierto/Llamita Stock.

A3.4c — reversas y activación real — permanece **PENDIENTE** y no se activa automáticamente.

## Respuesta de Codex — A3.4c: prueba controlada Lama en modo prueba

Fecha: 2026-10-06
Estado: **COMPLETADA**

Se activó únicamente la verificación A3.4c en una sede sintética y temporal con `modo = 'prueba'`. El flujo reprodujo las acciones de la interfaz Lama con `cuenta_agregar`, `cuenta_confirmar` y `cuenta_cerrar`; luego se comprobó la captura y aplicación del evento. Todo ocurrió dentro de `BEGIN ... ROLLBACK`.

IDs observados durante la prueba:

- Cuenta: `990301`
- Evento: `646d4cb3-5124-4410-ab40-4dbd89a68b6c`
- Aplicaciones: `2a419ca9-56bf-49b8-8bea-71645f3f10dd`, `a9bea2ef-19c9-4f25-82c8-07f4b49fa33d`

El evento quedó `prueba` y se generó una aplicación por ingrediente. Dos reintentos de `lama_stock_aplicar_evento` mantuvieron exactamente dos aplicaciones. El stock sintético no cambió (`10` por producto), la cuenta quedó cerrada y `lama_stock_config` volvió a cero filas después del rollback.

Conteos pre/post: cuentas 59, líneas 88, productos 1437, recetas 396, ítems de receta 514, comandas 50 y stock total 15438; eventos, aplicaciones, capturas y configuración quedaron en cero. No se usaron ventas reales, no se habilitó modo real, no se tocó Fudo, no se implementaron áreas y no se accedió a Café del Desierto/Llamita Stock.

El procedimiento manual reproducible quedó en `docs/hermes/12-prueba-manual-a3-4c.md`. A3.4d — reversas y activación real — permanece pendiente.

## Respuesta de Codex — B2.2: auditoría de fuente única de stock

Fecha: 2026-10-07
Estado: **REQUIERE DECISIÓN**. B2.3 (interfaz y formularios) queda pendiente.

La auditoría se limitó a Llamita Plus (`iuryhsjucblmebdogewa`) y al repositorio `leoalejoleo1537/llamita-plus`. `productos.stock_actual` sigue siendo fuente vigente. Para `plaza` se comprobaron 329 productos y 4.566,20 unidades; en total, 1.437 productos y 15.438,00 unidades. Los conteos global/plaza fueron 431/25 movimientos, 42/9 lotes, 361/148 repartos con destino plaza, y 396/195 recetas.

No es seguro poblar una tabla de saldos por área aún: la interfaz escribe directamente `productos.stock_actual` y reemplaza lotes; varios RPC instalados para mermas, entradas/reversas, repartos/reversas, Fudo, Lama, restauraciones y fusiones también actualizan el mismo saldo o delegan en el trigger de lotes. Lectores y mínimos/máximos siguen centrados en el producto. La relación B2.1 no tiene cantidades, permite una fila por producto/sede y no representa una distribución. Los lotes carecen de área, aunque sus sumas actuales coinciden con el agregado.

La recomendación es una transición coordinada: autoridad única por ubicación para `plaza` y `productos.stock_actual` como proyección de lectura no editable durante compatibilidad. Hace falta decidir el corte de todos los escritores y permisos/API, el destino de lotes y si la simulación de clasificación se acepta como asignación física inicial. El stock no contado debe conservarse una sola vez en Sin asignar.

No se ejecutaron migraciones, RPC de escritura, ni SQL de mutación; no se modificó código ni dato. Conteos al cierre iguales a los del inicio. El informe con matriz de escritores, evidencia SQL, riesgos y decisiones es `docs/hermes/16-b2-2-auditoria-fuente-unica-stock.md`. No se preparó rollback SQL porque no hubo mutación. B2.3 permanece pendiente y no activa.

## Decisión de Alejo — libro de existencias por ubicación

Fecha: 2026-10-07
Estado: **APROBADA como decisión arquitectónica**. B2.2 se cierra como `REQUIERE DECISIÓN RESUELTA`, sin implementación; B2.3 sigue `PENDIENTE`, no activa.

- La fuente futura única será un libro de existencias por producto, sede, ubicación y lote cuando corresponda. `productos.stock_actual` será una proyección de compatibilidad no editable; nunca un segundo saldo.
- Ubicaciones iniciales: Bodega central; Sin asignar de Local 1; Cocina fría, Cocina caliente, Barra y Cafetería de Local 1.
- Recepción, conteo normal y origen de repartos permanecen en Bodega central. Todo producto físico nuevo entra primero allí. El reparto requiere destino de área y se registra como transferencia atómica, preservando producto, cantidad, usuario, fecha y lote.
- Una habilitación de producto en un área no crea saldo. Las cantidades solo se distribuyen mediante movimiento explícito. Mermas se registran en un único módulo global con área obligatoria; búsqueda, reportes y críticos se calculan por área.
- Migración futura: `central` completo a Bodega central; `plaza` completo a Sin asignar; lotes actuales de `plaza` a Sin asignar; ninguna migración de `angamos` ni de la clave histórica `bodega`; ninguna clasificación histórica automática. Las sugerencias por nombre no escriben asignaciones. Distribuciones posteriores desde Sin asignar se registran explícitamente con procedencia inicial `simulacion`.
- Recetas y Lama–Stock real siguen sin activar hasta que el modelo por ubicación funcione.

La decisión y el plan no ejecutan la migración. Esta actualización fue solo documental: sin SQL, tablas, código ni cambios de datos. Alcance, precondiciones y criterios previstos para B2.3 están en `docs/hermes/17-decision-libro-existencias-ubicacion.md` y `docs/hermes/01-plan-areas-operativas.md`.


---

## Respuesta de Codex — Bloque 0: auditoría de áreas, sedes y Bodega

Fecha: 2026-10-07
Estado: **COMPLETADO; solo lectura**. B1 queda **PENDIENTE**, no activa.

- Repositorio confirmado: `leoalejoleo1537/llamita-plus`, remoto `origin` correcto, rama local `work`. Supabase confirmado por metadatos: `llamita-plus` (`iuryhsjucblmebdogewa`).
- `plaza` corresponde a Local 1, `angamos` a Local 2, `central` a Bodega activa; `bodega` es una clave histórica distinta. Totales leídos: 1,437 filas de producto y `stock_actual` 15,438.00. El detalle de 42 lotes cuadra con su producto y no se suma de nuevo.
- No existe modelo de inventario por área/sede normalizada. `lama_areas` son áreas de mesas; movimientos/mermas, lotes y repartos carecen de área explícita.
- `productos.stock_actual` es autoridad actual, pero numerosas rutas lo escriben; los lotes se sincronizan por trigger. La recomendación de diseño es una autoridad única por producto/ubicación, con movimiento atómico/idempotente y saldo agregado de compatibilidad solo de lectura durante transición. No se fijan nombres de tablas/columnas.
- Bodega `central` debe seguir como nodo logístico. Reparto actual puede registrar recepción y baja de origen en pasos separados; la futura transferencia a área requiere destino por línea, origen, unidad/factor, lotes y atomicidad.
- Local 2 se archivaría después preservando IDs e historia. Mermas permanecen globales con área opcional para operaciones nuevas. Mínimos/críticos deben calcularse por ubicación. Clonar sede copia configuración aprobada y parte con stock cero.
- Riesgo de seguridad: Local 1 no es sandbox. Las políticas RLS observadas son permisivas y los permisos de app son globales, sin alcance por sede/área.
- Decisiones pendientes para B1: autoridad/corte de todos los escritores; límites RLS/API; stock sin asignar y conciliación física; reparto transaccional con lotes; estrategia de proyección y su retiro.

Informe completo y consultas de solo lectura: `docs/hermes/13-auditoria-areas-sedes-bodega.md`. No hubo invocación de RPC, SQL de escritura, migración ni mutación de datos. No se consultó Café del Desierto / Llamita Stock. No se activó B1 ni bloques posteriores.

## Respuesta de Codex — B2.1: cimientos del modelo de áreas

Fecha: 2026-10-07
Estado: **COMPLETADA**. B2.2 queda **PENDIENTE**, no activada.

- Repositorio confirmado: `leoalejoleo1537/llamita-plus`, remoto oficial; rama local `work`. Supabase confirmado: Llamita Plus `iuryhsjucblmebdogewa`.
- Se aplicaron `b2_1_cimientos_areas_operativas`, `b2_1_indices_fk_producto_area` y `b2_1_comentario_relacion_area`: `public.areas_operativas` y relación preparatoria vacía `public.producto_area_asignacion`, con índices para sus FK. Áreas físicas exclusivamente en `plaza`: Cocina fría, Cocina caliente, Barra y Cafetería. `Sin asignar` es un estado, no una quinta área.
- No existe fuente paralela de stock: la relación no tiene cantidad y se mantiene vacía. Un índice único limita a una asignación por producto/sede; para distribución física simultánea, B2.2 debe diseñar cantidades por área antes de abrir esa posibilidad.
- RLS está habilitado en ambas tablas, sin políticas ni permisos directos para `PUBLIC`, `anon`, `authenticated` o `service_role`. Helpers de trigger sin EXECUTE para roles de aplicación.
- Conciliación reproducible `sql/2026-10-b2-1-simulacion-clasificacion.sql`: 329 productos, uno por destino como máximo; Barra 18 y 108,00; Cafetería 42 y 536,50; Cocina caliente 19 y 204,00; Cocina fría 17 y 17,50; Sin asignar 233 y 3.700,20. Total 4.566,20 = stock actual de `plaza`. Es simulación heurística, no dato histórico ni asignación persistida.
- Conteos pre/post: 1.437 productos y 15.438,00 global; plaza 329 productos y 4.566,20. Sin cambios en movimientos 431, repartos 361/2.040 líneas, lotes 42, recetas 396/514 ítems, permisos 9 o `lama_areas` 5. Las nuevas tablas no almacenan saldos y la relación tiene 0 filas.
- Pruebas estructurales y de restricciones dentro de `BEGIN ... ROLLBACK`: áreas exactas/sede, sede cruzada, unicidad, coherencia estado/área, código reservado, clave estable, RLS/grants/policies y ausencia de columnas de saldo. Conteos post iguales. Advisor final sin FK desindexadas nuevas; RLS sin políticas es intencional y los índices de relación aún no se han usado porque está vacía. Rollback preparado y no ejecutado.
- Evidencia detallada: `docs/hermes/15-b2-1-cimientos-areas.md`. No se tocó `central`, `angamos`, `bodega`, Lama, Fudo ni Café del Desierto/Llamita Stock. No se creó interfaz.
- Riesgo abierto: los nombres/categorías actuales dejan productos en revisión; la regla de simulación requiere validación operativa. Fuente de stock, corte de escritores, cantidades por área y seguridad por sede quedan para B2.2.

## Respuesta de Codex — B2.3: corte del libro por ubicación detenido

Fecha: 2026-10-07
Estado: **REQUIERE DECISIÓN**. B2.4 permanece **PENDIENTE**, no activa.

- Repositorio: `leoalejoleo1537/llamita-plus`, rama `work`, al inicio alineada con `origin/master`. Proyecto Supabase: `llamita-plus` (`iuryhsjucblmebdogewa`), activo.
- Se verificaron escritores de stock de la interfaz, grants/políticas DML, trigger de sincronización de lotes, RPC de inventario y delegaciones de Fudo/Lama. Estos caminos impiden afirmar que `stock_actual` pueda quedar como proyección no editable con seguridad sin una adaptación/bloqueo coordinado y pruebas por sede.
- No se creó ledger ni se migraron saldos. `productos.stock_actual` permanece como fuente actual. No cambió cantidad o ubicación de lotes, movimientos, repartos, recetas, permisos ni datos comerciales.
- Conteos SELECT de inicio/cierre: productos 1.437, stock 15.438,00; central 349 / 4.750,50; plaza 329 / 4.566,20. Lotes central 2 / 96,00 (un producto, cero diferencias); plaza 9 / 36,00 (seis productos, cero diferencias). Movimientos 431, repartos 361, recetas 396 / 514 líneas, permisos 9. Los lotes se tratan como detalle del saldo y no se suman de nuevo.
- Informe completo: `docs/hermes/18-b2-3-bloqueo-corte-libro-ubicaciones.md`. El plan y la cola registran el bloqueo; el documento 17 ya distingue B2.3 de la interfaz UX posterior.
- Solo se hicieron consultas SELECT y lecturas de catálogo/código. No se aplicó SQL, migración ni cambio de código/datos. No se accedió a Café del Desierto / Llamita Stock. La interfaz de áreas y B2.4 quedan pendientes; no activar automáticamente.

## Respuesta de Codex — B2.3: corte coordinado completado

Fecha: 2026-10-07
Estado: **COMPLETADA para `central` y `plaza`**. B2.4 permanece **PENDIENTE**, no activada.

El bloqueo del primer intento quedó resuelto por la autorización explícita de Alejo para implementar el corte temporal. En Supabase Llamita Plus `iuryhsjucblmebdogewa` se aplicaron `20261007152558 b2_3_libro_existencias_corte` y `20261007152805 b2_3_indices_permisos_libro`.

Se creó `stock_internal` con ubicaciones, movimientos inmutables, aperturas, transferencias idempotentes, permiso transaccional de proyección y vista de existencias. Se abrieron 150 productos de `central` en Bodega central y 258 de `plaza` en Sin asignar: 408 movimientos por 9.316,70. No se hicieron asignaciones históricas a áreas físicas; las cuatro áreas tienen cero saldo. `angamos` y `bodega` histórica quedan intactas.

Conteos pre/post sin cambios: productos 1.437; agregado 15.438,00; central 349/4.750,50; plaza 329/4.566,20; angamos 351/2.764,20; bodega histórica 408/3.357,10; lotes 42/304,00; movimientos legacy 431; repartos/líneas 361/2.040; recetas/líneas 396/514; permisos 9; `lama_stock_config` 0. Conciliación por producto/sede sin diferencias. Los lotes existentes quedaron congelados para las sedes cortadas y no se suman como saldo adicional.

`productos.stock_actual` conserva su valor y queda protegido como proyección. Se bloquearon con mensajes explícitos los escritores legacy que aún no usan el libro: stock manual, alta con saldo, lotes, entradas, ajustes, mermas, movimientos, repartos/deshacer, restauraciones y fusiones. Los triggers también bloquean Fudo real/aplicado y Lama real para sedes migradas. Fudo remoto no fue modificado; fuentes Edge actualizadas no se desplegaron. Lama real sigue apagado y su configuración vacía.

La prueba transaccional verificó permisos/RLS, conciliación, transferencia Bodega -12/Cafetería +12 con producto lógico, lote y referencia compartidos, idempotencia y rollback completo. `npm test`, análisis de sintaxis Edge y `git diff --check` pasaron; browser tests se omitieron porque no hay navegador instalado. El rollback técnico aborta si existen movimientos posteriores; una vez haya actividad solo se permite compensación auditada.

Informe: `docs/hermes/19-b2-3-corte-libro-ubicaciones.md`. No se accedió a Café del Desierto / Llamita Stock. No se alteró stock agregado previo ni filas comerciales. No activar B2.4 automáticamente.

## Respuesta de Codex — B2.3.1: blindaje de origen POS por sede

Fecha: 2026-10-07
Estado: **COMPLETADA**. B2.4 permanece **PENDIENTE**, no activa.

La configuración previa de Fudo (`fudo_sync`), Lama (`lama_stock_config`) y flags (`ajustes`) no representaba un origen POS único. Se creó `stock_internal.origen_pos`, privada y con una fila por sede. El origen inicial quedó `ninguno` en `plaza`, `central`, `angamos` y `bodega`; para `central` y sedes históricas el constraint solo admite `ninguno`. `prueba` no habilita escrituras. No hay mutación directa desde navegador ni service role.

El helper server-side `public.stock_pos_origen_permitido` solo concede `EXECUTE` a `service_role`. Se protegieron el RPC instalado `fudo_procesar_item`, movimientos Fudo directos, configuración/aplicaciones reales de Lama y el motor `lama_stock_aplicar_evento`. Fudo solo puede empezar ventas/empujes/reversiones si el helper confirma `fudo`; Lama real requiere `lama` además del modo real de Lama. El bloqueo de inventario legacy de B2.3 sigue vigente.

Se desplegaron seis Edge Functions como `ACTIVE`, v1, JWT requerido y release marker `2026-10-07-b2.3.1`: `fudo-ciclo`, `fudo-sync-ventas`, `fudo-empujar-stock`, `fudo-deshacer-stock`, `fudo-sumar-stock`, `fudo-probar-escritura`. Consulté la fuente de cada despliegue y confirmé helper y marker. Una petición sin JWT a `fudo-sync-ventas` recibió 401; no se llamó a Fudo.

Pruebas `BEGIN ... ROLLBACK`: `plaza` en ninguno/prueba deniega Fudo y Lama; unicidad impide dos proveedores; central, angamos y bodega no aceptan origen activo; RPC/DML Fudo bloqueados; Lama real falla sin origen Lama; ACL/RLS y helper bajo rol `service_role`. Conteos persistentes: stock 15.438,00; productos 1.437; movimientos 431; registros Fudo 15.357; Lama config vacía. `fudo_sync` plaza continúa prueba/cron apagado. Sin cambios en Fudo remoto ni datos comerciales.

No existe aún selector de Ajustes. Una futura ruta administrativa deberá verificar `app_permisos.puede_ajustes` desde backend y dejar auditoría del cambio. No se activa Fudo/Lama real, Toteat ni B2.4. Informe: `docs/hermes/20-b2-3-1-blindaje-origen-pos.md`. No se accedió a Café del Desierto / Llamita Stock.

## Respuesta de Codex — B2.4: motor seguro de transferencias entre ubicaciones

Fecha: 2026-10-07
Estado: **COMPLETADA**. B3 queda **PENDIENTE**, no activada.

Se aplicaron en Supabase Llamita Plus (`iuryhsjucblmebdogewa`) las versiones `20261007165310`, `20261007165656` y `20261007165826`. El RPC `public.stock_transferir` usa `SECURITY INVOKER`, solo se concede a `authenticated` y valida identidad JWT, email y `app_permisos.puede_editar`. El helper interno repite la validación y el motor queda fuera de acceso directo. Las tablas internas no reciben DML de `anon`, `authenticated` ni `service_role`.

Las transferencias permitidas son Bodega central→área de Local 1 con enlace explícito factor 1, Sin asignar→área y área→área. Cada referencia idempotente produce dos movimientos opuestos dentro de una transacción; el trigger diferido rechaza pares incompletos o no balanceados. El origen y destino se validan como ubicaciones activas. La operación no hace UPDATE directo a `productos.stock_actual`; el trigger de proyección refleja los movimientos. En productos maestros distintos cambia el agregado de cada producto, pero la suma global no cambia.

Los lotes mantienen su identidad mediante el ID canónico y una relación de continuidad que registra el producto enlazado y el vencimiento. No se insertan lotes ficticios. La transferencia fue probada con y sin lote, en todas las rutas solicitadas; también con saldo insuficiente, producto sin enlace, repetición, error forzado entre salida/entrada, usuario sin permiso y llamada como `authenticated`. Todo se revirtió con `ROLLBACK`.

Post rollback: 1.437 productos, stock global 15.438,00, 42 lotes, libro neto 9.316,70; cero transferencias, continuidad, clasificación o movimientos de transferencia persistentes; `fudo_movimientos` 15.357, movimientos legacy 431 y Lama real 0. Fudo remoto no fue consultado ni modificado.

El rollback técnico aborta si encuentra actividad B2.4; después de transferencias persistidas corresponde reversa compensatoria auditada. El campo `reversa_de` está preparado, sin operación de reversa expuesta. El informe y scripts son `docs/hermes/21-b2-4-motor-transferencias-ubicaciones.md`, `sql/2026-10-b2-4-pruebas-transferencias.sql` y `sql/2026-10-b2-4-transferencias-ubicaciones.rollback.sql`. No se construyó UI, no se activó Lama/Fudo y no se activó B3. No se accedió a Café del Desierto / Llamita Stock.

## Respuesta de Codex — B3.1: lectura y navegación de inventario por áreas

Fecha: 2026-10-07
Estado: **COMPLETADA**. B3.2 queda **PENDIENTE**, no activada.

La portada de Inventario de `plaza` muestra Cocina fría, Cocina caliente, Barra, Cafetería, Sin asignar y Todas las áreas. Las tarjetas no simulan críticos sin mínimos. Sin asignar describe el saldo inicial pendiente de distribución. Las páginas de área filtran consulta y tipo y muestran solo productos con saldo en esa ubicación; la vista global conserva una cantidad separada por área para cada producto. Bodega (`central`) mantiene la pantalla existente.

El cliente consulta solo `public.stock_leer_areas()`. La función invoker, disponible a `authenticated`, delega en un helper privado que exige sesión y calcula los saldos desde `stock_internal.existencias`, sin leer `productos.stock_actual`. La función no devuelve Bodega ni otras sedes. No hay escritura ni llamada a `stock_transferir` en esta experiencia.

Conciliación autenticada: las cuatro áreas físicas tienen 0 productos con saldo y 0,00 unidades; Sin asignar tiene 255 productos y 4.566,20 unidades, igual al libro de `plaza`. Conteos SELECT al cierre: 1.437 productos, libro plaza 4.566,20, central 4.750,50, 408 movimientos del libro, cero transferencias, 42 lotes y 514 líneas de receta. La interfaz no alteró productos ni datos.

Supabase confirmó permisos: anon y service_role no ejecutan las funciones; authenticated sí; roles de aplicación sin INSERT en movimientos ni UPDATE de ubicaciones. La llamada sin sesión fue rechazada. Advisors muestran hallazgos globales previos en otros objetos del proyecto, documentados en el informe para su gestión separada.

Las pruebas estáticas, `npm test`, consulta de permisos y conciliación pasaron. El entorno carece de Chromium; la comprobación DOM del navegador quedó omitida y el informe 22 contiene una secuencia manual para desktop/móvil y consola. Migraciones aplicadas solo a Llamita Plus: `20261007174518` y `20261007174626`. Informe: `docs/hermes/22-b3-1-lectura-areas.md`. Implementación publicada en `master` como `2a9c8c2`. No se accedió a Café del Desierto / Llamita Stock.

## Respuesta de Codex — B3.2a: gestión de áreas y asignación preferida

Fecha: 2026-10-07
Estado: **REQUIERE DECISIÓN**. B3.2b queda **PENDIENTE**, no activa.

Se verificó de nuevo que el proyecto Supabase es `llamita-plus` (`iuryhsjucblmebdogewa`, `ACTIVE_HEALTHY`, PostgreSQL 17.6.1.166). La inspección de solo lectura de `pg_policies` encontró en `public.app_permisos`:

- `INSERT` para `authenticated` con `WITH CHECK true`.
- `UPDATE` para `authenticated` con `USING true` y `WITH CHECK true`.
- Otra política `UPDATE` para `anon,authenticated` con `USING true` y `WITH CHECK true`.
- Grants directos para `anon` y `authenticated`, incluidos `INSERT`, `UPDATE`, `DELETE` y `TRUNCATE`.

La tabla contiene nueve filas y seis tienen `puede_ajustes=true`, pero ese conteo no identifica autorizaciones confiables: las políticas permiten que clientes escriban esos mismos permisos. Una RPC que valide solamente `app_permisos.puede_ajustes` sería eludible. Por ello no se implementó ningún CRUD de áreas, asignación de productos ni alta desde el navegador.

Se requiere una decisión de arquitectura: autorizar el endurecimiento de la administración de `app_permisos` de forma que solo un permiso existente y confiable pueda gestionarla, incluyendo el bootstrap y las operaciones backend necesarias, o definir otra fuente de autorización verificable. La propuesta, evidencia, alcance no ejecutado y condiciones para reanudar están en `docs/hermes/23-b3-2a-bloqueo-autorizacion.md`.

No hubo cambios en código, SQL, migraciones, permisos, datos operativos ni stock; no se tocó `central`, `angamos`, `bodega`, POS, recetas ni datos comerciales. No se accedió a Café del Desierto / Llamita Stock. B3.2b permanece sin activar.

## Respuesta de Codex — S0: auditoría integral de seguridad y permisos

Fecha: 2026-10-07
Estado: **REQUIERE DECISIÓN**. S1 no queda activa.

La auditoría de solo lectura confirmó que el problema no está limitado a `app_permisos`. Treinta y seis tablas operativas de `public` tienen políticas `ALL` abiertas para anon/authenticated. Cuarenta funciones `SECURITY DEFINER` son ejecutables por anon; 36 contienen rutas de escritura y ninguna de esas 40 valida sesión. La superficie incluye permisos, Ajustes, Lama, caja, arqueos, mesas, cuentas, pagos, productos, recetas, repartos y escritores legacy de stock.

`app_permisos` no tiene `auth.uid()`, FK, sede ni propietario. Hay dos usuarios Auth confirmados; ambos coinciden por correo con filas administrativas. Siete filas adicionales no tienen usuario Auth actual. No hay rol de propietario en `app_metadata` ni bandera equivalente. Los identificadores y correos no se publicaron.

El libro `stock_internal`, áreas/asignaciones y puente Lama–Stock sí permanecen cerrados. Los triggers del corte protegen el stock de `central/plaza`. Las seis Edge Functions Fudo desplegadas tienen JWT y guard de origen POS; el riesgo remoto está contenido porque todas las sedes siguen en `ninguno`, Fudo continúa en prueba/cron apagado y Lama real está apagado. Varias Edge no tienen una capacidad de usuario confiable dentro de su cuerpo y deberán revisarse antes de activar Fudo.

S1 debe comenzar por designar privadamente el `auth.uid()` de Alejo como único `propietario_raiz`, definir recuperación de emergencia, cerrar DML/lectura global de permisos y separar gobierno de operación. Luego debe migrar por fases Lama/caja, RPC privilegiados, productos/logística, Fudo y reportes. No se debe migrar automáticamente por correo.

Informe completo, matriz y dependencias: `docs/hermes/24-auditoria-integral-seguridad-permisos.md`. No hubo migraciones, DML, RPC operativos, Edge invocadas, cambios de RLS/grants, usuarios, datos, configuración o código funcional. No se accedió a Café del Desierto / Llamita Stock.
## Respuesta de Codex — B3.2a.2: interfaz dinámica de áreas y preferencias

Fecha: 2026-10-08
Estado: **COMPLETADA**. B3.2a.3 y B3.2b quedan **PENDIENTES**, no activas.

Inventario de Local 1 dejó de depender de `AREA_ORDEN_UI`: obtiene las áreas activas de `areas_operativas_listar` y las cantidades exclusivamente de `stock_leer_areas`, cuyo helper ahora admite cualquier área activa vinculada. Sin asignar permanece como ubicación lógica, las archivadas desaparecen de navegación y Bodega conserva su pantalla.

Ajustes incorporó “Áreas de inventario” para crear, renombrar, ordenar y archivar usando solo RPC protegidas. Las altas normales de `plaza` y la alta auxiliar del taller de recetas usan `producto_plaza_crear`; la edición de ficha lee la preferencia con la nueva RPC `producto_area_preferencia_leer` y la cambia con `producto_area_preferencia_guardar`. La UI separa explícitamente preferencia, ubicación física y saldo; ninguna acción mueve existencias.

Las pruebas sintéticas se ejecutaron con `BEGIN ... ROLLBACK`. La primera detectó un grant de delegación faltante entre la RPC invoker y el helper privado; no persistió datos y se corrigió con una migración mínima. La repetición completa pasó y no dejó Heladería, productos ni asignaciones sintéticas. Conteos pre/post: 1.437 productos, 15.438,00 de proyección global, 9.316,70 en ledger migrado, 42 lotes, 431/408 movimientos legacy/ledger, 0 transferencias, 396 recetas, 15.357 movimientos Fudo y 0 eventos Lama.

No se modificaron Edge Functions, Fudo remoto, Lama, caja, Bodega, recetas, lotes, transferencias ni `stock_transferir`. Informe: `docs/hermes/29-b3-2a-2-interfaz-dinamica-areas.md`. No se accedió a Café del Desierto / Llamita Stock.
