begin;

-- La copia es estructural y permite reconstruir exactamente los bloques
-- históricos sin conservar AM/PM como parte del contrato operativo.
create table if not exists stock_internal.turnos_secciones_respaldo_20261023 as
select 'area_secciones'::text fuente,id::text clave,turno,now() respaldado_at
from public.area_secciones
union all
select 'secciones',sede||':'||nombre,turno,now() from public.secciones;
revoke all on stock_internal.turnos_secciones_respaldo_20261023 from public,anon,authenticated,service_role;

-- Firma nueva sin turno. La firma anterior se retira al final, cuando ya no
-- queda ningún consumidor web de AM/PM.
create or replace function public.area_seccion_crear(
  p_area_id uuid,p_nombre text,p_orden integer default 100,p_codigo text default null
) returns uuid language plpgsql security definer set search_path=''
as $function$
declare v_actor uuid;v_id uuid;v_nombre text;v_codigo text;
begin
  v_actor:=authz_internal.exigir_capacidad_b3_2a('editar');
  v_nombre:=btrim(regexp_replace(coalesce(p_nombre,''),'[[:space:]]+',' ','g'));
  if length(v_nombre) not between 1 and 80 then raise exception 'El nombre de la sección es obligatorio.' using errcode='22023';end if;
  if not exists(select 1 from public.areas_operativas a where a.id=p_area_id and a.sede='plaza' and a.estado='activa') then
    raise exception 'El área no existe o está archivada.' using errcode='22023';end if;
  v_codigo:=coalesce(nullif(btrim(p_codigo),''),'sec_'||substr(md5(gen_random_uuid()::text),1,12));
  insert into public.area_secciones(area_id,codigo,nombre,orden,turno,estado,creado_por,actualizado_por)
  values(p_area_id,v_codigo,v_nombre,greatest(coalesce(p_orden,100),0),'pm','activa',v_actor,v_actor)
  returning id into v_id;
  return v_id;
end $function$;

create table if not exists stock_internal.producto_area_ficha_operaciones(
  referencia uuid primary key,actor uuid not null references auth.users(id),solicitud jsonb not null,
  resultado jsonb not null,creado_at timestamptz not null default now()
);
alter table stock_internal.producto_area_ficha_operaciones enable row level security;
alter table stock_internal.producto_area_ficha_operaciones force row level security;
revoke all on stock_internal.producto_area_ficha_operaciones from public,anon,authenticated,service_role;

create or replace function public.producto_area_ficha_guardar(
 p_referencia uuid,p_producto_id bigint,p_area_id uuid,p_seccion_id uuid,
 p_stock_min numeric,p_stock_max numeric,p_es_principal boolean,p_conteos jsonb default null,
 p_motivo text default 'Conteo/corrección manual desde ficha'
) returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_actor uuid;v_sol jsonb;v_prev stock_internal.producto_area_ficha_operaciones;
 v_config uuid;v_ubicacion uuid;v_ajuste jsonb;v_result jsonb;
