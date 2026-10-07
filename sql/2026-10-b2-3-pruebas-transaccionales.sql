-- Dónde se ejecuta: solo Supabase Llamita Plus (iuryhsjucblmebdogewa), después
-- de aplicar 20261007145034_b2_3_libro_existencias_corte.
-- Ejecución: copiar el bloque completo en SQL Editor. Todo termina en ROLLBACK.
-- Qué prueba: conciliación, permisos, escritores legacy, modos Fudo/Lama,
-- idempotencia y transferencia Bodega -> Cafetería con el mismo producto lógico
-- (enlace de catálogo 1:1), lote y referencia. No deja cambios persistentes.
-- Resultado esperado: todos los ASSERT/controles pasan y las cantidades finales
-- de productos, lotes, movimientos/repartos, recetas y permisos quedan iguales.

begin;
do $tests$
declare
  v_id bigint; v_id2 bigint; v_lote bigint; v_qty numeric;
  v_site_stock numeric; v_ledger numeric; v_lotes bigint;
  v_transfer uuid:=gen_random_uuid(); v_loc_bodega uuid; v_loc_cafeteria uuid;
  v_pair record; v_blocked boolean; v_fecha date;
  v_before_products bigint; v_before_legacy_moves bigint; v_before_repartos bigint;
  v_before_recipes bigint; v_before_recipe_items bigint; v_before_perms bigint;
  v_before_lot_count bigint; v_before_lot_qty numeric;
  v_before_central_stock numeric; v_before_plaza_stock numeric; v_before_global_stock numeric;
