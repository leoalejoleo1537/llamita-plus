-- El RPC expuesto corre como invocador; el helper privado valida identidad y permiso.
alter function stock_internal.transferir(uuid,bigint,bigint,uuid,uuid,numeric,bigint,text,text)
  rename to transferir_aplicar;
revoke all on function stock_internal.transferir_aplicar(uuid,bigint,bigint,uuid,uuid,numeric,bigint,text,text)
  from public,anon,authenticated,service_role;

create function stock_internal.transferir(
  p_transferencia_id uuid,
  p_producto_origen_id bigint,
  p_producto_destino_id bigint,
  p_ubicacion_origen_id uuid,
  p_ubicacion_destino_id uuid,
  p_cantidad numeric,
  p_lote_id bigint,
  p_motivo text,
  p_actor text
) returns uuid
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_claims jsonb;
  v_email text;
begin
  v_claims := auth.jwt();
  v_email := lower(btrim(coalesce(v_claims->>'email','')));
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
revoke all on function stock_internal.transferir(uuid,bigint,bigint,uuid,uuid,numeric,bigint,text,text)
  from public,anon,authenticated,service_role;
revoke all on schema stock_internal from public,anon,authenticated,service_role;
grant usage on schema stock_internal to authenticated;
grant execute on function stock_internal.transferir(uuid,bigint,bigint,uuid,uuid,numeric,bigint,text,text)
  to authenticated;

alter function public.stock_transferir(uuid,bigint,bigint,uuid,uuid,numeric,text,bigint)
  security invoker;
