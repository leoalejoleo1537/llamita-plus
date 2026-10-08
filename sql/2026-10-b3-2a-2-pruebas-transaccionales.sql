-- B3.2a.2: prueba dinámica completa. Toda escritura sintética se revierte.
begin;

do $test$
declare
  v_raiz constant uuid:='decc9a8d-0ab6-4306-bab5-a62bcaa40338'::uuid;
  v_operador constant uuid:='6c3f6e47-7a26-40ce-84f6-9fe26925d642'::uuid;
  v_area uuid;
  v_producto bigint;
  v_resultado jsonb;
  v_stock numeric;
  v_productos bigint;
  v_lotes bigint;
  v_mov_legacy bigint;
  v_mov_ledger bigint;
  v_recetas bigint;
  v_fudo bigint;
  v_lama bigint;
begin
  select count(*) into v_productos from public.productos;
  select coalesce(sum(cantidad),0) into v_stock from stock_internal.existencias;
  select count(*) into v_lotes from public.producto_lotes;
  select count(*) into v_mov_legacy from public.movimientos;
  select count(*) into v_mov_ledger from stock_internal.movimientos;
  select count(*) into v_recetas from public.recetas;
  select count(*) into v_fudo from public.fudo_movimientos;
  select count(*) into v_lama from public.lama_stock_eventos;

  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',v_raiz,'role','authenticated','email',(select email from auth.users where id=v_raiz))::text,true);
  execute 'set local role authenticated';

  v_area:=public.area_operativa_crear('Heladería B3.2a.2',90,null,'plaza');
  if not exists(select 1 from public.stock_leer_areas() where area_codigo='heladeria_b3_2a_2' and cantidad=0) then
    raise exception 'Falla: el lector dinámico no mostró Heladería con saldo cero.';
  end if;
  perform public.area_operativa_editar(v_area,'Heladería fría B3.2a.2',91);
  if not exists(select 1 from public.stock_leer_areas() where area_nombre='Heladería fría B3.2a.2') then
    raise exception 'Falla: el lector dinámico no reflejó el nombre editado.';
  end if;

  v_resultado:=public.producto_plaza_crear(
    'Producto interfaz B3.2a.2','Pruebas',0,0,false,null,null,v_area,null,'plaza');
  v_producto:=(v_resultado->>'producto_id')::bigint;
  v_resultado:=public.producto_area_preferencia_leer(v_producto,'plaza');
  if (v_resultado->>'area_id')::uuid<>v_area
     or jsonb_array_length(v_resultado->'ubicaciones')<>0 then
    raise exception 'Falla: preferencia o ubicación física inicial incorrecta.';
  end if;
  execute 'reset role';
  if exists(select 1 from public.producto_lotes where producto_id=v_producto)
     or exists(select 1 from public.movimientos where producto_id=v_producto)
     or exists(select 1 from stock_internal.movimientos where producto_id=v_producto)
     or exists(select 1 from stock_internal.existencias where producto_id=v_producto) then
    raise exception 'Falla: el alta visual creó lotes, movimientos o existencias.';
  end if;

  execute 'set local role authenticated';
  perform public.producto_area_preferencia_guardar(v_producto,null,'plaza');
  v_resultado:=public.producto_area_preferencia_leer(v_producto,'plaza');
  if v_resultado->>'estado'<>'sin_asignar' or v_resultado->>'area_id' is not null then
    raise exception 'Falla: el cambio de preferencia a Sin asignar no se reflejó.';
  end if;
  perform public.area_operativa_archivar(v_area,false);
  if exists(select 1 from public.stock_leer_areas() where area_codigo='heladeria_b3_2a_2') then
    raise exception 'Falla: el área archivada sigue en navegación operativa.';
  end if;

  execute 'reset role';
  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',v_operador,'role','authenticated','email',(select email from auth.users where id=v_operador))::text,true);
  execute 'set local role authenticated';
  perform count(*) from public.areas_operativas_listar('plaza',true);
  perform public.producto_area_preferencia_leer(v_producto,'plaza');
  execute 'reset role';

  execute 'set local role anon';
  begin
    perform public.producto_area_preferencia_leer(v_producto,'plaza');
    raise exception 'Falla: anon pudo leer la preferencia protegida.';
  exception when insufficient_privilege then null;
  end;
  execute 'reset role';

  if (select coalesce(sum(cantidad),0) from stock_internal.existencias)<>v_stock
     or (select count(*) from public.producto_lotes)<>v_lotes
     or (select count(*) from public.movimientos)<>v_mov_legacy
     or (select count(*) from stock_internal.movimientos)<>v_mov_ledger
     or (select count(*) from public.recetas)<>v_recetas
     or (select count(*) from public.fudo_movimientos)<>v_fudo
     or (select count(*) from public.lama_stock_eventos)<>v_lama then
    raise exception 'Falla: B3.2a.2 alteró stock, lotes, movimientos, recetas, Fudo o Lama.';
  end if;
  if (select count(*) from public.productos)<>v_productos+1 then
    raise exception 'Falla: la transacción sintética no contiene exactamente su producto temporal.';
  end if;
end
$test$;

rollback;
