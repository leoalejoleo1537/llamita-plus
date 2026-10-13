-- Prueba integral del vínculo maestro Bodega → representación Local 1.
-- Debe ejecutarse con permisos de servidor y termina siempre en ROLLBACK.
begin;

select set_config('request.jwt.claim.sub','decc9a8d-0ab6-4306-bab5-a62bcaa40338',true);
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','decc9a8d-0ab6-4306-bab5-a62bcaa40338',
  'role','authenticated','email','s2-root-test@invalid.example')::text,true);

do $test$
declare
  v_cold uuid;
  v_cafe uuid;
  v_master bigint;
  v_master_linked bigint;
  v_master_multi bigint;
  v_master_candidate bigint;
  v_master_duplicate bigint;
  v_local bigint;
  v_local_a bigint;
  v_local_b bigint;
  v_candidate bigint;
  v_result jsonb;
  v_rows bigint;
  v_products_before bigint;
  v_lots_before bigint;
  v_movements_before bigint;
  v_ledger_rows_before bigint;
  v_ledger_total_before numeric;
  v_exception boolean;
begin
  select id into v_cold from public.areas_operativas
    where sede='plaza' and codigo='cocina_fria' and estado='activa';
  select id into v_cafe from public.areas_operativas
    where sede='plaza' and codigo='cafeteria' and estado='activa';
  if v_cold is null or v_cafe is null then raise exception 'Faltan áreas activas de prueba'; end if;

  select count(*) into v_products_before from public.productos;
  select count(*) into v_lots_before from public.producto_lotes;
  select count(*) into v_movements_before from stock_internal.movimientos;
  select count(*),coalesce(sum(cantidad),0) into v_ledger_rows_before,v_ledger_total_before from stock_internal.existencias;

  insert into public.productos(producto,rubro,stock_actual,stock_min,stock_max,activo,origen,sede,perecedero,urgente,tipo,unidad)
  values('Menta hoja prueba 91731','Insumos',0,0,0,'SÍ','bodega_producto_area_test','central',false,false,'Insumos','kg')
  returning id into v_master;
  insert into public.productos(producto,rubro,stock_actual,stock_min,stock_max,activo,origen,sede,perecedero,urgente,tipo,unidad)
  values('Leche prueba vinculada 91732','Lácteos',0,0,0,'SÍ','bodega_producto_area_test','central',false,false,'Lácteos','L')
  returning id into v_master_linked;
  insert into public.productos(producto,rubro,stock_actual,stock_min,stock_max,activo,origen,sede,perecedero,urgente,tipo,unidad)
  values('Jarabe prueba múltiples 91733','Insumos',0,0,0,'SÍ','bodega_producto_area_test','central',false,false,'Insumos','ml')
  returning id into v_master_multi;
  insert into public.productos(producto,rubro,stock_actual,stock_min,stock_max,activo,origen,sede,perecedero,urgente,tipo,unidad)
  values('Hojas de menta prueba 91734','Insumos',0,0,0,'SÍ','bodega_producto_area_test','central',false,false,'Insumos','kg')
  returning id into v_master_candidate;
  insert into public.productos(producto,rubro,stock_actual,stock_min,stock_max,activo,origen,sede,perecedero,urgente,tipo,unidad)
  values('Naranja exacta prueba 91735','Fruta',0,0,0,'SÍ','bodega_producto_area_test','central',false,false,'Fruta','kg')
  returning id into v_master_duplicate;

  -- Sin representación: una consulta plural y sin acentos sigue encontrando el maestro.
  v_result:=public.bodega_productos_area_buscar('MÉNTAS HOJAS PRUEBA 91731',v_cold);
  if not exists(select 1 from jsonb_array_elements(v_result) r where (r->>'producto_bodega_id')::bigint=v_master)
     then raise exception 'Búsqueda no toleró tildes/plural'; end if;
  v_result:=public.bodega_producto_area_agregar(v_master,null,true,v_cold,null,1,5,false,true);
  if (v_result->>'representacion_creada')::boolean is not true
     or (v_result->>'saldo_movido')::boolean is not false then raise exception 'No creó representación nueva con saldo cero'; end if;
  v_local:=(v_result->>'producto_plaza_id')::bigint;
  if not exists(select 1 from public.productos p where p.id=v_local and p.sede='plaza' and p.stock_actual=0)
     or exists(select 1 from stock_internal.existencias x where x.producto_id=v_local)
     or not exists(select 1 from public.producto_enlace e where e.producto_bodega_id=v_master and e.sede='plaza' and e.producto_sede_id=v_local and e.factor=1)
     then raise exception 'La representación no está enlazada o no tiene saldo cero'; end if;
  if not exists(select 1 from public.producto_area_asignacion pa where pa.producto_id=v_local and pa.area_id=v_cold and pa.creado_por='decc9a8d-0ab6-4306-bab5-a62bcaa40338')
     then raise exception 'No quedó auditada la configuración actor/producto/área'; end if;

  -- Doble envío: reutiliza el mismo enlace/configuración y no duplica filas.
  v_result:=public.bodega_producto_area_agregar(v_master,v_local,false,v_cold,null,1,5,false,true);
  if (v_result->>'ya_configurado')::boolean is not true then raise exception 'Reintento no detectó configuración existente'; end if;
  v_result:=public.bodega_producto_area_agregar(v_master,null,true,v_cold,null,1,5,false,true);
  if (v_result->>'ya_configurado')::boolean is not true or (v_result->>'producto_plaza_id')::bigint<>v_local
     then raise exception 'Reintento de creación con timeout no reutilizó la identidad'; end if;
  select count(*) into v_rows from public.producto_area_asignacion where producto_id=v_local and area_id=v_cold and estado='asignado';
  if v_rows<>1 then raise exception 'El reintento duplicó la configuración'; end if;

  -- La misma identidad local puede configurarse en otra área sin mover saldo.
  v_result:=public.bodega_producto_area_agregar(v_master,v_local,false,v_cafe,null,2,8,false,true);
  if (v_result->>'ya_configurado')::boolean is true then raise exception 'Se impidió usar una representación en dos áreas'; end if;
  select count(*) into v_rows from public.producto_area_asignacion where producto_id=v_local and estado='asignado' and area_id in (v_cold,v_cafe);
  if v_rows<>2 then raise exception 'No quedaron dos configuraciones por área'; end if;

  -- Reutiliza un enlace ya existente.
  insert into public.productos(producto,rubro,stock_actual,stock_min,stock_max,activo,origen,sede,perecedero,urgente,tipo,unidad)
  values('Leche Local rep 91732','Lácteos',0,0,0,'SÍ','bodega_producto_area_test','plaza',false,false,'Lácteos','L') returning id into v_local_a;
  insert into public.producto_enlace(producto_bodega_id,sede,producto_sede_id,factor,creado_por)
  values(v_master_linked,'plaza',v_local_a,1,'decc9a8d-0ab6-4306-bab5-a62bcaa40338');
  v_result:=public.bodega_productos_area_buscar(v_master_linked::text,v_cafe);
  if jsonb_array_length(v_result->0->'representaciones')<>1 then raise exception 'No mostró la representación enlazada existente'; end if;
  v_result:=public.bodega_producto_area_agregar(v_master_linked,v_local_a,false,v_cafe,null,0,4,false,true);
  if (v_result->>'producto_plaza_id')::bigint<>v_local_a or (v_result->>'vinculo_creado')::boolean then
    raise exception 'No reutilizó el enlace existente';
  end if;

  -- Con dos representaciones enlazadas, la búsqueda las lista y la operación requiere el ID elegido.
  insert into public.productos(producto,rubro,stock_actual,stock_min,stock_max,activo,origen,sede,perecedero,urgente,tipo,unidad)
  values('Jarabe local A 91733','Insumos',0,0,0,'SÍ','bodega_producto_area_test','plaza',false,false,'Insumos','ml') returning id into v_local_a;
  insert into public.productos(producto,rubro,stock_actual,stock_min,stock_max,activo,origen,sede,perecedero,urgente,tipo,unidad)
  values('Jarabe local B 91733','Insumos',0,0,0,'SÍ','bodega_producto_area_test','plaza',false,false,'Insumos','ml') returning id into v_local_b;
  insert into public.producto_enlace(producto_bodega_id,sede,producto_sede_id,factor,creado_por) values
    (v_master_multi,'plaza',v_local_a,1,'test'),(v_master_multi,'plaza',v_local_b,1,'test');
  v_result:=public.bodega_productos_area_buscar(v_master_multi::text,v_cold);
  if jsonb_array_length(v_result->0->'representaciones')<>2 then raise exception 'No mostró todos los enlaces locales'; end if;
  v_result:=public.bodega_producto_area_agregar(v_master_multi,v_local_b,false,v_cold,null,null,null,false,true);
  if (v_result->>'producto_plaza_id')::bigint<>v_local_b then raise exception 'No respetó selección explícita de representación'; end if;
  v_result:=public.bodega_productos_area_buscar(v_master_multi::text,v_cold);
  if (v_result->0->>'ya_configurado_en_area')::boolean is not true then raise exception 'No señaló configuración existente por maestro'; end if;
  v_result:=public.bodega_producto_area_agregar(v_master_multi,v_local_a,false,v_cold,null,null,null,false,true);
  if (v_result->>'ya_configurado')::boolean is not true or (v_result->>'producto_plaza_id')::bigint<>v_local_b then
    raise exception 'Una segunda representación generó otra configuración de la misma identidad maestra';
  end if;
  select count(*) into v_rows from public.producto_area_asignacion pa
    join public.producto_enlace e on e.sede='plaza' and e.producto_sede_id=pa.producto_id
    where e.producto_bodega_id=v_master_multi and pa.area_id=v_cold and pa.estado='asignado';
  if v_rows<>1 then raise exception 'Duplicó configuración producto maestro-área'; end if;

  -- Coincidencia local de nombre distinto: se presenta como candidata, nunca se enlaza sola.
  insert into public.productos(producto,rubro,stock_actual,stock_min,stock_max,activo,origen,sede,perecedero,urgente,tipo,unidad)
  values('Menta en hojas local 91734','Insumos',0,0,0,'SÍ','bodega_producto_area_test','plaza',false,false,'Insumos','kg') returning id into v_candidate;
  v_result:=public.bodega_productos_area_buscar('hojas de menta prueba 91734',v_cold);
  if not exists(select 1 from jsonb_array_elements(v_result->0->'posibles_representaciones') r where (r->>'producto_plaza_id')::bigint=v_candidate)
     then raise exception 'No presentó la candidata local de nombre distinto'; end if;
  v_result:=public.bodega_producto_area_agregar(v_master_candidate,v_candidate,false,v_cold,null,null,null,false,true);
  if not exists(select 1 from public.producto_enlace e where e.producto_bodega_id=v_master_candidate and e.producto_sede_id=v_candidate and e.sede='plaza')
     then raise exception 'La vinculación explícita de candidato no quedó registrada'; end if;

  -- No permite crear una copia cuando ya existe el mismo nombre normalizado local.
  insert into public.productos(producto,rubro,stock_actual,stock_min,stock_max,activo,origen,sede,perecedero,urgente,tipo,unidad)
  values('NARANJA exacta prueba 91735','Fruta',0,0,0,'SÍ','bodega_producto_area_test','plaza',false,false,'Fruta','kg');
  v_exception:=false;
  begin
    perform public.bodega_producto_area_agregar(v_master_duplicate,null,true,v_cold,null,null,null,false,true);
  exception when unique_violation then v_exception:=true;
  end;
  if not v_exception then raise exception 'Se permitió crear representación duplicada normalizada'; end if;

  if (select count(*) from public.producto_lotes)<>v_lots_before
     or (select count(*) from stock_internal.movimientos)<>v_movements_before
     or (select count(*) from stock_internal.existencias)<>v_ledger_rows_before
     or (select coalesce(sum(cantidad),0) from stock_internal.existencias)<>v_ledger_total_before
     then raise exception 'La prueba alteró lotes, movimientos o ledger'; end if;
