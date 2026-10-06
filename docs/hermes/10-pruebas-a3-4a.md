# Evidencia de pruebas A3.4a

Fecha: 2026-10-06
Proyecto: `llamita-plus` (`iuryhsjucblmebdogewa`)

Todas las pruebas se ejecutaron en transacciones `BEGIN ... ROLLBACK`.

| Caso | Resultado |
|---|---|
| Consulta de estados `pendiente`, `aplicado`, `error`, `sin_receta` | Vista interna mostró los cuatro estados |
| Reproceso de evento `error` en `prueba` | Cambió a `prueba` y generó una aplicación |
| Segundo reproceso | No duplicó la aplicación |
| Evento `sin_receta` | Rechazado con diagnóstico |
| Evento `real` | Rechazado por el helper A3.4a |
| Permisos | Sin EXECUTE del helper ni SELECT de la vista para roles públicos |
| Stock | Suma de `productos.stock_actual` idéntica antes/después |

Estado posterior: `lama_stock_config`, eventos y aplicaciones en cero; 1.437 productos; suma de stock `15.438`. No se modificaron cierres, ventas, lotes, movimientos, Fudo ni áreas.
