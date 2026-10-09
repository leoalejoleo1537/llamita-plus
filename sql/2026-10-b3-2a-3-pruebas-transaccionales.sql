-- B3.2a.3: áreas visibles y preferencia de productos existentes.
-- Toda escritura es sintética y termina en ROLLBACK.
begin;

do $test$
declare
  v_raiz constant uuid:='decc9a8d-0ab6-4306-bab5-a62bcaa40338'::uuid;
  v_operador constant uuid:='6c3f6e47-7a26-40ce-84f6-9fe26925d642'::uuid;
  v_comun constant uuid:='00000000-0000-4000-8000-000000000321'::uuid;
  v_heladeria uuid;
  v_area_prueba uuid;
  v_helado bigint;
  v_nuevo bigint;
  v_resultado jsonb;
  v_productos bigint; v_preferencias bigint; v_lotes bigint;
  v_mov_legacy bigint; v_mov_ledger bigint; v_transferencias bigint;
  v_recetas bigint; v_fudo bigint; v_lama bigint; v_enlaces bigint;
  v_stock_productos numeric; v_stock_ledger numeric;
begin
  select count(*),coalesce(sum(stock_actual),0) into v_productos,v_stock_productos from public.productos;
  select count(*) into v_preferencias from public.producto_area_asignacion;
  select count(*) into v_lotes from public.producto_lotes;
  select count(*) into v_mov_legacy from public.movimientos;
  select count(*),coalesce(sum(cantidad),0) into v_mov_ledger,v_stock_ledger from stock_internal.movimientos;
  select count(*) into v_transferencias from stock_internal.transferencias;
  select count(*) into v_recetas from public.recetas;
  select count(*) into v_fudo from public.fudo_movimientos;
  select count(*) into v_lama from public.lama_stock_eventos;
  select count(*) into v_enlaces from public.producto_enlace;

  select id into strict v_heladeria from public.areas_operativas
  where sede='plaza' and codigo='heladeria' and estado='activa';
  select id into strict v_helado from public.productos
  where sede='plaza' and producto='Helado de vainilla' and activo='SÍ';

  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',v_raiz,'role','authenticated','email',(select email from auth.users where id=v_raiz))::text,true);
  execute 'set local role authenticated';

  -- Área nueva + ubicación vinculada, sin saldo inventado.
  v_area_prueba:=public.area_operativa_crear('Área sintética B3.2a.3',903,null,'plaza');
  execute 'reset role';
  if not exists(select 1 from stock_internal.ubicaciones u
    where u.area_id=v_area_prueba and u.sede='plaza' and u.activa) then
    raise exception 'Falla: el área sintética no creó su ubicación vinculada.';
  end if;
  execute 'set local role authenticated';

  -- Usar una ficha existente cambia solo su preferencia.
  perform public.producto_area_preferencia_guardar(v_helado,v_heladeria,'plaza');
  v_resultado:=public.producto_area_preferencia_leer(v_helado,'plaza');
  if (v_resultado->>'area_id')::uuid<>v_heladeria then
    raise exception 'Falla: Helado de vainilla no quedó preferido en Heladería.';
  end if;

  -- Un alta verdaderamente nueva nace en cero y sin efectos contables.
  v_resultado:=public.producto_plaza_crear(
    'Producto sintético B3.2a.3','Pruebas',0,0,false,'Prueba',null,v_heladeria,null,'plaza');
  v_nuevo:=(v_resultado->>'producto_id')::bigint;
  execute 'reset role';
  if (v_resultado->>'stock_actual')::numeric<>0
     or exists(select 1 from public.producto_lotes where producto_id=v_nuevo)
     or exists(select 1 from public.movimientos where producto_id=v_nuevo)
     or exists(select 1 from stock_internal.movimientos where producto_id=v_nuevo)
     or exists(select 1 from stock_internal.existencias where producto_id=v_nuevo) then
    raise exception 'Falla: el alta nueva creó saldo, lote, movimiento o existencia.';
  end if;

  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',v_operador,'role','authenticated','email',(select email from auth.users where id=v_operador))::text,true);
  execute 'set local role authenticated';
  perform public.area_operativa_editar(v_area_prueba,'Área sintética B3.2a.3 editada',904);
  perform public.producto_area_preferencia_guardar(v_helado,v_area_prueba,'plaza');
  execute 'reset role';

  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_comun,'role','authenticated')::text,true);
  execute 'set local role authenticated';
  begin
    perform public.producto_area_preferencia_guardar(v_helado,v_heladeria,'plaza');
    raise exception 'Falla: un usuario común pudo asignar preferencias.';
  exception when insufficient_privilege then null;
  end;
  execute 'reset role';

  if (select coalesce(sum(stock_actual),0) from public.productos)<>v_stock_productos
     or (select coalesce(sum(cantidad),0) from stock_internal.movimientos)<>v_stock_ledger
     or (select count(*) from public.producto_lotes)<>v_lotes
     or (select count(*) from public.movimientos)<>v_mov_legacy
     or (select count(*) from stock_internal.movimientos)<>v_mov_ledger
     or (select count(*) from stock_internal.transferencias)<>v_transferencias
     or (select count(*) from public.recetas)<>v_recetas
     or (select count(*) from public.fudo_movimientos)<>v_fudo
     or (select count(*) from public.lama_stock_eventos)<>v_lama
     or (select count(*) from public.producto_enlace)<>v_enlaces then
    raise exception 'Falla: la preferencia alteró stock, lotes, movimientos, transferencias, recetas, Fudo, Lama o enlaces.';
  end if;
  if (select count(*) from public.productos)<>v_productos+1
     or (select count(*) from public.producto_area_asignacion)<>v_preferencias+2 then
    raise exception 'Falla: la transacción no contiene exactamente sus filas sintéticas esperadas.';
  end if;
  if to_regprocedure('public.stock_transferir(uuid,bigint,bigint,uuid,uuid,numeric,text,bigint)') is null then
    raise exception 'Falla: cambió o desapareció la firma de stock_transferir.';
  end if;
end
$test$;

rollback;
