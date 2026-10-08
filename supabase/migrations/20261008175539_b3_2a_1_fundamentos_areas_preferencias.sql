begin;

-- B3.2a.1: fundamentos de áreas operativas y preferencia de producto.
-- No mueve existencias ni crea lotes, movimientos, recetas o enlaces Fudo.

do $preflight$
begin
  if to_regclass('public.areas_operativas') is null
     or to_regclass('public.producto_area_asignacion') is null
     or to_regclass('stock_internal.ubicaciones') is null then
    raise exception 'B3.2a.1 abortada: faltan los cimientos de áreas o del libro de existencias.';
  end if;
  if not exists (
    select 1 from authz_internal.propietario_raiz
    where singleton and auth_uid='decc9a8d-0ab6-4306-bab5-a62bcaa40338'::uuid
  ) then
    raise exception 'B3.2a.1 abortada: la identidad raíz S1 no coincide.';
  end if;
  if exists(select 1 from public.areas_operativas where sede<>'plaza') then
    raise exception 'B3.2a.1 abortada: existen áreas fuera de plaza.';
  end if;
  if exists(
    select 1
    from public.areas_operativas a
    left join stock_internal.ubicaciones u on u.area_id=a.id
    where a.sede='plaza'
      and (u.id is null or u.sede<>'plaza' or u.codigo<>a.codigo)
  ) then
    raise exception 'B3.2a.1 abortada: un área existente no tiene una ubicación coherente.';
  end if;
end
$preflight$;

alter table public.areas_operativas
  add column nombre_normalizado text generated always as (
    translate(lower(btrim(regexp_replace(nombre, '[[:space:]]+', ' ', 'g'))),
      'áéíóúüñ', 'aeiouun')
  ) stored,
  add column creado_por uuid references auth.users(id) on delete restrict,
  add column actualizado_por uuid references auth.users(id) on delete restrict,
  add column archivado_por uuid references auth.users(id) on delete restrict,
  add column archivado_at timestamptz,
  add constraint areas_operativas_solo_plaza_ck check (sede='plaza'),
  add constraint areas_operativas_orden_no_negativo_ck check (orden>=0),
  add constraint areas_operativas_archivo_actor_ck check (
    (estado='activa' and archivado_por is null and archivado_at is null)
    or (estado='archivada' and archivado_por is not null and archivado_at is not null)
  );

alter table public.producto_area_asignacion
  add column creado_por uuid not null references auth.users(id) on delete restrict,
  add column actualizado_por uuid not null references auth.users(id) on delete restrict,
  add constraint producto_area_asignacion_solo_plaza_ck check (sede='plaza');

alter table stock_internal.ubicaciones
  add constraint stock_ubicaciones_area_id_uk unique(area_id);

create unique index areas_operativas_sede_nombre_normalizado_uk
  on public.areas_operativas(sede,nombre_normalizado);
create index areas_operativas_creado_por_idx
  on public.areas_operativas(creado_por) where creado_por is not null;
create index areas_operativas_actualizado_por_idx
  on public.areas_operativas(actualizado_por) where actualizado_por is not null;
create index areas_operativas_archivado_por_idx
  on public.areas_operativas(archivado_por) where archivado_por is not null;
create index producto_area_creado_por_idx
  on public.producto_area_asignacion(creado_por);
create index producto_area_actualizado_por_idx
  on public.producto_area_asignacion(actualizado_por);

comment on column public.areas_operativas.nombre_normalizado is
  'Nombre comparable sin diferencias de mayúsculas, espacios repetidos ni tildes comunes.';
comment on column public.areas_operativas.creado_por is
  'Actor Auth que creó el área. NULL solo en las cuatro filas heredadas de B2.1.';
comment on table public.producto_area_asignacion is
  'Preferencia operativa por producto/sede, sin cantidad. Nunca mueve existencias.';

create or replace function public.producto_area_validar_contexto()
returns trigger
language plpgsql
set search_path=''
as $function$
declare
  v_producto_sede text;
  v_area_sede text;
  v_area_estado text;
