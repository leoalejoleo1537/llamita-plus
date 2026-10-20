begin;
do $rollback_guard$
begin
  if exists(select 1 from stock_internal.ajustes_manuales)
     or exists(select 1 from stock_internal.movimientos where ajuste_manual_id is not null) then
    raise exception 'Rollback técnico detenido: existen ajustes; conservarlos y usar solo una reversa compensatoria auditada.';
  end if;
end
$rollback_guard$;
revoke all on function public.stock_ajuste_guardar(uuid,bigint,uuid,jsonb,text) from public,anon,authenticated,service_role;
revoke all on function public.stock_ajuste_desglose_leer(bigint,uuid) from public,anon,authenticated,service_role;
drop function public.stock_ajuste_guardar(uuid,bigint,uuid,jsonb,text);
drop function public.stock_ajuste_desglose_leer(bigint,uuid);
drop trigger ajustes_manuales_inmutables on stock_internal.ajustes_manuales;
drop function stock_internal.impedir_mutacion_ajuste_manual();
alter table stock_internal.movimientos drop constraint movimientos_ajuste_manual_fk;
drop index stock_internal.movimientos_ajuste_manual_id_idx;
alter table stock_internal.movimientos drop column ajuste_manual_id;
drop table stock_internal.ajustes_manuales;
commit;
