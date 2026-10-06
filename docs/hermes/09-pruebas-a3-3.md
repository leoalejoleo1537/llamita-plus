# Evidencia de pruebas A3.3

Fecha: 2026-10-06
Proyecto: `llamita-plus` (`iuryhsjucblmebdogewa`)
Migraciones: `a3_3_motor_neutral_lama_stock`, `a3_3_fulfillment_rules`

Todas las pruebas sintéticas se ejecutaron en `BEGIN ... ROLLBACK`. No quedó configuración, evento, aplicación, captura, cuenta, mesa, lote ni movimiento sintético.

## Casos ejecutados

| Caso | Resultado |
|---|---|
| Receta de un ingrediente | Aplicación esperada creada |
| Receta de varios ingredientes | Una aplicación por ingrediente |
| Modo `prueba` | Deltas negativos registrados; stock sin cambios |
| Modo `real`, producto sin lotes | Delegación a `descontar_con_reposicion`; sin stock negativo |
| Modo `real`, FIFO | Delegación a `descontar_lotes`; `trg_sync_stock_lotes` recalculó stock una sola vez |
| Repetición / timeout equivalente | Devuelve la aplicación existente; no duplica descuento |
| Error en ingrediente intermedio | Revirtió el ingrediente anterior; evento y aplicaciones quedan `error` |
| Stock insuficiente | Conservó exactamente el comportamiento instalado: tope en cero |
| Producto sin receta | Sin aplicación |
| Receta modificada después de capturar | El snapshot del evento no cambió |
| `siempre` / `servir` / `llevar` | `serve` aplica siempre/servir; `takeaway` aplica siempre/llevar |
| Cierre real de cuenta | Cuenta cerrada y aplicaciones creadas dentro de la transacción de prueba |

## Conteos posteriores

- `lama_stock_config`: 0 filas.
- `lama_stock_eventos`: 0 filas.
- `lama_stock_aplicaciones`: 0 filas.
- `lama_stock_capturas`: 0 filas.
- `productos`: 1.437 filas.
- Suma de `productos.stock_actual`: 15.438.

Los helpers internos no son ejecutables por `public`, `anon`, `authenticated` ni `service_role`. Los advisors de Supabase fueron revisados; sus avisos restantes son preexistentes o corresponden al diseño intencional de tablas internas con RLS sin políticas y sin grants directos.
