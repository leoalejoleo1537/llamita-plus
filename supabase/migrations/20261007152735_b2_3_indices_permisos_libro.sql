-- Dónde se ejecuta: solo Supabase Llamita Plus (iuryhsjucblmebdogewa).
-- Bloque Hermes: B2.3, complemento de índices y denegación explícita del libro.
-- Ejecución: migración verificada posterior a b2_3_libro_existencias_corte.
-- Qué cambia: índices de las claves foráneas nuevas y políticas RLS restrictivas
-- que documentan el cierre total del acceso directo a tablas internas.
-- Qué no cambia: existencias, productos, lotes, historial ni configuración POS.
-- Resultado esperado: consultas del motor indexadas; acceso API continúa cerrado.

create index if not exists stock_movimientos_ubicacion_sede_idx
  on stock_internal.movimientos(ubicacion_id,sede);
create index if not exists stock_transferencias_producto_origen_idx
  on stock_internal.transferencias(producto_origen_id);
create index if not exists stock_transferencias_producto_destino_idx
  on stock_internal.transferencias(producto_destino_id);
create index if not exists stock_transferencias_ubicacion_origen_idx
  on stock_internal.transferencias(ubicacion_origen_id);
create index if not exists stock_transferencias_ubicacion_destino_idx
  on stock_internal.transferencias(ubicacion_destino_id);
create index if not exists stock_ubicaciones_area_id_idx
  on stock_internal.ubicaciones(area_id) where area_id is not null;

drop policy if exists stock_interno_solo_privado_ubicaciones on stock_internal.ubicaciones;
create policy stock_interno_solo_privado_ubicaciones on stock_internal.ubicaciones
  as restrictive for all to public using (false) with check (false);
drop policy if exists stock_interno_solo_privado_aperturas on stock_internal.aperturas;
create policy stock_interno_solo_privado_aperturas on stock_internal.aperturas
  as restrictive for all to public using (false) with check (false);
drop policy if exists stock_interno_solo_privado_movimientos on stock_internal.movimientos;
create policy stock_interno_solo_privado_movimientos on stock_internal.movimientos
  as restrictive for all to public using (false) with check (false);
drop policy if exists stock_interno_solo_privado_transferencias on stock_internal.transferencias;
create policy stock_interno_solo_privado_transferencias on stock_internal.transferencias
  as restrictive for all to public using (false) with check (false);
drop policy if exists stock_interno_solo_privado_permisos on stock_internal.permiso_proyeccion;
create policy stock_interno_solo_privado_permisos on stock_internal.permiso_proyeccion
  as restrictive for all to public using (false) with check (false);
