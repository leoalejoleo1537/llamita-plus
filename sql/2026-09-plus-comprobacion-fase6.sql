--  DÓNDE VA:  Supabase -> SQL Editor -> New query   (en el proyecto NUEVO, llamita-plus)
--  ES:        2 bloques, uno por uno. El editor solo muestra el último resultado.
--  TARDA:     instantáneo. NO ESCRIBE NADA: son dos select.
--  QUÉ HACE:  cierra la Fase 6 del plan de separación — comprueba que ningún
--             cron llame a la casa de Café del Desierto, y que el respaldo
--             haya llegado completo.
--  QUÉ VER:   bloque 1 -> CERO filas.  bloque 2 -> 44 · 76 · 60 · 5 · 1434.


-- ================================================================
-- BLOQUE 1 — ¿Algún cron sigue llamando al proyecto viejo?
-- QUÉ VER: CERO FILAS. Si aparece alguna, avisá antes de tocar nada.
-- ================================================================
select jobname, left(command, 120) as empieza_asi
  from cron.job
 where command like '%fqjdecjsbnicvyrxkxcu%';


-- ================================================================
-- BLOQUE 2 — ¿El respaldo llegó completo?
-- QUÉ VER: 44 tablas · 76 funciones · 60 políticas · 5 crons · 1434 productos.
-- Si algún número es MENOR, avisá: el respaldo no llegó entero.
-- Los crons pueden dar 0 y está bien: no viajaron, se rehacen con la Fase 4.
-- ================================================================
select
  (select count(*) from information_schema.tables where table_schema='public') as tablas,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public') as funciones,
  (select count(*) from pg_policies where schemaname='public') as politicas,
  (select count(*) from cron.job) as crons,
  (select count(*) from public.productos) as productos;
