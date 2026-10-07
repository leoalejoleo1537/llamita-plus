-- Ejecutar únicamente en Supabase Llamita Plus iuryhsjucblmebdogewa.
-- Todas las escrituras de este archivo se rechazan dentro de bloques aislados;
-- el BEGIN/ROLLBACK asegura que la prueba no deje filas persistentes.
begin;

do $test$
declare v_count integer;
begin
  select count(*) into v_count from stock_internal.origen_pos;
  if v_count <> 4 then raise exception 'Esperadas cuatro configuraciones de sede; encontradas %.',v_count; end if;
  if (select origen from stock_internal.origen_pos where sede='plaza') <> 'ninguno' then
    raise exception 'plaza debe iniciar sin POS activo.';
  end if;
  if public.stock_pos_origen_permitido('plaza','fudo') then raise exception 'Fudo no debe estar permitido en plaza.'; end if;
  if public.stock_pos_origen_permitido('plaza','lama') then raise exception 'Lama no debe estar permitido en plaza.'; end if;
  if public.stock_pos_origen_permitido('plaza','toteat') then raise exception 'Toteat no debe estar permitido en plaza.'; end if;
  if public.stock_pos_origen_permitido('plaza','ninguno') then raise exception 'Ninguno no es un proveedor escritor.'; end if;
  update stock_internal.origen_pos set origen='prueba' where sede='plaza';
  if public.stock_pos_origen_permitido('plaza','fudo') or public.stock_pos_origen_permitido('plaza','lama') then
    raise exception 'El estado prueba permitió que un POS escribiera.';
  end if;
  update stock_internal.origen_pos set origen='ninguno' where sede='plaza';
  if public.stock_pos_origen_permitido('central','fudo') then raise exception 'central no permite un POS de ventas.'; end if;
  if public.stock_pos_origen_permitido('angamos','fudo') or public.stock_pos_origen_permitido('bodega','fudo') then
    raise exception 'Las sedes archivadas/históricas no pueden tener un origen activo.';
  end if;

  if has_table_privilege('anon','stock_internal.origen_pos','SELECT')
     or has_table_privilege('authenticated','stock_internal.origen_pos','SELECT')
     or has_table_privilege('service_role','stock_internal.origen_pos','SELECT')
     or has_table_privilege('anon','stock_internal.origen_pos','UPDATE')
     or has_table_privilege('authenticated','stock_internal.origen_pos','UPDATE')
     or has_table_privilege('service_role','stock_internal.origen_pos','UPDATE') then
    raise exception 'Un rol de API recibió permisos directos sobre origen_pos.';
  end if;
  if has_function_privilege('anon','public.stock_pos_origen_permitido(text,text)','EXECUTE')
     or has_function_privilege('authenticated','public.stock_pos_origen_permitido(text,text)','EXECUTE')
     or not has_function_privilege('service_role','public.stock_pos_origen_permitido(text,text)','EXECUTE') then
    raise exception 'ACL inesperada para el helper de Edge.';
  end if;
  if has_function_privilege('anon','public.fudo_procesar_item(text,text,text,text,text,numeric,text,timestamp with time zone)','EXECUTE')
     or has_function_privilege('authenticated','public.fudo_procesar_item(text,text,text,text,text,numeric,text,timestamp with time zone)','EXECUTE')
     or not has_function_privilege('service_role','public.fudo_procesar_item(text,text,text,text,text,numeric,text,timestamp with time zone)','EXECUTE') then
    raise exception 'fudo_procesar_item debe quedar invocable solo por el backend.';
  end if;

  begin
    insert into stock_internal.origen_pos(sede,origen) values ('plaza','fudo');
    raise exception 'Se aceptó una segunda configuración para plaza.';
  exception when unique_violation then null;
  end;
  begin
    update stock_internal.origen_pos set origen='fudo' where sede='central';
    raise exception 'central aceptó Fudo como origen.';
  exception when check_violation then null;
  end;
  begin
    update stock_internal.origen_pos set origen='lama' where sede='angamos';
    raise exception 'angamos aceptó Lama como origen.';
  exception when check_violation then null;
  end;
  begin
    update stock_internal.origen_pos set origen='toteat' where sede='bodega';
    raise exception 'bodega histórica aceptó Toteat como origen.';
  exception when check_violation then null;
  end;
  begin
    perform public.fudo_procesar_item('plaza','b2-3-1-test-sale','b2-3-1-test-item',null,'Prueba',1,'EAT-IN',now());
    raise exception 'fudo_procesar_item permitió procesar una venta sin origen activo.';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.fudo_movimientos(sede,fudo_item_id,aplicado)
    values ('plaza','b2-3-1-test-item-direct',false);
    raise exception 'fudo_movimientos aceptó una escritura sin origen activo.';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.lama_stock_config(sede,modo) values ('plaza','real');
    raise exception 'Lama permitió activar real sin ser el origen POS.';
  exception when insufficient_privilege then null;
  end;

  if exists(select 1 from public.lama_stock_config where sede in ('central','plaza')) then
    raise exception 'La prueba dejó configuración Lama persistente.';
  end if;
end
$test$;

rollback;
