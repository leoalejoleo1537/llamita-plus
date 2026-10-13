-- Bodega → Local 1: búsqueda segura y alta explícita de una representación
-- enlazada más su configuración de área. No mueve ni crea existencias.

create or replace function public.bodega_productos_area_buscar(
  p_consulta text,
  p_area_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_actor uuid;
  v_q text;
  v_result jsonb;
begin
  v_actor := authz_internal.exigir_capacidad_b3_2a('editar');
  v_q := btrim(regexp_replace(
    translate(lower(coalesce(p_consulta,'')), 'áéíóúüñ', 'aeiouun'),
    '[^a-z0-9]+', ' ', 'g'));
  if length(v_q) < 2 or length(v_q) > 80 then
    raise exception 'Escribe al menos dos caracteres para buscar en Bodega.' using errcode='22023';
  end if;
  if p_area_id is null or not exists(
    select 1 from public.areas_operativas a
    join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza' and u.activa
    where a.id=p_area_id and a.sede='plaza' and a.estado='activa'
  ) then
    raise exception 'El área no existe, no pertenece a Local 1 o está archivada.' using errcode='22023';
  end if;

  with q as (
    select v_q as texto, regexp_split_to_array(v_q,'[^a-z0-9]+') as tokens
  ), maestros as (
    select p.id, p.producto, p.rubro, p.tipo, p.unidad,
      translate(lower(p.producto),'áéíóúüñ','aeiouun') as nombre_norm,
      regexp_split_to_array(translate(lower(p.producto),'áéíóúüñ','aeiouun'),'[^a-z0-9]+') as tokens
    from public.productos p
    where p.sede='central' and p.activo='SÍ'
  ), coincidencias as (
    select m.* from maestros m cross join q
    where m.id::text=q.texto
       or m.nombre_norm like '%'||q.texto||'%'
       or not exists (
         select 1 from unnest(q.tokens) qt(token)
         where qt.token<>'' and not exists (
           select 1 from unnest(m.tokens) mt(token)
           where mt.token=qt.token
              or mt.token=regexp_replace(qt.token,'(es|s)$','')
              or qt.token=regexp_replace(mt.token,'(es|s)$','')
         )
       )
    order by case when m.id::text=q.texto then 0 when m.nombre_norm=q.texto then 1 else 2 end,
      m.producto
    limit 50
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'producto_bodega_id',m.id,
    'nombre_bodega',m.producto,
    'rubro',m.rubro,
    'tipo',m.tipo,
    'unidad',m.unidad,
    'stock_bodega',coalesce((
      select sum(x.cantidad) from stock_internal.existencias x
      join stock_internal.ubicaciones ub on ub.id=x.ubicacion_id and ub.sede=x.sede
      where x.producto_id=m.id and x.sede='central' and ub.codigo='bodega_central' and ub.activa
    ),0),
    'representaciones',coalesce((
      select jsonb_agg(jsonb_build_object(
        'producto_plaza_id',lp.id,'nombre',lp.producto,'unidad',lp.unidad,
        'rubro',lp.rubro,'tipo',lp.tipo,'factor',e.factor,
        'saldo',coalesce((select sum(x.cantidad) from stock_internal.existencias x
          where x.producto_id=lp.id and x.sede='plaza'),0),
        'ubicaciones',coalesce((select jsonb_agg(jsonb_build_object('nombre',u.nombre,'cantidad',z.cantidad) order by u.nombre)
          from (select x.ubicacion_id,sum(x.cantidad) cantidad from stock_internal.existencias x
            where x.producto_id=lp.id and x.sede='plaza' group by x.ubicacion_id) z
          join stock_internal.ubicaciones u on u.id=z.ubicacion_id and u.sede='plaza'),'[]'::jsonb),
        'configurada_en_area',exists(select 1 from public.producto_area_asignacion pa
          where pa.sede='plaza' and pa.producto_id=lp.id and pa.area_id=p_area_id
            and pa.estado='asignado' and pa.archivado_at is null),
        'configuracion', (select jsonb_build_object('seccion_id',pa.seccion_id,'seccion',s.nombre,
          'stock_min',pa.stock_min,'stock_max',pa.stock_max)
          from public.producto_area_asignacion pa
          left join public.area_secciones s on s.id=pa.seccion_id
          where pa.sede='plaza' and pa.producto_id=lp.id and pa.area_id=p_area_id
            and pa.estado='asignado' and pa.archivado_at is null limit 1)
      ) order by lp.producto)
      from public.producto_enlace e
      join public.productos lp on lp.id=e.producto_sede_id and lp.sede='plaza'
      where e.sede='plaza' and e.producto_bodega_id=m.id
    ),'[]'::jsonb),
    'posibles_representaciones',coalesce((
      select jsonb_agg(jsonb_build_object(
        'producto_plaza_id',lp.id,'nombre',lp.producto,'unidad',lp.unidad,
        'rubro',lp.rubro,'tipo',lp.tipo,'saldo',coalesce((select sum(x.cantidad)
          from stock_internal.existencias x where x.producto_id=lp.id and x.sede='plaza'),0),
        'ubicaciones',coalesce((select jsonb_agg(jsonb_build_object('nombre',u.nombre,'cantidad',z.cantidad) order by u.nombre)
          from (select x.ubicacion_id,sum(x.cantidad) cantidad from stock_internal.existencias x
            where x.producto_id=lp.id and x.sede='plaza' group by x.ubicacion_id) z
          join stock_internal.ubicaciones u on u.id=z.ubicacion_id and u.sede='plaza'),'[]'::jsonb),
        'vinculada_a_bodega_id',e.producto_bodega_id,
        'vinculada_a_este_maestro',e.producto_bodega_id=m.id,
        'configurada_en_area',exists(select 1 from public.producto_area_asignacion pa
          where pa.sede='plaza' and pa.producto_id=lp.id and pa.area_id=p_area_id
            and pa.estado='asignado' and pa.archivado_at is null),
        'configuracion',(select jsonb_build_object('seccion_id',pa.seccion_id,'seccion',s.nombre,
          'stock_min',pa.stock_min,'stock_max',pa.stock_max)
          from public.producto_area_asignacion pa
          left join public.area_secciones s on s.id=pa.seccion_id
          where pa.sede='plaza' and pa.producto_id=lp.id and pa.area_id=p_area_id
            and pa.estado='asignado' and pa.archivado_at is null limit 1)
      ) order by lp.producto)
      from public.productos lp
      left join public.producto_enlace e on e.sede='plaza' and e.producto_sede_id=lp.id
      where lp.sede='plaza' and lp.activo='SÍ'
        and exists (
          select 1 from unnest(m.tokens) mt(token)
          where length(mt.token)>=4 and exists (
            select 1 from unnest(regexp_split_to_array(translate(lower(lp.producto),'áéíóúüñ','aeiouun'),'[^a-z0-9]+')) lt(token)
            where lt.token=mt.token or lt.token=regexp_replace(mt.token,'(es|s)$','')
              or mt.token=regexp_replace(lt.token,'(es|s)$','')
          )
        )
        and (e.producto_bodega_id is distinct from m.id)
    ),'[]'::jsonb)
  ) order by m.producto),'[]'::jsonb)
  into v_result
  from coincidencias m;

  return v_result;
