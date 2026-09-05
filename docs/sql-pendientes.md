# SQL pendientes de pegar en Supabase

> **Para qué existe.** El SQL llegaba en mensajes de chat, y entre varios se
> te confundía cuál ya habías corrido y cuál no. Este es **el único lugar**
> donde se sabe qué falta — y **el SQL completo está acá mismo**, no en otro
> archivo al que haya que saltar. Tocas "▶ Ver el SQL completo", lo copias
> entero, lo pegas en Supabase.
>
> **Link fijo para guardar** (este, no el de una rama de trabajo — esa puede
> cambiar de nombre; `master` no):
> `https://github.com/leoalejoleo1537/llamita-plus/blob/master/docs/sql-pendientes.md`
>
> ⚠️ **Corregido el 2026-09-03.** Apuntaba a `inventario-mall-plaza`, que es el
> repositorio de Café del Desierto y quedó congelado. Este archivo es el de
> **Llamita Plus**.
>
> **Las dos sesiones (Stock y Lama) agregan acá** apenas dejan un `.sql`
> nuevo listo para correr, **con el texto completo pegado**, no solo el
> nombre del archivo. Vos marcás `[x]` y la fecha cuando lo pegás.
>
> **El orden de la lista importa.** Si dos items dependen uno del otro, van
> en el orden en que hay que correrlos, y se dice por qué.

---

## Pendientes ahora

### [ ] `sql/2026-09-plus-comprobacion-fase6.sql` — cierra la separación

> **No escribe nada. Son dos `select`.** Se puede correr las veces que sea.

**Por qué importa, y no es burocracia.** El `README.md` decía que la copia está
separada, y **todo indica que sí** — el código no nombra el proyecto de ellos por
ninguna parte, y la app corre contra la base nueva. Pero eso son indicios, no la
comprobación. **La Fase 6 del plan de separación nunca se corrió**, y el propio
plan la llama *"la fase más importante: creo que quedó separado no es una
respuesta"*.

**Cómo se corre:** **2 bloques, uno por uno.** El editor de Supabase solo muestra
el resultado del último, así que juntos se pierde el primero.

**Qué mirar:**

| Bloque | Qué ver | Qué significa |
|---|---|---|
| 1 | **CERO filas** | ningún cron llama a la casa de Café del Desierto |
| 2 | **44 · 76 · 60 · 5 · 1434** | el respaldo llegó completo. Si algún número es **menor**, avisá |

⚠️ **Los `crons` pueden dar 0 y está bien:** no viajaron en el respaldo, se
rehacen cuando estén desplegadas las Edge Functions.

<details><summary>▶ Ver el SQL completo</summary>

```sql
-- ================================================================
-- BLOQUE 1 — ¿Algún cron sigue llamando al proyecto viejo?
-- QUÉ VER: CERO FILAS. Si aparece alguna, avisá antes de tocar nada.
-- ================================================================
select jobname, left(command, 120) as empieza_asi
  from cron.job
 where command like '%fqjdecjsbnicvyrxkxcu%';
```

```sql
-- ================================================================
-- BLOQUE 2 — ¿El respaldo llegó completo?
-- QUÉ VER: 44 tablas · 76 funciones · 60 políticas · 5 crons · 1434 productos.
-- ================================================================
select
  (select count(*) from information_schema.tables where table_schema='public') as tablas,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public') as funciones,
  (select count(*) from pg_policies where schemaname='public') as politicas,
  (select count(*) from cron.job) as crons,
  (select count(*) from public.productos) as productos;
```

</details>

---

### [ ] Y una prueba que NO es SQL — la que de verdad prueba

**Es el punto (c) de la Fase 6, y ningún `select` lo reemplaza.** Tarda dos
minutos y no necesita herramientas de desarrollador:

1. En **la app nueva**, crear un producto llamado **`ZZZ PRUEBA COPIA`**.
2. Abrir el **editor de tablas** de Supabase, tabla `productos`, y buscarlo:
   - en el proyecto **nuevo** (`iuryhsjucblmebdogewa`) → **tiene que aparecer**
   - en el proyecto **viejo** (`fqjdecjsbnicvyrxkxcu`) → **NO puede aparecer**
3. Borrarlo de la base nueva.

⚠️ **Si aparece en los dos, o solo en el viejo: parar todo y avisar.** Es
literalmente lo que pediste el primer día — *"si aparece en la de ellos, paramos
todo"*.

---

Cuando cualquiera de las dos sesiones deje un `.sql` nuevo, aparece acá con el
texto completo pegado y un `[ ]` para marcar.

---

## Historial reciente

### [x] `sql/2026-09-plus-encender-tiempo-real.sql` — **corrido el 2026-09-04** ✅

> **Comprobado**: las seis tablas en `sí`, y `mesas`/`comandas` en `NO` como
> corresponde. **La app volvió a actualizarse sola.**

> **Qué arreglaba, y no era un detalle de Lama: era media app.** Las ocho
> tablas daban `NO`, o sea que la app **no actualizaba nada sola**.

Lo que hoy NO pasa, y debería:

