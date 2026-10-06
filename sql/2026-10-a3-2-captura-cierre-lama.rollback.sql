-- A3.2 rollback: restaura las funciones instaladas antes de la captura
-- y elimina únicamente la estructura A3.2 si no contiene filas.
begin;

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

  delete from public.cuenta_pagos where cuenta_id = p_cuenta_id and not parcial;
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
  return v_cuenta;
end;
$function$;

do $$
declare n bigint;
begin
  select
    (select count(*) from public.lama_stock_capturas)
    + (select count(*) from public.lama_stock_eventos)
    into n;
  if n <> 0 then
    raise exception 'Rollback detenido: A3.2 contiene % filas', n;
  end if;
end $$;

revoke all on function public.lama_stock_capturar_cuenta(bigint)
  from public, anon, authenticated, service_role;
drop function public.lama_stock_capturar_cuenta(bigint);
drop table public.lama_stock_capturas;

commit;
