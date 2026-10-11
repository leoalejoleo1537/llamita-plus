begin;

-- Bloque 1A: configuración operativa Producto -> Área -> Sección -> mínimo/máximo.
-- Las cantidades continúan exclusivamente en stock_internal.existencias.

do $preflight$
begin
  if to_regclass('public.areas_operativas') is null
     or to_regclass('public.producto_area_asignacion') is null
     or to_regclass('stock_internal.ubicaciones') is null
     or to_regclass('stock_internal.movimientos') is null then
    raise exception 'Bloque 1A abortado: faltan los cimientos del inventario por ubicación.';
  end if;
  if to_regclass('public.area_secciones') is not null then
    raise exception 'Bloque 1A abortado: public.area_secciones ya existe; revisar colisión antes de continuar.';
  end if;
  if exists(select 1 from public.areas_operativas where sede<>'plaza') then
    raise exception 'Bloque 1A abortado: existen áreas operativas fuera de Local 1.';
  end if;
  if exists(
    select 1
    from public.areas_operativas a
    left join stock_internal.ubicaciones u on u.area_id=a.id
    where a.sede='plaza'
      and (u.id is null or u.sede<>'plaza' or u.codigo<>a.codigo)
  ) then
    raise exception 'Bloque 1A abortado: hay un área sin ubicación de ledger coherente.';
  end if;
end
$preflight$;

create table public.area_secciones(
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null references public.areas_operativas(id) on update restrict on delete restrict,
  codigo text not null check(codigo ~ '^[a-z][a-z0-9_]*$'),
  nombre text not null check(length(btrim(nombre)) between 1 and 80),
  nombre_normalizado text generated always as (
    translate(lower(btrim(regexp_replace(nombre,'[[:space:]]+',' ','g'))),
      'áéíóúüñ','aeiouun')
  ) stored,
  turno text not null default 'pm' check(turno in ('am','pm')),
  orden integer not null default 100 check(orden>=0),
  estado text not null default 'activa' check(estado in ('activa','archivada')),
  creado_at timestamptz not null default now(),
  actualizado_at timestamptz not null default now(),
  archivado_at timestamptz,
  creado_por uuid not null references auth.users(id) on delete restrict,
  actualizado_por uuid not null references auth.users(id) on delete restrict,
  archivado_por uuid references auth.users(id) on delete restrict,
  constraint area_secciones_archivo_actor_ck check(
    (estado='activa' and archivado_at is null and archivado_por is null)
    or (estado='archivada' and archivado_at is not null and archivado_por is not null)
  ),
  constraint area_secciones_id_area_uk unique(id,area_id),
  constraint area_secciones_area_codigo_uk unique(area_id,codigo),
  constraint area_secciones_area_nombre_uk unique(area_id,nombre_normalizado)
);

comment on table public.area_secciones is
  'Catálogo físico secundario dentro de un área de Local 1. No almacena cantidades, lotes ni movimientos.';
comment on column public.area_secciones.turno is
  'Organización visual AM/PM; no modifica saldos ni crea ubicaciones de ledger.';

create index area_secciones_area_estado_orden_idx
  on public.area_secciones(area_id,estado,orden,nombre_normalizado);
create index area_secciones_creado_por_idx on public.area_secciones(creado_por);
create index area_secciones_actualizado_por_idx on public.area_secciones(actualizado_por);
create index area_secciones_archivado_por_idx
  on public.area_secciones(archivado_por) where archivado_por is not null;

alter table public.producto_area_asignacion
  add column seccion_id uuid,
  add column stock_min numeric,
  add column stock_max numeric,
  add column es_principal boolean not null default false,
  add column archivado_at timestamptz,
  add column archivado_por uuid references auth.users(id) on delete restrict;

alter table public.producto_area_asignacion
  drop constraint producto_area_asignacion_estado_check,
  drop constraint producto_area_estado_area_ck,
  add constraint producto_area_asignacion_estado_check
    check(estado in ('asignado','sin_asignar','archivada')),
  add constraint producto_area_minimo_ck check(stock_min is null or stock_min>=0),
  add constraint producto_area_maximo_ck check(stock_max is null or stock_max>=0),
  add constraint producto_area_rango_ck
    check(stock_min is null or stock_max is null or stock_max>=stock_min),
  add constraint producto_area_estado_area_ck check(
    (estado='sin_asignar' and area_id is null and seccion_id is null
      and not es_principal and archivado_at is null and archivado_por is null)
    or
    (estado='asignado' and area_id is not null
      and archivado_at is null and archivado_por is null)
    or
    (estado='archivada' and area_id is not null and not es_principal
      and archivado_at is not null and archivado_por is not null)
  ),
  add constraint producto_area_seccion_area_fk
    foreign key(seccion_id,area_id)
    references public.area_secciones(id,area_id)
    on update restrict on delete restrict;