| | |
|---|---|
| El stock | no cambia solo en la lista cuando alguien vende |
| Las fechas de los sándwiches | no se actualizan solas |
| Un reparto que llega | no avisa |
| **Dos teléfonos sobre la misma mesa** | **no se ven entre ellos** |

El último es el que muerde: si el segundo garzón no ve lo que agregó el
primero, **el cliente recibe el pedido dos veces**.

**Por qué faltaba:** el respaldo copió la casa entera con los muebles adentro,
pero no copió el cable del timbre. Todo está en su sitio; nadie se entera de
nada.

**Cómo se corre:** **2 bloques, uno por uno** (hay un tercero opcional). El
primero enciende, el segundo comprueba.

**Qué mirar:** en el bloque 2, las **seis** primeras tienen que decir `sí`.
`mesas` y `comandas` van a decir `NO` y **está bien**: están apagadas a
propósito, porque la app no las escucha y encender una tabla que nadie mira
gasta cuota a cambio de nada.

<details><summary>▶ Ver el SQL completo</summary>

```sql
-- ================================================================
-- BLOQUE 1 — Encender el timbre
-- ================================================================
alter publication supabase_realtime add table public.productos;
alter publication supabase_realtime add table public.producto_lotes;
alter publication supabase_realtime add table public.repartos;
alter publication supabase_realtime add table public.reparto_items;
alter publication supabase_realtime add table public.cuentas;
alter publication supabase_realtime add table public.cuenta_items;
```

```sql
-- ================================================================
-- BLOQUE 2 — Comprobar que quedó encendido
-- QUÉ VER: las seis primeras en "sí". mesas y comandas en NO está BIEN.
-- ================================================================
select
  t.tabla,
  case when p.tablename is null then 'NO' else 'sí' end as en_vivo,
  t.para_que
from (values
        ('productos',      'Stock · el número de stock cambia solo en la lista'),
        ('producto_lotes', 'Stock · las fechas de los sándwiches'),
        ('repartos',       'Stock · avisa que llegó un reparto'),
        ('reparto_items',  'Stock · las líneas de ese reparto'),
        ('cuentas',        'Lama · el color de la mesa y su total'),
        ('cuenta_items',   'Lama · los productos de la mesa'),
        ('mesas',          'Lama · APAGADA a propósito, nadie la escucha'),
        ('comandas',       'Lama · APAGADA a propósito, nadie la escucha')
     ) as t(tabla, para_que)
left join pg_publication_tables p
       on p.pubname    = 'supabase_realtime'
      and p.schemaname = 'public'
      and p.tablename  = t.tabla
order by en_vivo desc, t.tabla;
```

```sql
-- ================================================================
-- BLOQUE 3 — (opcional) ¿tus dos cuentas ven el área de ventas?
-- ================================================================
select
  correo,
  case when puede_lama then 'sí' else 'NO' end as ve_lama
from public.app_permisos
where correo in ('leoalejoleo1@gmail.com', 'leoalejoleo12@gmail.com')
order by correo;
```

</details>

**Cómo se comprueba de verdad, después de correrlo:** abrí la app en **dos
pestañas** del navegador sobre la misma mesa. Lo que agregues en una tiene que
aparecer solo en la otra. Si no aparece, el SQL no quedó.

---

### [x] 2 · `sql/2026-09-plus-donde-estamos-parados.sql` — *no escribe nada, solo mira* · **corrido el 2026-09-04**

> **Es una radiografía, no una operación.** Son dos `select`. No crea, no
> borra, no modifica una sola fila. Se puede correr las veces que sea.

> ### ✅ Lo que contestó, el 2026-09-04
>
> **Bloque 1 · las OCHO tablas dieron `NO`.** El tiempo real no viajó en el
> respaldo, ni para Lama ni para Stock. De ahí sale el pendiente N°1 de arriba,
> que es el arreglo.
>
> **Bloque 2 · nueve cuentas en `app_permisos`**, heredadas del respaldo — el
> equipo de Café del Desierto incluido. Sólo `leoalejoleo12@gmail.com` tenía
> `puede_lama`. Jhon se dio acceso a sus dos cuentas después de esta foto.
>
> ⚠️ **Y una cosa que conviene no perder de vista:** esos correos son de
> personas reales de Café del Desierto. Hoy no pueden entrar —sólo las dos
> cuentas de Jhon existen en el autenticador— pero **esas filas no pueden
> viajar a otro cliente**. Es el *"limpiar antes de vender"* del plan de
> separación, anotado y todavía sin ejecutar.

**Por qué hace falta.** La base de Llamita Plus nació de un respaldo. Un
respaldo copia la casa entera con los muebles adentro — pero **no copia el
cable del timbre**: la lista de qué tablas se transmiten en vivo a los
teléfonos. Todo está en su sitio, y cuando alguien toca la puerta, adentro no
suena nada.

Eso le importa a Lama más que a nada: dos garzones sobre la misma mesa tienen
que verse. Si el cable no está, el segundo no ve lo que agregó el primero.

**Cómo se corre:** son **2 bloques, uno por uno**. El editor de Supabase solo
muestra el resultado del último, así que si se pegan juntos se pierde el
primero.

