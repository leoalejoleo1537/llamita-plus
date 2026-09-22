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

### [ ] `sql/2026-09-lama-arqueo-fudo.sql` — el arqueo compara CADA medio de pago

--  DÓNDE VA:  Supabase -> SQL Editor -> New query
--  ES:        1 solo bloque
--  TARDA:     instantáneo
--  QUÉ HACE:  cambia CÓMO se cierra el arqueo: ahora compara cada medio de
--             pago (efectivo, débito, crédito...) contra su propio "según
--             sistema" por separado — igual que la pantalla real de Fudo—,
--             en vez de solo el efectivo. Agrega la tabla donde se declara
--             cuánto hay de cada medio MIENTRAS la caja sigue abierta.
--  QUÉ VER:   el bloque final tiene que decir, para cada función, "1
--             firma". Si alguna dice 2, avisame antes de usar la
--             pantalla — no la uses todavía.

**Reemplaza al arqueo que ya está andando** (`sql/2026-09-lama-arqueo.sql`,
corrido el 21). Ese primer arqueo solo miraba el efectivo — vos lo probaste
y me hiciste notar, con las capturas de la pantalla real de Fudo, que ahí
se compara CADA medio (efectivo, débito, crédito, lo que sea) contra su
propio sistema, y la diferencia final es la suma de todas. Le pregunté a
NotebookLM los detalles que me faltaban y esto ya los tiene adentro.

**Nada de lo que ya usaste se pierde**: las cajas que abriste y cerraste
siguen ahí. Este `.sql` solo agrega tablas y columnas nuevas, y reemplaza
la función de cerrar por una que sabe hacer la cuenta completa.

<details><summary>▶ Ver el SQL completo</summary>

