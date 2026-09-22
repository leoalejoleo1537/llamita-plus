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
