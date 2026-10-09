-- Pruebas B2.4.1. Toda escritura sintética vive dentro de BEGIN/ROLLBACK.
begin;

create temporary table b241_before on commit drop as
select
  (select count(*) from public.productos) productos,
  (select coalesce(sum(stock_actual),0) from public.productos) stock,
  (select count(*) from public.producto_lotes) lotes,
  (select count(*) from stock_internal.movimientos) movimientos,
  (select coalesce(sum(cantidad),0) from stock_internal.existencias) ledger,
  (select count(*) from stock_internal.transferencias) transferencias;

create temporary table b241_context on commit drop as
select e.producto_id,
       u.id as sin_asignar_id,
       (select id from stock_internal.ubicaciones where sede='plaza' and codigo='cocina_fria') cocina_fria_id,
       (select id from stock_internal.ubicaciones where sede='plaza' and codigo='cafeteria') cafeteria_id,
       (select id from stock_internal.ubicaciones where sede='plaza' and codigo='heladeria') heladeria_id,
       (select id from stock_internal.ubicaciones where sede='central' and codigo='bodega_central') bodega_id
from stock_internal.existencias e
join stock_internal.ubicaciones u on u.id=e.ubicacion_id
where u.sede='plaza' and u.codigo='sin_asignar' and e.lote_id is null and e.cantidad>=10
  and not exists(select 1 from public.producto_lotes l where l.producto_id=e.producto_id and l.cantidad>0)
order by e.cantidad desc
limit 1;

do $setup$
declare v_actor uuid;
begin
  if not exists(select 1 from b241_context) then
    raise exception 'B2.4.1: no existe producto sintético seguro con saldo sin lote.';
  end if;
  select auth_uid into v_actor from authz_internal.propietario_raiz where singleton;
  insert into public.areas_operativas(id,sede,codigo,nombre,estado,orden,creado_por,actualizado_por)
  values
    ('b2410000-0000-4000-8000-000000000001','plaza','b241_futura','B2.4.1 futura','activa',900,v_actor,v_actor),
    ('b2410000-0000-4000-8000-000000000002','plaza','b241_archivada','B2.4.1 archivada','activa',901,v_actor,v_actor);
  update public.areas_operativas set estado='archivada',archivado_por=v_actor,archivado_at=now()
   where id='b2410000-0000-4000-8000-000000000002';
  insert into stock_internal.ubicaciones(id,sede,codigo,nombre,area_id,activa) values
    ('b2411000-0000-4000-8000-000000000001','plaza','b241_futura','B2.4.1 futura','b2410000-0000-4000-8000-000000000001',true),
    ('b2411000-0000-4000-8000-000000000002','plaza','b241_archivada','B2.4.1 archivada','b2410000-0000-4000-8000-000000000002',false),
    ('b2411000-0000-4000-8000-000000000003','plaza','b241_sin_vinculo','B2.4.1 sin vínculo',null,true);
end
$setup$;

create function pg_temp.b241_transfer(p_id uuid,p_destino uuid,p_cantidad numeric default 0.01)
returns uuid language plpgsql as $fn$
declare v b241_context;
begin
  select * into strict v from b241_context;
  return stock_internal.transferir_aplicar(p_id,v.producto_id,v.producto_id,
    v.sin_asignar_id,p_destino,p_cantidad,null,'prueba B2.4.1','b2.4.1-test@internal.invalid');
end
$fn$;

create function pg_temp.b241_debe_fallar(p_destino uuid,p_cantidad numeric,p_esperado text,p_caso text)
returns void language plpgsql as $fn$
begin
  begin
    perform pg_temp.b241_transfer(gen_random_uuid(),p_destino,p_cantidad);
    raise exception 'B2.4.1 esperaba rechazo: %',p_caso;
  exception when others then
    if sqlerrm like 'B2.4.1 esperaba rechazo:%' then raise; end if;
    if position(p_esperado in sqlerrm)=0 then
      raise exception 'B2.4.1 rechazo inesperado en %: %',p_caso,sqlerrm;
    end if;
  end;
end
$fn$;

do $tests$
declare v b241_context; v_id uuid:=gen_random_uuid(); v_count bigint;
begin
  select * into strict v from b241_context;
  perform pg_temp.b241_transfer(gen_random_uuid(),v.cocina_fria_id);
  perform pg_temp.b241_transfer(gen_random_uuid(),v.cafeteria_id);
  perform pg_temp.b241_transfer(gen_random_uuid(),v.heladeria_id);
  perform pg_temp.b241_transfer(gen_random_uuid(),'b2411000-0000-4000-8000-000000000001');

  perform pg_temp.b241_debe_fallar('b2411000-0000-4000-8000-000000000002',0.01,'Ubicación inexistente o inactiva','área archivada');
  perform pg_temp.b241_debe_fallar('b241ffff-ffff-4fff-8fff-ffffffffffff',0.01,'Ubicación inexistente o inactiva','ubicación inexistente');
  perform pg_temp.b241_debe_fallar('b2411000-0000-4000-8000-000000000003',0.01,'El destino debe ser un área operativa activa','ubicación sin vínculo');
  perform pg_temp.b241_debe_fallar(v.bodega_id,0.01,'Transferencia bloqueada','sede incorrecta');
  perform pg_temp.b241_debe_fallar(v.cocina_fria_id,999999999,'Existencia insuficiente','saldo insuficiente');

  perform pg_temp.b241_transfer(v_id,v.heladeria_id);
  perform pg_temp.b241_transfer(v_id,v.heladeria_id);
  select count(*) into v_count from stock_internal.transferencias where id=v_id;
  if v_count<>1 or (select count(*) from stock_internal.movimientos where transferencia_id=v_id)<>2 then
    raise exception 'B2.4.1 falló la idempotencia.';
  end if;

end
$tests$;

set constraints all immediate;

do $assertions$
begin
  if (select count(*) from stock_internal.transferencias)<>(select transferencias+5 from b241_before) then
    raise exception 'B2.4.1 produjo un número inesperado de transferencias.';
  end if;
  if (select coalesce(sum(cantidad),0) from stock_internal.existencias)<>(select ledger from b241_before) then
    raise exception 'B2.4.1 alteró el total físico del ledger.';
  end if;
  if (select coalesce(sum(stock_actual),0) from public.productos)<>(select stock from b241_before) then
    raise exception 'B2.4.1 alteró el stock global proyectado.';
  end if;
end
$assertions$;

rollback;

select
  (select count(*) from public.productos) productos,
  (select coalesce(sum(stock_actual),0) from public.productos) stock,
  (select count(*) from public.producto_lotes) lotes,
  (select count(*) from stock_internal.movimientos) movimientos,
  (select coalesce(sum(cantidad),0) from stock_internal.existencias) ledger,
  (select count(*) from stock_internal.transferencias) transferencias,
  (select count(*) from public.areas_operativas where codigo like 'b241_%') areas_sinteticas,
  (select count(*) from stock_internal.ubicaciones where codigo like 'b241_%') ubicaciones_sinteticas;
