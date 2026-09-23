-- ================================================================
--  LLAMITA LAMA · LA FECHA Y HORA DE APERTURA DEL ARQUEO
--
--  DÓNDE VA:  Supabase -> SQL Editor -> New query
--  ES:        1 solo bloque. Copiar TODO, pegar, apretar Run.
--  TARDA:     instantáneo
--  SEGURO DE RE-CORRER: sí.
--
--  QUÉ HACE:  1) al abrir un arqueo se puede elegir la fecha y hora de
--                apertura hacia atrás (nunca hacia adelante);
--             2) se guarda además la hora REAL en que se apretó el botón,
--                para saber a qué hora llegó de verdad quien abrió;
--             3) una venta ya contada en un arqueo cerrado NO se vuelve a
--                contar en el siguiente, aunque las horas se crucen.
--             No borra nada. Reemplaza dos funciones: arqueo_abrir y
--             arqueo_cerrar.
--
--  QUÉ VER AL TERMINAR: el bloque final tiene que decir "1 firma" en las
--             dos funciones. Si dice 2, avisale a Claude antes de abrir
--             una caja.
--
--  Sale de las ocho preguntas que Jhon le hizo a NotebookLM el 2026-09-22
--  (docs/atlas-fudo.md, H4). Lo que decide todo:
--    · una venta es del arqueo que estaba abierto CUANDO SE COBRÓ;
--    · abrir con la hora hacia atrás solo recoge las ventas "huérfanas" —
--      las que se cobraron sin ninguna caja abierta—; lo que ya quedó en
--      un arqueo cerrado, ahí se queda;
--    · una hora en el futuro dejaría fuera las ventas de ahora mismo.
-- ================================================================


-- ----------------------------------------------------------------
-- 1) LA HORA REAL. `abierto_at` es la hora que se ELIGE (la que manda
--    para contar ventas); `creado_at` es la que pone el servidor al
--    apretar el botón, y nadie la puede cambiar. Las filas que ya existen
--    reciben su propia hora de apertura: hasta hoy las dos eran la misma.
-- ----------------------------------------------------------------
alter table public.lama_arqueos add column if not exists creado_at timestamptz;
update public.lama_arqueos set creado_at = abierto_at where creado_at is null;
alter table public.lama_arqueos alter column creado_at set default now();
alter table public.lama_arqueos alter column creado_at set not null;


-- ----------------------------------------------------------------
-- 2) ABRIR, con la hora elegida.
--    La firma cambia (un argumento más), así que la vieja se borra con
--    su firma exacta ANTES de crear la nueva (§0.5: dos firmas del mismo
--    nombre dejan la llamada desde la app ambigua).
--    Hacia el futuro no: con 2 minutos de margen por relojes desparejos.
-- ----------------------------------------------------------------
drop function if exists public.arqueo_abrir(text, numeric, text);

create or replace function public.arqueo_abrir(
  p_sede          text,
  p_monto_inicial numeric,
  p_quien         text default null,
  p_abierto_at    timestamptz default null
) returns public.lama_arqueos
language plpgsql
security definer
set search_path = public
as $$
declare
  v_arqueo public.lama_arqueos;
  v_desde  timestamptz := coalesce(p_abierto_at, now());
begin
  if exists (select 1 from public.lama_arqueos where sede = p_sede and estado = 'abierta') then
    raise exception 'Ya hay una caja abierta en esta sede.';
  end if;
  if p_monto_inicial is null or p_monto_inicial < 0 then
    raise exception 'El monto inicial no puede ser negativo.';
  end if;
  if v_desde > now() + interval '2 minutes' then
    raise exception 'La hora de apertura no puede ser en el futuro: las ventas de ahora quedarían fuera de la caja.';
  end if;

  insert into public.lama_arqueos (sede, monto_inicial, abierto_por, abierto_at, creado_at)
  values (p_sede, p_monto_inicial, p_quien, v_desde, now())
  returning * into v_arqueo;

  return v_arqueo;
end;
$$;


