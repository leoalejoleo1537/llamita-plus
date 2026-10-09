# Plan de implementación: inventario por áreas operativas en Llamita Plus

**Estado:** B1, B2.1, B2.3, B2.3.1, B2.4, B3.1, S1, S2 y B3.2a.1–B3.2a.3 completados. C0 auditó el circuito de transferencias y detectó una incompatibilidad entre áreas dinámicas y la lista fija del motor; C1–C3 están **REQUIERE DECISIÓN**. El frente móvil M2–M4 está pausado. Evidencia: documentos 23–29, 32 y 33.

### C0 — Auditoría del circuito interno

**Estado: COMPLETADA CON BLOQUEO (2026-10-09).** La lectura física y la asignación preferida están correctamente separadas. `productos.rubro`/`secciones` y `productos.tipo` son clasificaciones legadas, no ubicaciones. Sin embargo, aunque el catálogo y las ubicaciones admiten áreas dinámicas, el núcleo B2.4 solo acepta cuatro códigos de área. Antes de implementar secciones internas o una interfaz de transferencias se debe decidir si B2.4 se amplía para validar por `area_id` activa en vez de una lista fija. Ver informe 33.

**Repositorio objetivo:** `leoalejoleo1537/llamita-plus`, rama `master`.

**Límite permanente:** Café del Desierto / Llamita Stock queda completamente fuera de alcance. Toda simulación, migración, dato de prueba y cambio de aplicación descrito aquí corresponde exclusivamente a Llamita Plus.

## 1. Objetivo

Convertir el inventario de Llamita Plus en una vista por áreas operativas configurables dentro de cada sede. Cada área debe funcionar como un espacio de inventario propio: sus productos asignados, existencias, mínimos, movimientos y mermas deben poder consultarse dentro de esa área. La persona también debe poder consultar todas las áreas desde una vista general.

La configuración inicial de `plaza` contiene cuatro áreas: **Cocina fría, Cocina caliente, Barra y Cafetería**. Las reglas por nombre o categoría son sugerencias para futuras distribuciones explícitas; no clasifican ni mueven automáticamente el stock histórico.

La arquitectura debe permitir que un mismo producto maestro exista en varias áreas con cantidades distintas. Por ejemplo, la búsqueda general de “leche” puede mostrar 5 unidades en Cocina, 12 en Cafetería, 1 en Barra y 3 en Cocina fría; dentro de Cafetería, el buscador debe mostrar solo el inventario de Cafetería.

## 2. Decisiones acordadas

1. Las áreas se configuran por sede. No se deducen de `tipo`, `rubro`, nombre de producto ni turno.
2. Las tarjetas de áreas son entradas a páginas completas. Al seleccionar Cocina fría, la persona entra a esa área y la pantalla de inventario queda acotada a ella.
3. El buscador dentro de un área busca solo en esa área. La vista global sigue disponible y agrupa el mismo producto por área con sus existencias.
4. Los productos mantienen una identidad maestra. No se crean copias como “Leche Cafetería” y “Leche Cocina” para representar existencias distintas.
5. No se automatiza ahora el descuento de stock desde Fudo ni desde recetas.
6. Se construirá la posibilidad de asociar una receta a un área de elaboración. Esa relación será metadato; no aplicará recetas a productos existentes ni ejecutará descuentos.
7. Las recetas existentes se conservan tal como están. Alejo creará productos y recetas nuevos para probar la asignación por área.
8. Bodega central (`central`) es el único punto normal de recepción, conteo y origen de repartos. Todo producto físico nuevo entra primero allí.
9. Cada reparto desde Bodega elige Cocina fría, Cocina caliente, Barra o Cafetería como destino. Es una transferencia atómica y auditable: disminuye el origen, aumenta el destino y conserva producto, cantidad, usuario, fecha y lote cuando corresponda.
10. Un producto puede habilitarse para varias áreas. Cada cantidad física está en una sola ubicación; cualquier distribución a otra área exige reparto/transferencia explícita y no duplica unidades.
11. Las mermas se registran en un único módulo global e indican el área de ocurrencia. Críticos, reportes y búsquedas globales se calculan por área.
12. `productos.stock_actual` será una proyección de compatibilidad de solo lectura; no será un segundo saldo editable.
13. Recetas y Lama–Stock real permanecen desactivados hasta que el libro por ubicación esté funcionando y verificado.
14. `angamos` archivada y la clave histórica `bodega` conservan su historia y no se migran en esta fase. No se aplican como reglas universales flujos heredados de Café del Desierto.

## 3. Sugerencias para distribución futura (no clasificación histórica)

