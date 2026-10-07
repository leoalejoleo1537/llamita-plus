begin;

-- S1: una identidad raíz por UUID y permisos administrados únicamente por RPC.
do $preflight$
declare
  v_raiz constant uuid := 'decc9a8d-0ab6-4306-bab5-a62bcaa40338'::uuid;
  v_operador constant uuid := '6c3f6e47-7a26-40ce-84f6-9fe26925d642'::uuid;
begin
  if to_regnamespace('authz_internal') is not null then
    raise exception 'S1 abortada: el esquema authz_internal ya existe.';
  end if;
  if exists(select 1 from information_schema.columns
    where table_schema='public' and table_name='app_permisos' and column_name='auth_uid') then
    raise exception 'S1 abortada: app_permisos.auth_uid ya existe.';
  end if;
  if (select count(*) from auth.users) <> 2 then
    raise exception 'S1 abortada: se esperaban exactamente dos cuentas Auth existentes.';
  end if;
  if not exists(select 1 from auth.users
    where id=v_raiz and confirmed_at is not null and not is_anonymous) then
    raise exception 'S1 abortada: el UUID raíz exacto no existe, no está confirmado o es anónimo.';
  end if;
  if not exists(select 1 from auth.users
    where id=v_operador and confirmed_at is not null and not is_anonymous) then
    raise exception 'S1 abortada: la segunda cuenta Auth esperada no coincide.';
  end if;
  if (select count(*) from public.app_permisos p join auth.users u
      on lower(p.correo)=lower(u.email) where u.id=v_raiz) <> 1 then
    raise exception 'S1 abortada: la cuenta raíz no coincide con una única fila heredada.';
  end if;
  if not exists(select 1 from public.app_permisos p join auth.users u
      on lower(p.correo)=lower(u.email)
      where u.id=v_operador and p.puede_editar and p.puede_fudo
        and p.puede_ajustes and not p.puede_lama
        and cardinality(p.fudo_bloqueos)=0) then
    raise exception 'S1 abortada: las capacidades de la segunda cuenta cambiaron desde el preflight.';
  end if;
end
$preflight$;

create schema authz_internal;
revoke all on schema authz_internal from public, anon, authenticated, service_role;

create table authz_internal.propietario_raiz(
  singleton boolean primary key default true check(singleton),
  auth_uid uuid not null unique references auth.users(id) on delete restrict,
  creado_at timestamptz not null default now(),
  creado_por uuid not null references auth.users(id) on delete restrict
);
alter table authz_internal.propietario_raiz enable row level security;
alter table authz_internal.propietario_raiz force row level security;

create table authz_internal.permisos_auditoria(
  id bigint generated always as identity primary key,
  actor_auth_uid uuid not null references auth.users(id) on delete restrict,
  objetivo_auth_uid uuid not null references auth.users(id) on delete restrict,
  accion text not null check(accion in ('actualizar_permisos')),
  estado_anterior jsonb,
  estado_nuevo jsonb not null,
  creado_at timestamptz not null default now()
);
alter table authz_internal.permisos_auditoria enable row level security;
alter table authz_internal.permisos_auditoria force row level security;

-- Foto privada para el rollback técnico previo a cualquier cambio posterior.
create table authz_internal.app_permisos_pre_s1 as
select * from public.app_permisos;
alter table authz_internal.app_permisos_pre_s1 enable row level security;
alter table authz_internal.app_permisos_pre_s1 force row level security;

create function authz_internal.impedir_mutacion_auditoria()
returns trigger language plpgsql set search_path=''
as $function$
begin
  raise exception 'La auditoría de permisos es inmutable.' using errcode='42501';
end
$function$;
revoke all on function authz_internal.impedir_mutacion_auditoria()
  from public, anon, authenticated, service_role;
create trigger permisos_auditoria_inmutable
before update or delete on authz_internal.permisos_auditoria
for each row execute function authz_internal.impedir_mutacion_auditoria();

revoke all on all tables in schema authz_internal
  from public, anon, authenticated, service_role;
revoke all on all sequences in schema authz_internal
  from public, anon, authenticated, service_role;

alter table public.app_permisos add column auth_uid uuid;
alter table public.app_permisos
  add constraint app_permisos_auth_uid_fkey
  foreign key(auth_uid) references auth.users(id) on delete restrict;
alter table public.app_permisos
  add constraint app_permisos_auth_uid_key unique(auth_uid);

