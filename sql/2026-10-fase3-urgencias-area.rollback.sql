begin;

do $rollback$
begin
  if exists(select 1 from public.producto_area_asignacion where urgente) then
    raise exception 'Rollback bloqueado: existen urgencias activas. Quítelas mediante la RPC para conservar el estado operativo.';
  end if;
end
$rollback$;

drop function if exists public.producto_area_urgencias_listar(uuid);
drop function if exists public.producto_area_urgencia_guardar(bigint,uuid,boolean,text);
drop index if exists public.producto_area_urgentes_idx;
alter table public.producto_area_asignacion
  drop constraint if exists producto_area_urgencia_estado_ck,
  drop constraint if exists producto_area_urgencia_nota_ck,
  drop column if exists urgente_por,
  drop column if exists urgente_desde,
  drop column if exists urgente_nota,
  drop column if exists urgente;

commit;