Las siguientes reglas pueden presentarse como sugerencias al preparar una distribución futura, pero no asignan ni mueven stock existente automáticamente. Todo movimiento debe ser confirmado como una transferencia explícita; los ambiguos permanecen en Sin asignar hasta revisión.

| Regla prioritaria | Destino | Ejemplos / alcance |
|---|---|---|
| Bebidas calientes y productos de barra de café simple | Cafetería | Café, té, leches de uso de cafetería y bebidas de café. Una bebida fría de café puede requerir revisión si el nombre no permite distinguirla. |
| Tortas | Cafetería | Todas las tortas, incluyendo trozos, mientras el nombre permita identificarlas. |
| Preparaciones saladas | Cocina caliente | Panes, pizzas y sándwiches. |
| Helados y productos identificados como “ice” | Cocina fría | Aplicar solo cuando el nombre realmente identifique helado/producto frío; coincidencias ambiguas se revisan. |
| Ingredientes dulces | Cocina fría | Leche condensada, manjar/dulce de leche y otros ingredientes dulces identificables. |
| Bebidas gaseosas | Barra | Coca-Cola, Sprite y otras bebidas gaseosas claramente identificables. |
| Otros productos | Sin asignar | Revisión manual; no inferir destino por una categoría incompleta. |

**Uso permitido:** sugerir destinos en una operación futura, con confirmación humana. No generar asignaciones persistentes ni movimientos por lote como efecto de coincidencias de texto. Un conflicto o una clasificación dudosa no sale de Sin asignar sin decisión explícita.

Estas reglas no modifican nombre, stock, sede, `tipo` ni `rubro` y no constituyen una fuente de ubicación histórica.

## 4. Arquitectura propuesta

La implementación debe modelar tres conceptos distintos:

- **Producto maestro:** qué producto es, con su identidad existente.
- **Área operativa:** dónde se controla dentro de una sede.
- **Existencia por producto y área:** cuánto hay de ese producto en esa área, con sus parámetros de control propios.

La fuente futura aprobada es un **libro de existencias por ubicación**. Conceptualmente, cada saldo se identifica por producto, sede, ubicación y lote cuando corresponda. El esquema físico, sus restricciones, la separación entre libro de movimientos y saldo derivado, y los nombres de tablas/columnas se diseñarán al implementar el bloque correspondiente; esta decisión no crea tablas.

### Fuente única de stock

El libro por ubicación será la única autoridad editable. `productos.stock_actual` se conserva temporalmente como proyección de compatibilidad de solo lectura, derivada de las ubicaciones del producto en esa sede. No dejar el campo global y el libro por ubicación editables en paralelo.

La migración inicial aprobada no usa clasificación histórica automática: todo saldo actual de `central` se representa en Bodega central; todo saldo actual de `plaza`, en Sin asignar de Local 1. Los lotes actuales de `plaza` también inician en Sin asignar sin atribución retroactiva a áreas. `angamos` y la clave histórica `bodega` conservan su historia sin migrarse en esta fase. Distribuciones posteriores desde Sin asignar hacia un área se anotan como transferencias explícitas con procedencia inicial `simulacion`; las sugerencias de clasificación no escriben asignaciones.

Antes de migrar, producir conciliación por producto, sede, ubicación y lote; verificar el stock total por sede; asegurar que cada unidad aparece en una única ubicación; y desplegar la ruta de compatibilidad de solo lectura. La migración debe ser aditiva, auditable y reversible sin eliminar historia.

Codex debe confirmar si área equivale a ubicación de stock, si lotes y vencimientos requieren área, cómo se identifica una existencia por sede, y qué pantallas o procesos escriben stock. No implementar una capa de áreas solo en la interfaz mientras las operaciones sigan descontando un stock ambiguo.

### Movimientos, lotes y reparto

- Una operación manual dentro de un área debe indicar el área y afectar solo la existencia de ese producto en esa área.
- Las mermas deben quedar ligadas al área donde ocurrieron para que los indicadores posteriores puedan discriminarla.
- Los registros históricos sin área mantienen su condición histórica; no asignarlos retroactivamente según las reglas de nombre sin autorización.
- Codex debe inspeccionar si los lotes/vencimientos pertenecen al producto o a la ubicación. Si una misma partida puede distribuirse entre áreas, la relación de lote debe permitir esa trazabilidad o documentar la limitación antes de implementarla.
- Todo producto físico nuevo se recibe y cuenta primero en Bodega central.
- El reparto desde Bodega requiere elegir un área destino en Local 1. La salida de Bodega y entrada al área forman una única transacción: ambas se confirman o ninguna; se conserva producto, cantidad, usuario, fecha y lote.
- El stock de plaza aún no contado por área permanece en Sin asignar. Su distribución posterior se registra como transferencia explícita, inicialmente con procedencia `simulacion`.
- Las mermas siguen en un único módulo global e incluyen el área en que ocurrió la pérdida.
- Los lotes de plaza migran inicialmente a Sin asignar; no se copia un lote a varias áreas. Cada transferencia futura debe conservar la identidad del lote o sus vínculos de trazabilidad.
- Críticos, reportes y búsqueda global se agregan desde el libro por ubicación, sin sumar dos veces una unidad o lote.

