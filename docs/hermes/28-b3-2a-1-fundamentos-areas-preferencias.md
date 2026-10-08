# B3.2a.1 — fundamentos de áreas y preferencias de producto

Fecha: 2026-10-08

Estado: **COMPLETADA**

Repositorio: `leoalejoleo1537/llamita-plus`

Supabase: `llamita-plus` (`iuryhsjucblmebdogewa`)

## Resultado

B3.2a.1 quedó instalada como una capa de datos y RPC protegidas, sin interfaz. El catálogo de áreas y la preferencia de producto continúan separados del libro físico: una preferencia no contiene cantidad y cambiarla no genera movimientos ni mueve existencias.

La migración remota registrada es `20261008175901 b3_2a_1_fundamentos_areas_preferencias`. Su fuente versionada es `supabase/migrations/20261008175539_b3_2a_1_fundamentos_areas_preferencias.sql`.

## Modelo exacto

### `public.areas_operativas`

Se añadieron:

- `nombre_normalizado`, generado desde el nombre sin diferencias de mayúsculas, espacios repetidos ni tildes comunes;
- `creado_por`, `actualizado_por`, `archivado_por`, vinculados a `auth.users(id)`;
- `archivado_at`;
- unicidad por `(sede, nombre_normalizado)`;
- restricciones de sede `plaza`, orden no negativo y coherencia entre estado/actor/fecha de archivo.

Las cuatro áreas heredadas conservan actores nulos porque fueron creadas antes de esta auditoría y no se inventó una autoría histórica. Las áreas nuevas deben registrar actor real.

### `public.producto_area_asignacion`

Se añadieron `creado_por` y `actualizado_por`, ambos obligatorios y vinculados a `auth.users(id)`. Se conserva la clave única `(sede, producto_id)`, por lo que cada producto tiene una sola preferencia en Local 1. `Sin asignar` sigue representándose con `area_id IS NULL` y `estado='sin_asignar'`; no es un área física.

El trigger de contexto ahora rechaza áreas inexistentes, de otra sede o archivadas. La tabla continúa sin cantidad y sin permisos directos de cliente.

### `stock_internal.ubicaciones`

Cada `area_id` puede vincular una sola ubicación. Un trigger privado exige coincidencia de sede, código y estado entre área y ubicación. La creación de un área inserta su ubicación dentro de la misma transacción. Solo `plaza` admite altas mediante estas RPC; no se crearon áreas ni ubicaciones en `central`, `angamos` o `bodega`.

## RPC instaladas

| RPC | Capacidad | Efecto |
|---|---|---|
| `areas_operativas_listar(text, boolean)` | sesión para activas; `puede_ajustes` para incluir archivadas | lectura del catálogo, ubicación, preferencias y saldo |
| `area_operativa_crear(text, integer, text, text)` | `puede_ajustes` | crea área de `plaza` y ubicación atómicamente |
| `area_operativa_editar(uuid, text, integer)` | `puede_ajustes` | cambia nombre/orden y sincroniza el nombre de ubicación |
| `area_operativa_archivar(uuid, boolean)` | `puede_ajustes` | archivo lógico; bloquea saldo y exige confirmación para preferencias |
| `producto_area_preferencia_guardar(bigint, uuid, text)` | `puede_editar` | inserta/cambia solo la preferencia |
| `producto_plaza_crear(...)` | `puede_editar` | crea ficha `plaza` con stock cero y preferencia atómica |

Todas son `SECURITY DEFINER`, `search_path=''`, objetos calificados, validación interna de `auth.uid()`/rol y capacidad efectiva mediante `permisos_mios()`. Solo `authenticated` tiene `EXECUTE`; `PUBLIC`, `anon` y `service_role` no. Los helpers de `authz_internal` y `stock_internal` no son ejecutables por roles de aplicación.

El propietario raíz recibe las capacidades efectivas de S1. El administrador operativo conserva `puede_ajustes` y `puede_editar`, pero no adquiere gobierno de usuarios. Un usuario común puede leer áreas activas, pero no incluir archivadas ni escribir.

`areas_operativas`, `producto_area_asignacion` y `stock_internal.ubicaciones` continúan sin SELECT/DML directo para `anon`, `authenticated` o `service_role`. El aviso del advisor “RLS sin política” es intencional en las dos tablas públicas cerradas: RLS está habilitada y los grants están revocados. Los avisos sobre RPC `SECURITY DEFINER` ejecutables por `authenticated` también son esperados; cada entrada valida sesión y capacidad en servidor. Ninguna RPC nueva es ejecutable por anónimos.

## Reglas de archivo

