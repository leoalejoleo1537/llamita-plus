-- B2.4.1 — permite transferencias hacia cualquier área activa de plaza.
-- Cambia solo las dos validaciones de código fijo del núcleo B2.4.
do $migration$
declare
  v_oid regprocedure := 'stock_internal.transferir_aplicar(uuid,bigint,bigint,uuid,uuid,numeric,bigint,text,text)'::regprocedure;
  v_definition text;
  v_old_destination text := $old$
  if v_codigo_destino not in ('cocina_fria','cocina_caliente','barra','cafeteria') or v_area_destino is null
     or not exists(select 1 from public.areas_operativas a where a.id=v_area_destino and a.sede='plaza' and a.estado='activa') then
$old$;
  v_new_destination text := $new$
  if v_area_destino is null
     or not exists(select 1 from public.areas_operativas a
       where a.id=v_area_destino and a.sede='plaza' and a.estado='activa'
         and a.codigo=v_codigo_destino) then
$new$;
  v_old_origin text := $old$
    if v_codigo_origen not in ('cocina_fria','cocina_caliente','barra','cafeteria') or v_area_origen is null
       or not exists(select 1 from public.areas_operativas a where a.id=v_area_origen and a.sede='plaza' and a.estado='activa') then
$old$;
  v_new_origin text := $new$
    if v_area_origen is null
       or not exists(select 1 from public.areas_operativas a
         where a.id=v_area_origen and a.sede='plaza' and a.estado='activa'
           and a.codigo=v_codigo_origen) then
$new$;
begin
  select pg_get_functiondef(v_oid) into v_definition;
  if length(v_definition)-length(replace(v_definition,v_old_destination,'')) <> length(v_old_destination)
     or length(v_definition)-length(replace(v_definition,v_old_origin,'')) <> length(v_old_origin) then
    raise exception 'B2.4.1 abortada: la definición instalada no coincide exactamente con B2.4.';
  end if;
  v_definition := replace(v_definition,v_old_destination,v_new_destination);
  v_definition := replace(v_definition,v_old_origin,v_new_origin);
  execute v_definition;

  if not exists(
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where p.oid=v_oid and p.prosecdef and p.proconfig @> array['search_path=""']::text[]
      and p.proacl::text='{postgres=X/postgres}'
  ) then
    raise exception 'B2.4.1 abortada: cambiaron seguridad, search_path o ACL del núcleo.';
  end if;
end
$migration$;

comment on function stock_internal.transferir_aplicar(uuid,bigint,bigint,uuid,uuid,numeric,bigint,text,text) is
  'B2.4.1: motor atómico; acepta cualquier ubicación vinculada a un área activa de plaza.';
