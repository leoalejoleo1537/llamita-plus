-- A3.2 — captura protegida del cierre Lama
-- Captura solo en modo prueba. Nunca modifica stock, lotes ni aplicaciones.
begin;

create table public.lama_stock_capturas (
  cuenta_id bigint primary key,
  sede text not null,
  modo_efectivo text not null default 'apagado'
    check (modo_efectivo in ('apagado','prueba','real')),
  estado text not null default 'pendiente'
    check (estado in ('pendiente','capturado','error')),
  eventos_insertados integer not null default 0 check (eventos_insertados >= 0),
  intentos integer not null default 0 check (intentos >= 0),
  ultimo_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.lama_stock_capturas is
  'Estado persistente de captura por cuenta. A3.2 no aplica inventario.';
comment on column public.lama_stock_capturas.modo_efectivo is
  'Modo leído al capturar; ausencia de configuración equivale a apagado.';

alter table public.lama_stock_capturas enable row level security;
revoke all on table public.lama_stock_capturas from anon, authenticated;

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
  v_error text;
begin
  select * into v_cuenta
    from public.cuentas
   where id = p_cuenta_id
   for share;

  if not found then
    raise exception 'Esa cuenta ya no existe.';
  end if;

  select coalesce(
    (select c.modo from public.lama_stock_config c where c.sede = v_cuenta.sede),
    'apagado'
  ) into v_modo;

  -- A3.2: apagado es exactamente el camino anterior. Real queda reservado.
  if v_modo <> 'prueba' then
    return 0;
  end if;

  insert into public.lama_stock_capturas
    (cuenta_id, sede, modo_efectivo, estado, intentos, ultimo_error, updated_at)
  values
    (p_cuenta_id, v_cuenta.sede, v_modo, 'pendiente', 1, null, now())
  on conflict (cuenta_id) do update
    set modo_efectivo = excluded.modo_efectivo,
        estado = 'pendiente',
        intentos = public.lama_stock_capturas.intentos + 1,
        ultimo_error = null,
        updated_at = now();

  begin
    for v_item in
      select ci.id, ci.cantidad, ci.precio, ci.fudo_product_id, ci.nombre,
             ci.comentario, ci.agregado_at
        from public.cuenta_items ci
       where ci.cuenta_id = p_cuenta_id
         and ci.estado = 'confirmado'
         and ci.anulado_at is null
       order by ci.id
    loop
      v_receta_id := null;
      v_snapshot := null;

      select r.id,
             jsonb_build_object(
               'receta_id', r.id,
               'sede', r.sede,
               'fudo_product_id', r.fudo_product_id,
               'fudo_product_nombre', r.fudo_product_nombre,
               'activo', r.activo,
               'items', coalesce((
                 select jsonb_agg(
                          jsonb_build_object(
                            'producto_id', ri.producto_id,
                            'cantidad', ri.cantidad,
                            'aplica', ri.aplica
                          ) order by ri.id
                        )
                   from public.receta_items ri
                  where ri.receta_id = r.id
               ), '[]'::jsonb)
             )
        into v_receta_id, v_snapshot
        from public.recetas r
       where r.sede = v_cuenta.sede
         and r.fudo_product_id = v_item.fudo_product_id
         and r.activo = true
       order by r.id desc
       limit 1;

      if v_receta_id is null then
        insert into public.lama_stock_eventos (
          source, sede, source_sale_id, source_line_id,
          cuenta_id, cuenta_item_id, provider_product_id, cantidad,
          estado, modo_efectivo, ocurrido_at, observado_at,
          precio, snapshot_precio, snapshot_receta, metadata
        ) values (
          'lama', v_cuenta.sede, p_cuenta_id::text, v_item.id::text,
          p_cuenta_id, v_item.id, v_item.fudo_product_id, v_item.cantidad,
          'sin_receta', 'prueba', coalesce(v_item.agregado_at, now()), now(),
          v_item.precio,
          jsonb_build_object('amount', v_item.precio, 'captured_at', now()),
          null,
          jsonb_build_object('nombre', v_item.nombre, 'comentario', v_item.comentario)
        )
        on conflict (source, sede, source_sale_id, source_line_id) do nothing;
      else
        insert into public.lama_stock_eventos (
          source, sede, source_sale_id, source_line_id,
          cuenta_id, cuenta_item_id, provider_product_id, cantidad,
          estado, modo_efectivo, ocurrido_at, observado_at,
          precio, snapshot_precio, recipe_version_id, snapshot_receta, metadata
        ) values (
          'lama', v_cuenta.sede, p_cuenta_id::text, v_item.id::text,
          p_cuenta_id, v_item.id, v_item.fudo_product_id, v_item.cantidad,
          'prueba', 'prueba', coalesce(v_item.agregado_at, now()), now(),
          v_item.precio,
          jsonb_build_object('amount', v_item.precio, 'captured_at', now()),
          v_receta_id::text, v_snapshot,
          jsonb_build_object('nombre', v_item.nombre, 'comentario', v_item.comentario)
        )
        on conflict (source, sede, source_sale_id, source_line_id) do nothing;
      end if;

      get diagnostics v_nuevos = row_count;
      v_insertados := v_insertados + v_nuevos;
    end loop;

    select count(*) into v_insertados
      from public.lama_stock_eventos
     where cuenta_id = p_cuenta_id;

    update public.lama_stock_capturas
       set estado = 'capturado',
           eventos_insertados = v_insertados,
           ultimo_error = null,
           updated_at = now()
     where cuenta_id = p_cuenta_id;
  exception when others then
    get stacked diagnostics v_error = message_text;
    update public.lama_stock_capturas
       set estado = 'error',
           eventos_insertados = 0,
           ultimo_error = left(v_error, 2000),
           updated_at = now()
     where cuenta_id = p_cuenta_id;
    return 0;
  end;

  return v_insertados;
end;
$function$;

-- Reemplaza las definiciones instaladas, conservando exactamente sus firmas.
create or replace function public.cuenta_cobrar(
  p_cuenta_id bigint,
  p_quien text default null,
  p_desc_motivo text default null,
  p_desc_formato text default null,
  p_desc_valor numeric default null,
  p_propinas jsonb default '[]'::jsonb,
  p_pagos jsonb default '[]'::jsonb
)
returns public.cuentas
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_cuenta    public.cuentas;
  v_subtotal  numeric := 0;
  v_descuento numeric := 0;
  v_propina   numeric := 0;
  v_total     numeric := 0;
  v_parcial   numeric := 0;
  v_ahora     numeric := 0;
  v_falta     numeric := 0;
begin
  select * into v_cuenta from public.cuentas where id = p_cuenta_id for update;
  if not found then
    raise exception 'Esa cuenta ya no existe.';
  end if;
  if v_cuenta.estado = 'cerrada' then
    return v_cuenta;
  end if;

  select coalesce(sum(cantidad * precio), 0) into v_subtotal
    from public.cuenta_items
   where cuenta_id = p_cuenta_id and anulado_at is null;

  if p_desc_formato = 'pct' then
    v_descuento := round(v_subtotal * coalesce(p_desc_valor, 0) / 100);
  elsif p_desc_formato = 'fijo' then
    v_descuento := coalesce(p_desc_valor, 0);
  end if;
  if v_descuento < 0 then v_descuento := 0; end if;
  if v_descuento > v_subtotal then v_descuento := v_subtotal; end if;

  select coalesce(sum((x->>'monto')::numeric), 0) into v_propina
    from jsonb_array_elements(coalesce(p_propinas, '[]'::jsonb)) x;
  if v_propina < 0 then v_propina := 0; end if;

  v_total := v_subtotal - v_descuento + v_propina;

  select coalesce(sum(monto), 0) into v_parcial
    from public.cuenta_pagos
   where cuenta_id = p_cuenta_id and parcial;

  select coalesce(sum((x->>'monto')::numeric), 0) into v_ahora
    from jsonb_array_elements(coalesce(p_pagos, '[]'::jsonb)) x;

  v_falta := v_total - v_parcial;
  if v_ahora < v_falta then
    raise exception 'Falta plata: se pagaron % de los % que faltaban.', v_ahora, v_falta;
  end if;

  delete from public.cuenta_pagos
   where cuenta_id = p_cuenta_id and not parcial;
  delete from public.cuenta_propinas where cuenta_id = p_cuenta_id;

  insert into public.cuenta_propinas (cuenta_id, medio, monto, creado_por)
  select p_cuenta_id, x->>'medio', (x->>'monto')::numeric, p_quien
    from jsonb_array_elements(coalesce(p_propinas, '[]'::jsonb)) x
   where (x->>'monto')::numeric <> 0;

  insert into public.cuenta_pagos (cuenta_id, medio, monto, creado_por, parcial)
  select p_cuenta_id, x->>'medio', (x->>'monto')::numeric, p_quien, false
    from jsonb_array_elements(coalesce(p_pagos, '[]'::jsonb)) x
   where (x->>'monto')::numeric <> 0;

  update public.cuentas
     set estado = 'cerrada',
         subtotal = v_subtotal,
         descuento = v_descuento,
         descuento_motivo = p_desc_motivo,
         descuento_formato = p_desc_formato,
         descuento_valor = p_desc_valor,
         propina = v_propina,
         total = v_total,
         pagado = v_parcial + v_ahora,
         vuelto = (v_parcial + v_ahora) - v_total,
         cerrada_por = p_quien,
         cerrada_at = now()
   where id = p_cuenta_id
   returning * into v_cuenta;

  begin
    perform public.lama_stock_capturar_cuenta(p_cuenta_id);
  exception when others then
    null;
  end;

  return v_cuenta;
end;
$function$;

create or replace function public.cuenta_cerrar(
  p_cuenta_id bigint,
  p_quien text default null
)
returns public.cuentas
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_cuenta public.cuentas;
begin
  select * into v_cuenta from public.cuentas where id = p_cuenta_id for update;
  if not found then
    raise exception 'Esa cuenta ya no existe.';
  end if;
  if v_cuenta.estado = 'cerrada' then
    return v_cuenta;
  end if;

  perform public.cuenta_recalcular(p_cuenta_id);
  update public.cuentas
     set estado = 'cerrada', cerrada_por = p_quien, cerrada_at = now()
   where id = p_cuenta_id
   returning * into v_cuenta;

  begin
    perform public.lama_stock_capturar_cuenta(p_cuenta_id);
  exception when others then
    null;
  end;

  return v_cuenta;
end;
$function$;

revoke all on function public.lama_stock_capturar_cuenta(bigint) from public, anon, authenticated, service_role;

commit;
