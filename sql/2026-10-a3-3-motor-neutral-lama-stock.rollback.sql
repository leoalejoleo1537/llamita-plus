--  DÓNDE VA: Supabase -> SQL Editor -> New query
--  ES:        1 solo bloque transaccional
--  TARDA:     instantáneo
--  QUÉ HACE:  elimina únicamente A3.3 si no existen aplicaciones persistentes y restaura la captura A3.2.
--  QUÉ VER:   el bloque aborta si hay filas; A3.1/A3.2 permanecen intactas si no se ejecuta.
-- A3.3 rollback: no ejecuta si hay aplicaciones/eventos/capturas.
begin;

do $$
declare n bigint;
begin
  select (select count(*) from public.lama_stock_aplicaciones)
       + (select count(*) from public.lama_stock_eventos)
       + (select count(*) from public.lama_stock_capturas)
    into n;
  if n <> 0 then raise exception 'Rollback A3.3 detenido: existen % filas del puente', n; end if;
end $$;

revoke all on function public.lama_stock_aplicar_evento(uuid) from public, anon, authenticated, service_role;
drop function public.lama_stock_aplicar_evento(uuid);
-- La captura A3.2 queda instalada; su rollback histórico se mantiene separado.
commit;