```sql
-- ================================================================
--  LLAMITA LAMA · EL ARQUEO DE CAJA, VERSIÓN FUDO (v2)
--
--  DÓNDE VA:  Supabase -> SQL Editor -> New query
--  ES:        1 solo bloque. Copiar TODO, pegar, apretar Run.
--  TARDA:     instantáneo
--  SEGURO DE RE-CORRER: sí.
--
--  QUÉ HACE:  cambia CÓMO se cierra el arqueo, para que compare cada
--             medio de pago por separado contra su propio "según
--             sistema" —igual que la pantalla real de Fudo—, en vez de
--             solo el efectivo. Agrega la tabla donde el cajero declara
--             cuánto hay de cada medio MIENTRAS la caja sigue abierta.
--
--  LA DIFERENCIA A PROPÓSITO CON FUDO: acá lo que se tipea en "Según
--  usuario" se GUARDA apenas se escribe, no solo al cerrar. Fudo lo
--  pierde si recargás la página antes de terminar — es una limitación de
--  ellos (confirmado por NotebookLM, 2026-09-22), no algo que convenga
--  copiar en un sistema que se usa desde el teléfono.
--
--  QUÉ VER AL TERMINAR: el bloque final tiene que decir, para cada
--  función, "1 firma". Si alguna dice 2, avisale a Claude antes de usar
--  la pantalla — no la uses todavía.
--
--  Contestado por NotebookLM (con toda la info de Fudo) el 2026-09-22:
--    1. La Diferencia final es la SUMA de la diferencia de cada medio,
--       no solo la del efectivo.
--    2. "Según Usuario" es editable con la caja abierta, pero Fudo no lo
--       guarda hasta cerrar — nosotros SÍ lo guardamos al tipear.
--    3. Un medio sin conteo manual se autocompleta igual al sistema (su
--       diferencia da $0 sola) — es el comportamiento de fábrica de Fudo
--       para tarjetas, y es el que copiamos acá para TODO medio que
--       nadie declaró a mano.
--    4. Cada medio de pago es su propio renglón, nunca agrupados.
--    5. Los movimientos de caja quedan atados a UN arqueo para siempre
--       (ya lo hacíamos así).
-- ================================================================


-- ----------------------------------------------------------------
-- 1) LA DECLARACIÓN POR MEDIO, mientras la caja sigue abierta
-- ----------------------------------------------------------------
create table if not exists public.lama_arqueo_declarado (
  id            bigserial primary key,
  arqueo_id     bigint  not null references public.lama_arqueos(id) on delete cascade,
  medio         text    not null,
  monto         numeric not null,
  declarado_por text,
  declarado_at  timestamptz not null default now(),
  constraint lama_arqueo_declarado_monto_ok check (monto >= 0),
  constraint lama_arqueo_declarado_un_medio unique (arqueo_id, medio)
);

alter table public.lama_arqueo_declarado enable row level security;
drop policy if exists "lama_arqueo_declarado all" on public.lama_arqueo_declarado;
create policy "lama_arqueo_declarado all" on public.lama_arqueo_declarado
  for all to anon, authenticated using (true) with check (true);
grant all on public.lama_arqueo_declarado to anon, authenticated;
grant usage, select on sequence public.lama_arqueo_declarado_id_seq to anon, authenticated;


-- ----------------------------------------------------------------
-- 2) LO CONGELADO AL CERRAR, un renglón por medio — la misma razón por la
-- que `cuentas.total` se congela: el arqueo de dentro de seis meses no
-- tiene por qué recalcular nada, y sirve para el detalle que Fudo abre al
-- tocar el nombre de un medio ("qué cobró ese canal ese turno").
-- ----------------------------------------------------------------
create table if not exists public.lama_arqueo_cierre_medios (
  id          bigserial primary key,
  arqueo_id   bigint  not null references public.lama_arqueos(id) on delete cascade,
  medio       text    not null,
  ventas      numeric not null default 0,
  propinas    numeric not null default 0,
  sistema     numeric not null default 0,
  usuario     numeric not null default 0,
  diferencia  numeric not null default 0,
  constraint lama_arqueo_cierre_medios_un_medio unique (arqueo_id, medio)
);
alter table public.lama_arqueo_cierre_medios enable row level security;
drop policy if exists "lama_arqueo_cierre_medios all" on public.lama_arqueo_cierre_medios;
create policy "lama_arqueo_cierre_medios all" on public.lama_arqueo_cierre_medios
  for all to anon, authenticated using (true) with check (true);
grant all on public.lama_arqueo_cierre_medios to anon, authenticated;
grant usage, select on sequence public.lama_arqueo_cierre_medios_id_seq to anon, authenticated;


-- ----------------------------------------------------------------
-- 3) TRES COLUMNAS NUEVAS EN `lama_arqueos` — el total consolidado de
-- TODOS los medios, separado del efectivo (que sigue existiendo tal cual:
-- es el cajón físico, con su fondo de cambio, y tiene sentido propio aparte
-- de la reconciliación general).
-- ----------------------------------------------------------------
alter table public.lama_arqueos add column if not exists total_esperado   numeric;
alter table public.lama_arqueos add column if not exists total_declarado  numeric;
alter table public.lama_arqueos add column if not exists diferencia_total numeric;


-- ----------------------------------------------------------------
-- 4) DECLARAR UN MEDIO — upsert por (arqueo_id, medio). Se puede llamar
-- todas las veces que haga falta mientras la caja sigue abierta.
-- ----------------------------------------------------------------
create or replace function public.arqueo_declarar(
  p_arqueo_id bigint,
  p_medio     text,
  p_monto     numeric,
  p_quien     text default null
) returns public.lama_arqueo_declarado
language plpgsql
security definer
set search_path = public
as $$
declare
  v_arqueo public.lama_arqueos;
  v_fila   public.lama_arqueo_declarado;
begin
  select * into v_arqueo from public.lama_arqueos where id = p_arqueo_id for update;
  if not found then
    raise exception 'Esa caja ya no existe.';
  end if;
  if v_arqueo.estado <> 'abierta' then
    raise exception 'Esa caja ya está cerrada.';
  end if;
  if p_monto is null or p_monto < 0 then
    raise exception 'El monto no puede ser negativo.';
  end if;
  if coalesce(btrim(p_medio), '') = '' then
    raise exception 'Falta decir de qué medio es este monto.';
  end if;

  insert into public.lama_arqueo_declarado (arqueo_id, medio, monto, declarado_por)
  values (p_arqueo_id, p_medio, p_monto, p_quien)
  on conflict (arqueo_id, medio) do update
    set monto = excluded.monto, declarado_por = excluded.declarado_por, declarado_at = now()
  returning * into v_fila;

  return v_fila;
end;
$$;


-- ----------------------------------------------------------------
-- 5) CERRAR LA CAJA, RECONCILIANDO CADA MEDIO POR SEPARADO
--
-- REEMPLAZA LA FUNCIÓN ANTERIOR ENTERA (§0.5): la de 4 argumentos
-- (…numeric, text, text) desaparece con un `drop` explícito, así no
-- quedan dos firmas conviviendo y la llamada por la API deja de ser
-- ambigua — es la falla que dejó el motor 15 horas sin descontar.
--
-- p_efectivo_contado deja de existir como parámetro: el efectivo es un
-- medio más, declarado por `arqueo_declarar` como cualquier otro. Un
-- medio que nadie declaró se autocompleta igual al sistema —el
-- comportamiento de fábrica de Fudo para tarjetas—, así que su
-- diferencia da $0 sola.
-- ----------------------------------------------------------------
drop function if exists public.arqueo_cerrar(bigint, numeric, text, text);

create or replace function public.arqueo_cerrar(
  p_arqueo_id  bigint,
  p_comentario text default null,
  p_quien      text default null
) returns public.lama_arqueos
language plpgsql
security definer
set search_path = public
as $$
declare
  v_arqueo    public.lama_arqueos;
  v_ingresos  numeric := 0;
  v_egresos   numeric := 0;
  v_medio     record;
  v_ventas    numeric;
  v_propinas  numeric;
  v_sistema   numeric;
  v_declarado numeric;
  v_total_sis numeric := 0;
  v_total_usr numeric := 0;
  v_ef_sis    numeric := 0;
  v_ef_usr    numeric := 0;
begin
  select * into v_arqueo from public.lama_arqueos where id = p_arqueo_id for update;
  if not found then
    raise exception 'Esa caja ya no existe.';
  end if;

  if v_arqueo.estado = 'cerrada' then
    return v_arqueo;
  end if;

  select coalesce(sum(monto) filter (where tipo = 'ingreso'), 0),
         coalesce(sum(monto) filter (where tipo = 'egreso'), 0)
    into v_ingresos, v_egresos
    from public.lama_caja_movimientos
   where arqueo_id = p_arqueo_id;

  delete from public.lama_arqueo_cierre_medios where arqueo_id = p_arqueo_id;

  -- Un renglón por cada medio que tuvo ventas, que alguien declaró, o
  -- 'efectivo' siempre — aunque no se haya vendido nada, el cajón físico
  -- ya tiene el fondo de cambio y hay que poder contarlo (es exactamente
  -- lo que muestra la pantalla real de Fudo con un turno recién abierto).
  for v_medio in
    select medio from (
      select cp.medio from public.cuenta_pagos cp join public.cuentas c on c.id = cp.cuenta_id
       where c.sede = v_arqueo.sede and cp.created_at >= v_arqueo.abierto_at
      union
      select cp.medio from public.cuenta_propinas cp join public.cuentas c on c.id = cp.cuenta_id
       where c.sede = v_arqueo.sede and cp.created_at >= v_arqueo.abierto_at
      union
      select medio from public.lama_arqueo_declarado where arqueo_id = p_arqueo_id
      union
      select 'efectivo'
    ) x
    group by medio
  loop
    select coalesce(sum(cp.monto), 0) into v_ventas
      from public.cuenta_pagos cp join public.cuentas c on c.id = cp.cuenta_id
     where c.sede = v_arqueo.sede and cp.medio = v_medio.medio
       and cp.created_at >= v_arqueo.abierto_at;
    select coalesce(sum(cp.monto), 0) into v_propinas
      from public.cuenta_propinas cp join public.cuentas c on c.id = cp.cuenta_id
     where c.sede = v_arqueo.sede and cp.medio = v_medio.medio
       and cp.created_at >= v_arqueo.abierto_at;
    v_sistema := v_ventas + v_propinas;

    -- El efectivo, y SOLO el efectivo, arrastra además el fondo inicial y
    -- los movimientos de mano: son plata que entra o sale del cajón
    -- físico, no una venta con medio de pago.
    if v_medio.medio = 'efectivo' then
      v_sistema := v_sistema + v_arqueo.monto_inicial + v_ingresos - v_egresos;
    end if;

    select monto into v_declarado
      from public.lama_arqueo_declarado
     where arqueo_id = p_arqueo_id and medio = v_medio.medio;
    if v_declarado is null then v_declarado := v_sistema; end if;   -- autocompleta, como Fudo

    insert into public.lama_arqueo_cierre_medios (arqueo_id, medio, ventas, propinas, sistema, usuario, diferencia)
    values (p_arqueo_id, v_medio.medio, v_ventas, v_propinas, v_sistema, v_declarado, v_declarado - v_sistema);

    v_total_sis := v_total_sis + v_sistema;
    v_total_usr := v_total_usr + v_declarado;
    if v_medio.medio = 'efectivo' then
      v_ef_sis := v_sistema; v_ef_usr := v_declarado;
    end if;
  end loop;

  update public.lama_arqueos
     set estado            = 'cerrada',
         cerrado_por       = p_quien,
         cerrado_at        = now(),
         comentario        = nullif(btrim(p_comentario), ''),
         efectivo_esperado = v_ef_sis,
         efectivo_contado  = v_ef_usr,
         diferencia        = v_ef_usr - v_ef_sis,
         total_esperado    = v_total_sis,
         total_declarado   = v_total_usr,
         diferencia_total  = v_total_usr - v_total_sis
   where id = p_arqueo_id
   returning * into v_arqueo;

  return v_arqueo;
end;
$$;


-- ----------------------------------------------------------------
-- 6) LOS PERMISOS
-- ----------------------------------------------------------------
grant execute on function public.arqueo_declarar(bigint,text,numeric,text) to anon, authenticated;
grant execute on function public.arqueo_cerrar(bigint,text,text)           to anon, authenticated;


-- ----------------------------------------------------------------
-- 7) EL CUADERNO
-- ----------------------------------------------------------------
insert into public.migraciones_aplicadas (archivo, quien, como_se_supo, nota)
values ('2026-09-lama-arqueo-fudo.sql', 'Jhon', 'lo corrió a mano en el SQL Editor',
        'El arqueo pasa a comparar CADA medio de pago contra su propio sistema (no solo efectivo), igual que la pantalla real de Fudo. Declarar un medio ya no espera al cierre: se guarda al tipear.')
on conflict (archivo) do update set aplicado_at = now(), nota = excluded.nota;


-- ----------------------------------------------------------------
-- 8) PARA COMPROBAR QUE QUEDÓ BIEN
-- ----------------------------------------------------------------
select 'arqueo_cerrar' as funcion,
       count(*) || ' firma' || case when count(*) = 1 then '' else 's ← PARAR' end as estado
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'arqueo_cerrar'
union all
select 'arqueo_declarar',
       count(*) || ' firma' || case when count(*) = 1 then '' else 's ← PARAR' end
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'arqueo_declarar'
union all
select 'arqueo_movimiento',
       count(*) || ' firma' || case when count(*) = 1 then '' else 's ← PARAR' end
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'arqueo_movimiento'
union all
select 'lama_arqueo_declarado (tabla)', count(*) || ' fila(s)'
  from public.lama_arqueo_declarado
union all
select 'lama_arqueo_cierre_medios (tabla)', count(*) || ' fila(s)'
  from public.lama_arqueo_cierre_medios;
```

