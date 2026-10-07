-- Índices de cobertura para las FK de la relación preparatoria de B2.1.
-- Mantiene el acceso filtrado por sede/área del índice compuesto existente.
create index if not exists producto_area_producto_fk_idx
  on public.producto_area_asignacion(producto_id);
create index if not exists producto_area_area_fk_idx
  on public.producto_area_asignacion(area_id);
