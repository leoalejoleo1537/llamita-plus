--  DÓNDE VA: Supabase -> SQL Editor -> New query
--  ES:        1 solo bloque transaccional
--  TARDA:     instantáneo
--  QUÉ HACE:  corrige el filtrado de receta_items.aplica para servir y llevar.
--  QUÉ VER:   una mesa serve incluye siempre/servir; takeaway incluye siempre/llevar.
begin;
create or replace function public.lama_stock_aplicar_evento(p_evento_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_event public.lama_stock_eventos;
  v_app_id uuid;
  v_product_id bigint;
  v_lote_id bigint;
  v_cantidad numeric;
  v_aplica text;
  v_clave text;
  v_error text;
  v_count integer := 0;
  v_item record;
begin
  select * into v_event
    from public.lama_stock_eventos
   where id = p_evento_id
   for update;

  if not found then
    raise exception 'El evento Lama % no existe.', p_evento_id;
  end if;

  if v_event.estado in ('aplicado', 'sin_receta', 'revertido') then
    select count(*) into v_count
      from public.lama_stock_aplicaciones
     where evento_id = p_evento_id
       and estado in ('aplicado', 'prueba');
    return v_count;
  end if;

  if v_event.modo_efectivo = 'apagado' then
    return 0;
  end if;

  begin
    for v_item in
      select item, ordinality::integer as ordinal
        from jsonb_array_elements(coalesce(v_event.snapshot_receta->'items', '[]'::jsonb))
          with ordinality as x(item, ordinality)
    loop
      v_aplica := coalesce(nullif(v_item.item->>'aplica', ''), 'siempre');
      -- Una cuenta de mesa Lama siempre representa servicio en local.
      if not (v_aplica = 'siempre' or (v_aplica = 'servir' and v_event.fulfillment = 'serve') or (v_aplica = 'llevar' and v_event.fulfillment = 'takeaway')) then
        continue;
      end if;

      v_product_id := nullif(v_item.item->>'producto_id', '')::bigint;
      v_cantidad := v_event.cantidad * (v_item.item->>'cantidad')::numeric;
      v_clave := format('lama:%s:%s:%s', p_evento_id, v_item.ordinal, coalesce(v_product_id::text, 'null'));
      v_lote_id := null;

      if exists (
        select 1 from public.producto_lotes l
         where l.producto_id = v_product_id and l.cantidad > 0
      ) then
        select l.id into v_lote_id
          from public.producto_lotes l
         where l.producto_id = v_product_id and l.cantidad > 0
         order by l.vencimiento asc nulls last, l.id asc
         limit 1;
      end if;

      insert into public.lama_stock_aplicaciones (
        evento_id, componente_producto_id, lote_id, cantidad_delta,
        unidad, estado, clave_idempotencia, error_code, error_detail, updated_at
      ) values (
        p_evento_id, v_product_id, v_lote_id, -v_cantidad,
        (select pr.unidad from public.productos pr where pr.id = v_product_id),
        case when v_event.modo_efectivo = 'prueba' then 'prueba' else 'pendiente' end,
        v_clave, null, null, now()
      )
      on conflict (clave_idempotencia) do update
        set componente_producto_id = excluded.componente_producto_id,
            lote_id = coalesce(public.lama_stock_aplicaciones.lote_id, excluded.lote_id),
            cantidad_delta = excluded.cantidad_delta,
            unidad = excluded.unidad,
            estado = case
              when public.lama_stock_aplicaciones.estado in ('aplicado','prueba')
                then public.lama_stock_aplicaciones.estado
              else excluded.estado
            end,
            error_code = null,
            error_detail = null,
            updated_at = now()
      returning id into v_app_id;

      select estado into v_aplica
        from public.lama_stock_aplicaciones
       where id = v_app_id;

      if v_event.modo_efectivo = 'prueba' then
        v_count := v_count + 1;
        continue;
      end if;

      if v_aplica = 'aplicado' then
        v_count := v_count + 1;
        continue;
      end if;

      -- Se delega el saldo al FIFO instalado. Si hay lotes, su trigger actualiza
      -- productos.stock_actual; por eso no se hace un segundo UPDATE manual.
      if v_lote_id is not null then
        perform public.descontar_lotes(v_product_id, v_cantidad);
      else
        perform public.descontar_con_reposicion(v_event.sede, v_product_id, v_cantidad);
      end if;

      update public.lama_stock_aplicaciones
         set estado = 'aplicado', applied_at = now(), updated_at = now()
       where id = v_app_id;
      v_count := v_count + 1;
    end loop;

    update public.lama_stock_eventos
       set estado = case when v_event.modo_efectivo = 'prueba' then 'prueba' else 'aplicado' end,
           error_code = null, error_detail = null, updated_at = now()
     where id = p_evento_id;
    return v_count;
  exception when others then
    get stacked diagnostics v_error = message_text;

    -- La excepción revierte el bloque completo: no queda ingrediente aplicado
    -- a medias. Luego se conserva un marcador error por cada ingrediente elegible.
    update public.lama_stock_eventos
       set estado = 'error', error_code = sqlstate,
           error_detail = left(v_error, 2000), updated_at = now()
     where id = p_evento_id;

    for v_item in
      select item, ordinality::integer as ordinal
        from jsonb_array_elements(coalesce(v_event.snapshot_receta->'items', '[]'::jsonb))
          with ordinality as x(item, ordinality)
    loop
      v_aplica := coalesce(nullif(v_item.item->>'aplica', ''), 'siempre');
      if not (v_aplica = 'siempre' or (v_aplica = 'servir' and v_event.fulfillment = 'serve') or (v_aplica = 'llevar' and v_event.fulfillment = 'takeaway')) then continue; end if;
      v_product_id := nullif(v_item.item->>'producto_id', '')::bigint;
      v_cantidad := v_event.cantidad * coalesce((v_item.item->>'cantidad')::numeric, 0);
      v_clave := format('lama:%s:%s:%s', p_evento_id, v_item.ordinal, coalesce(v_product_id::text, 'null'));
      insert into public.lama_stock_aplicaciones (
        evento_id, componente_producto_id, cantidad_delta, estado,
        clave_idempotencia, error_code, error_detail, updated_at
      ) values (
        p_evento_id, v_product_id, -v_cantidad, 'error',
        v_clave, sqlstate, left(v_error, 2000), now()
      )
      on conflict (clave_idempotencia) do update
        set estado = 'error', error_code = excluded.error_code,
            error_detail = excluded.error_detail, updated_at = now();
    end loop;
    return 0;
  end;
end;
$function$;

comment on function public.lama_stock_aplicar_evento(uuid) is
  'Motor interno A3.3 por event_id. Usa snapshot_receta y respeta fulfillment.';
revoke all on function public.lama_stock_aplicar_evento(uuid) from public, anon, authenticated, service_role;
commit;
