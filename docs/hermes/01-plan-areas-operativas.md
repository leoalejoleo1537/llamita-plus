# Plan de implementación: inventario por áreas operativas en Llamita Plus

**Estado:** B1 y B2.1 completados. La decisión arquitectónica de B2.2 quedó aprobada por Alejo el 2026-10-07 y documentada en `docs/hermes/17-decision-libro-existencias-ubicacion.md`; B2.2 se cierra como **REQUIERE DECISIÓN RESUELTA**, sin implementación de tablas, datos o código. B2.3 queda **PENDIENTE**, no activa. No activar fases posteriores automáticamente.

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
4. La fuente conceptual aprobada es un libro por producto/sede/ubicación/lote; queda pendiente su implementación física en una fase reactivada.
5. Migración inicial aprobada: `central` a Bodega central; `plaza` a Sin asignar; lotes de `plaza` a Sin asignar; no migrar `angamos` ni la clave histórica `bodega`.
6. Toda futura transferencia debe ser explícita, atómica y conservar la trazabilidad; la clasificación por texto solo sugiere destino.
7. `productos.stock_actual` se mantiene como proyección de compatibilidad no editable, después de adaptar todos sus escritores/lectores y permisos.
8. Recetas y Lama–Stock real no se activan antes de que el modelo por ubicación esté funcionando.

**Resultado de arquitectura:** queda resuelto el bloqueo de decisión descrito en `docs/hermes/16-b2-2-auditoria-fuente-unica-stock.md`. Siguen pendientes la construcción del libro, el corte de escritores/lectores, permisos/RLS, lotes y conciliación. Ninguna cantidad se ha migrado.

### Bloque B2.3 — Interfaz y formularios (pendiente)

**Estado: PENDIENTE; no activa.** No ejecutar hasta recibir activación explícita y verificar que el libro por ubicación, la migración conciliada y los adaptadores de lectura/escritura estén implementados y disponibles.

**Alcance previsto:** portada con las ubicaciones habilitadas; páginas de Bodega, Sin asignar y las cuatro áreas; búsqueda y vista global por ubicación; selección de área destino en la preparación de reparto; indicación del área en la merma global; formularios que llaman únicamente a operaciones del libro y nunca editan `productos.stock_actual`; filtros y mínimos/críticos calculados por área. La operación de transferencia pertenece a una transacción del backend, no a escrituras independientes de la interfaz.

**Criterios de salida:** cada saldo se muestra en una sola ubicación; Sin asignar conserva lo no distribuido; un reparto indica destino y no permite confirmar si origen/destino no pueden aplicarse atómicamente; lote y auditoría visibles cuando existen; merma exige área; consultas y críticos se filtran por área; el total por producto/sede reconcilia; rutas y permisos no revelan ni permiten editar otra sede; `stock_actual` es solo lectura; ninguna clasificación por nombre mueve stock; pruebas desktop/móvil, errores/reintentos e idempotencia pasan. Las recetas y Lama–Stock real siguen apagados.

### Bloque B3 — Portada, páginas de área, productos y búsquedas

**Objetivo:** hacer que la navegación refleje áreas sin perder inventario global.

1. Construir la portada de Inventario con tarjetas por área, conteos y críticos.
2. Construir la página completa de cada área y conservar navegación de ida y vuelta.
3. Acotar búsqueda, conteos, rubros/filtros y listados al área abierta.
4. Implementar “Todas las áreas” con agrupación por producto y cantidades por área.
5. Agregar la asignación de un producto existente a una o más áreas y el alta de productos con asignación inicial a área. No duplicar la identidad maestra.
6. Mantener Sin asignar visible y corregible. La lista general no puede desaparecer ni quedar inaccesible desde un enlace antiguo.
7. Validar sede activa, roles y acceso directo a rutas de áreas.

**Criterios de salida:** búsquedas aisladas y globales correctas; un producto puede tener cantidades independientes en varias áreas; no se filtra información de otra sede; tarjetas reflejan datos; pruebas de navegación, permisos y datos vacíos.

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

La fuente futura, ubicaciones iniciales, tratamiento del stock histórico, transferencia atómica y proyección están aprobados y registrados en `docs/hermes/17-decision-libro-existencias-ubicacion.md`. No se ha implementado la arquitectura.

Antes de cualquier fase de implementación siguen pendientes: adaptar todos los lectores/escritores y permisos al libro; implementar ubicación/trazabilidad de lotes; definir y verificar mínimos/máximos por ubicación; diseñar el corte sin escrituras parciales; y probar conciliación por producto, sede, ubicación y lote. La decisión no activa B2.3 ni autoriza SQL o cambios de datos. `angamos` y la clave histórica `bodega` no se migran en esta fase.

Estas verificaciones no son permiso para abrir alcance hacia Café del Desierto, ejecutar operaciones destructivas o automatizar el descuento de recetas.


## 11. Resultado de B1 — administración segura de sedes

**Estado: COMPLETADO (2026-10-06).** Se creó el catálogo aditivo `public.sede_registro`: código interno estable, nombre visible, tipo y estado. `plaza` (Local 1) y `central` (Bodega logística) quedan activas; `angamos` (Local 2) queda archivada; `bodega` permanece como clave histórica separada y archivada.

El cliente solo puede leer el catálogo. La UI oculta Local 2, rechaza su selección directa y no ofrece nuevos repartos a ese destino; no se añadió un editor en Ajustes porque `app_permisos` no ofrece autorización confiable por sede. El esquema permite gestionar nombre y estado mediante cambios de base controlados, conserva la clave interna inmutable y no da privilegios de escritura al navegador.

El archivo es lógico: no se borraron ni actualizaron datos operativos de Local 2. Bodega `central` mantiene sus rutas de recepción, conteo y envío a Local 1. Las guardas de interfaz evitan entradas accidentales, pero no crean aislamiento de API; el RLS permisivo legado queda como riesgo documentado en `docs/hermes/14-b1-registro-sedes-resultados.md`.

**B2 sigue pendiente y no activado.** Esta fase no crea áreas ni existencias por área y no cambia stock, productos, lotes, vencimientos o registros de reparto. La clonación de sedes queda para una subfase futura; no se copian datos.
