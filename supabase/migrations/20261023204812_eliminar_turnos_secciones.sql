begin;
drop function public.stock_leer_areas();
drop function stock_internal.leer_existencias_areas_plaza();
drop function public.producto_area_configuraciones_listar(bigint,text);
drop function public.area_secciones_listar(uuid,boolean);
alter table public.area_secciones drop column turno;
alter table public.secciones drop column turno;

create or replace function public.area_seccion_crear(p_area_id uuid,p_nombre text,p_orden integer default 100,p_codigo text default null)
returns uuid language plpgsql security definer set search_path='' as $function$
declare v_actor uuid;v_id uuid;v_nombre text;v_codigo text;
begin
 v_actor:=authz_internal.exigir_capacidad_b3_2a('editar');v_nombre:=btrim(regexp_replace(coalesce(p_nombre,''),'[[:space:]]+',' ','g'));
 if length(v_nombre) not between 1 and 80 then raise exception 'El nombre de la sección es obligatorio.' using errcode='22023';end if;
 if not exists(select 1 from public.areas_operativas a where a.id=p_area_id and a.sede='plaza' and a.estado='activa') then raise exception 'El área no existe o está archivada.' using errcode='22023';end if;
 v_codigo:=coalesce(nullif(btrim(p_codigo),''),'sec_'||substr(md5(gen_random_uuid()::text),1,12));
 insert into public.area_secciones(area_id,codigo,nombre,orden,estado,creado_por,actualizado_por)
 values(p_area_id,v_codigo,v_nombre,greatest(coalesce(p_orden,100),0),'activa',v_actor,v_actor) returning id into v_id;return v_id;
end $function$;

create function public.area_secciones_listar(p_area_id uuid,p_incluir_archivadas boolean default false)
returns table(id uuid,area_id uuid,codigo text,nombre text,orden integer,estado text,productos_configurados bigint)
language plpgsql stable security definer set search_path='' as $function$
begin
 perform authz_internal.exigir_capacidad_b3_2a(case when p_incluir_archivadas then 'ajustes' else 'lectura' end);
 if not exists(select 1 from public.areas_operativas a where a.id=p_area_id and a.sede='plaza') then raise exception 'El área no existe en Local 1.' using errcode='22023';end if;
 return query select s.id,s.area_id,s.codigo,s.nombre,s.orden,s.estado,
  (select count(*) from public.producto_area_asignacion pa where pa.seccion_id=s.id and pa.estado='asignado')
 from public.area_secciones s where s.area_id=p_area_id and (p_incluir_archivadas or s.estado='activa')
 order by s.orden,s.nombre_normalizado,s.id;
end $function$;

create function public.producto_area_configuraciones_listar(p_producto_id bigint,p_sede text default 'plaza')
returns table(id uuid,producto_id bigint,area_id uuid,area_codigo text,area_nombre text,seccion_id uuid,seccion_codigo text,seccion_nombre text,
 stock_min numeric,stock_max numeric,es_principal boolean,estado text,ubicacion_id uuid,cantidad numeric)
language plpgsql stable security definer set search_path='' as $function$
begin
 perform authz_internal.exigir_capacidad_b3_2a('lectura');
 if p_sede is distinct from 'plaza' then raise exception 'La configuración producto-área está limitada a Local 1.' using errcode='22023';end if;
 return query select pa.id,pa.producto_id,pa.area_id,a.codigo,a.nombre,pa.seccion_id,s.codigo,s.nombre,pa.stock_min,pa.stock_max,
 pa.es_principal,pa.estado,u.id,coalesce(sum(e.cantidad),0)::numeric
 from public.producto_area_asignacion pa join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza'
 join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza' left join public.area_secciones s on s.id=pa.seccion_id
 left join stock_internal.existencias e on e.ubicacion_id=u.id and e.sede='plaza' and e.producto_id=pa.producto_id
 where pa.sede='plaza' and pa.producto_id=p_producto_id and pa.estado='asignado'
 group by pa.id,pa.producto_id,pa.area_id,a.codigo,a.nombre,pa.seccion_id,s.codigo,s.nombre,pa.stock_min,pa.stock_max,pa.es_principal,pa.estado,u.id,a.orden,s.orden
 order by pa.es_principal desc,a.orden,a.nombre,s.orden,s.nombre;
