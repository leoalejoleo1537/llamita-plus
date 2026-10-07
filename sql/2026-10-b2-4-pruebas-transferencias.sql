-- B2.4: pruebas contra datos actuales dentro de una sola transacción revertida.
-- Proyecto autorizado: Llamita Plus iuryhsjucblmebdogewa.
-- No se llama a Fudo ni se habilita Lama. No usar en otra base.
begin;

create function pg_temp.b2_4_forzar_fallo_entrada()
returns trigger language plpgsql
as $function$
begin
  if new.tipo='transferencia' and new.cantidad>0
     and current_setting('b2_4.forzar_fallo_entrada',true)='on' then
    raise exception 'B2.4 prueba: fallo forzado entre salida y entrada.';
  end if;
  return new;
end
$function$;
create trigger b2_4_test_forzar_fallo_entrada
before insert on stock_internal.movimientos
for each row execute function pg_temp.b2_4_forzar_fallo_entrada();

do $test$
declare
  v_email text;
  v_uid uuid := gen_random_uuid();
  v_bodega uuid;
  v_sin_asignar uuid;
  v_barra uuid;
  v_cafeteria uuid;
  v_prod_central bigint;
  v_prod_plaza bigint;
  v_prod_sin_lote bigint;
  v_prod_local bigint;
  v_prod_otro_local bigint;
  v_lote bigint;
  v_motivo text := 'Prueba transaccional B2.4';
  v_tx_central uuid := gen_random_uuid();
  v_tx_sin_asignar uuid := gen_random_uuid();
  v_tx_area uuid := gen_random_uuid();
  v_tx_lote uuid := gen_random_uuid();
  v_tx_error uuid := gen_random_uuid();
  v_total_antes numeric;
  v_total_despues numeric;
  v_stock_antes numeric;
  v_stock_despues numeric;
  v_source_before numeric;
  v_fudo_before bigint;
  v_lotes_before bigint;
  v_products_before bigint;
  v_rechazado boolean;
  v_pairs integer;
