# B2.4 — Motor seguro de transferencias entre ubicaciones

**Estado:** COMPLETADA — 2026-10-07.
**Siguiente bloque:** B3, interfaz por áreas, permanece **PENDIENTE** y no se activa automáticamente.
**Repositorio:** `leoalejoleo1537/llamita-plus`.
**Supabase:** proyecto Llamita Plus, ref `iuryhsjucblmebdogewa`.

## Alcance realizado

Se implementó el motor transaccional para estas rutas:

1. Bodega central (`central`) → Cocina fría, Cocina caliente, Barra o Cafetería (`plaza`), solo con un enlace explícito de `public.producto_enlace` y factor 1.
2. Sin asignar de Local 1 → una de sus áreas activas.
3. Un área activa de Local 1 → otra área activa, conservando el mismo producto.

No se habilitan destinos Sin asignar, ni `angamos`, ni la clave histórica `bodega`. No se infieren equivalencias por nombre. Las áreas no recibieron saldos permanentes; todas las operaciones de prueba se revirtieron.

## Modelo y funciones

- `stock_internal.transferencias` guarda referencia idempotente, actor autenticado, motivo, fecha y vínculo `reversa_de`.
- `stock_internal.movimientos` recibe un movimiento negativo de salida y uno positivo de entrada, ligados al mismo encabezado y referencia. Las claves de cada lado son únicas.
- Un constraint trigger diferido verifica al confirmar que el par esté completo y balanceado, con origen/destino, productos, lote, usuario y motivo consistentes. Cualquier excepción revierte la salida y la entrada juntas.
- `public.stock_transferir(...)` es la entrada RPC `SECURITY INVOKER`, con `EXECUTE` para `authenticated`. Valida `auth.uid()`, role/email del JWT y que el correo coincida con un registro autorizado en `public.app_permisos` con `puede_editar=true`.
- El helper del esquema privado repite la validación antes de llamar al núcleo. El núcleo es `SECURITY DEFINER` y queda ejecutable solo por el propietario; los roles API no obtienen DML sobre tablas internas. `anon` y `service_role` no reciben ejecución del RPC ni uso del esquema interno.
- Una referencia repetida con el mismo payload y actor devuelve el resultado existente. Reutilizarla con datos distintos se rechaza. Locks transaccionales serializan llamadas que compiten por referencia y saldo.
- Se valida saldo por producto, ubicación y lote antes de insertar. No se permite cantidad cero/negativa ni saldo final negativo.

## Productos enlazados y lotes

En la ruta entre sedes, el motor requiere el enlace real Bodega–plaza en `public.producto_enlace`, con factor 1. No crea ni modifica enlaces; un producto sin enlace queda bloqueado.

Se inspeccionó la estructura instalada de `public.producto_lotes` y su relación con el libro. La tabla heredada identifica un lote bajo el producto de origen, mientras el producto enlazado de Local 1 puede tener otro ID. Para conservar identidad sin fabricar una segunda identidad física, `stock_internal.lote_continuidad` liga el `producto_lotes.id` canónico con el producto de destino, su vencimiento y la transferencia. No se inserta un lote ficticio en `producto_lotes`.

Si el saldo inicial del libro contiene cantidad en el bucket sin lote, el motor puede clasificar la cantidad respaldada por el lote legado: primero comprueba que `producto_lotes.cantidad` no exceda el saldo agregado sin lote y lo registra como movimientos opuestos de clasificación, en la misma transacción de transferencia. Si el respaldo no concilia, la operación falla y no cambia el libro. Las transferencias internas de Local 1 conservan el mismo ID de lote.

## Permisos y seguridad

Las tablas internas conservan RLS y no otorgan mutación directa a `anon`, `authenticated` ni `service_role`. La UI futura deberá invocar únicamente el RPC público, sin escribir tablas. Hoy el usuario requiere el permiso existente `app_permisos.puede_editar`; no se creó un permiso adicional ni una interfaz. Los helpers internos no son una API de reproceso o transferencia abierta.

La función pública es `SECURITY INVOKER` y verifica JWT/permiso. Su uso de helpers internos limitados no cambia la política de datos: el helper vuelve a comprobar la identidad, y el núcleo solo es invocable por el dueño de la función. El modo real de Lama sigue apagado; no hay escrituras de Fudo habilitadas.

## Migraciones aplicadas

Versiones confirmadas con la lista de migraciones del proyecto:

