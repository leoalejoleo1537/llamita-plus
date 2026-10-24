create or replace function stock_internal.exigir_seccion_configuracion_nueva()
returns trigger language plpgsql set search_path='' as $function$
begin
 if new.sede='plaza' and new.estado='asignado' and new.archivado_at is null and new.seccion_id is null
    and (tg_op='INSERT' or old.seccion_id is not null) then
  raise exception 'Toda configuración nueva de Local 1 necesita una sección física.' using errcode='23514';
 end if;
 return new;
end $function$;
revoke all on function stock_internal.exigir_seccion_configuracion_nueva() from public,anon,authenticated,service_role;
drop trigger if exists exigir_seccion_configuracion_nueva_trg on public.producto_area_asignacion;
create trigger exigir_seccion_configuracion_nueva_trg before insert or update of seccion_id,estado,archivado_at
on public.producto_area_asignacion for each row execute function stock_internal.exigir_seccion_configuracion_nueva();
