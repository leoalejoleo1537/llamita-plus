begin;
create or replace function public.area_seccion_crear(p_area_id uuid,p_nombre text,p_orden integer default 100,p_codigo text default null)
returns uuid language plpgsql security definer set search_path='' as $function$
declare v_actor uuid;v_id uuid;v_nombre text;v_codigo text;
begin
 v_actor:=authz_internal.exigir_capacidad_b3_2a('editar');v_nombre:=btrim(regexp_replace(coalesce(p_nombre,''),'[[:space:]]+',' ','g'));
 if length(v_nombre) not between 1 and 80 then raise exception 'El nombre de la sección es obligatorio.' using errcode='22023';end if;
 if not exists(select 1 from public.areas_operativas a where a.id=p_area_id and a.sede='plaza' and a.estado='activa') then raise exception 'El área no existe o está archivada.' using errcode='22023';end if;
 v_codigo:=coalesce(nullif(btrim(p_codigo),''),'sec_'||substr(md5(gen_random_uuid()::text),1,12));
 insert into public.area_secciones(area_id,codigo,nombre,orden,turno,estado,creado_por,actualizado_por)
 values(p_area_id,v_codigo,v_nombre,greatest(coalesce(p_orden,100),0),'pm','activa',v_actor,v_actor) returning id into v_id;return v_id;
end $function$;
create or replace function public.area_seccion_editar(p_seccion_id uuid,p_nombre text,p_orden integer)
returns void language plpgsql security definer set search_path='' as $function$
declare v_actor uuid;v_nombre text;
begin
 v_actor:=authz_internal.exigir_capacidad_b3_2a('ajustes');v_nombre:=btrim(regexp_replace(coalesce(p_nombre,''),'[[:space:]]+',' ','g'));
 if length(v_nombre) not between 1 and 80 then raise exception 'El nombre de la sección es obligatorio.' using errcode='22023';end if;
 update public.area_secciones set nombre=v_nombre,orden=greatest(coalesce(p_orden,100),0),actualizado_por=v_actor,actualizado_at=now() where id=p_seccion_id;
 if not found then raise exception 'La sección no existe.' using errcode='P0002';end if;
end $function$;
commit;
