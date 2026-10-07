-- No ocultar stock físico por estar inactivo el producto maestro.
-- Los inactivos sin saldo siguen fuera del inventario visible.
create or replace function stock_internal.leer_existencias_areas_plaza()
returns table (
  area_codigo text,
  area_nombre text,
  area_orden integer,
  producto_id bigint,
  producto text,
  rubro text,
  tipo text,
  unidad text,
  cantidad numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null then
    raise exception 'Se requiere una sesión autenticada.' using errcode='28000';
  end if;

  return query
  with ubicaciones_plaza as (
    select u.id, u.codigo, u.nombre,
           case when u.codigo='sin_asignar' then 0 else a.orden end as orden
    from stock_internal.ubicaciones u
    left join public.areas_operativas a
      on a.id=u.area_id and a.sede='plaza' and a.estado='activa'
    where u.sede='plaza'
      and u.activa
      and (
        (u.codigo='sin_asignar' and u.area_id is null)
        or (u.codigo in ('cocina_fria','cocina_caliente','barra','cafeteria')
            and u.area_id is not null and a.id is not null)
      )
  ), productos_plaza as (
    select p.id, p.producto, p.rubro, p.tipo, p.unidad
    from public.productos p
    where p.sede='plaza'
      and (p.activo='SÍ' or exists(
        select 1 from stock_internal.existencias e
        where e.sede='plaza' and e.producto_id=p.id and e.cantidad>0
      ))
  ), saldo_por_producto_ubicacion as (
    select e.producto_id, e.ubicacion_id, sum(e.cantidad)::numeric as cantidad
    from stock_internal.existencias e
    where e.sede='plaza'
    group by e.producto_id, e.ubicacion_id
  )
  select u.codigo, u.nombre, u.orden,
         p.id, p.producto, p.rubro, p.tipo, p.unidad,
         coalesce(s.cantidad,0)::numeric
  from ubicaciones_plaza u
  cross join productos_plaza p
  left join saldo_por_producto_ubicacion s
    on s.producto_id=p.id and s.ubicacion_id=u.id
  order by u.orden, p.producto, p.id;
end
$function$;

comment on function stock_internal.leer_existencias_areas_plaza() is
  'Helper privado autenticado que expone únicamente saldos y metadatos de plaza desde stock_internal.existencias; conserva productos inactivos con saldo positivo.';
