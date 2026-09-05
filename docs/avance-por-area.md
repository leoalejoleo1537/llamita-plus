# Cuánto llevamos y cuánto falta, por área

> Pedido por Jhon el 2026-09-04 para el cierre del informe diario. **Es la
> fuente**: el informe la lee y la pinta, no la reinventa cada noche — dos
> copias del mismo estado se desincronizan, que es el error que este proyecto
> ya cometió cuatro veces.
>
> **Se actualiza cuando una etapa cambia de estado, no todos los días.**

---

## ⚠️ Cómo leer los números, porque si no engañan

**Los porcentajes de acá NO miden código.** Miden **piezas terminadas sobre
piezas previstas** — las que están listadas en la tabla de cada área, ni una
más. La cuenta está a la vista en cada fila.

Eso significa dos cosas que conviene tener claras:

1. **El 100 % de un área no es "está perfecta"**: es "las piezas que
   listamos están hechas". Si mañana aparece una pieza nueva, el número baja.
   Eso está bien: significa que aprendimos algo.
2. **Un área grande y una chica pesan igual en su propia fila.** No hay un
   "avance total del proyecto", y es a propósito: un número único mezcla
   terminar un botón con construir el arqueo de caja, y esconde justo lo que
   hay que ver.

---

## El cuadro

| Área | Avance | Cuenta | Estado |
|---|---|---|---|
| **Stock · inventario** | **100 %** | 9 de 9 | 🟢 terminado y en producción hace meses |
| **Stock · bodega y reparto** | **86 %** | 6 de 7 | 🟢 falta el relleno automático |
| **Lama · mesas** | **100 %** | 7 de 7 | 🟢 |
| **Lama · comanda** | **100 %** | 5 de 5 | 🟢 |
| **Lama · cobro** | **100 %** | 8 de 8 | 🟢 cerrado con la F1 |
| **Lama · configuración** | **83 %** | 5 de 6 | 🟢 **hecha** · falta el detalle del ticket, que depende de F5 |
| **Lama · mostrador** | **0 %** | 0 de 4 | 🟡 **maqueta escrita** · espera tu visto bueno |
| **Lama · impresión** | **10 %** | medido, sin construir | ⬜ necesita ir al local |
| **Lama · arqueo de caja** | **0 %** | 0 de 5 | 🟡 **maqueta escrita** · espera tu visto bueno |
| **Conexión Lama ↔ Stock** | **0 %** | 0 de 3 | ⬜ va última a propósito |
| **Producto multi-cliente** | **0 %** | 0 de 4 | ⬜ no empezado |

---

## El detalle de cada área

### Stock · inventario — 9 de 9 🟢

Productos y secciones · stock con tope en cero · perecederos por fechas ·
mermas · recetas · motor de descuento desde Fudo · metas de venta · historial
y foto diaria · permisos.

**Deuda conocida:** `estetica-no-rompio-nada` en rojo (4 casos de la gráfica de
metas). Es vieja y está aislada.

### Stock · bodega y reparto — 6 de 7 🟢

Bodega `central` · enlaces entre bodega y locales · armar reparto · recibir y
descontar · origen del producto (bodega / proveedor / otra sede) · envíos a
franquicias. **Falta:** el relleno automático a partir del crítico.

### Lama · mesas — 7 de 7 🟢

Plano con los tres colores · abrir y cerrar a mano · mover la mesa · mover
productos · el riel del teléfono · el tamaño ajustable · **reordenar en la
grilla** (opción A, elegida el 2026-09-03).

### Lama · comanda — 5 de 5 🟢

Buscador en el panel · carta completa con `− n +` · comentario por producto ·
confirmar manda a cocina · anular con motivo (lo comandado no se edita).

### Lama · cobro — 8 de 8 🟢

Ventana emergente · medios de pago · descuento (panel y cobro, un solo dueño) ·
propina al 10 % que nace puesta · vuelto nunca negativo · **cobro parcial por
producto** · la precuenta bloquea agregar · los tres símbolos del teléfono.

### Lama · configuración — 5 de 6 🟢 *hecha el 2026-09-04*