</details>

---

Cuando cualquiera de las dos sesiones deje un `.sql` nuevo, aparece acá con el
texto completo pegado y un `[ ]` para marcar.

---

## Historial reciente

### [x] `sql/2026-09-lama-arqueo.sql` — **corrido el 2026-09-21** ✅

> **La caja del turno (F6), confirmada sana:** el bloque 8 devolvió "1 firma"
> en las cuatro funciones (`item_anular`, `arqueo_abrir`, `arqueo_movimiento`,
> `arqueo_cerrar`) y las dos tablas nuevas en 0 filas, como corresponde a un
> `create table` recién corrido. El arqueo ya está vivo en Mesas.

### [x] `sql/2026-09-lama-cola-de-impresion.sql` — **corrido el 2026-09-06** ✅

> **`lama_impresiones` quedó en vivo.** Con eso la app ya deja los papeles en el
> buzón y se pueden mirar en **Ajustes → Impresión**, con o sin impresora.

> **No urgente, y sin riesgo.** Crea una tabla nueva y no toca ninguna
> existente. **Sin el puente instalado, esta tabla junta papeles y no molesta
> a nadie** — no imprime nada por sí sola.

**Qué es, en una imagen.** La app no le habla a la impresora: **deja el papel
escrito en un buzón** y sigue con lo suyo. El programita del computador del
local está mirando ese buzón y saca lo que aparezca.