begin
  select count(*),coalesce(sum(stock_actual),0) into v_before_products,v_site_stock from public.productos;
  v_before_global_stock:=v_site_stock;
  select coalesce(sum(stock_actual),0) into v_before_central_stock from public.productos where sede='central';
  select coalesce(sum(stock_actual),0) into v_before_plaza_stock from public.productos where sede='plaza';
  select count(*),coalesce(sum(cantidad),0) into v_before_lot_count,v_before_lot_qty from public.producto_lotes;
  select count(*) into v_before_legacy_moves from public.movimientos;
  select count(*) into v_before_repartos from public.repartos;
  select count(*) into v_before_recipes from public.recetas;
  select count(*) into v_before_recipe_items from public.receta_items;
  select count(*) into v_before_perms from public.app_permisos;

  if (select count(*) from stock_internal.ubicaciones where sede='plaza' and codigo in ('cocina_fria','cocina_caliente','barra','cafeteria'))<>4 then
    raise exception 'FALLO: faltan áreas de Local 1.';
  end if;
  if exists(select 1 from stock_internal.movimientos where sede='central' and ubicacion_id<>(select id from stock_internal.ubicaciones where sede='central' and codigo='bodega_central')) then
    raise exception 'FALLO: saldo de central fue abierto fuera de Bodega central.';
  end if;
  if exists(select 1 from stock_internal.movimientos where sede='plaza' and ubicacion_id<>(select id from stock_internal.ubicaciones where sede='plaza' and codigo='sin_asignar')) then
    raise exception 'FALLO: saldo de Local 1 fue abierto fuera de Sin asignar.';
  end if;
  if exists(select 1 from public.productos p where p.sede in ('central','plaza') and abs(coalesce(p.stock_actual,0)-(select coalesce(sum(m.cantidad),0) from stock_internal.movimientos m where m.producto_id=p.id))>0.000001) then
    raise exception 'FALLO: conciliación por producto.';
  end if;
  select coalesce(sum(stock_actual),0) into v_site_stock from public.productos where sede in ('central','plaza');
  select coalesce(sum(cantidad),0) into v_ledger from stock_internal.movimientos;
  if abs(v_site_stock-v_ledger)>0.000001 then raise exception 'FALLO: conciliación global central/plaza.'; end if;
  if exists(select 1 from public.productos p where p.sede in ('central','plaza')
    and (select coalesce(sum(l.cantidad),0) from public.producto_lotes l where l.producto_id=p.id)>coalesce(p.stock_actual,0)+0.000001) then
    raise exception 'FALLO: lotes superan el total maestro.';
  end if;
  if exists(select 1 from stock_internal.movimientos where tipo='apertura_migracion' and cantidad>0 and lote_id is not null
    group by producto_id,lote_id having count(*)>1) then raise exception 'FALLO: lote duplicado en apertura.'; end if;

  -- El mismo producto lógico permanece en dos ubicaciones y sedes como dos
  -- productos maestros enlazados, sin combinar sus saldos ni IDs.
  if not exists(select 1 from public.productos p join public.producto_enlace e
    on (e.producto_bodega_id=p.id or e.producto_sede_id=p.id)
    where p.sede in ('central','plaza') and lower(p.producto) like '%leche%') then
    raise exception 'FALLO: falta ejemplo de leche enlazada en dos sedes.';
  end if;
  if not exists(select 1 from public.productos pb join public.producto_enlace e on e.producto_bodega_id=pb.id
      join public.productos ps on ps.id=e.producto_sede_id
      join stock_internal.existencias eb on eb.producto_id=pb.id and eb.sede='central'
      join stock_internal.existencias ep on ep.producto_id=ps.id and ep.sede='plaza'
      where lower(pb.producto) like '%leche%' and e.sede='plaza'
        and eb.ubicacion_id=(select id from stock_internal.ubicaciones where sede='central' and codigo='bodega_central')
        and ep.ubicacion_id=(select id from stock_internal.ubicaciones where sede='plaza' and codigo='sin_asignar')) then
    raise exception 'FALLO: los saldos de leche no quedaron como filas independientes Bodega/Sin asignar.';
  end if;

  -- La migración es idempotente por su clave de apertura: una repetición no
  -- debe añadir movimientos ni volver a proyectar un saldo.
  if (select count(*) from stock_internal.aperturas where clave='b2_3_apertura_2026_10')<>1 then
    raise exception 'FALLO: no hay una única apertura idempotente.';
  end if;

  -- Direct UPDATE al saldo antiguo bloqueado.
  select id into v_id from public.productos where sede='plaza' and coalesce(stock_actual,0)>0 order by id limit 1;
  v_blocked:=false;
  begin
    update public.productos set stock_actual=stock_actual+1 where id=v_id;
    raise exception 'TEST_FALLO: UPDATE directo fue permitido.';
  exception when others then
    if sqlerrm like 'Stock por ubicación:%' then v_blocked:=true;
    elsif sqlerrm like 'TEST_FALLO:%' then raise;
    else raise; end if;
  end;
  if not v_blocked then raise exception 'FALLO: no se bloqueó stock_actual.'; end if;

  -- El escritor legacy de mermas revierte la operación completa.
  select p.id into v_id from public.productos p where p.sede='plaza' and p.stock_actual>=1
    and not exists(select 1 from public.producto_lotes l where l.producto_id=p.id) order by p.id limit 1;
  v_blocked:=false;
  begin
    perform public.mermar(v_id,1,null,'daño',null,'prueba B2.3');
    raise exception 'TEST_FALLO: mermar legacy fue permitido.';
  exception when others then
    if sqlerrm like 'Stock por ubicación:%' then v_blocked:=true;
    elsif sqlerrm like 'TEST_FALLO:%' then raise;
    else raise; end if;
  end;
  if not v_blocked then raise exception 'FALLO: escritor de merma no bloqueado.'; end if;

  -- Entrada y restauración ejecutan sus rutas instaladas y se revierten al
  -- llegar a sus guardas. Esto evita validar solo un UPDATE sintético.
  select id into v_id from public.productos p where p.sede='central'
    and not exists(select 1 from public.producto_lotes l where l.producto_id=p.id) order by p.id limit 1;
  v_blocked:=false;
  begin
    perform public.registrar_entrada(jsonb_build_array(jsonb_build_object('producto_id',v_id,'cantidad',1)),'prueba B2.3',null,'prueba B2.3');
    raise exception 'TEST_FALLO: registrar_entrada legacy fue permitido.';
  exception when others then
    if sqlerrm like 'Stock por ubicación:%' then v_blocked:=true;
    elsif sqlerrm like 'TEST_FALLO:%' then raise;
    else raise; end if;
  end;
  if not v_blocked then raise exception 'FALLO: escritor de entradas no bloqueado.'; end if;

  select max(fecha) into v_fecha from public.historial where sede='plaza';
  v_blocked:=false;
  begin
    perform public.restaurar_sede('plaza',v_fecha,'prueba B2.3');
    raise exception 'TEST_FALLO: restaurar_sede legacy fue permitido.';
  exception when others then
    if sqlerrm like 'Stock por ubicación:%' then v_blocked:=true;
    elsif sqlerrm like 'TEST_FALLO:%' then raise;
    else raise; end if;
  end;
  if not v_blocked then raise exception 'FALLO: escritor de restauración no bloqueado.'; end if;

  select min(id),max(id) into v_id,v_id2 from public.productos where sede='plaza';
  v_blocked:=false;
  begin
    perform public.fusionar_productos(v_id,v_id2,'prueba B2.3');
    raise exception 'TEST_FALLO: fusionar_productos legacy fue permitido.';
  exception when others then
    if sqlerrm like 'Stock por ubicación:%' then v_blocked:=true;
    elsif sqlerrm like 'TEST_FALLO:%' then raise;
    else raise; end if;
  end;
  if not v_blocked then raise exception 'FALLO: escritor de fusiones no bloqueado.'; end if;

  -- Lotes, movimientos y repartos legacy no admiten escrituras en el corte.
  select id into v_id from public.productos where sede='plaza' order by id limit 1;
  v_blocked:=false;
  begin
    insert into public.producto_lotes(producto_id,cantidad,vencimiento) values(v_id,0.5,current_date+30);
    raise exception 'TEST_FALLO: lote legacy fue permitido.';
  exception when others then
    if sqlerrm like 'Stock por ubicación:%' then v_blocked:=true;
    elsif sqlerrm like 'TEST_FALLO:%' then raise;
    else raise; end if;
  end;
  if not v_blocked then raise exception 'FALLO: escritor de lotes no bloqueado.'; end if;

  v_blocked:=false;
  begin
    insert into public.movimientos(sede,producto_id,producto,tipo,cantidad)
      select sede,id,producto,'ajuste',1 from public.productos where sede='plaza' order by id limit 1;
    raise exception 'TEST_FALLO: movimiento legacy fue permitido.';
  exception when others then
    if sqlerrm like 'Stock por ubicación:%' then v_blocked:=true;
    elsif sqlerrm like 'TEST_FALLO:%' then raise;
    else raise; end if;
  end;
  if not v_blocked then raise exception 'FALLO: escritor de movimientos no bloqueado.'; end if;

  v_blocked:=false;
  begin
    insert into public.repartos(sede,origen,estado,creado_por,nombre)
      values('plaza','Bodega','pendiente','prueba B2.3','prueba rollback');
    raise exception 'TEST_FALLO: reparto legacy fue permitido.';
  exception when others then
    if sqlerrm like 'Stock por ubicación:%' then v_blocked:=true;
    elsif sqlerrm like 'TEST_FALLO:%' then raise;
    else raise; end if;
  end;
  if not v_blocked then raise exception 'FALLO: escritor de repartos no bloqueado.'; end if;

  -- No existe modo real ni endpoint de escritura remota habilitado por DB.
  v_blocked:=false;
  begin
    insert into public.fudo_sync(sede,modo) values('plaza','real')
    on conflict(sede) do update set modo='real';
    raise exception 'TEST_FALLO: Fudo real fue permitido.';
  exception when others then
    if sqlerrm like 'Stock por ubicación:%' then v_blocked:=true;
    elsif sqlerrm like 'TEST_FALLO:%' then raise;
    else raise; end if;
  end;
  if not v_blocked then raise exception 'FALLO: modo real Fudo no bloqueado.'; end if;
  v_blocked:=false;
  begin
    insert into public.lama_stock_config(sede,modo) values('plaza','real');
    raise exception 'TEST_FALLO: Lama real fue permitido.';
  exception when others then
    if sqlerrm like 'Stock por ubicación:%' then v_blocked:=true;
    elsif sqlerrm like 'TEST_FALLO:%' then raise;
    else raise; end if;
  end;
  if not v_blocked then raise exception 'FALLO: modo real Lama no bloqueado.'; end if;

  v_blocked:=false;
  begin
    insert into public.fudo_movimientos(sede,fudo_sale_id,fudo_item_id,fudo_product_id,
      fudo_product_nombre,cantidad_vendida,producto_id,producto_nombre,descuento,aplicado,venta_at)
    select 'plaza','B2-3-TEST','B2-3-TEST','B2-3-TEST',producto,1,id,producto,1,true,now()
      from public.productos where sede='plaza' order by id limit 1;
    raise exception 'TEST_FALLO: Fudo aplicó stock legacy.';
  exception when others then
    if sqlerrm like 'Stock por ubicación:%' then v_blocked:=true;
    elsif sqlerrm like 'TEST_FALLO:%' then raise;
    else raise; end if;
  end;
  if not v_blocked then raise exception 'FALLO: aplicación real de Fudo no bloqueada.'; end if;
  if exists(select 1 from public.fudo_sync where sede in ('central','plaza') and lower(modo)='real') then
    raise exception 'FALLO: Fudo quedó en modo real.';
  end if;

  -- Simulación atómica/idempotente: Bodega -12 y Cafetería +12, misma partida,
  -- mismo vínculo de SKU y mismo UUID. La segunda llamada no duplica filas.
  select e.producto_bodega_id,e.producto_sede_id,l.id as lote_id
    into v_pair from public.producto_enlace e
    join public.productos pb on pb.id=e.producto_bodega_id
    join public.productos ps on ps.id=e.producto_sede_id
    join public.producto_lotes l on l.producto_id=e.producto_bodega_id
    where e.sede='plaza' and e.factor=1 and pb.sede='central' and ps.sede='plaza'
      and lower(pb.producto) like '%dona%oreo%' and l.cantidad>=12
    order by l.id limit 1;
  if v_pair.producto_bodega_id is null then raise exception 'FALLO: no se encontró SKU/lote sintético para probar transferencia.'; end if;
  select id into v_loc_bodega from stock_internal.ubicaciones where sede='central' and codigo='bodega_central';
  select id into v_loc_cafeteria from stock_internal.ubicaciones where sede='plaza' and codigo='cafeteria';
  select coalesce(sum(cantidad),0) into v_site_stock from stock_internal.movimientos
    where producto_id in (v_pair.producto_bodega_id,v_pair.producto_sede_id);
  perform stock_internal.transferir(v_transfer,v_pair.producto_bodega_id,v_pair.producto_sede_id,
      v_loc_bodega,v_loc_cafeteria,12,v_pair.lote_id);
  perform stock_internal.transferir(v_transfer,v_pair.producto_bodega_id,v_pair.producto_sede_id,
      v_loc_bodega,v_loc_cafeteria,12,v_pair.lote_id);
  if (select count(*) from stock_internal.movimientos where transferencia_id=v_transfer)<>2 then
    raise exception 'FALLO: transferencia duplicada o no atómica.';
  end if;
  if (select count(*) from stock_internal.movimientos where transferencia_id=v_transfer and lote_id=v_pair.lote_id)<>2 then
    raise exception 'FALLO: la transferencia no conservó el lote.';
  end if;
  if (select count(distinct referencia) from stock_internal.movimientos where transferencia_id=v_transfer)<>1 then
    raise exception 'FALLO: falta referencia común.';
  end if;
  if (select coalesce(sum(cantidad),0) from stock_internal.movimientos where producto_id in (v_pair.producto_bodega_id,v_pair.producto_sede_id))<>v_site_stock then
    raise exception 'FALLO: el total lógico del producto varió.';
  end if;
  if abs((select coalesce(sum(stock_actual),0) from public.productos)-v_before_global_stock)>0.000001
     or abs((select coalesce(sum(stock_actual),0) from public.productos where sede='central')-(v_before_central_stock-12))>0.000001
     or abs((select coalesce(sum(stock_actual),0) from public.productos where sede='plaza')-(v_before_plaza_stock+12))>0.000001 then
    raise exception 'FALLO: variación esperada por ubicación/global incorrecta en la transferencia.';
  end if;
  if not exists(select 1 from public.productos where id=v_pair.producto_bodega_id and stock_actual=84)
     or not exists(select 1 from public.productos where id=v_pair.producto_sede_id and stock_actual=12) then
    -- La proyección de Local 1 parte de su saldo previo, no se asume cero.
    if not exists(select 1 from public.productos where id=v_pair.producto_bodega_id and stock_actual=84) then
      raise exception 'FALLO: proyección de Bodega no refleja -12.';
    end if;
    if not exists(select 1 from public.productos where id=v_pair.producto_sede_id and stock_actual=(select coalesce(sum(m.cantidad),0) from stock_internal.movimientos m where m.producto_id=v_pair.producto_sede_id)) then
      raise exception 'FALLO: proyección de Local 1 no coincide con libro.';
    end if;
  end if;

  if has_table_privilege('anon','stock_internal.movimientos','SELECT')
     or has_table_privilege('authenticated','stock_internal.movimientos','INSERT')
     or has_table_privilege('service_role','stock_internal.movimientos','UPDATE') then
    raise exception 'FALLO: grants directos abiertos sobre el libro.';
  end if;
  if has_table_privilege('anon','public.productos','TRUNCATE')
     or has_table_privilege('authenticated','public.producto_lotes','TRUNCATE')
     or has_table_privilege('service_role','public.productos','TRUNCATE') then
    raise exception 'FALLO: TRUNCATE sigue otorgado.';
  end if;
  if has_function_privilege('anon','stock_internal.transferir(uuid,bigint,bigint,uuid,uuid,numeric,bigint)','EXECUTE')
     or has_function_privilege('authenticated','stock_internal.transferir(uuid,bigint,bigint,uuid,uuid,numeric,bigint)','EXECUTE')
     or has_function_privilege('service_role','stock_internal.transferir(uuid,bigint,bigint,uuid,uuid,numeric,bigint)','EXECUTE') then
    raise exception 'FALLO: EXECUTE público/service_role del helper interno.';
  end if;
  if (select count(*) from public.lama_stock_config)<>0 then raise exception 'FALLO: apareció configuración persistente Lama.'; end if;

  -- Estado íntegro dentro de la prueba antes del ROLLBACK exterior.
  if (select count(*) from public.productos)<>v_before_products
     or (select count(*) from public.movimientos)<>v_before_legacy_moves
     or (select count(*) from public.repartos)<>v_before_repartos
     or (select count(*) from public.recetas)<>v_before_recipes
     or (select count(*) from public.receta_items)<>v_before_recipe_items
     or (select count(*) from public.app_permisos)<>v_before_perms
     or (select count(*) from public.producto_lotes)<>v_before_lot_count
     or (select coalesce(sum(cantidad),0) from public.producto_lotes)<>v_before_lot_qty then
    raise exception 'FALLO: cambió un conteo comercial durante la prueba.';
  end if;
  raise notice 'B2.3 PASS: conciliación, guardas, permisos, transferencia y reintento idempotente; transaction se revierte completa.';
end $tests$;
rollback;
