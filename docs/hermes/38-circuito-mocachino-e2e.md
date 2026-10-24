# Corrección del circuito Mocachino E2E

Fecha: 2026-10-23. Estado: **IMPLEMENTADA CON LÍMITE DOCUMENTADO**.

## Resultado

- Mesas vuelve a la barra móvil de Local 1 y conserva el guard `puede_lama`.
- Todo `input[type=number]` enfocado ignora rueda/trackpad; teclado y botones siguen activos.
- El costo del Panel es siempre editable y `costo_pendiente` se deriva de costo cero.
- Panel, alta desde Bodega y ficha permiten crear una sección en contexto con `puede_editar` y seleccionarla sin recargar.
- La ficha de área usa un solo `Guardar cambios`: configuración y conteo opcional se confirman mediante `producto_area_ficha_guardar`; el conteo delega en `stock_ajuste_guardar` y nunca escribe `productos.stock_actual`.
- Los repartos nuevos derivan en servidor la configuración y sección activas, guardan su instantánea y muestran `Área → Sección`. Una sección con repartos abiertos no puede archivarse.
- Recetas siguen aceptando solo configuraciones válidas; el editor muestra aparte productos con saldo pendientes de configuración y su motivo.
- AM/PM fue retirado del esquema, RPC y experiencia funcional. Sus valores previos quedaron respaldados en `stock_internal.turnos_secciones_respaldo_20261023` para una reversa exacta.

## Migraciones y RPC

- `20261023152940_circuito_mocachino_e2e.sql`
- `20261023204230_circuito_mocachino_firmas.sql`
- `20261023204300_circuito_mocachino_actor_secciones.sql`
- `20261023204333_circuito_mocachino_indices.sql`
- `20261023204812_eliminar_turnos_secciones.sql`
- `20261023204914_exigir_seccion_configuracion.sql`
- RPC nuevas: `producto_area_ficha_guardar`, `reparto_area_rutas_listar`, `panel_ingredientes_pendientes_listar`.
- Firma operativa de `area_seccion_crear` sin turno; edición sin turno.

## Pruebas y datos

- `npm test`: aprobado.
- Chromium real: aprobado en 390×844, 667×375 y 1280×800; Mesas se abrió pulsando el acceso móvil visible, se verificaron permisos, barra estable, Panel en móvil/escritorio y ausencia de errores JavaScript.
- SQL transaccional `sql/2026-10-circuito-mocachino-pruebas.sql`: aprobado con `ROLLBACK`; idempotencia, rechazo de referencia distinta y creación de sección.
- E2E transaccional P4 repetido después de las migraciones: receta manual simple y multiárea, reserva, consumo, reversa, atomicidad y permisos aprobados; terminó en `ROLLBACK`.
- `git diff --check`: aprobado.
- Pre/post idénticos: 1.438 productos; ledger 9.337,7; 42 lotes; 424 movimientos ledger; 5 repartos de área; 396 recetas; 15.357 movimientos Fudo. Cero filas `ZZ_MOCACHINO_E2E` y cero operaciones de ficha persistentes.
- Advisors: las RPC nuevas usan `SECURITY DEFINER`, `search_path=''`, ACL solo `authenticated`; RLS sin políticas en la tabla interna es intencional. Se añadieron índices de sus FKs. Persisten hallazgos históricos ajenos al bloque.

## Riesgo pendiente

El respaldo versionado de AM/PM es deliberado y no participa en ninguna lectura funcional. Debe conservarse hasta confirmar el recorrido manual del local y solo después decidir su retención histórica.

No se invocó ni modificó Fudo, Café del Desierto/Llamita Stock, caja, pagos o recetas heredadas. La prueba comercial Mocachino real debe ejecutarse manualmente después de configurar los insumos reales; esta publicación no movió stock real.
