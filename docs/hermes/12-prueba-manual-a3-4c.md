# Procedimiento manual de prueba A3.4c — Lama en modo prueba

## Propósito y límites

Este procedimiento valida el camino comercial que utiliza la interfaz Lama para agregar, confirmar y cerrar una mesa, junto con la captura y aplicación del evento Lama–Stock. Se ejecuta solo en el proyecto Supabase `llamita-plus` (`iuryhsjucblmebdogewa`) y solo con datos sintéticos.

El modo debe ser `prueba`. Nunca se usa `real`, no se usan ventas reales y el procedimiento completo debe estar dentro de `BEGIN ... ROLLBACK`. No se accede a Café del Desierto/Llamita Stock.

## Secuencia

1. Confirmar el proyecto y que `lama_stock_config` no tenga filas persistentes.
2. Abrir una transacción.
3. Insertar una sede, mesa, cuenta, dos productos y una receta temporales.
4. Configurar la sede sintética con `modo = 'prueba'`.
5. Reproducir las acciones de Lama: agregar producto, confirmar comanda y cerrar mesa. En base de datos son `cuenta_agregar`, `cuenta_confirmar` y `cuenta_cerrar`, que son las funciones usadas por la interfaz.
6. Consultar el evento creado y sus aplicaciones. Debe quedar `modo_efectivo = 'prueba'`, estado `prueba` y una aplicación por ingrediente.
7. Ejecutar `lama_stock_aplicar_evento(event_id)` dos veces. El número de aplicaciones debe seguir siendo el mismo y las claves de idempotencia no deben duplicarse.
8. Confirmar que el stock no cambia.
9. Registrar los IDs observados y ejecutar `ROLLBACK`.
10. Fuera de la transacción, confirmar que los conteos y la suma de stock coinciden con el corte inicial y que `lama_stock_config` vuelve a estar vacía.

## Resultado verificado el 2026-10-06

- Cuenta sintética: `990301`.
- Evento: `646d4cb3-5124-4410-ab40-4dbd89a68b6c`.
- Aplicaciones: `2a419ca9-56bf-49b8-8bea-71645f3f10dd`, `a9bea2ef-19c9-4f25-82c8-07f4b49fa33d`.
- Estado de cuenta: `cerrada`.
- Estado/modo del evento: `prueba`/`prueba`.
- Aplicaciones: `2`, sin duplicados después de dos reintentos.
- Stock sintético antes y después del procesamiento: `10` y `10` por producto.

Los IDs anteriores existieron solo durante la transacción y fueron revertidos.

## Conteos pre/post

| Entidad | Antes | Después |
|---|---:|---:|
| cuentas | 59 | 59 |
| cuenta_items | 88 | 88 |
| productos | 1437 | 1437 |
| recetas | 396 | 396 |
| receta_items | 514 | 514 |
| suma `productos.stock_actual` | 15438 | 15438 |
| comandas | 50 | 50 |
| `lama_stock_config` | 0 | 0 |
| `lama_stock_eventos` | 0 | 0 |
| `lama_stock_aplicaciones` | 0 | 0 |
| `lama_stock_capturas` | 0 | 0 |

La prueba no deja datos persistentes ni habilita el modo real.