end
$function$;

revoke all on function public.bodega_productos_area_buscar(text,uuid) from public, anon, service_role;
grant execute on function public.bodega_productos_area_buscar(text,uuid) to authenticated;
comment on function public.bodega_productos_area_buscar(text,uuid) is
  'Busca maestros de Bodega, saldo del ledger y representaciones explícitas de Local 1; no escribe datos.';

create or replace function public.bodega_producto_area_agregar(
  p_producto_bodega_id bigint,
  p_producto_plaza_id bigint,
  p_crear_representacion boolean,
  p_area_id uuid,
  p_seccion_id uuid default null,
  p_stock_min numeric default null,
  p_stock_max numeric default null,
  p_es_principal boolean default false,
  p_confirmar boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid;
  v_maestro public.productos%rowtype;
  v_local public.productos%rowtype;
  v_local_id bigint;
  v_enlace public.producto_enlace%rowtype;
  v_config_id uuid;
  v_config_existente uuid;
  v_creada boolean := false;
  v_vinculo_creado boolean := false;
begin
  v_actor := authz_internal.exigir_capacidad_b3_2a('editar');
  if p_confirmar is distinct from true then
    raise exception 'Confirma el producto maestro y su representación en Local 1 antes de guardar.' using errcode='22023';
  end if;
  if p_area_id is null or not exists(
    select 1 from public.areas_operativas a
    join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza' and u.activa
    where a.id=p_area_id and a.sede='plaza' and a.estado='activa'
  ) then
    raise exception 'El área no existe, no pertenece a Local 1 o está archivada.' using errcode='22023';
  end if;
  if p_stock_min is not null and p_stock_min<0 or p_stock_max is not null and p_stock_max<0
     or p_stock_min is not null and p_stock_max is not null and p_stock_max<p_stock_min then
    raise exception 'El mínimo y máximo del área no son válidos.' using errcode='22023';
  end if;
  if p_crear_representacion and p_producto_plaza_id is not null
     or not p_crear_representacion and p_producto_plaza_id is null then
    raise exception 'Selecciona una representación existente o confirma la creación de una nueva, no ambas.' using errcode='22023';
  end if;

  select p.* into v_maestro
  from public.productos p
  where p.id=p_producto_bodega_id and p.sede='central' and p.activo='SÍ'
  for update;
  if not found then
    raise exception 'El producto maestro ya no existe o no está activo en Bodega.' using errcode='22023';
  end if;

  if p_crear_representacion then
    -- Reintento tras timeout: reutiliza la ficha creada por esta misma RPC.
    select lp.* into v_local
    from public.producto_enlace e
    join public.productos lp on lp.id=e.producto_sede_id and lp.sede='plaza'
    where e.sede='plaza' and e.producto_bodega_id=v_maestro.id
      and lp.origen='bodega_maestro_rpc'
      and lp.notas='Representación enlazada al producto maestro Bodega #'||v_maestro.id
    order by e.created_at
    limit 1
    for update of lp;
    if found then
      v_local_id:=v_local.id;
    else
      if exists(select 1 from public.producto_enlace e
        where e.sede='plaza' and e.producto_bodega_id=v_maestro.id) then
        raise exception 'Este maestro ya tiene representación en Local 1. Selecciona una de las opciones existentes.' using errcode='23505';
      end if;
      if exists(select 1 from public.productos p where p.sede='plaza'
        and translate(lower(btrim(p.producto)),'áéíóúüñ','aeiouun')=
            translate(lower(btrim(v_maestro.producto)),'áéíóúüñ','aeiouun')) then
        raise exception 'Ya existe en Local 1 una ficha con el mismo nombre normalizado. Elígela explícitamente como representación.' using errcode='23505';
      end if;
      insert into public.productos(
        producto,rubro,stock_actual,stock_min,stock_max,activo,origen,notas,
        sede,perecedero,urgente,tipo,unidad
      ) values(
        v_maestro.producto,v_maestro.rubro,0,0,0,'SÍ','bodega_maestro_rpc',
        'Representación enlazada al producto maestro Bodega #'||v_maestro.id,
        'plaza',v_maestro.perecedero,false,v_maestro.tipo,v_maestro.unidad
      ) returning * into v_local;
      v_local_id:=v_local.id;
      v_creada:=true;
    end if;
  else
    select p.* into v_local
    from public.productos p
    where p.id=p_producto_plaza_id and p.sede='plaza' and p.activo='SÍ'
    for update;
    if not found then
      raise exception 'La representación seleccionada ya no existe o no está activa en Local 1.' using errcode='22023';
    end if;
    v_local_id:=v_local.id;
  end if;

  select e.* into v_enlace
  from public.producto_enlace e
  where e.sede='plaza' and e.producto_sede_id=v_local_id
  for update;
  if found then
    if v_enlace.producto_bodega_id<>v_maestro.id then
      raise exception 'La ficha de Local 1 ya está enlazada a otro producto maestro de Bodega.' using errcode='23505';
    end if;
  else
    insert into public.producto_enlace(producto_bodega_id,sede,producto_sede_id,factor,creado_por)
    values(v_maestro.id,'plaza',v_local_id,1,v_actor::text)
    returning * into v_enlace;
    v_vinculo_creado:=true;
  end if;

  select pa.id into v_config_existente
  from public.producto_area_asignacion pa
  where pa.sede='plaza' and pa.producto_id=v_local_id and pa.area_id=p_area_id
    and pa.estado='asignado' and pa.archivado_at is null
  for update;
  if v_config_existente is not null then
    return jsonb_build_object(
      'producto_bodega_id',v_maestro.id,'producto_plaza_id',v_local_id,
      'area_id',p_area_id,'asignacion_id',v_config_existente,
      'representacion_creada',v_creada,'vinculo_creado',v_vinculo_creado,
      'ya_configurado',true,'saldo_movido',false,'stock_creado',false,
      'lotes_creados',false,'movimientos_creados',false
    );
  end if;

  v_config_id:=stock_internal.guardar_configuracion_producto(
    v_local_id,p_area_id,p_seccion_id,p_stock_min,p_stock_max,
    coalesce(p_es_principal,false),v_actor);

  return jsonb_build_object(
    'producto_bodega_id',v_maestro.id,'producto_plaza_id',v_local_id,
    'area_id',p_area_id,'asignacion_id',v_config_id,
    'representacion_creada',v_creada,'vinculo_creado',v_vinculo_creado,
    'ya_configurado',false,'saldo_movido',false,'stock_creado',false,
    'lotes_creados',false,'movimientos_creados',false,
    'auditoria',jsonb_build_object('actor',v_actor,'maestro_bodega_id',v_maestro.id,
      'representacion_plaza_id',v_local_id,'area_id',p_area_id,
      'enlace_creado_at',v_enlace.created_at,'configuracion_id',v_config_id)
  );
end
$function$;

revoke all on function public.bodega_producto_area_agregar(bigint,bigint,boolean,uuid,uuid,numeric,numeric,boolean,boolean) from public, anon, service_role;
grant execute on function public.bodega_producto_area_agregar(bigint,bigint,boolean,uuid,uuid,numeric,numeric,boolean,boolean) to authenticated;
comment on function public.bodega_producto_area_agregar(bigint,bigint,boolean,uuid,uuid,numeric,numeric,boolean,boolean) is
  'Crea/reutiliza una representación explícita de producto maestro en Local 1 y la configura en un área. No crea existencias ni movimientos.';
