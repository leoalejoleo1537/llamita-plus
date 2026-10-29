begin;

-- Mesas es una herramienta de operación de Local 1. El permiso Lama conserva
-- el gobierno de fuentes y configuración; la sesión autenticada habilita el
-- trabajo diario que ya valida sus propios escritores.
create or replace function authz_internal.exigir_lama(p_gobierno boolean default false)
returns uuid
language plpgsql stable security definer set search_path=''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_raiz boolean;
  v_lama boolean;
  v_ajustes boolean;
begin
  if v_uid is null then
    raise exception 'Inicia sesión para usar Mesas.' using errcode='28000';
  end if;

  if not coalesce(p_gobierno,false) then return v_uid; end if;

  select exists(select 1 from authz_internal.propietario_raiz r
    where r.singleton and r.auth_uid=v_uid) into v_raiz;
  if v_raiz then return v_uid; end if;

  select coalesce(p.puede_lama,false),coalesce(p.puede_ajustes,false)
    into v_lama,v_ajustes
    from public.app_permisos p where p.auth_uid=v_uid;
  if not coalesce(v_lama,false) or not coalesce(v_ajustes,false) then
    raise exception 'Tu cuenta no puede configurar fuentes de inventario para Mesas.' using errcode='42501';
  end if;
  return v_uid;
end
$function$;

revoke all on function authz_internal.exigir_lama(boolean) from public,anon,authenticated,service_role;

commit;
