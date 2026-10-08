# B3.2a.2 — interfaz dinámica de áreas y preferencias

Fecha: 2026-10-08

Estado: **COMPLETADA**

Repositorio: `leoalejoleo1537/llamita-plus`

Supabase: `llamita-plus` (`iuryhsjucblmebdogewa`)

## Resultado

La experiencia de Local 1 ahora descubre las áreas operativas desde la base. Ya no existe una lista JavaScript de cuatro códigos. Una nueva área activa aparece en la portada y en los selectores sin editar el cliente, empieza con saldo cero y nunca toma cantidades de `productos.stock_actual`.

La interfaz distingue tres conceptos:

- área preferida: metadata operativa de `producto_area_asignacion`;
- ubicación física: ubicación real con saldo en el ledger;
- saldo físico: suma de `stock_internal.existencias` en esa ubicación.

Cambiar la preferencia no mueve unidades ni crea movimientos.

## Migraciones y RPC

Migraciones remotas aplicadas únicamente a Llamita Plus:

- `20261008210149 b3_2a_2_lectura_dinamica_areas`;
- `20261008210212 b3_2a_2_restaurar_execute_lector`.

La segunda restituyó el `EXECUTE` de `authenticated` sobre el helper privado que necesita la RPC invoker `stock_leer_areas`. El helper vive en `stock_internal`, fuera del esquema expuesto; no se concedió acceso a tablas ni a `anon`/`service_role`.

Se creó `producto_area_preferencia_leer(bigint,text)`: `SECURITY DEFINER`, `search_path=''`, nombres calificados, sesión autenticada obligatoria y `EXECUTE` solo para `authenticated`. Devuelve preferencia y saldos físicos por ubicación; no escribe.

La interfaz consume:

- `stock_leer_areas`;
- `areas_operativas_listar`;
- `area_operativa_crear`;
- `area_operativa_editar`;
- `area_operativa_archivar`;
- `producto_plaza_crear`;
- `producto_area_preferencia_leer`;
- `producto_area_preferencia_guardar`.

No se llama a `stock_transferir` desde la interfaz.

## Rutas y formularios

### Inventario de Local 1

La portada construye tarjetas para todas las áreas activas, Sin asignar y Todas las áreas. Las archivadas se excluyen. Las áreas nuevas aparecen con cero productos/unidades hasta que una transferencia real les dé saldo. La vista global sigue separando las cantidades por ubicación.

Cada área ofrece “Crear producto en esta área”; el formulario preselecciona la preferencia, permite cambiarla y avisa que el alta nace con saldo cero. Desde Todas las áreas o Ajustes se usa Sin asignar por defecto.

### Ajustes

“Áreas de inventario” aparece en `plaza` solo con `puede_ajustes`. Lista activas/archivadas y usa exclusivamente RPC para crear, editar y archivar. Explica saldo y preferencias: con saldo se bloquea; con preferencias solicita confirmación para pasarlas a Sin asignar. Sin asignar no se presenta como área administrable.

La sección Productos conserva Bodega/Enlaces para `central`; en `plaza`, “Crear producto” abre el alta segura local con `producto_plaza_crear`.

### Ficha de producto

La ficha de `plaza` muestra Área preferida y, por separado, Ubicación física actual con saldo real. Guardar la preferencia usa su RPC y mantiene los enlaces Fudo. El stock legacy continúa deshabilitado para `plaza`/`central`.

### Taller de recetas

Solo se cambió la creación auxiliar de ficha de producto en `plaza`: usa `producto_plaza_crear` con stock cero y Sin asignar. El paso posterior de receta permanece igual. No se modificaron Edge Functions, catálogo Fudo, recetas existentes ni producto enlazado/Bodega.

## Seguridad

Las tablas `areas_operativas`, `producto_area_asignacion` y `stock_internal.ubicaciones` continúan sin DML directo del navegador. Las operaciones de áreas vuelven a exigir `puede_ajustes`; productos/preferencias, `puede_editar`. El propietario raíz recibe capacidades efectivas S1 y el administrador operativo puede administrar áreas sin adquirir gobierno de usuarios. “Personas y acceso” sigue reservado al propietario raíz.