begin
 v_actor:=authz_internal.exigir_capacidad_b3_2a('editar');
 if p_referencia is null or p_seccion_id is null then raise exception 'La referencia y la sección física son obligatorias.' using errcode='22023';end if;
 if p_stock_min<0 or p_stock_max<0 or (p_stock_min is not null and p_stock_max is not null and p_stock_max<p_stock_min) then
  raise exception 'Revisa el mínimo y máximo.' using errcode='22023';end if;
 select u.id into v_ubicacion from public.areas_operativas a join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza' and u.activa
 where a.id=p_area_id and a.sede='plaza' and a.estado='activa';
 if not found then raise exception 'El área no existe o está archivada.' using errcode='22023';end if;
 if not exists(select 1 from public.area_secciones s where s.id=p_seccion_id and s.area_id=p_area_id and s.estado='activa') then
  raise exception 'La sección no pertenece al área o está archivada.' using errcode='22023';end if;
 v_sol:=jsonb_build_object('producto',p_producto_id,'area',p_area_id,'seccion',p_seccion_id,'min',p_stock_min,'max',p_stock_max,'principal',coalesce(p_es_principal,false),'conteos',p_conteos,'motivo',p_motivo);
 perform pg_advisory_xact_lock(hashtextextended('ficha-area:'||p_referencia,0));
 select * into v_prev from stock_internal.producto_area_ficha_operaciones where referencia=p_referencia;
 if found then
  if v_prev.actor<>v_actor or v_prev.solicitud<>v_sol then raise exception 'La referencia ya fue usada con otro contenido.' using errcode='23505';end if;
  return v_prev.resultado;
 end if;
 v_config:=stock_internal.guardar_configuracion_producto(p_producto_id,p_area_id,p_seccion_id,p_stock_min,p_stock_max,coalesce(p_es_principal,false),v_actor);
 if p_conteos is not null then
  v_ajuste:=public.stock_ajuste_guardar(p_referencia,p_producto_id,v_ubicacion,p_conteos,coalesce(nullif(btrim(p_motivo),''),'Conteo/corrección manual desde ficha'));
 end if;
 v_result:=jsonb_build_object('configuracion_id',v_config,'ajuste',v_ajuste,'repetido',false);
 insert into stock_internal.producto_area_ficha_operaciones values(p_referencia,v_actor,v_sol,v_result,now());
 return v_result;
end $function$;

alter table stock_internal.repartos_area_items
 add column if not exists configuracion_id uuid references public.producto_area_asignacion(id) on delete restrict,
 add column if not exists seccion_destino_id uuid references public.area_secciones(id) on delete restrict,
 add column if not exists seccion_destino_nombre text;

create or replace function stock_internal.validar_ruta_reparto_item() returns trigger
language plpgsql security definer set search_path='' as $function$
declare v_area uuid;v_config public.producto_area_asignacion;v_nombre text;
begin
 select r.area_id into v_area from stock_internal.repartos_area r where r.id=new.reparto_id;
 select pa.* into v_config from public.producto_area_asignacion pa join public.area_secciones s on s.id=pa.seccion_id and s.estado='activa'
 where pa.producto_id=new.producto_plaza_id and pa.area_id=v_area and pa.sede='plaza' and pa.estado='asignado' and pa.archivado_at is null;
 if not found then raise exception 'Configura una sección física activa para este producto y área antes de repartir.' using errcode='23514';end if;
 select nombre into v_nombre from public.area_secciones where id=v_config.seccion_id;
 new.configuracion_id:=v_config.id;new.seccion_destino_id:=v_config.seccion_id;new.seccion_destino_nombre:=v_nombre;
 return new;
end $function$;
drop trigger if exists trg_reparto_item_ruta on stock_internal.repartos_area_items;
create trigger trg_reparto_item_ruta before insert on stock_internal.repartos_area_items
for each row execute function stock_internal.validar_ruta_reparto_item();

create or replace function stock_internal.bloquear_archivo_seccion_reparto() returns trigger
language plpgsql security definer set search_path='' as $function$
begin
 if old.estado='activa' and new.estado='archivada' and exists(
  select 1 from stock_internal.repartos_area_items i join stock_internal.repartos_area r on r.id=i.reparto_id
  where i.seccion_destino_id=old.id and r.estado='enviado') then
  raise exception 'La sección tiene repartos abiertos por recibir.' using errcode='23514';
 end if;return new;
end $function$;
drop trigger if exists trg_area_seccion_reparto_abierto on public.area_secciones;
create trigger trg_area_seccion_reparto_abierto before update of estado on public.area_secciones
for each row execute function stock_internal.bloquear_archivo_seccion_reparto();