**Por qué así, y está medido en el local el 2026-09-01** (§2.3): el navegador
**no puede tomar la impresora** —Windows se queda con ella y no la suelta— y si
el garzón imprime desde el teléfono, una página en `https` tampoco puede llamar
a una dirección de la red local. La salida es que el puente **no reciba nada**:
que se suscriba y saque. Sin conexión entrante no hay firewall, ni IP que
averiguar, y funciona desde cualquier teléfono.

**Cómo se corre:** **3 bloques cortos, uno por uno.**

| Bloque | Qué ver |
|---|---|
| **1** | *"Success. No rows returned"* |
| **2** | *"Success"*. Si dice que ya está en la publicación, también está bien |
| **3** | `lama_impresiones` con **`en_vivo` = sí** |

⚠️ **El bloque 2 es el que importa.** Sin él el puente tendría que preguntar
cada pocos segundos si hay algo —gastando cuota y llegando tarde—. Con él,
Supabase le avisa.

<details><summary>▶ Ver el SQL completo</summary>

```sql
--  DÓNDE VA:  Supabase -> SQL Editor -> New query   (proyecto llamita-plus)
--  ES:        3 bloques cortos, uno por uno.
--  TARDA:     instantáneo.
--  QUÉ HACE:  crea la COLA DE IMPRESIÓN. La app deja el papel escrito acá; el
--             programita del computador del local lo saca y lo imprime.
--             NO imprime nada por sí solo — sin el puente instalado, esta
--             tabla simplemente junta papeles y no molesta a nadie.
--  QUÉ VER:   bloque 3 -> `lama_impresiones` diciendo "sí" en la columna
--             `en_vivo`. Sin eso el puente no se entera de nada.
--
--  POR QUÉ UNA COLA Y NO UNA CONEXIÓN DIRECTA (§2.3, medido en el local el
--  2026-09-01): el navegador NO puede tomar la impresora — Windows se queda
--  con ella y no la suelta. Y si el garzón imprime desde el teléfono, una
--  página en https tampoco puede llamar a una dirección de la red local.
--  La salida es que el puente no reciba nada: que se suscriba y saque lo que
--  aparezca. Sin conexión entrante no hay contenido mixto, ni firewall, ni IP
--  que averiguar, y funciona desde cualquier teléfono.


-- ================================================================
-- BLOQUE 1 — LA TABLA
-- QUÉ VER: "Success. No rows returned".
-- ================================================================
create table if not exists public.lama_impresiones (
  id         bigserial primary key,
  sede       text    not null,
  -- comanda = lo que va a prepararse · precuenta = el papel del cliente
  -- anulacion = el aviso de que algo YA COMANDADO se cayó
  tipo       text    not null,
  contenido  text    not null,
  estado     text    not null default 'pendiente',
  quien      text,
  cuenta_id  bigint,
  creada_at  timestamptz not null default now(),
  impresa_at timestamptz,
  error      text,
  constraint lama_impresiones_tipo_ok
    check (tipo in ('comanda','precuenta','anulacion','prueba')),
  constraint lama_impresiones_estado_ok
    check (estado in ('pendiente','impresa','error'))
);
create index if not exists lama_impresiones_cola_idx
  on public.lama_impresiones (sede, estado, creada_at);

alter table public.lama_impresiones enable row level security;
drop policy if exists "lama_impresiones all" on public.lama_impresiones;
create policy "lama_impresiones all" on public.lama_impresiones
  for all to anon, authenticated using (true) with check (true);
grant all on public.lama_impresiones to anon, authenticated;
grant usage, select on sequence public.lama_impresiones_id_seq to anon, authenticated;


-- ================================================================
-- BLOQUE 2 — ENCENDER EL TIMBRE PARA ESTA TABLA
-- QUÉ VER: "Success". Si dice que ya está en la publicación, también está bien.
--
-- Sin esto el puente tendría que preguntar cada pocos segundos si hay algo
-- —gastando cuota y llegando tarde—. Con esto, Supabase le avisa.
-- ================================================================
alter publication supabase_realtime add table public.lama_impresiones;


-- ================================================================
-- BLOQUE 3 — COMPROBAR
-- QUÉ VER: una fila, `lama_impresiones`, con `en_vivo` = sí.
-- ================================================================
select 'lama_impresiones' as tabla,
       case when exists (
         select 1 from pg_publication_tables
          where pubname = 'supabase_realtime'
            and schemaname = 'public'
            and tablename = 'lama_impresiones') then 'sí' else 'NO' end as en_vivo;
```

