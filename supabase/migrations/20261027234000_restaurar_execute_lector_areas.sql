-- La RPC pública stock_leer_areas es SECURITY INVOKER y delega en esta
-- función interna. El rol authenticated necesita EXECUTE sobre ambas; no
-- se habilita ninguna escritura ni acceso de tabla.
begin;

revoke all on function stock_internal.leer_existencias_areas_plaza()
  from public,anon,service_role;
grant execute on function stock_internal.leer_existencias_areas_plaza()
  to authenticated;

commit;
