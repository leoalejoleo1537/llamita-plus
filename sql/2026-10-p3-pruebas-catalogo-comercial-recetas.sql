begin;

do $test$
declare
  v_root uuid:='decc9a8d-0ab6-4306-bab5-a62bcaa40338';
  v_oper uuid:='6c3f6e47-7a26-40ce-84f6-9fe26925d642';
  v_asig1 uuid;v_asig2 uuid;v_asig3 uuid;v_asig_otra uuid;v_inactiva uuid;
  v_area_otra uuid;v_producto bigint;v_maestro bigint;v_revision bigint;
  v_ref uuid:=gen_random_uuid();v_r jsonb;v_r2 jsonb;v_producto_venta uuid;
  v_before jsonb;v_after jsonb;v_rejected boolean;
begin
  select jsonb_build_object(
    'productos',(select count(*) from public.productos),
    'stock',(select coalesce(sum(stock_actual),0) from public.productos),
    'existencias',(select coalesce(sum(cantidad),0) from stock_internal.existencias),
    'ledger',(select count(*) from stock_internal.movimientos),
    'lotes',(select count(*) from public.producto_lotes),
    'transferencias',(select count(*) from stock_internal.transferencias),
    'repartos',(select count(*) from stock_internal.repartos_area),
    'recetas_legacy',(select count(*) from public.recetas),
    'items_legacy',(select count(*) from public.receta_items),
    'fudo_productos',(select count(*) from public.fudo_productos),
    'fudo_movimientos',(select count(*) from public.fudo_movimientos),
    'lama_reservas',(select count(*) from stock_internal.lama_reservas)
  ) into v_before;

  select max(id::text) filter(where n=1)::uuid,max(id::text) filter(where n=2)::uuid,max(id::text) filter(where n=3)::uuid
    into v_asig1,v_asig2,v_asig3
  from (select pa.id,row_number() over(order by pa.id) n
    from public.producto_area_asignacion pa
    join public.productos p on p.id=pa.producto_id and p.sede='plaza' and p.activo='SÍ'
    join public.producto_enlace e on e.producto_sede_id=p.id and e.sede='plaza'
    join public.areas_operativas a on a.id=pa.area_id and a.estado='activa'
    join stock_internal.ubicaciones u on u.area_id=a.id and u.activa
    where pa.estado='asignado' and pa.archivado_at is null limit 3) q;
  if v_asig1 is null or v_asig2 is null or v_asig3 is null then
    raise exception 'P3 requiere tres insumos configurados para la prueba.';
  end if;

  -- Se agrega transaccionalmente una segunda área al primer insumo para
  -- probar receta multiárea sin dejar configuración sintética persistente.
  select pa.producto_id,e.producto_bodega_id,m.catalogo_revision
    into v_producto,v_maestro,v_revision
  from public.producto_area_asignacion pa
  join public.producto_enlace e on e.producto_sede_id=pa.producto_id and e.sede='plaza'
  join public.productos m on m.id=e.producto_bodega_id
  where pa.id=v_asig1;
  select a.id into v_area_otra from public.areas_operativas a
    where a.sede='plaza' and a.estado='activa'
      and a.id<>(select area_id from public.producto_area_asignacion where id=v_asig1)
    order by a.orden,a.id limit 1;
  if v_area_otra is null then raise exception 'P3 requiere una segunda área activa.'; end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_root,'role','authenticated')::text,true);
  perform public.panel_producto_guardar(gen_random_uuid(),v_maestro,v_revision,(
    select jsonb_build_object(
      'nombre',m.producto,'unidad',m.unidad,'rubro',m.rubro,
      'costo_compra',m.costo_compra,'costo_pendiente',m.costo_pendiente,
      'representacion_id',v_producto,'crear_representacion',true,
      'areas',jsonb_build_array(jsonb_build_object('area_id',v_area_otra))
    ) from public.productos m where m.id=v_maestro));
  select id into v_asig_otra from public.producto_area_asignacion
    where producto_id=v_producto and area_id=v_area_otra and estado='asignado';
  select id into v_inactiva from public.producto_area_asignacion
    where estado<>'asignado' order by id limit 1;
  if v_asig_otra is null or v_inactiva is null then raise exception 'No se preparó origen alterno/inactivo.'; end if;

  -- Borrador vacío: identidad comercial neutral, sin receta automática.
  v_r:=public.panel_venta_guardar(v_ref,null,null,jsonb_build_object(
    'nombre','P3 Borrador '||v_ref,'precio_venta',3500,'estado','borrador','componentes','[]'::jsonb));
  v_producto_venta:=(v_r->>'producto_venta_id')::uuid;
  if v_producto_venta is null or (v_r->>'receta_id') is not null
     or exists(select 1 from catalogo_internal.recetas_venta where producto_venta_id=v_producto_venta) then
    raise exception 'El borrador vacío creó receta automática.';
  end if;
  v_r2:=public.panel_venta_guardar(v_ref,null,null,jsonb_build_object(
    'nombre','P3 Borrador '||v_ref,'precio_venta',3500,'estado','borrador','componentes','[]'::jsonb));
  if v_r2<>v_r then raise exception 'El reintento no fue idempotente.'; end if;
  v_rejected:=false;
  begin
    perform public.panel_venta_guardar(v_ref,null,null,jsonb_build_object(
      'nombre','P3 referencia distinta','precio_venta',1,'estado','borrador','componentes','[]'::jsonb));
  exception when invalid_parameter_value then v_rejected:=true; end;
  if not v_rejected then raise exception 'Se reutilizó una referencia con otro contenido.'; end if;

  -- Receta manual de una línea.
  v_r:=public.panel_venta_guardar(gen_random_uuid(),null,null,jsonb_build_object(
    'nombre','P3 Simple '||gen_random_uuid(),'precio_venta',2500,'estado','listo',
    'componentes',jsonb_build_array(jsonb_build_object('asignacion_id',v_asig1,'cantidad',1))));
  if (v_r->>'estado')<>'listo' or (v_r->>'ingredientes')::int<>1 then
    raise exception 'No se creó la receta manual de una línea.';
  end if;

  -- Tres ingredientes, decimal y un origen de otra área; conserva el orden.
  v_r:=public.panel_venta_guardar(gen_random_uuid(),null,null,jsonb_build_object(
    'nombre','P3 Compuesto '||gen_random_uuid(),'precio_venta',4800,'estado','listo',
    'componentes',jsonb_build_array(
      jsonb_build_object('asignacion_id',v_asig2,'cantidad',1),
      jsonb_build_object('asignacion_id',v_asig_otra,'cantidad',0.5),
      jsonb_build_object('asignacion_id',v_asig3,'cantidad',1)
    )));
  if (select array_agg(c.asignacion_id order by c.orden)
      from catalogo_internal.receta_venta_componentes c where c.receta_id=(v_r->>'receta_id')::uuid)
     <> array[v_asig2,v_asig_otra,v_asig3]
     or not exists(select 1 from catalogo_internal.receta_venta_componentes c
       where c.receta_id=(v_r->>'receta_id')::uuid and c.cantidad=0.5) then
    raise exception 'P3 perdió orden, decimal u origen multiárea.';
  end if;

  -- Vacía lista, cantidad cero/negativa y origen inactivo se rechazan.
  v_rejected:=false;
  begin perform public.panel_venta_guardar(gen_random_uuid(),null,null,jsonb_build_object(
    'nombre','P3 Vacía '||gen_random_uuid(),'precio_venta',1,'estado','listo','componentes','[]'::jsonb));
  exception when invalid_parameter_value then v_rejected:=true; end;
  if not v_rejected then raise exception 'Una receta vacía quedó lista.'; end if;
  foreach v_r in array array[
    jsonb_build_object('asignacion_id',v_asig1,'cantidad',0),
    jsonb_build_object('asignacion_id',v_asig1,'cantidad',-1),
    jsonb_build_object('asignacion_id',v_inactiva,'cantidad',1)
  ] loop
    v_rejected:=false;
    begin perform public.panel_venta_guardar(gen_random_uuid(),null,null,jsonb_build_object(
      'nombre','P3 Rechazo '||gen_random_uuid(),'precio_venta',1,'estado','borrador',
      'componentes',jsonb_build_array(v_r)));
    exception when invalid_parameter_value then v_rejected:=true; end;
    if not v_rejected then raise exception 'P3 aceptó cantidad u origen inválido: %',v_r; end if;
  end loop;

  -- Usuario operativo con edición sí; usuario sin permiso y anon no.
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_oper,'role','authenticated')::text,true);
  perform public.panel_venta_guardar(gen_random_uuid(),null,null,jsonb_build_object(
    'nombre','P3 Operativo '||gen_random_uuid(),'precio_venta',0,'estado','borrador','componentes','[]'::jsonb));
  perform set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'role','authenticated')::text,true);
  v_rejected:=false;
  begin perform public.panel_venta_guardar(gen_random_uuid(),null,null,jsonb_build_object(
    'nombre','P3 Sin permiso','precio_venta',0,'estado','borrador','componentes','[]'::jsonb));
  exception when insufficient_privilege then v_rejected:=true; end;
  if not v_rejected then raise exception 'Usuario sin edición pudo crear un producto de venta.'; end if;
  perform set_config('request.jwt.claims','{"role":"anon"}',true);
  v_rejected:=false;
  begin perform public.panel_ventas_listar('',null);
  exception when insufficient_privilege then v_rejected:=true; end;
  if not v_rejected then raise exception 'Anon pudo leer el catálogo neutral.'; end if;

  if has_function_privilege('anon','public.panel_ventas_listar(text,uuid)','EXECUTE')
     or has_function_privilege('anon','public.panel_ingredientes_listar(text)','EXECUTE')
     or has_function_privilege('anon','public.panel_venta_guardar(uuid,uuid,bigint,jsonb)','EXECUTE')
     or has_table_privilege('authenticated','catalogo_internal.productos_venta','INSERT')
     or has_table_privilege('authenticated','catalogo_internal.recetas_venta','INSERT')
     or has_table_privilege('authenticated','catalogo_internal.receta_venta_componentes','INSERT') then
    raise exception 'P3 expuso DML o RPC a anon.';
  end if;

  select jsonb_build_object(
    'productos',(select count(*) from public.productos),
    'stock',(select coalesce(sum(stock_actual),0) from public.productos),
    'existencias',(select coalesce(sum(cantidad),0) from stock_internal.existencias),
    'ledger',(select count(*) from stock_internal.movimientos),
    'lotes',(select count(*) from public.producto_lotes),
    'transferencias',(select count(*) from stock_internal.transferencias),
    'repartos',(select count(*) from stock_internal.repartos_area),
    'recetas_legacy',(select count(*) from public.recetas),
    'items_legacy',(select count(*) from public.receta_items),
    'fudo_productos',(select count(*) from public.fudo_productos),
    'fudo_movimientos',(select count(*) from public.fudo_movimientos),
    'lama_reservas',(select count(*) from stock_internal.lama_reservas)
  ) into v_after;
  if v_before<>v_after then raise exception 'P3 alteró stock, POS o recetas heredadas: % / %',v_before,v_after; end if;
end
$test$;

select 'P3: catálogo neutral, recetas manuales, origen explícito, ACL e invariantes OK' resultado;
rollback;