### Recetas

- Añadir en creación/edición de receta el campo “Área de elaboración” o equivalente, permitiendo elegir una de las áreas de la sede.
- Si la receta es nueva, su área puede guardarse y editarse para probar el flujo.
- No vincular automáticamente la receta a productos actuales, a Fudo, a ventas, a mermas ni al descuento de ingredientes.
- No alterar ni migrar recetas existentes. Una pantalla nueva puede mostrar “Sin área asignada” en las recetas históricas, pero no las asigna en lote.
- No usar esta primera versión para decidir cómo se descuenta café en grano u otros ingredientes no cuantificables. Esos conteos permanecen manuales.

## 5. Experiencia esperada

### Portada de Inventario

- Mostrar tarjetas navegables de Cocina fría, Cocina caliente, Barra y Cafetería para la sede de prueba.
- Cada tarjeta presenta al menos cantidad de productos asignados y cantidad de productos críticos, calculados desde datos reales del modelo. La definición de “crítico” debe reutilizar la regla actual de mínimos si existe y Codex debe verificarla.
- Incluir entrada a “Todas las áreas” y a la lista de productos Sin asignar.
- Incluir una opción clara para administrar/agregar áreas por sede. Antes de crear Ajustes nuevos, inspeccionar si ya hay una sección de configuración adecuada.

### Página de un área

- Entrar a una página completa, con nombre del área y sede visibles.
- Mostrar únicamente productos con existencia/asignación a esa área.
- Buscador, rubros/secciones, filtros, conteos y acciones deben permanecer dentro del área seleccionada.
- Permitir asignar un producto maestro existente al área y definir su stock y parámetros de control para esa área.
- Permitir crear un producto nuevo y asignarlo a una o más áreas si el modelo actual admite producto compartido. Cada área mantiene su cantidad independiente.
- Preservar rutas de retorno y navegación, sin enlaces huérfanos.

### Vista global

- Mantener búsqueda global.
- Agrupar resultados por producto maestro y mostrar cada área con su cantidad, incluyendo cero o “sin asignar” según el comportamiento acordado.
- Al pulsar una línea de área, abrir el producto dentro de esa área.
- No sumar cantidades que pertenezcan a otra sede; respetar sede activa y permisos existentes.

## 6. Fases de trabajo para Codex

### Bloque 0 — Auditoría de áreas, sedes y Bodega

**Estado: COMPLETADO (solo lectura y documentación).** El informe `docs/hermes/13-auditoria-areas-sedes-bodega.md` registra esquema instalado, sedes, stock, lotes, escritores, reparto, mermas, Fudo, Lama, permisos, arquitectura recomendada y conciliación. No se cambió código, esquema ni datos.

Decisiones de negocio registradas: Local 1 (`plaza`) será el ensayo operativo, Local 2 (`angamos`) se archivará más adelante conservando historia, Bodega (`central`) es nodo logístico, las áreas serán configurables por sede, mermas siguen globales con área cuando corresponda, las clasificaciones son editables, la distribución identifica destino por línea y una sede futura solo copia configuración aprobada. Local 1 no es aislamiento técnico: comparte proyecto y políticas de datos permisivas.

**Salida histórica de Bloque 0:** mantener B1 pendiente en esa etapa; antes de stock por área quedaban por decidir autoridad, corte, Sin asignar y controles. La decisión posterior aprobada por Alejo está en el documento 17. La selección de Local 1 nunca autorizó clasificar o migrar stock por sí sola.


La cola tendrá una sola fase activa. Las tres ventanas sugeridas son **12:00, 14:00 y 17:00 hora de Santiago**, cada una para un bloque independiente. Si el bloque previo no terminó o dejó una decisión pendiente, el siguiente no empieza y registra el bloqueo. Codex no activa por su cuenta la fase siguiente.

### Bloque B2.1 — Cimientos del modelo de áreas operativas

**Estado: COMPLETADO (2026-10-07).** Se creó el catálogo `public.areas_operativas` con código estable, sede, nombre visible, estado y orden. Solo se sembraron las cuatro áreas para `plaza`. `Sin asignar` es un estado de la relación preparatoria, no un área física adicional.

