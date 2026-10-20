begin;

do $rollback$
begin
  if exists(select 1 from stock_internal.repartos_area)
     or exists(select 1 from stock_internal.repartos_area_items)
     or exists(select 1 from stock_internal.lote_continuidad where reparto_area_item_id is not null) then
    raise exception 'Rollback técnico bloqueado: ya existen repartos/recepciones de Fase 2. Conservar la auditoría y usar compensación.';
  end if;
end
$rollback$;

drop function if exists public.reparto_area_recibir(uuid,uuid,jsonb,text);
drop function if exists public.repartos_area_listar(uuid,boolean);
drop function if exists public.reparto_area_crear(uuid,uuid,text,jsonb);
drop function if exists public.reparto_area_catalogo_buscar(uuid,text);
drop function if exists stock_internal.saldo_transferible_bodega(bigint,uuid,bigint);

drop index if exists stock_internal.stock_lote_continuidad_reparto_item_idx;
alter table stock_internal.lote_continuidad drop constraint if exists lote_continuidad_origen_check;
alter table stock_internal.lote_continuidad drop column if exists reparto_area_item_id;
alter table stock_internal.lote_continuidad alter column transferencia_id set not null;

drop trigger if exists repartos_area_items_inmutables on stock_internal.repartos_area_items;
drop trigger if exists repartos_area_inmutables on stock_internal.repartos_area;
drop function if exists stock_internal.proteger_reparto_area();
drop table if exists stock_internal.repartos_area_items;
drop table if exists stock_internal.repartos_area;

commit;