- No existe borrado físico.
- Se rechaza el archivo si cualquier saldo agregado de la ubicación es distinto de cero.
- Con saldo cero y sin preferencias, se archivan área y ubicación.
- Con preferencias, `p_reasignar_sin_asignar=true` es obligatorio.
- La confirmación cambia únicamente `producto_area_asignacion` a `area_id=NULL`; no crea movimientos, lotes, ajustes ni transferencias.

## Creación de producto

`producto_plaza_crear` crea una sola ficha maestra en `plaza`, fuerza `stock_actual=0` y registra `origen='b3_2a_rpc'`. No crea existencias, lotes, movimientos legacy o del ledger, recetas, ítems, enlaces Fudo ni producto de Bodega. Si no recibe área, crea la preferencia `Sin asignar`; si recibe un área, esta debe existir y estar activa.

Las rutas heredadas de interfaz no fueron reemplazadas. Ese corte corresponde a B3.2a.2/B3.2a.3.

## Pruebas

`sql/2026-10-b3-2a-1-pruebas-transaccionales.sql` pasó dentro de `BEGIN ... ROLLBACK`:

- alta de área y ubicación vinculada;
- duplicado por nombre normalizado;
- rechazo de otra sede y del código reservado `sin_asignar`;
- archivo vacío;
- archivo con preferencias sin/sí confirmación;
- rechazo de preferencia hacia área archivada;
- archivo con saldo rechazado, usando una transferencia sintética Sin asignar → Cafetería mediante `stock_transferir` y revertida;
- producto con área y producto Sin asignar, ambos con stock cero y sin efectos laterales;
- cambio de preferencia de un producto enlazado sin cambiar `producto_enlace` ni existencias;
- propietario raíz, administrador operativo, usuario común y anónimo;
- DML directo rechazado;
- lectura de áreas activas e inclusión de archivadas según capacidad;
- firma y autorización de `stock_transferir` intactas.

`npm test` pasó; las pruebas que requieren navegador se omitieron por ausencia de Chromium, sin impacto en este bloque sin interfaz. `git diff --check` pasó al cierre. Los advisors de seguridad y rendimiento se revisaron; no apareció ejecución anónima, `search_path` mutable ni grants nuevos atribuibles a B3.2a.1. Los índices nuevos figuran como no usados porque las asignaciones persistentes continúan vacías.

## Conteos pre/post

| Objeto | Antes | Después |
|---|---:|---:|
| Productos | 1.437 | 1.437 |
| Stock global `productos.stock_actual` | 15.438,00 | 15.438,00 |
| Productos `plaza` | 329 | 329 |
| Áreas operativas | 4 | 4 |
| Asignaciones persistentes | 0 | 0 |
| Ubicaciones del ledger | 6 | 6 |
| Movimientos del ledger | 408 | 408 |
| Neto del ledger | 9.316,70 | 9.316,70 |
| Transferencias | 0 | 0 |
| Lotes | 42 | 42 |
| Movimientos legacy | 431 | 431 |
| Recetas / ítems | 396 / 514 | 396 / 514 |
| Enlaces de producto | 513 | 513 |
| Movimientos Fudo | 15.357 | 15.357 |
| Eventos Lama–Stock | 0 | 0 |
| Cuentas / pagos | 59 / 30 | 59 / 30 |

No quedaron productos de prueba (`origen='b3_2a_rpc'`: 0), áreas, asignaciones, movimientos ni transferencias sintéticas.

## Compatibilidad

No se modificaron Edge Functions, Fudo remoto, `producto_enlace`, recetas, Lama, cuentas, mesas, pagos, caja, Bodega, lotes, mermas, `stock_internal.movimientos`, `stock_internal.existencias`, `stock_transferir` ni el valor de `productos.stock_actual`.

La única interacción contable fue la transferencia de prueba revertida. No se accedió ni modificó Café del Desierto / Llamita Stock.

## Rollback y riesgos pendientes

El rollback técnico está en `sql/2026-10-b3-2a-1-fundamentos-areas-preferencias.rollback.sql`. Aborta si detecta áreas/productos/asignaciones creados o modificados por B3.2a.1. Después del primer uso persistente corresponde una reversión compensatoria y no borrar preferencias o fichas reales.

Para B3.2a.2 quedan pendientes:

1. hacer dinámica la lectura B3.1, que aún filtra los cuatro códigos fundacionales;
2. adaptar formularios y rutas heredadas para usar estas RPC;
3. mostrar con claridad que cambiar preferencia no mueve saldo;
4. diseñar UX desktop/móvil y pruebas visuales;
5. mantener B3.2b (transferencias visuales) separado y sin activarlo automáticamente.