</details>

---


### [x] `sql/2026-09-plus-comprobacion-fase6.sql` — **corrido el 2026-09-05** ✅

> **No escribe nada. Es un `select`.** Se puede correr las veces que sea.

🔴 **Se rompió tres veces por el mismo error, y era mío: preguntaba por
`cron.job`.** `pg_cron` es una extensión de Postgres, y en este proyecto **no
está instalada** — el respaldo no la trajo. Postgres analiza la sentencia entera
antes de ejecutarla, así que una tabla que no existe **mata el bloque completo**,
aunque el resto esté perfecto. Es la §0.1.9 del archivo madre.

**Y el error ya contestó la pregunta:** sin `pg_cron` no existe ningún cron en
esta base, así que **ninguno puede estar llamando al proyecto de Café del
Desierto**. El punto (a) de la Fase 6 queda cerrado. ✅

> ### ✅ Lo que contestó
>
> **Las 32 funciones que la app llama están puestas.** La lista traía una fila
> de más —`cuenta_abrir`— que dio `FALTA`, y **era un error mío**: esa función
> no existe ni la llama nadie. La que abre una mesa se llama **`mesa_abrir`**, y
> esa sí está. La escribí de memoria en vez de sacarla del código, que es
> exactamente la §0.1.9 del archivo madre. Ya está sacada de la lista.
>
> **Con esto la estructura queda comprobada** de la única forma que sirve: por
> nombre, no por conteo.

**Lo que queda por comprobar es mejor que un conteo.** El conteo a secas decía
*"faltan 31 funciones"* sin decir cuáles, y encima nuestras propias notas no se
ponían de acuerdo sobre la vara (el plan dice 76, el `README` dice 45 verificadas
contra el original). **Este `select` pregunta por las 33 funciones que la app
llama de verdad**, una por una.

**Qué mirar:** la columna `esta` tiene que decir **`sí` en las 32 filas**. Si
alguna dice `FALTA`, esa es la que hay que rehacer — y sabemos exactamente cuál.

<details><summary>▶ Ver el SQL completo</summary>

