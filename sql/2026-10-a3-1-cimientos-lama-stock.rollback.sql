-- A3.1 rollback seguro: solo ejecutar si las tres tablas siguen vacías.
-- No elimina ventas, recetas, productos ni stock.
begin;

do $$
declare
  n bigint;
begin
  select
    (select count(*) from public.lama_stock_config)
    + (select count(*) from public.lama_stock_eventos)
    + (select count(*) from public.lama_stock_aplicaciones)
    into n;
  if n <> 0 then
    raise exception 'Rollback detenido: las tablas A3.1 contienen % filas', n;
  end if;
end $$;

drop table public.lama_stock_aplicaciones;
drop table public.lama_stock_eventos;
drop table public.lama_stock_config;

commit;
