-- Rollback técnico de B3.2a.1. Solo es seguro antes de uso persistente.
begin;

do $guard$
begin
  if exists(select 1 from public.areas_operativas where creado_por is not null or actualizado_por is not null or estado='archivada')
     or exists(select 1 from public.producto_area_asignacion)
     or exists(select 1 from public.productos where origen='b3_2a_rpc') then
    raise exception 'Rollback abortado: B3.2a.1 ya tiene actividad. Requiere reversión compensatoria documentada.';
  end if;
end
$guard$;

drop function public.producto_plaza_crear(text,text,double precision,double precision,boolean,text,text,uuid,text,text);
drop function public.producto_area_preferencia_guardar(bigint,uuid,text);
drop function public.area_operativa_archivar(uuid,boolean);
drop function public.area_operativa_editar(uuid,text,integer);
drop function public.area_operativa_crear(text,integer,text,text);
drop function public.areas_operativas_listar(text,boolean);
drop function stock_internal.guardar_preferencia_producto(bigint,uuid,uuid);
drop function stock_internal.codigo_area_desde_nombre(text);
drop function authz_internal.exigir_capacidad_b3_2a(text);

drop trigger stock_ubicaciones_validar_area_trg on stock_internal.ubicaciones;
drop function stock_internal.validar_ubicacion_area();

create or replace function public.producto_area_validar_contexto()
returns trigger language plpgsql set search_path=pg_catalog
as $function$
declare v_producto_sede text; v_area_sede text;
begin
  select p.sede into v_producto_sede from public.productos p where p.id=new.producto_id;
  if not found or v_producto_sede is distinct from new.sede then
    raise check_violation using message='La sede de la asignación debe coincidir con la sede del producto';
  end if;
  if new.area_id is not null then
    select a.sede into v_area_sede from public.areas_operativas a where a.id=new.area_id;
    if not found or v_area_sede is distinct from new.sede then
      raise check_violation using message='El área y el producto deben pertenecer a la misma sede';
    end if;
  end if;
  new.actualizado_at:=now(); return new;
end
$function$;

drop index public.producto_area_actualizado_por_idx;
drop index public.producto_area_creado_por_idx;
drop index public.areas_operativas_archivado_por_idx;
drop index public.areas_operativas_actualizado_por_idx;
drop index public.areas_operativas_creado_por_idx;
drop index public.areas_operativas_sede_nombre_normalizado_uk;

alter table stock_internal.ubicaciones drop constraint stock_ubicaciones_area_id_uk;
alter table public.producto_area_asignacion
  drop constraint producto_area_asignacion_solo_plaza_ck,
  drop column actualizado_por,
  drop column creado_por;
alter table public.areas_operativas
  drop constraint areas_operativas_archivo_actor_ck,
  drop constraint areas_operativas_orden_no_negativo_ck,
  drop constraint areas_operativas_solo_plaza_ck,
  drop column archivado_at,
  drop column archivado_por,
  drop column actualizado_por,
  drop column creado_por,
  drop column nombre_normalizado;

commit;
