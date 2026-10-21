begin;
do $$ begin
  if exists(select 1 from catalogo_internal.operaciones) or exists(select 1 from public.productos where panel_gestionado) then
    raise exception 'Panel con uso real: conservar auditoría y planificar reversión sin borrar datos.';
  end if;
end $$;
drop function public.panel_producto_guardar(uuid,bigint,bigint,jsonb);
drop function public.panel_productos_listar(text,bigint);
drop trigger catalogo_enlace_coherente on public.producto_enlace;
drop trigger catalogo_proteger_producto on public.productos;
drop index public.productos_central_nombre_activo_uk;
drop function catalogo_internal.enlace_coherente();
drop function catalogo_internal.proteger_producto();
drop function catalogo_internal.nombre_clave(text);
drop table catalogo_internal.operaciones;
drop table catalogo_internal.permiso_escritura;
drop function catalogo_internal.inmutable();
drop schema catalogo_internal;
alter table public.productos drop column costo_compra,drop column costo_pendiente,drop column panel_gestionado,drop column catalogo_revision;
commit;
