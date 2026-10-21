begin;

create index productos_venta_creado_por_idx
  on catalogo_internal.productos_venta(creado_por);
create index productos_venta_actualizado_por_idx
  on catalogo_internal.productos_venta(actualizado_por);
create index productos_venta_archivado_por_idx
  on catalogo_internal.productos_venta(archivado_por) where archivado_por is not null;
create index recetas_venta_creado_por_idx
  on catalogo_internal.recetas_venta(creado_por);
create index receta_venta_componentes_creado_por_idx
  on catalogo_internal.receta_venta_componentes(creado_por);
create index producto_venta_pos_creado_por_idx
  on catalogo_internal.producto_venta_pos_enlaces(creado_por);
create index producto_venta_pos_actualizado_por_idx
  on catalogo_internal.producto_venta_pos_enlaces(actualizado_por);

commit;
