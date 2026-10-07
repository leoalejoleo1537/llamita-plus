# Bloque 0 — Auditoría de inventario por áreas, sedes y Bodega

Fecha: 2026-10-07
Estado: **COMPLETADO — auditoría de solo lectura**
Repositorio verificado: `leoalejoleo1537/llamita-plus` (`origin` correcto; rama local `work`).
Proyecto Supabase verificado por metadatos: `llamita-plus`, ref `iuryhsjucblmebdogewa`, PostgreSQL 17.6.
Límite: toda consulta fue al proyecto Llamita Plus. No se consultó ni modificó Café del Desierto / Llamita Stock.

## 1. Alcance y resultado

Se revisaron documentación Hermes, `index.html`, migraciones disponibles, esquema activo y metadatos de Supabase mediante lecturas. No se ejecutó SQL de escritura, RPC, migración, prueba sintética ni cambio de datos. Este documento es un diagnóstico para decidir el siguiente corte; no activa B1.

La aplicación actual controla existencias mediante una fila de `productos` por producto y sede. No hay entidad de sede ni de área de inventario en la base. `lama_areas` describe zonas del plano de mesas de Lama y no se puede reutilizar como área de stock. La separación por áreas requiere decidir primero una única fuente de verdad y adaptar coordinadamente todos los escritores. Una tabla paralela editable mientras las rutas actuales siguen escribiendo `productos.stock_actual` causaría doble saldo.

## 2. Sitios y cantidades observadas

La UI declara `plaza` (Local 1), `angamos` (Local 2) y `central` (Bodega). La clave `bodega` aparece en datos históricos, pero no es la Bodega activa: el código y la documentación la identifican como clave antigua que no debe reutilizarse. Los nombres históricos asociados a sedes no se deben interpretar como áreas.

| Clave `productos.sede` | Significado actual | Filas de producto | Activos | Productos con stock distinto de cero | Suma `stock_actual` |
|---|---|---:|---:|---:|---:|
| `plaza` | Local 1 | 329 | 264 | 255 | 4,566.20 |
| `angamos` | Local 2 | 351 | 245 | 228 | 2,764.20 |
| `central` | Bodega activa | 349 | 262 | 149 | 4,750.50 |
| `bodega` | Clave histórica, separada | 408 | 351 | 302 | 3,357.10 |
| **Total** | Cuatro conjuntos de filas independientes | **1,437** | **1,122** | **934** | **15,438.00** |

Las cifras son una lectura de inventario, no un conteo físico conciliado. No se sumó el detalle de lotes encima de `stock_actual`.

### Decisiones de negocio recibidas para orientar el diseño

- Local 1 (`plaza`) será el local operativo de prueba. Esto no crea aislamiento técnico: es una sede poblada dentro del mismo proyecto y las políticas RLS observadas no aíslan por sede.
- Local 2 (`angamos`) se archivará en una fase posterior, conservando IDs, productos, lotes e historial; no se borrará ni se transferirá stock automáticamente.
- Bodega activa es `central` y funciona como nodo logístico diferenciado, no como área operativa del local.
- Las áreas serán configurables por sede; Cocina fría, Cocina caliente, Barra de bar y Cafetería son la configuración inicial de trabajo.
- Mermas siguen siendo una función global, con atribución de área cuando la operación se origine dentro de un área.
- La clasificación sugerida se podrá editar y revisar; no se inferirá área de `rubro`, `tipo`, turno o nombre como dato definitivo.
- Una ubicación podrá administrar productos nuevos y asignar un producto existente a varias áreas; la identidad de producto y las existencias por ubicación deben permanecer diferenciadas.
- La distribución desde Bodega debe identificar un destino por línea y conservar trazabilidad de origen/destino.
- Una futura clonación de sede podrá copiar configuración autorizada, nunca stock ni datos operativos.

## 3. Hechos comprobados del modelo instalado

### Catálogo, sede y enlaces