drop index public.producto_area_producto_sede_uk;
create unique index producto_area_producto_area_uk
  on public.producto_area_asignacion(sede,producto_id,area_id) nulls not distinct;
create unique index producto_area_principal_uk
  on public.producto_area_asignacion(sede,producto_id)
  where estado='asignado' and es_principal;
create index producto_area_seccion_idx
  on public.producto_area_asignacion(seccion_id) where seccion_id is not null;
create index producto_area_activa_area_idx
  on public.producto_area_asignacion(area_id,producto_id)
  where estado='asignado';
create index producto_area_archivado_por_idx
  on public.producto_area_asignacion(archivado_por) where archivado_por is not null;

-- La preferencia que ya existía conserva su significado como principal.
update public.producto_area_asignacion
set es_principal=true
where estado='asignado';

comment on table public.producto_area_asignacion is
  'Configuración operativa producto-área: sección, mínimo/máximo y principal. No almacena cantidad; el saldo vive solo en el ledger.';
comment on column public.producto_area_asignacion.seccion_id is
  'Sección física secundaria del área. NULL significa Sin sección; nunca representa una ubicación contable.';
comment on column public.producto_area_asignacion.stock_min is
  'Mínimo del producto dentro de esta área; no altera el mínimo legado del producto maestro.';
comment on column public.producto_area_asignacion.stock_max is
  'Máximo del producto dentro de esta área; no altera el máximo legado del producto maestro.';

create or replace function stock_internal.codigo_seccion_desde_nombre(p_valor text)
returns text
language plpgsql
immutable
set search_path=''
as $function$
declare v_codigo text;
begin
  v_codigo:=regexp_replace(
    regexp_replace(
      translate(lower(btrim(coalesce(p_valor,''))),'áéíóúüñ','aeiouun'),
      '[^a-z0-9]+','_','g'),
    '^_+|_+$','','g');
  if v_codigo='' then
    raise exception 'El nombre o código de la sección no contiene caracteres válidos.' using errcode='22023';
  end if;
  if v_codigo ~ '^[0-9]' then v_codigo:='seccion_'||v_codigo; end if;
  return v_codigo;
end
$function$;
revoke all on function stock_internal.codigo_seccion_desde_nombre(text)
  from public,anon,authenticated,service_role;

create function public.area_seccion_validar_contexto()
returns trigger
language plpgsql
set search_path=''
as $function$
declare v_area public.areas_operativas%rowtype;
begin
  select a.* into v_area
  from public.areas_operativas a
  where a.id=new.area_id;
  if not found or v_area.sede<>'plaza' then
    raise check_violation using message='La sección debe pertenecer a un área de Local 1';
  end if;
  if new.estado='activa' and v_area.estado<>'activa' then
    raise check_violation using message='No se puede activar una sección dentro de un área archivada';
  end if;
  new.nombre:=btrim(regexp_replace(new.nombre,'[[:space:]]+',' ','g'));
  new.actualizado_at:=now();
  return new;
end
$function$;
revoke all on function public.area_seccion_validar_contexto()
  from public,anon,authenticated,service_role;
create trigger area_secciones_validar_contexto_trg
before insert or update on public.area_secciones
for each row execute function public.area_seccion_validar_contexto();

create or replace function public.producto_area_validar_contexto()
returns trigger
language plpgsql
set search_path=''
as $function$
declare
  v_producto_sede text;
  v_area_sede text;
  v_area_estado text;
  v_seccion_estado text;
  v_seccion_area uuid;
begin
  select p.sede into v_producto_sede
  from public.productos p
  where p.id=new.producto_id;
  if not found or v_producto_sede is distinct from new.sede then
    raise check_violation using message='La sede de la configuración debe coincidir con la sede del producto';
  end if;

  if new.area_id is not null then
    select a.sede,a.estado into v_area_sede,v_area_estado
    from public.areas_operativas a
    where a.id=new.area_id;
    if not found or v_area_sede is distinct from new.sede then
      raise check_violation using message='El área y el producto deben pertenecer a la misma sede';
    end if;
    if new.estado='asignado' and v_area_estado<>'activa' then
      raise check_violation using message='No se puede configurar un producto en un área archivada';
    end if;
  end if;

  if new.seccion_id is not null then
    select s.area_id,s.estado into v_seccion_area,v_seccion_estado
    from public.area_secciones s
    where s.id=new.seccion_id;
    if not found or v_seccion_area is distinct from new.area_id then
      raise check_violation using message='La sección debe pertenecer al área configurada';
    end if;
    if v_seccion_estado<>'activa' then
      raise check_violation using message='No se puede configurar un producto en una sección archivada';
    end if;
  end if;

  new.actualizado_at:=now();
  return new;
