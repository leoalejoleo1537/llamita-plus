begin;
do $test$
declare v_root uuid;v_area uuid;v_seccion uuid;v_producto bigint;v_sin_config bigint;v_ref uuid:=gen_random_uuid();v_result jsonb;
begin
 select auth_uid into v_root from authz_internal.propietario_raiz where singleton;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_root,'role','authenticated')::text,true);
 select a.id,s.id,pa.producto_id into v_area,v_seccion,v_producto
 from public.producto_area_asignacion pa join public.areas_operativas a on a.id=pa.area_id
 join public.area_secciones s on s.id=pa.seccion_id and s.estado='activa'
 where pa.sede='plaza' and pa.estado='asignado' and pa.archivado_at is null limit 1;
 if v_producto is null then raise exception 'Falta una configuración completa para ejecutar la prueba.';end if;
 v_result:=public.producto_area_ficha_guardar(v_ref,v_producto,v_area,v_seccion,null,null,false,null,'Prueba rollback');
 if public.producto_area_ficha_guardar(v_ref,v_producto,v_area,v_seccion,null,null,false,null,'Prueba rollback')<>v_result then
  raise exception 'El reintento idempotente devolvió otro resultado';end if;
 begin
  perform public.producto_area_ficha_guardar(v_ref,v_producto,v_area,v_seccion,1,2,false,null,'Contenido distinto');
  raise exception 'Se aceptó reutilizar una referencia con otro contenido';
 exception when unique_violation then null;end;
 if public.area_seccion_crear(v_area,'ZZ_MOCACHINO_E2E_SECCION',9999,null) is null then raise exception 'No se creó la sección transaccional';end if;
 select p.id into v_sin_config from public.productos p where p.sede='plaza' and p.activo='SÍ'
  and not exists(select 1 from public.producto_area_asignacion pa where pa.producto_id=p.id and pa.area_id=v_area) limit 1;
 begin
  perform public.producto_area_configuracion_guardar(v_sin_config,v_area,null,null,null,false,'plaza');
  raise exception 'Se aceptó una configuración nueva sin sección';
 exception when check_violation then null;end;
 perform set_config('request.jwt.claims','{"role":"anon"}',true);
 begin
  perform public.area_seccion_crear(v_area,'ZZ_MOCACHINO_E2E_NO_AUTORIZADA',9999,null);
  raise exception 'Anon pudo crear una sección';
 exception when others then
  if sqlerrm='Anon pudo crear una sección' then raise;end if;
 end;
end $test$;
rollback;
