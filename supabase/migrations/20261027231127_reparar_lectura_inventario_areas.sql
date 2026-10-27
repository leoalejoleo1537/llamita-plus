-- Repara la lectura que alimenta la portada de Inventario de Local 1.
-- PostgreSQL no permite ordenar un UNION usando expresiones/columnas
-- calificadas directamente en ese nivel. La unión se encapsula en `filas`
-- y el orden se aplica sobre esa relación, sin cambiar datos ni cantidades.
create or replace function stock_internal.leer_existencias_areas_plaza()
returns table(
  area_id uuid,
  area_codigo text,
  area_nombre text,
  area_orden integer,
  ubicacion_id uuid,
  configuracion_id uuid,
  configurado boolean,
  es_principal boolean,
  seccion_id uuid,
  seccion_codigo text,
  seccion_nombre text,
  seccion_orden integer,
  producto_id bigint,
  producto text,
  rubro text,
  tipo text,
  unidad text,
  stock_min numeric,
  stock_max numeric,
  cantidad numeric
)
language plpgsql
stable
security definer
set search_path=''
as $function$
begin
  if auth.uid() is null or coalesce(auth.jwt()->>'role','') <> 'authenticated' then
    raise exception 'Se requiere una sesión autenticada.' using errcode='28000';
  end if;

  return query
  with ups as (
    select
      u.id as ubicacion_id,
      u.area_id,
      u.codigo,
      u.nombre,
      case when u.codigo='sin_asignar' then 2147483647 else a.orden end as orden
    from stock_internal.ubicaciones u
    left join public.areas_operativas a
      on a.id=u.area_id and a.sede='plaza' and a.estado='activa'
    where u.sede='plaza'
      and u.activa
      and (
        (u.codigo='sin_asignar' and u.area_id is null)
        or (u.area_id is not null and a.id is not null)
      )
  ), saldos as (
    select
      e.producto_id,
      e.ubicacion_id,
      sum(e.cantidad)::numeric as cantidad
    from stock_internal.existencias e
    where e.sede='plaza'
    group by e.producto_id,e.ubicacion_id
  ), configuradas(
    area_id,area_codigo,area_nombre,area_orden,ubicacion_id,
    configuracion_id,configurado,es_principal,seccion_id,seccion_codigo,
    seccion_nombre,seccion_orden,producto_id,producto,rubro,tipo,unidad,
    stock_min,stock_max,cantidad
  ) as (
    select
      a.id,a.codigo,a.nombre,a.orden,u.ubicacion_id,
      pa.id,true,pa.es_principal,s.id,s.codigo,s.nombre,s.orden,
      p.id,p.producto,p.rubro,p.tipo,p.unidad,
      pa.stock_min,pa.stock_max,coalesce(sa.cantidad,0)::numeric
    from public.producto_area_asignacion pa
    join public.areas_operativas a
      on a.id=pa.area_id and a.sede='plaza' and a.estado='activa'
    join ups u on u.area_id=a.id
    join public.productos p on p.id=pa.producto_id and p.sede='plaza'
    left join public.area_secciones s on s.id=pa.seccion_id and s.estado='activa'
    left join saldos sa on sa.producto_id=p.id and sa.ubicacion_id=u.ubicacion_id
    where pa.sede='plaza'
      and pa.estado='asignado'
      and (p.activo='SÍ' or coalesce(sa.cantidad,0)<>0)
  ), fisicas(
    area_id,area_codigo,area_nombre,area_orden,ubicacion_id,
    configuracion_id,configurado,es_principal,seccion_id,seccion_codigo,
    seccion_nombre,seccion_orden,producto_id,producto,rubro,tipo,unidad,
    stock_min,stock_max,cantidad
  ) as (
    select
      u.area_id,u.codigo,u.nombre,u.orden,u.ubicacion_id,
      null::uuid,false,false,null::uuid,null::text,null::text,null::integer,
      p.id,p.producto,p.rubro,p.tipo,p.unidad,
      null::numeric,null::numeric,sa.cantidad
    from saldos sa
    join ups u on u.ubicacion_id=sa.ubicacion_id
    join public.productos p on p.id=sa.producto_id and p.sede='plaza'
    where sa.cantidad<>0
      and not exists (
        select 1
        from public.producto_area_asignacion pa
        where pa.sede='plaza'
          and pa.producto_id=p.id
          and pa.area_id=u.area_id
          and pa.estado='asignado'
      )
  ), filas as (
    select * from configuradas
    union all
    select * from fisicas
  )
  select
    f.area_id,f.area_codigo,f.area_nombre,f.area_orden,f.ubicacion_id,
    f.configuracion_id,f.configurado,f.es_principal,f.seccion_id,
    f.seccion_codigo,f.seccion_nombre,f.seccion_orden,f.producto_id,
    f.producto,f.rubro,f.tipo,f.unidad,f.stock_min,f.stock_max,f.cantidad
  from filas f
  order by
    f.area_orden,
    f.area_nombre,
    f.seccion_orden nulls last,
    f.seccion_nombre nulls last,
    f.producto,
    f.producto_id;
end
$function$;

revoke all on function stock_internal.leer_existencias_areas_plaza()
  from public,anon,authenticated,service_role;