También se creó `public.producto_area_asignacion`, vacía y sin campo de cantidad. Tiene una única fila permitida por producto/sede, para que el stock total no se atribuya accidentalmente a varias áreas. Si en el futuro un producto se distribuye físicamente entre áreas, el reparto requerirá cantidades explícitas en el modelo de saldos de B2.2; no se debe sumar esta relación como stock.

Ambas tablas tienen RLS habilitado, sin políticas ni privilegios directos para `PUBLIC`, `anon`, `authenticated` o `service_role`. No se modificó `lama_areas`, que sigue representando el plano de mesas. La consulta `sql/2026-10-b2-1-simulacion-clasificacion.sql` conserva valor como análisis histórico de solo lectura; sus destinos y sumas son hipotéticos, no se persisten ni se usan para migrar stock. La decisión aprobada en el documento 17 prohíbe la clasificación histórica automática.

Resultado detallado, pruebas, conteos y rollback: `docs/hermes/15-b2-1-cimientos-areas.md`.

### Bloque B2.2 — Modelo de existencias por área

**Estado: REQUIERE DECISIÓN RESUELTA (2026-10-07); fase cerrada sin implementación.** Alejo aprobó el libro de existencias por ubicación, las ubicaciones iniciales, la política de migración y las reglas operativas descritas en `docs/hermes/17-decision-libro-existencias-ubicacion.md`. Esta aprobación resuelve la decisión arquitectónica; no autoriza por sí sola SQL, migración o cambios de aplicación.

**Objetivo:** resolver el modelo de cantidades por área y transición desde la fuente vigente `productos.stock_actual` sin duplicar stock.

1. Leer `CLAUDE.md`, las reglas de `docs/hermes/` y documentación relevante.
2. Trazar el inventario actual: producto, stock por sede, secciones/rubros, movimientos, mermas, lotes, reparto, permisos, búsqueda y rutas.
3. Verificar contra el esquema activo de Llamita Plus las tablas y columnas necesarias. No conectarse ni escribir en Café del Desierto.
4. La fuente aprobada e implementada en B2.3 es un libro por producto/sede/ubicación/lote.
5. Migración inicial aprobada: `central` a Bodega central; `plaza` a Sin asignar; lotes de `plaza` a Sin asignar; no migrar `angamos` ni la clave histórica `bodega`.
6. Toda futura transferencia debe ser explícita, atómica y conservar la trazabilidad; la clasificación por texto solo sugiere destino.
7. `productos.stock_actual` se mantiene como proyección protegida para `central` y `plaza`; los caminos antiguos que todavía no escriben al libro están bloqueados.
8. Recetas y Lama–Stock real no se activan antes de que el modelo por ubicación esté funcionando.

**Resultado de arquitectura:** queda resuelto el bloqueo de decisión descrito en `docs/hermes/16-b2-2-auditoria-fuente-unica-stock.md`. El libro por ubicación y su corte se implementaron en B2.3; el motor de transferencias se completó en B2.4. La distribución operativa y sus pantallas siguen pendientes de una fase posterior.

### Bloque B2.3 — Libro por ubicación y corte coordinado de escritores

**Estado: COMPLETADO (2026-10-07) para `central` y `plaza`.** El primer intento quedó bloqueado según `docs/hermes/18-b2-3-bloqueo-corte-libro-ubicaciones.md`; Alejo autorizó después el corte coordinado. Resultado completo: `docs/hermes/19-b2-3-corte-libro-ubicaciones.md`.

Se implementó un libro privado por producto/sede/ubicación/lote, con catálogo de ubicaciones, movimientos inmutables, aperturas auditables, transferencias idempotentes y vista de existencias. `central` se abrió en Bodega central; `plaza` en Sin asignar. No hubo clasificación histórica ni cantidades en Cocina fría, Cocina caliente, Barra o Cafetería. `angamos` y la clave histórica `bodega` no se migraron.

`productos.stock_actual` conserva sus valores como proyección protegida. Escritura directa del agregado, alta con saldo no cero, reemplazo de lotes y caminos legacy de movimientos, entradas, mermas, repartos/deshacer, restauraciones y fusiones fallan con un mensaje explícito para sedes migradas; las sedes históricas mantienen compatibilidad. Los lotes actuales de `central` y `plaza` se mantienen congelados como detalle legado y no se vuelven a sumar. Fudo recibió guardas en código fuente, pero las Edge Functions no se desplegaron; sus escritores de base y la aplicación real permanecen bloqueados. Lama real sigue apagado.

Las migraciones aplicadas en Llamita Plus fueron `20261007152558 b2_3_libro_existencias_corte` y `20261007152805 b2_3_indices_permisos_libro`. Pruebas de RLS/permisos, conciliación, bloqueos, transferencia Bodega -12/Cafetería +12 con producto lógico/lote/referencia compartidos e idempotencia pasaron dentro de una transacción revertida. El rollback técnico aborta si existen movimientos posteriores; en ese caso requiere reversión compensatoria auditada.

