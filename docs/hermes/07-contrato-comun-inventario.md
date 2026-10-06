# Contrato común de venta, receta e inventario

Fecha: 2026-10-06
Estado: **diseño propuesto para aprobación**
Alcance: Llamita Plus, únicamente documentación. No crea tablas, no ejecuta SQL y no modifica aplicación, Supabase ni datos.

## 1. Propósito y reglas no negociables

Este contrato separa tres responsabilidades:

1. El POS registra qué se vendió y conserva precio, identidad y estado comercial.
2. El adaptador de cada proveedor traduce su formato a un evento canónico.
3. Un solo motor de inventario resuelve receta, lote, área, movimiento y reversa.

Reglas:

- Una sede tiene un solo origen POS activo: Fudo, Lama o Toteat.
- Los reintentos del mismo origen deben ser idempotentes.
- El pago, la propina, el medio de pago y el cierre de caja no son eventos de inventario.
- En Lama, el consumo se emite al **cerrar la mesa** y cubre todas las líneas confirmadas no anuladas.
- El precio pertenece a la venta, no al stock ni a la receta.
- Una receta o precio histórico nunca se reescribe por cambiar el catálogo actual.
- Los movimientos aplicados no se borran. Una reversa genera un movimiento compensatorio vinculado al original.
- El motor de inventario es el único escritor de saldos. Mientras dure la transición, `productos.stock_actual` no puede convivir con otro saldo editable.

## 2. Modelo canónico

### 2.1 Producto

Identidad permanente de Llamita, independiente del proveedor:

```text
Product {
  product_id: UUID o ID canónico de Llamita
  canonical_name: text
  unit: text                    // unidad, kg, L, etc.
  active: boolean
  product_kind: 'ingredient'|'sellable'|'service'|'other'
  created_at: timestamptz
}
```

La identidad Fudo (`fudo_product_id`) y Toteat (`toteat_product_id`) son referencias de adaptador:

```text
ProductLink {
  product_id: Product.product_id
  provider: 'fudo'|'toteat'|'lama'
  provider_product_id: text
  provider_name: text
  sede: text
  active: boolean
  valid_from: timestamptz
  valid_to: timestamptz|null
}
```

Lama puede referenciar directamente `product_id`. Durante una transición, puede conservar `fudo_product_id` como referencia de catálogo, pero no debe convertirlo en identidad permanente.

### 2.2 Precio

El precio vive separado del inventario:

```text
Price {
  price_id: UUID o ID canónico
  product_id: Product.product_id
  sede: text
  amount: numeric
  currency: text
  valid_from: timestamptz
  valid_to: timestamptz|null
}
```

Cada línea vendida guarda una instantánea, aunque el precio vigente cambie:

```text
SoldLinePrice {
  price_id: optional
  amount: numeric
  currency: text
  captured_at: timestamptz
}
```

No se calcula pérdida monetaria de inventario desde este contrato: el costo unitario histórico es otra fuente y debe ser confiable antes de usarse.

### 2.3 Receta

Una receta es versionada por producto vendible y sede:

```text
RecipeVersion {
  recipe_version_id: UUID o ID canónico
  product_id: Product.product_id
  sede: text
  version: integer
  valid_from: timestamptz
  valid_to: timestamptz|null
  status: 'draft'|'active'|'retired'
  snapshot_hash: text
  snapshot_json: jsonb
}

RecipeComponent {
  recipe_version_id: RecipeVersion.recipe_version_id
  component_product_id: Product.product_id
  quantity: numeric
  unit: text
  fulfillment: 'always'|'takeaway'|'serve'|'other'
}
```

El `snapshot_json` es una defensa adicional: permite reconstruir exactamente la receta aun si la tabla normalizada cambia. Cada evento aplicado debe guardar `recipe_version_id` y `snapshot_hash` (o la instantánea completa si la versión no existe todavía).

### 2.4 Evento comercial canónico

```text
SaleEvent {
  event_id: UUID                       // generado por Llamita
  source: 'fudo'|'lama'|'toteat'
  source_sale_id: text
  source_line_id: text
  sede: text
  occurred_at: timestamptz
  observed_at: timestamptz
  state: 'closed'|'voided'|'reopened'
  product_id: Product.product_id
  provider_product_id: text|null
  quantity: numeric
  fulfillment: 'serve'|'takeaway'|'other'|null
  unit_price: numeric|null
  currency: text|null
  price_snapshot: jsonb|null
  recipe_version_id: UUID|null
  recipe_snapshot: jsonb|null
  metadata: jsonb
}
```

`source_sale_id + source_line_id` identifica la línea del proveedor. `event_id` identifica el evento canónico interno. Una misma venta puede tener varias líneas, pero nunca dos eventos aplicables para la misma clave de origen y versión.

### 2.5 Libro de inventario

El motor produce un ledger inmutable:

```text
InventoryApplication {
  application_id: UUID
  event_id: UUID
  component_product_id: Product.product_id
  area_id: UUID|null
  quantity_delta: numeric       // negativo consumo, positivo compensación
  unit: text
  lot_id: UUID|null
  status: 'pending'|'applied'|'failed'|'reversed'
  idempotency_key: text
  applied_at: timestamptz|null
  reversal_of: UUID|null
  error_code: text|null
  error_detail: text|null
}
```

El saldo consultable se deriva de este libro y de entradas/mermas/repartos bajo la misma frontera. El campo de compatibilidad `productos.stock_actual`, si se mantiene durante la transición, debe ser una proyección calculada, nunca editable en paralelo.

## 3. Estados operativos de Lama

### 3.1 Línea y mesa

Estados de línea existentes o equivalentes:

```text
line: draft → confirmed → (voided_before_close | consumed_at_close)
line: consumed_at_close → reversed (solo por anulación compensatoria autorizada)
mesa: abierta → precuenta → cerrada
```

- Una línea `draft` puede eliminarse sin evento de inventario porque aún no salió a cocina.
- Una línea `confirmed` se conserva; no se edita destructivamente.
- Una anulación antes del cierre queda registrada y no consume stock.
- Al pasar la mesa a `cerrada`, el adaptador emite una vez todas las líneas confirmadas, descontando también las cortesías y consumos internos que estén modelados como líneas.
- El importe pagado, los pagos parciales, la propina y el arqueo solo completan el cierre comercial. No generan eventos adicionales.
- Un cierre repetido debe devolver el mismo resultado sin volver a descontar.
- Si una línea ya consumida se anula después del cierre, se registra `voided` y se genera una compensación positiva del consumo original. No se elimina la venta ni se edita el movimiento histórico.
- Reabrir una mesa cerrada no debe borrar el cierre ni sus aplicaciones. Requiere una operación administrativa explícita que cree eventos de compensación y una nueva venta, si el negocio lo autoriza.

### 3.2 Consumos sin cobro

Una cortesía, consumo de garzón, cumpleaños o consumo administrativo sigue siendo una salida física. Debe representarse como línea confirmada con:

```text
commercial_treatment: 'sale'|'courtesy'|'internal_consumption'
payment_amount: numeric
```

El campo comercial explica caja; la cantidad consumida sigue entrando al evento de inventario al cerrar la mesa. El código exacto de motivos y descuentos queda pendiente de aprobación de producto.

## 4. Idempotencia y errores

Cada adaptador debe crear una clave determinista:

```text
idempotency_key =
  source + ':' + sede + ':' + source_sale_id + ':' +
  source_line_id + ':' + recipe_version_or_hash
```

Reglas:

1. El motor busca la clave antes de aplicar. Si existe `applied`, devuelve el resultado anterior.
2. Si existe `pending`, el reintento reanuda o consulta el intento, nunca crea otro descuento.
3. Si existe `failed`, conserva el error y permite reintentar con la misma clave después de corregirlo.
4. Cada componente de una receta tiene su propia fila de aplicación, pero comparte el evento y la clave de venta.
5. Un timeout después del commit debe ser seguro: repetir la solicitud devuelve el ledger existente.
6. Una anulación referencia `event_id` y crea una compensación con `reversal_of`; no reutiliza la clave del consumo original.

La idempotencia es por proveedor y sede. La regla de un POS activo evita que Fudo y Lama compitan por una misma venta; no reemplaza la deduplicación.

## 5. Encaje con Fudo existente

El adaptador Fudo conserva su flujo actual:

```text
fudo-sync-ventas
  → fudo_procesar_item
  → fudo_movimientos
  → receta Fudo / enlace a Product
  → evento común o aplicación equivalente
  → ledger de inventario
```

Transición recomendada:

1. No cambiar todavía `fudo_procesar_item` ni sus firmas.
2. Mapear `(sede, fudo_product_id)` a `ProductLink`.
3. Convertir la receta activa en `RecipeVersion` y conservar el snapshot utilizado por cada venta.
4. Mantener `fudo_movimientos` como trazabilidad de entrada del proveedor durante una fase de compatibilidad.
5. Hacer que una única capa de aplicación produzca el ledger; Fudo no debe descontar por un camino paralelo una vez activado el contrato.
6. Validar modo `prueba` como evento recibido/previsualizado sin aplicación y modo `real` como evento aplicable.

El empuje manual de stock hacia Fudo es otra dirección de integración y no debe confundirse con el consumo local. Debe seguir protegido por Ajustes y permisos.

## 6. Interfaz esperada de Toteat

El adaptador Toteat debe entregar el mismo `SaleEvent`, sin conocer tablas de inventario:

- catálogo: `provider_product_id`, nombre, sede y precio;
- venta cerrada: `source_sale_id`, líneas estables, cantidades, fecha y estado;
- anulación: referencia a la venta/línea original;
- reintentos: misma clave de origen;
- sin secretos, tokens ni credenciales en `metadata`.

