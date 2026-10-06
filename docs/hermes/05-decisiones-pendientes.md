# Decisiones pendientes

Este registro reúne decisiones que deben resolverse antes de activar fases de implementación.

## Decisiones registradas para A2 — 2026-10-06

Estas decisiones orientan el diseño; no autorizan aún una migración ni cambios de código.

- **Caja no es inventario:** pagos, propinas, cobros parciales y cierre de caja de Lama no disparan descuentos. El consumo debe originarse en un evento operativo de la venta.
- **Origen POS único por sede:** una sede opera con Fudo, Lama o Toteat a la vez. Aun así, cada origen necesita deduplicar sus propios reintentos, sincronizaciones repetidas y anulaciones.
- **Identidad canónica propia:** Llamita necesita una identidad propia para cada producto vendible. Los identificadores Fudo/Toteat serán enlaces de adaptador, no la identidad permanente del núcleo.
- **Receta histórica:** cada consumo aplicado debe conservar la versión o instantánea de la receta que se utilizó, para que editar una receta mañana no reescriba una venta pasada.
- **Precio separado del stock:** el precio pertenece al catálogo/venta y cada línea debe guardar la instantánea del precio cobrado. No se debe inferir desde el stock ni desde una receta.

### Decisiones que A2 debe dejar preparadas para aprobación

1. Momento de consumo Lama: confirmar comanda, envío a preparación, entrega u otro estado operativo.
2. Regla de reversa para una anulación antes y después de la preparación/consumo.
3. Tratamiento de consumos internos, cortesías y mermas operativas.
4. Forma concreta de identidad canónica y enlaces Fudo/Toteat sin romper recetas existentes.
5. Estrategia de receta histórica: versión numerada, instantánea JSON o combinación.
6. Secuencia de transición desde `productos.stock_actual` hacia stock por producto-área sin dos saldos editables.

## Resueltos para B1

- El plan de áreas está aprobado para iniciar el Bloque 1; la cola lo autoriza.
- Las ventanas vigentes de esta ejecución son las indicadas directamente por Alejo: 00:00, 02:00 y 05:00 hora de Santiago. La cola mantiene una sola tarea activa y Codex no activa el bloque siguiente.
- B1 puede hacer push a `master` únicamente al terminar verificado. Esto no activa ni autoriza publicaciones de B2/B3.

## Decisiones requeridas antes de migrar o crear datos

### 1. Contexto aislado para datos de prueba

La conexión configurada en el repositorio y la consulta de proyecto confirman que el Supabase configurado para la app es `llamita-plus` (`iuryhsjucblmebdogewa`). En el esquema `public` que usa la app no hay una sede demo ni una tabla separada de demostración; la búsqueda de ramas de desarrollo no encontró ramas. El ajuste `modo_demostracion` existe con `sede=''` y `valor=true`, pero solo oculta o muestra pantallas: comparte los mismos datos.

Las claves actuales son `plaza`, `angamos`, `central` y `bodega`. Todas tienen productos, stock o historial; `central` está poblada, y `bodega` es la clave histórica que las reglas de `CLAUDE.md` prohíben reutilizar. Por eso no es seguro clasificar ni crear filas de áreas en una sede existente.

Además, las tablas existentes usan políticas RLS permisivas (`true`) para `anon`/`authenticated`; `app_permisos` tiene flags globales y no permisos por sede/área. Una sede nueva en el mismo esquema no sería un límite de seguridad de base de datos. Sus lectores, reportes y permisos de app tendrían que revisarse antes de usarla como laboratorio.

**Propuesta:** decidir primero un espacio identificable y aislado para áreas de prueba. Opción de menor alcance dentro del proyecto existente: autorizar una sede exclusivamente de laboratorio, con clave nueva como `areas-demo`, con productos sintéticos o catálogo curado y stock inicial cero; antes de crearla habrá que revisar todos los lectores globales para evitar que aparezca en reportes o pantallas operativas. Alternativa: un proyecto Supabase de desarrollo de Llamita Plus con esquema restaurado y datos sintéticos. No crear ninguno hasta que Alejo elija y autorice el contexto.

### 2. Corte de fuente única de stock