```sql
select
  f.nombre,
  case when p.proname is null then 'FALTA' else 'sí' end as esta
from (values
   ('mesa_abrir'),('cuenta_agregar'),('cuenta_confirmar'),
   ('cuenta_recalcular'),('cuenta_precuenta'),('cuenta_cerrar'),('cuenta_cobrar'),
   ('cuenta_cobrar_parcial'),('cuenta_pago_parcial_deshacer'),('cuenta_mover'),
   ('items_mover'),('item_anular'),
   ('mermar'),('deshacer_merma'),('registrar_entrada'),('deshacer_entrada'),
   ('fusionar_productos'),('deshacer_fusion'),('restaurar_sede'),
   ('deshacer_restauracion'),('crear_producto_enlazado'),
   ('reparto_recibir'),('reparto_cerrar'),('reparto_rechazar'),
   ('reparto_deshacer'),('reparto_descontar_bodega'),
   ('historial_dias'),('fotos_por_dia'),('meta_avance'),('recetas_rotas'),
   ('franquicia_linea_lista'),('franquicia_linea_no_hay')
) as f(nombre)
left join (
  select distinct p.proname
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
) p on p.proname = f.nombre
order by esta, f.nombre;
```

</details>

---

> **El resultado tal cual salió** lo pegó Jhon acá el 2026-09-05, y se resume
> arriba en vez de dejar el volcado entero: 33 filas de JSON en el archivo que
> se lee para saber *qué falta correr* lo vuelven ilegible. **Queda en la
> historia de git**, en el commit `4c450ac`, si alguna vez hay que mirarlo
> literal.


### [x] La prueba `ZZZ PRUEBA COPIA` — **cerrada el 2026-09-05** ✅

> ### ✅ EL RESULTADO, y es el que queríamos
>
> En la base de Café del Desierto **solo están las dos pruebas viejas** (ids
> 1279 y 1280, un `zzz ejemplo 1` que quedó de un chat antiguo y viajó en el
> respaldo). **Los tres productos creados el 2026-09-05 — ids 1468, 1469 y
> 1470 — no llegaron ahí.**
>
> **La copia está separada, comprobado y no prometido.** La Fase 6 se cierra.
>
> ⚠️ **Y el susto que hubo en el medio vale escribirlo.** La primera corrida
> "en el proyecto viejo" devolvió los cinco productos, ids idénticos incluidos,
> y parecía que la app escribía en las dos bases. **No había cambiado de
> proyecto**: el editor de Supabase **no dice en la pantalla en cuál estás**.
> Lo que lo destrabó no fue deducirlo — fue una consulta que le pregunta a la
> base **quién es** (si tiene `pg_cron` es la vieja, si no es Plus). *Cuando dos
> explicaciones encajan con la misma evidencia, la salida es una medición que
> las separe, no un razonamiento más largo.*

**Lo que pasó antes:** creaste el producto en Llamita Plus, **apareció
en la app**, y **NO apareció en Llamita Stock**. Eso ya era una señal fuerte.

⚠️ **Pero no lo encontraste en el editor de tablas, y eso NO significa que no
esté: el editor muestra de a 100 filas.** Hay 1.434 productos, así que
`ZZZ PRUEBA COPIA` está en alguna página que no miraste. **No es una
coincidencia, es la paginación** — y por eso no se puede concluir nada de no
haberlo visto ahí.

**Cómo se remata, y son dos consultas de una línea.** La primera va en
**Llamita Plus**, la segunda en el proyecto **viejo**. Las dos son `select`:
**no escriben ni una fila**.

```sql
-- ACÁ, en llamita-plus (iuryhsjucblmebdogewa)
-- QUÉ VER: la fila. Si no aparece, avisá — algo raro pasa.
select id, producto, sede, activo from public.productos
 where producto ilike '%ZZZ%';
```

```sql
-- ALLÁ, en el proyecto de Café del Desierto (fqjdecjsbnicvyrxkxcu)
-- QUÉ VER: CERO FILAS. Si aparece algo, parar todo y avisar.
select id, producto, sede from public.productos
 where producto ilike '%ZZZ%';
```

⚠️ **La segunda es la única vez que se toca la base de ellos, y es de solo
lectura** — la pide el propio plan de separación, punto (c) de la Fase 6.
**No corras nada más ahí.**

**Y cuando las dos den lo esperado:** borrá el producto de prueba en Llamita
Plus, desde la app, como cualquier otro.

---

Cuando cualquiera de las dos sesiones deje un `.sql` nuevo, aparece acá con el
texto completo pegado y un `[ ]` para marcar.

---

### [x] `sql/2026-09-lama-plano-editable.sql` — **corrido el 2026-09-05** ✅