end $function$;

create function stock_internal.leer_existencias_areas_plaza()
returns table(area_id uuid,area_codigo text,area_nombre text,area_orden integer,ubicacion_id uuid,configuracion_id uuid,configurado boolean,es_principal boolean,
 seccion_id uuid,seccion_codigo text,seccion_nombre text,seccion_orden integer,producto_id bigint,producto text,rubro text,tipo text,unidad text,stock_min numeric,stock_max numeric,cantidad numeric)
language plpgsql stable security definer set search_path='' as $function$
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'role','')<>'authenticated' then raise exception 'Se requiere una sesión autenticada.' using errcode='28000';end if;
 return query with ups as(
  select u.id ubicacion_id,u.area_id,u.codigo,u.nombre,case when u.codigo='sin_asignar' then 2147483647 else a.orden end orden
  from stock_internal.ubicaciones u left join public.areas_operativas a on a.id=u.area_id and a.sede='plaza' and a.estado='activa'
  where u.sede='plaza' and u.activa and ((u.codigo='sin_asignar' and u.area_id is null) or (u.area_id is not null and a.id is not null))
 ),saldos as(select e.producto_id,e.ubicacion_id,sum(e.cantidad)::numeric cantidad from stock_internal.existencias e where e.sede='plaza' group by e.producto_id,e.ubicacion_id),
 configuradas as(
  select a.id,a.codigo,a.nombre,a.orden,u.ubicacion_id,pa.id,true,pa.es_principal,s.id,s.codigo,s.nombre,s.orden,p.id,p.producto,p.rubro,p.tipo,p.unidad,pa.stock_min,pa.stock_max,coalesce(sa.cantidad,0)::numeric
  from public.producto_area_asignacion pa join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza' and a.estado='activa' join ups u on u.area_id=a.id
  join public.productos p on p.id=pa.producto_id and p.sede='plaza' left join public.area_secciones s on s.id=pa.seccion_id and s.estado='activa'
  left join saldos sa on sa.producto_id=p.id and sa.ubicacion_id=u.ubicacion_id where pa.sede='plaza' and pa.estado='asignado' and (p.activo='SÍ' or coalesce(sa.cantidad,0)<>0)
 ),fisicas as(
  select u.area_id,u.codigo,u.nombre,u.orden,u.ubicacion_id,null::uuid,false,false,null::uuid,null::text,null::text,null::integer,p.id,p.producto,p.rubro,p.tipo,p.unidad,null::numeric,null::numeric,sa.cantidad
  from saldos sa join ups u on u.ubicacion_id=sa.ubicacion_id join public.productos p on p.id=sa.producto_id and p.sede='plaza'
  where sa.cantidad<>0 and not exists(select 1 from public.producto_area_asignacion pa where pa.sede='plaza' and pa.producto_id=p.id and pa.area_id=u.area_id and pa.estado='asignado'))
 select * from configuradas union all select * from fisicas order by area_orden,area_nombre,seccion_orden nulls last,seccion_nombre nulls last,producto,producto_id;
end $function$;

create function public.stock_leer_areas() returns table(area_id uuid,area_codigo text,area_nombre text,area_orden integer,ubicacion_id uuid,configuracion_id uuid,configurado boolean,es_principal boolean,
 seccion_id uuid,seccion_codigo text,seccion_nombre text,seccion_orden integer,producto_id bigint,producto text,rubro text,tipo text,unidad text,stock_min numeric,stock_max numeric,cantidad numeric)
language sql stable set search_path='' as $function$ select * from stock_internal.leer_existencias_areas_plaza() $function$;

revoke all on function public.area_secciones_listar(uuid,boolean),public.producto_area_configuraciones_listar(bigint,text),stock_internal.leer_existencias_areas_plaza(),public.stock_leer_areas() from public,anon,authenticated,service_role;
grant execute on function public.area_secciones_listar(uuid,boolean),public.producto_area_configuraciones_listar(bigint,text),stock_internal.leer_existencias_areas_plaza(),public.stock_leer_areas() to authenticated;
commit;
