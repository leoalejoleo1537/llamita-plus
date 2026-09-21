-- ================================================================
--  LLAMITA LAMA · EL ARQUEO DE CAJA (F6)
--
--  DÓNDE VA:  Supabase  ->  SQL Editor  ->  New query
--  ES:        1 solo bloque. Copiar TODO, pegar, apretar Run.
--  TARDA:     instantáneo
--  SEGURO DE RE-CORRER: sí.
--
--  QUÉ HACE:  crea las dos tablas del arqueo (lama_arqueos,
--             lama_caja_movimientos), las tres funciones que lo mueven
--             (abrir, movimiento, cerrar), y le agrega a `item_anular` el
--             candado que faltaba: una venta que ya quedó dentro de un
--             arqueo cerrado no se puede anular.
--
--  QUÉ VER AL TERMINAR: el bloque 7 tiene que decir, para cada función,
--             "1 firma". Si alguna dice 2, algo salió mal — avisale a
--             Claude antes de usar la pantalla nueva.
--
--  Aprobado por Jhon el 2026-09-21 sobre docs/propuesta-lama-arqueo.html,
--  con las tres preguntas de esa hoja contestadas así:
--    1. El arqueo ciego  -> SÍ, es "una de las joyas de la corona". El
--       interruptor vive en Ajustes -> Interruptores (no hace falta SQL
--       aparte: reusa la tabla `ajustes` que ya existe).
--    2. Cuántas cajas por sede -> una sola, sin selector (ya contestado
--       el 2026-09-05).
--    3. Quién abre y cierra -> cualquiera que entre a Mesas, con su
--       nombre escrito (ya contestado el 2026-09-05).
-- ================================================================


-- ----------------------------------------------------------------
-- 1) LAS DOS TABLAS
--
-- Nada más que esto: las ventas ya están en `cuentas`, los pagos en
-- `cuenta_pagos` y las propinas en `cuenta_propinas`. El arqueo los LEE
-- al cerrar, no los copia — la misma razón por la que `cuenta_cobrar`
-- siempre relee el subtotal en vez de confiar en lo que mandó la pantalla.
-- ----------------------------------------------------------------
create table if not exists public.lama_arqueos (
  id                bigserial primary key,
  sede              text    not null,
  monto_inicial     numeric not null default 0,
  abierto_por       text,
  abierto_at        timestamptz not null default now(),
  -- lo que declara el cajero al cerrar
  cerrado_por       text,
  cerrado_at        timestamptz,
  efectivo_contado  numeric,
  comentario        text,
  -- LO CONGELADO al cerrar, aunque se pueda recalcular — misma razón por la
  -- que `cuentas.total` se congela: el arqueo de dentro de seis meses no
  -- tiene por qué volver a sumar seis meses de líneas.
  efectivo_esperado numeric,
  diferencia        numeric,
  estado            text    not null default 'abierta',
  constraint lama_arqueos_estado_ok check (estado in ('abierta','cerrada'))
);

-- EL CANDADO DE LA PREGUNTA 2: una sola caja por sede a la vez. Índice
-- único PARCIAL, la misma receta que ya usa `cuentas_una_viva_por_mesa`.
create unique index if not exists lama_arqueos_una_abierta_por_sede
  on public.lama_arqueos(sede) where estado = 'abierta';
create index if not exists lama_arqueos_sede_idx on public.lama_arqueos(sede, abierto_at desc);

create table if not exists public.lama_caja_movimientos (
  id          bigserial primary key,
  arqueo_id   bigint  not null references public.lama_arqueos(id) on delete cascade,
  sede        text    not null,
  -- 'ingreso' entra plata que no es venta (ej. un vuelto de más) ·
  -- 'egreso' sale plata que no es venta (ej. un pago a proveedor de mano,
  -- que es como la maqueta pide registrar un gasto sin inventar un módulo)
  tipo        text    not null,
  monto       numeric not null,
  nota        text    not null,
  creado_por  text,
  created_at  timestamptz not null default now(),
  constraint lama_caja_movimientos_tipo_ok  check (tipo in ('ingreso','egreso')),
  constraint lama_caja_movimientos_monto_ok check (monto > 0)
);
create index if not exists lama_caja_movimientos_arqueo_idx on public.lama_caja_movimientos(arqueo_id);