- `productos` contiene `sede`, `stock_actual`, `stock_min`, `stock_max`, `rubro`, `tipo`, unidad, perecibilidad y estado. El identificador representa una copia de producto dentro de una sede; no hay un producto maestro compartido entre sedes.
- `producto_enlace` enlaza una fila de producto de Bodega (`producto_bodega_id`) con una fila por sede (`producto_sede_id`) y un factor. Son copias relacionadas, no una identidad canónica ni una asignación a áreas. La lectura encontró 250 enlaces para `plaza` y 263 para `angamos`; en Plaza hay 249 IDs de Bodega distintos para 250 enlaces. Ambos extremos existían en sus sedes esperadas.
- `secciones` y los campos `rubro`/`tipo` organizan presentación y filtros. No identifican ubicación física ni área operativa.
- `app_permisos` expone flags globales (`puede_fudo`, `puede_editar`, `puede_ajustes`, `puede_lama`, `fudo_bloqueos`); el esquema activo no tiene permiso por sede ni por área.

### Áreas, movimientos e historial

- No existen las relaciones `public.sedes`, `public.areas`, `public.area_existencias` ni una tabla `public.mermas`.
- `lama_areas` tiene cinco filas para `plaza` y se usa con `mesas.area_id` para el plano de mesas. No es inventario.
- `movimientos` contiene entradas, salidas, ajustes y mermas (`tipo='merma'`), con producto/sede, cantidad firmada, motivo, contraparte de sede, autor/fecha, referencia opcional a reparto y datos de reversa. No tiene `area_id`.
- `historial` y `historial_auto` son snapshots por sede/producto sin área; no son un ledger de stock. Sus filas históricas deben permanecer sin área y no se pueden asignar retroactivamente por heurística.
- Los registros de `movimientos` observados sumaban 431: `angamos` 3, `central` 403 y `plaza` 25. En `central` se observaron 58 mermas, 246 salidas, 93 ajustes y 6 entradas; en `plaza`, 25 mermas; en `angamos`, 2 mermas y 1 salida.

### Lotes, mínimos y críticos

- `producto_lotes` tiene 42 filas y solo referencia `producto_id`, cantidad y vencimiento; no tiene sede ni área propia. La sede se deriva de la fila de producto.
- Para cada producto que tenía lotes, la suma de sus lotes igualaba `productos.stock_actual` (diferencia observada: cero). El trigger `trg_sync_stock_lotes` llama a `sync_stock_desde_lotes()` y recalcula `stock_actual` después de cambios de lotes. El lote es detalle del mismo saldo, no una cantidad adicional.
- `stock_min` y `stock_max` están en la fila de producto/sede. La UI calcula crítico cuando el stock es cero o está en/por debajo del mínimo; el máximo permite señalar exceso. La adaptación por área requiere umbrales de cada ubicación, no repartir umbrales actuales por inferencia.

### Recepción y distribución

- `repartos.sede` es la sede destino; `origen` es texto y por defecto puede decir “Bodega”, por lo que no demuestra el origen efectivo.
- `reparto_items.producto_id` señala el producto del destino y `producto_bodega_id` / `producto_origen_id` pueden señalar origen; incluye cantidades, estado, lote creado y datos de deshacer. No incluye área destino.
- `reparto_recibir` suma al producto destino o crea lotes; `reparto_descontar_bodega` puede hacer la baja del origen por una acción separada; `reparto_deshacer` revierte el destino y, cuando existe trazabilidad, devuelve al origen. El flujo puede recibir primero en el local y descontar Bodega después, de modo que una futura área necesita definir si ambas puntas son una transacción única.
- `registrar_entrada` está restringida a productos de `central` (Bodega). En perecederos crea lotes y el trigger actualiza la proyección de stock. `deshacer_entrada` tiene restricciones cuando hay lotes.
- `franquicia_linea_lista` es otro flujo que escribe stock de Bodega desde la UI.

### Mermas, Fudo y Lama

- La función instalada `mermar` valida motivos existentes (incluye `daño`, `robo`, `vencimiento`, `otro`); con lotes descuenta filas/lotes y el trigger sincroniza el total, sin lotes decrementa stock directamente. `deshacer_merma` restaura el saldo o lotes. No hay atribución de área.
- Fudo mantiene catálogos, enlaces, recetas, sincronización y movimientos por sede. Las sedes con `fudo_sync` consultadas (`plaza`, `angamos`) estaban en modo `prueba`, con cron deshabilitado; no se consultaron secretos ni se llamó a la API. El adaptador de stock afecta el stock por producto/sede actual y requiere coordinarlo con cualquier nuevo motor.
- Lama ya tiene tablas y funciones de puente de inventario A3, pero `lama_stock_config`, eventos, capturas y aplicaciones tenían cero filas en las lecturas. No hay configuración persistente activa. `lama_areas` no debe convertirse en ubicación de inventario.