end
$function$;

create function stock_internal.guardar_configuracion_producto(
  p_producto_id bigint,
  p_area_id uuid,
  p_seccion_id uuid,
  p_stock_min numeric,
  p_stock_max numeric,
  p_es_principal boolean,
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
  if p_area_id is null or not exists(
    select 1 from public.areas_operativas a
    where a.id=p_area_id and a.sede='plaza' and a.estado='activa'
  ) then
    raise exception 'El área no existe, no pertenece a Local 1 o está archivada.' using errcode='22023';
  end if;
  if p_seccion_id is not null and not exists(
    select 1 from public.area_secciones s
    where s.id=p_seccion_id and s.area_id=p_area_id and s.estado='activa'
  ) then
    raise exception 'La sección no existe, está archivada o pertenece a otra área.' using errcode='22023';
  end if;
  if p_stock_min is not null and p_stock_min<0
     or p_stock_max is not null and p_stock_max<0
     or p_stock_min is not null and p_stock_max is not null and p_stock_max<p_stock_min then
    raise exception 'El mínimo y máximo del área no son válidos.' using errcode='22023';
  end if;

  select pa.id into v_id
  from public.producto_area_asignacion pa
  where pa.sede='plaza' and pa.producto_id=p_producto_id and pa.area_id=p_area_id
  for update;

  if v_id is null then
    select pa.id into v_id
    from public.producto_area_asignacion pa
    where pa.sede='plaza' and pa.producto_id=p_producto_id
      and pa.area_id is null and pa.estado='sin_asignar'
    for update;
  end if;

  if coalesce(p_es_principal,false) then
    update public.producto_area_asignacion
    set es_principal=false,actualizado_por=p_actor,actualizado_at=now()
    where sede='plaza' and producto_id=p_producto_id
      and estado='asignado' and es_principal
      and (v_id is null or id<>v_id);
  end if;

  if v_id is null then
    insert into public.producto_area_asignacion(
      sede,producto_id,area_id,seccion_id,stock_min,stock_max,es_principal,
      estado,origen,regla,creado_por,actualizado_por
    ) values(
      'plaza',p_producto_id,p_area_id,p_seccion_id,p_stock_min,p_stock_max,
      coalesce(p_es_principal,false),'asignado','manual',null,p_actor,p_actor
    ) returning id into v_id;
  else
    update public.producto_area_asignacion
    set area_id=p_area_id,seccion_id=p_seccion_id,stock_min=p_stock_min,stock_max=p_stock_max,
        es_principal=coalesce(p_es_principal,false),estado='asignado',origen='manual',regla=null,
        archivado_at=null,archivado_por=null,actualizado_por=p_actor,actualizado_at=now()
    where id=v_id;
  end if;
  return v_id;
end
$function$;
revoke all on function stock_internal.guardar_configuracion_producto(bigint,uuid,uuid,numeric,numeric,boolean,uuid)
  from public,anon,authenticated,service_role;

create or replace function stock_internal.guardar_preferencia_producto(
  p_producto_id bigint,
  p_area_id uuid,
  p_actor uuid
) returns uuid
language plpgsql
set search_path=''
as $function$
declare
  v_id uuid;
  v_actual public.producto_area_asignacion%rowtype;
begin
  if p_area_id is null then
    if not exists(select 1 from public.productos p where p.id=p_producto_id and p.sede='plaza') then
      raise exception 'El producto no existe en Local 1.' using errcode='22023';
    end if;
    update public.producto_area_asignacion
    set es_principal=false,actualizado_por=p_actor,actualizado_at=now()
    where sede='plaza' and producto_id=p_producto_id and estado='asignado' and es_principal;
    insert into public.producto_area_asignacion(
      sede,producto_id,area_id,estado,origen,regla,creado_por,actualizado_por
    ) values('plaza',p_producto_id,null,'sin_asignar','manual',null,p_actor,p_actor)
    on conflict(sede,producto_id,area_id) do update set
      estado='sin_asignar',origen='manual',regla=null,actualizado_por=p_actor,actualizado_at=now()
    returning id into v_id;
    return v_id;
  end if;

  select pa.* into v_actual
  from public.producto_area_asignacion pa
  where pa.sede='plaza' and pa.producto_id=p_producto_id
    and pa.area_id=p_area_id and pa.estado in ('asignado','archivada');

  return stock_internal.guardar_configuracion_producto(
    p_producto_id,p_area_id,v_actual.seccion_id,v_actual.stock_min,v_actual.stock_max,true,p_actor);
end
$function$;

create function public.area_secciones_listar(
  p_area_id uuid,
  p_incluir_archivadas boolean default false
) returns table(
  id uuid,area_id uuid,codigo text,nombre text,turno text,orden integer,estado text,
  productos_configurados bigint
)
language plpgsql
stable security definer
set search_path=''
as $function$
begin
  perform authz_internal.exigir_capacidad_b3_2a(
    case when p_incluir_archivadas then 'ajustes' else 'lectura' end);
  if not exists(select 1 from public.areas_operativas a where a.id=p_area_id and a.sede='plaza') then
    raise exception 'El área no existe en Local 1.' using errcode='22023';
  end if;
  return query
  select s.id,s.area_id,s.codigo,s.nombre,s.turno,s.orden,s.estado,
    (select count(*) from public.producto_area_asignacion pa
      where pa.seccion_id=s.id and pa.estado='asignado')
  from public.area_secciones s
  where s.area_id=p_area_id and (p_incluir_archivadas or s.estado='activa')
  order by case s.turno when 'am' then 0 else 1 end,s.orden,s.nombre_normalizado,s.id;
end
$function$;

create function public.area_seccion_crear(
  p_area_id uuid,
  p_nombre text,
  p_orden integer default 100,
  p_turno text default 'pm',
  p_codigo text default null
) returns uuid
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_actor uuid;
  v_id uuid;
  v_nombre text:=btrim(regexp_replace(coalesce(p_nombre,''),'[[:space:]]+',' ','g'));
  v_codigo text;
begin
  v_actor:=authz_internal.exigir_capacidad_b3_2a('ajustes');
  if not exists(select 1 from public.areas_operativas a where a.id=p_area_id and a.sede='plaza' and a.estado='activa') then
    raise exception 'La sección debe pertenecer a un área activa de Local 1.' using errcode='22023';
  end if;
  if v_nombre='' or length(v_nombre)>80 or p_orden is null or p_orden<0
     or p_turno not in ('am','pm') then
    raise exception 'Nombre, orden o bloque visual AM/PM inválido.' using errcode='22023';
  end if;
  v_codigo:=stock_internal.codigo_seccion_desde_nombre(coalesce(p_codigo,v_nombre));
  insert into public.area_secciones(
    area_id,codigo,nombre,turno,orden,estado,creado_por,actualizado_por
  ) values(p_area_id,v_codigo,v_nombre,p_turno,p_orden,'activa',v_actor,v_actor)
  returning id into v_id;
  return v_id;
exception when unique_violation then
  raise exception 'Ya existe una sección con ese nombre o código dentro del área.' using errcode='23505';
end
$function$;

create function public.area_seccion_editar(
  p_seccion_id uuid,
  p_nombre text,
  p_orden integer,
  p_turno text
) returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_actor uuid;
  v_nombre text:=btrim(regexp_replace(coalesce(p_nombre,''),'[[:space:]]+',' ','g'));
begin
  v_actor:=authz_internal.exigir_capacidad_b3_2a('ajustes');
  if not exists(
    select 1 from public.area_secciones s join public.areas_operativas a on a.id=s.area_id
    where s.id=p_seccion_id and a.sede='plaza' and s.estado='activa'
  ) then
    raise exception 'La sección no existe o está archivada.' using errcode='22023';
  end if;
  if v_nombre='' or length(v_nombre)>80 or p_orden is null or p_orden<0
     or p_turno not in ('am','pm') then
    raise exception 'Nombre, orden o bloque visual AM/PM inválido.' using errcode='22023';
  end if;
  update public.area_secciones
  set nombre=v_nombre,orden=p_orden,turno=p_turno,actualizado_por=v_actor
  where id=p_seccion_id;
  return jsonb_build_object('id',p_seccion_id,'nombre',v_nombre,'orden',p_orden,'turno',p_turno);
exception when unique_violation then
  raise exception 'Ya existe una sección con ese nombre dentro del área.' using errcode='23505';
end
$function$;

create function public.area_seccion_archivar(
  p_seccion_id uuid,
  p_desasignar_productos boolean default false
) returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_actor uuid;
  v_seccion public.area_secciones%rowtype;
  v_productos bigint;
begin
  v_actor:=authz_internal.exigir_capacidad_b3_2a('ajustes');
  select s.* into v_seccion
  from public.area_secciones s join public.areas_operativas a on a.id=s.area_id
  where s.id=p_seccion_id and a.sede='plaza' for update of s;
  if not found then raise exception 'La sección no existe en Local 1.' using errcode='22023'; end if;
  if v_seccion.estado='archivada' then
    return jsonb_build_object('id',p_seccion_id,'estado','archivada','productos_sin_seccion',0);
  end if;
  select count(*) into v_productos
  from public.producto_area_asignacion pa
  where pa.seccion_id=p_seccion_id and pa.estado='asignado';
  if v_productos>0 and not coalesce(p_desasignar_productos,false) then
    raise exception 'La sección tiene productos configurados. Confirma que quedarán Sin sección.' using errcode='23514';
  end if;
  if v_productos>0 then
    update public.producto_area_asignacion
    set seccion_id=null,actualizado_por=v_actor,actualizado_at=now()
    where seccion_id=p_seccion_id and estado='asignado';
  end if;
  update public.area_secciones
  set estado='archivada',archivado_at=now(),archivado_por=v_actor,actualizado_por=v_actor
  where id=p_seccion_id;
  return jsonb_build_object('id',p_seccion_id,'estado','archivada','productos_sin_seccion',v_productos);
end
$function$;

create function public.producto_area_configuraciones_listar(
  p_producto_id bigint,
  p_sede text default 'plaza'
) returns table(
  id uuid,producto_id bigint,area_id uuid,area_codigo text,area_nombre text,
  seccion_id uuid,seccion_codigo text,seccion_nombre text,seccion_turno text,
  stock_min numeric,stock_max numeric,es_principal boolean,estado text,
  ubicacion_id uuid,cantidad numeric
)
language plpgsql
stable security definer
set search_path=''
as $function$
begin
  perform authz_internal.exigir_capacidad_b3_2a('lectura');
  if p_sede is distinct from 'plaza' then
    raise exception 'La configuración producto-área está limitada a Local 1.' using errcode='22023';
  end if;
  if not exists(select 1 from public.productos p where p.id=p_producto_id and p.sede='plaza') then
    raise exception 'El producto no existe en Local 1.' using errcode='22023';
  end if;
  return query
  select pa.id,pa.producto_id,pa.area_id,a.codigo,a.nombre,
    pa.seccion_id,s.codigo,s.nombre,s.turno,pa.stock_min,pa.stock_max,
    pa.es_principal,pa.estado,u.id,coalesce(sum(e.cantidad),0)::numeric
  from public.producto_area_asignacion pa
  join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza'
  join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza'
  left join public.area_secciones s on s.id=pa.seccion_id
  left join stock_internal.existencias e
    on e.ubicacion_id=u.id and e.sede='plaza' and e.producto_id=pa.producto_id
  where pa.sede='plaza' and pa.producto_id=p_producto_id and pa.estado='asignado'
  group by pa.id,pa.producto_id,pa.area_id,a.codigo,a.nombre,
    pa.seccion_id,s.codigo,s.nombre,s.turno,pa.stock_min,pa.stock_max,
    pa.es_principal,pa.estado,u.id,a.orden,s.orden
  order by pa.es_principal desc,a.orden,a.nombre,s.orden,s.nombre;
end
$function$;

create function public.producto_area_configuracion_guardar(
  p_producto_id bigint,
  p_area_id uuid,
  p_seccion_id uuid default null,
  p_stock_min double precision default null,
  p_stock_max double precision default null,
  p_es_principal boolean default false,
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
    raise exception 'La configuración producto-área está limitada a Local 1.' using errcode='22023';
  end if;
  v_id:=stock_internal.guardar_configuracion_producto(
    p_producto_id,p_area_id,p_seccion_id,p_stock_min::numeric,p_stock_max::numeric,
    coalesce(p_es_principal,false),v_actor);
  return jsonb_build_object('id',v_id,'producto_id',p_producto_id,'area_id',p_area_id,
    'seccion_id',p_seccion_id,'stock_min',p_stock_min,'stock_max',p_stock_max,
    'es_principal',coalesce(p_es_principal,false),'saldo_movido',false);
end
$function$;

create function public.producto_area_configuracion_archivar(
  p_configuracion_id uuid
) returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare v_actor uuid; v_fila public.producto_area_asignacion%rowtype;
begin
  v_actor:=authz_internal.exigir_capacidad_b3_2a('editar');
  select pa.* into v_fila from public.producto_area_asignacion pa
  where pa.id=p_configuracion_id and pa.sede='plaza' for update;
  if not found or v_fila.area_id is null then
    raise exception 'La configuración no existe en Local 1.' using errcode='22023';
  end if;
  if v_fila.estado='archivada' then
    return jsonb_build_object('id',p_configuracion_id,'estado','archivada','saldo_movido',false);
  end if;
  update public.producto_area_asignacion
  set estado='archivada',es_principal=false,archivado_at=now(),archivado_por=v_actor,
      actualizado_por=v_actor,actualizado_at=now()
  where id=p_configuracion_id;
  return jsonb_build_object('id',p_configuracion_id,'estado','archivada','saldo_movido',false);
end
$function$;

create or replace function public.areas_operativas_listar(
  p_sede text default 'plaza',
  p_incluir_archivadas boolean default false
) returns table(
  id uuid,sede text,codigo text,nombre text,estado text,orden integer,
  ubicacion_id uuid,ubicacion_activa boolean,productos_preferidos bigint,
  productos_con_saldo bigint,unidades numeric
)
language plpgsql
stable security definer
set search_path=''
as $function$
begin
  if p_sede is distinct from 'plaza' then
    raise exception 'La gestión de áreas está limitada a Local 1.' using errcode='22023';
  end if;
  perform authz_internal.exigir_capacidad_b3_2a(
    case when p_incluir_archivadas then 'ajustes' else 'lectura' end);
  return query
  select a.id,a.sede,a.codigo,a.nombre,a.estado,a.orden,u.id,u.activa,
    (select count(*) from public.producto_area_asignacion pa
      where pa.area_id=a.id and pa.estado='asignado'),
    (select count(distinct e.producto_id) from stock_internal.existencias e
      where e.ubicacion_id=u.id and e.cantidad<>0),
    coalesce((select sum(e.cantidad) from stock_internal.existencias e
      where e.ubicacion_id=u.id),0)::numeric
  from public.areas_operativas a
  join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza'
  where a.sede='plaza' and (p_incluir_archivadas or a.estado='activa')
  order by a.orden,a.nombre_normalizado,a.id;
end
$function$;

create or replace function public.area_operativa_archivar(
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
  v_configuraciones bigint;
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
  select count(*) into v_configuraciones
  from public.producto_area_asignacion pa
  where pa.area_id=p_area_id and pa.estado='asignado';
  if v_configuraciones>0 and not coalesce(p_reasignar_sin_asignar,false) then
    raise exception 'El área tiene productos configurados. Confirma que sus configuraciones quedarán archivadas.' using errcode='23514';
  end if;
  if v_configuraciones>0 then
    update public.producto_area_asignacion
    set estado='archivada',es_principal=false,archivado_at=now(),archivado_por=v_actor,
        actualizado_por=v_actor,actualizado_at=now()
    where area_id=p_area_id and estado='asignado';
  end if;
  update public.area_secciones
  set estado='archivada',archivado_at=now(),archivado_por=v_actor,
      actualizado_por=v_actor,actualizado_at=now()
  where area_id=p_area_id and estado='activa';
  update public.areas_operativas
  set estado='archivada',archivado_por=v_actor,archivado_at=now(),actualizado_por=v_actor
  where id=p_area_id;
  update stock_internal.ubicaciones set activa=false where id=v_ubicacion;
  return jsonb_build_object('id',p_area_id,'estado','archivada','reasignadas',v_configuraciones);
end
$function$;

create or replace function public.producto_area_preferencia_leer(
  p_producto_id bigint,
  p_sede text default 'plaza'
) returns jsonb
language plpgsql
stable security definer
set search_path=''
as $function$
declare v_resultado jsonb;
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
        'ubicacion_id',s.ubicacion_id,'codigo',s.codigo,'nombre',s.nombre,'cantidad',s.cantidad
      ) order by s.orden,s.nombre)
      from (
        select u.id ubicacion_id,u.codigo,u.nombre,
          case when u.codigo='sin_asignar' then 2147483647 else coalesce(ao.orden,2147483646) end orden,
          sum(e.cantidad)::numeric cantidad
        from stock_internal.existencias e
        join stock_internal.ubicaciones u on u.id=e.ubicacion_id and u.sede='plaza'
        left join public.areas_operativas ao on ao.id=u.area_id
        where e.sede='plaza' and e.producto_id=p_producto_id and e.cantidad<>0
        group by u.id,u.codigo,u.nombre,ao.orden
      ) s
    ),'[]'::jsonb)
  ) into v_resultado
  from (select 1) base
  left join lateral(
    select x.* from public.producto_area_asignacion x
    where x.sede='plaza' and x.producto_id=p_producto_id and x.estado='asignado'
    order by x.es_principal desc,x.actualizado_at desc,x.id limit 1
  ) pa on true
  left join public.areas_operativas a on a.id=pa.area_id;
  return v_resultado;
