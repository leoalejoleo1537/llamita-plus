--  DÓNDE VA: Supabase -> SQL Editor -> New query
--  ES:        1 solo bloque transaccional
--  TARDA:     ~12 segundos
--  QUÉ HACE:  añade el motor interno de aplicaciones A3.3 y corrige la captura de cierre; no deja sedes activadas.
--  QUÉ VER:   lama_stock_config debe quedar vacía; no deben cambiar los saldos al terminar las pruebas revertidas.
-- A3.3 — motor neutral y aplicación transaccional del puente Lama -> Stock
-- Solo para Llamita Plus. El modo real se prueba únicamente dentro de transacciones revertidas.
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
  'Motor interno A3.3 por event_id. Usa snapshot_receta; prueba no escribe stock y real delega FIFO instalado.';

-- Captura actualizada: cierre como ocurrido_at, agregado_at solo en metadata,
-- fulfillment serve para una mesa Lama y aplicación automática en prueba/real.
create or replace function public.lama_stock_capturar_cuenta(p_cuenta_id bigint)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_cuenta public.cuentas;
  v_modo text;
  v_insertados integer := 0;
  v_nuevos integer := 0;
  v_receta_id bigint;
  v_snapshot jsonb;
  v_item record;
  v_evento_id uuid;
  v_error text;
  v_estado text;
begin
  select * into v_cuenta from public.cuentas where id = p_cuenta_id for share;
  if not found then raise exception 'Esa cuenta ya no existe.'; end if;

  select coalesce((select c.modo from public.lama_stock_config c where c.sede = v_cuenta.sede), 'apagado')
    into v_modo;
  if v_modo not in ('prueba','real') then return 0; end if;

  insert into public.lama_stock_capturas
    (cuenta_id, sede, modo_efectivo, estado, intentos, ultimo_error, updated_at)
  values (p_cuenta_id, v_cuenta.sede, v_modo, 'pendiente', 1, null, now())
  on conflict (cuenta_id) do update
    set modo_efectivo = excluded.modo_efectivo,
        estado = 'pendiente', intentos = public.lama_stock_capturas.intentos + 1,
        ultimo_error = null, updated_at = now();

  begin
    for v_item in
      select ci.id, ci.cantidad, ci.precio, ci.fudo_product_id, ci.nombre,
             ci.comentario, ci.agregado_at
        from public.cuenta_items ci
       where ci.cuenta_id = p_cuenta_id and ci.estado = 'confirmado' and ci.anulado_at is null
       order by ci.id
    loop
      v_receta_id := null; v_snapshot := null; v_evento_id := null;
      select r.id,
             jsonb_build_object(
               'receta_id', r.id, 'sede', r.sede,
               'fudo_product_id', r.fudo_product_id,
               'fudo_product_nombre', r.fudo_product_nombre,
               'activo', r.activo,
               'items', coalesce((select jsonb_agg(jsonb_build_object(
                 'producto_id', ri.producto_id, 'cantidad', ri.cantidad, 'aplica', ri.aplica
               ) order by ri.id) from public.receta_items ri where ri.receta_id = r.id), '[]'::jsonb)
             )
        into v_receta_id, v_snapshot
        from public.recetas r
       where r.sede = v_cuenta.sede and r.fudo_product_id = v_item.fudo_product_id and r.activo = true
       order by r.id desc limit 1;

      insert into public.lama_stock_eventos (
        source, sede, source_sale_id, source_line_id, cuenta_id, cuenta_item_id,
        provider_product_id, cantidad, fulfillment, estado, modo_efectivo,
        ocurrido_at, observado_at, precio, snapshot_precio, recipe_version_id,
        snapshot_receta, metadata
      ) values (
        'lama', v_cuenta.sede, p_cuenta_id::text, v_item.id::text, p_cuenta_id, v_item.id,
        v_item.fudo_product_id, v_item.cantidad, 'serve',
        case when v_receta_id is null then 'sin_receta' else case when v_modo = 'prueba' then 'prueba' else 'pendiente' end end,
        v_modo, coalesce(v_cuenta.cerrada_at, now()), now(), v_item.precio,
        jsonb_build_object('amount', v_item.precio, 'captured_at', now()), v_receta_id::text,
        v_snapshot, jsonb_build_object('nombre', v_item.nombre, 'comentario', v_item.comentario,
          'agregado_at', v_item.agregado_at)
      )
      on conflict (source, sede, source_sale_id, source_line_id) do nothing
      returning id into v_evento_id;

      if v_evento_id is null then
        select id into v_evento_id from public.lama_stock_eventos
         where source='lama' and sede=v_cuenta.sede and source_sale_id=p_cuenta_id::text
           and source_line_id=v_item.id::text;
      end if;

      if v_receta_id is not null then
        perform public.lama_stock_aplicar_evento(v_evento_id);
      end if;
    end loop;

    select count(*) into v_insertados from public.lama_stock_eventos where cuenta_id = p_cuenta_id;
    select case when exists (select 1 from public.lama_stock_eventos where cuenta_id=p_cuenta_id and estado='error') then 'error' else 'capturado' end into v_estado;
    update public.lama_stock_capturas
       set estado = v_estado, eventos_insertados = v_insertados,
           ultimo_error = (select string_agg(error_detail, '; ') from public.lama_stock_eventos where cuenta_id=p_cuenta_id and estado='error'),
           updated_at = now()
     where cuenta_id = p_cuenta_id;
  exception when others then
    get stacked diagnostics v_error = message_text;
    update public.lama_stock_capturas
       set estado = 'error', eventos_insertados = 0, ultimo_error = left(v_error, 2000), updated_at = now()
     where cuenta_id = p_cuenta_id;
    return 0;
  end;
  return v_insertados;
end;
$function$;

-- EXECUTE cerrado explícitamente: el motor y la captura son internos.
revoke all on function public.lama_stock_aplicar_evento(uuid) from public, anon, authenticated, service_role;
revoke all on function public.lama_stock_capturar_cuenta(bigint) from public, anon, authenticated, service_role;

commit;