> ### ✅ Lo que dejó
>
> | | |
> |---|---|
> | Números repetidos entre salones | **ninguno** — el freno del bloque 1 pasó |
> | Lo que había | **solo Plaza tiene mesas**: 12, numeradas 1 a 12, todas en "Salón". Angamos y Bodega no tienen ninguna |
> | Cómo quedó | página **Salón** → sección **Salón** → las 12 mesas. `sin_area` = **0** |
>
> ⚠️ **El bloque 3 falló la primera vez, y el error era mío.** `padre_id` es
> `bigint` y yo escribí un `null` pelado: **dentro de un `insert ... select`,
> Postgres NO deduce el tipo de la columna de destino** — ahí un `null` nace
> como TEXTO. Va `null::bigint`. Ya está corregido acá y en `sql/`.
>
> **Y contesta sola la pregunta que quedaba pendiente:** Angamos **no tiene
> mesas cargadas**, así que no hay nada que repartir allá. Se crean desde el
> modo edición cuando toque.


> **Sale de la maqueta que aprobaste** el 2026-09-05:
> [`docs/propuesta-lama-mesas.html`](propuesta-lama-mesas.html). **Sin esto la
> pantalla nueva no tiene dónde guardar nada** — es el paso 1 de los cinco.

**Qué hace, en una imagen.** Hoy las mesas son una lista suelta con una etiqueta
de salón pegada. Después de esto, el local tiene **páginas** (los botones de
arriba: Salón, Mostrador…) y adentro **secciones** (Ala izquierda, Barra, Para
llevar…), y cada mesa vive en una. Es la diferencia entre una caja de fotos
sueltas y un álbum con hojas.

**Qué NO hace, y conviene decirlo:** **no borra ni una mesa**, no les cambia el
número, y **no toca la columna `salon`** — se queda quieta hasta comprobar que
todo anda. Sacarla ahora sería quemar el puente de vuelta.

**Cómo se corre:** **6 bloques cortos, uno por uno.** El editor de Supabase
muestra solo el resultado del último, así que pegarlos juntos pierde los
primeros.

**Qué mirar, bloque por bloque:**

| Bloque | Qué ver |
|---|---|
| **1** | 🔴 **CERO FILAS.** Si aparece alguna, **pará y avisame** |
| **1b** | la foto de lo que hay hoy: cuántas mesas por sede y salón |
| **2 · 3 · 4** | *"Success. No rows returned"* |
| **5** | una fila por sección, con sus mesas adentro |
| **5b** | `sin_area` en **0** |

⚠️ **Por qué el bloque 1 manda.** Hoy la base exige que el número sea único
**por salón**, y esto lo pasa a único **por sede** — la mesa 12 es la 12 en todo
Mall Plaza. Si hoy hubiera dos mesas con el mismo número en salones distintos,
el bloque 4 fallaría a mitad de camino. Preferimos verlo antes que romperlo.

<details><summary>▶ Ver el SQL completo</summary>