end
$function$;

create or replace function public.producto_plaza_crear(
  p_nombre text,p_rubro text,p_stock_min double precision default 0,
  p_stock_max double precision default 0,p_perecedero boolean default false,
  p_tipo text default null,p_unidad text default null,p_area_id uuid default null,
  p_notas text default null,p_sede text default 'plaza'
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
    raise exception 'Nombre y categoría son obligatorios.' using errcode='22023';
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
    'bloque_1a_rpc',nullif(btrim(coalesce(p_notas,'')),''),'plaza',coalesce(p_perecedero,false),false,
    nullif(btrim(coalesce(p_tipo,'')),''),nullif(btrim(coalesce(p_unidad,'')),'')
  ) returning id into v_producto_id;
  if p_area_id is null then
    v_asignacion_id:=stock_internal.guardar_preferencia_producto(v_producto_id,null,v_actor);
  else
    v_asignacion_id:=stock_internal.guardar_configuracion_producto(
      v_producto_id,p_area_id,null,p_stock_min::numeric,p_stock_max::numeric,true,v_actor);
  end if;
  return jsonb_build_object('producto_id',v_producto_id,'asignacion_id',v_asignacion_id,
    'area_id',p_area_id,'stock_actual',0,'sede','plaza');
end
$function$;

create function public.producto_plaza_crear_configurado(
  p_nombre text,p_rubro text,p_stock_min double precision default 0,
  p_stock_max double precision default 0,p_perecedero boolean default false,
  p_tipo text default null,p_unidad text default null,p_area_id uuid default null,
  p_seccion_id uuid default null,p_notas text default null,p_sede text default 'plaza'
) returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare v_resultado jsonb; v_actor uuid; v_configuracion uuid;
begin
  v_actor:=authz_internal.exigir_capacidad_b3_2a('editar');
  if p_area_id is null and p_seccion_id is not null then
    raise exception 'Sin asignar no admite una sección física.' using errcode='22023';
  end if;
  v_resultado:=public.producto_plaza_crear(
    p_nombre,p_rubro,p_stock_min,p_stock_max,p_perecedero,p_tipo,p_unidad,
    p_area_id,p_notas,p_sede);
  if p_area_id is not null then
    v_configuracion:=stock_internal.guardar_configuracion_producto(
      (v_resultado->>'producto_id')::bigint,p_area_id,p_seccion_id,
      p_stock_min::numeric,p_stock_max::numeric,true,v_actor);
    v_resultado:=v_resultado||jsonb_build_object(
      'asignacion_id',v_configuracion,'seccion_id',p_seccion_id);
  end if;
  return v_resultado;
