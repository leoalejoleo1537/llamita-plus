--  DÓNDE VA:  Supabase -> SQL Editor -> New query   (en el proyecto NUEVO, llamita-plus)
--  ES:        1 solo bloque.
--  TARDA:     instantáneo. NO ESCRIBE NADA: es un select.
--  QUÉ HACE:  comprueba que estén las 33 funciones que la app LLAMA de verdad.
--             Reemplaza al conteo a secas, que no distingue cuál falta.
--  QUÉ VER:   la columna `esta` tiene que decir "sí" en las 33 filas.
--
--  ⚠️ CORREGIDO EL 2026-09-05. La versión anterior preguntaba por `cron.job` y
--  fallaba entera: `pg_cron` es una extensión y en este proyecto NO está
--  instalada. Postgres analiza toda la sentencia antes de ejecutarla, así que
--  una tabla inexistente mata el bloque completo. Ya está contestado: sin la
--  extensión no existe ningún cron, así que ninguno puede llamar al proyecto
--  viejo.

select
  f.nombre,
  case when p.proname is null then 'FALTA' else 'sí' end as esta
from (values
   ('cuenta_abrir'),('mesa_abrir'),('cuenta_agregar'),('cuenta_confirmar'),
   ('cuenta_recalcular'),('cuenta_precuenta'),('cuenta_cerrar'),('cuenta_cobrar'),
   ('cuenta_cobrar_parcial'),('cuenta_pago_parcial_deshacer'),('cuenta_mover'),
   ('items_mover'),('item_anular'),
   ('mermar'),('deshacer_merma'),('registrar_entrada'),('deshacer_entrada'),
   ('fusionar_productos'),('deshacer_fusion'),('restaurar_sede'),
   ('deshacer_restauracion'),('crear_producto_enlazado'),
   ('reparto_recibir'),('reparto_cerrar'),('reparto_rechazar'),
   ('reparto_deshacer'),('reparto_descontar_bodega'),
   ('historial_dias'),('fotos_por_dia'),('meta_avance'),('recetas_rotas'),
   ('franquicia_linea_lista'),('franquicia_linea_no_hay')
) as f(nombre)
left join (
  select distinct p.proname
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
) p on p.proname = f.nombre
order by esta, f.nombre;