-- ----------------------------------------------------------------
-- 3) CERRAR, sin contar dos veces.
--    Misma firma que la de ayer (bigint, text, text): `create or replace`
--    la reemplaza de verdad. Lo único que cambia es QUÉ ventas cuenta:
--    las de su franja, MENOS las que caen dentro de un arqueo anterior ya
--    cerrado de la misma sede (ésas ya se contaron y se firmaron allá).
--    Un arqueo eliminado no se queda con nada: sus ventas vuelven a estar
--    sin dueño.
-- ----------------------------------------------------------------
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

  if v_arqueo.estado <> 'abierta' then
    return v_arqueo;
  end if;

  select coalesce(sum(monto) filter (where tipo = 'ingreso'), 0),
         coalesce(sum(monto) filter (where tipo = 'egreso'), 0)
    into v_ingresos, v_egresos
    from public.lama_caja_movimientos
   where arqueo_id = p_arqueo_id;

  delete from public.lama_arqueo_cierre_medios where arqueo_id = p_arqueo_id;

  for v_medio in
    select medio from (
      select cp.medio from public.cuenta_pagos cp join public.cuentas c on c.id = cp.cuenta_id
       where c.sede = v_arqueo.sede and cp.created_at >= v_arqueo.abierto_at
         and not exists (select 1 from public.lama_arqueos y
                          where y.sede = v_arqueo.sede and y.id < v_arqueo.id and y.estado = 'cerrada'
                            and cp.created_at between y.abierto_at and y.cerrado_at)
      union
      select cp.medio from public.cuenta_propinas cp join public.cuentas c on c.id = cp.cuenta_id
       where c.sede = v_arqueo.sede and cp.created_at >= v_arqueo.abierto_at
         and not exists (select 1 from public.lama_arqueos y
                          where y.sede = v_arqueo.sede and y.id < v_arqueo.id and y.estado = 'cerrada'
                            and cp.created_at between y.abierto_at and y.cerrado_at)
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
       and cp.created_at >= v_arqueo.abierto_at
       and not exists (select 1 from public.lama_arqueos y
                        where y.sede = v_arqueo.sede and y.id < v_arqueo.id and y.estado = 'cerrada'
                          and cp.created_at between y.abierto_at and y.cerrado_at);
    select coalesce(sum(cp.monto), 0) into v_propinas
      from public.cuenta_propinas cp join public.cuentas c on c.id = cp.cuenta_id
     where c.sede = v_arqueo.sede and cp.medio = v_medio.medio
       and cp.created_at >= v_arqueo.abierto_at
       and not exists (select 1 from public.lama_arqueos y
                        where y.sede = v_arqueo.sede and y.id < v_arqueo.id and y.estado = 'cerrada'
                          and cp.created_at between y.abierto_at and y.cerrado_at);
    v_sistema := v_ventas + v_propinas;

    -- El efectivo, y SOLO el efectivo, arrastra además el fondo inicial y
    -- los movimientos de mano: son plata del cajón, no ventas.
    if v_medio.medio = 'efectivo' then
      v_sistema := v_sistema + v_arqueo.monto_inicial + v_ingresos - v_egresos;
    end if;

    select monto into v_declarado
      from public.lama_arqueo_declarado
     where arqueo_id = p_arqueo_id and medio = v_medio.medio;
    if v_declarado is null then v_declarado := v_sistema; end if;

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
-- 4) LOS PERMISOS
-- ----------------------------------------------------------------
grant execute on function public.arqueo_abrir(text,numeric,text,timestamptz) to anon, authenticated;
grant execute on function public.arqueo_cerrar(bigint,text,text)             to anon, authenticated;


-- ----------------------------------------------------------------
-- 5) EL CUADERNO
-- ----------------------------------------------------------------
insert into public.migraciones_aplicadas (archivo, quien, como_se_supo, nota)
values ('2026-09-lama-arqueo-horario.sql', 'Jhon', 'lo corrió a mano en el SQL Editor',
        'Fecha y hora de apertura elegible (hacia atrás, nunca adelante), hora real guardada aparte, y una venta ya contada en un arqueo cerrado no se cuenta en el siguiente.')
on conflict (archivo) do update set aplicado_at = now(), nota = excluded.nota;


-- ----------------------------------------------------------------
-- 6) PARA COMPROBAR QUE QUEDÓ BIEN — un solo resultado, como pide el editor
-- ----------------------------------------------------------------
select 'arqueo_abrir' as funcion,
       count(*) || ' firma' || case when count(*) = 1 then '' else 's ← PARAR' end as estado
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'arqueo_abrir'
union all
select 'arqueo_cerrar',
       count(*) || ' firma' || case when count(*) = 1 then '' else 's ← PARAR' end
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'arqueo_cerrar'
union all
select 'arqueos sin hora real', count(*) || ' (tiene que decir 0)'
  from public.lama_arqueos where creado_at is null;
