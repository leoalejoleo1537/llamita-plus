begin;
drop function if exists public.area_seccion_crear(uuid,text,integer,text,text);

create or replace function public.area_seccion_editar(p_seccion_id uuid,p_nombre text,p_orden integer)
returns void language plpgsql security definer set search_path='' as $function$
declare v_actor uuid;v_nombre text;
begin
 v_actor:=authz_internal.exigir_capacidad_b3_2a('ajustes');
 v_nombre:=btrim(regexp_replace(coalesce(p_nombre,''),'[[:space:]]+',' ','g'));
 if length(v_nombre) not between 1 and 80 then raise exception 'El nombre de la sección es obligatorio.' using errcode='22023';end if;
 update public.area_secciones set nombre=v_nombre,orden=greatest(coalesce(p_orden,100),0),actualizado_por=v_actor,actualizado_at=now()
 where id=p_seccion_id;
 if not found then raise exception 'La sección no existe.' using errcode='P0002';end if;
end $function$;
drop function if exists public.area_seccion_editar(uuid,text,integer,text);
revoke all on function public.area_seccion_editar(uuid,text,integer) from public,anon,authenticated,service_role;
grant execute on function public.area_seccion_editar(uuid,text,integer) to authenticated;
commit;