-- ---------- permisos, igual que todas las demás tablas de Lama ----------
alter table public.lama_arqueos enable row level security;
drop policy if exists "lama_arqueos all" on public.lama_arqueos;
create policy "lama_arqueos all" on public.lama_arqueos
  for all to anon, authenticated using (true) with check (true);
grant all on public.lama_arqueos to anon, authenticated;
grant usage, select on sequence public.lama_arqueos_id_seq to anon, authenticated;

alter table public.lama_caja_movimientos enable row level security;
drop policy if exists "lama_caja_movimientos all" on public.lama_caja_movimientos;
create policy "lama_caja_movimientos all" on public.lama_caja_movimientos
  for all to anon, authenticated using (true) with check (true);
grant all on public.lama_caja_movimientos to anon, authenticated;
grant usage, select on sequence public.lama_caja_movimientos_id_seq to anon, authenticated;


-- ----------------------------------------------------------------
-- 2) ABRIR LA CAJA
-- Un campo, nada más — la hora la pone el sistema. El candado de "una sola
-- por sede" ya está en el índice único; acá se comprueba antes para dar un
-- error que se entiende, en vez del texto crudo de Postgres.
-- ----------------------------------------------------------------
create or replace function public.arqueo_abrir(
  p_sede          text,
  p_monto_inicial numeric,
  p_quien         text default null
) returns public.lama_arqueos
language plpgsql
security definer
set search_path = public
as $$
declare
  v_arqueo public.lama_arqueos;
begin
  if exists (select 1 from public.lama_arqueos where sede = p_sede and estado = 'abierta') then
    raise exception 'Ya hay una caja abierta en esta sede.';
  end if;
  if p_monto_inicial is null or p_monto_inicial < 0 then
    raise exception 'El monto inicial no puede ser negativo.';
  end if;

  insert into public.lama_arqueos (sede, monto_inicial, abierto_por)
  values (p_sede, p_monto_inicial, p_quien)
  returning * into v_arqueo;

  return v_arqueo;
end;
$$;


-- ----------------------------------------------------------------
-- 3) UN INGRESO O EGRESO DE MANO
-- "Un pago a proveedor sacado del cajón se anota como egreso manual con su
-- nota. Es la misma plata saliendo" (la maqueta, §1). Nada más que eso.
-- ----------------------------------------------------------------
create or replace function public.arqueo_movimiento(
  p_arqueo_id bigint,
  p_tipo      text,
  p_monto     numeric,
  p_nota      text,
  p_quien     text default null
) returns public.lama_caja_movimientos
language plpgsql
security definer
set search_path = public
as $$
declare
  v_arqueo public.lama_arqueos;
  v_mov    public.lama_caja_movimientos;
begin
  select * into v_arqueo from public.lama_arqueos where id = p_arqueo_id for update;
  if not found then
    raise exception 'Esa caja ya no existe.';
  end if;
  if v_arqueo.estado <> 'abierta' then
    raise exception 'Esa caja ya está cerrada.';
  end if;
  if p_tipo not in ('ingreso','egreso') then
    raise exception 'El movimiento tiene que ser ingreso o egreso.';
  end if;
  if p_monto is null or p_monto <= 0 then
    raise exception 'El monto tiene que ser mayor que cero.';
  end if;
  if coalesce(btrim(p_nota), '') = '' then
    raise exception 'Escribí para qué es este movimiento.';
  end if;

  insert into public.lama_caja_movimientos (arqueo_id, sede, tipo, monto, nota, creado_por)
  values (p_arqueo_id, v_arqueo.sede, p_tipo, p_monto, btrim(p_nota), p_quien)
  returning * into v_mov;

  return v_mov;
end;
$$;