begin
  select lower(a.correo) into v_email from public.app_permisos a
   where a.puede_editar is true order by a.correo limit 1;
  if v_email is null then raise exception 'Falta un usuario de prueba con permiso puede_editar.'; end if;
  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',v_uid::text,'role','authenticated','email',v_email)::text,true);
  perform set_config('request.jwt.claim.sub',v_uid::text,true);
  perform set_config('request.jwt.claim.role','authenticated',true);

  select id into v_bodega from stock_internal.ubicaciones where sede='central' and codigo='bodega_central' and activa;
  select id into v_sin_asignar from stock_internal.ubicaciones where sede='plaza' and codigo='sin_asignar' and activa;
  select id into v_barra from stock_internal.ubicaciones where sede='plaza' and codigo='barra' and activa;
  select id into v_cafeteria from stock_internal.ubicaciones where sede='plaza' and codigo='cafeteria' and activa;
  if v_bodega is null or v_sin_asignar is null or v_barra is null or v_cafeteria is null then
    raise exception 'Faltan ubicaciones B2.4 esperadas.';
  end if;

  -- Enlace real uno a uno con saldo Bodega y sin lotes legados.
  select e.producto_bodega_id,e.producto_sede_id into v_prod_central,v_prod_plaza
    from public.producto_enlace e
    join stock_internal.existencias x on x.producto_id=e.producto_bodega_id
      and x.ubicacion_id=v_bodega and x.lote_id is null and x.cantidad>=20
    where e.sede='plaza' and e.factor=1
      and not exists(select 1 from public.producto_lotes l where l.producto_id=e.producto_bodega_id and l.cantidad>0)
    order by x.cantidad desc,e.id limit 1;
  if v_prod_central is null then raise exception 'No hay enlace real Bodega/Local 1 sin lotes y con saldo para la prueba.'; end if;

  -- Producto de Local 1 con saldo sin lote para las dos transferencias internas.
  select x.producto_id into v_prod_sin_lote
    from stock_internal.existencias x
    join public.productos p on p.id=x.producto_id and p.sede='plaza'
    join stock_internal.ubicaciones u on u.id=x.ubicacion_id and u.codigo='sin_asignar'
    where x.cantidad>=2 and x.lote_id is null
      and not exists(select 1 from public.producto_lotes l where l.producto_id=x.producto_id and l.cantidad>0)
    order by x.cantidad desc,x.producto_id limit 1;
  if v_prod_sin_lote is null then raise exception 'No hay producto de Local 1 sin lote para prueba interna.'; end if;

  -- Enlace real con lote de Bodega; la fecha del lote se usa como canon.
  select e.producto_bodega_id,e.producto_sede_id,l.id into v_prod_local,v_prod_otro_local,v_lote
    from public.producto_enlace e
    join public.producto_lotes l on l.producto_id=e.producto_bodega_id and l.cantidad>0
    join stock_internal.existencias x on x.producto_id=e.producto_bodega_id
      and x.ubicacion_id=v_bodega and x.lote_id=l.id and x.cantidad>=l.cantidad
    where e.sede='plaza' and e.factor=1
    order by e.id,l.id limit 1;
  if v_prod_local is null or v_lote is null then raise exception 'No hay lote real enlazado a Local 1 para la prueba.'; end if;

  select coalesce(sum(cantidad),0) into v_total_antes from stock_internal.movimientos;
  select coalesce(sum(stock_actual::numeric),0) into v_stock_antes from public.productos;
  select count(*) into v_fudo_before from public.fudo_movimientos;
  select count(*) into v_lotes_before from public.producto_lotes;
  select count(*) into v_products_before from public.productos;

  -- Bodega central → Cafetería, producto con enlace explícito.
  perform public.stock_transferir(v_tx_central,v_prod_central,v_prod_plaza,v_bodega,v_cafeteria,12,
    v_motivo,null);
  -- Reintento idéntico: devuelve la referencia sin volver a descontar.
  perform public.stock_transferir(v_tx_central,v_prod_central,v_prod_plaza,v_bodega,v_cafeteria,12,
    v_motivo,null);

  -- Sin asignar → Barra y luego Barra → Cafetería, mismo producto de Local 1.
  perform public.stock_transferir(v_tx_sin_asignar,v_prod_sin_lote,v_prod_sin_lote,v_sin_asignar,v_barra,1,
    v_motivo,null);
  perform public.stock_transferir(v_tx_area,v_prod_sin_lote,v_prod_sin_lote,v_barra,v_cafeteria,1,
    v_motivo,null);

  -- Lote Bodega: clasifica el saldo ya abierto desde el bucket sin lote sin
  -- cambiar total, luego crea la continuidad al producto enlazado de Local 1.
  perform public.stock_transferir(v_tx_lote,v_prod_local,v_prod_otro_local,v_bodega,v_cafeteria,1,
    v_motivo,v_lote);
  if not exists(select 1 from stock_internal.lote_continuidad c
     where c.lote_canonico_id=v_lote and c.producto_id=v_prod_otro_local
       and c.sede='plaza' and c.vencimiento is not distinct from
         (select l.vencimiento from public.producto_lotes l where l.id=v_lote)) then
    raise exception 'No quedó continuidad del mismo lote con su vencimiento al producto enlazado.';
  end if;

  -- Saldo insuficiente y par de productos sin enlace se rechazan íntegros.
  v_rechazado := false;
  begin
    perform public.stock_transferir(gen_random_uuid(),v_prod_central,v_prod_plaza,v_bodega,v_cafeteria,999999,
      v_motivo,null);
  exception when others then v_rechazado := true;
  end;
  if not v_rechazado then raise exception 'No se rechazó el saldo insuficiente.'; end if;

  select p.id into v_prod_otro_local from public.productos p
   where p.sede='plaza' and not exists(select 1 from public.producto_enlace e
      where e.sede='plaza' and e.producto_bodega_id=v_prod_central and e.producto_sede_id=p.id)
   order by p.id limit 1;
  if v_prod_otro_local is null then raise exception 'No hay producto Local 1 no enlazado para probar el rechazo.'; end if;
  v_rechazado := false;
  begin
    perform public.stock_transferir(gen_random_uuid(),v_prod_central,v_prod_otro_local,v_bodega,v_cafeteria,1,
      v_motivo,null);
  exception when others then v_rechazado := true;
  end;
  if not v_rechazado then raise exception 'Se aceptó una transferencia sin enlace.'; end if;

  -- Fallo forzado después de insertar la salida, antes de la entrada.
  select coalesce(sum(m.cantidad),0) into v_source_before from stock_internal.movimientos m
   where m.producto_id=v_prod_central and m.ubicacion_id=v_bodega and m.lote_id is null;
  perform set_config('b2_4.forzar_fallo_entrada','on',true);
  v_rechazado := false;
  begin
    perform public.stock_transferir(v_tx_error,v_prod_central,v_prod_plaza,v_bodega,v_cafeteria,1,
      v_motivo,null);
  exception when others then v_rechazado := true;
  end;
  perform set_config('b2_4.forzar_fallo_entrada','off',true);
  if not v_rechazado then raise exception 'No se activó el fallo forzado entre salida y entrada.'; end if;
  if exists(select 1 from stock_internal.transferencias where id=v_tx_error)
     or exists(select 1 from stock_internal.movimientos where transferencia_id=v_tx_error) then
    raise exception 'El fallo dejó una transferencia o movimiento parcial.';
  end if;
  if (select coalesce(sum(m.cantidad),0) from stock_internal.movimientos m
       where m.producto_id=v_prod_central and m.ubicacion_id=v_bodega and m.lote_id is null)<>v_source_before then
    raise exception 'El fallo cambió el saldo de origen.';
  end if;

  -- Sin permiso real, el RPC rechaza aunque se tenga una sesión autenticada.
  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',gen_random_uuid()::text,'role','authenticated','email','b2.4-sin-permiso@invalid.example')::text,true);
  perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  v_rechazado := false;
  begin
    perform public.stock_transferir(gen_random_uuid(),v_prod_central,v_prod_plaza,v_bodega,v_cafeteria,1,
      v_motivo,null);
  exception when others then v_rechazado := true;
  end;
  if not v_rechazado then raise exception 'El RPC permitió transferir sin puede_editar.'; end if;

  select coalesce(sum(cantidad),0) into v_total_despues from stock_internal.movimientos;
  select coalesce(sum(stock_actual::numeric),0) into v_stock_despues from public.productos;
  if v_total_despues<>v_total_antes then
    raise exception 'El total del libro cambió durante transferencias balanceadas.';
  end if;
  if exists(select 1 from stock_internal.existencias x where x.cantidad<0) then
    raise exception 'La prueba dejó saldo negativo.';
  end if;
  if v_stock_despues<>v_stock_antes then
    raise exception 'La proyección global stock_actual cambió en forma neta.';
  end if;
  if exists(select 1 from public.productos p where p.sede in ('central','plaza')
     and p.stock_actual::numeric<>(select coalesce(sum(m.cantidad),0) from stock_internal.movimientos m where m.producto_id=p.id)) then
    raise exception 'stock_actual no coincide con la proyección del libro.';
  end if;
  if (select count(*) from public.fudo_movimientos)<>v_fudo_before
     or (select count(*) from public.producto_lotes)<>v_lotes_before
     or (select count(*) from public.productos)<>v_products_before
     or exists(select 1 from public.lama_stock_config where lower(modo)='real') then
    raise exception 'La prueba tocó Fudo, lotes/productos o activó Lama real.';
  end if;
  if has_function_privilege('anon','stock_internal.transferir(uuid,bigint,bigint,uuid,uuid,numeric,bigint,text,text)','EXECUTE')
     or has_function_privilege('service_role','stock_internal.transferir(uuid,bigint,bigint,uuid,uuid,numeric,bigint,text,text)','EXECUTE')
     or not has_function_privilege('authenticated','stock_internal.transferir(uuid,bigint,bigint,uuid,uuid,numeric,bigint,text,text)','EXECUTE')
     or has_function_privilege('anon','public.stock_transferir(uuid,bigint,bigint,uuid,uuid,numeric,text,bigint)','EXECUTE')
     or has_function_privilege('service_role','public.stock_transferir(uuid,bigint,bigint,uuid,uuid,numeric,text,bigint)','EXECUTE')
     or not has_function_privilege('authenticated','public.stock_transferir(uuid,bigint,bigint,uuid,uuid,numeric,text,bigint)','EXECUTE')
     or has_table_privilege('authenticated','stock_internal.movimientos','INSERT')
     or has_table_privilege('service_role','stock_internal.movimientos','INSERT')
     or has_table_privilege('anon','stock_internal.transferencias','INSERT')
     or not has_schema_privilege('authenticated','stock_internal','USAGE')
     or has_schema_privilege('service_role','stock_internal','USAGE')
     or (select p.prosecdef from pg_proc p where p.oid='public.stock_transferir(uuid,bigint,bigint,uuid,uuid,numeric,text,bigint)'::regprocedure) then
    raise exception 'La ACL del motor o de las tablas internas no es segura.';
  end if;

  select count(*) into v_pairs from stock_internal.transferencias t
   where t.id in (v_tx_central,v_tx_sin_asignar,v_tx_area,v_tx_lote);
  if v_pairs<>4 then raise exception 'No se crearon las cuatro referencias esperadas dentro de la transacción.'; end if;