### Subfase B2.3.1 — Blindaje de conectores POS y origen activo

**Estado: COMPLETADO (2026-10-07); ningún POS quedó activo.** La configuración previa se encontraba separada: `public.fudo_sync` guardaba modo/cursor de Fudo, `public.lama_stock_config` guardaba modo de Lama y `public.ajustes` almacenaba flags booleanos. Ninguna de ellas era una fuente única por sede.

La migración `20261007162948 b2_3_1_pos_origin_guard` creó `stock_internal.origen_pos`, con una fila por sede y una sola columna de origen. El estado persistente inicial es `ninguno` para `plaza`, `central`, `angamos` y `bodega`. Solo `plaza` admite en el modelo `fudo`, `lama`, `toteat`, `ninguno` o `prueba`; `central`, `angamos` y `bodega` solo admiten `ninguno`. `prueba` nunca autoriza escrituras. RLS y ACL dejan la tabla inaccesible directamente a `anon`, `authenticated` y `service_role`; el navegador no puede elegir o cambiar el origen.

Fudo requiere que el helper `public.stock_pos_origen_permitido` confirme el origen antes de procesar venta o tocar inventario local/remoto. El helper solo tiene `EXECUTE` para `service_role`. El RPC `fudo_procesar_item` conserva la definición instalada con una guarda añadida y queda invocable solo por backend; trigger adicional bloquea eventos Fudo directos cuando Fudo no sea origen activo. Lama requiere origen `lama` al intentar habilitar modo real y antes de aplicar una aplicación de evento real; se conserva además el bloqueo real previo de B2.3. Toteat es solo un valor reservado.

Se desplegaron seis funciones Edge activas con JWT requerido y release marker `2026-10-07-b2.3.1`: `fudo-ciclo`, `fudo-sync-ventas`, `fudo-empujar-stock`, `fudo-deshacer-stock`, `fudo-sumar-stock` y `fudo-probar-escritura`. Sus versiones de Supabase quedaron en `1`; se recuperó el contenido desplegado y se verificó el guard/marker en cada una. Ningún endpoint llamó a Fudo durante esta fase.

No existe un selector de Ajustes. Para implementarlo, una operación de backend deberá verificar `app_permisos.puede_ajustes` y cambiar la fila por sede de forma atómica/auditable; si Alejo quiere delegar ese cambio a un grupo más pequeño, hace falta una capacidad administrativa específica. Reporte, pruebas y riesgos: `docs/hermes/20-b2-3-1-blindaje-origen-pos.md`.

Fudo sigue en modo prueba con cron apagado en `plaza`; Lama permanece sin configuración real; la autoridad por ubicación sigue bloqueando operaciones de stock legacy hasta que cada escritor se adapte al libro. B2.4 implementa solo transferencias explícitas y no abre otros escritores.

### Bloque B2.4 — Motor seguro de transferencias entre ubicaciones

**Estado: COMPLETADO (2026-10-07).** Se habilitó el RPC protegido `public.stock_transferir` para cuentas autenticadas con `app_permisos.puede_editar=true`. La entrada pública es `SECURITY INVOKER`; el helper del esquema privado valida nuevamente el JWT/email y el permiso antes de ejecutar el núcleo transaccional. Las tablas `stock_internal` siguen sin mutación directa desde API, `anon` o `service_role`.

Se admiten únicamente estos movimientos: Bodega central → área activa de Local 1 usando un enlace `producto_enlace` explícito con factor 1; Sin asignar → área activa de Local 1; área → otra área activa de Local 1 conservando el mismo producto. Se rechazan sedes `angamos` y `bodega`, equivalencias por nombre, destinos Sin asignar, productos sin enlace válido y saldos insuficientes.

Cada llamada crea un encabezado inmutable y dos movimientos de igual referencia/idempotencia: salida negativa y entrada positiva. Un trigger diferido verifica al confirmar la transacción que exista el par completo y balanceado. El motor serializa por referencia y saldo origen, rechaza saldos negativos y revierte ambos lados ante cualquier excepción. Registra actor autenticado, fecha, motivo, productos, ubicaciones, lote y referencia; `reversa_de` deja preparada la trazabilidad de una futura reversa compensatoria, que aún no tiene endpoint.

Para lotes se conserva el `producto_lotes.id` canónico y su vencimiento mediante `stock_internal.lote_continuidad`, que enlaza el mismo lote a los IDs de producto de Bodega y Local 1. No se inserta un lote ficticio en `producto_lotes`. El motor solo puede asignar detalle legado desde el saldo sin lote cuando la cantidad existente en `producto_lotes` cabe en el saldo no asignado; esa reclasificación se registra como dos movimientos compensados y ocurre en la misma transacción. Si no concilia, bloquea la transferencia.

