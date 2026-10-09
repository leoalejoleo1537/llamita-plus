# B2.4.1 — Áreas activas dinámicas en transferencias

Fecha: 2026-10-09

Estado: **COMPLETADA**

Entorno: `leoalejoleo1537/llamita-plus`; Supabase `llamita-plus` (`iuryhsjucblmebdogewa`).

## Resultado

`stock_internal.transferir_aplicar` ya no conoce una lista de cuatro áreas. Tanto el destino como un origen de tipo área se validan mediante la relación instalada:

- ubicación activa;
- sede `plaza`;
- `ubicacion.area_id` no nulo;
- área existente y activa;
- `areas_operativas.codigo = ubicaciones.codigo`.

Esto habilita Heladería y futuras áreas creadas mediante el contrato B3.2a. Sin asignar continúa permitido solo como origen lógico de Local 1. Bodega conserva el único origen `central/bodega_central` y los destinos continúan limitados a áreas de Local 1.

## Cambio exacto

Se reemplazaron únicamente los predicados que contenían:

```sql
codigo not in ('cocina_fria','cocina_caliente','barra','cafeteria')
```

No se alteraron firma, cuerpo contable, locks, enlaces, lotes, movimientos, actor, motivo, idempotencia, permisos o proyección.

La migración obtiene la definición instalada, exige que ambos fragmentos antiguos aparezcan exactamente una vez y ejecuta `CREATE OR REPLACE` solo después de esa precondición. También comprueba que el núcleo continúe como `SECURITY DEFINER`, `search_path=''` y ejecutable únicamente por su propietario.

## Migración y rollback

- Archivo: `supabase/migrations/20261009191927_b2_4_1_dynamic_active_areas.sql`.
- Versión remota: `20261009192100 b2_4_1_dynamic_active_areas`.
- Rollback: `sql/2026-10-b2-4-1-dynamic-active-areas.rollback.sql`.

El rollback restaura las listas B2.4 solo si no existe ninguna transferencia persistente cuyo origen o destino sea un área dinámica. Si existe actividad, aborta para no dejar movimientos que después no puedan volver a transferirse o compensarse.

## Pruebas transaccionales

`sql/2026-10-b2-4-1-pruebas-dynamic-active-areas.sql` ejecutó `BEGIN … ROLLBACK` y comprobó:

- Sin asignar → Cocina fría;
- Sin asignar → Cafetería;
- Sin asignar → Heladería;
- Sin asignar → área futura activa y vinculada;
- rechazo de área archivada/inactiva;
- rechazo de UUID de ubicación inexistente;
- rechazo de ubicación de `plaza` sin `area_id`;
- rechazo de destino en sede incorrecta;
- rechazo de saldo insuficiente;
- repetición con el mismo UUID y payload: un encabezado y dos movimientos;
- constraints diferidos del par de movimientos;
- total del ledger y stock global invariantes.

Los dos primeros intentos del fixture fallaron antes de llegar al motor: primero se intentó escribir una columna generada y después se intentó mantener activa la ubicación de un área archivada. Ambas transacciones abortaron sin persistir. El fixture se ajustó al esquema real y la ejecución completa pasó.

El rollback técnico también fue ensayado reemplazando su `COMMIT` final por `ROLLBACK`; la definición dinámica permaneció instalada.

## Conteos antes y después

| Control | Antes | Después |
|---|---:|---:|
| Productos | 1.437 | 1.437 |
| Stock global | 15.438,00 | 15.438,00 |
| Lotes | 42 | 42 |
| Movimientos legacy | 431 | 431 |
| Movimientos ledger | 408 | 408 |
| Neto ledger | 9.316,70 | 9.316,70 |
| Transferencias | 0 | 0 |
| Áreas sintéticas B2.4.1 | 0 | 0 |
| Ubicaciones sintéticas B2.4.1 | 0 | 0 |

## Seguridad y regresión

- `public.stock_transferir` conserva firma, `SECURITY INVOKER` y `EXECUTE` solo para `authenticated`.
- El núcleo conserva `SECURITY DEFINER`, `search_path=''` y ACL solo para `postgres`.
- La validación existente de `auth.uid()`, JWT y `permisos_mios().puede_editar` no cambió.
- No hubo DML directo desde navegador ni nuevos grants.
- `npm test` pasó; las pruebas que requieren Chromium se omitieron automáticamente por no estar instalado.
- `git diff --check` pasó.
- Advisors de seguridad y rendimiento conservan hallazgos heredados; no apareció uno atribuible a B2.4.1.

No se modificaron productos, lotes, recetas, caja, mermas, Fudo, Lama, Bodega operativa ni Café del Desierto / Llamita Stock. No se implementaron C1, C2, C3 o C4.
