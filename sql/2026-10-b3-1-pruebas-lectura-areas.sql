-- B3.1: consulta de solo lectura ejecutada como authenticated y revertida.
-- Proyecto autorizado: Llamita Plus iuryhsjucblmebdogewa.
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000001","role":"authenticated","email":"b3-1-test@test.invalid"}',true);

-- Debe listar exactamente las cuatro áreas y Sin asignar, siempre en plaza.
select area_codigo, area_nombre,
       count(*) filter (where cantidad>0) as productos_con_saldo,
       coalesce(sum(cantidad),0) as unidades
from public.stock_leer_areas()
group by area_codigo,area_nombre
order by area_codigo;

reset role;
-- Conciliación con el libro: se comprueba como operador de pruebas, no se
-- concede esta lectura directa a los roles de la aplicación.
select (select coalesce(sum(cantidad),0) from public.stock_leer_areas()) as rpc_total,
       (select coalesce(sum(cantidad),0) from stock_internal.existencias where sede='plaza') as ledger_total,
       (select count(distinct producto_id) from public.stock_leer_areas() where cantidad>0) as productos_con_saldo;

select has_function_privilege('anon','public.stock_leer_areas()','EXECUTE') as anon_rpc,
       has_function_privilege('authenticated','public.stock_leer_areas()','EXECUTE') as authenticated_rpc,
       has_function_privilege('service_role','public.stock_leer_areas()','EXECUTE') as service_rpc,
       has_table_privilege('authenticated','stock_internal.movimientos','INSERT') as auth_insert_movimientos,
       has_table_privilege('authenticated','stock_internal.ubicaciones','UPDATE') as auth_update_ubicaciones,
       has_table_privilege('service_role','stock_internal.movimientos','INSERT') as service_insert_movimientos;
rollback;