`productos.stock_actual` no se escribe desde la función: los triggers del libro actualizan su proyección. En una transferencia entre sedes con IDs maestros distintos, el agregado proyectado del producto origen disminuye y el del producto destino aumenta; el total global permanece igual. El rollback técnico aborta si existen transferencias o continuidad nuevas; después solo corresponde compensar con movimientos auditados. No se implementó interfaz ni asignación automática.

Migraciones y pruebas: `docs/hermes/21-b2-4-motor-transferencias-ubicaciones.md`. B3 —portada, páginas, productos y búsqueda por áreas— queda **PENDIENTE**, no activada.

### Bloque B3 — Portada, páginas de área, productos y búsquedas

#### B3.1 — Lectura y navegación por áreas

**Estado: COMPLETADO (2026-10-07).** Para `plaza`, la entrada actual de Inventario es una portada con Cocina fría, Cocina caliente, Barra, Cafetería, Sin asignar y Todas las áreas. Cada tarjeta informa productos con saldo y unidades; el estado de críticos dice “sin mínimos configurados”, sin mostrar ceros falsos. Sin asignar explica que contiene stock pendiente de distribución.

Las páginas de área reutilizan la vista de Inventario, filtran búsqueda y tipo por ubicación y presentan solo productos con saldo positivo en esa ubicación. La vista global agrupa una identidad de producto y separa cantidades por ubicación, con accesos al producto dentro de cada área. Bodega `central` conserva su renderer existente. La lectura proviene de `stock_internal.existencias` mediante `public.stock_leer_areas`; no usa `productos.stock_actual` como saldo, no incluye Bodega y no habilita operaciones. Las cuatro áreas físicas de Local 1 continúan en cero; Sin asignar conserva 4.566,20 unidades en 255 productos con saldo.

RLS y grants mantienen cerradas las tablas internas; la RPC requiere sesión autenticada y solo tiene `EXECUTE` para `authenticated`. Las vistas de área no permiten editar stock ni llamar `stock_transferir`. Sin mínimos por área no se calculan críticos. Evidencia: `docs/hermes/22-b3-1-lectura-areas.md`.

#### B3.2 — Escrituras visuales por área

**Estado: dividido en subfases. B3.2a.1–B3.2a.3 COMPLETADAS; B3.2b PENDIENTE, no activa.** S1/S2 cerraron el bloqueo de autorización; B3.2a.1 instaló el contrato de datos/RPC, B3.2a.2 la lectura/UX dinámica y B3.2a.3 hizo encontrable la gestión y separó asignación de existencia física. Las transferencias requieren activación separada. Ver informes 23, 25, 26, 28, 29 y 32.

La auditoría S0 amplió la evidencia: 36 tablas operativas tienen políticas abiertas `ALL`, y 40 funciones `SECURITY DEFINER` son ejecutables por anon. S1 debe resolver primero identidad, gobierno de permisos y las rutas críticas por fases. No debe mezclarse ese corte transversal con la UI de áreas. Informe: `docs/hermes/24-auditoria-integral-seguridad-permisos.md`.

##### B3.2a — Gestión de áreas y asignación preferida de productos

**Estado: COMPLETADA POR SUBFASES.**

- **B3.2a.1 COMPLETADA (2026-10-08):** contrato aditivo, actores, nombres normalizados, área/ubicación 1:1, archivo seguro, preferencia única y RPC de producto con stock cero. No mueve existencias. Informe 28.
- **B3.2a.2 COMPLETADA (2026-10-08):** lectura dinámica y formularios/UX consumen RPC protegidas; nuevas áreas aparecen sin listas fijas. Preferencia y saldo físico se muestran por separado, sin transferencias. Informe 29.
- **B3.2a.3 COMPLETADA (2026-10-09):** “Gestionar áreas” enlaza Inventario con la única pantalla administrativa; las tarjetas separan agregar una ficha existente de crear una nueva; un duplicado ofrece reutilizar la ficha; preferencia y ubicación física se explican por separado. Los selectores de destino usan solo áreas activas y Sin asignar. Informe 32.

La jerarquía queda explícita: la **sede** es el nodo operativo; **Bodega central** es un nodo logístico, no un área de Local 1; un **área operativa** es una ubicación física vinculada al ledger; el **área preferida** es metadata organizativa sin cantidad; la **ubicación física** contiene el saldo; una futura **sección interna** podría subdividir visualmente un área, pero todavía no existe; categoría, rubro y tipo siguen siendo clasificaciones descriptivas y nunca destinos del ledger. Limpieza, Vitrina y Sándwiches no se convierten automáticamente en ubicaciones.