✅ Medios de pago · ✅ motivos de descuento · ✅ motivos de anulación ·
✅ **el descuento de los 5 consumos internos** (los escribe Jhon en la
pantalla) · ✅ lo anulado del día · ⬜ qué detalle lleva el ticket.

**Salió sin una línea de SQL**, como estaba previsto. Lo único que falta
depende de **F5**: decidir qué lleva el ticket antes de que exista el puente de
impresión es decidir a ciegas cómo se ve algo que todavía no imprime.

### Lama · mostrador — 0 de 4 🟡

Vender sin mesa · varias ventas a la vez · cobro directo · el ticket.

**La maqueta ya está escrita** y espera tu visto bueno:
[`docs/propuesta-lama-mostrador.html`](propuesta-lama-mostrador.html). Sigue en
0 de 4 a propósito — una maqueta no es una pieza construida.

⚠️ **Tiene un costo en la base**, y la maqueta lo compara: `cuentas.mesa_id` es
obligatorio y el candado `cuentas_una_viva_por_mesa` prohíbe dos cuentas vivas
en la misma mesa — en mostrador hay muchas a la vez.

### Lama · impresión — medido, sin construir ⬜

**Lo medido ya vale**: la impresora habla ESC/POS, está instalada, y se
comprobó **en el local** que el navegador no puede tomarla — las dos puertas
(USB y serie) están cerradas por Windows, no por Fudo.

**Falta el puente**: un programa chico en el computador del local que se
suscriba a Supabase y le pida a Windows que imprima. Va **aislado**: si falla,
que falle solo.

### Lama · arqueo de caja — 0 de 5 🟡 *desbloqueado el 2026-09-04*

Abrir y cerrar turno · efectivo contado vs. calculado · sobrantes y faltantes ·
arqueo ciego · el informe del turno.

✅ **El atlas ya contestó las tres preguntas del bloque H.** Se sabe el ciclo
completo, la fórmula del efectivo esperado, que el cierre es **irreversible**,
que puede haber varios arqueos abiertos a la vez, y que si se olvidaron de
abrirlo se puede abrir con hora hacia atrás.

**La maqueta ya está escrita** y espera tu visto bueno:
[`docs/propuesta-lama-arqueo.html`](propuesta-lama-arqueo.html). Sigue en 0 de 5
a propósito — una maqueta no es una pieza construida.

⚠️ **Trae tres preguntas para Jhon**, y una es urgente: **cuántas cajas físicas
hay en cada local**, porque cambia la forma de la tabla y después se paga
migrando datos. Las otras dos son el *arqueo ciego* —que en Fudo es un permiso
por rol y Llamita no tiene roles a propósito (§6.1)— y quién puede abrir y
cerrar.

### Conexión Lama ↔ Stock — 0 de 3 ⬜

Que cerrar una mesa descuente el inventario · que anular lo devuelva · leer
recetas desde Lama.

**Va última a propósito**, con interruptor. Hoy Lama **no toca el stock**, y eso
es lo que permite abrir y cerrar mesas veinte veces mientras se prueba. El día
que se conecten, esa libertad se acaba.

### Producto multi-cliente — 0 de 4 ⬜

Sacar la dirección de la base de adentro del código · un despliegue por cliente
· limpiar los datos de Café del Desierto · la lista de SQL a correr en cada
cliente.

**La primera es de dos líneas** (`index.html:3194-3195`) y es la que convierte
"mi app" en "un producto". El detalle está en `docs/primer-cliente.md`.

---

## Lo que hoy espera a Jhon, y no a Claude

| Qué | Desbloquea |
|---|---|
| ~~Las 3 preguntas del bloque H~~ | ✅ **hecho el 2026-09-04** |
| **Decidir el arqueo ciego** — Fudo lo hace con roles y Llamita no tiene | que F6 arranque sin frenarse a mitad |
| Desplegar las **11 Edge Functions** | los crons: la foto diaria y la limpieza |
| Una **visita al local** con el puente instalado | la impresión |
| Aprobar la maqueta de **mostrador** ([ya está escrita](propuesta-lama-mostrador.html)) | el mostrador |