-- Los UUID son la fuente de verdad. El correo solo localiza las dos filas
-- heredadas durante este corte y deja de participar en autorización.
do $vincular$
declare
  v_raiz constant uuid := 'decc9a8d-0ab6-4306-bab5-a62bcaa40338'::uuid;
  v_operador constant uuid := '6c3f6e47-7a26-40ce-84f6-9fe26925d642'::uuid;
  v_filas integer;
begin
  update public.app_permisos p set auth_uid=v_raiz,
      puede_editar=true, puede_fudo=true, puede_ajustes=true, puede_lama=true
  where p.correo=(select u.email from auth.users u where u.id=v_raiz);
  get diagnostics v_filas=row_count;
  if v_filas<>1 then raise exception 'S1 abortada al vincular la cuenta raíz.'; end if;

  update public.app_permisos p set auth_uid=v_operador
  where p.correo=(select u.email from auth.users u where u.id=v_operador);
  get diagnostics v_filas=row_count;
  if v_filas<>1 then raise exception 'S1 abortada al vincular la segunda cuenta.'; end if;
end
$vincular$;

-- Las filas sin usuario Auth se conservan para trazabilidad, pero no conceden
-- capacidades ni pueden heredarse al crear una cuenta futura con el mismo correo.
update public.app_permisos
set puede_editar=false, puede_fudo=false, puede_ajustes=false,
    puede_lama=false, fudo_bloqueos='{}'::text[]
where auth_uid is null;

alter table public.app_permisos alter column puede_editar set default false;
alter table public.app_permisos alter column puede_fudo set default false;
alter table public.app_permisos
  add constraint app_permisos_sin_auth_sin_capacidades check(
    auth_uid is not null or (
      not puede_editar and not puede_fudo and not puede_ajustes and not puede_lama
      and cardinality(fudo_bloqueos)=0
    )
  );

insert into authz_internal.propietario_raiz(singleton,auth_uid,creado_por)
values(true,'decc9a8d-0ab6-4306-bab5-a62bcaa40338'::uuid,
  'decc9a8d-0ab6-4306-bab5-a62bcaa40338'::uuid);

drop policy if exists "app_permisos alta" on public.app_permisos;
drop policy if exists "app_permisos cambio" on public.app_permisos;
drop policy if exists "app_permisos escribir" on public.app_permisos;
drop policy if exists "app_permisos read" on public.app_permisos;

revoke all on table public.app_permisos from public, anon, authenticated, service_role;
grant select on table public.app_permisos to authenticated, service_role;

create policy app_permisos_lectura_propia
on public.app_permisos for select to authenticated
using(auth_uid is not null and auth_uid=(select auth.uid()));

create function public.permisos_mios()
returns table(
  auth_uid uuid,
  correo text,
  nombre text,
  puede_fudo boolean,
  puede_editar boolean,
  puede_ajustes boolean,
  fudo_bloqueos text[],
  puede_lama boolean,
  es_propietario_raiz boolean
)
language plpgsql stable security definer set search_path=''
as $function$
declare
  v_uid uuid := auth.uid();
  v_es_raiz boolean;
  v_claims jsonb := auth.jwt();
begin
  if v_uid is null or coalesce(v_claims->>'role','')<>'authenticated' then
    raise exception 'Se requiere una sesión autenticada.' using errcode='42501';
  end if;
  select exists(select 1 from authz_internal.propietario_raiz r
    where r.singleton and r.auth_uid=v_uid) into v_es_raiz;
  return query
  select v_uid,
    coalesce(p.correo,v_claims->>'email')::text,
    p.nombre,
    case when v_es_raiz then true else coalesce(p.puede_fudo,false) end,
    case when v_es_raiz then true else coalesce(p.puede_editar,false) end,
    case when v_es_raiz then true else coalesce(p.puede_ajustes,false) end,
    case when v_es_raiz then '{}'::text[] else coalesce(p.fudo_bloqueos,'{}'::text[]) end,
    case when v_es_raiz then true else coalesce(p.puede_lama,false) end,
    v_es_raiz
  from (select 1) x
  left join public.app_permisos p on p.auth_uid=v_uid;
end
$function$;

create function public.permisos_listar()
returns table(
  auth_uid uuid,
  correo text,
  nombre text,
  puede_fudo boolean,
  puede_editar boolean,
  puede_ajustes boolean,
  fudo_bloqueos text[],
  puede_lama boolean,
  es_propietario_raiz boolean
)
language plpgsql stable security definer set search_path=''
as $function$
declare
  v_uid uuid := auth.uid();
  v_claims jsonb := auth.jwt();
