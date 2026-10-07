-- B3.1 no creó filas ni saldos. Retira solo las funciones de lectura.
begin;
drop function if exists public.stock_leer_areas();
drop function if exists stock_internal.leer_existencias_areas_plaza();
commit;