## 4. Puntos que leen o escriben stock

La lista se obtuvo combinando inspección de `index.html`, migraciones versionadas y funciones instaladas referidas por las inspecciones anteriores A1/A3. Las funciones deben volver a verificarse con sus firmas reales antes de cualquier cambio; los archivos históricos no sustituyen la definición instalada.

| Camino | Efecto actual / riesgo de transición |
|---|---|
| UI `saveFields()` y alta de producto | Actualiza directamente `productos.stock_actual` y permite stock inicial; la edición manual no genera movimiento de auditoría. |
| `guardarLotes()` y `producto_lotes` | Reemplaza los lotes; trigger recalcula el stock agregado. No escribir el total otra vez en paralelo. |
| `registrar_entrada` / `deshacer_entrada` | Recibe en Bodega; lote y cantidad directa según producto. |
| `mermar` / `deshacer_merma` | Baja/restaura cantidad o lotes sin campo de área. |
| `reparto_recibir`, `reparto_descontar_bodega`, `reparto_deshacer` | Entrada destino y salida origen no siempre son el mismo paso; posible doble recepción si se añade otra ruta sin idempotencia y origen/destino explícitos. |
| Fudo: `fudo_procesar_item`, `descontar_lotes`, `descontar_con_reposicion` | Consume desde producto/sede; la ruta por lotes delega el total al trigger. |
| `fusionar_productos` / `deshacer_fusion` | Reasigna/consolida stock y debe conservar historial e identidad. |
| `restaurar_sede` / `deshacer_restauracion` | Restaura snapshots de producto/sede; necesitará una regla de corte, no debe sobreescribir asignación por área silenciosamente. |
| `franquicia_linea_lista` | Aumenta o altera el saldo de Bodega desde el flujo de franquicia/lista. |
| Lama `lama_stock_aplicar_evento` | En modo real llama los escritores existentes por producto/lote. Configuración vacía hoy; cualquier transición debe incluirlo. |
| Lecturas de reportes, críticos, filtros, exportaciones y snapshots | Leen directamente `productos.stock_actual`, mínimos/máximos y sede; pueden duplicar conteos si además se suman áreas sin una proyección definida. |
| Funciones de reposición/ajuste y flujos auxiliares | `descontar_con_reposicion`, `urgente_solo_si_falta`, `tomar_foto_inventario` y procesos de restauración tienen que clasificarse como escritor, trigger, lectura o snapshot al preparar el corte. |

**Riesgo principal de doble escritura:** si un escritor cambia lotes y después actualiza `productos.stock_actual`, el trigger ya habrá recalculado el agregado. Si se crea una tabla por área y siguen activos tanto ese camino como la nueva tabla, habrá dos cantidades editables. Un traslado de Bodega puede duplicarse si la recepción en un área suma y el flujo actual también recibe en el producto de sede.

## 5. Opciones arquitectónicas

| Opción | Ventaja | Riesgo / conclusión |
|---|---|---|
| Mantener `productos.stock_actual` como saldo por producto/sede y crear saldo editable de área a su lado | Cambio inicial simple | Rechazada: dos verdades, operaciones ambiguas y sumas duplicables. |
| Duplicar filas de producto para cada área | Reutiliza UI y campos actuales | Rechazada: copia identidad, recetas, enlaces Fudo y conteos; no representa un producto compartido y no asegura transferencia. |
| Etiquetar un saldo actual con un área sin separación física contada | Fácil de mostrar | Rechazada como saldo confiable: el stock actual no indica cómo se distribuye físicamente entre áreas. |
| Una identidad canónica de producto con saldos/ledger por ubicación dentro de sede, lotes ligados a ubicación y vista de compatibilidad agregada | Preserva identidad y hace ubicación explícita; soporta Bodega y áreas | Recomendada para diseño. Requiere corte coordinado y mecanismo único de escritura antes de operar. No se fijan nombres de tabla/columnas en este bloque. |

### Recomendación de fuente única

Diseñar una única autoridad de cantidad para cada producto y ubicación: Bodega, área operativa o bucket temporal “Sin asignar”. Los movimientos deben ser idempotentes y registrar origen/destino, motivo, autor, fecha y lote. Una vista/proyección por producto y sede puede servir a lectores heredados durante una transición, pero no ser editable por separado. El proceso que cambia ubicación debe actualizar el saldo de salida y el de entrada de forma atómica.

