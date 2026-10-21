begin;

do $test$
declare
  v_root uuid:='decc9a8d-0ab6-4306-bab5-a62bcaa40338';
  v_oper uuid:='6c3f6e47-7a26-40ce-84f6-9fe26925d642';
  v_area1 uuid; v_area2 uuid; v_ref uuid:=gen_random_uuid();
  v_r jsonb; v_r2 jsonb; v_m bigint; v_l bigint; v_m_rec bigint; v_l_rec bigint;
  v_before jsonb; v_after jsonb; v_rejected boolean:=false;
begin
  select jsonb_build_object(
    'stock',(select coalesce(sum(stock_actual),0) from public.productos),
    'ledger',(select count(*) from stock_internal.movimientos),
    'existencias',(select coalesce(sum(cantidad),0) from stock_internal.existencias),
    'lotes',(select count(*) from public.producto_lotes),
    'transferencias',(select count(*) from stock_internal.transferencias),
    'repartos',(select count(*) from stock_internal.repartos_area),
    'recetas',(select count(*) from public.recetas),
    'items',(select count(*) from public.receta_items),
    'fudo',(select count(*) from public.fudo_movimientos),
    'lama',(select count(*) from stock_internal.lama_reservas)
  ) into v_before;
  select id into v_area1 from public.areas_operativas where sede='plaza' and estado='activa' order by orden,id limit 1;
  select id into v_area2 from public.areas_operativas where sede='plaza' and estado='activa' and id<>v_area1 order by orden,id limit 1;
  if v_area1 is null or v_area2 is null then raise exception 'P2 requiere dos áreas activas.'; end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_root,'role','authenticated')::text,true);

  -- Alta desde un área: maestro central, representación enlazada y saldo cero.
  v_r:=public.panel_producto_guardar(v_ref,null,null,jsonb_build_object(
    'nombre','P2 AREA '||v_ref,'unidad','kg','rubro','Insumos','costo_compra',0,
    'costo_pendiente',true,'crear_representacion',true,
    'areas',jsonb_build_array(jsonb_build_object('area_id',v_area1,'stock_min',1,'stock_max',4,'es_principal',true))));
  v_m:=(v_r->>'maestro_id')::bigint;v_l:=(v_r->>'representacion_id')::bigint;
  if v_m is null or v_l is null
     or not exists(select 1 from public.producto_enlace where producto_bodega_id=v_m and producto_sede_id=v_l and sede='plaza')
     or not exists(select 1 from public.producto_area_asignacion where producto_id=v_l and area_id=v_area1 and estado='asignado') then
    raise exception 'Alta desde área no creó una identidad enlazada y configurada.';
  end if;
  if exists(select 1 from public.productos where id in(v_m,v_l) and stock_actual<>0)
     or exists(select 1 from stock_internal.existencias where producto_id in(v_m,v_l))
     or exists(select 1 from public.producto_lotes where producto_id in(v_m,v_l)) then
    raise exception 'El Panel creó saldo, existencias o lotes.';
  end if;
  v_r2:=public.panel_producto_guardar(v_ref,null,null,jsonb_build_object(
    'nombre','P2 AREA '||v_ref,'unidad','kg','rubro','Insumos','costo_compra',0,
    'costo_pendiente',true,'crear_representacion',true,
    'areas',jsonb_build_array(jsonb_build_object('area_id',v_area1,'stock_min',1,'stock_max',4,'es_principal',true))));
  if v_r2<>v_r then raise exception 'El reintento P2 no fue idempotente.'; end if;

  -- El mismo insumo se habilita en otra área sin otra identidad local.
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_oper,'role','authenticated')::text,true);
  perform public.panel_producto_guardar(gen_random_uuid(),v_m,1,jsonb_build_object(
    'nombre','P2 AREA '||v_ref,'unidad','kg','rubro','Insumos','costo_compra',0,
    'costo_pendiente',true,'representacion_id',v_l,'crear_representacion',true,
    'areas',jsonb_build_array(jsonb_build_object('area_id',v_area2))));
  if (select count(*) from public.producto_enlace where producto_bodega_id=v_m and sede='plaza')<>1
     or (select count(*) from public.producto_area_asignacion where producto_id=v_l and estado='asignado')<>2 then
    raise exception 'Reutilizar el insumo en dos áreas creó un duplicado o perdió configuración.';
  end if;

  -- Alta desde Recetas: representación explícita Sin asignar, todavía sin receta.
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_root,'role','authenticated')::text,true);
  v_r:=public.panel_producto_guardar(gen_random_uuid(),null,null,jsonb_build_object(
    'nombre','P2 RECETA '||gen_random_uuid(),'unidad','unidad','rubro','Insumos',
    'costo_compra',0,'costo_pendiente',true,'crear_representacion',true,'areas','[]'::jsonb));
  v_m_rec:=(v_r->>'maestro_id')::bigint;v_l_rec:=(v_r->>'representacion_id')::bigint;
  if v_m_rec is null or v_l_rec is null
     or not exists(select 1 from public.producto_area_asignacion where producto_id=v_l_rec and area_id is null and estado='sin_asignar') then
    raise exception 'El retorno a Recetas no obtuvo representación Sin asignar.';
  end if;
  if exists(select 1 from public.receta_items where producto_id=v_l_rec) then
    raise exception 'Crear ingrediente creó una receta automática.';
  end if;

  -- La capacidad sigue siendo obligatoria.
  perform set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'role','authenticated')::text,true);
  begin
    perform public.panel_producto_guardar(gen_random_uuid(),null,null,jsonb_build_object(
      'nombre','P2 SIN PERMISO','rubro','Insumos','crear_representacion',false,'areas','[]'::jsonb));
  exception when insufficient_privilege then v_rejected:=true; end;
  if not v_rejected then raise exception 'Usuario sin edición pudo crear.'; end if;

  if has_function_privilege('authenticated','public.crear_producto_enlazado(text,text,numeric,numeric,boolean,jsonb,text)','EXECUTE')
    or has_function_privilege('authenticated','public.producto_plaza_crear(text,text,double precision,double precision,boolean,text,text,uuid,text,text)','EXECUTE')
    or has_function_privilege('authenticated','public.producto_plaza_crear_configurado(text,text,double precision,double precision,boolean,text,text,uuid,uuid,text,text)','EXECUTE')
    or has_function_privilege('authenticated','public.bodega_producto_area_agregar(bigint,bigint,boolean,uuid,uuid,numeric,numeric,boolean,boolean)','EXECUTE')
    or has_function_privilege('anon','public.panel_producto_guardar(uuid,bigint,bigint,jsonb)','EXECUTE')
    or has_table_privilege('authenticated','public.productos','INSERT')
    or has_table_privilege('anon','public.productos','INSERT') then
    raise exception 'Sobrevive una ruta de alta heredada o DML directo.';
  end if;

  select jsonb_build_object(
    'stock',(select coalesce(sum(stock_actual),0) from public.productos),
    'ledger',(select count(*) from stock_internal.movimientos),
    'existencias',(select coalesce(sum(cantidad),0) from stock_internal.existencias),
    'lotes',(select count(*) from public.producto_lotes),
    'transferencias',(select count(*) from stock_internal.transferencias),
    'repartos',(select count(*) from stock_internal.repartos_area),
    'recetas',(select count(*) from public.recetas),
    'items',(select count(*) from public.receta_items),
    'fudo',(select count(*) from public.fudo_movimientos),
    'lama',(select count(*) from stock_internal.lama_reservas)
  ) into v_after;
  if v_before<>v_after then raise exception 'P2 alteró un módulo físico/comercial: % / %',v_before,v_after; end if;
end $test$;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"decc9a8d-0ab6-4306-bab5-a62bcaa40338","role":"authenticated"}',true);
do $$
declare v_rejected boolean:=false;
begin
  begin insert into public.productos(producto,rubro,sede,stock_actual) values('P2 DML BLOQUEADO','Insumos','central',0);
  exception when insufficient_privilege then v_rejected:=true; end;
  if not v_rejected then raise exception 'authenticated conserva INSERT directo en productos.'; end if;
end $$;
reset role;

select 'P2: Bodega/área/Recetas usan una identidad, saldo cero, ACL cerrada e idempotencia OK' resultado;
rollback;
