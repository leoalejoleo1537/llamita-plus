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
| **Lama · el plano de mesas** | **100 %** | 5 de 5 | 🟢 **terminado** |
| **Lama · impresión** | **83 %** | 5 de 6 | 🟡 **falta ir al local** · todo lo demás está |
| **Lama · arqueo de caja** | **100 %** | 5 de 5 | 🟢 reconstruido y el `.sql` ya está corrido |
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

### Lama · el plano de mesas — 5 de 5 🟢

Páginas · secciones en tarjetas · modo edición · forma y tamaño por mesa · los
candados de una mesa con cuenta abierta.

✅ **Vender para llevar dejó de ser un problema el 2026-09-05.** Jhon eligió la
mesa especial, y la objeción técnica no aplicaba: la mesa 12 se cobra al
instante, así que nunca hay dos para llevar a la vez. **Eso no cuesta ni una
línea de SQL.**

**Lo que sí había que construir era el plano editable, y está.** Maqueta
aprobada el 2026-09-05, `.sql` corrido, pantalla publicada:

| Pieza | |
|---|---|
| El `.sql` con páginas y secciones | ✅ |
| El plano agrupado en secciones de color | ✅ |
| El modo edición (crear, renombrar, mover, quitar) | ✅ |
| Forma y tamaño por mesa | ✅ redonda, larga, chica y grande se dibujan en el plano de computador. **En el teléfono el tamaño no se aplica a propósito**: en un riel de 66 px una mesa grande empujaría a las demás fuera de la vista |
| Reordenar secciones — **con flechas, no arrastrando** | ✅ misma decisión que Configuración: en un teléfono arrastrar falla más de lo que acierta |

Prueba: `pruebas/lama-plano.mjs`, 38 casos.

### Lama · impresión — 5 de 6 🟡

**Lo medido ya vale**: la impresora habla ESC/POS, está instalada, y se
comprobó **en el local** que el navegador no puede tomarla — las dos puertas
(USB y serie) están cerradas por Windows, no por Fudo.

**El puente ya está escrito** (`puente/`), y va **aislado**: no sabe nada de
inventario ni de ventas, así que si falla, falla solo.

| Pieza | |
|---|---|
| La cola `lama_impresiones` | ✅ corrida y en vivo el 2026-09-06 |
| La app encola los tres papeles | ✅ |
| El programa del puente | ✅ escrito |
| **Ajustes → Impresión** · ver la cola y el papel entero | ✅ **así se prueba comandar sin impresora** |
| Reimprimir un ticket | ✅ manda una copia, no revive la vieja |
| **Probarlo contra la impresora** | ⬜ **hace falta ir al local** → [el paso a paso](plan-visita-al-local.html) |

**Fuera de la cuenta y esperando a Jhon:** el detalle del ticket (lo que deja
Configuración en 5 de 6) necesita sus fotos de las comandas de verdad.

⚠️ **El puente nunca habló con la impresora de verdad.** Lo probado es el texto
del programa —el BOM, el avance antes del corte, que no borre filas—, no el
encaje con Windows. Las dos cosas no son lo mismo (§0.5).

🟢 **Y el 2026-09-07 dejó de necesitar Node.** El cliente no instala nada:
Windows ya trae PowerShell. Tres archivos, un doble clic, la impresora se elige
de una lista. Ver [`docs/la-impresora.md`](la-impresora.md).

### Lama · arqueo de caja — 5 de 5 🟢 *cerrada el 2026-09-21*

Abrir y cerrar turno · efectivo contado vs. calculado · sobrantes y
faltantes · arqueo ciego (interruptor en Ajustes) · el historial de arqueos.

Las tres preguntas de la maqueta las contestó Jhon el 2026-09-21: el arqueo
ciego es un interruptor por sede en Ajustes → Interruptores (apagado de
fábrica), una sola caja por sede sin selector, y cualquiera que entre a
Mesas puede abrir y cerrar con su nombre escrito.

