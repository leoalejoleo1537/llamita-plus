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

## Mermas: analítica e historial

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
La categoría **no se guarda** en el movimiento: la pantalla consulta el `tipo`
actual del producto por `producto_id`, pero no reconstruye con seguridad su
categoría histórica. El turno tampoco se guarda; `created_at` permite agrupar
por hora local si se define formalmente el horario de cada turno. El usuario
queda como texto en `quien`, no como ID estable de Auth.

No hay costo unitario ni valor monetario congelado en el movimiento, por lo
que no se pueden calcular pérdidas monetarias históricas confiables. Para un
reporte futuro habría que decidir y guardar el costo unitario aplicado en
cada merma, la moneda, la categoría histórica, el turno o sus límites por
sede y un identificador estable del usuario. También habría que definir el
tratamiento de mermas deshechas y el costo de productos con varios lotes.
Nada de eso se agrega con este modo. Los gráficos muestran unidades y no dinero.

La pantalla ofrece períodos de 7, 30 y 90 días, mes actual, rango personalizado
y todo el historial. Usa `created_at` en hora local de Chile. Los registros se
leen en páginas de 1.000 para evitar el límite silencioso de la API; la tabla
visible muestra 100 registros por página. Los gráficos excluyen mermas
deshechas y agregan por motivo y tipo actual.

Cuando el período y la sede no tienen registros, la vista muestra una muestra
local sintética —Torta Matilda, Sándwich Pollo Palta, Jugos, bollería, bebidas
envasadas y pizza— con motivos verosímiles. Lleva una etiqueta visible de
“Datos ficticios de demostración”, no se inserta en Supabase, no modifica stock
y su exportación declara su origen. No se presenta como historial real. Cuando
hay al menos una merma real para la sede y el filtro seleccionado, se oculta la
muestra completa.

La rutina de limpieza versionada conserva indefinidamente los movimientos con
`tipo='merma'`; los demás movimientos mantienen la retención de 30 días. Esto
protege el historial si esa rutina se instala más adelante. La interfaz ya no
aplica el límite de 500 registros.

El repositorio apunta exclusivamente al proyecto Supabase `llamita-plus`
(`iuryhsjucblmebdogewa`). No se insertaron ni modificaron datos en la base para
esta mejora.
