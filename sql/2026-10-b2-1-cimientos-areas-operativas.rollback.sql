-- Rollback de B2.1. Solo elimina el esquema aditivo de áreas.
-- Se detiene si alguien ya creó asignaciones o alteró el catálogo esperado.
begin;
do $$
declare
  v_asignaciones bigint;
  v_areas_plaza bigint;
  v_areas_otras bigint;
  v_catalogo text[];
begin
  if to_regclass('public.producto_area_asignacion') is null
     or to_regclass('public.areas_operativas') is null then
    raise exception 'Rollback detenido: faltan tablas de B2.1';
  end if;

  execute 'select count(*) from public.producto_area_asignacion' into v_asignaciones;
  execute 'select count(*) from public.areas_operativas where sede = ''plaza''' into v_areas_plaza;
  execute 'select count(*) from public.areas_operativas where sede <> ''plaza''' into v_areas_otras;
  execute 'select array_agg(codigo || '':'' || nombre || '':'' || estado order by codigo) from public.areas_operativas where sede = ''plaza''' into v_catalogo;
  if v_asignaciones <> 0 or v_areas_plaza <> 4 or v_areas_otras <> 0 then
    raise exception 'Rollback detenido: cambió el estado esperado (asignaciones %, áreas plaza %, áreas otras %)',
      v_asignaciones, v_areas_plaza, v_areas_otras;
  end if;
  if v_catalogo is distinct from array[
    'barra:Barra:activa',
    'cafeteria:Cafetería:activa',
    'cocina_caliente:Cocina caliente:activa',
    'cocina_fria:Cocina fría:activa'
  ]::text[] then
    raise exception 'Rollback detenido: los códigos, nombres o estados del catálogo cambiaron';
  end if;
end;
$$;

drop table public.producto_area_asignacion;
drop table public.areas_operativas;
drop function public.producto_area_validar_contexto();
drop function public.areas_operativas_guardar();
commit;