Si Toteat no aporta una línea estable, el adaptador debe generar y persistir una clave determinista antes de enviar el evento. No se debe deduplicar por nombre de producto, precio o timestamp solamente.

## 7. Transición hacia stock producto-área

La transición debe ser coordinada y mantener una sola fuente editable:

### Fase 0 — inventario de escritores

Documentar y probar todos los caminos actuales: edición de productos, lotes y trigger, entradas, mermas, repartos, restauraciones, fusiones, Fudo, reportes y snapshots. No crear saldos por área todavía.

### Fase 1 — identidad y proyección

Crear (en una fase autorizada posterior) la identidad canónica de producto, enlaces y recetas versionadas. Clasificar productos sin alterar históricos. Mantener `productos.stock_actual` como lectura de compatibilidad.

### Fase 2 — ledger único con área opcional

El motor registra movimientos nuevos con `area_id` nullable. Lo no clasificado queda en `Sin asignar`. Las cantidades históricas conservan área nula; no se infiere retrospectivamente por nombre o rubro.

### Fase 3 — corte de escritura

Adaptar en conjunto todos los escritores para que escriban al ledger producto-área. `productos.stock_actual` pasa a ser una proyección recalculada. Bloquear edición directa de la proyección y establecer conciliación automática.

### Fase 4 — activación por sede

Activar una sede por vez, con un POS activo, ventana de corte, conciliación inicial y reversa ensayada. No activar áreas en las sedes existentes hasta disponer de contexto de datos seguro y permisos revisados.

### Fase 5 — retiro de compatibilidad

Cuando reportes, Fudo, Lama, mermas, repartos y restauraciones lean la proyección nueva sin diferencias, retirar gradualmente los escritores directos antiguos. No borrar históricos.

## 8. Alternativas consideradas

### Recomendación: cierre de Lama como disparador

Ventajas: incluye todo lo confirmado, respeta la decisión de negocio, separa caja de consumo y permite una reversa posterior explícita.

### Descartada: descontar al confirmar comanda

Genera stock consumido por ventas que pueden anularse, modificarse o quedar abiertas; exige reversas por cada cambio y complica pagos parciales.

### Descartada: descontar al cobrar cada pago

Un pago parcial dividiría artificialmente el consumo; propinas, medios y cierre de caja no representan salida física.

### Descartada: descontar al entregar cada plato

Requiere un estado de cocina completo y sincronizado, hoy inexistente en el contrato de Lama; además puede dejar mesas cerradas sin una reconciliación comercial simple.

### Descartada: mantener un saldo por POS

Duplicaría `productos.stock_actual`, permitiría doble descuento y haría imposible saber cuál saldo es autoritativo.

## 9. Pruebas de aceptación futuras

No se ejecutan en A2; quedan como criterios para implementación:

1. Repetir el cierre de una mesa diez veces: una sola aplicación por línea.
2. Confirmar, anular antes de cierre y cerrar: no hay consumo de la línea anulada.
3. Cerrar y repetir la respuesta con timeout: no duplica stock.
4. Cerrar con pago parcial, propina, tarjeta y cortesía: todas las líneas confirmadas se consumen una vez.
5. Anular después del cierre: aparece compensación positiva vinculada, sin borrar el consumo original.
6. Cambiar una receta después de una venta: la venta conserva la receta y cantidades antiguas.
7. Cambiar precio después de una venta: la línea conserva precio y moneda aplicados.
8. Fudo reenvía el mismo ítem: devuelve la aplicación existente.
9. Toteat reintenta una línea con la misma clave: no duplica.
10. Fallo en un ingrediente: se conserva error por componente y no se marca toda la venta como aplicada sin resultado explícito.
11. Lotes FIFO: consume por vencimiento y deja trazabilidad del lote.
12. Transición por área: ningún camino escribe un saldo paralelo y la proyección concilia con el ledger.

## 10. Decisiones que Alejo debe confirmar

1. Catálogo de estados y motivos para consumos internos/cortesías.
2. Si una anulación posterior al cierre requiere permiso de administrador y si la compensación puede ejecutarse automáticamente.
3. Formato final de identidad canónica (UUID o bigint) y estrategia de enlace de productos existentes.
4. Si se conserva snapshot JSON además de una versión normalizada de receta.
5. Unidad y reglas de redondeo por componente.
6. Política de errores parciales: reintento por ingrediente o bloqueo del evento completo.
7. Ventana y procedimiento de corte por sede para pasar a producto-área.
8. Permisos/RLS mínimos del motor y de los adaptadores.

Hasta resolver estas decisiones no se debe implementar el puente Lama→inventario, cambiar `fudo_procesar_item` ni crear stock por área.

## 11. Límites de esta entrega

- No se creó ni modificó código.
- No se ejecutó SQL, migración, RPC o Edge Function.
- No se insertaron, actualizaron ni borraron datos.
- No se consultó Café del Desierto / Llamita Stock.