Antes de seleccionar tablas/columnas, documentar identidad canónica, conversión del factor `producto_enlace`, unidades, reglas de lotes/vencimientos, reparto, operación cuando una de las dos puntas falla y estrategia para cada función instalada. No reutilizar `lama_areas`.

## 6. Conciliación y estrategia de corte

1. Elegir una hora de corte coordinada por sede y detener temporalmente todos los escritores relevantes durante la toma de snapshots.
2. Capturar por sede y `producto_id`: `stock_actual`, unidad, min/max, estado, enlaces y detalle de lotes/vencimiento. Guardar hashes/conteos y totales antes de migrar.
3. Para cada producto con lotes, contar el saldo de `stock_actual` una sola vez y conservar las cantidades de lote como desglose del mismo saldo.
4. Para Local 1, colocar toda existencia no contada físicamente en un bucket “Sin asignar”. La simulación de clasificación solo propone destinos; no reparte automáticamente el mismo saldo entre cuatro áreas. Asignaciones físicas requieren conteo o transferencias con auditoría y vencimiento preservado.
5. Mantener `central` como Bodega logística; no trasladar su saldo a Local 1 al crear áreas.
6. Mantener `angamos` y la clave histórica `bodega` separados y recuperables. Excluir Local 2 de la operación tras una fase aprobada, pero conservar cantidades/historial identificados; no mover stock ni borrar filas automáticamente.
7. Conciliar antes/después por producto e identidad/unidad: saldo previo = Bodega + suma de áreas + Sin asignar + saldos archivados que continúan contabilizados. Diferencias deben ser cero salvo ajustes explícitos, autorizados y auditados.
8. Activar un escritor único; bloquear escrituras a la proyección agregada o invertir la autoridad de forma atómica. Verificar que la transición no permita una ventana en que UI, lotes, Fudo, Lama, mermas o reparto mantengan saldos divergentes.

## 7. Repartos, Bodega y ubicaciones

La futura recepción debe seleccionar destino por línea: Bodega, sede o área válida de la sede receptora. La interfaz no puede inferirlo desde `repartos.origen`, porque ese texto no prueba cuál producto se descontó. Un traslado Bodega→área necesita asociar producto fuente/destino, factor/unidad, cantidades y lote/vencimiento, y escribir ambos lados como una sola operación idempotente. Debe conservar compatibilidad con repartos históricos que solo apuntan a producto/sede.

La clave activa de Bodega es `central`. La clave `bodega` se conserva como conjunto histórico separado y no se reutiliza. Local 2 se archiva por estado operativo/read-only en fase posterior, preservando datos y sin renumerar ni trasladar stock.

## 8. Mermas, críticos y recetas

- Mermas permanece como módulo global. Para una merma nueva iniciada dentro de un área, su evento debe indicar esa ubicación y descontar solo ese saldo. Las mermas históricas conservan área nula; no se atribuyen retroactivamente.
- Producto crítico se calcula por ubicación con su propio stock mínimo/máximo y su bandera manual, si aplica. Un producto puede ser crítico en Cafetería y suficiente en Cocina; el resumen global debe agrupar por producto/ubicación y evitar sumar “productos críticos” como cantidades.
- Área de elaboración de receta es metadato para nuevas recetas según el alcance aprobado; no cambia recetas existentes ni activa descuento de receta/Fudo/Lama.
- La clasificación hipotética debe ser una propuesta revisable con procedencia explícita. `rubro`, `tipo`, nombre y turno no son una asignación permanente.

## 9. Sedes futuras y clonación

La clonación debe crear una sede con IDs nuevos y copiar únicamente configuración aprobada (por ejemplo, áreas vacías, preferencias y plantillas explícitas). No copiar stock, lotes, vencimientos, movimientos, historiales, ventas, caja, cuentas, usuarios, enlaces de secretos Fudo/Toteat, cursores ni credenciales. Un nuevo sitio parte con saldo cero, vinculación de productos revisada y permisos propios. La operación debe ser transaccional e idempotente; no confundir `crear_producto_enlazado` con clonar una sede: hoy crea copias de catálogo enlazadas, no una configuración de local.

## 10. Permisos y riesgos