-- ----------------------------------------------------------------
-- 4) CERRAR LA CAJA
--
-- EL EFECTIVO ESPERADO SE RELEE DE LA BASE, siempre — la misma regla de
-- `cuenta_cobrar`: nunca confiar en un número que mandó la pantalla, y
-- menos todavía en el único momento en que el número se firma para
-- siempre. La fórmula es la del atlas (bloque H):
--
--   esperado = monto inicial + efectivo cobrado + ingresos de mano
--              - egresos de mano
--
-- Los gastos a proveedor y las propinas retiradas quedan FUERA a propósito
-- (la maqueta, §1): no hay módulo de gastos, y un gasto pagado del cajón ya
-- entra como egreso manual — es la misma plata, contada una sola vez.
--
-- Es irreversible: si ya está cerrada, devuelve lo que quedó escrito sin
-- tocar nada — la misma idempotencia de `item_anular`. "Un arqueo cerrado
-- no se reabre jamás" (atlas, E2).
-- ----------------------------------------------------------------
create or replace function public.arqueo_cerrar(
  p_arqueo_id        bigint,
  p_efectivo_contado numeric,
  p_comentario       text default null,
  p_quien            text default null
) returns public.lama_arqueos
language plpgsql
security definer
set search_path = public
as $$
declare
  v_arqueo   public.lama_arqueos;
  v_efectivo numeric := 0;
  v_ingresos numeric := 0;
  v_egresos  numeric := 0;
  v_esperado numeric := 0;
begin
  select * into v_arqueo from public.lama_arqueos where id = p_arqueo_id for update;
  if not found then
    raise exception 'Esa caja ya no existe.';
  end if;

  if v_arqueo.estado = 'cerrada' then
    return v_arqueo;
  end if;

  if p_efectivo_contado is null or p_efectivo_contado < 0 then
    raise exception 'El efectivo contado no puede ser negativo.';
  end if;

  select coalesce(sum(cp.monto), 0) into v_efectivo
    from public.cuenta_pagos cp
    join public.cuentas c on c.id = cp.cuenta_id
   where c.sede = v_arqueo.sede
     and cp.medio = 'efectivo'
     and cp.created_at >= v_arqueo.abierto_at;

  select coalesce(sum(monto) filter (where tipo = 'ingreso'), 0),
         coalesce(sum(monto) filter (where tipo = 'egreso'), 0)
    into v_ingresos, v_egresos
    from public.lama_caja_movimientos
   where arqueo_id = p_arqueo_id;

  v_esperado := v_arqueo.monto_inicial + v_efectivo + v_ingresos - v_egresos;

  update public.lama_arqueos
     set estado            = 'cerrada',
         cerrado_por       = p_quien,
         cerrado_at        = now(),
         efectivo_contado  = p_efectivo_contado,
         comentario        = nullif(btrim(p_comentario), ''),
         efectivo_esperado = v_esperado,
         diferencia        = p_efectivo_contado - v_esperado
   where id = p_arqueo_id
   returning * into v_arqueo;

  return v_arqueo;
end;
$$;


-- ----------------------------------------------------------------
-- 5) EL CANDADO QUE SÍ CORRESPONDE (§0.8): con el arqueo cerrado, una
-- venta de esa franja no se anula más. El atlas lo dice con estas palabras
-- (E2), y la razón es la que ya vale para el resto del proyecto: cambiaría
-- un número que ya se declaró y se firmó. La corrección es la de siempre
-- en contabilidad — un movimiento de ajuste en el turno siguiente.
--
-- REEMPLAZA `item_anular` con LOS MISMOS CUATRO PARÁMETROS que ya tiene
-- (§0.5): un `create or replace` con la lista exacta reemplaza de verdad,
-- no agrega una segunda firma. El bloque 7 lo comprueba.
-- ----------------------------------------------------------------
create or replace function public.item_anular(
  p_item_id    bigint,
  p_motivo     text,
  p_comentario text default null,
  p_quien      text default null
) returns public.cuenta_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item      public.cuenta_items;
  v_cuenta    public.cuentas;
  v_pide      boolean;
  v_bloqueado boolean;