end
$function$;

-- La lectura deja de cruzar todos los productos con todas las áreas. Devuelve
-- configuraciones activas (aunque el saldo sea cero) y saldos físicos no configurados.
drop function public.stock_leer_areas();
drop function stock_internal.leer_existencias_areas_plaza();

create function stock_internal.leer_existencias_areas_plaza()
returns table(
  area_id uuid,area_codigo text,area_nombre text,area_orden integer,ubicacion_id uuid,
  configuracion_id uuid,configurado boolean,es_principal boolean,
  seccion_id uuid,seccion_codigo text,seccion_nombre text,seccion_turno text,seccion_orden integer,
  producto_id bigint,producto text,rubro text,tipo text,unidad text,
  stock_min numeric,stock_max numeric,cantidad numeric
)
language plpgsql
stable security definer
set search_path=''
as $function$
begin
  if auth.uid() is null or coalesce(auth.jwt()->>'role','')<>'authenticated' then
    raise exception 'Se requiere una sesión autenticada.' using errcode='28000';
  end if;
  return query
  with ubicaciones_plaza as (
    select u.id ubicacion_id,u.area_id,u.codigo,u.nombre,
      case when u.codigo='sin_asignar' then 2147483647 else a.orden end orden
    from stock_internal.ubicaciones u
    left join public.areas_operativas a
      on a.id=u.area_id and a.sede='plaza' and a.estado='activa'
    where u.sede='plaza' and u.activa
      and ((u.codigo='sin_asignar' and u.area_id is null)
        or (u.area_id is not null and a.id is not null))
  ), saldos as (
    select e.producto_id,e.ubicacion_id,sum(e.cantidad)::numeric cantidad
    from stock_internal.existencias e
    where e.sede='plaza'
    group by e.producto_id,e.ubicacion_id
  ), configuradas as (
    select a.id area_id,a.codigo area_codigo,a.nombre area_nombre,a.orden area_orden,u.ubicacion_id,
      pa.id configuracion_id,true configurado,pa.es_principal,
      s.id seccion_id,s.codigo seccion_codigo,s.nombre seccion_nombre,s.turno seccion_turno,s.orden seccion_orden,
      p.id producto_id,p.producto,p.rubro,p.tipo,p.unidad,pa.stock_min,pa.stock_max,
      coalesce(sa.cantidad,0)::numeric cantidad
    from public.producto_area_asignacion pa
    join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza' and a.estado='activa'
    join ubicaciones_plaza u on u.area_id=a.id
    join public.productos p on p.id=pa.producto_id and p.sede='plaza'
    left join public.area_secciones s on s.id=pa.seccion_id and s.estado='activa'
    left join saldos sa on sa.producto_id=p.id and sa.ubicacion_id=u.ubicacion_id
    where pa.sede='plaza' and pa.estado='asignado'
      and (p.activo='SÍ' or coalesce(sa.cantidad,0)<>0)
  ), fisicas_sin_configurar as (
    select u.area_id,u.codigo,u.nombre,u.orden,u.ubicacion_id,
      null::uuid configuracion_id,false configurado,false es_principal,
      null::uuid seccion_id,null::text seccion_codigo,null::text seccion_nombre,
      null::text seccion_turno,null::integer seccion_orden,
      p.id,p.producto,p.rubro,p.tipo,p.unidad,null::numeric stock_min,null::numeric stock_max,
      sa.cantidad
    from saldos sa
    join ubicaciones_plaza u on u.ubicacion_id=sa.ubicacion_id
    join public.productos p on p.id=sa.producto_id and p.sede='plaza'
    where sa.cantidad<>0 and not exists(
      select 1 from public.producto_area_asignacion pa
      where pa.sede='plaza' and pa.producto_id=p.id and pa.area_id=u.area_id
        and pa.estado='asignado'
    )
  )
  select * from configuradas
  union all
  select * from fisicas_sin_configurar
  order by area_orden,area_nombre,seccion_orden nulls last,seccion_nombre nulls last,producto,producto_id;