- Se observaron políticas RLS permisivas (`true`) en tablas operativas como productos, lotes, movimientos, enlaces, recetas y repartos. `app_permisos` no tiene permisos por sede/área. Por tanto, elegir Local 1 como prueba no constituye aislamiento técnico ni control de acceso.
- No habilitar datos sintéticos ni rutas por área hasta decidir límites de acceso, endurecimiento RLS/API y acciones permitidas por rol. Revisar además funciones `SECURITY DEFINER`, grants RPC y acceso directo a Supabase.
- Riesgos pendientes: escritores incompletos; doble escritura lotes/agregado; falta de área histórica; reparto de dos pasos; identidad duplicada entre sedes; conversión de unidades; lote sin ubicación; restauración de snapshots; filtros globales y reportes; acceso cruzado por RLS; automatización Fudo/Lama; residuos de Local 2 y clave antigua `bodega`.

## 11. Hechos, inferencias y discrepancias

### Hechos

Los hechos medidos se describen en secciones 2–4. No hay tablas de inventario por área o sede normalizada; el inventario actual está distribuido en filas de productos por sede. El detalle de lotes se deriva del producto. Las mermas son movimientos. La entidad de áreas de Lama es para mesas.

### Inferencias / recomendación

Una identidad canónica junto con ledger/saldo por ubicación parece la ruta que mejor evita duplicar catálogo y cantidades. Esto requiere diseño posterior; no es una afirmación de que tal tabla o migración ya exista. Un saldo agregado de compatibilidad podría existir como vista de lectura, sujeto a plan de retiro.

### Discrepancias documentales resueltas por el esquema/código

- Documentos anteriores proponían sede aislada de demostración; no se encontró tal entidad ni un contexto aislado. La instrucción actual elige Local 1 para el ensayo operativo, pero no cambia la limitación de seguridad.
- Los planes previos preguntaban si Bodega era sede independiente; el código mapea Bodega activa a `central`. La clave `bodega` es antigua y distinta.
- Los planes previos describían `lama_areas` como posible lugar por inspeccionar; esquema y FK `mesas.area_id` confirman que es del plano de mesas.
- El nombre “Bodega” en `repartos.origen` no acredita movimiento de stock: la línea y sus IDs fuente son los datos relevantes.

## 12. Consultas/verificaciones de solo lectura

Se usaron `git status`, `git remote -v`, `git branch --show-current`, `git log`, lecturas de documentación y `rg`/`sed` sobre el repositorio. En Supabase Llamita Plus se consultaron metadatos del proyecto, `list_tables` y consultas `SELECT`/`information_schema`/`pg_catalog` para:

1. Confirmar proyecto, ref y versión Postgres.
2. Enumerar tablas públicas y columnas de `sede`, ubicación, producto origen/destino y `area_id`.
3. Comprobar existencia/no existencia de tablas de áreas, sedes, mermas y lotes.
4. Contar productos, estados, stock agregado por sede y sedes presentes en tablas operativas.
5. Comparar por producto lotes frente a `stock_actual` sin sumar los dos saldos.
6. Contar enlaces y validar existencia/sede de productos en ambos extremos.
7. Contar movimientos por tipo y suma con signo.
8. Revisar Fudo por sede/modo/cron/última ejecución sin seleccionar secretos.
9. Revisar repartos por destino/origen/estado e items asociados.
10. Revisar políticas RLS y columnas de permisos.
11. Contar filas de Lama stock config/eventos/aplicaciones/capturas.
12. Revisar definiciones instaladas de las funciones relevantes mediante catálogo, en continuidad con auditorías previas; ninguna función fue invocada.

Todas fueron lecturas. No se consultó el proyecto de Café del Desierto / Llamita Stock.

## 13. Siguiente secuencia sugerida (sin activar)

1. Resolver fuente única, corte de escritores, modelo de identidad, permisos/RLS, inventario sin asignar y comportamiento de fallos de transferencia.
2. Convertir el diseño en una fase B1 de solo diseño/estructura con criterios y alcance de prueba definidos antes de tocar datos.
3. Solo con las decisiones cerradas y autorización concreta, especificar migración, snapshots, reconciliación y plan de reversa.
4. Activar luego la interfaz y operaciones por etapas. B2/B3 continúan inactivas.

Este cierre completa Bloque 0 documental. No activa B1 ni autoriza cambios de aplicación, esquema o datos.