ACL verificada: las RPC B3.2a no son ejecutables por `PUBLIC`, `anon` ni `service_role`; `authenticated` puede invocarlas y cada función valida la sesión/capacidad en servidor. `stock_transferir` mantuvo firma y autorización.

## Pruebas

`sql/2026-10-b3-2a-2-pruebas-transaccionales.sql` pasó con `BEGIN ... ROLLBACK`:

- crear Heladería y verla dinámicamente con cero;
- renombrarla y reflejar el nombre;
- crear producto con preferencia y sin existencias/lotes/movimientos;
- cambiar la preferencia a Sin asignar sin mover stock;
- archivar el área y excluirla de la lectura operativa;
- propietario raíz y administrador operativo;
- rechazo anónimo;
- conteos contables invariables.

La primera ejecución descubrió que el wrapper invoker había perdido el grant para delegar en el helper. Falló antes de persistir y el `ROLLBACK` eliminó toda fila sintética. Tras la corrección mínima, la suite pasó.

También pasaron:

- `npm test`;
- prueba estática específica `pruebas/b3-2a-2-interfaz-areas.mjs`;
- parseo de todos los scripts de `index.html`;
- revisión de permisos y `search_path`;
- advisors de seguridad/rendimiento;
- `git diff --check`.

No había Chromium instalado, por lo que las suites visuales se omitieron automáticamente.

## Procedimiento manual visual

1. Entrar como propietario raíz u operador con `puede_ajustes` y abrir Local 1.
2. En Ajustes → Áreas de inventario, crear “Heladería”; comprobar escritorio y ancho móvil, error de duplicado, renombre y orden.
3. Volver a Inventario y confirmar tarjeta automática con saldo cero, sin scroll horizontal.
4. Desde Heladería y Cafetería, abrir “Crear producto en esta área”; comprobar preselección, cambio a Sin asignar y texto de saldo cero.
5. Abrir una ficha de producto; contrastar Área preferida con Ubicación física actual y verificar que cambiar la primera no altera la segunda.
6. Archivar Heladería vacía; si tiene preferencias, confirmar la reasignación; verificar que desaparece de Inventario y queda en historial de Ajustes.
7. Abrir Bodega y comprobar su lista/Enlaces sin portada de áreas.
8. Revisar consola: no deben existir errores ni llamadas a Edge Functions Fudo/Lama.

## Conteos pre/post

| Objeto | Antes | Después |
|---|---:|---:|
| Productos | 1.437 | 1.437 |
| Proyección global `productos.stock_actual` | 15.438,00 | 15.438,00 |
| Ledger migrado (`central` + `plaza`) | 9.316,70 | 9.316,70 |
| Lotes | 42 | 42 |
| Movimientos legacy | 431 | 431 |
| Movimientos ledger | 408 | 408 |
| Transferencias persistentes | 0 | 0 |
| Recetas | 396 | 396 |
| Movimientos Fudo | 15.357 | 15.357 |
| Eventos Lama | 0 | 0 |
| Áreas persistentes | 4 | 4 |
| Preferencias persistentes | 0 | 0 |

No quedaron productos ni áreas sintéticas.

## Rollback y riesgos pendientes

El rollback está en `sql/2026-10-b3-2a-2-lectura-dinamica-areas.rollback.sql`: elimina la RPC de lectura individual y restaura la lectura B3.1 de las cuatro áreas fundacionales. No borra áreas, preferencias ni productos reales.

Riesgos pendientes para B3.2a.3/B3.2b:

1. Los productos ya existentes continúan Sin asignar hasta una decisión explícita; no hubo clasificación automática.
2. No existen transferencias visuales, mínimos por área ni críticos por área.
3. Las rutas enlazadas Bodega/Fudo conservan su comportamiento deliberadamente; cualquier convergencia futura requiere un bloque propio.
4. Los advisors mantienen hallazgos heredados globales fuera de B3.2a.2; no aparecieron grants anónimos ni `search_path` inseguro atribuibles a la RPC nueva.

No se modificaron Fudo remoto, Lama, caja, Bodega, lotes, recetas, ledger, transferencias ni Café del Desierto / Llamita Stock.
