# B3.2a.3 — Depuración de áreas y productos existentes

Fecha: 2026-10-09  
Estado: **COMPLETADA**  
Entorno exclusivo: `leoalejoleo1537/llamita-plus`; Supabase Llamita Plus `iuryhsjucblmebdogewa`.

## Resultado

La creación de áreas ya existía y su RPC funcionaba. El problema real era de encontrabilidad: la acción estaba únicamente en la subsección interna `Ajustes → Áreas de inventario`, condicionada a `plaza` y `puede_ajustes`; Inventario no ofrecía acceso y en móvil había que descubrir primero el riel interno de Ajustes. Se conservó una sola implementación y se agregó desde la portada de Inventario el enlace secundario **Gestionar áreas**, que abre esa misma subsección. Allí las acciones se presentan como **Nueva área** y **Crear área**.

Las tarjetas de áreas y el detalle de área separan ahora dos operaciones:

- **Agregar producto existente** busca la ficha maestra y guarda solo su preferencia con `producto_area_preferencia_guardar`.
- **Crear producto nuevo** conserva `producto_plaza_crear`, crea la ficha con saldo cero y permite elegir una de las áreas activas o Sin asignar.

Si el alta detecta un nombre coincidente, no crea una copia artificial: abre el producto encontrado y ofrece **Usar producto existente**. La búsqueda admite nombre, ID interno, rubro o tipo. El esquema real no tiene una columna de código de producto; por eso se presenta el `id` como identificador interno, sin inventar otro campo.

Antes de confirmar una preferencia se muestran por separado el área preferida actual y las ubicaciones/saldos reales recibidos por la lectura protegida. La confirmación aclara que las existencias no se movieron. No se agregó ningún botón de transferencia ni una ruta incompleta hacia B3.2b.

## Modelo visible

- **Sede:** nodo operativo; `plaza` es Local 1.
- **Bodega:** `central` conserva su flujo logístico y no es un área de Local 1.
- **Área operativa:** ubicación física vinculada al ledger, por ejemplo Heladería o Cafetería.
- **Área preferida:** metadata que organiza normalmente una ficha; no contiene ni mueve unidades.
- **Ubicación física:** fila o agregado real del ledger donde están las unidades.
- **Sección interna:** posible subdivisión futura; no se creó tabla, jerarquía ni ubicación para ella.
- **Categoría/rubro/tipo:** clasificación descriptiva. Limpieza, Vitrina y Sándwiches se conservan donde el modelo legado los usa, pero no aparecen como destinos de inventario.

## RPC y datos

Se reutilizaron exclusivamente las RPC protegidas instaladas en B3.2a.1/B3.2a.2:

- `areas_operativas_listar`
- `area_operativa_crear`
- `area_operativa_editar`
- `area_operativa_archivar`
- `producto_area_preferencia_leer`
- `producto_area_preferencia_guardar`
- `producto_plaza_crear`
- `stock_leer_areas`

No se creó ni aplicó migración. No hubo DML directo desde el navegador. Las funciones conservaron firma, ACL, validación de sesión y permisos; `stock_transferir` conserva su firma instalada y no se invoca desde este flujo.

## Archivos

- `index.html`: acceso a gestión, modal de búsqueda/asignación, recuperación de duplicado, etiquetas separadas de sección/categoría y área, confirmaciones y comportamiento responsive.
- `pruebas/b3-2a-3-asignacion-existente.mjs`: contrato estático del flujo.
- `pruebas/b3-2a-3-flujo-browser.mjs`: recorrido responsive con Supabase simulado y control de llamadas.
- `sql/2026-10-b3-2a-3-pruebas-transaccionales.sql`: prueba real de RPC y permisos dentro de `BEGIN … ROLLBACK`.
- documentación Hermes: cola, plan, bitácora, canal y este informe.

## Verificación

La prueba transaccional real cubrió, con rollback, creación de área y ubicación vinculada, asignación temporal de `Helado de vainilla` a Heladería, producto nuevo con saldo cero, roles raíz/operativo/común y continuidad de la firma de `stock_transferir`. No quedaron el área, producto ni preferencias sintéticas.

La prueba de navegador en Chromium cubrió 390 px y 1280 px: gestión visible para raíz y administrador operativo, oculta a usuario común; alta/renombre/archivo simulados; búsqueda y asignación de ficha existente; recuperación de duplicado; producto realmente nuevo; selector limitado a áreas activas/Sin asignar; escritorio conservado; sin scroll horizontal ni errores de consola. También pasó la regresión M1.

Pasaron:

- `npm test`
- `CHROME_PATH=… node pruebas/b3-2a-3-flujo-browser.mjs`
- `CHROME_PATH=… node pruebas/movil-navegacion.mjs`
- prueba SQL `BEGIN … ROLLBACK`
- revisión de ACL, definiciones y advisors de Supabase
- `git diff --check`

Los advisors conservan hallazgos globales heredados —funciones antiguas ejecutables por anon, vistas definer, funciones antiguas con `search_path` mutable, índices sin uso y políticas permisivas ajenas—; este bloque no creó objetos de base ni añadió findings.

## Conciliación

Los conteos anteriores y posteriores fueron idénticos:

| Control | Antes | Después |
|---|---:|---:|
| Productos | 1.437 | 1.437 |
| Productos `plaza` | 329 | 329 |
| Stock global | 15.438,00 | 15.438,00 |
| Áreas activas `plaza` | 5 | 5 |
| Preferencias persistentes | 0 | 0 |
| Lotes | 42 | 42 |
| Movimientos legacy | 431 | 431 |
| Movimientos ledger | 408 | 408 |
| Transferencias | 0 | 0 |
| Recetas | 396 | 396 |
| Enlaces de producto | 513 | 513 |
| Movimientos Fudo | 15.357 | 15.357 |
| Eventos Lama–Stock | 0 | 0 |

Heladería persistió como el área real preexistente; los sintéticos terminaron en cero. No cambiaron `productos.stock_actual`, existencias, lotes, movimientos, recetas, enlaces ni datos comerciales.

## Compatibilidad y riesgos

No se modificaron ni invocaron Edge Functions o servicios remotos Fudo. Lama real continúa apagado. Bodega, caja, recetas, mermas, lotes y el motor `stock_transferir` quedaron intactos. No se accedió a Café del Desierto / Llamita Stock.

B3.2b permanece pendiente: deberá mover unidades mediante `stock_transferir`, resolver selección de lote y continuidad entre productos enlazados, generar una referencia idempotente, mostrar errores de saldo y no confundir esa transferencia con la preferencia ya implementada. Tampoco existe aún un modelo de secciones internas; cualquier conversión de clasificaciones heredadas exige un plan separado.

