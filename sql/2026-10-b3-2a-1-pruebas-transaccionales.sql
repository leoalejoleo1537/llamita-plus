-- Pruebas B3.2a.1. Todo cambio sintético termina en ROLLBACK.
begin;

do $test$
declare
  v_raiz constant uuid:='decc9a8d-0ab6-4306-bab5-a62bcaa40338'::uuid;
  v_operador constant uuid:='6c3f6e47-7a26-40ce-84f6-9fe26925d642'::uuid;
  v_comun constant uuid:='00000000-0000-4000-8000-000000000099'::uuid;
  v_area uuid;
  v_area_pref uuid;
  v_area_saldo uuid;
  v_area_vacia uuid;
  v_area_operador uuid;
  v_ubicacion_origen uuid;
  v_ubicacion_destino uuid;
  v_producto_existente bigint;
  v_producto_enlazado bigint;
  v_producto_area bigint;
  v_producto_sin_area bigint;
  v_json jsonb;
  v_stock numeric;
  v_movimientos bigint;
  v_lotes bigint;
  v_recetas bigint;
  v_fudo bigint;
  v_enlaces bigint;
  v_existencias bigint;
  v_pref_stock numeric;
  v_pref_existencias bigint;
  v_error text;
  v_n bigint;
begin
  select coalesce(sum(e.cantidad),0),count(*) into v_stock,v_movimientos
  from stock_internal.existencias e;
  v_existencias:=v_movimientos;
  select count(*) into v_lotes from public.producto_lotes;
  select count(*) into v_recetas from public.recetas;
  select count(*) into v_fudo from public.fudo_movimientos;
  select count(*) into v_enlaces from public.producto_enlace;

  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',v_raiz,'role','authenticated','email',(select email from auth.users where id=v_raiz))::text,true);
  execute 'set local role authenticated';

  -- Propietario: alta atómica de área + ubicación.
  v_area:=public.area_operativa_crear('Área Norte B3',20,null,'plaza');
  execute 'reset role';
  if not exists(
    select 1 from public.areas_operativas a
    join stock_internal.ubicaciones u on u.area_id=a.id
    where a.id=v_area and a.nombre_normalizado='area norte b3'
      and u.sede='plaza' and u.codigo=a.codigo and u.activa
  ) then raise exception 'Falla: área y ubicación no se crearon atómicamente.'; end if;

  execute 'set local role authenticated';
  begin
    perform public.area_operativa_crear('  AREA   NÓRTE B3  ',21,'otro_codigo','plaza');
    raise exception 'Falla: se aceptó un nombre normalizado duplicado.';
  exception when unique_violation then null;
  end;
  begin
    perform public.area_operativa_crear('Área Central inválida',1,null,'central');
    raise exception 'Falla: se creó un área fuera de plaza.';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform public.area_operativa_crear('Sin asignar física',1,'sin_asignar','plaza');
    raise exception 'Falla: sin_asignar se creó como área física.';
  exception when sqlstate '22023' then null;
  end;

  -- Archivo de área vacía y sin preferencias.
  v_area_vacia:=public.area_operativa_crear('Área Vacía B3',22,null,'plaza');
  perform public.area_operativa_archivar(v_area_vacia,false);
  execute 'reset role';
  if not exists(
    select 1 from public.areas_operativas a join stock_internal.ubicaciones u on u.area_id=a.id
    where a.id=v_area_vacia and a.estado='archivada' and a.archivado_por=v_raiz and not u.activa
  ) then raise exception 'Falla: el archivo lógico no sincronizó área y ubicación.'; end if;

  -- Área con preferencia: exige confirmación y mueve solo metadata a Sin asignar.
  execute 'set local role authenticated';
  v_area_pref:=public.area_operativa_crear('Área Preferencia B3',23,null,'plaza');
  select p.id into v_producto_existente from public.productos p where p.sede='plaza' order by p.id limit 1;
  perform public.producto_area_preferencia_guardar(v_producto_existente,v_area_pref,'plaza');
  begin
    perform public.area_operativa_archivar(v_area_pref,false);
    raise exception 'Falla: se archivó un área con preferencias sin confirmación.';
  exception when check_violation then null;
  end;
  perform public.area_operativa_archivar(v_area_pref,true);
  execute 'reset role';
  if not exists(
    select 1 from public.producto_area_asignacion pa
    where pa.producto_id=v_producto_existente and pa.sede='plaza'
      and pa.area_id is null and pa.estado='sin_asignar' and pa.actualizado_por=v_raiz
  ) then raise exception 'Falla: la preferencia no volvió a Sin asignar.'; end if;
  execute 'set local role authenticated';
  begin
    perform public.producto_area_preferencia_guardar(v_producto_existente,v_area_pref,'plaza');
    raise exception 'Falla: se aceptó una preferencia hacia un área archivada.';
  exception when sqlstate '22023' then null;
  end;

  -- Área con saldo sintético a través del motor existente: el archivo se rechaza.
  -- B2.4 todavía admite únicamente las cuatro áreas fundacionales; se usa Cafetería.
  execute 'reset role';
  select a.id into v_area_saldo from public.areas_operativas a
  where a.sede='plaza' and a.codigo='cafeteria' and a.estado='activa';
  select u.id into v_ubicacion_origen from stock_internal.ubicaciones u
  where u.sede='plaza' and u.codigo='sin_asignar';
  select u.id into v_ubicacion_destino from stock_internal.ubicaciones u where u.area_id=v_area_saldo;
  select e.producto_id into v_producto_existente
  from stock_internal.existencias e
  where e.sede='plaza' and e.ubicacion_id=v_ubicacion_origen
    and e.lote_id is null and e.cantidad>=1
  order by e.producto_id limit 1;
  execute 'set local role authenticated';
  perform public.stock_transferir(gen_random_uuid(),v_producto_existente,v_producto_existente,
    v_ubicacion_origen,v_ubicacion_destino,1,'Prueba revertida B3.2a.1',null);
  begin
    perform public.area_operativa_archivar(v_area_saldo,false);
    raise exception 'Falla: se archivó un área con saldo.';
  exception when check_violation then null;
  end;

  -- Alta atómica de producto y preferencia, siempre con saldo cero.
  select public.producto_plaza_crear(
    'Producto B3 con área','Pruebas',0,10,false,'Pruebas','unidad',v_area,null,'plaza'
  ) into v_json;
  v_producto_area:=(v_json->>'producto_id')::bigint;
  execute 'reset role';
  if not exists(select 1 from public.productos p where p.id=v_producto_area and p.sede='plaza' and p.stock_actual=0)
     or not exists(select 1 from public.producto_area_asignacion pa where pa.producto_id=v_producto_area and pa.area_id=v_area)
     or exists(select 1 from public.producto_lotes l where l.producto_id=v_producto_area)
     or exists(select 1 from public.movimientos m where m.producto_id=v_producto_area)
     or exists(select 1 from stock_internal.movimientos m where m.producto_id=v_producto_area)
     or exists(select 1 from public.receta_items ri where ri.producto_id=v_producto_area)
     or exists(select 1 from public.producto_enlace pe
       where pe.producto_sede_id=v_producto_area or pe.producto_bodega_id=v_producto_area) then
    raise exception 'Falla: el producto con área creó efectos fuera de ficha/preferencia.';
  end if;

  execute 'set local role authenticated';
  select public.producto_plaza_crear(
    'Producto B3 sin área','Pruebas',0,10,false,null,'unidad',null,null,'plaza'
  ) into v_json;
  v_producto_sin_area:=(v_json->>'producto_id')::bigint;
  execute 'reset role';
  if not exists(select 1 from public.producto_area_asignacion pa
    where pa.producto_id=v_producto_sin_area and pa.area_id is null and pa.estado='sin_asignar') then
    raise exception 'Falla: el producto sin área no quedó en Sin asignar.';
  end if;
  execute 'set local role authenticated';
  perform public.producto_area_preferencia_guardar(v_producto_sin_area,v_area,'plaza');
  execute 'reset role';
  if not exists(select 1 from public.producto_area_asignacion pa
    where pa.producto_id=v_producto_sin_area and pa.area_id=v_area and pa.estado='asignado') then
    raise exception 'Falla: no se cambió la preferencia existente.';
  end if;

  -- La preferencia de un producto enlazado tampoco altera su enlace ni el ledger.
  select pe.producto_sede_id into v_producto_enlazado
  from public.producto_enlace pe
  join public.productos p on p.id=pe.producto_sede_id and p.sede='plaza'
  order by pe.id limit 1;
  select coalesce(sum(e.cantidad),0),count(*) into v_pref_stock,v_pref_existencias
  from stock_internal.existencias e;
  execute 'set local role authenticated';
  perform public.producto_area_preferencia_guardar(v_producto_enlazado,v_area,'plaza');
  execute 'reset role';
  if (select count(*) from public.producto_enlace)<>v_enlaces
     or (select count(*) from stock_internal.existencias)<>v_pref_existencias
     or (select coalesce(sum(e.cantidad),0) from stock_internal.existencias e)<>v_pref_stock then
    raise exception 'Falla: la preferencia alteró enlaces Fudo o existencias.';
  end if;

  -- El administrador operativo conserva ajustes/edición, sin gobierno de usuarios.
  execute 'reset role';
  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',v_operador,'role','authenticated','email',(select email from auth.users where id=v_operador))::text,true);
  execute 'set local role authenticated';
  v_area_operador:=public.area_operativa_crear('Área Operador B3',25,null,'plaza');
  perform public.area_operativa_editar(v_area_operador,'Área Operador Editada B3',26);
  perform public.producto_area_preferencia_guardar(v_producto_sin_area,v_area_operador,'plaza');
  select count(*) into v_n from public.areas_operativas_listar('plaza',true);
  if v_n<4 then raise exception 'Falla: el administrador no pudo listar áreas.'; end if;
  begin
    perform public.permisos_listar();
    raise exception 'Falla: el administrador operativo pudo gestionar usuarios.';
  exception when insufficient_privilege then null;
  end;

  -- Usuario común y anon no pueden escribir ni ejecutar operaciones protegidas.
  execute 'reset role';
  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',v_comun,'role','authenticated','email','comun@example.invalid')::text,true);
  execute 'set local role authenticated';
  select count(*) into v_n from public.areas_operativas_listar('plaza',false);
  if v_n<4 then raise exception 'Falla: el usuario autenticado no pudo leer áreas activas.'; end if;
  begin
    perform count(*) from public.areas_operativas_listar('plaza',true);
    raise exception 'Falla: el usuario común pudo listar áreas archivadas.';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.area_operativa_crear('Área común',30,null,'plaza');
    raise exception 'Falla: un usuario común creó un área.';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.producto_area_asignacion(
      sede,producto_id,area_id,estado,creado_por,actualizado_por
    ) values('plaza',v_producto_existente,null,'sin_asignar',v_comun,v_comun);
    raise exception 'Falla: authenticated conserva DML directo en asignaciones.';
  exception when insufficient_privilege then null;
  end;

  execute 'reset role';
  execute 'set local role anon';
  begin
    perform public.area_operativa_crear('Área anónima',31,null,'plaza');
    raise exception 'Falla: anon ejecutó una RPC protegida.';
  exception when insufficient_privilege then null;
  end;
  execute 'reset role';

  -- Las únicas alteraciones contables de esta prueba son la transferencia sintética;
  -- el total físico no cambia. El ROLLBACK elimina también ese par de movimientos.
  if (select coalesce(sum(e.cantidad),0) from stock_internal.existencias e)<>v_stock then
    raise exception 'Falla: cambió el total físico del ledger.';
  end if;
  if (select count(*) from public.producto_lotes)<>v_lotes
     or (select count(*) from public.recetas)<>v_recetas
     or (select count(*) from public.fudo_movimientos)<>v_fudo
     or (select count(*) from public.producto_enlace)<>v_enlaces then
    raise exception 'Falla: cambiaron lotes, recetas o Fudo durante la prueba.';
  end if;
end
$test$;

rollback;
