begin;

do $test$
declare
  v_root constant uuid:='decc9a8d-0ab6-4306-bab5-a62bcaa40338'::uuid;
  v_operativo constant uuid:='6c3f6e47-7a26-40ce-84f6-9fe26925d642'::uuid;
  v_claims jsonb:=jsonb_build_object('sub',v_root,'role','authenticated','email','root-test@invalid.local');
  v_area1 uuid; v_area2 uuid; v_producto bigint; v_result jsonb; v_repeat jsonb;
  v_before jsonb; v_after jsonb; v_rows jsonb; v_rejected boolean;
begin
  perform set_config('request.jwt.claims',v_claims::text,true);
  select pa.area_id,pa.producto_id into v_area1,v_producto
    from public.producto_area_asignacion pa
    join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza' and a.estado='activa'
    where pa.sede='plaza' and pa.estado='asignado' and pa.archivado_at is null
    order by a.orden,pa.producto_id limit 1;
  select a.id into v_area2 from public.areas_operativas a
    where a.sede='plaza' and a.estado='activa' and a.id<>v_area1 order by a.orden,a.id limit 1;
  if v_area1 is null or v_area2 is null or v_producto is null then
    raise exception 'TEST BLOCKED: se requieren dos áreas activas y una configuración de producto.';
  end if;
  -- El segundo destino es una configuración sintética y transaccional: no mueve stock
  -- y desaparece con el ROLLBACK final.
  perform public.producto_area_configuracion_guardar(v_producto,v_area2,null,null,null,false,'plaza');

  select jsonb_build_object(
    'stock',(select coalesce(sum(stock_actual),0) from public.productos),
    'ledger',(select count(*) from stock_internal.movimientos),
    'existencias',(select count(*) from stock_internal.existencias),
    'lotes',(select count(*) from public.producto_lotes),
    'transferencias',(select count(*) from stock_internal.transferencias),
    'repartos',(select count(*) from stock_internal.repartos_area),
    'reparto_items',(select count(*) from stock_internal.repartos_area_items),
    'fudo',(select count(*) from public.fudo_movimientos),
    'lama',(select count(*) from public.lama_stock_eventos),
    'recetas',(select count(*) from public.recetas),
    'caja',(select count(*) from public.lama_caja_movimientos),
    'cuentas',(select count(*) from public.cuentas)
  ) into v_before;

  v_result:=public.producto_area_urgencia_guardar(v_producto,v_area1,true,'Prioridad de prueba');
  v_repeat:=public.producto_area_urgencia_guardar(v_producto,v_area1,true,'Prioridad de prueba');
  if not (v_result->>'urgente')::boolean or (v_result->>'repetido')::boolean
     or not (v_repeat->>'repetido')::boolean then
    raise exception 'Falla: marcar urgencia o su idempotencia.';
  end if;
  if not exists(select 1 from public.producto_area_asignacion pa where pa.producto_id=v_producto
      and pa.area_id=v_area1 and pa.urgente and pa.urgente_por=v_root and pa.urgente_desde is not null)
     or exists(select 1 from public.producto_area_asignacion pa where pa.producto_id=v_producto
      and pa.area_id=v_area2 and pa.urgente) then
    raise exception 'Falla: la urgencia no quedó aislada por área.';
  end if;

  perform public.producto_area_urgencia_guardar(v_producto,v_area2,true,null);
  v_rows:=public.producto_area_urgencias_listar(null);
  if (select count(*) from jsonb_array_elements(v_rows) x
      where (x->>'producto_id')::bigint=v_producto and (x->>'area_id')::uuid in (v_area1,v_area2))<>2 then
    raise exception 'Falla: el mismo producto no aparece urgente en dos áreas.';
  end if;
  if (select count(*) from jsonb_array_elements(public.producto_area_urgencias_listar(v_area1)) x
      where (x->>'producto_id')::bigint=v_producto)<>1 then
    raise exception 'Falla: la lista de Bodega no filtra/agrupar por destino.';
  end if;

  v_result:=public.producto_area_urgencia_guardar(v_producto,v_area1,false,null);
  v_repeat:=public.producto_area_urgencia_guardar(v_producto,v_area1,false,'nota ignorada');
  if (v_result->>'urgente')::boolean or (v_result->>'repetido')::boolean
     or not (v_repeat->>'repetido')::boolean then
    raise exception 'Falla: quitar urgencia o su idempotencia.';
  end if;

  -- La segunda cuenta operativa conserva puede_editar y también puede priorizar.
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_operativo,'role','authenticated','email','operational-test@invalid.local')::text,true);
  v_result:=public.producto_area_urgencia_guardar(v_producto,v_area1,true,'Prueba operativa');
  if not (v_result->>'urgente')::boolean then raise exception 'Falla: usuario operativo autorizado no pudo marcar urgencia.'; end if;
  perform public.producto_area_urgencia_guardar(v_producto,v_area1,false,null);

  perform set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'role','authenticated','email','ordinary-test@invalid.local')::text,true);
  v_rejected:=false;
  begin perform public.producto_area_urgencia_guardar(v_producto,v_area1,true,null);
  exception when insufficient_privilege then v_rejected:=true; end;
  if not v_rejected then raise exception 'Falla: usuario sin puede_editar marcó urgente.'; end if;
  perform set_config('request.jwt.claims','{}',true);
  v_rejected:=false;
  begin perform public.producto_area_urgencias_listar(null);
  exception when insufficient_privilege then v_rejected:=true; end;
  if not v_rejected then raise exception 'Falla: anónimo leyó urgencias.'; end if;
  perform set_config('request.jwt.claims',v_claims::text,true);

  select jsonb_build_object(
    'stock',(select coalesce(sum(stock_actual),0) from public.productos),
    'ledger',(select count(*) from stock_internal.movimientos),
    'existencias',(select count(*) from stock_internal.existencias),
    'lotes',(select count(*) from public.producto_lotes),
    'transferencias',(select count(*) from stock_internal.transferencias),
    'repartos',(select count(*) from stock_internal.repartos_area),
    'reparto_items',(select count(*) from stock_internal.repartos_area_items),
    'fudo',(select count(*) from public.fudo_movimientos),
    'lama',(select count(*) from public.lama_stock_eventos),
    'recetas',(select count(*) from public.recetas),
    'caja',(select count(*) from public.lama_caja_movimientos),
    'cuentas',(select count(*) from public.cuentas)
  ) into v_after;
  if v_after is distinct from v_before then raise exception 'Falla: una urgencia cambió cantidades o tablas operativas.'; end if;
  raise notice 'Fase 3 SQL correcta: marca, retiro, dos áreas, idempotencia, permisos y cero efectos físicos.';
end
$test$;

select 'Fase 3 SQL transaccional correcta; rollback a continuación.' resultado;
rollback;
