begin;

do $test$
declare
  v_root constant uuid:='decc9a8d-0ab6-4306-bab5-a62bcaa40338'::uuid;
  v_operativo constant uuid:='6c3f6e47-7a26-40ce-84f6-9fe26925d642'::uuid;
  v_claims jsonb:=jsonb_build_object('sub',v_root,'role','authenticated','email','root-test@invalid.local');
  v_asignacion uuid; v_producto bigint; v_area uuid; v_ubicacion uuid; v_nombre text;
  v_fudo text:='fase4-directo-'||gen_random_uuid()::text;
  v_fudo_sin text:='fase4-sin-fuente-'||gen_random_uuid()::text;
  v_mesa bigint; v_cuenta bigint; v_item bigint; v_comanda public.comandas;
  v_cuenta2 bigint; v_item2 bigint; v_cuenta3 bigint; v_item3 bigint;
  v_cuenta4 bigint; v_item4 bigint; v_bad bigint; v_movs integer; v_rejected boolean;
  v_disp numeric; v_before jsonb; v_after jsonb;
begin
  perform set_config('request.jwt.claims',v_claims::text,true);
  select pa.id,pa.producto_id,pa.area_id,u.id,p.producto
    into v_asignacion,v_producto,v_area,v_ubicacion,v_nombre
    from public.producto_area_asignacion pa
    join public.productos p on p.id=pa.producto_id and p.sede='plaza'
    join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza' and a.estado='activa'
    join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza' and u.activa
    where pa.sede='plaza' and pa.estado='asignado' and pa.archivado_at is null and pa.es_principal
      and not exists(select 1 from public.producto_lotes l where l.producto_id=p.id)
      and not exists(select 1 from stock_internal.movimientos m where m.producto_id=p.id and m.lote_id is not null)
    order by pa.producto_id limit 1;
  if v_asignacion is null then raise exception 'TEST BLOCKED: falta un producto principal sin lote.'; end if;

  select jsonb_build_object(
    'fudo_movs',(select count(*) from public.fudo_movimientos),
    'lama_legacy',(select count(*) from public.lama_stock_eventos),
    'recetas',(select count(*) from public.recetas),
    'repartos',(select count(*) from stock_internal.repartos_area),
    'transferencias',(select count(*) from stock_internal.transferencias),
    'caja',(select count(*) from public.lama_caja_movimientos),
    'pagos',(select count(*) from public.cuenta_pagos)
  ) into v_before;

  insert into public.fudo_productos(sede,fudo_product_id,nombre,precio,activo)
    values('plaza',v_fudo,v_nombre||' F4',1000,true),
          ('plaza',v_fudo_sin,'Sin fuente F4',1000,true);
  perform public.lama_fuente_directa_guardar(v_fudo,v_asignacion);
  perform public.stock_ajuste_guardar(gen_random_uuid(),v_producto,v_ubicacion,
    jsonb_build_object('sin_lote',10),'Prueba transaccional Fase 4');

  -- Confirmación con saldo: reserva, no descuenta. Un segundo llamado devuelve
  -- la misma comanda y la disponibilidad ya considera esta mesa.
  insert into public.mesas(sede,numero,orden) values('plaza',990001,990001) returning id into v_mesa;
  insert into public.cuentas(sede,mesa_id,abierta_por) values('plaza',v_mesa,'fase4-test') returning id into v_cuenta;
  insert into public.cuenta_items(cuenta_id,fudo_product_id,nombre,cantidad,precio,estado)
    values(v_cuenta,v_fudo,v_nombre||' F4',3,1000,'nuevo') returning id into v_item;
  v_comanda:=public.cuenta_confirmar(v_cuenta,'fase4-test');
  if (select count(*) from stock_internal.lama_reservas where cuenta_item_id=v_item and estado='reservada')<>1
     or coalesce((select sum(cantidad) from stock_internal.existencias where producto_id=v_producto and ubicacion_id=v_ubicacion),0)<>10 then
    raise exception 'Falla: confirmar no creó exactamente una reserva o movió stock.';
  end if;
  if (public.cuenta_confirmar(v_cuenta,'fase4-test')).id<>v_comanda.id
     or (select count(*) from stock_internal.lama_reservas where cuenta_item_id=v_item)<>1 then
    raise exception 'Falla: doble confirmación no fue idempotente.';
  end if;
  select disponible into v_disp from public.lama_fuentes_directas_listar() where fudo_product_id=v_fudo;
  if v_disp<>7 then raise exception 'Falla: disponibilidad esperada 7, obtenida %.',v_disp; end if;

  -- Otra mesa ve la reserva activa y no puede tomar ocho. La línea queda nueva.
  insert into public.mesas(sede,numero,orden) values('plaza',990002,990002) returning id into v_mesa;
  insert into public.cuentas(sede,mesa_id,abierta_por) values('plaza',v_mesa,'fase4-test') returning id into v_cuenta2;
  insert into public.cuenta_items(cuenta_id,fudo_product_id,nombre,cantidad,precio,estado)
    values(v_cuenta2,v_fudo,v_nombre||' F4',8,1000,'nuevo') returning id into v_item2;
  v_rejected:=false;
  begin perform public.cuenta_confirmar(v_cuenta2,'fase4-test');
  exception when check_violation then v_rejected:=true; end;
  if not v_rejected or exists(select 1 from stock_internal.lama_reservas where cuenta_item_id=v_item2)
     or (select estado from public.cuenta_items where id=v_item2)<>'nuevo' then
    raise exception 'Falla: saldo insuficiente no rechazó toda la confirmación.';
  end if;

  -- Multilínea atómica: una línea sin fuente revierte también la reservable.
  update public.cuenta_items set cantidad=1 where id=v_item2;
  insert into public.cuenta_items(cuenta_id,fudo_product_id,nombre,cantidad,precio,estado)
    values(v_cuenta2,v_fudo_sin,'Sin fuente F4',1,1000,'nuevo') returning id into v_bad;
  v_rejected:=false;
  begin perform public.cuenta_confirmar(v_cuenta2,'fase4-test');
  exception when check_violation then v_rejected:=true; end;
  if not v_rejected or exists(select 1 from stock_internal.lama_reservas where cuenta_item_id in(v_item2,v_bad))
     or exists(select 1 from public.comandas where cuenta_id=v_cuenta2) then
    raise exception 'Falla: la confirmación multilínea no fue atómica.';
  end if;
  delete from public.cuenta_items where id=v_bad;

  -- Cierre: consumo único del ledger. Anulación posterior crea reversa única.
  update public.cuentas set estado='cerrada',cerrada_at=now(),cerrada_por='fase4-test' where id=v_cuenta;
  if (select estado from stock_internal.lama_reservas where cuenta_item_id=v_item)<>'consumida'
     or coalesce((select sum(cantidad) from stock_internal.existencias where producto_id=v_producto and ubicacion_id=v_ubicacion),0)<>7 then
    raise exception 'Falla: el cierre no consumió exactamente la reserva.';
  end if;
  select count(*) into v_movs from stock_internal.lama_reserva_movimientos
    where reserva_id=(select id from stock_internal.lama_reservas where cuenta_item_id=v_item) and tipo='consumo';
  update public.cuentas set estado='cerrada' where id=v_cuenta;
  if (select count(*) from stock_internal.lama_reserva_movimientos
      where reserva_id=(select id from stock_internal.lama_reservas where cuenta_item_id=v_item) and tipo='consumo')<>v_movs then
    raise exception 'Falla: el cierre repetido duplicó movimientos.';
  end if;
  perform public.item_anular(v_item,'prueba',null,'fase4-test');
  perform public.item_anular(v_item,'prueba',null,'fase4-test');
  if (select estado from stock_internal.lama_reservas where cuenta_item_id=v_item)<>'liberada'
     or coalesce((select sum(cantidad) from stock_internal.existencias where producto_id=v_producto and ubicacion_id=v_ubicacion),0)<>10
     or (select count(*) from stock_internal.lama_reserva_movimientos
         where reserva_id=(select id from stock_internal.lama_reservas where cuenta_item_id=v_item) and tipo='reversa')<>v_movs then
    raise exception 'Falla: anulación/reintento no revirtió una sola vez.';
  end if;

  -- Anulación completa de comanda antes del cierre libera sin mover stock.
  delete from public.cuenta_items where id=v_item2;
  insert into public.cuenta_items(cuenta_id,fudo_product_id,nombre,cantidad,precio,estado)
    values(v_cuenta2,v_fudo,v_nombre||' F4',2,1000,'nuevo') returning id into v_item2;
  v_comanda:=public.cuenta_confirmar(v_cuenta2,'fase4-test');
  perform public.comanda_anular(v_comanda.id,'prueba',null,'fase4-test');
  perform public.comanda_anular(v_comanda.id,'prueba',null,'fase4-test');
  if (select estado from stock_internal.lama_reservas where cuenta_item_id=v_item2)<>'liberada'
     or coalesce((select sum(cantidad) from stock_internal.existencias where producto_id=v_producto and ubicacion_id=v_ubicacion),0)<>10 then
    raise exception 'Falla: anular la comanda no liberó de forma idempotente.';
  end if;

  -- Falla técnica inesperada: el conteo físico cae luego de reservar. La mesa
  -- cierra comercialmente, no hay negativo y queda alerta recuperable.
  insert into public.mesas(sede,numero,orden) values('plaza',990004,990004) returning id into v_mesa;
  insert into public.cuentas(sede,mesa_id,abierta_por) values('plaza',v_mesa,'fase4-test') returning id into v_cuenta4;
  insert into public.cuenta_items(cuenta_id,fudo_product_id,nombre,cantidad,precio,estado)
    values(v_cuenta4,v_fudo,v_nombre||' F4',1,1000,'nuevo') returning id into v_item4;
  perform public.cuenta_confirmar(v_cuenta4,'fase4-test');
  perform public.stock_ajuste_guardar(gen_random_uuid(),v_producto,v_ubicacion,
    jsonb_build_object('sin_lote',0),'Simulación técnica Fase 4');
  update public.cuentas set estado='cerrada',cerrada_at=now(),cerrada_por='fase4-test' where id=v_cuenta4;
  if (select estado from public.cuentas where id=v_cuenta4)<>'cerrada'
     or (select estado from stock_internal.lama_reservas where cuenta_item_id=v_item4)<>'error'
     or not exists(select 1 from stock_internal.lama_alertas where cuenta_id=v_cuenta4 and estado='pendiente')
     or exists(select 1 from stock_internal.existencias where cantidad<0) then
    raise exception 'Falla: el cierre tolerante no cerró, no alertó o dejó saldo negativo.';
  end if;

  -- Permisos reales: la cuenta operativa sin Lama y una sesión anónima no
  -- pueden consultar ni confirmar; el propietario sí ejerció todo el flujo.
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_operativo,'role','authenticated')::text,true);
  v_rejected:=false;
  begin perform public.lama_fuentes_directas_listar();
  exception when insufficient_privilege then v_rejected:=true; end;
  if not v_rejected then raise exception 'Falla: usuario sin puede_lama leyó disponibilidad.'; end if;
  perform set_config('request.jwt.claims','{}',true);
  v_rejected:=false;
  begin perform public.lama_fuentes_directas_listar();
  exception when invalid_authorization_specification then v_rejected:=true; end;
  if not v_rejected then raise exception 'Falla: anónimo leyó disponibilidad.'; end if;
  perform set_config('request.jwt.claims',v_claims::text,true);

  select jsonb_build_object(
    'fudo_movs',(select count(*) from public.fudo_movimientos),
    'lama_legacy',(select count(*) from public.lama_stock_eventos),
    'recetas',(select count(*) from public.recetas),
    'repartos',(select count(*) from stock_internal.repartos_area),
    'transferencias',(select count(*) from stock_internal.transferencias),
    'caja',(select count(*) from public.lama_caja_movimientos),
    'pagos',(select count(*) from public.cuenta_pagos)
  ) into v_after;
  if v_after is distinct from v_before then
    raise exception 'Falla: Fase 4 cambió Fudo, Lama legacy, recetas, repartos, caja o pagos.';
  end if;
  raise notice 'Fase 4 correcta: fuente explícita, disponibilidad, atomicidad, consumo, liberación y cierre tolerante.';
end
$test$;

select 'Fase 4 SQL transaccional correcta; rollback a continuación.' resultado;
rollback;