begin
  select p.sede into v_producto_sede
  from public.productos p
  where p.id=new.producto_id;
  if not found or v_producto_sede is distinct from new.sede then
    raise check_violation using message='La sede de la asignación debe coincidir con la sede del producto';
  end if;

  if new.area_id is not null then
    select a.sede,a.estado into v_area_sede,v_area_estado
    from public.areas_operativas a
    where a.id=new.area_id;
    if not found or v_area_sede is distinct from new.sede then
      raise check_violation using message='El área y el producto deben pertenecer a la misma sede';
    end if;
    if v_area_estado<>'activa' then
      raise check_violation using message='No se puede asignar un producto a un área archivada';
    end if;
  end if;

  new.actualizado_at:=now();
  return new;
end
$function$;

create function stock_internal.validar_ubicacion_area()
returns trigger
language plpgsql
set search_path=''
as $function$
declare
  v_area public.areas_operativas%rowtype;
begin
  if new.area_id is null then
    return new;
  end if;
  select a.* into v_area from public.areas_operativas a where a.id=new.area_id;
  if not found or v_area.sede<>'plaza' or new.sede<>v_area.sede or new.codigo<>v_area.codigo then
    raise check_violation using message='La ubicación debe corresponder al código y sede de su área operativa';
  end if;
  if new.activa is distinct from (v_area.estado='activa') then
    raise check_violation using message='El estado de la ubicación debe coincidir con el estado del área';
  end if;
  return new;
end
$function$;

revoke all on function stock_internal.validar_ubicacion_area()
  from public,anon,authenticated,service_role;
create trigger stock_ubicaciones_validar_area_trg
before insert or update of sede,codigo,area_id,activa on stock_internal.ubicaciones
for each row execute function stock_internal.validar_ubicacion_area();

create function authz_internal.exigir_capacidad_b3_2a(p_capacidad text)
returns uuid
language plpgsql
stable security definer
set search_path=''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_claims jsonb:=auth.jwt();
  v_permitido boolean:=false;
begin
  if v_uid is null or coalesce(v_claims->>'role','')<>'authenticated' then
    raise exception 'Se requiere una sesión autenticada.' using errcode='42501';
  end if;
  if p_capacidad='lectura' then
    v_permitido:=true;
  elsif p_capacidad='ajustes' then
    select coalesce(p.puede_ajustes,false) into v_permitido from public.permisos_mios() p;
  elsif p_capacidad='editar' then
    select coalesce(p.puede_editar,false) into v_permitido from public.permisos_mios() p;
  else
    raise exception 'Capacidad interna desconocida.' using errcode='22023';
  end if;
  if not coalesce(v_permitido,false) then
    raise exception 'Tu cuenta no tiene la capacidad requerida para esta operación.' using errcode='42501';
  end if;
  return v_uid;
end
$function$;
revoke all on function authz_internal.exigir_capacidad_b3_2a(text)
  from public,anon,authenticated,service_role;

create function stock_internal.codigo_area_desde_nombre(p_valor text)
returns text
language plpgsql
immutable
set search_path=''
as $function$
declare v_codigo text;
begin
  v_codigo:=regexp_replace(
    regexp_replace(
      translate(lower(btrim(coalesce(p_valor,''))), 'áéíóúüñ', 'aeiouun'),
      '[^a-z0-9]+','_','g'),
    '^_+|_+$','','g');
  if v_codigo='' then
    raise exception 'El nombre o código del área no contiene caracteres válidos.' using errcode='22023';
  end if;
  if v_codigo ~ '^[0-9]' then v_codigo:='area_'||v_codigo; end if;
  return v_codigo;
end
$function$;
revoke all on function stock_internal.codigo_area_desde_nombre(text)
  from public,anon,authenticated,service_role;