```sql
--  DÓNDE VA:  Supabase -> SQL Editor -> New query   (proyecto llamita-plus)
--  ES:        6 bloques cortos, UNO POR UNO. El editor solo muestra el último
--             resultado, así que pegarlos juntos pierde los primeros.
--  TARDA:     instantáneo cada uno.
--  QUÉ HACE:  el plano de mesas deja de ser una lista plana y pasa a tener
--             PÁGINAS y SECCIONES, que se editan desde la app. Crea una tabla
--             nueva y tres columnas en `mesas`. NO borra ninguna mesa.
--  QUÉ VER:   está escrito arriba de cada bloque. El bloque 1 tiene que dar
--             CERO filas — si da alguna, PARÁ y avisá.
--
--  De la maqueta aprobada: docs/propuesta-lama-mesas.html


-- ================================================================
-- BLOQUE 1 — ANTES DE TOCAR NADA
-- QUÉ VER: la primera consulta tiene que dar CERO FILAS.
--
-- POR QUÉ. Hoy la base exige que el número sea único POR SALÓN, y vamos a
-- pasarlo a único POR SEDE (la mesa 12 es la 12 en todo Mall Plaza). Si hoy
-- existieran dos mesas con el mismo número en salones distintos, el cambio
-- fallaría a mitad. Preferimos verlo antes.
-- ================================================================
select sede, numero, count(*) as cuantas
  from public.mesas
 group by sede, numero
having count(*) > 1;


-- ================================================================
-- BLOQUE 1b — (mirá esto también, es la foto de lo que hay hoy)
-- QUÉ VER: cuántas mesas tiene cada sede y en qué salón están.
-- ================================================================
select sede, salon, count(*) as mesas,
       min(numero) as desde, max(numero) as hasta
  from public.mesas
 group by sede, salon
 order by sede, salon;


-- ================================================================
-- BLOQUE 2 — LA TABLA NUEVA Y LAS COLUMNAS
-- QUÉ VER: "Success. No rows returned".
--
-- `lama_areas` guarda los dos niveles con un solo diseño: una fila SIN padre
-- es una PÁGINA (los botones de arriba); una fila CON padre es una SECCIÓN
-- dentro de esa página. Un solo lugar, una sola forma de leerlo.
-- ================================================================
create table if not exists public.lama_areas (
  id         bigserial primary key,
  sede       text    not null,
  nombre     text    not null,
  padre_id   bigint  references public.lama_areas(id) on delete restrict,
  color      text    not null default 'a',
  orden      integer not null default 0,
  activa     boolean not null default true,
  created_at timestamptz not null default now()
);

-- Dos secciones con el mismo nombre en la misma página es una trampa: nadie
-- sabría cuál es cuál. `coalesce(padre_id,0)` es para que las páginas también
-- se comparen entre sí — con NULL a secas, Postgres las considera distintas
-- siempre y dejaría crear dos "Mostrador".
create unique index if not exists lama_areas_nombre_unico
  on public.lama_areas (sede, coalesce(padre_id, 0), lower(nombre));
create index if not exists lama_areas_sede_idx
  on public.lama_areas (sede, padre_id, orden);

alter table public.lama_areas enable row level security;
drop policy if exists "lama_areas all" on public.lama_areas;
create policy "lama_areas all" on public.lama_areas
  for all to anon, authenticated using (true) with check (true);
grant all on public.lama_areas to anon, authenticated;
grant usage, select on sequence public.lama_areas_id_seq to anon, authenticated;

-- La mesa ahora vive en una sección, y tiene forma y tamaño propios.
-- `salon` NO se toca: se queda quieta hasta comprobar que todo anda. Sacarla
-- ahora sería quemar el puente de vuelta.
alter table public.mesas add column if not exists area_id bigint
  references public.lama_areas(id) on delete restrict;
alter table public.mesas add column if not exists forma text not null default 'cuadrada';
alter table public.mesas add column if not exists tam   text not null default 'normal';

alter table public.mesas drop constraint if exists mesas_forma_ok;
alter table public.mesas add  constraint mesas_forma_ok
  check (forma in ('cuadrada','redonda','larga'));
alter table public.mesas drop constraint if exists mesas_tam_ok;
alter table public.mesas add  constraint mesas_tam_ok
  check (tam in ('chica','normal','grande'));


-- ================================================================
-- BLOQUE 3 — REPARTIR LAS MESAS DE HOY
-- QUÉ VER: "Success". Ninguna mesa se borra ni cambia de número.
--
-- Cada sede estrena una página "Salón", y adentro una sección por cada salón
-- que ya existía. Después las movés vos desde la app, que es para lo que
-- sirve el modo edición.
-- ================================================================
insert into public.lama_areas (sede, nombre, padre_id, orden, color)
select distinct m.sede, 'Salón', null::bigint, 0, 'a'
  from public.mesas m
 where not exists (select 1 from public.lama_areas a
                    where a.sede = m.sede and a.padre_id is null);

insert into public.lama_areas (sede, nombre, padre_id, orden, color)
select p.sede, m.salon, p.id, 0, 'a'
  from (select distinct sede, salon from public.mesas) m
  join public.lama_areas p on p.sede = m.sede and p.padre_id is null
 where not exists (select 1 from public.lama_areas s
                    where s.sede = m.sede and s.padre_id = p.id
                      and lower(s.nombre) = lower(m.salon));

update public.mesas m
   set area_id = s.id
  from public.lama_areas s
  join public.lama_areas p on p.id = s.padre_id
 where p.padre_id is null
   and s.sede = m.sede
   and lower(s.nombre) = lower(m.salon)
   and m.area_id is null;


-- ================================================================
-- BLOQUE 4 — EL NÚMERO PASA A SER ÚNICO POR SEDE
-- QUÉ VER: "Success". Si acá diera error, es que el bloque 1 no dio cero:
-- pará y avisá en vez de forzarlo.
-- ================================================================
alter table public.mesas drop constraint if exists mesas_una_por_salon;
create unique index if not exists mesas_numero_por_sede
  on public.mesas (sede, numero);


-- ================================================================
-- BLOQUE 5 — COMPROBAR QUE QUEDÓ
-- QUÉ VER: una fila por sección, con sus mesas adentro.
-- ================================================================
select
  p.sede,
  p.nombre  as pagina,
  s.nombre  as seccion,
  (select count(*) from public.mesas m where m.area_id = s.id) as mesas
from public.lama_areas s
join public.lama_areas p on p.id = s.padre_id
order by p.sede, p.orden, s.orden, s.nombre;


-- ================================================================
-- BLOQUE 5b — Y QUE NINGUNA MESA QUEDARA HUÉRFANA
-- QUÉ VER: sin_area = 0. Si da otra cosa, avisá antes de seguir.
-- (Va aparte porque el editor muestra SOLO el resultado del último select:
--  dos consultas en un mismo Run pierden la primera.)
-- ================================================================
select count(*) as sin_area from public.mesas where area_id is null;
```

</details>

---



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