| Versión | Nombre | Archivo fuente |
|---|---|---|
| `20261007165310` | `b2_4_transferencias_ubicaciones_seguras` | `supabase/migrations/20261007164746_b2_4_transferencias_ubicaciones_seguras.sql` |
| `20261007165656` | `b2_4_index_lote_continuidad_transferencia` | `supabase/migrations/20261007165621_b2_4_index_lote_continuidad_transferencia.sql` |
| `20261007165826` | `b2_4_secure_transfer_entrypoint` | `supabase/migrations/20261007165808_b2_4_secure_transfer_entrypoint.sql` |

Los tiempos locales de los archivos son distintos a los IDs que Supabase registró al aplicar las migraciones. La documentación usa los IDs remotos confirmados.

## Pruebas y conteos

`sql/2026-10-b2-4-pruebas-transferencias.sql` ejecuta una sola transacción con `BEGIN ... ROLLBACK`. Se validó:

- Bodega→Cafetería con enlace real de producto.
- Sin asignar→Barra y luego Barra→Cafetería.
- Transferencia con lote y vencimiento conservados, y transferencia sin lote.
- Stock insuficiente rechazado.
- Producto sin enlace rechazado.
- Doble llamada con referencia/payload idénticos sin duplicación.
- Excepción forzada después de la salida y antes de la entrada: sin transferencia ni salida huérfana al revertirse el intento.
- Denegación de usuario sin permiso y ejecución válida simulando el rol `authenticated`.
- ACL, RLS, par diferido, no negatividad, total del libro y suma global proyectada.
- Fudo remoto no se llamó. Lama real continúa apagado.

Resultado de conteos al finalizar la transacción revertida: productos `1.437`; suma global de `productos.stock_actual` `15.438,00`; lotes `42`; neto del libro `9.316,70`; transferencias persistentes `0`; continuidades nuevas `0`; clasificaciones persistentes `0`; movimientos de transferencia persistentes `0`; `fudo_movimientos` `15.357`; movimientos legacy `431`; configuraciones Lama en modo real `0`.

La función no actualiza `productos.stock_actual` directamente. El trigger existente proyecta los movimientos del libro. Cuando el enlace cruza IDs maestros distintos, la proyección individual del producto origen disminuye y la del producto destino aumenta; la suma global permanece idéntica. Por ello el resultado confirma que no hubo cambio en el total físico, no que cada fila de proyección individual quedara intacta.

## Reversa y rollback

El rollback técnico está en `sql/2026-10-b2-4-transferencias-ubicaciones.rollback.sql`. Aborta antes de alterar el esquema si detecta encabezados con datos B2.4, continuidad de lotes o clasificación persistida. Solo se debe ejecutar antes de operaciones posteriores.

Si ya existen transferencias reales, no se eliminan movimientos. Se requiere crear una transferencia compensatoria, enlazada mediante `reversa_de`, conservando auditoría. El campo está preparado, pero la interfaz/API de reversa no forma parte de B2.4.

## Riesgos y pendientes

- Entradas, ajustes, mermas, repartos legacy y consumo de recetas siguen bloqueados para las sedes migradas hasta adaptarse al libro.
- La transferencia todavía no tiene interfaz. Usuarios sin `puede_editar` no pueden usarla.
- Un lote legado cuya cantidad exceda el saldo sin lote, o que no se concilie, requiere revisión antes de transferir.
- El `producto_lotes.id` queda canónico en el origen; la continuidad permite rastrearlo en el destino, pero futuros reportes de lote deben unir esa relación explícitamente.
- No hay operación de reversa expuesta. Los movimientos posteriores obligan a compensación auditada en vez de rollback destructivo.

## Archivos de esta fase

- `supabase/migrations/20261007164746_b2_4_transferencias_ubicaciones_seguras.sql`
- `supabase/migrations/20261007165621_b2_4_index_lote_continuidad_transferencia.sql`
- `supabase/migrations/20261007165808_b2_4_secure_transfer_entrypoint.sql`
- `sql/2026-10-b2-4-pruebas-transferencias.sql`
- `sql/2026-10-b2-4-transferencias-ubicaciones.rollback.sql`
- `docs/hermes/01-plan-areas-operativas.md`
- `docs/hermes/03-cola-de-trabajo-codex.md`
- `docs/hermes/04-bitacora-codex.md`
- `docs/hermes/06-canal-hermes-codex.md`
- `docs/hermes/21-b2-4-motor-transferencias-ubicaciones.md`

No se accedió ni se hicieron cambios en Café del Desierto / Llamita Stock. No se implementó B3 ni se modificaron datos persistentes de transferencia.