create function stock_internal.guardar_preferencia_producto(
  p_producto_id bigint,
  p_area_id uuid,
  p_actor uuid
) returns uuid
language plpgsql
set search_path=''
as $function$
declare v_id uuid;
begin
  if not exists(select 1 from public.productos p where p.id=p_producto_id and p.sede='plaza') then
    raise exception 'El producto no existe en Local 1.' using errcode='22023';
  end if;
  if p_area_id is not null and not exists(
    select 1 from public.areas_operativas a
    where a.id=p_area_id and a.sede='plaza' and a.estado='activa'
  ) then
    raise exception 'El área no existe, no pertenece a Local 1 o está archivada.' using errcode='22023';
  end if;

  insert into public.producto_area_asignacion(
    sede,producto_id,area_id,estado,origen,regla,creado_por,actualizado_por
  ) values(
    'plaza',p_producto_id,p_area_id,
    case when p_area_id is null then 'sin_asignar' else 'asignado' end,
    'manual',null,p_actor,p_actor
  )
  on conflict(sede,producto_id) do update set
    area_id=excluded.area_id,
    estado=excluded.estado,
    origen='manual',
    regla=null,
    actualizado_por=p_actor,
    actualizado_at=now()
  returning id into v_id;
  return v_id;
end
$function$;
revoke all on function stock_internal.guardar_preferencia_producto(bigint,uuid,uuid)
  from public,anon,authenticated,service_role;

create function public.areas_operativas_listar(
  p_sede text default 'plaza',
  p_incluir_archivadas boolean default false
) returns table(
  id uuid,
  sede text,
  codigo text,
  nombre text,
  estado text,
  orden integer,
  ubicacion_id uuid,
  ubicacion_activa boolean,
  productos_preferidos bigint,
  productos_con_saldo bigint,
  unidades numeric
)
language plpgsql
stable security definer
set search_path=''
as $function$
begin
  if p_sede is distinct from 'plaza' then
    raise exception 'La gestión de áreas de B3.2a.1 está limitada a Local 1.' using errcode='22023';
  end if;
  perform authz_internal.exigir_capacidad_b3_2a(
    case when p_incluir_archivadas then 'ajustes' else 'lectura' end);
  return query
  select a.id,a.sede,a.codigo,a.nombre,a.estado,a.orden,u.id,u.activa,
    (select count(*) from public.producto_area_asignacion pa where pa.area_id=a.id),
    (select count(*) from stock_internal.existencias e where e.ubicacion_id=u.id and e.cantidad<>0),
    coalesce((select sum(e.cantidad) from stock_internal.existencias e where e.ubicacion_id=u.id),0)::numeric
  from public.areas_operativas a
  join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza'
  where a.sede='plaza' and (p_incluir_archivadas or a.estado='activa')
  order by a.orden,a.nombre_normalizado,a.id;
end
$function$;

create function public.area_operativa_crear(
  p_nombre text,
  p_orden integer default 0,
  p_codigo text default null,
  p_sede text default 'plaza'
) returns uuid
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_actor uuid;
  v_area uuid;
  v_codigo text;
  v_nombre text:=btrim(regexp_replace(coalesce(p_nombre,''),'[[:space:]]+',' ','g'));
begin
  v_actor:=authz_internal.exigir_capacidad_b3_2a('ajustes');
  if p_sede is distinct from 'plaza' then
    raise exception 'Solo se pueden crear áreas operativas para Local 1.' using errcode='22023';
  end if;
  if v_nombre='' or length(v_nombre)>80 then
    raise exception 'El nombre del área debe contener entre 1 y 80 caracteres.' using errcode='22023';
  end if;
  if p_orden is null or p_orden<0 then
    raise exception 'El orden del área no puede ser negativo.' using errcode='22023';
  end if;
  v_codigo:=stock_internal.codigo_area_desde_nombre(coalesce(p_codigo,v_nombre));
  if v_codigo='sin_asignar' then
    raise exception 'Sin asignar es una ubicación lógica reservada, no un área física.' using errcode='22023';
  end if;

  insert into public.areas_operativas(
    sede,codigo,nombre,estado,orden,creado_por,actualizado_por
  ) values('plaza',v_codigo,v_nombre,'activa',p_orden,v_actor,v_actor)
  returning id into v_area;

  insert into stock_internal.ubicaciones(sede,codigo,nombre,area_id,activa)
  values('plaza',v_codigo,v_nombre,v_area,true);
  return v_area;
exception when unique_violation then
  raise exception 'Ya existe un área con ese nombre o código en Local 1.' using errcode='23505';
end
$function$;

create function public.area_operativa_editar(
  p_area_id uuid,
  p_nombre text,
  p_orden integer
) returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_actor uuid;
  v_area public.areas_operativas%rowtype;
  v_nombre text:=btrim(regexp_replace(coalesce(p_nombre,''),'[[:space:]]+',' ','g'));
