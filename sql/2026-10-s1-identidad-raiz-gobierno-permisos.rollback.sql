-- Rollback técnico de S1.
-- Solo es válido antes del primer cambio persistente hecho con permisos_actualizar.
begin;

do $preflight$
begin
  if to_regclass('authz_internal.propietario_raiz') is null
     or to_regclass('authz_internal.app_permisos_pre_s1') is null then
    raise exception 'Rollback S1 abortado: no está instalada la estructura esperada.';
  end if;
  if exists(select 1 from authz_internal.permisos_auditoria) then
    raise exception 'Rollback S1 abortado: ya existen cambios posteriores auditados. Use reversión compensatoria.';
  end if;
end
$preflight$;

-- Restaura primero las funciones que dependen de permisos_mios.
create or replace function public.stock_transferir(
  p_transferencia_id uuid,p_producto_origen_id bigint,p_producto_destino_id bigint,
  p_ubicacion_origen_id uuid,p_ubicacion_destino_id uuid,p_cantidad numeric,
  p_motivo text,p_lote_id bigint default null
) returns uuid language plpgsql security invoker set search_path=''
as $function$
declare v_claims jsonb; v_actor text;
begin
  v_claims:=auth.jwt();
  v_actor:=lower(btrim(coalesce(v_claims->>'email','')));
  if auth.uid() is null or v_claims->>'role'<>'authenticated' or v_actor='' then
    raise exception 'Se requiere una sesión autenticada para transferir existencias.' using errcode='42501';
  end if;
  if not exists(select 1 from public.app_permisos a
    where lower(a.correo)=v_actor and a.puede_editar is true) then
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
  if not exists(select 1 from public.app_permisos a
    where lower(a.correo)=v_email and a.puede_editar is true) then
    raise exception 'Tu cuenta no tiene permiso para editar inventario.' using errcode='42501';
  end if;
  return stock_internal.transferir_aplicar(p_transferencia_id,p_producto_origen_id,
    p_producto_destino_id,p_ubicacion_origen_id,p_ubicacion_destino_id,p_cantidad,
    p_lote_id,p_motivo,v_email);
end
$function$;

drop function if exists public.permisos_actualizar(uuid,boolean,boolean,boolean,boolean,text[]);
drop function if exists public.permisos_listar();
drop function if exists public.permisos_mios();

update public.app_permisos p set
  nombre=s.nombre, puede_fudo=s.puede_fudo, puede_editar=s.puede_editar,
  creado_por=s.creado_por, created_at=s.created_at, puede_ajustes=s.puede_ajustes,
  fudo_bloqueos=s.fudo_bloqueos, puede_lama=s.puede_lama
from authz_internal.app_permisos_pre_s1 s where s.correo=p.correo;

drop policy if exists app_permisos_lectura_propia on public.app_permisos;
alter table public.app_permisos drop constraint if exists app_permisos_sin_auth_sin_capacidades;
alter table public.app_permisos drop constraint if exists app_permisos_auth_uid_fkey;
alter table public.app_permisos drop constraint if exists app_permisos_auth_uid_key;
alter table public.app_permisos drop column if exists auth_uid;
alter table public.app_permisos alter column puede_editar set default true;
alter table public.app_permisos alter column puede_fudo set default true;

grant select,insert,update,delete,truncate,references,trigger
  on table public.app_permisos to anon,authenticated,service_role;
create policy "app_permisos read" on public.app_permisos
  for select to anon,authenticated using(true);
create policy "app_permisos alta" on public.app_permisos
  for insert to authenticated with check(true);
create policy "app_permisos cambio" on public.app_permisos
  for update to authenticated using(true) with check(true);
create policy "app_permisos escribir" on public.app_permisos
  for update to anon,authenticated using(true) with check(true);

drop schema authz_internal cascade;
commit;
