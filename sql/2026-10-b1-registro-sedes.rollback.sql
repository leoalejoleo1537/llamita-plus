--  DÓNDE VA:  Supabase MCP → proyecto llamita-plus → aplicar rollback
--  ES:        una transacción, solo después de revertir la app
--  TARDA:     segundos
--  QUÉ HACE:  elimina el catálogo solo si conserva exactamente las 4 filas
--             iniciales. Si fue administrado o ampliado, se detiene.
--  QUÉ VER:   Success. No rows returned; la tabla sede_registro deja de existir.

do $$
begin
  if to_regclass('public.sede_registro') is null then
    return;
  end if;

  if (select count(*) from public.sede_registro) <> 4
     or exists (
       select 1
       from (values
         ('plaza','Local 1','local','activa'),
         ('angamos','Local 2','local','archivada'),
         ('central','Bodega','logistica','activa'),
         ('bodega','Bodega histórica','historica','archivada')
       ) expected(codigo,nombre_visible,tipo,estado)
       full join public.sede_registro actual using (codigo)
       where expected.codigo is null
          or actual.codigo is null
          or expected.nombre_visible is distinct from actual.nombre_visible
          or expected.tipo is distinct from actual.tipo
          or expected.estado is distinct from actual.estado
     ) then
    raise exception 'Rollback detenido: sede_registro ya contiene cambios distintos al catálogo inicial.';
  end if;
end;
$$;

drop table if exists public.sede_registro;
drop function if exists public.sede_registro_codigo_inmutable();
