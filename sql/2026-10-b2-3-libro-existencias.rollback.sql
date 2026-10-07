-- Dónde se ejecuta: solo Supabase Llamita Plus (iuryhsjucblmebdogewa).
-- Bloque Hermes: rollback técnico de B2.3.
-- Ejecución: manual, con respaldo y dentro de una transacción; NO se aplica
-- como migración normal. El bloque DO aborta antes de cambios si hay actividad
-- posterior a las aperturas. Ver docs/hermes/19-b2-3-corte-libro-ubicaciones.md.
-- Qué hace: restaura permisos/política histórica y el trigger original de lotes.
-- Qué no hace: no borra datos operativos ni modifica existencias o lotes.
-- Si ya existen movimientos posteriores: no ejecutar; usar compensación auditada.

begin;

do $guard$
begin
  if to_regclass('stock_internal.movimientos') is null then
    raise exception 'Rollback detenido: no está instalado el libro B2.3.';
  end if;
  if exists(select 1 from stock_internal.movimientos where tipo<>'apertura_migracion')
     or exists(select 1 from stock_internal.transferencias) then
    raise exception 'Rollback técnico detenido: existen operaciones posteriores. Requiere reversión compensatoria auditada; no borrar movimientos.';
  end if;
end $guard$;

drop trigger if exists trg_stock_proteger_maestro on public.productos;
drop trigger if exists trg_stock_proteger_lotes on public.producto_lotes;
drop trigger if exists trg_stock_bloquear_fudo_real on public.fudo_sync;
drop trigger if exists trg_stock_bloquear_lama_real on public.lama_stock_config;
drop trigger if exists trg_stock_bloquear_fudo_aplicado on public.fudo_movimientos;
drop trigger if exists trg_stock_bloquear_fusion on public.fusiones;
drop trigger if exists trg_stock_bloquear_restauracion on public.restauraciones;
drop trigger if exists trg_stock_bloquear_movimiento_legacy on public.movimientos;
drop trigger if exists trg_stock_bloquear_repartos on public.repartos;
drop trigger if exists trg_stock_bloquear_reparto_items on public.reparto_items;
drop trigger if exists trg_stock_ledger_projection on stock_internal.movimientos;
drop trigger if exists trg_stock_ledger_immutable on stock_internal.movimientos;
drop trigger if exists trg_stock_transfer_immutable on stock_internal.transferencias;

drop policy if exists "producto_lotes lectura legacy" on public.producto_lotes;
drop policy if exists "producto_lotes alta sedes no migradas" on public.producto_lotes;
drop policy if exists "producto_lotes edicion sedes no migradas" on public.producto_lotes;
drop policy if exists "producto_lotes baja sedes no migradas" on public.producto_lotes;
create policy "producto_lotes all" on public.producto_lotes for all to anon,authenticated using (true) with check (true);
grant select,insert,update,delete,truncate,trigger,references on public.productos,public.producto_lotes to anon,authenticated,service_role;

create or replace function public.sync_stock_desde_lotes()
returns trigger language plpgsql security definer set search_path to 'public'
as $function$
declare v_pid bigint;
begin
  v_pid := coalesce(new.producto_id, old.producto_id);
  update public.productos p
  set stock_actual = coalesce((select sum(l.cantidad) from public.producto_lotes l where l.producto_id = v_pid), 0),
      updated_at = now()
  where p.id = v_pid;
  return null;
end;
$function$;
grant execute on function public.sync_stock_desde_lotes() to anon,authenticated,service_role;

drop schema stock_internal cascade;

commit;
