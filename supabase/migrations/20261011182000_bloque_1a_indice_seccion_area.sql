begin;

-- El FK compuesto (seccion_id, area_id) necesita cobertura en el mismo orden.
drop index if exists public.producto_area_seccion_idx;
create index producto_area_seccion_area_idx
  on public.producto_area_asignacion(seccion_id,area_id)
  where seccion_id is not null;

commit;