end
$test$;

do $permissions$
declare
  v_area uuid;
  v_blocked boolean:=false;
begin
  select id into v_area from public.areas_operativas
    where sede='plaza' and codigo='cocina_fria' and estado='activa';
  if has_function_privilege('anon','public.bodega_productos_area_buscar(text,uuid)','EXECUTE')
     or has_function_privilege('service_role','public.bodega_producto_area_agregar(bigint,bigint,boolean,uuid,uuid,numeric,numeric,boolean,boolean)','EXECUTE')
     or not has_function_privilege('authenticated','public.bodega_producto_area_agregar(bigint,bigint,boolean,uuid,uuid,numeric,numeric,boolean,boolean)','EXECUTE') then
    raise exception 'Grants EXECUTE de las RPC nuevas son incorrectos';
  end if;
  if has_table_privilege('authenticated','public.producto_area_asignacion','INSERT')
     or has_table_privilege('authenticated','public.producto_area_asignacion','UPDATE') then
    raise exception 'Se habilitó DML directo en la configuración de área';
  end if;
  perform set_config('request.jwt.claim.sub','decc9a8d-0ab6-4306-bab5-a62bcaa40338',true);
  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub','decc9a8d-0ab6-4306-bab5-a62bcaa40338','role','anon')::text,true);
  begin
    perform public.bodega_productos_area_buscar('leche',v_area);
  exception when insufficient_privilege then v_blocked:=true;
  end;
  if not v_blocked then raise exception 'Una sesión no autenticada pudo ejecutar la búsqueda'; end if;
end
$permissions$;

rollback;
