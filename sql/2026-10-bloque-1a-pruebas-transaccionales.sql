-- Bloque 1A: toda escritura sintética queda dentro de BEGIN/ROLLBACK.
begin;

do $test$
declare
  v_raiz constant uuid:='decc9a8d-0ab6-4306-bab5-a62bcaa40338'::uuid;
  v_operador constant uuid:='6c3f6e47-7a26-40ce-84f6-9fe26925d642'::uuid;
  v_comun constant uuid:='00000000-0000-4000-8000-000000000099'::uuid;
  v_area_1 uuid; v_area_2 uuid; v_seccion uuid; v_producto bigint; v_nuevo bigint;
  v_config_1 uuid; v_config_2 uuid; v_json jsonb;
  v_productos bigint; v_lotes bigint; v_mov_legacy bigint; v_mov_ledger bigint;
  v_recetas bigint; v_fudo bigint; v_lama bigint; v_ledger numeric; v_stock numeric;
begin
  select count(*),coalesce(sum(stock_actual),0) into v_productos,v_stock from public.productos;
  select count(*) into v_lotes from public.producto_lotes;
  select count(*) into v_mov_legacy from public.movimientos;
  select count(*),coalesce(sum(cantidad),0) into v_mov_ledger,v_ledger from stock_internal.movimientos;
  select count(*) into v_recetas from public.recetas;
  select count(*) into v_fudo from public.fudo_movimientos;
  select count(*) into v_lama from public.lama_stock_eventos;

  select id into v_area_1 from public.areas_operativas
  where sede='plaza' and estado='activa' order by orden,id limit 1;
  select id into v_area_2 from public.areas_operativas
  where sede='plaza' and estado='activa' and id<>v_area_1 order by orden,id limit 1;
  select p.id into v_producto from public.productos p
  where p.sede='plaza' and p.activo='SÍ'
    and not exists(select 1 from public.producto_area_asignacion pa
      where pa.producto_id=p.id and pa.estado='asignado')
  order by p.id limit 1;
  if v_area_1 is null or v_area_2 is null or v_producto is null then
    raise exception 'Precondición de prueba: faltan dos áreas activas o un producto disponible.';
  end if;

  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',v_raiz,'role','authenticated','email',(select email from auth.users where id=v_raiz))::text,true);
  execute 'set local role authenticated';

  v_seccion:=public.area_seccion_crear(v_area_1,'Refrigerador prueba 1A',10,'am',null);
  execute 'reset role';
  if not exists(select 1 from public.area_secciones s
    where s.id=v_seccion and s.turno='am' and s.estado='activa') then
    raise exception 'Falla: no se creó la sección física.';
  end if;
  execute 'set local role authenticated';
  begin
    perform public.area_seccion_crear(v_area_1,'  REFRIGERADOR   PRUEBA 1A ',20,'pm','otro_codigo');
    raise exception 'Falla: se aceptó un nombre normalizado duplicado.';
  exception when unique_violation then null;
  end;

  v_json:=public.producto_area_configuracion_guardar(
    v_producto,v_area_1,v_seccion,2,8,true,'plaza');
  v_config_1:=(v_json->>'id')::uuid;
  v_json:=public.producto_area_configuracion_guardar(
    v_producto,v_area_2,null,1,5,false,'plaza');
  v_config_2:=(v_json->>'id')::uuid;
  execute 'reset role';
  if (select count(*) from public.producto_area_asignacion pa
      where pa.producto_id=v_producto and pa.estado='asignado')<>2 then
    raise exception 'Falla: un mismo producto no quedó configurado en dos áreas.';
  end if;
  if not exists(select 1 from public.stock_leer_areas() r
    where r.configuracion_id=v_config_1 and r.configurado and r.cantidad=0
      and r.stock_min=2 and r.stock_max=8 and r.seccion_id=v_seccion) then
    raise exception 'Falla: la lectura no muestra la configuración con saldo cero.';
  end if;
  if (select count(*) from public.producto_area_asignacion pa
      where pa.producto_id=v_producto and pa.es_principal and pa.estado='asignado')<>1 then
    raise exception 'Falla: hay más de un área principal para el producto.';
  end if;

  -- Cambiar organización nunca altera el ledger.
  execute 'set local role authenticated';
  perform public.producto_area_configuracion_guardar(v_producto,v_area_1,v_seccion,3,9,true,'plaza');
  execute 'reset role';
  if (select count(*) from stock_internal.movimientos)<>v_mov_ledger
     or (select coalesce(sum(cantidad),0) from stock_internal.movimientos)<>v_ledger then
    raise exception 'Falla: guardar sección o límites alteró el ledger.';
  end if;

  -- Alta atómica: ficha + configuración, siempre sin saldo, lote ni movimiento.
  v_json:=public.producto_plaza_crear_configurado(
    'Producto sintético Bloque 1A','Pruebas',1,6,false,'Pruebas','unidad',
    v_area_1,v_seccion,null,'plaza');
  v_nuevo:=(v_json->>'producto_id')::bigint;
  execute 'reset role';
  if not exists(select 1 from public.productos p where p.id=v_nuevo and p.stock_actual=0)
     or not exists(select 1 from public.producto_area_asignacion pa
       where pa.producto_id=v_nuevo and pa.area_id=v_area_1 and pa.seccion_id=v_seccion
         and pa.stock_min=1 and pa.stock_max=6)
     or exists(select 1 from public.producto_lotes where producto_id=v_nuevo)
     or exists(select 1 from public.movimientos where producto_id=v_nuevo)
     or exists(select 1 from stock_internal.movimientos where producto_id=v_nuevo) then
    raise exception 'Falla: el alta configurada creó saldo, lote o movimiento.';
  end if;

  -- El administrador operativo puede administrar secciones y configuraciones.
  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',v_operador,'role','authenticated','email',(select email from auth.users where id=v_operador))::text,true);
  execute 'set local role authenticated';
  perform public.area_seccion_editar(v_seccion,'Refrigerador prueba editado',11,'pm');
  perform public.producto_area_configuracion_guardar(v_producto,v_area_1,v_seccion,3,10,true,'plaza');
  perform count(*) from public.area_secciones_listar(v_area_1,false);

  -- Un usuario común ve áreas/secciones, pero no las administra ni configura productos.
  execute 'reset role';
  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',v_comun,'role','authenticated','email','comun@example.invalid')::text,true);
  execute 'set local role authenticated';
  perform count(*) from public.areas_operativas_listar('plaza',false);
  perform count(*) from public.area_secciones_listar(v_area_1,false);
  begin
    perform public.area_seccion_crear(v_area_1,'No autorizada',30,'pm',null);
    raise exception 'Falla: el usuario común creó una sección.';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.producto_area_configuracion_guardar(v_producto,v_area_1,null,0,1,false,'plaza');
    raise exception 'Falla: el usuario común configuró un producto.';
  exception when insufficient_privilege then null;
  end;

  execute 'reset role';
  execute 'set local role anon';
  begin
    perform count(*) from public.area_secciones_listar(v_area_1,false);
    raise exception 'Falla: anon ejecutó la lectura protegida.';
  exception when insufficient_privilege then null;
  end;
  execute 'reset role';

  -- Archivo lógico: exige confirmación si hay productos y solo limpia la sección.
  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',v_raiz,'role','authenticated','email',(select email from auth.users where id=v_raiz))::text,true);
  execute 'set local role authenticated';
  begin
    perform public.area_seccion_archivar(v_seccion,false);
    raise exception 'Falla: se archivó una sección ocupada sin confirmación.';
  exception when check_violation then null;
  end;
  perform public.area_seccion_archivar(v_seccion,true);
  execute 'reset role';
  if exists(select 1 from public.producto_area_asignacion where seccion_id=v_seccion and estado='asignado')
     or not exists(select 1 from public.area_secciones where id=v_seccion and estado='archivada') then
    raise exception 'Falla: el archivo lógico no dejó productos Sin sección.';
  end if;

  if to_regprocedure('public.stock_transferir(uuid,bigint,bigint,uuid,uuid,numeric,text,bigint)') is null then
    raise exception 'Falla: cambió la firma protegida de stock_transferir.';
  end if;
  if (select count(*) from public.productos)<>v_productos+1
     or (select coalesce(sum(stock_actual),0) from public.productos)<>v_stock
     or (select count(*) from public.producto_lotes)<>v_lotes
     or (select count(*) from public.movimientos)<>v_mov_legacy
     or (select count(*) from stock_internal.movimientos)<>v_mov_ledger
     or (select count(*) from public.recetas)<>v_recetas
     or (select count(*) from public.fudo_movimientos)<>v_fudo
     or (select count(*) from public.lama_stock_eventos)<>v_lama then
    raise exception 'Falla: conteos contables/comerciales cambiaron fuera del alta sintética esperada.';
  end if;
end
$test$;

rollback;