El esquema instalado guarda `productos.stock_actual`, `stock_min` y `stock_max` en cada producto/sede. La app edita esos campos directamente; las RPC y el flujo de ventas también escriben stock; `producto_lotes` lo recalcula con `sync_stock_desde_lotes`. Movimientos, mermas, repartos, fotos de historial y recetas se relacionan con `producto_id`/`sede`, sin área. Las áreas de `lama_areas` pertenecen al plano de mesas y no son áreas de inventario.

**Propuesta técnica:** que el futuro stock por producto-área sea la única cantidad editable, y que `productos.stock_actual` sea solo una suma de compatibilidad, nunca una segunda cantidad independiente. El stock actual sin clasificación quedaría en `Sin asignar`; el historial conservaría `area_id` nulo y no se atribuiría retroactivamente. Para que esa regla sea cierta, el corte debe adaptar en conjunto todos los escritores: edición de stock, lotes y su trigger, ventas/Fudo, entradas, mermas, recepción/deshacer de reparto, restauraciones, fusiones y fotos/reportes. La inspección confirma que no es seguro activar la nueva cantidad mientras esos caminos sigan escribiendo a nivel de producto.

**Decisión solicitada:** autorizar que se reprograme el corte de datos y operaciones como una fase coordinada antes de habilitar stock independiente por área, o mantener B1 solo como análisis/preparación y aplazar esa fuente única hasta que se apruebe y ejecute el corte integral. No aplicar la migración aditiva ni cargar clasificación hasta resolverlo.

## Resultado de inspección — 2026-10-06

- B1 queda en `REQUIERE DECISIÓN`; no hay cambios de código, migraciones ni datos.
- Supabase comprobado por metadatos: `llamita-plus`, ref `iuryhsjucblmebdogewa`, PostgreSQL 17.6; la app usa el mismo host.
- No se deben resolver implícitamente las decisiones pendientes durante una ejecución de Codex.

### Mapa de dependencias confirmado

- `productos` tiene una fila por producto/sede con PK `id`; incluye `sede`, `stock_actual`, `stock_min`, `stock_max`, `rubro`, `tipo`, `unidad`, `perecedero` y `activo`. No hay una entidad maestra global de inventario. `producto_enlace` conecta el producto de `central` con copias por sede; `secciones` define rubros/orden por sede.
- `lama_areas` pertenece a las áreas del plano de mesas (`mesas.area_id`); no es modelo de inventario y no debe reutilizarse. La app define las sedes admitidas en `SEDES`: `plaza`, `angamos` y `central`; `bodega` es histórica.
- `movimientos` registra entradas, salidas, ajustes y mermas por sede/producto, sin área. Las mermas usan `tipo='merma'`. `producto_lotes` solo lleva `producto_id`; `trg_sync_stock_lotes` recalcula `productos.stock_actual` desde sus cantidades.
- `repartos` lleva sede destino y `reparto_items` producto destino/origen/bodega, sin área. `reparto_recibir`, `reparto_descontar_bodega` y `reparto_deshacer` afectan el stock de producto.
- `historial` y `historial_auto` guardan foto por sede/producto sin área; esos registros deben conservar el área nula y no se deben asignar retroactivamente por nombre. Las recetas son por sede (`recetas`) y ligan insumos a `productos.id` (`receta_items`); el área de elaboración debe ser metadato futuro, sin descuento automático.
- La app actualiza stock directamente mediante `saveFields()` desde edición rápida/ficha y escribe lotes desde `guardarLotes()`. Las rutinas activas que contienen referencias a `productos.stock_actual` son `crear_producto_enlazado`, `descontar_con_reposicion`, `deshacer_entrada`, `deshacer_fusion`, `deshacer_merma`, `deshacer_restauracion`, `franquicia_linea_lista`, `fudo_stock_calculado`, `fusionar_productos`, `mermar`, `registrar_entrada`, `reparto_descontar_bodega`, `reparto_deshacer`, `reparto_recibir`, `restaurar_sede`, `sync_stock_desde_lotes`, `tomar_foto_inventario` y `urgente_solo_si_falta`. Además, `fudo_procesar_item` descuenta por `descontar_lotes` (que activa el trigger de lotes) o `descontar_con_reposicion` según lotes/modo. Los conteos y reportes leen `stock_actual` directamente.
