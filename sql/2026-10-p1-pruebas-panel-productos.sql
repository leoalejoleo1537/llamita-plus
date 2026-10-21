begin;
do $test$
declare
  v_root uuid:='decc9a8d-0ab6-4306-bab5-a62bcaa40338';
  v_oper uuid:='6c3f6e47-7a26-40ce-84f6-9fe26925d642';
  v_ref uuid:=gen_random_uuid(); v_ref2 uuid:=gen_random_uuid();
  v_area1 uuid; v_area2 uuid; v_data jsonb; v_r jsonb; v_r2 jsonb;
  v_m bigint; v_l bigint; v_otro bigint; v_count bigint; v_rejected boolean;
  v_before jsonb; v_after jsonb;
begin
  select jsonb_build_object('stock',(select sum(stock_actual) from public.productos),
    'ledger',(select count(*) from stock_internal.movimientos),'existencias',(select sum(cantidad) from stock_internal.existencias),
    'lotes',(select count(*) from public.producto_lotes),'transferencias',(select count(*) from stock_internal.transferencias),
    'fudo',(select count(*) from public.fudo_movimientos),'espejo',(select count(*) from public.fudo_productos),
    'recetas',(select count(*) from public.recetas),'items',(select count(*) from public.receta_items),
    'lama',(select count(*) from stock_internal.lama_reservas),'repartos',(select count(*) from stock_internal.repartos_area),
    'caja',(select count(*) from public.lama_caja_movimientos)) into v_before;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_root,'role','authenticated')::text,true);
  select id into v_area1 from public.areas_operativas where estado='activa' order by orden,id limit 1;
  select id into v_area2 from public.areas_operativas where estado='activa' and id<>v_area1 order by orden,id limit 1;
  if v_area1 is null or v_area2 is null then raise exception 'Se requieren dos áreas.'; end if;
  v_data:=jsonb_build_object('nombre','P1 TEST '||v_ref,'unidad','kg','rubro','Insumos','costo_compra',0,'costo_pendiente',true,
    'areas',jsonb_build_array(jsonb_build_object('area_id',v_area1,'stock_min',1,'stock_max',3,'es_principal',true),jsonb_build_object('area_id',v_area2)));
  v_r:=public.panel_producto_guardar(v_ref,null,null,v_data);
  v_m:=(v_r->>'maestro_id')::bigint; v_l:=(v_r->>'representacion_id')::bigint;
  if v_m is null or v_l is null or (select count(*) from public.producto_area_asignacion where producto_id=v_l and estado='asignado')<>2 then
    raise exception 'Alta maestro/representación/multiárea incompleta.';
  end if;
  if exists(select 1 from public.productos where id in (v_m,v_l) and stock_actual<>0)
    or exists(select 1 from stock_internal.existencias where producto_id in (v_m,v_l))
    or exists(select 1 from public.producto_lotes where producto_id in (v_m,v_l)) then raise exception 'Alta creó existencias/lotes.'; end if;
  v_r2:=public.panel_producto_guardar(v_ref,null,null,v_data);
  if v_r2<>v_r then raise exception 'Reintento no idempotente.'; end if;
  v_rejected:=false;
  begin perform public.panel_producto_guardar(v_ref,null,null,v_data||'{"unidad":"g"}'); exception when sqlstate '22023' then v_rejected:=true; end;
  if not v_rejected then raise exception 'Referencia con contenido distinto aceptada.'; end if;
  v_rejected:=false;
  begin perform public.panel_producto_guardar(gen_random_uuid(),null,null,v_data); exception when unique_violation then v_rejected:=true; end;
  if not v_rejected then raise exception 'Duplicado aceptado.'; end if;

  -- Segundo enlace histórico explícito; el trigger debe heredar atributos.
  insert into public.productos(producto,rubro,sede,stock_actual,unidad,activo) values('P1 alias','Insumos','plaza',0,'otro','SÍ') returning id into v_otro;
  insert into public.producto_enlace(producto_bodega_id,producto_sede_id,sede,factor) values(v_m,v_otro,'plaza',1);
  if (select unidad from public.productos where id=v_otro)<>'kg' then raise exception 'Enlace posterior no heredó el maestro.'; end if;
  v_data:=v_data||jsonb_build_object('nombre','P1 EDIT '||v_ref,'unidad','g','costo_compra',12.345678,'costo_pendiente',false,'areas','[]'::jsonb);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_oper,'role','authenticated')::text,true);
  v_r:=public.panel_producto_guardar(v_ref2,v_m,1,v_data);
  if exists(select 1 from public.productos where id in(v_m,v_l,v_otro) and (producto<>v_data->>'nombre' or unidad<>'g' or costo_compra<>12.345678 or costo_pendiente)) then
    raise exception 'Nombre/unidad/costo divergentes.';
  end if;
  if not exists(select 1 from catalogo_internal.operaciones where referencia=v_ref2 and actor=v_oper and anterior is not null) then raise exception 'Falta auditoría.'; end if;
  if (public.panel_productos_listar('',v_m)->'productos'->0->>'producto')<>v_data->>'nombre' then raise exception 'Lectura del Panel incorrecta.'; end if;

  -- Revisión optimista: equivale al segundo guardado concurrente tras el bloqueo.
  v_rejected:=false;
  begin perform public.panel_producto_guardar(gen_random_uuid(),v_m,1,v_data); exception when serialization_failure then v_rejected:=true; end;
  if not v_rejected then raise exception 'Se sobrescribió una revisión obsoleta.'; end if;
  v_rejected:=false;
  begin update public.productos set unidad='litro' where id=v_l; exception when insufficient_privilege then v_rejected:=true; end;
  if not v_rejected then raise exception 'Edición local independiente aceptada.'; end if;
  v_rejected:=false;
  begin update public.productos set producto='falso' where id=v_m; exception when insufficient_privilege then v_rejected:=true; end;
  if not v_rejected then raise exception 'Maestro editable fuera del RPC.'; end if;
  v_rejected:=false;
  begin delete from public.producto_enlace where producto_sede_id=v_l; exception when insufficient_privilege then v_rejected:=true; end;
  if not v_rejected then raise exception 'Desvinculación dejó copia aislada.'; end if;
  v_rejected:=false;
  begin update catalogo_internal.operaciones set resultado='{}' where referencia=v_ref; exception when raise_exception then v_rejected:=true; end;
  if not v_rejected then raise exception 'Auditoría mutable.'; end if;

  -- Falla al final revierte también el cambio maestro y su propagación.
  v_rejected:=false;
  begin perform public.panel_producto_guardar(gen_random_uuid(),v_m,2,v_data||jsonb_build_object('nombre','P1 NO GUARDAR',
    'representacion_id',v_l,'areas',jsonb_build_array(jsonb_build_object('area_id',gen_random_uuid()))));
  exception when others then v_rejected:=true; end;
  if not v_rejected or (select catalogo_revision from public.productos where id=v_m)<>2 then raise exception 'Falta atomicidad.'; end if;

  -- Varias representaciones exigen elección, no se adivina por nombre.
  v_rejected:=false;
  begin perform public.panel_producto_guardar(gen_random_uuid(),v_m,2,v_data||jsonb_build_object('areas',jsonb_build_array(jsonb_build_object('area_id',v_area1))));
  exception when sqlstate '22023' then v_rejected:=true; end;
  if not v_rejected then raise exception 'Ambigüedad no rechazada.'; end if;
  perform public.panel_producto_guardar(gen_random_uuid(),v_m,2,v_data||jsonb_build_object('representacion_id',v_l,
    'areas',jsonb_build_array(jsonb_build_object('area_id',v_area1,'stock_min',2,'stock_max',5,'es_principal',true))));
  if (select count(*) from public.producto_area_asignacion where producto_id=v_l and estado='asignado')<>2 then raise exception 'Perdió configuración de área omitida.'; end if;

  perform set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'role','authenticated')::text,true);
  v_rejected:=false;
  begin perform public.panel_producto_guardar(gen_random_uuid(),null,null,v_data); exception when insufficient_privilege then v_rejected:=true; end;
  if not v_rejected then raise exception 'Usuario sin permiso pudo guardar.'; end if;
  perform set_config('request.jwt.claims','{}',true);
  v_rejected:=false;
  begin perform public.panel_productos_listar(); exception when insufficient_privilege then v_rejected:=true; end;
  if not v_rejected then raise exception 'Anónimo pudo leer.'; end if;
  if has_function_privilege('anon','public.panel_producto_guardar(uuid,bigint,bigint,jsonb)','EXECUTE')
    or has_function_privilege('service_role','public.panel_producto_guardar(uuid,bigint,bigint,jsonb)','EXECUTE')
    or has_table_privilege('authenticated','catalogo_internal.operaciones','INSERT') then raise exception 'ACL incorrecta.'; end if;
  if exists(select 1 from catalogo_internal.permiso_escritura) then raise exception 'Permiso transitorio quedó activo.'; end if;
  select jsonb_build_object('stock',(select sum(stock_actual) from public.productos),
    'ledger',(select count(*) from stock_internal.movimientos),'existencias',(select sum(cantidad) from stock_internal.existencias),
    'lotes',(select count(*) from public.producto_lotes),'transferencias',(select count(*) from stock_internal.transferencias),
    'fudo',(select count(*) from public.fudo_movimientos),'espejo',(select count(*) from public.fudo_productos),
    'recetas',(select count(*) from public.recetas),'items',(select count(*) from public.receta_items),
    'lama',(select count(*) from stock_internal.lama_reservas),'repartos',(select count(*) from stock_internal.repartos_area),
    'caja',(select count(*) from public.lama_caja_movimientos)) into v_after;
  if v_before<>v_after then raise exception 'Cambió stock u otro módulo: % / %',v_before,v_after; end if;
end $test$;
-- Ejecución con ACL/RLS del rol de navegador, no solo identidad simulada.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"decc9a8d-0ab6-4306-bab5-a62bcaa40338","role":"authenticated"}',true);
do $$ declare r jsonb; begin
  r:=public.panel_producto_guardar(gen_random_uuid(),null,null,jsonb_build_object(
    'nombre','P1 AUTH '||gen_random_uuid(),'rubro','Insumos','unidad','kg','areas','[]'::jsonb));
  if (public.panel_productos_listar('',(r->>'maestro_id')::bigint)->'productos'->0->>'costo_pendiente')<>'true' then
    raise exception 'El rol authenticated no puede usar el Panel.';
  end if;
end $$;
reset role;
select 'P1: alta, edición coherente, reintento, conflicto, permisos, atomicidad y cero efecto físico OK' resultado;
rollback;
