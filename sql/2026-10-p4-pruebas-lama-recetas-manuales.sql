begin;

do $test$
declare
  v_root uuid:='decc9a8d-0ab6-4306-bab5-a62bcaa40338';
  v_oper uuid:='6c3f6e47-7a26-40ce-84f6-9fe26925d642';
  v_asig1 uuid;v_asig2 uuid;v_prod1 bigint;v_prod2 bigint;v_ubi1 uuid;v_ubi2 uuid;
  v_pv_simple uuid;v_pv_combo uuid;v_res jsonb;v_mesa bigint;v_cuenta bigint;
  v_item bigint;v_item_combo bigint;v_comanda bigint;v_ledger bigint;v_saldo1 numeric;
  v_motivo text;v_rejected boolean;v_before jsonb;v_after jsonb;v_principal boolean;v_e record;
begin
  select jsonb_build_object(
    'productos',(select count(*) from public.productos),
    'stock',(select coalesce(sum(stock_actual),0) from public.productos),
    'ledger',(select count(*) from stock_internal.movimientos),
    'lotes',(select count(*) from public.producto_lotes),
    'transferencias',(select count(*) from stock_internal.transferencias),
    'recetas_legacy',(select count(*) from public.recetas),
    'items_legacy',(select count(*) from public.receta_items),
    'fudo_productos',(select count(*) from public.fudo_productos),
    'fudo_movimientos',(select count(*) from public.fudo_movimientos)
  ) into v_before;

  select max(asignacion_id::text) filter(where n=1)::uuid,max(asignacion_id::text) filter(where n=2)::uuid,
    max(producto_id) filter(where n=1),max(producto_id) filter(where n=2),
    max(ubicacion_id::text) filter(where n=1)::uuid,max(ubicacion_id::text) filter(where n=2)::uuid
    into v_asig1,v_asig2,v_prod1,v_prod2,v_ubi1,v_ubi2
  from (
    select pa.id asignacion_id,pa.producto_id,u.id ubicacion_id,
      row_number() over(order by pa.id) n
    from public.producto_area_asignacion pa
    join public.productos p on p.id=pa.producto_id and p.sede='plaza' and p.activo='SÍ'
    join public.producto_enlace e on e.producto_sede_id=p.id and e.sede='plaza'
    join public.productos m on m.id=e.producto_bodega_id and m.sede='central' and m.activo='SÍ'
    join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza' and a.estado='activa'
    join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza' and u.activa
    left join public.area_secciones s on s.id=pa.seccion_id
    where pa.sede='plaza' and pa.estado='asignado' and pa.archivado_at is null
      and (pa.seccion_id is null or s.estado='activa')
    order by pa.id limit 2
  ) s;
  if v_asig1 is null or v_asig2 is null then raise exception 'P4 necesita dos insumos configurados.'; end if;

  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_root,'role','authenticated')::text,true);
  v_res:=public.panel_venta_guardar(gen_random_uuid(),null,null,jsonb_build_object(
    'nombre','P4 Simple '||gen_random_uuid(),'precio_venta',2000,'estado','listo',
    'componentes',jsonb_build_array(jsonb_build_object('asignacion_id',v_asig1,'cantidad',1))));
  v_pv_simple:=(v_res->>'producto_venta_id')::uuid;
  v_res:=public.panel_venta_guardar(gen_random_uuid(),null,null,jsonb_build_object(
    'nombre','P4 Combo '||gen_random_uuid(),'precio_venta',4500,'estado','listo',
    'componentes',jsonb_build_array(
      jsonb_build_object('asignacion_id',v_asig1,'cantidad',1),
      jsonb_build_object('asignacion_id',v_asig2,'cantidad',0.5))));
  v_pv_combo:=(v_res->>'producto_venta_id')::uuid;

  -- Stock sintético auditable, únicamente dentro de esta transacción revertida.
  insert into stock_internal.movimientos(producto_id,sede,ubicacion_id,lote_id,cantidad,tipo,actor,referencia,clave_idempotencia,metadata)
  values
    (v_prod1,'plaza',v_ubi1,null,30,'entrada','prueba:p4','Prueba P4','prueba:p4:stock:1:'||gen_random_uuid(),'{"prueba":"p4"}'),
    (v_prod2,'plaza',v_ubi2,null,30,'entrada','prueba:p4','Prueba P4','prueba:p4:stock:2:'||gen_random_uuid(),'{"prueba":"p4"}');

  insert into public.mesas(sede,salon,numero,orden,activa)
    values('plaza','P4 transaccional',990001,990001,true) returning id into v_mesa;
  insert into public.cuentas(sede,mesa_id,abierta_por) values('plaza',v_mesa,'prueba:p4') returning id into v_cuenta;

  select id into v_item from public.cuenta_producto_venta_agregar(v_cuenta,v_pv_simple,2,null,'prueba:p4');
  select id into v_item_combo from public.cuenta_producto_venta_agregar(v_cuenta,v_pv_combo,2,null,'prueba:p4');
  select count(*) into v_ledger from stock_internal.movimientos;
  select id into v_comanda from public.cuenta_confirmar(v_cuenta,'prueba:p4');
  if (select count(*) from stock_internal.movimientos)<>v_ledger then
    raise exception 'Confirmar consumió stock en vez de reservar.';
  end if;
  if (select count(*) from stock_internal.lama_receta_reservas where cuenta_id=v_cuenta)<>3
     or (select sum(cantidad) from stock_internal.lama_receta_reservas where cuenta_item_id=v_item)<>2
     or (select sum(cantidad) from stock_internal.lama_receta_reservas where cuenta_item_id=v_item_combo)<>3 then
    raise exception 'La receta simple/combo no reservó sus componentes exactos.';
  end if;
  if (select id from public.cuenta_confirmar(v_cuenta,'prueba:p4'))<>v_comanda
     or (select count(*) from stock_internal.lama_receta_reservas where cuenta_id=v_cuenta)<>3 then
    raise exception 'Doble confirmación duplicó comanda o reservas.';
  end if;

  select coalesce(sum(cantidad),0) into v_saldo1 from stock_internal.existencias
    where producto_id=v_prod1 and ubicacion_id=v_ubi1;
  perform public.cuenta_cerrar(v_cuenta,'prueba:p4');
  if (select count(*) from stock_internal.lama_receta_reservas where cuenta_id=v_cuenta and estado='consumida')<>3
     or (select coalesce(sum(cantidad),0) from stock_internal.existencias where producto_id=v_prod1 and ubicacion_id=v_ubi1)<>v_saldo1-4 then
    raise exception 'Cerrar no consumió exactamente una vez el snapshot reservado.';
  end if;
  perform public.cuenta_cerrar(v_cuenta,'prueba:p4');
  if (select coalesce(sum(cantidad),0) from stock_internal.existencias where producto_id=v_prod1 and ubicacion_id=v_ubi1)<>v_saldo1-4 then
    raise exception 'Doble cierre descontó dos veces.';
  end if;

  -- Anular después del consumo compensa todos los componentes una sola vez.
  select codigo into v_motivo from public.lama_motivos_anulacion where activo order by codigo limit 1;
  perform public.item_anular(v_item_combo,v_motivo,'prueba P4','prueba:p4');
  if (select count(*) from stock_internal.lama_receta_reservas where cuenta_item_id=v_item_combo and estado='liberada')<>2
     or (select coalesce(sum(cantidad),0) from stock_internal.existencias where producto_id=v_prod1 and ubicacion_id=v_ubi1)<>v_saldo1-2 then
    raise exception 'La anulación posterior no compensó el combo.';
  end if;
  perform public.item_anular(v_item_combo,v_motivo,'prueba P4','prueba:p4');
  if (select coalesce(sum(cantidad),0) from stock_internal.existencias where producto_id=v_prod1 and ubicacion_id=v_ubi1)<>v_saldo1-2 then
    raise exception 'Doble anulación duplicó la reversa.';
  end if;

  -- Anulación antes del cierre libera sin movimiento.
  insert into public.cuentas(sede,mesa_id,abierta_por) values('plaza',v_mesa,'prueba:p4') returning id into v_cuenta;
  select id into v_item from public.cuenta_producto_venta_agregar(v_cuenta,v_pv_simple,1,null,'prueba:p4');
  perform public.cuenta_confirmar(v_cuenta,'prueba:p4');
  select count(*) into v_ledger from stock_internal.movimientos;
  perform public.item_anular(v_item,v_motivo,'prueba P4','prueba:p4');
  if (select count(*) from stock_internal.movimientos)<>v_ledger
     or not exists(select 1 from stock_internal.lama_receta_reservas where cuenta_item_id=v_item and estado='liberada') then
    raise exception 'Anular antes del cierre movió stock o no liberó.';
  end if;
  perform public.cuenta_cerrar(v_cuenta,'prueba:p4');

  -- Insuficiencia en un componente revierte comanda y todas las reservas.
  insert into public.cuentas(sede,mesa_id,abierta_por) values('plaza',v_mesa,'prueba:p4') returning id into v_cuenta;
  perform public.cuenta_producto_venta_agregar(v_cuenta,v_pv_combo,100000,null,'prueba:p4');
  v_rejected:=false;
  begin perform public.cuenta_confirmar(v_cuenta,'prueba:p4');
  exception when check_violation then v_rejected:=true; end;
  if not v_rejected or exists(select 1 from stock_internal.lama_receta_reservas where cuenta_id=v_cuenta)
     or exists(select 1 from public.comandas where cuenta_id=v_cuenta) then
    raise exception 'Saldo insuficiente dejó una reserva/comanda parcial.';
  end if;
  delete from public.cuentas where id=v_cuenta;

  -- Origen archivado entre alta y confirmación: rechazo completo, sin inferencia.
  insert into public.cuentas(sede,mesa_id,abierta_por) values('plaza',v_mesa,'prueba:p4') returning id into v_cuenta;
  perform public.cuenta_producto_venta_agregar(v_cuenta,v_pv_simple,1,null,'prueba:p4');
  select es_principal into v_principal from public.producto_area_asignacion where id=v_asig1;
  update public.producto_area_asignacion set estado='archivada',es_principal=false,
    archivado_at=now(),archivado_por=v_root where id=v_asig1;
  v_rejected:=false;
  begin perform public.cuenta_confirmar(v_cuenta,'prueba:p4');
  exception when check_violation then v_rejected:=true; end;
  if not v_rejected or exists(select 1 from stock_internal.lama_receta_reservas where cuenta_id=v_cuenta) then
    raise exception 'Origen inactivo fue inferido o reservado.';
  end if;
  update public.producto_area_asignacion set estado='asignado',es_principal=v_principal,
    archivado_at=null,archivado_por=null where id=v_asig1;
  delete from public.cuentas where id=v_cuenta;

  -- Una falla física inesperada no revierte el cierre comercial: queda alerta auditable.
  insert into public.cuentas(sede,mesa_id,abierta_por) values('plaza',v_mesa,'prueba:p4') returning id into v_cuenta;
  perform public.cuenta_producto_venta_agregar(v_cuenta,v_pv_simple,1,null,'prueba:p4');
  perform public.cuenta_confirmar(v_cuenta,'prueba:p4');
  for v_e in select lote_id,cantidad from stock_internal.existencias
    where producto_id=v_prod1 and ubicacion_id=v_ubi1 and cantidad>0
  loop
    insert into stock_internal.movimientos(
      producto_id,sede,ubicacion_id,lote_id,cantidad,tipo,actor,referencia,clave_idempotencia,metadata
    ) values(
      v_prod1,'plaza',v_ubi1,v_e.lote_id,-v_e.cantidad,'salida','prueba:p4',
      'Simulación falla técnica P4','prueba:p4:agotamiento:'||gen_random_uuid(),'{"prueba":"p4_falla_cierre"}'
    );
  end loop;
  perform public.cuenta_cerrar(v_cuenta,'prueba:p4');
  if (select estado from public.cuentas where id=v_cuenta)<>'cerrada'
     or not exists(select 1 from stock_internal.lama_receta_reservas
       where cuenta_id=v_cuenta and estado='error')
     or not exists(select 1 from stock_internal.lama_alertas
       where cuenta_id=v_cuenta and clave_idempotencia='lama:cierre:error:'||v_cuenta) then
    raise exception 'La falla técnica bloqueó el cierre o no dejó alerta auditable.';
  end if;

  -- Usuario Lama operativo (habilitado solo dentro del rollback) sí; sin permiso y anon no.
  update public.app_permisos set puede_lama=true where auth_uid=v_oper;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_oper,'role','authenticated')::text,true);
  perform public.lama_productos_venta_listar();
  insert into public.cuentas(sede,mesa_id,abierta_por) values('plaza',v_mesa,'prueba:p4') returning id into v_cuenta;
  perform public.cuenta_producto_venta_agregar(v_cuenta,v_pv_simple,1,null,'operativo:p4');
  perform set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'role','authenticated')::text,true);
  v_rejected:=false;
  begin perform public.lama_productos_venta_listar();
  exception when insufficient_privilege then v_rejected:=true; end;
  if not v_rejected then raise exception 'Usuario sin Lama leyó el catálogo de Mesas.'; end if;
  perform set_config('request.jwt.claims','{"role":"anon"}',true);
  v_rejected:=false;
  begin perform public.lama_productos_venta_listar();
  exception when sqlstate '28000' then v_rejected:=true; end;
  if not v_rejected or has_function_privilege('anon','public.cuenta_producto_venta_agregar(bigint,uuid,numeric,text,text)','EXECUTE') then
    raise exception 'Anon accedió a P4.';
  end if;
  if has_table_privilege('authenticated','stock_internal.lama_receta_reservas','INSERT')
     or has_table_privilege('service_role','stock_internal.lama_receta_reservas','INSERT') then
    raise exception 'P4 expuso DML directo de reservas.';
  end if;
  if (select origen from stock_internal.origen_pos where sede='plaza')<>'ninguno' then
    raise exception 'P4 cambió origen_pos.';
  end if;

  select jsonb_build_object(
    'productos',(select count(*) from public.productos),
    'stock',(select coalesce(sum(stock_actual),0) from public.productos),
    'ledger',(select count(*) from stock_internal.movimientos),
    'lotes',(select count(*) from public.producto_lotes),
    'transferencias',(select count(*) from stock_internal.transferencias),
    'recetas_legacy',(select count(*) from public.recetas),
    'items_legacy',(select count(*) from public.receta_items),
    'fudo_productos',(select count(*) from public.fudo_productos),
    'fudo_movimientos',(select count(*) from public.fudo_movimientos)
  ) into v_after;
  -- Solo las operaciones sintéticas P4 explican la variación dentro de esta transacción.
  if (v_after->>'productos')<>(v_before->>'productos')
     or (v_after->>'lotes')<>(v_before->>'lotes')
     or (v_after->>'transferencias')<>(v_before->>'transferencias')
     or (v_after->>'recetas_legacy')<>(v_before->>'recetas_legacy')
     or (v_after->>'items_legacy')<>(v_before->>'items_legacy')
     or (v_after->>'fudo_productos')<>(v_before->>'fudo_productos')
     or (v_after->>'fudo_movimientos')<>(v_before->>'fudo_movimientos') then
    raise exception 'P4 alteró productos, lotes, transferencias, recetas o Fudo heredados.';
  end if;
end
$test$;

select 'P4: recetas manuales, multiárea, reservas, consumo, reversa, atomicidad y permisos OK' resultado;
rollback;
