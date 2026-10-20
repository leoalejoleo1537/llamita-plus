begin;

do $test$
declare
  v_raiz constant uuid:='decc9a8d-0ab6-4306-bab5-a62bcaa40338'::uuid;
  v_operativo constant uuid:='6c3f6e47-7a26-40ce-84f6-9fe26925d642'::uuid;
  v_claims jsonb;
  v_producto bigint;
  v_ubicacion uuid;
  v_actual numeric;
  v_target numeric;
  v_referencia uuid;
  v_result jsonb;
  v_repetido jsonb;
  v_lote_producto bigint;
  v_lote_ubicacion uuid;
  v_lote_id bigint;
  v_desglose jsonb;
  v_conteos jsonb;
  v_item jsonb;
  v_antes jsonb;
  v_despues jsonb;
  v_def text;
  v_rechazado boolean;
begin
  if not exists(select 1 from auth.users where id=v_raiz and confirmed_at is not null and not is_anonymous) then
    raise exception 'TEST BLOCKED: UUID Auth raíz no disponible.';
  end if;
  v_claims:=jsonb_build_object('sub',v_raiz,'role','authenticated','email','root-test@invalid.local');
  perform set_config('request.jwt.claims',v_claims::text,true);

  select jsonb_build_object(
    'transferencias',(select count(*) from stock_internal.transferencias),
    'lotes',(select count(*) from public.producto_lotes),
    'fudo',(select count(*) from public.fudo_movimientos),
    'recetas',(select count(*) from public.recetas),
    'lama_eventos',(select count(*) from public.lama_stock_eventos),
    'lama_config',(select count(*) from public.lama_stock_config),
    'caja',(select count(*) from public.lama_caja_movimientos)
  ) into v_antes;

  select p.id,e.ubicacion_id,sum(e.cantidad) into v_producto,v_ubicacion,v_actual
  from public.productos p
  join stock_internal.existencias e on e.producto_id=p.id and e.sede='plaza' and e.lote_id is null and e.cantidad>0
  where p.sede='plaza'
    and not exists(select 1 from public.producto_lotes l where l.producto_id=p.id)
    and not exists(select 1 from stock_internal.lote_continuidad c where c.producto_id=p.id and c.sede='plaza')
    and not exists(select 1 from stock_internal.movimientos m where m.producto_id=p.id and m.sede='plaza' and m.lote_id is not null)
  group by p.id,e.ubicacion_id
  order by sum(e.cantidad) desc,p.id
  limit 1;
  if v_producto is null then raise exception 'TEST BLOCKED: no existe un producto plaza con saldo positivo sin lote.'; end if;

  v_desglose:=public.stock_ajuste_desglose_leer(v_producto,v_ubicacion);
  if v_desglose->>'tiene_lotes'<>'false' or jsonb_array_length(v_desglose->'lotes')<>1 then
    raise exception 'Falla: el producto sin lote no se mostró como un único bucket.';
  end if;

  -- Ajuste positivo decimal y reintento idéntico.
  v_referencia:=gen_random_uuid(); v_target:=v_actual+0.75;
  v_result:=public.stock_ajuste_guardar(v_referencia,v_producto,v_ubicacion,jsonb_build_object('sin_lote',v_target),'Prueba Fase 1');
  v_repetido:=public.stock_ajuste_guardar(v_referencia,v_producto,v_ubicacion,jsonb_build_object('sin_lote',v_target),'Prueba Fase 1');
  if v_repetido->>'repetido'<>'true'
     or (select count(*) from stock_internal.ajustes_manuales a where a.referencia=v_referencia)<>1
     or (select count(*) from stock_internal.movimientos m where m.ajuste_manual_id=v_referencia)<>1 then
    raise exception 'Falla: el reintento idéntico no fue idempotente.';
  end if;
  if abs((select sum(m.cantidad) from stock_internal.movimientos m where m.producto_id=v_producto and m.ubicacion_id=v_ubicacion and m.lote_id is null)-v_target)>0.000001 then
    raise exception 'Falla: saldo tras ajuste positivo incorrecto.';
  end if;
  if abs((select p.stock_actual::numeric-(select sum(m.cantidad) from stock_internal.movimientos m where m.producto_id=p.id) from public.productos p where p.id=v_producto))>0.000001 then
    raise exception 'Falla: proyección productos.stock_actual no coincide con el ledger.';
  end if;

  -- La misma referencia con contenido distinto se rechaza.
  v_rechazado:=false;
  begin
    perform public.stock_ajuste_guardar(v_referencia,v_producto,v_ubicacion,jsonb_build_object('sin_lote',v_target+1),'Prueba Fase 1');
  exception when unique_violation then v_rechazado:=true;
  end;
  if not v_rechazado then raise exception 'Falla: una referencia reutilizada con otro contenido fue aceptada.'; end if;

  -- Ajuste negativo sin llegar debajo de cero.
  perform public.stock_ajuste_guardar(gen_random_uuid(),v_producto,v_ubicacion,jsonb_build_object('sin_lote',v_actual),'Prueba Fase 1 reversa');
  v_rechazado:=false;
  begin
    perform public.stock_ajuste_guardar(gen_random_uuid(),v_producto,v_ubicacion,jsonb_build_object('sin_lote',-0.1),'Conteo negativo inválido');
  exception when check_violation then v_rechazado:=true;
  end;
  if not v_rechazado then raise exception 'Falla: se aceptó un saldo contado negativo.'; end if;
  -- Un conteo sin diferencia también queda auditado e idempotente sin forzar movimiento cero.
  v_referencia:=gen_random_uuid();
  v_result:=public.stock_ajuste_guardar(v_referencia,v_producto,v_ubicacion,jsonb_build_object('sin_lote',v_actual),'Conteo sin diferencia');
  v_repetido:=public.stock_ajuste_guardar(v_referencia,v_producto,v_ubicacion,jsonb_build_object('sin_lote',v_actual),'Conteo sin diferencia');
  if v_repetido->>'repetido'<>'true'
     or (select count(*) from stock_internal.ajustes_manuales a where a.referencia=v_referencia)<>1
     or exists(select 1 from stock_internal.movimientos m where m.ajuste_manual_id=v_referencia) then
    raise exception 'Falla: el conteo sin diferencia no quedó auditado sin movimientos cero.';
  end if;

  -- La cuenta operativa confirmada ajusta por puede_editar, sin pertenecer al gobierno raíz.
  if not exists(select 1 from auth.users where id=v_operativo and confirmed_at is not null and not is_anonymous)
     or not exists(select 1 from public.app_permisos where auth_uid=v_operativo and puede_editar) then
    raise exception 'TEST BLOCKED: la cuenta operativa confirmada no tiene puede_editar.';
  end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_operativo,'role','authenticated','email','operational-test@invalid.local')::text,true);
  v_referencia:=gen_random_uuid();
  perform public.stock_ajuste_guardar(v_referencia,v_producto,v_ubicacion,jsonb_build_object('sin_lote',v_actual+0.25),'Prueba de permiso operativo');
  if not exists(select 1 from stock_internal.ajustes_manuales a where a.referencia=v_referencia and a.actor_auth_uid=v_operativo) then
    raise exception 'Falla: el ajuste operativo no conservó el actor Auth.';
  end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_raiz,'role','authenticated','email','root-test@invalid.local')::text,true);
  perform public.stock_ajuste_guardar(gen_random_uuid(),v_producto,v_ubicacion,jsonb_build_object('sin_lote',v_actual),'Reversa de prueba operativa');

  -- Lote conocido con ajuste decimal independiente.
  select m.producto_id,m.ubicacion_id,m.lote_id into v_lote_producto,v_lote_ubicacion,v_lote_id
  from stock_internal.existencias m
  join public.productos p on p.id=m.producto_id and p.sede='plaza'
  where m.sede='plaza' and m.lote_id is not null and m.cantidad>0
  order by m.cantidad desc,m.producto_id limit 1;
  if v_lote_producto is null then raise exception 'TEST BLOCKED: no hay producto con lote y saldo para probar.'; end if;
  v_desglose:=public.stock_ajuste_desglose_leer(v_lote_producto,v_lote_ubicacion);
  if v_desglose->>'tiene_lotes'<>'true' or not exists(
    select 1 from jsonb_array_elements(v_desglose->'lotes') x where x->>'clave'=v_lote_id::text
  ) then raise exception 'Falla: no se mostró el lote conocido.'; end if;
  v_conteos:='{}'::jsonb;
  for v_item in select value from jsonb_array_elements(v_desglose->'lotes') loop
    v_target:=case when v_item->>'clave'=v_lote_id::text then (v_item->>'cantidad')::numeric+0.25 else (v_item->>'cantidad')::numeric end;
    v_conteos:=jsonb_set(v_conteos,array[v_item->>'clave'],to_jsonb(v_target),true);
  end loop;
  v_referencia:=gen_random_uuid();
  perform public.stock_ajuste_guardar(v_referencia,v_lote_producto,v_lote_ubicacion,v_conteos,'Ajuste lote conocido');
  if not exists(select 1 from stock_internal.movimientos m where m.ajuste_manual_id=v_referencia and m.lote_id=v_lote_id and m.cantidad=0.25 and m.tipo='ajuste') then
    raise exception 'Falla: el lote conocido no recibió el delta esperado.';
  end if;

  -- Bucket explícito sin lote en un producto loteado.
  v_desglose:=public.stock_ajuste_desglose_leer(v_lote_producto,v_lote_ubicacion);
  v_conteos:='{}'::jsonb;
  for v_item in select value from jsonb_array_elements(v_desglose->'lotes') loop
    v_target:=(v_item->>'cantidad')::numeric;
    if v_item->>'clave'='sin_lote' then v_target:=v_target+0.5; end if;
    v_conteos:=jsonb_set(v_conteos,array[v_item->>'clave'],to_jsonb(v_target),true);
  end loop;
  v_referencia:=gen_random_uuid();
  perform public.stock_ajuste_guardar(v_referencia,v_lote_producto,v_lote_ubicacion,v_conteos,'Alta sin lote informado');
  if not exists(select 1 from stock_internal.movimientos m where m.ajuste_manual_id=v_referencia and m.lote_id is null and m.cantidad=0.5 and m.tipo='ajuste') then
    raise exception 'Falla: no se registró por separado el saldo sin lote/vencimiento.';
  end if;

  -- La implementación comparte cerrojo producto/ubicación; la verificación evita que se quite por accidente.
  select pg_get_functiondef('public.stock_ajuste_guardar(uuid,bigint,uuid,jsonb,text)'::regprocedure) into v_def;
  if position('pg_advisory_xact_lock' in v_def)=0 or position('stock-location:' in v_def)=0 then
    raise exception 'Falla: falta el bloqueo transaccional producto/ubicación.';
  end if;
  if has_function_privilege('anon','public.stock_ajuste_guardar(uuid,bigint,uuid,jsonb,text)','EXECUTE')
     or has_function_privilege('service_role','public.stock_ajuste_guardar(uuid,bigint,uuid,jsonb,text)','EXECUTE')
     or not has_function_privilege('authenticated','public.stock_ajuste_guardar(uuid,bigint,uuid,jsonb,text)','EXECUTE')
     or has_function_privilege('anon','public.stock_ajuste_desglose_leer(bigint,uuid)','EXECUTE')
     or has_function_privilege('service_role','public.stock_ajuste_desglose_leer(bigint,uuid)','EXECUTE')
     or not has_function_privilege('authenticated','public.stock_ajuste_desglose_leer(bigint,uuid)','EXECUTE')
     or has_table_privilege('anon','stock_internal.ajustes_manuales','INSERT')
     or has_table_privilege('authenticated','stock_internal.ajustes_manuales','INSERT')
     or has_table_privilege('service_role','stock_internal.ajustes_manuales','INSERT')
     or has_table_privilege('authenticated','stock_internal.movimientos','INSERT') then
    raise exception 'Falla: privilegios de RPC o tablas internas fuera del contrato.';
  end if;

  perform set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'role','authenticated','email','ordinary-test@invalid.local')::text,true);
  v_rechazado:=false;
  begin
    perform public.stock_ajuste_guardar(gen_random_uuid(),v_producto,v_ubicacion,jsonb_build_object('sin_lote',v_actual),'Prueba sin permiso');
  exception when insufficient_privilege then v_rechazado:=true;
  end;
  if not v_rechazado then raise exception 'Falla: usuario sin puede_editar pudo ajustar.'; end if;

  select jsonb_build_object(
    'transferencias',(select count(*) from stock_internal.transferencias),
    'lotes',(select count(*) from public.producto_lotes),
    'fudo',(select count(*) from public.fudo_movimientos),
    'recetas',(select count(*) from public.recetas),
    'lama_eventos',(select count(*) from public.lama_stock_eventos),
    'lama_config',(select count(*) from public.lama_stock_config),
    'caja',(select count(*) from public.lama_caja_movimientos)
  ) into v_despues;
  if v_despues is distinct from v_antes then raise exception 'Falla: cambió un dato fuera del alcance de ajuste.'; end if;
  if exists(select 1 from stock_internal.existencias e where e.cantidad<0) then raise exception 'Falla: quedó una existencia negativa.'; end if;
  raise notice 'Fase 1 SQL: positivo/negativo, idempotencia, lote conocido, sin lote, proyección, permisos y límites externos verificados; rollback al final.';
end
$test$;

select 'Fase 1 SQL transaccional correcta; los ajustes sintéticos se revierten a continuación.' as resultado;
rollback;
