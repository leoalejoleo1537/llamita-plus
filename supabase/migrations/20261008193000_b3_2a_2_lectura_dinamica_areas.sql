begin;

-- B3.2a.2: lectura dinámica de áreas y lectura protegida de preferencias.
-- No crea ni mueve existencias, lotes, movimientos, recetas o enlaces POS.

do $preflight$
begin
  if to_regclass('public.areas_operativas') is null
     or to_regclass('public.producto_area_asignacion') is null
     or to_regclass('stock_internal.ubicaciones') is null
     or to_regclass('stock_internal.existencias') is null then
    raise exception 'B3.2a.2 abortada: faltan los cimientos instalados por B3.2a.1.';
  end if;
  if to_regprocedure('public.areas_operativas_listar(text,boolean)') is null
     or to_regprocedure('public.producto_area_preferencia_guardar(bigint,uuid,text)') is null
     or to_regprocedure('public.producto_plaza_crear(text,text,double precision,double precision,boolean,text,text,uuid,text,text)') is null then
    raise exception 'B3.2a.2 abortada: las RPC protegidas de B3.2a.1 no están instaladas.';
  end if;
  if exists(select 1 from public.areas_operativas where sede<>'plaza') then
    raise exception 'B3.2a.2 abortada: existen áreas operativas fuera de Local 1.';
  end if;
end
$preflight$;

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
  if auth.uid() is null or coalesce(auth.jwt()->>'role','')<>'authenticated' then
    raise exception 'Se requiere una sesión autenticada.' using errcode='28000';
  end if;

  return query
  with ubicaciones_plaza as (
    select u.id,u.codigo,u.nombre,
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
  ), productos_plaza as (
    select p.id,p.producto,p.rubro,p.tipo,p.unidad
    from public.productos p
    where p.sede='plaza'
      and (p.activo='SÍ' or exists(
        select 1 from stock_internal.existencias e
        where e.sede='plaza' and e.producto_id=p.id and e.cantidad>0
      ))
  ), saldo_por_producto_ubicacion as (
    select e.producto_id,e.ubicacion_id,sum(e.cantidad)::numeric as cantidad
    from stock_internal.existencias e
    where e.sede='plaza'
    group by e.producto_id,e.ubicacion_id
  )
  select u.codigo,u.nombre,u.orden,
    p.id,p.producto,p.rubro,p.tipo,p.unidad,
    coalesce(s.cantidad,0)::numeric
  from ubicaciones_plaza u
  cross join productos_plaza p
  left join saldo_por_producto_ubicacion s
    on s.producto_id=p.id and s.ubicacion_id=u.id
  order by u.orden,u.nombre,p.producto,p.id;
end
$function$;

comment on function stock_internal.leer_existencias_areas_plaza() is
  'Lectura autenticada y dinámica de todas las áreas activas de plaza más Sin asignar; las cantidades provienen solo de stock_internal.existencias.';

create function public.producto_area_preferencia_leer(
  p_producto_id bigint,
  p_sede text default 'plaza'
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $function$
declare
  v_resultado jsonb;
begin
  perform authz_internal.exigir_capacidad_b3_2a('lectura');
  if p_sede is distinct from 'plaza' then
    raise exception 'La lectura de preferencias está limitada a Local 1.' using errcode='22023';
  end if;
  if not exists(select 1 from public.productos p where p.id=p_producto_id and p.sede='plaza') then
    raise exception 'El producto no existe en Local 1.' using errcode='22023';
  end if;

  select jsonb_build_object(
    'producto_id',p_producto_id,
    'area_id',pa.area_id,
    'estado',coalesce(pa.estado,'sin_asignar'),
    'area_codigo',a.codigo,
    'area_nombre',a.nombre,
    'ubicaciones',coalesce((
      select jsonb_agg(jsonb_build_object(
        'ubicacion_id',s.ubicacion_id,
        'codigo',s.codigo,
        'nombre',s.nombre,
        'cantidad',s.cantidad
      ) order by s.orden,s.nombre)
      from (
        select u.id as ubicacion_id,u.codigo,u.nombre,
          case when u.codigo='sin_asignar' then 2147483647 else coalesce(ao.orden,2147483646) end as orden,
          sum(e.cantidad)::numeric as cantidad
        from stock_internal.existencias e
        join stock_internal.ubicaciones u on u.id=e.ubicacion_id and u.sede='plaza'
        left join public.areas_operativas ao on ao.id=u.area_id
        where e.sede='plaza' and e.producto_id=p_producto_id and e.cantidad<>0
        group by u.id,u.codigo,u.nombre,ao.orden
      ) s
    ),'[]'::jsonb)
  ) into v_resultado
  from (select 1) base
  left join public.producto_area_asignacion pa
    on pa.sede='plaza' and pa.producto_id=p_producto_id
  left join public.areas_operativas a on a.id=pa.area_id;

  return v_resultado;
end
$function$;

revoke all on function public.producto_area_preferencia_leer(bigint,text)
  from public,anon,authenticated,service_role;
grant execute on function public.producto_area_preferencia_leer(bigint,text)
  to authenticated;

-- El helper privado continúa fuera de la Data API y sin ejecución cliente.
revoke all on function stock_internal.leer_existencias_areas_plaza()
  from public,anon,authenticated,service_role;
grant execute on function stock_internal.leer_existencias_areas_plaza()
  to postgres,authenticated;

commit;