end
$test$;

-- Repite una transferencia con SET ROLE authenticated para ejercitar el mismo
-- camino de permisos que usa el cliente HTTP, sin usar service_role.
do $auth_context$
declare
  v_email text;
  v_uid uuid := gen_random_uuid();
  v_source bigint;
  v_dest bigint;
  v_origin uuid;
  v_target uuid;
begin
  select lower(correo) into v_email from public.app_permisos
   where puede_editar is true order by correo limit 1;
  select e.producto_bodega_id,e.producto_sede_id into v_source,v_dest
    from public.producto_enlace e
    join stock_internal.existencias x on x.producto_id=e.producto_bodega_id
      and x.ubicacion_id=(select id from stock_internal.ubicaciones where sede='central' and codigo='bodega_central')
      and x.lote_id is null and x.cantidad>=1
    where e.sede='plaza' and e.factor=1
      and not exists(select 1 from public.producto_lotes l where l.producto_id=e.producto_bodega_id and l.cantidad>0)
    order by e.id limit 1;
  select id into v_origin from stock_internal.ubicaciones where sede='central' and codigo='bodega_central';
  select id into v_target from stock_internal.ubicaciones where sede='plaza' and codigo='cafeteria';
  if v_email is null or v_source is null or v_dest is null or v_origin is null or v_target is null then
    raise exception 'No se pudo preparar la prueba como authenticated.';
  end if;
  perform set_config('b2_4.rpc_id',gen_random_uuid()::text,true);
  perform set_config('b2_4.rpc_source',v_source::text,true);
  perform set_config('b2_4.rpc_dest',v_dest::text,true);
  perform set_config('b2_4.rpc_origin',v_origin::text,true);
  perform set_config('b2_4.rpc_target',v_target::text,true);
  perform set_config('request.jwt.claim.sub',v_uid::text,true);
  perform set_config('request.jwt.claim.role','authenticated',true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_uid::text,'role','authenticated','email',v_email)::text,true);