begin
  if v_uid is null or coalesce(v_claims->>'role','')<>'authenticated'
     or not exists(select 1 from authz_internal.propietario_raiz r
       where r.singleton and r.auth_uid=v_uid) then
    raise exception 'Solo el propietario raíz puede consultar permisos.' using errcode='42501';
  end if;
  return query
  select u.id,u.email::text,p.nombre,
    case when r.auth_uid is not null then true else coalesce(p.puede_fudo,false) end,
    case when r.auth_uid is not null then true else coalesce(p.puede_editar,false) end,
    case when r.auth_uid is not null then true else coalesce(p.puede_ajustes,false) end,
    case when r.auth_uid is not null then '{}'::text[] else coalesce(p.fudo_bloqueos,'{}'::text[]) end,
    case when r.auth_uid is not null then true else coalesce(p.puede_lama,false) end,
    r.auth_uid is not null
  from auth.users u
  left join public.app_permisos p on p.auth_uid=u.id
  left join authz_internal.propietario_raiz r on r.auth_uid=u.id and r.singleton
  where u.confirmed_at is not null and not u.is_anonymous
  order by r.auth_uid is not null desc, lower(u.email);
end
$function$;

create function public.permisos_actualizar(
  p_objetivo uuid,
  p_puede_editar boolean,
  p_puede_fudo boolean,
  p_puede_ajustes boolean,
  p_puede_lama boolean,
  p_fudo_bloqueos text[] default '{}'::text[]
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare
  v_actor uuid := auth.uid();
  v_claims jsonb := auth.jwt();
  v_correo text;
  v_bloqueos text[];
  v_antes public.app_permisos%rowtype;
  v_despues public.app_permisos%rowtype;
  v_encontrado boolean := false;
begin
  if v_actor is null or coalesce(v_claims->>'role','')<>'authenticated'
     or not exists(select 1 from authz_internal.propietario_raiz r
       where r.singleton and r.auth_uid=v_actor) then
    raise exception 'Solo el propietario raíz puede administrar permisos.' using errcode='42501';
  end if;
  if p_objetivo=v_actor or exists(select 1 from authz_internal.propietario_raiz r
      where r.singleton and r.auth_uid=p_objetivo) then
    raise exception 'El propietario raíz no puede modificarse mediante esta operación.' using errcode='42501';
  end if;
  select u.email::text into v_correo from auth.users u
  where u.id=p_objetivo and u.confirmed_at is not null and not u.is_anonymous;
  if v_correo is null then
    raise exception 'La cuenta objetivo no existe, no está confirmada o es anónima.' using errcode='22023';
  end if;
  if p_puede_editar is null or p_puede_fudo is null or p_puede_ajustes is null
     or p_puede_lama is null or p_fudo_bloqueos is null then
    raise exception 'Todas las capacidades deben enviarse explícitamente.' using errcode='22004';
  end if;
  if exists(select 1 from unnest(p_fudo_bloqueos) b
    where b not in ('boton','ficha','todo','reparto','merma','crear','apagar','deshacer')) then
    raise exception 'Existe un bloqueo Fudo desconocido.' using errcode='22023';
  end if;
  select coalesce(array_agg(distinct b order by b),'{}'::text[]) into v_bloqueos
  from unnest(p_fudo_bloqueos) b;

  perform pg_advisory_xact_lock(hashtextextended('permisos:'||p_objetivo::text,0));
  select p.* into v_antes from public.app_permisos p
  where p.auth_uid=p_objetivo for update;
  v_encontrado := found;
  if not v_encontrado then
    select p.* into v_antes from public.app_permisos p
    where lower(p.correo)=lower(v_correo) for update;
    v_encontrado := found;
  end if;

  if v_encontrado then
    update public.app_permisos p set
      correo=v_correo, auth_uid=p_objetivo,
      puede_editar=p_puede_editar, puede_fudo=p_puede_fudo,
      puede_ajustes=p_puede_ajustes, puede_lama=p_puede_lama,
      fudo_bloqueos=v_bloqueos, creado_por=v_actor::text
    where p.correo=v_antes.correo returning p.* into v_despues;
  else
    insert into public.app_permisos(
      correo,auth_uid,puede_editar,puede_fudo,puede_ajustes,puede_lama,
      fudo_bloqueos,creado_por)
    values(v_correo,p_objetivo,p_puede_editar,p_puede_fudo,p_puede_ajustes,
      p_puede_lama,v_bloqueos,v_actor::text)
    returning * into v_despues;
  end if;

  insert into authz_internal.permisos_auditoria(
    actor_auth_uid,objetivo_auth_uid,accion,estado_anterior,estado_nuevo)
  values(v_actor,p_objetivo,'actualizar_permisos',
    case when v_encontrado then to_jsonb(v_antes) else null end,to_jsonb(v_despues));
  return to_jsonb(v_despues)||jsonb_build_object('es_propietario_raiz',false);
end
$function$;

revoke all on function public.permisos_mios() from public, anon, authenticated, service_role;
revoke all on function public.permisos_listar() from public, anon, authenticated, service_role;
revoke all on function public.permisos_actualizar(uuid,boolean,boolean,boolean,boolean,text[])
  from public, anon, authenticated, service_role;
grant execute on function public.permisos_mios() to authenticated;
grant execute on function public.permisos_listar() to authenticated;
grant execute on function public.permisos_actualizar(uuid,boolean,boolean,boolean,boolean,text[])
  to authenticated;

-- Conserva la firma y el comportamiento del motor; solo reemplaza la fuente
-- de autorización por el RPC ligado a auth.uid().
create or replace function public.stock_transferir(
  p_transferencia_id uuid,
  p_producto_origen_id bigint,
  p_producto_destino_id bigint,
  p_ubicacion_origen_id uuid,
  p_ubicacion_destino_id uuid,
  p_cantidad numeric,
  p_motivo text,
  p_lote_id bigint default null
) returns uuid language plpgsql security invoker set search_path=''
as $function$
declare v_claims jsonb; v_actor text;
begin
  v_claims:=auth.jwt();
  v_actor:=lower(btrim(coalesce(v_claims->>'email','')));
  if auth.uid() is null or v_claims->>'role'<>'authenticated' or v_actor='' then
    raise exception 'Se requiere una sesión autenticada para transferir existencias.' using errcode='42501';
  end if;
  if not exists(select 1 from public.permisos_mios() p where p.puede_editar) then
    raise exception 'Tu cuenta no tiene permiso para editar inventario.' using errcode='42501';
  end if;
  return stock_internal.transferir(p_transferencia_id,p_producto_origen_id,p_producto_destino_id,
    p_ubicacion_origen_id,p_ubicacion_destino_id,p_cantidad,p_lote_id,p_motivo,v_actor);
end
$function$;

create or replace function stock_internal.transferir(
  p_transferencia_id uuid,p_producto_origen_id bigint,p_producto_destino_id bigint,
  p_ubicacion_origen_id uuid,p_ubicacion_destino_id uuid,p_cantidad numeric,
  p_lote_id bigint,p_motivo text,p_actor text
) returns uuid language plpgsql security definer set search_path=''
as $function$
declare v_claims jsonb; v_email text;
begin
  v_claims:=auth.jwt();
  v_email:=lower(btrim(coalesce(v_claims->>'email','')));
  if auth.uid() is null or v_claims->>'role'<>'authenticated' or v_email=''
     or v_email is distinct from lower(btrim(p_actor)) then
    raise exception 'Se requiere una sesión autenticada coincidente con el actor.' using errcode='42501';
  end if;
  if not exists(select 1 from public.permisos_mios() p where p.puede_editar) then
    raise exception 'Tu cuenta no tiene permiso para editar inventario.' using errcode='42501';
  end if;
  return stock_internal.transferir_aplicar(p_transferencia_id,p_producto_origen_id,
    p_producto_destino_id,p_ubicacion_origen_id,p_ubicacion_destino_id,p_cantidad,
    p_lote_id,p_motivo,v_email);
end
$function$;

-- Restablece ACL exactas de las dos firmas reemplazadas.
revoke all on function public.stock_transferir(uuid,bigint,bigint,uuid,uuid,numeric,text,bigint)
  from public, anon, authenticated, service_role;
grant execute on function public.stock_transferir(uuid,bigint,bigint,uuid,uuid,numeric,text,bigint)
  to authenticated;
revoke all on function stock_internal.transferir(uuid,bigint,bigint,uuid,uuid,numeric,bigint,text,text)
  from public, anon, authenticated, service_role;
grant usage on schema stock_internal to authenticated;
grant execute on function stock_internal.transferir(uuid,bigint,bigint,uuid,uuid,numeric,bigint,text,text)
  to authenticated;

comment on schema authz_internal is
  'S1: identidad raíz, recuperación y auditoría privadas; no expuesto al navegador.';
comment on column public.app_permisos.auth_uid is
  'Identidad autorizable. El correo queda solo como dato visible y compatibilidad temporal.';
comment on function public.permisos_actualizar(uuid,boolean,boolean,boolean,boolean,text[]) is
  'Única mutación normal de permisos; valida propietario raíz por auth.uid y no puede modificarlo.';

commit;
