# Modo demostración

El interruptor vive en **Ajustes → Interruptores** y guarda la clave
`modo_demostracion` en `public.ajustes` con `sede=''`. Es **global**: se aplica
igual en Plaza, Angamos y Bodega. La tabla existente admite `clave`, `sede` y
`valor` booleano; no hace falta SQL nuevo. Si no hay fila, el valor de fábrica
es apagado. Al encender o apagar se cambia solo esa fila de configuración.

Encendido, la app abre en Inicio · Inventario. Siguen a la vista productos,
repartos y traslados de stock, Mermas, Historial y los Ajustes de inventario.
Se esconden Mesas, Arqueo, Movimientos de caja, Recetas y Enlaces, junto con
las secciones de Ajustes ligadas a ventas, Fudo e impresión. El cambio de
vista pasa por `pickTab`: un intento de abrir una vista oculta vuelve a
Inventario. Esta es una preferencia de presentación; `app_permisos` y las
políticas de la base no cambian. Apagado, se recupera la navegación anterior.

## Mermas: diagnóstico para reportes futuros

La aplicación registra mermas con `mermar(...)` en `public.movimientos`, con
`tipo='merma'` y `cantidad` negativa. La ficha de producto ofrece el gesto de
mermar y la pestaña Mermas lee ese mismo libro. `deshacer_merma(...)` marca la
fila como deshecha y repone stock; no elimina el registro.

Según el DDL del repositorio, cada movimiento tiene `id`, `sede`,
`producto_id`, `producto` (nombre guardado en ese momento), `tipo`, `cantidad`,
`sede_contraparte`, `motivo`, `reparto_item_id`, `quien` y `created_at`. La
migración de mermas agrega `nota`, `detalle` JSONB (lotes y fechas),
`deshecha_at` y `deshecha_por`. La causa se guarda en `motivo` con las opciones
`daño`, `robo`, `vencimiento` y `otro`; para «otro» se guarda texto en `nota`.
La categoría **no se guarda** en el movimiento: se puede consultar el `rubro`
actual del producto por `producto_id`, pero no reconstruir con seguridad su
categoría histórica. El turno tampoco se guarda; `created_at` permite agrupar
por hora local si se define formalmente el horario de cada turno. El usuario
queda como texto en `quien`, no como ID estable de Auth.

No hay costo unitario ni valor monetario congelado en el movimiento, por lo
que no se pueden calcular pérdidas monetarias históricas confiables. Para un
reporte futuro habría que decidir y guardar el costo unitario aplicado en
cada merma, la moneda, la categoría histórica, el turno o sus límites por
sede y un identificador estable del usuario. También habría que definir el
tratamiento de mermas deshechas y el costo de productos con varios lotes.
Nada de eso se agrega con este modo.

Este diagnóstico describe el código y el DDL versionados; no comprueba el
esquema ni los datos de la base en línea.