##### B3.2b — Transferencias visuales

**Estado: PENDIENTE, no activa.** No iniciar hasta que B3.2a quede resuelta y se active por separado. Esta fase deberá llamar únicamente a `stock_transferir`, con permiso, idempotencia, lotes y auditoría; nunca editará saldos directamente.

**Objetivo:** hacer que la navegación refleje áreas sin perder inventario global. Lo implementado en B3.1 cubre únicamente lectura y navegación; los siguientes puntos continúan pendientes:

1. Agregar la asignación de un producto existente a una o más áreas y el alta de productos con asignación inicial a área. No duplicar la identidad maestra.
2. Diseñar el flujo visual de transferencias invocando únicamente `stock_transferir`; validar permisos, referencias idempotentes, lotes y errores.
3. Mantener Sin asignar visible y corregible. La lista general no puede desaparecer ni quedar inaccesible desde un enlace antiguo.
4. Validar sede activa, roles y acceso directo a rutas de áreas.

**Criterios de salida:** las escrituras se ejecutan mediante funciones atómicas protegidas; un producto puede tener cantidades independientes en varias áreas; no se filtra información de otra sede; pruebas de navegación, permisos, concurrencia, idempotencia, lotes y reversión compensatoria.

### Bloque B4 — Operaciones, mermas, repartos, recetas y cierre

**Objetivo:** conectar las operaciones de inventario con el área correcta y dejar la receta lista como metadato.

1. Actualizar conteo manual, ajuste y registro de merma para exigir/usar el área cuando se opera desde una página de área.
2. Conservar movimientos históricos sin área y mostrarlos como históricos/globales sin atribuirlos falsamente a una zona.
3. Adaptar mínimos/críticos y reportes básicos para calcularlos por área, sin contar dos veces el mismo producto.
4. Revisar recepción de reparto y permitir el destino correcto por ítem según las capacidades actuales: bodega/sede o área operativa. No cambiar el destino predeterminado hasta verificar el flujo existente.
5. Implementar transferencias entre áreas solo si el análisis confirma que el modelo actual permite registrar ambos lados de forma atómica y auditable; si requiere otra fase, documentarlo y no simular el movimiento.
6. Añadir el campo de área de elaboración a creación/edición de recetas nuevas. Mantener recetas existentes intactas y sin asignación masiva.
7. Confirmar que no hay llamadas de descuento de receta, Fudo/POS ni stock automático relacionadas con esa metadata.
8. Ejecutar pruebas de integración, regresión de inventario general, conciliación por sede/área, datos sin asignar, errores de red y modos de demostración.
9. Actualizar `CLAUDE.md` en un capítulo específico de Llamita Plus y la documentación del plan/bitácora con comportamiento final y límites.

**Criterios de salida:** mermas y conteos asociados a la zona correcta; recetas con metadato editable y sin efectos automáticos; reparto no ambiguo; regresiones clave aprobadas; documentación y bitácora actualizadas; despliegue de Llamita Plus revisado.

## 7. Pruebas de aceptación globales

1. La sede de prueba muestra cuatro áreas configurables; otra sede no recibe esas áreas por accidente.
2. Una misma leche puede tener existencias independientes en Cocina fría, Cafetería y otras áreas.
3. Dentro de Cafetería, buscar “leche” no muestra las existencias de las otras áreas.
4. En “Todas las áreas”, “leche” muestra una sola identidad de producto con cantidades separadas por área y sede.
5. Coca-Cola y Sprite se proponen para Barra; café, té, leche común y tortas para Cafetería; panes, pizzas y sándwiches para Cocina caliente; leche condensada/manjar e ingredientes dulces identificables para Cocina fría.
6. Los nombres ambiguos permanecen Sin asignar y se pueden corregir manualmente.
7. La asignación no altera `rubro`, `tipo`, nombres, sedes, ventas o movimientos anteriores.
8. Una merma registrada dentro de Cocina fría reduce únicamente el inventario de ese producto allí y queda identificada con su área.
9. Una receta nueva puede asociarse a Cafetería y guardarse. Una receta antigua no cambia, y guardar la nueva no descuenta stock ni invoca Fudo.
10. La recepción de un reparto exige un destino inequívoco y conserva compatibilidad con el flujo de bodega/sedes vigente.
11. Un producto Sin asignar y un área vacía tienen una presentación utilizable, sin tablas rotas ni conteos falsos.
12. No hay cambio ni consulta sobre el proyecto de Café del Desierto / Llamita Stock.

## 8. Riesgos y controles

