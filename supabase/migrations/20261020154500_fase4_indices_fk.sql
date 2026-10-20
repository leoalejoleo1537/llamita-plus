begin;

-- Índices de soporte para las claves foráneas nuevas de Fase 4. No cambian
-- contratos ni datos; evitan escaneos completos al archivar actores/cuentas.
create index lama_alertas_cuenta_idx on stock_internal.lama_alertas(cuenta_id);
create index lama_alertas_resuelta_por_idx on stock_internal.lama_alertas(resuelta_por)
  where resuelta_por is not null;
create index lama_fuentes_creado_por_idx on stock_internal.lama_fuentes_directas(creado_por);
create index lama_fuentes_actualizado_por_idx on stock_internal.lama_fuentes_directas(actualizado_por);
create index lama_fuentes_aud_actor_idx on stock_internal.lama_fuentes_directas_auditoria(actor_auth_uid);
create index lama_reservas_area_idx on stock_internal.lama_reservas(area_id);
create index lama_reservas_cuenta_origen_idx on stock_internal.lama_reservas(cuenta_origen_id);
create index lama_reservas_ubicacion_sede_idx on stock_internal.lama_reservas(ubicacion_id,sede);
create index lama_reservas_reservada_por_idx on stock_internal.lama_reservas(reservada_por);
create index lama_reservas_consumida_por_idx on stock_internal.lama_reservas(consumida_por)
  where consumida_por is not null;
create index lama_reservas_liberada_por_idx on stock_internal.lama_reservas(liberada_por)
  where liberada_por is not null;

commit;