begin
  v_actor:=authz_internal.exigir_capacidad_b3_2a('ajustes');
  select a.* into v_area from public.areas_operativas a
  where a.id=p_area_id and a.sede='plaza' for update;
  if not found then raise exception 'El área no existe en Local 1.' using errcode='22023'; end if;
  if v_area.estado<>'activa' then raise exception 'No se puede editar un área archivada.' using errcode='22023'; end if;
  if v_nombre='' or length(v_nombre)>80 or p_orden is null or p_orden<0 then
    raise exception 'Nombre u orden de área inválido.' using errcode='22023';
  end if;
  update public.areas_operativas
  set nombre=v_nombre,orden=p_orden,actualizado_por=v_actor
  where id=p_area_id;
  update stock_internal.ubicaciones set nombre=v_nombre
  where area_id=p_area_id and sede='plaza';
  return jsonb_build_object('id',p_area_id,'nombre',v_nombre,'orden',p_orden);
exception when unique_violation then
  raise exception 'Ya existe un área con ese nombre en Local 1.' using errcode='23505';
end
$function$;

create function public.area_operativa_archivar(
  p_area_id uuid,
  p_reasignar_sin_asignar boolean default false
) returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_actor uuid;
  v_area public.areas_operativas%rowtype;
  v_ubicacion uuid;
  v_preferencias bigint;
begin
  v_actor:=authz_internal.exigir_capacidad_b3_2a('ajustes');
  select a.* into v_area from public.areas_operativas a
  where a.id=p_area_id and a.sede='plaza' for update;
  if not found then raise exception 'El área no existe en Local 1.' using errcode='22023'; end if;
  if v_area.estado='archivada' then
    return jsonb_build_object('id',p_area_id,'estado','archivada','reasignadas',0);
  end if;
  select u.id into v_ubicacion from stock_internal.ubicaciones u
  where u.area_id=p_area_id and u.sede='plaza' for update;
  if v_ubicacion is null then raise exception 'El área no tiene una ubicación de ledger vinculada.'; end if;
  if exists(select 1 from stock_internal.existencias e where e.ubicacion_id=v_ubicacion and e.cantidad<>0) then
    raise exception 'No se puede archivar un área con existencias. Transfiere primero todo su saldo.' using errcode='23514';
  end if;
  select count(*) into v_preferencias from public.producto_area_asignacion pa where pa.area_id=p_area_id;
  if v_preferencias>0 and not coalesce(p_reasignar_sin_asignar,false) then
    raise exception 'El área tiene productos preferidos. Confirma su reasignación a Sin asignar.' using errcode='23514';
  end if;
  if v_preferencias>0 then
    update public.producto_area_asignacion
    set area_id=null,estado='sin_asignar',origen='manual',regla=null,
        actualizado_por=v_actor,actualizado_at=now()
    where area_id=p_area_id;
  end if;
  update public.areas_operativas
  set estado='archivada',archivado_por=v_actor,archivado_at=now(),actualizado_por=v_actor
  where id=p_area_id;
  update stock_internal.ubicaciones set activa=false where id=v_ubicacion;
  return jsonb_build_object('id',p_area_id,'estado','archivada','reasignadas',v_preferencias);
end
$function$;

create function public.producto_area_preferencia_guardar(
  p_producto_id bigint,
  p_area_id uuid default null,
  p_sede text default 'plaza'
) returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare v_actor uuid; v_id uuid;
begin
  v_actor:=authz_internal.exigir_capacidad_b3_2a('editar');
  if p_sede is distinct from 'plaza' then
    raise exception 'Las preferencias de B3.2a.1 están limitadas a Local 1.' using errcode='22023';
  end if;
  v_id:=stock_internal.guardar_preferencia_producto(p_producto_id,p_area_id,v_actor);
  return jsonb_build_object('id',v_id,'producto_id',p_producto_id,'area_id',p_area_id,
    'estado',case when p_area_id is null then 'sin_asignar' else 'asignado' end);
end
$function$;

