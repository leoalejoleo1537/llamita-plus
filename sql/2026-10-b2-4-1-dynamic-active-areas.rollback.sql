-- Rollback técnico B2.4.1. No ejecutar si ya existen transferencias en áreas
-- dinámicas: en ese caso se requiere mantener el motor compatible.
begin;

do $guard$
begin
  if exists(
    select 1
    from stock_internal.transferencias t
    join stock_internal.ubicaciones u
      on u.id in (t.ubicacion_origen_id,t.ubicacion_destino_id)
    where u.sede='plaza' and u.area_id is not null
      and u.codigo not in ('cocina_fria','cocina_caliente','barra','cafeteria')
  ) then
    raise exception 'Rollback B2.4.1 bloqueado: existen transferencias persistentes en áreas dinámicas.';
  end if;
end
$guard$;

do $rollback$
declare
  v_oid regprocedure := 'stock_internal.transferir_aplicar(uuid,bigint,bigint,uuid,uuid,numeric,bigint,text,text)'::regprocedure;
  v_definition text;
  v_dynamic_destination text := $new$
  if v_area_destino is null
     or not exists(select 1 from public.areas_operativas a
       where a.id=v_area_destino and a.sede='plaza' and a.estado='activa'
         and a.codigo=v_codigo_destino) then
$new$;
  v_fixed_destination text := $old$
  if v_codigo_destino not in ('cocina_fria','cocina_caliente','barra','cafeteria') or v_area_destino is null
     or not exists(select 1 from public.areas_operativas a where a.id=v_area_destino and a.sede='plaza' and a.estado='activa') then
$old$;
  v_dynamic_origin text := $new$
    if v_area_origen is null
       or not exists(select 1 from public.areas_operativas a
         where a.id=v_area_origen and a.sede='plaza' and a.estado='activa'
           and a.codigo=v_codigo_origen) then
$new$;
  v_fixed_origin text := $old$
    if v_codigo_origen not in ('cocina_fria','cocina_caliente','barra','cafeteria') or v_area_origen is null
       or not exists(select 1 from public.areas_operativas a where a.id=v_area_origen and a.sede='plaza' and a.estado='activa') then
$old$;
begin
  select pg_get_functiondef(v_oid) into v_definition;
  if length(v_definition)-length(replace(v_definition,v_dynamic_destination,'')) <> length(v_dynamic_destination)
     or length(v_definition)-length(replace(v_definition,v_dynamic_origin,'')) <> length(v_dynamic_origin) then
    raise exception 'Rollback B2.4.1 abortado: la definición instalada no coincide.';
  end if;
  execute replace(replace(v_definition,v_dynamic_destination,v_fixed_destination),v_dynamic_origin,v_fixed_origin);
end
$rollback$;

commit;