end
$auth_context$;
set local role authenticated;
select public.stock_transferir(
  current_setting('b2_4.rpc_id')::uuid,
  current_setting('b2_4.rpc_source')::bigint,
  current_setting('b2_4.rpc_dest')::bigint,
  current_setting('b2_4.rpc_origin')::uuid,
  current_setting('b2_4.rpc_target')::uuid,
  1,'Prueba de rol authenticated',null
);
reset role;

set constraints all immediate;
rollback;

select (select count(*) from public.productos) productos,
       (select coalesce(sum(stock_actual::numeric),0) from public.productos) stock_actual_total,
       (select count(*) from public.producto_lotes) lotes,
       (select coalesce(sum(cantidad),0) from stock_internal.movimientos) ledger_net,
       (select count(*) from stock_internal.transferencias) transferencias_persistentes,
       (select count(*) from stock_internal.lote_continuidad) continuidad_lotes_persistente,
       (select count(*) from stock_internal.movimientos where tipo='clasificacion_lote') clasificaciones_persistentes,
       (select count(*) from stock_internal.movimientos where transferencia_id is not null) movimientos_transferencia_persistentes,
       (select count(*) from public.fudo_movimientos) fudo_movimientos,
       (select count(*) from public.movimientos) movimientos_legacy,
       (select count(*) from public.lama_stock_config where lower(modo)='real') lama_real;
