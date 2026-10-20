begin;

do $test$
declare
  v_root constant uuid:='decc9a8d-0ab6-4306-bab5-a62bcaa40338'::uuid;
  v_claims jsonb:=jsonb_build_object('sub',v_root,'role','authenticated','email','root-test@invalid.local');
  v_area1 uuid; v_area2 uuid; v_dest1 uuid;
  v_origen uuid; v_bodega bigint; v_plaza bigint; v_bodega2 bigint; v_plaza2 bigint; v_bodega3 bigint; v_plaza3 bigint;
  v_lote_bodega bigint; v_lote_plaza bigint; v_lote bigint; v_venc date;
  v_rep uuid; v_rec uuid; v_item uuid; v_result jsonb; v_repeat jsonb;
  v_before_src numeric; v_before_dst numeric; v_after_src numeric; v_after_dst numeric; v_available numeric; v_amount numeric;
  v_counts jsonb; v_counts_after jsonb; v_rejected boolean; v_rows jsonb; v_first record; v_second record;
begin
  if not exists(select 1 from auth.users where id=v_root and confirmed_at is not null) then
    raise exception 'TEST BLOCKED: propietario raíz no disponible.';
  end if;
  perform set_config('request.jwt.claims',v_claims::text,true);
  select u.id into v_origen from stock_internal.ubicaciones u
    where u.sede='central' and u.codigo='bodega_central' and u.activa;
  select a.id,u.id into v_area1,v_dest1 from public.areas_operativas a
    join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza' and u.activa
    where a.sede='plaza' and a.estado='activa' order by a.orden,a.id limit 1;
  select a.id into v_area2 from public.areas_operativas a
    join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza' and u.activa
    where a.sede='plaza' and a.estado='activa' and a.id<>v_area1 order by a.orden,a.id limit 1;
  if v_area1 is null or v_area2 is null then raise exception 'TEST BLOCKED: se requieren dos áreas activas.'; end if;

  select e.producto_bodega_id,e.producto_sede_id into v_bodega,v_plaza
  from public.producto_enlace e
  where e.sede='plaza' and e.factor=1
    and stock_internal.saldo_transferible_bodega(e.producto_bodega_id,v_origen,null)>3
    and not exists(select 1 from public.producto_lotes l where l.producto_id=e.producto_bodega_id)
    and not exists(select 1 from stock_internal.lote_continuidad c where c.producto_id=e.producto_bodega_id)
  order by e.producto_bodega_id limit 1;
  select e.producto_bodega_id,e.producto_sede_id into v_bodega2,v_plaza2
  from public.producto_enlace e where e.sede='plaza' and e.factor=1 and e.producto_bodega_id<>v_bodega
    and stock_internal.saldo_transferible_bodega(e.producto_bodega_id,v_origen,null)>1
    and not exists(select 1 from public.producto_lotes l where l.producto_id=e.producto_bodega_id)
  order by e.producto_bodega_id limit 1;
  select e.producto_bodega_id,e.producto_sede_id into v_bodega3,v_plaza3
  from public.producto_enlace e where e.sede='plaza' and e.factor=1 and e.producto_bodega_id not in (v_bodega,v_bodega2)
    and stock_internal.saldo_transferible_bodega(e.producto_bodega_id,v_origen,null)>1
    and not exists(select 1 from public.producto_lotes l where l.producto_id=e.producto_bodega_id)
  order by e.producto_bodega_id limit 1;
  if v_bodega is null or v_bodega2 is null or v_bodega3 is null then raise exception 'TEST BLOCKED: faltan tres enlaces sin lote con saldo.'; end if;

  select jsonb_build_object(
    'fudo',(select count(*) from public.fudo_movimientos),
    'lama',(select count(*) from public.lama_stock_eventos),
    'recetas',(select count(*) from public.recetas),
    'caja',(select count(*) from public.lama_caja_movimientos),
    'cuentas',(select count(*) from public.cuentas),'comandas',(select count(*) from public.comandas),
    'cuenta_items',(select count(*) from public.cuenta_items),'cuenta_pagos',(select count(*) from public.cuenta_pagos),
    'legacy_repartos',(select count(*) from public.repartos),
    'legacy_items',(select count(*) from public.reparto_items),
    'lotes',(select count(*) from public.producto_lotes)
  ) into v_counts;

  -- Preparar no mueve stock y la bandeja queda aislada por área.
  select coalesce(sum(m.cantidad),0) into v_before_src from stock_internal.movimientos m
    where m.producto_id=v_bodega and m.ubicacion_id=v_origen and m.lote_id is null;
  select coalesce(sum(m.cantidad),0) into v_before_dst from stock_internal.movimientos m
    where m.producto_id=v_plaza and m.ubicacion_id=v_dest1 and m.lote_id is null;
  v_rep:=gen_random_uuid();
  perform public.reparto_area_crear(v_rep,v_area1,'Exacto',jsonb_build_array(jsonb_build_object(
    'producto_bodega_id',v_bodega,'producto_plaza_id',v_plaza,'lote_id',null,'cantidad',1.25)));
  if (select coalesce(sum(m.cantidad),0) from stock_internal.movimientos m where m.producto_id=v_bodega and m.ubicacion_id=v_origen and m.lote_id is null)<>v_before_src
     or (select coalesce(sum(m.cantidad),0) from stock_internal.movimientos m where m.producto_id=v_plaza and m.ubicacion_id=v_dest1 and m.lote_id is null)<>v_before_dst then
    raise exception 'Falla: preparar movió stock.';
  end if;
  if jsonb_array_length(public.repartos_area_listar(v_area1,false))<>1
     or jsonb_array_length(public.repartos_area_listar(v_area2,false))<>0 then
    raise exception 'Falla: una bandeja vio repartos de otra área.';
  end if;
  select id into v_item from stock_internal.repartos_area_items where reparto_id=v_rep;
  v_rec:=gen_random_uuid();
  v_rows:=jsonb_build_array(jsonb_build_object('item_id',v_item,'cantidad_recibida',1.25));
  v_result:=public.reparto_area_recibir(v_rep,v_rec,v_rows,'Recepción exacta');
  v_repeat:=public.reparto_area_recibir(v_rep,v_rec,v_rows,'Recepción exacta');
  if v_repeat->>'repetido'<>'true' or (v_result->>'total_transferido')::numeric<>1.25
     or (v_result->>'total_ajustado')::numeric<>0 then raise exception 'Falla: recepción exacta o idempotencia.'; end if;
  select coalesce(sum(m.cantidad),0) into v_after_src from stock_internal.movimientos m where m.producto_id=v_bodega and m.ubicacion_id=v_origen and m.lote_id is null;
  select coalesce(sum(m.cantidad),0) into v_after_dst from stock_internal.movimientos m where m.producto_id=v_plaza and m.ubicacion_id=v_dest1 and m.lote_id is null;
  if v_after_src<>v_before_src-1.25 or v_after_dst<>v_before_dst+1.25 then raise exception 'Falla: saldos exactos incorrectos.'; end if;
  v_rejected:=false;
  begin perform public.reparto_area_recibir(v_rep,v_rec,jsonb_build_array(jsonb_build_object('item_id',v_item,'cantidad_recibida',1)),'Recepción exacta');
  exception when unique_violation then v_rejected:=true; end;
  if not v_rejected then raise exception 'Falla: una referencia repetida con otra carga fue aceptada.'; end if;

  -- Parcial: mueve solo lo recibido y cierra. Cero: cierra sin movimientos.
  v_rep:=gen_random_uuid();perform public.reparto_area_crear(v_rep,v_area1,'Parcial',jsonb_build_array(jsonb_build_object(
    'producto_bodega_id',v_bodega,'producto_plaza_id',v_plaza,'lote_id',null,'cantidad',2)));
  select id into v_item from stock_internal.repartos_area_items where reparto_id=v_rep;
  v_result:=public.reparto_area_recibir(v_rep,gen_random_uuid(),jsonb_build_array(jsonb_build_object('item_id',v_item,'cantidad_recibida',0.5)),'Recepción parcial');
  if (v_result->>'total_transferido')::numeric<>0.5 or (v_result->'lineas'->0->>'diferencia')::numeric<>-1.5 then raise exception 'Falla: recepción parcial.'; end if;
  v_rep:=gen_random_uuid();perform public.reparto_area_crear(v_rep,v_area1,'Cero',jsonb_build_array(jsonb_build_object(
    'producto_bodega_id',v_bodega,'producto_plaza_id',v_plaza,'lote_id',null,'cantidad',1)));
  select id into v_item from stock_internal.repartos_area_items where reparto_id=v_rep;
  v_result:=public.reparto_area_recibir(v_rep,gen_random_uuid(),jsonb_build_array(jsonb_build_object('item_id',v_item,'cantidad_recibida',0)),'No llegó');
  if (v_result->>'total_transferido')::numeric<>0 or (v_result->>'total_ajustado')::numeric<>0 then raise exception 'Falla: recepción cero movió stock.'; end if;

  -- Excedente: agota Bodega, completa el físico con ajuste auditado y cierra.
  v_available:=stock_internal.saldo_transferible_bodega(v_bodega,v_origen,null);
  v_rep:=gen_random_uuid();perform public.reparto_area_crear(v_rep,v_area1,'Excedente',jsonb_build_array(jsonb_build_object(
    'producto_bodega_id',v_bodega,'producto_plaza_id',v_plaza,'lote_id',null,'cantidad',1)));
  select id into v_item from stock_internal.repartos_area_items where reparto_id=v_rep;
  v_result:=public.reparto_area_recibir(v_rep,gen_random_uuid(),jsonb_build_array(jsonb_build_object('item_id',v_item,'cantidad_recibida',v_available+0.75)),'Excedente físico');
  if stock_internal.saldo_transferible_bodega(v_bodega,v_origen,null)<>0
     or (v_result->>'total_transferido')::numeric<>v_available
     or (v_result->>'total_ajustado')::numeric<>0.75
     or not exists(select 1 from stock_internal.repartos_area_items i join stock_internal.ajustes_manuales a on a.referencia=i.ajuste_referencia where i.id=v_item) then
    raise exception 'Falla: excedente no dejó Bodega en cero o no vinculó el ajuste.';
  end if;

  -- Lote conocido conserva identidad/vencimiento; el bucket sin lote queda separado.
  select e.producto_bodega_id,e.producto_sede_id,l.id,l.vencimiento
    into v_lote_bodega,v_lote_plaza,v_lote,v_venc
  from public.producto_enlace e join public.producto_lotes l on l.producto_id=e.producto_bodega_id
  where e.sede='plaza' and e.factor=1 and stock_internal.saldo_transferible_bodega(e.producto_bodega_id,v_origen,l.id)>0
  order by e.producto_bodega_id,l.id limit 1;
  if v_lote is null then raise exception 'TEST BLOCKED: falta enlace con lote transferible.'; end if;
  v_amount:=least(0.25,stock_internal.saldo_transferible_bodega(v_lote_bodega,v_origen,v_lote));
  v_rep:=gen_random_uuid();perform public.reparto_area_crear(v_rep,v_area1,'Lote',jsonb_build_array(jsonb_build_object(
    'producto_bodega_id',v_lote_bodega,'producto_plaza_id',v_lote_plaza,'lote_id',v_lote,'cantidad',v_amount)));
  select id into v_item from stock_internal.repartos_area_items where reparto_id=v_rep;
  v_result:=public.reparto_area_recibir(v_rep,gen_random_uuid(),jsonb_build_array(jsonb_build_object('item_id',v_item,'cantidad_recibida',v_amount)),'Lote conocido');
  if not exists(select 1 from stock_internal.movimientos m where m.transferencia_id=(select i.transferencia_id from stock_internal.repartos_area_items i where i.id=v_item) and m.producto_id=v_lote_plaza and m.lote_id=v_lote and m.cantidad=v_amount)
     or not exists(select 1 from stock_internal.lote_continuidad c where c.lote_canonico_id=v_lote and c.producto_id=v_lote_plaza and c.vencimiento is not distinct from v_venc) then
    raise exception 'Falla: lote o vencimiento no conservaron continuidad.';
  end if;
  v_rep:=gen_random_uuid();perform public.reparto_area_crear(v_rep,v_area1,'Sin lote',jsonb_build_array(jsonb_build_object(
    'producto_bodega_id',v_lote_bodega,'producto_plaza_id',v_lote_plaza,'lote_id',null,'cantidad',0.5)));
  select id into v_item from stock_internal.repartos_area_items where reparto_id=v_rep;
  v_result:=public.reparto_area_recibir(v_rep,gen_random_uuid(),jsonb_build_array(jsonb_build_object('item_id',v_item,'cantidad_recibida',0.5)),'Sin lote informado');
  if not exists(select 1 from stock_internal.movimientos m join stock_internal.repartos_area_items i on i.ajuste_referencia=m.ajuste_manual_id
      where i.id=v_item and m.producto_id=v_lote_plaza and m.lote_id is null and m.cantidad>0) then
    raise exception 'Falla: el saldo sin lote no quedó separado.';
  end if;

  -- Error tras una primera línea válida: toda la recepción vuelve atrás.
  v_rep:=gen_random_uuid();perform public.reparto_area_crear(v_rep,v_area1,'Atómico',jsonb_build_array(
    jsonb_build_object('producto_bodega_id',v_bodega2,'producto_plaza_id',v_plaza2,'lote_id',null,'cantidad',0.1),
    jsonb_build_object('producto_bodega_id',v_bodega3,'producto_plaza_id',v_plaza3,'lote_id',null,'cantidad',0.1)));
  select * into v_first from stock_internal.repartos_area_items where reparto_id=v_rep order by id limit 1;
  select * into v_second from stock_internal.repartos_area_items where reparto_id=v_rep order by id offset 1 limit 1;
  delete from public.producto_enlace where sede='plaza' and producto_bodega_id=v_second.producto_bodega_id and producto_sede_id=v_second.producto_plaza_id;
  v_rows=(select jsonb_agg(jsonb_build_object('item_id',i.id,'cantidad_recibida',0.1) order by i.id) from stock_internal.repartos_area_items i where i.reparto_id=v_rep);
  v_rejected:=false;
  begin perform public.reparto_area_recibir(v_rep,gen_random_uuid(),v_rows,'Error intermedio');
  exception when others then v_rejected:=true; end;
  if not v_rejected or exists(select 1 from stock_internal.movimientos m where m.transferencia_id=v_first.transferencia_id)
     or exists(select 1 from stock_internal.ajustes_manuales a where a.referencia=v_first.ajuste_referencia_planeada)
     or (select estado from stock_internal.repartos_area where id=v_rep)<>'enviado' then
    raise exception 'Falla: el error intermedio dejó efectos parciales.';
  end if;

  -- Sesión sin permiso y anónima rechazadas.
  perform set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'role','authenticated','email','ordinary-test@invalid.local')::text,true);
  v_rejected:=false;
  begin perform public.reparto_area_crear(gen_random_uuid(),v_area1,null,jsonb_build_array(jsonb_build_object(
    'producto_bodega_id',v_bodega2,'producto_plaza_id',v_plaza2,'lote_id',null,'cantidad',1)));
  exception when insufficient_privilege then v_rejected:=true; end;
  if not v_rejected then raise exception 'Falla: usuario sin puede_editar creó un reparto.'; end if;
  perform set_config('request.jwt.claims','{}',true);
  v_rejected:=false;
  begin perform public.repartos_area_listar(v_area1,false);
  exception when insufficient_privilege then v_rejected:=true; end;
  if not v_rejected then raise exception 'Falla: sesión anónima leyó repartos.'; end if;
  perform set_config('request.jwt.claims',v_claims::text,true);

  if exists(select 1 from stock_internal.existencias e where e.cantidad<0) then raise exception 'Falla: quedó un saldo negativo.'; end if;
  select jsonb_build_object(
    'fudo',(select count(*) from public.fudo_movimientos),'lama',(select count(*) from public.lama_stock_eventos),
    'recetas',(select count(*) from public.recetas),'caja',(select count(*) from public.lama_caja_movimientos),
    'cuentas',(select count(*) from public.cuentas),'comandas',(select count(*) from public.comandas),
    'cuenta_items',(select count(*) from public.cuenta_items),'cuenta_pagos',(select count(*) from public.cuenta_pagos),
    'legacy_repartos',(select count(*) from public.repartos),
    'legacy_items',(select count(*) from public.reparto_items),'lotes',(select count(*) from public.producto_lotes)
  ) into v_counts_after;
  if v_counts_after is distinct from v_counts then raise exception 'Falla: cambió una tabla fuera del alcance de Fase 2.'; end if;
  raise notice 'Fase 2 SQL correcta: preparación, aislamiento, exacta, parcial, cero, excedente, lotes, idempotencia, atomicidad y permisos.';
end
$test$;

select 'Fase 2 SQL transaccional correcta; rollback a continuación.' resultado;
rollback;