| Riesgo | Control previsto |
|---|---|
| Dos fuentes de stock (`stock_actual` y stock por área) | Definir una sola autoridad, conciliación antes/después y pruebas de no duplicación. |
| Cambiar stock histórico al asignar áreas | Migración auditada; no atribuir movimientos antiguos por heurística. |
| Búsqueda o total que mezcla áreas/sedes | Filtros explícitos de sede y contexto de área; pruebas con productos repetidos. |
| Clasificación incorrecta por palabras ambiguas | Precedencia documentada, origen visible, lista Sin asignar y corrección manual. |
| Lotes sin ubicación | Inspección en Bloque 1; modelar destino o dejar explícito el límite antes de recibir cambios de stock. |
| Recetas disparan descuentos no deseados | Campo solo metadato; pruebas que confirmen ausencia de llamadas a Fudo/POS o mutaciones de stock. |
| Repartos no distinguen bodega y áreas | Destino obligatorio por ítem cuando corresponda; mantener compatibilidad con sede actual. |
| Cambio de áreas rompe la vista de Café del Desierto | No tocar ese repo/base; no reutilizar lógica organizacional como regla universal. |

## 9. Publicación y registro

- Cada bloque autorizado termina con resumen, archivos, migraciones, pruebas, riesgos y commit.
- El destino normal de publicación es `master` de Llamita Plus, de acuerdo con la autorización de trabajo ya dada por Alejo.
- Un fallo de pruebas o una decisión de datos abierta detiene el bloque; no se presenta como completo.
- Codex registra el resultado en `docs/hermes/04-bitacora-codex.md` y deja la cola en un estado que impida repetir o saltar fases.
- El usuario revisa el resultado visible en Llamita Plus antes de activar el bloque siguiente.

## 10. Decisiones y precondiciones vigentes

La fuente única, ubicaciones iniciales, tratamiento del stock histórico, transferencia atómica y proyección aprobados están en `docs/hermes/17-decision-libro-existencias-ubicacion.md`. B2.3 implementó el libro y el corte para `central`/`plaza`; B2.3.1 añadió el origen POS único y el blindaje de Fudo/Lama. Resultados: `docs/hermes/19-b2-3-corte-libro-ubicaciones.md` y `docs/hermes/20-b2-3-1-blindaje-origen-pos.md`. El documento 18 conserva el bloqueo del intento previo como antecedente.

Quedan para fases posteriores: adaptar entradas, ajustes, mermas, repartos y consumo de recetas al libro; definir mínimos/máximos por ubicación; y habilitar escrituras visuales por área en B3.2. `angamos` y la clave histórica `bodega` no se migraron. B3.2 requiere activación separada.

Estas verificaciones no son permiso para abrir alcance hacia Café del Desierto, ejecutar operaciones destructivas o automatizar el descuento de recetas.

### Precondición de seguridad S0/S1

S0 confirmó que las capacidades heredadas se relacionaban con Auth solo por correo y podían ser modificadas por clientes. S1 quedó completada: existe un único `propietario_raiz` privado por `auth.uid()`, `app_permisos` está vinculada por UUID, el DML directo está revocado y la gestión usa RPC auditada. La recuperación de raíz queda fuera de la aplicación mediante acceso de proyecto con MFA.

La transición conservó triggers y ledger protegidos. Las fases siguientes deben migrar por separado Lama/caja, RPC privilegiados, productos, logística, Fudo y reportes; S1 no autorizó esos cortes. B3.2a puede planificarse sobre la fuente confiable, pero sigue pendiente de activación.


## 11. Resultado de B1 — administración segura de sedes

**Estado: COMPLETADO (2026-10-06).** Se creó el catálogo aditivo `public.sede_registro`: código interno estable, nombre visible, tipo y estado. `plaza` (Local 1) y `central` (Bodega logística) quedan activas; `angamos` (Local 2) queda archivada; `bodega` permanece como clave histórica separada y archivada.

El cliente solo puede leer el catálogo. La UI oculta Local 2, rechaza su selección directa y no ofrece nuevos repartos a ese destino; no se añadió un editor en Ajustes porque `app_permisos` no ofrece autorización confiable por sede. El esquema permite gestionar nombre y estado mediante cambios de base controlados, conserva la clave interna inmutable y no da privilegios de escritura al navegador.

El archivo es lógico: no se borraron ni actualizaron datos operativos de Local 2. Bodega `central` mantiene sus rutas de recepción, conteo y envío a Local 1. Las guardas de interfaz evitan entradas accidentales, pero no crean aislamiento de API; el RLS permisivo legado queda como riesgo documentado en `docs/hermes/14-b1-registro-sedes-resultados.md`.

**B2 sigue pendiente y no activado.** Esta fase no crea áreas ni existencias por área y no cambia stock, productos, lotes, vencimientos o registros de reparto. La clonación de sedes queda para una subfase futura; no se copian datos.