**Qué mirar:**

| Bloque | La columna | Qué significa |
|---|---|---|
| 1 | `en_vivo` | `sí` = el timbre está conectado · `NO` = esa tabla no avisa a nadie |
| 2 | `ve_lama` | que **tu** correo esté ahí con `sí`, o la pestaña Mesas no existe para vos |

**Con la respuesta se decide qué arreglar.** El arreglo del timbre es de una
línea por tabla, pero **primero hay que saber cuáles faltan** — la regla de la
casa es que el estado de la base se consulta, no se supone.

⚠️ **Si tu correo no aparece en el bloque 2, no lo agregues por tu cuenta.**
Avisá y te paso la línea: es una fila nueva y conviene escribirla bien la
primera vez.

<details><summary>▶ Ver el SQL completo</summary>

```sql
-- ================================================================
-- BLOQUE 1 — ¿Qué tablas están "en vivo"?
-- ================================================================
select
  t.tabla,
  case when p.tablename is null then 'NO' else 'sí' end as en_vivo,
  t.para_que
from (values
        ('productos',      'Stock · el número de stock cambia solo en la lista'),
        ('producto_lotes', 'Stock · las fechas de los sándwiches'),
        ('repartos',       'Stock · avisa que llegó un reparto'),
        ('reparto_items',  'Stock · las líneas de ese reparto'),
        ('mesas',          'Lama · el plano del salón'),
        ('cuentas',        'Lama · el color de la mesa y su total'),
        ('cuenta_items',   'Lama · los productos de la mesa'),
        ('comandas',       'Lama · los papeles que salieron a la cocina')
     ) as t(tabla, para_que)
left join pg_publication_tables p
       on p.pubname    = 'supabase_realtime'
      and p.schemaname = 'public'
      and p.tablename  = t.tabla
order by en_vivo, t.tabla;
```

```sql
-- ================================================================
-- BLOQUE 2 — ¿Quién puede ver el área de ventas?
-- ================================================================
select
  correo,
  nombre,
  case when puede_lama    then 'sí' else 'NO' end as ve_lama,
  case when puede_ajustes then 'sí' else 'NO' end as entra_a_ajustes
from public.app_permisos
order by puede_lama desc, correo;
```

</details>

---

## Cómo se marca uno como hecho

Marcás el `[ ]` por `[x]` y completás la fecha, o le decís a cualquiera de
las dos sesiones "ya corrí tal archivo" y ella lo hace por vos.

---

## Historial (lo que ya se corrió)

> **Por qué acá queda el nombre y no el SQL entero.** Los tres traían el texto
> completo pegado —793 líneas— para que no tuvieras que saltar a otro archivo.
> Una vez corridos eso deja de servir y solo estorba: **el archivo sigue en
> `sql/`, igual que siempre.** Si alguna vez hay que volver a mirarlo o
> re-correrlo, está ahí. Los tres son seguros de re-correr (`if not exists` /
> `on conflict`).

| Corrido | Archivo | Qué dejó |
|---|---|---|
| **2026-09-02** | `sql/2026-08-lama-cierre.sql` | El cierre de mesa. Tablas `lama_medios_pago` (12 medios, 5 de ellos consumos internos), `lama_motivos_descuento`, `cuenta_pagos` y `cuenta_propinas`; las columnas congeladas de `cuentas` (`subtotal`, `descuento*`, `propina`, `pagado`, `vuelto`); y la función **`cuenta_cobrar`**. No toca el inventario |
| **2026-09-02** | `sql/2026-09-lama-anulacion.sql` | Anular un producto ya comandado. Tabla `lama_motivos_anulacion`, las columnas `anulado_*` de `cuenta_items`, y la función **`item_anular`**. Reemplaza `cuenta_recalcular` y `cuenta_cobrar` con **la misma firma**, para que lo anulado deje de sumar en los dos lugares |
| **2026-09-02** | `sql/2026-09-lama-pago-parcial.sql` | **El pago parcial por producto (A1).** `cuenta_items.cantidad_pagada` con su `check`, `cuenta_pagos.parcial`, la tabla `cuenta_pago_items`, y las funciones `cuenta_cobrar_parcial` y `cuenta_pago_parcial_deshacer`. Reemplaza `cuenta_cobrar` (para que el cierre **no borre** los cobros parciales y congele la venta entera), `item_anular` e `items_mover` (para que no se anule ni se mueva lo ya cobrado). Corrido en 3 bloques, sin errores |
| **2026-09-02** | `sql/2026-08-metas-cuentan-por-sede.sql` | Arregla el conteo de las metas de venta por sede (el error del agua Bosqua/Angamos). Es de **Llamita Stock**, no de Lama |

**Lo que esto desbloqueó:** con `cuenta_cobrar` puesta, la ventana de cobro deja
de avisar que el medio de pago, la propina y el descuento no van a quedar
registrados — ahora sí quedan. Y **C5 (descuento) y A1 (pago parcial)** dejaron
de estar bloqueados. La ruta de Lama está en
[`docs/LAMA.md`](LAMA.md).
