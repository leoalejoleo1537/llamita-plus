-- Regresión: la lectura de la portada de Inventario debe poder ordenar la
-- unión de productos configurados y saldos físicos sin fallar en PostgreSQL.
-- La prueba no persiste datos.
begin;

select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
  true
);

do $test$
declare
  v_filas bigint;
  v_total_lectura numeric;
  v_total_ledger numeric;
begin
  select count(*),coalesce(sum(r.cantidad),0)
    into v_filas,v_total_lectura
  from public.stock_leer_areas() r;

  if v_filas=0 then
    raise exception 'stock_leer_areas no devolvió filas para Local 1';
  end if;

  select coalesce(sum(e.cantidad),0)
    into v_total_ledger
  from stock_internal.existencias e
  join stock_internal.ubicaciones u on u.id=e.ubicacion_id
  left join public.areas_operativas a
    on a.id=u.area_id and a.sede='plaza' and a.estado='activa'
  where e.sede='plaza'
    and u.sede='plaza'
    and u.activa
    and (
      (u.codigo='sin_asignar' and u.area_id is null)
      or (u.area_id is not null and a.id is not null)
    );

  if v_total_lectura is distinct from v_total_ledger then
    raise exception 'La lectura (%) no concilia con el ledger (%)',v_total_lectura,v_total_ledger;
  end if;
end
$test$;

do $anonymous$
declare
  v_rechazado boolean:=false;
begin
  perform set_config(
    'request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"anon"}',
    true
  );
  begin
    perform * from public.stock_leer_areas();
  exception when others then
    v_rechazado:=true;
  end;
  if not v_rechazado then
    raise exception 'Una sesión anónima pudo leer el inventario por áreas';
  end if;
end
$anonymous$;

rollback;
