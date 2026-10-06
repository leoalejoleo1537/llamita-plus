# Evidencia de pruebas A3.4b — flujo E2E Lama–Stock

Fecha: 2026-10-06
Proyecto: Supabase `llamita-plus` (`iuryhsjucblmebdogewa`)
Repositorio: `leoalejoleo1537/llamita-plus`

## Alcance

Prueba sintética completa, sin ventas reales, ejecutada en una única transacción `BEGIN ... ROLLBACK`. Los IDs temporales usados fueron productos `990001` y `990002`, receta `990001`, proveedor `A34B-TEST-001`, una mesa/cuenta sintéticas y un trigger temporal para provocar el error intermedio. No quedó ningún artefacto persistente.

## Casos verificados

| Caso | Resultado |
|---|---|
| Crear cuenta, agregar línea y confirmar | Correcto; línea confirmada y comanda asociada |
| Cerrar mesa y capturar evento | Correcto; cuenta cerrada y evento con snapshot |
| Modo `prueba` | Correcto; dos aplicaciones por ingrediente, sin cambiar stock |
| Snapshot frente a cambio de receta viva | Correcto; el evento conservó el snapshot original |
| Idempotencia | Correcto; reaplicar no creó duplicados |
| Error en ingrediente intermedio | Correcto; evento `error`, cero aplicación parcial |
| Reintento | Correcto; evento pasó a `prueba` |
| Reintento repetido | Correcto; no duplicó aplicaciones |
| Aislamiento comercial | Correcto; cuenta cerrada con total `250` pese al fallo de stock |

## Conteos pre/post

| Entidad | Antes | Después |
|---|---:|---:|
| cuentas | 59 | 59 |
| cuenta_items | 88 | 88 |
| recetas | 396 | 396 |
| receta_items | 514 | 514 |
| productos | 1437 | 1437 |
| suma `productos.stock_actual` | 15438.00 | 15438.00 |
| comandas persistentes | 50 | 50 |
| `lama_stock_config` | 0 | 0 |
| `lama_stock_eventos` | 0 | 0 |
| `lama_stock_aplicaciones` | 0 | 0 |
| `lama_stock_capturas` | 0 | 0 |

## Conclusión

El fallo del motor de stock no impide cerrar la mesa ni registrar sus datos comerciales. El modo real no fue activado y ningún stock persistente cambió. A3.4c queda pendiente.
