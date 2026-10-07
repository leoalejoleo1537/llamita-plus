-- Complemento B2.4: cubre la FK de trazabilidad lote → transferencia.
create index if not exists stock_lote_continuidad_transferencia_idx
  on stock_internal.lote_continuidad(transferencia_id);