**Lo que hay:** el aviso arriba del plano cuando la caja no está abierta ·
abrir con el monto inicial · la tarjeta del turno con lo cobrado por medio y
el total esperado · movimientos de mano (ingreso/egreso, con nota) · cerrar
contando el efectivo, con o sin el arqueo ciego · el candado que impide
anular una venta de un arqueo ya cerrado · **"Ver arqueos anteriores"**, de
solo lectura — un arqueo cerrado no se reabre jamás, así que la pantalla no
ofrece ni un botón que lo intente.

✅ **El `.sql` ya está corrido** (2026-09-21) — bloque 8 confirmó "1 firma"
en las cuatro funciones y las tablas nuevas en 0 filas. **El arqueo está vivo
en Mesas**, de punta a punta.

🟢 **2026-09-22 · dos pestañas propias, como en Fudo.** Jhon pidió que el
arqueo tuviera su propia página —historial completo + detalle por
turno—, en vez de vivir solo escondido detrás de un enlace en Mesas.
Quedaron **"Arqueo"** (la lista de todos los turnos con su diferencia, y al
tocar uno el detalle: monto inicial, lo cobrado por medio separado en
ventas y propinas —igual que la pantalla real de Fudo—, movimientos de
mano, total) y **"Movimientos"** (el libro de ingresos/egresos de mano,
con su propio formulario para anotar uno, sin tener que pasar por Mesas).
Abrir y cerrar la caja **siguen viviendo solo en Mesas** — a propósito, un
turno se abre parado frente al mesón, no revisando un historial.

⚠️ **Bug de arrastre encontrado y corregido el mismo día:** una página del
plano con cero mesas (como "ADM" recién creada) no dejaba agregar ninguna
en modo edición — el cartel de "esta página no tiene mesas" se dibujaba
ANTES de llegar al código que pinta el "+" de agregar. Con el modo edición
puesto, ahora sí se llega a esa parte del dibujo aunque la página esté
vacía.

🔴 **2026-09-22 · reconstruido entero, porque la primera versión estaba
mal.** Jhon la usó, comparó contra capturas de la pantalla REAL de Fudo, y
encontró que el arqueo solo miraba el efectivo — Fudo compara **cada medio
de pago por separado** (efectivo, débito, crédito…) contra su propio
"según sistema", y la diferencia final es la SUMA de todas. Antes de
tocar una línea, le mandé a NotebookLM (que tiene toda la info real de
Fudo) las cinco preguntas que hacían falta para no adivinar de nuevo.

**Lo que cambió de fondo:**
- `arqueo_cerrar()` ya no pide un solo número de efectivo: recorre cada
  medio que tuvo ventas (más 'efectivo', siempre, aunque no se haya
  vendido nada — el fondo de cambio ya está ahí para contar), compara su
  "sistema" contra lo declarado, y suma las diferencias.
- Nueva tabla `lama_arqueo_declarado`: el cajero puede escribir cuánto
  hay de CADA medio **mientras la caja sigue abierta**, no solo al
  cerrar — y a diferencia de Fudo, que pierde ese conteo si se recarga
  la página (confirmado por NotebookLM), acá se guarda apenas se tipea.
- Un medio que nadie declaró se autocompleta igual al sistema —el
  comportamiento de fábrica de Fudo para tarjetas—, así que su
  diferencia da $0 sola.
- Nueva tabla `lama_arqueo_cierre_medios`: el desglose congelado por
  medio (ventas, propinas, sistema, usuario, diferencia), para el
  detalle que se ve después de cerrado.
- La tarjeta del turno en Mesas y el detalle de la página Arqueo ahora
  muestran la MISMA tabla editable de "cuánto hay de cada medio", en vivo,
  con o sin el arqueo ciego.

✅ **El `.sql` ya está corrido** (2026-09-22) — bloque 8 confirmó "1 firma"
en las tres funciones y las dos tablas nuevas en 0 filas. **El arqueo por
medio está vivo**, de punta a punta.

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

> ⚠️ **Esta tabla se sacó el 2026-09-08.** Vivía duplicada acá y en la bandeja
> **🔴 PREGUNTAS QUE ESPERAN A JHON** de `docs/LAMA.md`, y las dos se
> desincronizaron — esta seguía pidiendo el arqueo ciego (ya contestado en
> parte y no bloqueante) y el plano de mesas (aprobado y construido). **La
> bandeja de `LAMA.md` es la única fuente** — se lee ahí, no se copia acá.
