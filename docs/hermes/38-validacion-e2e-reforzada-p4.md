# P4 — validación E2E reforzada

Fecha: 2026-10-22

Repositorio: `leoalejoleo1537/llamita-plus`

Proyecto Supabase: Llamita Plus (`iuryhsjucblmebdogewa`)

Versión validada: `66380488bd9e9ddd202509f7392cac2c78fc03e0`

Aplicación publicada: `https://llamita-plus.vercel.app/`

## Resultado

**P4 queda validado.** El circuito de producto de venta con receta manual, reserva al confirmar, consumo del ledger al cerrar, liberación al anular, rechazo atómico por saldo insuficiente e idempotencia pasó sin encontrar una regresión funcional.

No se modificó código, esquema, migraciones ni configuración. No se contactó Fudo ni Café del Desierto / Llamita Stock. La única publicación derivada de esta ejecución es este informe.

## Método y aislamiento

- Prefijo único: `ZZ_P4_E2E_20261022T022917Z_`.
- La prueba integral de backend se ejecutó en el proyecto verificado de Llamita Plus dentro de una sola transacción `BEGIN … ROLLBACK`.
- Las altas usaron los motores oficiales: Panel de productos, ajuste manual del ledger, catálogo comercial/receta manual y RPC de Mesas P4.
- Se conservaron los IDs devueltos durante la transacción para comprobar relaciones, movimientos y orígenes. Ninguno quedó persistente tras el `ROLLBACK`.
- La aplicación publicada se abrió con Chromium real en escritorio y teléfono. Para no crear cuentas o datos reales desde la UI, se cargó el HTML/JS desplegado y se sustituyó únicamente el transporte Supabase por un escenario controlado en memoria. El contrato backend se probó por separado contra Supabase real en la transacción anterior.
- Toda ruta de Edge Functions quedó bloqueada durante la prueba visual y se comprobó que no hubo solicitudes Fudo.

## Línea base y limpieza

Los conteos externos tomados antes de la prueba y después del `ROLLBACK` fueron idénticos:

| Objeto / medida | Antes | Después |
|---|---:|---:|
| productos | 1.438 | 1.438 |
| productos de venta | 0 | 0 |
| recetas de venta | 0 | 0 |
| componentes de venta | 0 | 0 |
| configuraciones producto–área | 7 | 7 |
| cuentas | 64 | 64 |
| comandas | 52 | 52 |
| ítems de cuenta | 95 | 95 |
| pagos | 33 | 33 |
| reservas de receta | 0 | 0 |
| movimientos de reserva/receta | 0 | 0 |
| movimientos del ledger | 410 | 410 |
| saldo total del ledger | 9.334,7 | 9.334,7 |
| stock proyectado total | 15.456 | 15.456 |
| ajustes | 2 | 2 |
| repartos | 1 | 1 |
| recetas heredadas | 396 | 396 |
| productos espejo Fudo | 1.377 | 1.377 |
| movimientos Fudo | 15.357 | 15.357 |
| alertas de stock | 0 | 0 |
| saldos negativos | 0 | 0 |

Comprobaciones específicas posteriores:

- productos con prefijo: 0;
- productos de venta con prefijo: 0;
- mesas, cuentas, ajustes y movimientos con prefijo: 0;
- reservas, alertas, comandas y pagos sintéticos: 0;
- ningún saldo negativo.

La primera preparación intentó usar un número de mesa sintética ya ocupado y fue rechazada por la restricción única. Se cambió exclusivamente el número del fixture a `990022` y se repitió. No fue un fallo del producto ni dejó datos porque la transacción se revirtió.

## Resultados por caso

### A. Preparación controlada

Pasó:

- `ZZ_P4_E2E_Leche`: maestro creado mediante el Panel, representación de Local 1 enlazada y configuración activa en Cafetería;
- `ZZ_P4_E2E_Menta`: maestro creado mediante el Panel, representación de Local 1 enlazada y configuración activa en Barra;
- ajuste oficial: Leche = 5 y Menta = 10;
- `ZZ_P4_E2E_Café simple`: receta manual Leche × 1 desde Cafetería, estado listo;
- `ZZ_P4_E2E_Bebida compuesta`: Leche × 2 desde Cafetería + Menta × 1 desde Barra, estado listo;
- borrador adicional para verificar que no fuera vendible.

