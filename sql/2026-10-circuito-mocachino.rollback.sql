begin;
do $guard$
begin
 if exists(select 1 from stock_internal.producto_area_ficha_operaciones)
    or exists(select 1 from stock_internal.repartos_area_items where seccion_destino_id is not null) then
  raise exception 'Rollback estructural bloqueado: ya existen operaciones reales. Use compensación auditada y conserve las instantáneas.';
 end if;
end $guard$;
drop trigger if exists exigir_seccion_configuracion_nueva_trg on public.producto_area_asignacion;
drop trigger if exists trg_reparto_item_ruta on stock_internal.repartos_area_items;
drop trigger if exists trg_area_seccion_reparto_abierto on public.area_secciones;
drop function if exists stock_internal.exigir_seccion_configuracion_nueva();
drop function if exists stock_internal.validar_ruta_reparto_item();
drop function if exists stock_internal.bloquear_archivo_seccion_reparto();
drop function if exists public.producto_area_ficha_guardar(uuid,bigint,uuid,uuid,numeric,numeric,boolean,jsonb,text);
drop function if exists public.reparto_area_rutas_listar(uuid);
drop function if exists public.panel_ingredientes_pendientes_listar(text);
alter table public.area_secciones add column if not exists turno text not null default 'pm' check(turno in ('am','pm'));
alter table public.secciones add column if not exists turno text not null default 'pm' check(turno in ('am','pm'));
update public.area_secciones s set turno=b.turno from stock_internal.turnos_secciones_respaldo_20261023 b
 where b.fuente='area_secciones' and b.clave=s.id::text;
update public.secciones s set turno=b.turno from stock_internal.turnos_secciones_respaldo_20261023 b
 where b.fuente='secciones' and b.clave=s.sede||':'||s.nombre;
alter table stock_internal.repartos_area_items drop column if exists configuracion_id,drop column if exists seccion_destino_id,drop column if exists seccion_destino_nombre;
drop table if exists stock_internal.producto_area_ficha_operaciones;
-- Reinstalar después las cuatro firmas lectoras del commit anterior junto con
-- el frontend anterior; este script restaura los datos y bloquea si ya hubo uso real.
commit;