begin
  select * into v_item from public.cuenta_items where id = p_item_id for update;
  if not found then
    raise exception 'Ese producto ya no existe en la cuenta.';
  end if;

  -- Idempotente: anular dos veces devuelve la fila, no falla.
  if v_item.anulado_at is not null then
    return v_item;
  end if;

  if v_item.estado <> 'confirmado' then
    raise exception 'Ese producto todavía no salió a la cocina: se quita, no se anula.';
  end if;

  select * into v_cuenta from public.cuentas where id = v_item.cuenta_id;
  select exists(
    select 1 from public.lama_arqueos a
     where a.sede = v_cuenta.sede
       and a.estado = 'cerrada'
       and v_cuenta.cerrada_at is not null
       and v_cuenta.cerrada_at >= a.abierto_at
       and v_cuenta.cerrada_at <= a.cerrado_at
  ) into v_bloqueado;
  if v_bloqueado then
    raise exception 'Esa venta ya quedó dentro de un arqueo cerrado: no se puede anular. Corregilo con un movimiento de ajuste en la caja del turno siguiente.';
  end if;

  select pide_comentario into v_pide
    from public.lama_motivos_anulacion where codigo = p_motivo and activo;
  if not found then
    raise exception 'Ese motivo de anulación no existe o está apagado.';
  end if;
  if v_pide and coalesce(btrim(p_comentario), '') = '' then
    raise exception 'Ese motivo necesita que se escriba el detalle.';
  end if;

  update public.cuenta_items
     set anulado_at         = now(),
         anulado_por        = p_quien,
         anulado_motivo     = p_motivo,
         anulado_comentario = nullif(btrim(p_comentario), '')
   where id = p_item_id
   returning * into v_item;

  perform public.cuenta_recalcular(v_item.cuenta_id);
  return v_item;
end;
$$;


-- ----------------------------------------------------------------
-- 6) LOS PERMISOS DE LAS FUNCIONES
-- ----------------------------------------------------------------
grant execute on function public.arqueo_abrir(text,numeric,text)         to anon, authenticated;
grant execute on function public.arqueo_movimiento(bigint,text,numeric,text,text) to anon, authenticated;
grant execute on function public.arqueo_cerrar(bigint,numeric,text,text) to anon, authenticated;
grant execute on function public.item_anular(bigint,text,text,text)      to anon, authenticated;


-- ----------------------------------------------------------------
-- 7) EL CUADERNO
-- ----------------------------------------------------------------
insert into public.migraciones_aplicadas (archivo, quien, como_se_supo, nota)
values ('2026-09-lama-arqueo.sql', 'Jhon', 'lo corrió a mano en el SQL Editor',
        'El arqueo de caja: abrir, ingresos y egresos de mano, cerrar con efectivo esperado vs. contado. Agrega el candado de no anular una venta de un arqueo ya cerrado.')
on conflict (archivo) do update set aplicado_at = now(), nota = excluded.nota;


-- ----------------------------------------------------------------
-- 8) PARA COMPROBAR QUE QUEDÓ BIEN
--
-- `item_anular` tiene que decir "1 firma". Si dice 2, hay dos versiones
-- conviviendo y la llamada desde la app se vuelve ambigua — es la falla
-- que dejó el sistema 15 horas sin descontar (§0.5).
-- ----------------------------------------------------------------
select 'item_anular' as funcion,
       count(*) || ' firma' || case when count(*) = 1 then '' else 's ← PARAR' end as estado
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'item_anular'
union all
select 'arqueo_abrir',
       count(*) || ' firma' || case when count(*) = 1 then '' else 's ← PARAR' end
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'arqueo_abrir'
union all
select 'arqueo_movimiento',
       count(*) || ' firma' || case when count(*) = 1 then '' else 's ← PARAR' end
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'arqueo_movimiento'
union all
select 'arqueo_cerrar',
       count(*) || ' firma' || case when count(*) = 1 then '' else 's ← PARAR' end
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'arqueo_cerrar'
union all
select 'lama_arqueos (tabla)', count(*) || ' fila(s)'
  from public.lama_arqueos
union all
select 'lama_caja_movimientos (tabla)', count(*) || ' fila(s)'
  from public.lama_caja_movimientos;