create function public.producto_plaza_crear(
  p_nombre text,
  p_rubro text,
  p_stock_min double precision default 0,
  p_stock_max double precision default 0,
  p_perecedero boolean default false,
  p_tipo text default null,
  p_unidad text default null,
  p_area_id uuid default null,
  p_notas text default null,
  p_sede text default 'plaza'
) returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_actor uuid;
  v_producto_id bigint;
  v_asignacion_id uuid;
  v_nombre text:=btrim(regexp_replace(coalesce(p_nombre,''),'[[:space:]]+',' ','g'));
  v_rubro text:=btrim(regexp_replace(coalesce(p_rubro,''),'[[:space:]]+',' ','g'));
begin
  v_actor:=authz_internal.exigir_capacidad_b3_2a('editar');
  if p_sede is distinct from 'plaza' then
    raise exception 'Esta operación solo crea productos en Local 1.' using errcode='22023';
  end if;
  if v_nombre='' or v_rubro='' then
    raise exception 'Nombre y rubro son obligatorios.' using errcode='22023';
  end if;
  if coalesce(p_stock_min,0)<0 or coalesce(p_stock_max,0)<0
     or coalesce(p_stock_max,0)<coalesce(p_stock_min,0) then
    raise exception 'Los mínimos y máximos del producto son inválidos.' using errcode='22023';
  end if;
  if p_area_id is not null and not exists(
    select 1 from public.areas_operativas a
    where a.id=p_area_id and a.sede='plaza' and a.estado='activa'
  ) then
    raise exception 'El área inicial no existe o está archivada.' using errcode='22023';
  end if;

  insert into public.productos(
    producto,rubro,stock_actual,stock_min,stock_max,activo,origen,notas,
    sede,perecedero,urgente,tipo,unidad
  ) values(
    v_nombre,v_rubro,0,coalesce(p_stock_min,0),coalesce(p_stock_max,0),'SÍ',
    'b3_2a_rpc',nullif(btrim(coalesce(p_notas,'')),''),'plaza',coalesce(p_perecedero,false),false,
    nullif(btrim(coalesce(p_tipo,'')),''),nullif(btrim(coalesce(p_unidad,'')),'')
  ) returning id into v_producto_id;

  v_asignacion_id:=stock_internal.guardar_preferencia_producto(v_producto_id,p_area_id,v_actor);
  return jsonb_build_object('producto_id',v_producto_id,'asignacion_id',v_asignacion_id,
    'area_id',p_area_id,'stock_actual',0,'sede','plaza');
end
$function$;

revoke all on function public.areas_operativas_listar(text,boolean) from public,anon,authenticated,service_role;
revoke all on function public.area_operativa_crear(text,integer,text,text) from public,anon,authenticated,service_role;
revoke all on function public.area_operativa_editar(uuid,text,integer) from public,anon,authenticated,service_role;
revoke all on function public.area_operativa_archivar(uuid,boolean) from public,anon,authenticated,service_role;
revoke all on function public.producto_area_preferencia_guardar(bigint,uuid,text) from public,anon,authenticated,service_role;
revoke all on function public.producto_plaza_crear(text,text,double precision,double precision,boolean,text,text,uuid,text,text)
  from public,anon,authenticated,service_role;

grant execute on function public.areas_operativas_listar(text,boolean) to authenticated;
grant execute on function public.area_operativa_crear(text,integer,text,text) to authenticated;
grant execute on function public.area_operativa_editar(uuid,text,integer) to authenticated;
grant execute on function public.area_operativa_archivar(uuid,boolean) to authenticated;
grant execute on function public.producto_area_preferencia_guardar(bigint,uuid,text) to authenticated;
grant execute on function public.producto_plaza_crear(text,text,double precision,double precision,boolean,text,text,uuid,text,text)
  to authenticated;

-- Las tablas continúan cerradas; la única escritura de cliente es por RPC.
alter table public.areas_operativas enable row level security;
alter table public.producto_area_asignacion enable row level security;
revoke all on table public.areas_operativas from public,anon,authenticated,service_role;
revoke all on table public.producto_area_asignacion from public,anon,authenticated,service_role;
revoke all on table stock_internal.ubicaciones from public,anon,authenticated,service_role;

commit;