No se crearon lotes, repartos ni enlaces Fudo.

### B. Circuito funcional

| Caso | Evidencia | Resultado |
|---|---|---|
| Venta simple | confirmar creó reserva 1; Leche siguió en 5; cerrar dejó Leche en 4 | OK |
| Venta multiárea | Leche 4 → 2 en Cafetería y Menta 10 → 9 en Barra | OK |
| Origen de movimientos | cada consumo conservó producto, configuración y ubicación de su componente | OK |
| Anulación antes del cierre | reserva liberada; saldo y movimientos físicos sin cambio | OK |
| Stock insuficiente | rechazo completo y legible; sin comanda parcial, reserva, movimiento ni negativo | OK |
| Doble confirmación | mismo resultado lógico; no creó una segunda reserva | OK |
| Doble cierre | un movimiento de consumo y ningún pago duplicado | OK |
| Borrador | no vendible | OK |
| Origen inválido | bloqueado con “Un ingrediente no tiene un origen de área activo” | OK |
| Proyección | `productos.stock_actual` continuó conciliado con el ledger | OK |

La recepción de resultados de la prueba SQL fue:

```text
A_preparacion   OK: Panel + ajuste oficial + recetas manuales
B1_simple       OK: reserva 1; saldo 5→4 al cerrar
B2_multi_area   OK: Leche 4→2 Cafetería; Menta 10→9 Barra
B3_anulacion    OK: libera sin movimiento
B4_insuficiente OK: rechazo atómico y claro
B5_idempotencia OK: doble confirmación/cierre sin duplicados ni pagos
B6_estados_ui   OK: borrador y origen inválido bloqueados
negativos       0
```

## Evidencia de navegador

Se ejecutó Chromium contra `https://llamita-plus.vercel.app/` en:

- escritorio: 1.440 × 900;
- móvil: 390 × 844.

En ambos tamaños se comprobó:

- Mesas visible y operativa;
- producto listo visible con disponibilidad y área de la receta;
- alta de línea mediante `cuenta_producto_venta_agregar`;
- confirmación mediante `cuenta_confirmar`;
- reserva 1 con saldo físico todavía en 5 y cero movimientos definitivos;
- cierre: saldo 4, una sola escritura de consumo y un solo pago en el escenario;
- segundo cierre: saldo 4 y contadores sin cambios;
- borrador deshabilitado con el texto “Borrador · completa y marca la receta como lista”;
- origen inválido deshabilitado con explicación visible;
- ancho del documento igual al viewport: 1.440/1.440 y 390/390, sin desplazamiento horizontal;
- cero errores JavaScript;
- cero solicitudes Fudo.

Las capturas fueron inspeccionadas durante la ejecución en `/tmp/p4-e2e-escritorio.png` y `/tmp/p4-e2e-movil.png`. No se incorporaron binarios al repositorio porque contienen únicamente el fixture visual y no son necesarios para operar ni reproducir la aplicación.

## Verificaciones del repositorio

- `npm test`: **OK**, salida 0. La suite estática completa pasó. Sus casos visuales estándar informan “sin navegador” porque no reciben automáticamente la ruta externa de Playwright en este entorno; la ejecución Chromium reforzada anterior sí usó explícitamente el navegador instalado y pasó.
- `git diff --check`: se ejecuta sobre la publicación documental antes del commit.
- Código y migraciones funcionales modificados: ninguno.

## Conclusión

P4 está operativo en los casos exigidos y no requiere corrección a partir de esta validación. La separación es coherente: confirmar reserva ingredientes; cerrar consume una sola vez desde las áreas declaradas por la receta; anular libera; un error de disponibilidad u origen rechaza toda la operación.

El siguiente nodo continúa siendo **P5 — adaptador Fudo hacia el mismo motor de recetas**, todavía no activado.
