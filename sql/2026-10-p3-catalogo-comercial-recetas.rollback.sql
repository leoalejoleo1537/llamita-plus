begin;

revoke all on function public.panel_ventas_listar(text,uuid) from public,anon,authenticated,service_role;
revoke all on function public.panel_ingredientes_listar(text) from public,anon,authenticated,service_role;
revoke all on function public.panel_venta_guardar(uuid,uuid,bigint,jsonb) from public,anon,authenticated,service_role;
drop function public.panel_venta_guardar(uuid,uuid,bigint,jsonb);
drop function public.panel_ingredientes_listar(text);
drop function public.panel_ventas_listar(text,uuid);
drop table catalogo_internal.producto_venta_operaciones;
drop table catalogo_internal.producto_venta_pos_enlaces;
drop table catalogo_internal.receta_venta_componentes;
drop table catalogo_internal.recetas_venta;
drop table catalogo_internal.productos_venta;

commit;
