-- A3.2 hardening: the capture helper is callable only by its owning functions.
begin;
revoke all on function public.lama_stock_capturar_cuenta(bigint)
  from public, anon, authenticated, service_role;
commit;
