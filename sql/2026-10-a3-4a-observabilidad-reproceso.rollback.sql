--  DÓNDE VA: Supabase -> SQL Editor -> New query
--  ES:        1 solo bloque transaccional
--  TARDA:     instantáneo
--  QUÉ HACE:  elimina solo la vista y el helper internos de A3.4a.
--  QUÉ VER:   las tablas, eventos, aplicaciones, configuración y stock permanecen intactos.
begin;
revoke all on function public.lama_stock_reintentar_evento(uuid) from public, anon, authenticated, service_role;
drop function public.lama_stock_reintentar_evento(uuid);
drop view public.lama_stock_eventos_observabilidad;
commit;
