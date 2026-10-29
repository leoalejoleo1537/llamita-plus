-- Configuración explícita de la ruta Bodega -> área para un reparto.
-- No crea stock, lotes, movimientos ni documentos de reparto.

create or replace function public.panel_producto_area_configurar(
  p_referencia uuid,
  p_maestro_id bigint,
  p_representacion_id bigint,
  p_area_id uuid,
  p_seccion_id uuid,
  p_stock_min numeric default null,
  p_stock_max numeric default null,
  p_es_principal boolean default false
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare
  v_actor uuid;
  v_maestro public.productos;
  v_local bigint:=p_representacion_id;
  v_cantidad integer;
  v_config uuid;
  v_ya_configurado boolean:=false;
  v_creada boolean:=false;
  v_enlace_creado boolean:=false;
  v_solicitud jsonb;
  v_previa catalogo_internal.operaciones;
  v_resultado jsonb;
begin
  v_actor:=authz_internal.exigir_capacidad_b3_2a('editar');
  if p_referencia is null or p_maestro_id is null or p_area_id is null or p_seccion_id is null then
    raise exception 'Producto, área, sección y referencia son obligatorios.' using errcode='22023';
  end if;
  if p_stock_min is not null and p_stock_min<0
     or p_stock_max is not null and p_stock_max<0
     or p_stock_min is not null and p_stock_max is not null and p_stock_max<p_stock_min then
    raise exception 'Revisa el mínimo y máximo del área.' using errcode='22023';
  end if;
  if not exists(select 1 from public.areas_operativas a where a.id=p_area_id and a.sede='plaza' and a.estado='activa')
     or not exists(select 1 from stock_internal.ubicaciones u where u.area_id=p_area_id and u.sede='plaza' and u.activa) then
    raise exception 'El área de Local 1 no existe, está archivada o no tiene ubicación.' using errcode='22023';
  end if;
  if not exists(select 1 from public.area_secciones s where s.id=p_seccion_id and s.area_id=p_area_id and s.estado='activa') then
    raise exception 'La sección no pertenece al área o está archivada.' using errcode='22023';
  end if;
  v_solicitud:=jsonb_build_object('maestro',p_maestro_id,'representacion',p_representacion_id,
    'area',p_area_id,'seccion',p_seccion_id,'min',p_stock_min,'max',p_stock_max,'principal',coalesce(p_es_principal,false));
  perform pg_advisory_xact_lock(hashtextextended('panel-area-ref:'||p_referencia::text,0));
  select * into v_previa from catalogo_internal.operaciones where referencia=p_referencia;
  if found then
    if v_previa.actor<>v_actor or v_previa.solicitud<>v_solicitud then
      raise exception 'La referencia ya fue usada con otro contenido.' using errcode='23505';
    end if;
    return jsonb_set(v_previa.resultado,'{repetido}','true'::jsonb,true);
  end if;
  select * into v_maestro from public.productos where id=p_maestro_id and sede='central' and activo='SÍ' for update;
  if not found then raise exception 'El producto maestro no existe en Bodega.' using errcode='22023'; end if;
  if v_local is not null then
    if not exists(select 1 from public.productos p where p.id=v_local and p.sede='plaza' and p.activo='SÍ') then
      raise exception 'La representación elegida no existe en Local 1.' using errcode='22023';
    end if;
    if exists(select 1 from public.producto_enlace e where e.producto_sede_id=v_local and e.sede='plaza' and e.producto_bodega_id<>v_maestro.id) then
      raise exception 'La representación elegida ya pertenece a otro producto maestro.' using errcode='23505';
    end if;
    if exists(select 1 from public.producto_enlace e where e.producto_bodega_id=v_maestro.id and e.producto_sede_id=v_local and e.sede='plaza' and e.factor<>1) then
      raise exception 'El vínculo existente usa una conversión distinta de 1. Revísalo antes de configurar el área.' using errcode='22023';
    end if;
    if not exists(select 1 from public.producto_enlace e where e.producto_bodega_id=v_maestro.id and e.producto_sede_id=v_local and e.sede='plaza' and e.factor=1) then
      insert into public.producto_enlace(producto_bodega_id,producto_sede_id,sede,factor,creado_por)
        values(v_maestro.id,v_local,'plaza',1,v_actor::text);
      v_enlace_creado:=true;
    end if;
  else
    select count(*),min(e.producto_sede_id) into v_cantidad,v_local
      from public.producto_enlace e join public.productos p on p.id=e.producto_sede_id
      where e.producto_bodega_id=v_maestro.id and e.sede='plaza' and e.factor=1 and p.sede='plaza' and p.activo='SÍ';
    if v_cantidad>1 then raise exception 'Hay varias representaciones en Local 1. Elige una explícitamente.' using errcode='22023'; end if;
    if v_cantidad=0 then
      if exists(select 1 from public.producto_enlace e where e.producto_bodega_id=v_maestro.id and e.sede='plaza') then
        raise exception 'La representación enlazada está archivada. Revísala antes de continuar.' using errcode='22023';
      end if;
      if exists(select 1 from public.productos p where p.sede='plaza' and p.activo='SÍ' and catalogo_internal.nombre_clave(p.producto)=catalogo_internal.nombre_clave(v_maestro.producto)) then
        raise exception 'Existe una ficha de Local 1 del mismo nombre sin enlace explícito. Confirma su identidad antes de crear otra.' using errcode='23505';
      end if;
      insert into catalogo_internal.permiso_escritura(backend_pid,txid) values(pg_backend_pid(),txid_current()) on conflict do nothing;
      insert into public.productos(producto,rubro,stock_actual,stock_min,stock_max,activo,origen,sede,perecedero,tipo,unidad,costo_compra,costo_pendiente)
        values(v_maestro.producto,v_maestro.rubro,0,v_maestro.stock_min,v_maestro.stock_max,'SÍ','panel_area','plaza',v_maestro.perecedero,v_maestro.tipo,v_maestro.unidad,v_maestro.costo_compra,v_maestro.costo_pendiente)
        returning id into v_local;
      insert into public.producto_enlace(producto_bodega_id,producto_sede_id,sede,factor,creado_por)
        values(v_maestro.id,v_local,'plaza',1,v_actor::text);
      v_creada:=true;v_enlace_creado:=true;
    end if;
  end if;
  if exists(select 1 from public.producto_enlace e join public.producto_area_asignacion pa on pa.producto_id=e.producto_sede_id
      where e.producto_bodega_id=v_maestro.id and e.sede='plaza' and pa.area_id=p_area_id and pa.estado='asignado' and pa.archivado_at is null and pa.producto_id<>v_local) then
    raise exception 'Otra representación del maestro ya está configurada en esta área.' using errcode='23505';
  end if;
  select exists(select 1 from public.producto_area_asignacion pa where pa.producto_id=v_local and pa.area_id=p_area_id and pa.sede='plaza' and pa.estado='asignado' and pa.archivado_at is null) into v_ya_configurado;
  v_config:=stock_internal.guardar_configuracion_producto(v_local,p_area_id,p_seccion_id,p_stock_min,p_stock_max,coalesce(p_es_principal,false),v_actor);
  v_resultado:=jsonb_build_object('maestro_id',v_maestro.id,'representacion_id',v_local,'configuracion_id',v_config,
    'representacion_creada',v_creada,'enlace_creado',v_enlace_creado,'ya_configurado',v_ya_configurado,'stock_movido',false,'repetido',false);
  insert into catalogo_internal.operaciones(referencia,actor,solicitud,resultado,anterior) values(p_referencia,v_actor,v_solicitud,v_resultado,null);
  delete from catalogo_internal.permiso_escritura where backend_pid=pg_backend_pid() and txid=txid_current();
  return v_resultado;
end
$function$;

revoke all on function public.panel_producto_area_configurar(uuid,bigint,bigint,uuid,uuid,numeric,numeric,boolean) from public, anon, authenticated, service_role;
grant execute on function public.panel_producto_area_configurar(uuid,bigint,bigint,uuid,uuid,numeric,numeric,boolean) to authenticated;
