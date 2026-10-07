-- Rollback técnico B2.4: solo antes de crear movimientos nuevos.
-- Si hay transferencias reales B2.4, detenerse y usar compensación auditada.
begin;
do $guard$
begin
  if exists(select 1 from stock_internal.transferencias where actor is not null or motivo is not null or reversa_de is not null)
     or exists(select 1 from stock_internal.lote_continuidad)
     or exists(select 1 from stock_internal.movimientos where tipo='clasificacion_lote') then
    raise exception 'Rollback B2.4 cancelado: hay actividad; use compensación auditada.';
  end if;
end
$guard$;

drop trigger if exists stock_transferencias_par_header on stock_internal.transferencias;
drop trigger if exists stock_transferencias_par_movimiento on stock_internal.movimientos;
drop function if exists stock_internal.validar_par_transferencia();
drop function if exists public.stock_transferir(uuid,bigint,bigint,uuid,uuid,numeric,text,bigint);
drop function if exists stock_internal.transferir(uuid,bigint,bigint,uuid,uuid,numeric,bigint,text,text);
drop function if exists stock_internal.transferir_aplicar(uuid,bigint,bigint,uuid,uuid,numeric,bigint,text,text);
revoke usage on schema stock_internal from authenticated;
drop table if exists stock_internal.lote_continuidad;
drop index if exists stock_transferencias_reversa_de_uidx;
alter table stock_internal.transferencias drop column if exists reversa_de;
alter table stock_internal.transferencias drop column if exists motivo;
alter table stock_internal.transferencias drop column if exists actor;
alter table stock_internal.movimientos drop constraint if exists movimientos_tipo_check;
alter table stock_internal.movimientos add constraint movimientos_tipo_check
  check (tipo in ('entrada','salida','transferencia','merma','ajuste','apertura_migracion'));

-- Restaurar la función interna exactamente al límite de B2.3.
create or replace function stock_internal.transferir(
  p_transferencia_id uuid,
  p_producto_origen_id bigint,
  p_producto_destino_id bigint,
  p_ubicacion_origen_id uuid,
  p_ubicacion_destino_id uuid,
  p_cantidad numeric,
  p_lote_id bigint default null
) returns uuid language plpgsql security definer set search_path=''
as $function$
declare
  v_sede_origen text; v_sede_destino text; v_codigo_origen text; v_codigo_destino text;
  v_ref text; v_hay numeric; v_origen public.productos; v_destino public.productos;
  v_existente stock_internal.transferencias;
begin
  if p_cantidad is null or p_cantidad<=0 then raise exception 'La cantidad debe ser mayor que cero.'; end if;
  select sede,codigo into v_sede_origen,v_codigo_origen from stock_internal.ubicaciones where id=p_ubicacion_origen_id and activa;
  select sede,codigo into v_sede_destino,v_codigo_destino from stock_internal.ubicaciones where id=p_ubicacion_destino_id and activa;
  if v_sede_origen is null or v_sede_destino is null then raise exception 'Ubicación inexistente o inactiva.'; end if;
  select * into v_origen from public.productos where id=p_producto_origen_id for update;
  select * into v_destino from public.productos where id=p_producto_destino_id for update;
  if v_origen.id is null or v_destino.id is null then raise exception 'Producto inexistente.'; end if;
  if v_origen.sede<>v_sede_origen or v_destino.sede<>v_sede_destino then raise exception 'Producto y ubicación no pertenecen a la misma sede.'; end if;
  if not (v_sede_origen='central' and v_sede_destino='plaza' and v_codigo_origen='bodega_central'
      and v_codigo_destino in ('cocina_fria','cocina_caliente','barra','cafeteria')) then
    raise exception 'En esta fase solo se permite transferir desde Bodega central a un área de Local 1.';
  end if;
  if not exists(select 1 from public.producto_enlace e where e.producto_bodega_id=p_producto_origen_id
      and e.producto_sede_id=p_producto_destino_id and e.sede='plaza' and e.factor=1) then
    raise exception 'No existe un enlace de producto uno a uno entre Bodega y Local 1.';
  end if;
  if p_lote_id is not null and not exists(select 1 from public.producto_lotes l where l.id=p_lote_id and l.producto_id=p_producto_origen_id) then
    raise exception 'El lote no pertenece al producto de origen.';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_producto_origen_id::text||':'||p_ubicacion_origen_id::text||':'||coalesce(p_lote_id::text,'-'),0));
  select coalesce(sum(cantidad),0) into v_hay from stock_internal.movimientos
   where producto_id=p_producto_origen_id and ubicacion_id=p_ubicacion_origen_id and lote_id is not distinct from p_lote_id;
  if v_hay<p_cantidad then raise exception 'Existencia insuficiente en Bodega: disponible %, solicitado %.',v_hay,p_cantidad; end if;
  v_ref:='transferencia:'||p_transferencia_id::text;
  insert into stock_internal.transferencias(id,producto_origen_id,producto_destino_id,ubicacion_origen_id,ubicacion_destino_id,lote_id,cantidad,referencia,clave_idempotencia)
  values(p_transferencia_id,p_producto_origen_id,p_producto_destino_id,p_ubicacion_origen_id,p_ubicacion_destino_id,p_lote_id,p_cantidad,v_ref,v_ref)
  on conflict(id) do nothing;
  select * into v_existente from stock_internal.transferencias where id=p_transferencia_id;
  if v_existente.producto_origen_id<>p_producto_origen_id or v_existente.producto_destino_id<>p_producto_destino_id
   or v_existente.ubicacion_origen_id<>p_ubicacion_origen_id or v_existente.ubicacion_destino_id<>p_ubicacion_destino_id
   or v_existente.lote_id is distinct from p_lote_id or v_existente.cantidad<>p_cantidad then
    raise exception 'La clave de transferencia ya existe con otra carga.';
  end if;
  if not exists(select 1 from stock_internal.movimientos where transferencia_id=p_transferencia_id) then
    insert into stock_internal.movimientos(producto_id,sede,ubicacion_id,lote_id,cantidad,tipo,actor,referencia,transferencia_id,clave_idempotencia,metadata)
    values
      (p_producto_origen_id,v_sede_origen,p_ubicacion_origen_id,p_lote_id,-p_cantidad,'transferencia','sistema:interno',v_ref,p_transferencia_id,v_ref||':salida',jsonb_build_object('producto_destino_id',p_producto_destino_id)),
      (p_producto_destino_id,v_sede_destino,p_ubicacion_destino_id,p_lote_id,p_cantidad,'transferencia','sistema:interno',v_ref,p_transferencia_id,v_ref||':entrada',jsonb_build_object('producto_origen_id',p_producto_origen_id));
  end if;
  return p_transferencia_id;
end $function$;
revoke all on function stock_internal.transferir(uuid,bigint,bigint,uuid,uuid,numeric,bigint) from public,anon,authenticated,service_role;
commit;
