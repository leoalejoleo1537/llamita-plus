-- Pruebas transaccionales del esquema B2.1. Ejecutar en Llamita Plus.
-- Toda fila sintética se revierte al final.
begin;
do $$
declare
  v_area uuid;
  v_product bigint;
  v_central_product bigint;
  v_expected boolean;
  v_rows bigint;
begin
  if (select count(*) from public.areas_operativas) <> 4
     or (select count(*) from public.areas_operativas where sede = 'plaza') <> 4
     or exists (select 1 from public.areas_operativas where sede <> 'plaza') then
    raise exception 'Debe haber exactamente cuatro áreas en plaza y ninguna en otra sede';
  end if;
  if (select array_agg(codigo order by codigo) from public.areas_operativas where sede='plaza')
     is distinct from array['barra','cafeteria','cocina_caliente','cocina_fria']::text[] then
    raise exception 'El catálogo no coincide con las cuatro áreas esperadas';
  end if;
  if (select count(*) from public.producto_area_asignacion) <> 0 then
    raise exception 'La tabla preparatoria debe iniciar sin asignaciones';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema='public'
      and table_name in ('areas_operativas','producto_area_asignacion')
      and column_name ~ '(stock|saldo|cantidad)'
  ) then
    raise exception 'Las tablas B2.1 no deben almacenar stock ni cantidades';
  end if;
  if not (select c.relrowsecurity from pg_class c where c.oid='public.areas_operativas'::regclass)
     or not (select c.relrowsecurity from pg_class c where c.oid='public.producto_area_asignacion'::regclass) then
    raise exception 'RLS debe estar habilitado en ambas tablas';
  end if;
  if has_table_privilege('anon','public.areas_operativas','SELECT,INSERT,UPDATE,DELETE')
     or has_table_privilege('authenticated','public.areas_operativas','SELECT,INSERT,UPDATE,DELETE')
     or has_table_privilege('service_role','public.areas_operativas','SELECT,INSERT,UPDATE,DELETE')
     or has_table_privilege('anon','public.producto_area_asignacion','SELECT,INSERT,UPDATE,DELETE')
     or has_table_privilege('authenticated','public.producto_area_asignacion','SELECT,INSERT,UPDATE,DELETE')
     or has_table_privilege('service_role','public.producto_area_asignacion','SELECT,INSERT,UPDATE,DELETE') then
    raise exception 'anon/authenticated/service_role no deben tener acceso directo';
  end if;
  if exists (
    select 1 from pg_class c
    cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) acl
    where c.oid in ('public.areas_operativas'::regclass,'public.producto_area_asignacion'::regclass)
      and acl.grantee=0
  ) then raise exception 'PUBLIC no debe tener privilegios de tabla'; end if;
  if exists (
    select 1 from pg_policies
    where schemaname='public' and tablename in ('areas_operativas','producto_area_asignacion')
  ) then
    raise exception 'B2.1 no debe crear políticas API directas';
  end if;
  if not exists (select 1 from pg_indexes where schemaname='public' and indexname='producto_area_producto_fk_idx')
     or not exists (select 1 from pg_indexes where schemaname='public' and indexname='producto_area_area_fk_idx') then
    raise exception 'Las FK de producto y área deben tener índices de cobertura';
  end if;
  if has_function_privilege('anon','public.areas_operativas_guardar()','EXECUTE')
     or has_function_privilege('authenticated','public.areas_operativas_guardar()','EXECUTE')
     or has_function_privilege('service_role','public.areas_operativas_guardar()','EXECUTE')
     or has_function_privilege('anon','public.producto_area_validar_contexto()','EXECUTE')
     or has_function_privilege('authenticated','public.producto_area_validar_contexto()','EXECUTE')
     or has_function_privilege('service_role','public.producto_area_validar_contexto()','EXECUTE')
     or exists (
       select 1 from pg_proc p
       join pg_namespace n on n.oid=p.pronamespace
       cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
       where n.nspname='public'
         and p.proname in ('areas_operativas_guardar','producto_area_validar_contexto')
         and acl.grantee=0 and acl.privilege_type='EXECUTE'
     ) then
    raise exception 'Los helpers internos no deben ser ejecutables por roles de aplicación ni PUBLIC';
  end if;

  select id into v_area from public.areas_operativas where sede='plaza' order by orden limit 1;
  select id into v_product from public.productos where sede='plaza' order by id limit 1;
  select id into v_central_product from public.productos where sede='central' order by id limit 1;
  if v_area is null or v_product is null or v_central_product is null then
    raise exception 'Faltan fixtures existentes para validar contexto entre sedes';
  end if;

  insert into public.producto_area_asignacion(sede,producto_id,area_id,estado)
  values ('plaza',v_product,v_area,'asignado');
  if (select count(*) from public.producto_area_asignacion where producto_id=v_product) <> 1 then
    raise exception 'No se pudo crear asignación válida temporal';
  end if;

  v_expected := false;
  begin
    insert into public.producto_area_asignacion(sede,producto_id,area_id,estado)
    values ('plaza',v_central_product,v_area,'asignado');
  exception when check_violation then v_expected := true;
  end;
  if not v_expected then raise exception 'No se rechazó una combinación de sedes'; end if;

  v_expected := false;
  begin
    insert into public.producto_area_asignacion(sede,producto_id,area_id,estado)
    values ('plaza',v_product,(select id from public.areas_operativas where sede='plaza' and codigo='barra'),'asignado');
  exception when unique_violation then v_expected := true;
  end;
  if not v_expected then raise exception 'No se rechazó una segunda área para el mismo producto/sede'; end if;

  v_expected := false;
  begin
    insert into public.producto_area_asignacion(sede,producto_id,area_id,estado)
    values ('plaza',v_product,null,'asignado');
  exception when check_violation then v_expected := true;
  end;
  if not v_expected then raise exception 'No se rechazó estado/área inconsistente'; end if;

  v_expected := false;
  begin
    insert into public.areas_operativas(sede,codigo,nombre)
    values ('plaza','sin_asignar','Sin asignar');
  exception when check_violation then v_expected := true;
  end;
  if not v_expected then raise exception 'sin_asignar no debe poder crearse como área física'; end if;

  v_expected := false;
  begin
    update public.areas_operativas set codigo='area_cambiada' where id=v_area;
  exception when sqlstate 'P0001' then v_expected := true;
  end;
  if not v_expected then raise exception 'La clave estable del área no debe cambiar'; end if;

  select count(*) into v_rows from public.producto_area_asignacion;
  if v_rows <> 1 then raise exception 'Las pruebas negativas dejaron filas inesperadas'; end if;
end;
$$;
rollback;