end
$function$;

create function public.stock_leer_areas()
returns table(
  area_id uuid,area_codigo text,area_nombre text,area_orden integer,ubicacion_id uuid,
  configuracion_id uuid,configurado boolean,es_principal boolean,
  seccion_id uuid,seccion_codigo text,seccion_nombre text,seccion_turno text,seccion_orden integer,
  producto_id bigint,producto text,rubro text,tipo text,unidad text,
  stock_min numeric,stock_max numeric,cantidad numeric
)
language sql
stable
set search_path=''
as $function$
  select * from stock_internal.leer_existencias_areas_plaza()
$function$;

-- Tablas cerradas: toda lectura/escritura de configuración pasa por RPC.
alter table public.area_secciones enable row level security;
revoke all on table public.area_secciones from public,anon,authenticated,service_role;
revoke all on table public.producto_area_asignacion from public,anon,authenticated,service_role;

revoke all on function public.area_secciones_listar(uuid,boolean) from public,anon,authenticated,service_role;
revoke all on function public.area_seccion_crear(uuid,text,integer,text,text) from public,anon,authenticated,service_role;
revoke all on function public.area_seccion_editar(uuid,text,integer,text) from public,anon,authenticated,service_role;
revoke all on function public.area_seccion_archivar(uuid,boolean) from public,anon,authenticated,service_role;
revoke all on function public.producto_area_configuraciones_listar(bigint,text) from public,anon,authenticated,service_role;
revoke all on function public.producto_area_configuracion_guardar(bigint,uuid,uuid,double precision,double precision,boolean,text) from public,anon,authenticated,service_role;
revoke all on function public.producto_area_configuracion_archivar(uuid) from public,anon,authenticated,service_role;
revoke all on function public.producto_plaza_crear_configurado(text,text,double precision,double precision,boolean,text,text,uuid,uuid,text,text) from public,anon,authenticated,service_role;
revoke all on function stock_internal.leer_existencias_areas_plaza() from public,anon,authenticated,service_role;
revoke all on function public.stock_leer_areas() from public,anon,authenticated,service_role;

grant execute on function public.area_secciones_listar(uuid,boolean) to authenticated;
grant execute on function public.area_seccion_crear(uuid,text,integer,text,text) to authenticated;
grant execute on function public.area_seccion_editar(uuid,text,integer,text) to authenticated;
grant execute on function public.area_seccion_archivar(uuid,boolean) to authenticated;
grant execute on function public.producto_area_configuraciones_listar(bigint,text) to authenticated;
grant execute on function public.producto_area_configuracion_guardar(bigint,uuid,uuid,double precision,double precision,boolean,text) to authenticated;
grant execute on function public.producto_area_configuracion_archivar(uuid) to authenticated;
grant execute on function public.producto_plaza_crear_configurado(text,text,double precision,double precision,boolean,text,text,uuid,uuid,text,text) to authenticated;
grant execute on function stock_internal.leer_existencias_areas_plaza() to authenticated;
grant execute on function public.stock_leer_areas() to authenticated;

comment on function public.stock_leer_areas() is
  'Lectura autenticada de Local 1: configuraciones producto-área aunque tengan cero y saldos físicos del ledger. No lee productos.stock_actual.';

commit;
