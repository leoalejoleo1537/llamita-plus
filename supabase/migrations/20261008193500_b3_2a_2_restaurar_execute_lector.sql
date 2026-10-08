begin;

-- stock_leer_areas es SECURITY INVOKER y necesita delegar en este helper.
-- stock_internal no está expuesto por la Data API; no se abre ninguna tabla.
revoke all on function stock_internal.leer_existencias_areas_plaza()
  from public,anon,authenticated,service_role;
grant execute on function stock_internal.leer_existencias_areas_plaza()
  to postgres,authenticated;

commit;