create or replace function public.reparto_area_rutas_listar(p_area_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $function$
begin
 perform authz_internal.exigir_capacidad_b3_2a('lectura');
 return jsonb_build_object(
  'configuraciones',coalesce((select jsonb_agg(jsonb_build_object(
   'producto_id',pa.producto_id,'configuracion_id',pa.id,'seccion_id',s.id,'seccion',s.nombre))
   from public.producto_area_asignacion pa join public.area_secciones s on s.id=pa.seccion_id and s.estado='activa'
   where pa.area_id=p_area_id and pa.sede='plaza' and pa.estado='asignado' and pa.archivado_at is null),'[]'::jsonb),
  'lineas',coalesce((select jsonb_agg(jsonb_build_object('item_id',i.id,'seccion_id',i.seccion_destino_id,'seccion',i.seccion_destino_nombre))
   from stock_internal.repartos_area_items i join stock_internal.repartos_area r on r.id=i.reparto_id where r.area_id=p_area_id),'[]'::jsonb)
 );
end $function$;

create or replace function public.panel_ingredientes_pendientes_listar(p_consulta text default '')
returns jsonb language plpgsql stable security definer set search_path='' as $function$
begin
 perform authz_internal.exigir_capacidad_b3_2a('lectura');
 return jsonb_build_object('pendientes',coalesce((select jsonb_agg(to_jsonb(x) order by x.producto,x.area) from (
  select p.id producto_id,p.producto,a.id area_id,a.nombre area,sum(e.cantidad) saldo,
   case when pa.id is null then 'Falta configurar el producto en el área y elegir sección'
        when pa.seccion_id is null then 'Falta elegir una sección física'
        else 'La sección está archivada o inactiva' end motivo
  from stock_internal.existencias e join stock_internal.ubicaciones u on u.id=e.ubicacion_id and u.sede='plaza' and u.activa
  join public.areas_operativas a on a.id=u.area_id and a.estado='activa'
  join public.productos p on p.id=e.producto_id and p.sede='plaza' and p.activo='SÍ'
  left join public.producto_area_asignacion pa on pa.producto_id=p.id and pa.area_id=a.id and pa.estado='asignado' and pa.archivado_at is null
  left join public.area_secciones s on s.id=pa.seccion_id and s.estado='activa'
  where e.cantidad>0 and s.id is null and catalogo_internal.nombre_clave(p.producto) like '%'||catalogo_internal.nombre_clave(coalesce(p_consulta,''))||'%'
  group by p.id,p.producto,a.id,a.nombre,pa.id,pa.seccion_id limit 300
 ) x),'[]'::jsonb));
end $function$;

revoke all on function public.area_seccion_crear(uuid,text,integer,text) from public,anon,authenticated,service_role;
grant execute on function public.area_seccion_crear(uuid,text,integer,text) to authenticated;
revoke all on function public.producto_area_ficha_guardar(uuid,bigint,uuid,uuid,numeric,numeric,boolean,jsonb,text) from public,anon,authenticated,service_role;
grant execute on function public.producto_area_ficha_guardar(uuid,bigint,uuid,uuid,numeric,numeric,boolean,jsonb,text) to authenticated;
revoke all on function public.reparto_area_rutas_listar(uuid) from public,anon,authenticated,service_role;
grant execute on function public.reparto_area_rutas_listar(uuid) to authenticated;
revoke all on function public.panel_ingredientes_pendientes_listar(text) from public,anon,authenticated,service_role;
grant execute on function public.panel_ingredientes_pendientes_listar(text) to authenticated;

-- Se conserva la copia versionada anterior; el dato AM/PM deja de ser
-- operativo. Las columnas se retiran en una migración posterior cuando se
-- hayan reemplazado todas las firmas históricas instaladas.
comment on column public.area_secciones.turno is 'DEPRECADO 2026-10-23: sin uso funcional; respaldo en stock_internal.turnos_secciones_respaldo_20261023';
comment on column public.secciones.turno is 'DEPRECADO 2026-10-23: sin uso funcional; respaldo en stock_internal.turnos_secciones_respaldo_20261023';

commit;
