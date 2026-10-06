--  DÓNDE VA: Supabase -> SQL Editor -> New query
--  ES:        1 solo bloque transaccional
--  TARDA:     instantáneo
--  QUÉ HACE:  crea una vista interna de observabilidad y un reproceso limitado a eventos prueba con error.
--  QUÉ VER:   la vista consulta estados; el helper no tiene EXECUTE público y no modifica stock.
-- A3.4a — observabilidad y reproceso seguro en modo prueba
begin;

create or replace view public.lama_stock_eventos_observabilidad
  with (security_invoker = on)
as
select
  e.id,
  e.source,
  e.sede,
  e.source_sale_id,
  e.source_line_id,
  e.cuenta_id,
  e.cuenta_item_id,
  e.provider_product_id,
  e.cantidad,
  e.fulfillment,
  e.estado,
  e.modo_efectivo,
  e.ocurrido_at,
  e.observado_at,
  e.precio,
  e.recipe_version_id,
  e.error_code,
  e.error_detail,
  e.created_at,
  e.updated_at,
  coalesce(a.aplicaciones_total, 0)::integer as aplicaciones_total,
  coalesce(a.aplicaciones_por_estado, '{}'::jsonb) as aplicaciones_por_estado
from public.lama_stock_eventos e
left join lateral (
  select
    count(*)::integer as aplicaciones_total,
    coalesce(jsonb_object_agg(x.estado, x.total), '{}'::jsonb) as aplicaciones_por_estado
  from (
    select la.estado, count(*)::integer as total
      from public.lama_stock_aplicaciones la
     where la.evento_id = e.id
     group by la.estado
  ) x
) a on true;

comment on view public.lama_stock_eventos_observabilidad is
  'A3.4a: consulta interna de eventos Lama y conteo de aplicaciones; no expone mutaciones.';

create or replace function public.lama_stock_reintentar_evento(p_evento_id uuid)
returns public.lama_stock_eventos
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_event public.lama_stock_eventos;
begin
  select * into v_event
    from public.lama_stock_eventos
   where id = p_evento_id
   for update;

  if not found then
    raise exception 'El evento Lama % no existe.', p_evento_id;
  end if;

  -- A3.4a nunca reprocesa un evento real: el guardia se mantiene aunque
  -- alguien conserve accidentalmente un registro antiguo con modo real.
  if v_event.modo_efectivo <> 'prueba' then
    raise exception 'A3.4a solo permite reproceso de eventos en modo prueba.';
  end if;

  if v_event.estado = 'sin_receta' then
    raise exception 'El evento % no tiene receta; requiere corrección de catálogo antes de reprocesar.', p_evento_id;
  end if;

  if v_event.estado <> 'error' then
    return v_event;
  end if;

  perform public.lama_stock_aplicar_evento(p_evento_id);

  select * into v_event
    from public.lama_stock_eventos
   where id = p_evento_id;
  return v_event;
end;
$function$;

comment on function public.lama_stock_reintentar_evento(uuid) is
  'A3.4a: reintenta solo eventos error en modo prueba, usando event_id e idempotencia A3.3.';

-- Vista y helper son internos. No se crea una nueva superficie RPC para el navegador.
revoke all on table public.lama_stock_eventos_observabilidad from public, anon, authenticated, service_role;
revoke all on function public.lama_stock_reintentar_evento(uuid) from public, anon, authenticated, service_role;

commit;
