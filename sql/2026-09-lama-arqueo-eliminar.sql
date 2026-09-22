-- ================================================================
--  LLAMITA LAMA · BORRAR UN ARQUEO (que no desaparece)
--
--  DÓNDE VA:  Supabase -> SQL Editor -> New query
--  ES:        1 solo bloque. Copiar TODO, pegar, apretar Run.
--  TARDA:     instantáneo
--  SEGURO DE RE-CORRER: sí.
--
--  QUÉ HACE:  agrega el estado "eliminada" a los arqueos y la función que
--             lo pone. NO BORRA NINGUNA FILA: un arqueo eliminado se queda
--             en la base, con quién lo eliminó y cuándo, y en la pantalla
--             se ve en gris y tachado — igual que un producto anulado en
--             una mesa, y igual que en Fudo ("Eliminado").
--
--  QUÉ VER AL TERMINAR: el bloque final tiene que decir "1 firma" en
--             arqueo_eliminar, y "sí" en el estado nuevo. Si dice otra
--             cosa, avisale a Claude antes de usar el botón.
--
--  Pedido por Jhon el 2026-09-22: "no debe eliminarse y desaparecer por
--  completo; debe quedar en gris en la lista con una línea que lo tache".
-- ================================================================


-- ----------------------------------------------------------------
-- 1) EL ESTADO NUEVO, y dónde queda escrito quién lo eliminó.
--    `estado_previo` guarda si estaba abierto o cerrado: un arqueo
--    cerrado y después eliminado sigue teniendo sus números, y hay que
--    poder saber que alguna vez se cerró.
-- ----------------------------------------------------------------
alter table public.lama_arqueos drop constraint if exists lama_arqueos_estado_ok;
alter table public.lama_arqueos add constraint lama_arqueos_estado_ok
  check (estado in ('abierta','cerrada','eliminada'));

alter table public.lama_arqueos add column if not exists eliminado_por text;
alter table public.lama_arqueos add column if not exists eliminado_at  timestamptz;
alter table public.lama_arqueos add column if not exists estado_previo text;


-- ----------------------------------------------------------------
-- 2) ELIMINAR. Idempotente: eliminar dos veces devuelve la fila, no
--    falla (la misma regla que `item_anular` y `arqueo_cerrar`).
--    Eliminar el ABIERTO libera la sede: el índice "una abierta por sede"
--    solo mira las que dicen 'abierta', así que se puede abrir otro.
-- ----------------------------------------------------------------
create or replace function public.arqueo_eliminar(
  p_arqueo_id bigint,
  p_quien     text default null
) returns public.lama_arqueos
language plpgsql
security definer
set search_path = public
as $$
declare
  v_arqueo public.lama_arqueos;
begin
  select * into v_arqueo from public.lama_arqueos where id = p_arqueo_id for update;
  if not found then
    raise exception 'Ese arqueo ya no existe.';
  end if;

  if v_arqueo.estado = 'eliminada' then
    return v_arqueo;
  end if;

  update public.lama_arqueos
     set estado_previo = estado,
         estado        = 'eliminada',
         eliminado_por = p_quien,
         eliminado_at  = now()
   where id = p_arqueo_id
   returning * into v_arqueo;

  return v_arqueo;
end;
$$;

grant execute on function public.arqueo_eliminar(bigint,text) to anon, authenticated;


-- ----------------------------------------------------------------
-- 3) EL CUADERNO
-- ----------------------------------------------------------------
insert into public.migraciones_aplicadas (archivo, quien, como_se_supo, nota)
values ('2026-09-lama-arqueo-eliminar.sql', 'Jhon', 'lo corrió a mano en el SQL Editor',
        'Borrar un arqueo sin borrar la fila: estado eliminada, con quién y cuándo. Se ve tachado en la lista.')
on conflict (archivo) do update set aplicado_at = now(), nota = excluded.nota;


-- ----------------------------------------------------------------
-- 4) PARA COMPROBAR QUE QUEDÓ BIEN
-- ----------------------------------------------------------------
select 'arqueo_eliminar' as que,
       count(*) || ' firma' || case when count(*) = 1 then '' else 's ← PARAR' end as estado
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'arqueo_eliminar'
union all
select 'el estado "eliminada" se acepta',
       case when pg_get_constraintdef(c.oid) like '%eliminada%' then 'sí' else 'NO ← PARAR' end
  from pg_constraint c
 where c.conname = 'lama_arqueos_estado_ok';
