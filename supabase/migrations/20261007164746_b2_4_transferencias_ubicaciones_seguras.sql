-- B2.4 — motor atómico de transferencias por ubicación.
-- Proyecto autorizado: Llamita Plus (iuryhsjucblmebdogewa).
-- Sin interfaz, Fudo ni Lama real. Solo central/plaza y ubicaciones activas.

-- El corte inicial dejó el detalle de lotes en producto_lotes, pero las
-- aperturas del libro fueron agregadas por producto. Antes de transferir,
-- este motor reclasifica en el libro el detalle legado de lote desde el saldo
-- sin lote, preservando la suma y la fecha real. No modifica producto_lotes.
alter table stock_internal.movimientos
  drop constraint if exists movimientos_tipo_check;
alter table stock_internal.movimientos
  add constraint movimientos_tipo_check
  check (tipo in ('entrada','salida','transferencia','merma','ajuste','apertura_migracion','clasificacion_lote'));

alter table stock_internal.transferencias
  add column if not exists actor text,
  add column if not exists motivo text,
  add column if not exists reversa_de uuid null references stock_internal.transferencias(id) on delete restrict;
create unique index if not exists stock_transferencias_reversa_de_uidx
  on stock_internal.transferencias(reversa_de) where reversa_de is not null;

create table if not exists stock_internal.lote_continuidad (
  lote_canonico_id bigint not null references public.producto_lotes(id) on delete restrict,
  producto_id bigint not null references public.productos(id) on delete restrict,
  sede text not null check (sede in ('central','plaza')),
  vencimiento date null,
  establecido_por text not null,
  transferencia_id uuid not null references stock_internal.transferencias(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (lote_canonico_id,producto_id)
);
create index if not exists stock_lote_continuidad_producto_idx
  on stock_internal.lote_continuidad(producto_id,lote_canonico_id);
create index if not exists stock_lote_continuidad_transferencia_idx
  on stock_internal.lote_continuidad(transferencia_id);
alter table stock_internal.lote_continuidad enable row level security;
revoke all on stock_internal.lote_continuidad from public,anon,authenticated,service_role;
drop policy if exists stock_interno_lote_continuidad_deny on stock_internal.lote_continuidad;
create policy stock_interno_lote_continuidad_deny on stock_internal.lote_continuidad
  as restrictive for all to public using (false) with check (false);

create or replace function stock_internal.validar_par_transferencia()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_id uuid;
  v_t stock_internal.transferencias;
  v_total integer;
  v_salida integer;
  v_entrada integer;
begin
  if tg_table_name='transferencias' then
    v_id := new.id;
  else
    v_id := new.transferencia_id;
  end if;
  if v_id is null then return null; end if;

  select * into v_t from stock_internal.transferencias where id=v_id;
  if not found then
    raise exception 'Transferencia % sin encabezado auditable.',v_id using errcode='23514';
  end if;

  select count(*),
         count(*) filter (where m.producto_id=v_t.producto_origen_id
           and m.ubicacion_id=v_t.ubicacion_origen_id and m.cantidad=-v_t.cantidad
           and m.clave_idempotencia=v_t.clave_idempotencia||':salida'),
         count(*) filter (where m.producto_id=v_t.producto_destino_id
           and m.ubicacion_id=v_t.ubicacion_destino_id and m.cantidad=v_t.cantidad
           and m.clave_idempotencia=v_t.clave_idempotencia||':entrada')
    into v_total,v_salida,v_entrada
    from stock_internal.movimientos m where m.transferencia_id=v_id
      and m.tipo='transferencia' and m.lote_id is not distinct from v_t.lote_id
      and m.referencia=v_t.referencia and m.actor=v_t.actor
      and m.metadata->>'motivo'=v_t.motivo;
  if v_total<>2 or v_salida<>1 or v_entrada<>1 then
    raise exception 'Transferencia % debe tener una salida y una entrada balanceadas.',v_id using errcode='23514';
  end if;
  return null;
end
$function$;
revoke all on function stock_internal.validar_par_transferencia() from public,anon,authenticated,service_role;
drop trigger if exists stock_transferencias_par_header on stock_internal.transferencias;
create constraint trigger stock_transferencias_par_header
after insert on stock_internal.transferencias
deferrable initially deferred for each row
execute function stock_internal.validar_par_transferencia();
drop trigger if exists stock_transferencias_par_movimiento on stock_internal.movimientos;
create constraint trigger stock_transferencias_par_movimiento
after insert on stock_internal.movimientos
deferrable initially deferred for each row
execute function stock_internal.validar_par_transferencia();

create or replace function stock_internal.transferir_aplicar(
  p_transferencia_id uuid,
  p_producto_origen_id bigint,
  p_producto_destino_id bigint,
  p_ubicacion_origen_id uuid,
  p_ubicacion_destino_id uuid,
  p_cantidad numeric,
  p_lote_id bigint,
  p_motivo text,
  p_actor text
) returns uuid
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_sede_origen text;
  v_sede_destino text;
  v_codigo_origen text;
  v_codigo_destino text;
  v_area_origen uuid;
  v_area_destino uuid;
  v_ref text;
  v_existente stock_internal.transferencias;
  v_origen public.productos;
  v_destino public.productos;
  v_lote record;
  v_vencimiento date;
  v_origen_sin_lote numeric;
  v_lotes_pendientes numeric;
  v_saldo_origen numeric;
begin
  if p_transferencia_id is null then raise exception 'La referencia de transferencia es obligatoria.'; end if;
  if p_producto_origen_id is null or p_producto_destino_id is null
     or p_ubicacion_origen_id is null or p_ubicacion_destino_id is null then
    raise exception 'Producto y ubicaciones de origen y destino son obligatorios.';
  end if;
  if p_cantidad is null or p_cantidad<=0 then raise exception 'La cantidad debe ser mayor que cero.'; end if;
  if coalesce(length(btrim(p_motivo)),0) not between 1 and 500 then
    raise exception 'El motivo debe contener entre 1 y 500 caracteres.';
  end if;
  if coalesce(length(btrim(p_actor)),0)=0 then raise exception 'No fue posible identificar al usuario.'; end if;

  v_ref := 'transferencia:'||p_transferencia_id::text;

  -- La referencia es idempotente incluso si la operación ya consumió el saldo.
  perform pg_advisory_xact_lock(hashtextextended('transfer-reference:'||p_transferencia_id::text,0));
  select * into v_existente from stock_internal.transferencias
   where id=p_transferencia_id for update;
  if found then
    if v_existente.producto_origen_id<>p_producto_origen_id
       or v_existente.producto_destino_id<>p_producto_destino_id
       or v_existente.ubicacion_origen_id<>p_ubicacion_origen_id
       or v_existente.ubicacion_destino_id<>p_ubicacion_destino_id
       or v_existente.lote_id is distinct from p_lote_id
       or v_existente.cantidad<>p_cantidad
       or v_existente.motivo is distinct from btrim(p_motivo)
       or v_existente.actor is distinct from lower(btrim(p_actor)) then
      raise exception 'La referencia ya existe con otra carga.' using errcode='23505';
    end if;
    if (select count(*) from stock_internal.movimientos m
         where m.transferencia_id=p_transferencia_id and m.tipo='transferencia')<>2 then
      raise exception 'La referencia existente no tiene su par íntegro; requiere revisión.' using errcode='23514';
    end if;
    return p_transferencia_id;
  end if;

  select u.sede,u.codigo,u.area_id into v_sede_origen,v_codigo_origen,v_area_origen
    from stock_internal.ubicaciones u where u.id=p_ubicacion_origen_id and u.activa for share;
  select u.sede,u.codigo,u.area_id into v_sede_destino,v_codigo_destino,v_area_destino
    from stock_internal.ubicaciones u where u.id=p_ubicacion_destino_id and u.activa for share;
  if v_sede_origen is null or v_sede_destino is null then
    raise exception 'Ubicación inexistente o inactiva.';
  end if;
  if p_ubicacion_origen_id=p_ubicacion_destino_id then
    raise exception 'El origen y el destino deben ser ubicaciones distintas.';
  end if;
  if v_sede_origen not in ('central','plaza') or v_sede_destino<>'plaza' then
    raise exception 'Transferencia bloqueada: angamos, bodega histórica y otros nodos están fuera del motor B2.4.';
  end if;
  if v_codigo_destino not in ('cocina_fria','cocina_caliente','barra','cafeteria') or v_area_destino is null
     or not exists(select 1 from public.areas_operativas a where a.id=v_area_destino and a.sede='plaza' and a.estado='activa') then
    raise exception 'El destino debe ser un área operativa activa de Local 1.';
  end if;
  if v_sede_origen='central' then
    if v_codigo_origen<>'bodega_central' or v_area_origen is not null then
      raise exception 'El único origen permitido desde Bodega es Bodega central.';
    end if;
  elsif v_codigo_origen<>'sin_asignar' then
    if v_codigo_origen not in ('cocina_fria','cocina_caliente','barra','cafeteria') or v_area_origen is null
       or not exists(select 1 from public.areas_operativas a where a.id=v_area_origen and a.sede='plaza' and a.estado='activa') then
      raise exception 'El origen de Local 1 debe ser Sin asignar o un área activa.';
    end if;
  end if;

  -- El lock común cubre transferencias con lote y sin lote del mismo producto
  -- y ubicación, evitando sobreventa al mezclar ambos modos.
  perform pg_advisory_xact_lock(hashtextextended(
    'stock-location:'||p_producto_origen_id::text||':'||p_ubicacion_origen_id::text,0));
  perform 1 from public.productos p where p.id in (p_producto_origen_id,p_producto_destino_id)
   order by p.id for update;
  select * into v_origen from public.productos where id=p_producto_origen_id;
  select * into v_destino from public.productos where id=p_producto_destino_id;
  if v_origen.id is null or v_destino.id is null then raise exception 'Producto inexistente.'; end if;
  if v_origen.sede<>v_sede_origen or v_destino.sede<>v_sede_destino then
    raise exception 'Producto y ubicación no pertenecen a la misma sede.';
  end if;
  if v_sede_origen='central' then
    if not exists(select 1 from public.producto_enlace e
      where e.producto_bodega_id=p_producto_origen_id and e.producto_sede_id=p_producto_destino_id
        and e.sede='plaza' and e.factor=1) then
      raise exception 'No existe un enlace explícito uno a uno entre el producto de Bodega y el de Local 1.';
    end if;
  elsif p_producto_origen_id<>p_producto_destino_id then
    raise exception 'Dentro de Local 1 la transferencia conserva el mismo producto.';
  end if;

  -- Clasifica en el libro los lotes legados, sin cambiar su tabla ni sumar stock.
  select coalesce(sum(m.cantidad),0) into v_origen_sin_lote
    from stock_internal.movimientos m where m.producto_id=p_producto_origen_id
      and m.ubicacion_id=p_ubicacion_origen_id and m.lote_id is null;
  select coalesce(sum(l.cantidad),0) into v_lotes_pendientes
    from public.producto_lotes l
   where l.producto_id=p_producto_origen_id and l.cantidad>0
     and not exists(select 1 from stock_internal.movimientos m
       where m.producto_id=p_producto_origen_id and m.ubicacion_id=p_ubicacion_origen_id and m.lote_id=l.id);
  if v_lotes_pendientes>v_origen_sin_lote then
    raise exception 'El detalle de lotes supera el saldo sin lote del libro; transferencia bloqueada para conciliación.';
  end if;
  for v_lote in
    select l.id,l.cantidad,l.vencimiento from public.producto_lotes l
    where l.producto_id=p_producto_origen_id and l.cantidad>0
      and not exists(select 1 from stock_internal.movimientos m
        where m.producto_id=p_producto_origen_id and m.ubicacion_id=p_ubicacion_origen_id and m.lote_id=l.id)
    order by l.id
  loop
    insert into stock_internal.movimientos(
      producto_id,sede,ubicacion_id,lote_id,cantidad,tipo,actor,referencia,transferencia_id,clave_idempotencia,metadata)
    values(p_producto_origen_id,v_sede_origen,p_ubicacion_origen_id,null,-v_lote.cantidad,
      'clasificacion_lote',lower(btrim(p_actor)),
      'clasificacion_lote:'||p_producto_origen_id||':'||p_ubicacion_origen_id||':'||v_lote.id,
      null,'clasificacion_lote:'||p_producto_origen_id||':'||p_ubicacion_origen_id||':'||v_lote.id||':salida',
      jsonb_build_object('lote_canonico_id',v_lote.id,'vencimiento',v_lote.vencimiento,'transferencia_solicitada',p_transferencia_id,'motivo',btrim(p_motivo)));
    insert into stock_internal.movimientos(
      producto_id,sede,ubicacion_id,lote_id,cantidad,tipo,actor,referencia,transferencia_id,clave_idempotencia,metadata)
    values(p_producto_origen_id,v_sede_origen,p_ubicacion_origen_id,v_lote.id,v_lote.cantidad,
      'clasificacion_lote',lower(btrim(p_actor)),
      'clasificacion_lote:'||p_producto_origen_id||':'||p_ubicacion_origen_id||':'||v_lote.id,
      null,'clasificacion_lote:'||p_producto_origen_id||':'||p_ubicacion_origen_id||':'||v_lote.id||':entrada',
      jsonb_build_object('lote_canonico_id',v_lote.id,'vencimiento',v_lote.vencimiento,'transferencia_solicitada',p_transferencia_id,'motivo',btrim(p_motivo)));
  end loop;

  if p_lote_id is null then
    select coalesce(sum(m.cantidad),0) into v_saldo_origen
      from stock_internal.movimientos m where m.producto_id=p_producto_origen_id
        and m.ubicacion_id=p_ubicacion_origen_id and m.lote_id is null;
  else
    select l.vencimiento into v_vencimiento from public.producto_lotes l where l.id=p_lote_id;
    if not found and not exists(select 1 from stock_internal.lote_continuidad c
       where c.lote_canonico_id=p_lote_id and c.producto_id=p_producto_origen_id) then
      raise exception 'El lote no pertenece ni tiene continuidad registrada para el producto de origen.';
    end if;
    select coalesce(sum(m.cantidad),0) into v_saldo_origen
      from stock_internal.movimientos m where m.producto_id=p_producto_origen_id
        and m.ubicacion_id=p_ubicacion_origen_id and m.lote_id=p_lote_id;
    if v_saldo_origen<0 then raise exception 'El saldo del lote de origen ya es negativo; transferencia bloqueada.'; end if;
  end if;
  if v_saldo_origen<p_cantidad then
    raise exception 'Existencia insuficiente en la ubicación de origen: disponible %, solicitado %.',v_saldo_origen,p_cantidad;
  end if;

  insert into stock_internal.transferencias(
    id,producto_origen_id,producto_destino_id,ubicacion_origen_id,ubicacion_destino_id,
    lote_id,cantidad,referencia,clave_idempotencia,actor,motivo)
  values(p_transferencia_id,p_producto_origen_id,p_producto_destino_id,p_ubicacion_origen_id,p_ubicacion_destino_id,
    p_lote_id,p_cantidad,v_ref,v_ref,lower(btrim(p_actor)),btrim(p_motivo));

  if p_lote_id is not null then
    if v_vencimiento is null then
      select c.vencimiento into v_vencimiento from stock_internal.lote_continuidad c
       where c.lote_canonico_id=p_lote_id and c.producto_id=p_producto_origen_id;
    end if;
    insert into stock_internal.lote_continuidad(lote_canonico_id,producto_id,sede,vencimiento,establecido_por,transferencia_id)
    values(p_lote_id,p_producto_origen_id,v_sede_origen,v_vencimiento,lower(btrim(p_actor)),p_transferencia_id)
    on conflict(lote_canonico_id,producto_id) do nothing;
    insert into stock_internal.lote_continuidad(lote_canonico_id,producto_id,sede,vencimiento,establecido_por,transferencia_id)
    values(p_lote_id,p_producto_destino_id,v_sede_destino,v_vencimiento,lower(btrim(p_actor)),p_transferencia_id)
    on conflict(lote_canonico_id,producto_id) do nothing;
    if exists(select 1 from stock_internal.lote_continuidad c where c.lote_canonico_id=p_lote_id
       and c.producto_id in (p_producto_origen_id,p_producto_destino_id)
       and (c.vencimiento is distinct from v_vencimiento or c.sede not in (v_sede_origen,v_sede_destino))) then
      raise exception 'La continuidad registrada del lote no coincide con producto, sede o vencimiento.';
    end if;
  end if;

  insert into stock_internal.movimientos(
    producto_id,sede,ubicacion_id,lote_id,cantidad,tipo,actor,referencia,transferencia_id,clave_idempotencia,metadata)
  values(p_producto_origen_id,v_sede_origen,p_ubicacion_origen_id,p_lote_id,-p_cantidad,'transferencia',
    lower(btrim(p_actor)),v_ref,p_transferencia_id,v_ref||':salida',
    jsonb_build_object('lado','salida','producto_contraparte_id',p_producto_destino_id,
      'ubicacion_contraparte_id',p_ubicacion_destino_id,'motivo',btrim(p_motivo),'vencimiento',v_vencimiento));
  insert into stock_internal.movimientos(
    producto_id,sede,ubicacion_id,lote_id,cantidad,tipo,actor,referencia,transferencia_id,clave_idempotencia,metadata)
  values(p_producto_destino_id,v_sede_destino,p_ubicacion_destino_id,p_lote_id,p_cantidad,'transferencia',
    lower(btrim(p_actor)),v_ref,p_transferencia_id,v_ref||':entrada',
    jsonb_build_object('lado','entrada','producto_contraparte_id',p_producto_origen_id,
      'ubicacion_contraparte_id',p_ubicacion_origen_id,'motivo',btrim(p_motivo),'vencimiento',v_vencimiento));
  return p_transferencia_id;
end
$function$;

-- Retira la vía antigua, que no llevaba actor/motivo ni admitía Local 1→áreas.
create or replace function stock_internal.transferir(
  p_transferencia_id uuid,p_producto_origen_id bigint,p_producto_destino_id bigint,
  p_ubicacion_origen_id uuid,p_ubicacion_destino_id uuid,p_cantidad numeric,p_lote_id bigint default null
) returns uuid language plpgsql security definer set search_path=''
as $function$
begin
  raise exception 'La firma antigua de transferencia está retirada; use el RPC autenticado stock_transferir.' using errcode='42501';
end
$function$;
revoke all on function stock_internal.transferir(uuid,bigint,bigint,uuid,uuid,numeric,bigint) from public,anon,authenticated,service_role;

create or replace function stock_internal.transferir(
  p_transferencia_id uuid,p_producto_origen_id bigint,p_producto_destino_id bigint,
  p_ubicacion_origen_id uuid,p_ubicacion_destino_id uuid,p_cantidad numeric,
  p_lote_id bigint,p_motivo text,p_actor text
) returns uuid language plpgsql security definer set search_path=''
as $function$
declare v_claims jsonb; v_email text;
begin
  v_claims:=auth.jwt();
  v_email:=lower(btrim(coalesce(v_claims->>'email','')));
  if auth.uid() is null or v_claims->>'role'<>'authenticated' or v_email=''
     or v_email is distinct from lower(btrim(p_actor)) then
    raise exception 'Se requiere una sesión autenticada coincidente con el actor.' using errcode='42501';
  end if;
  if not exists(select 1 from public.app_permisos a where lower(a.correo)=v_email and a.puede_editar is true) then
    raise exception 'Tu cuenta no tiene permiso para editar inventario.' using errcode='42501';
  end if;
  return stock_internal.transferir_aplicar(p_transferencia_id,p_producto_origen_id,
    p_producto_destino_id,p_ubicacion_origen_id,p_ubicacion_destino_id,p_cantidad,p_lote_id,p_motivo,v_email);
end
$function$;
revoke all on function stock_internal.transferir_aplicar(uuid,bigint,bigint,uuid,uuid,numeric,bigint,text,text) from public,anon,authenticated,service_role;
revoke all on function stock_internal.transferir(uuid,bigint,bigint,uuid,uuid,numeric,bigint,text,text) from public,anon,authenticated,service_role;
revoke all on schema stock_internal from public,anon,authenticated,service_role;
grant usage on schema stock_internal to authenticated;
grant execute on function stock_internal.transferir(uuid,bigint,bigint,uuid,uuid,numeric,bigint,text,text) to authenticated;

create or replace function public.stock_transferir(
  p_transferencia_id uuid,
  p_producto_origen_id bigint,
  p_producto_destino_id bigint,
  p_ubicacion_origen_id uuid,
  p_ubicacion_destino_id uuid,
  p_cantidad numeric,
  p_motivo text,
  p_lote_id bigint default null
) returns uuid
language plpgsql
security invoker
set search_path=''
as $function$
declare
  v_claims jsonb;
  v_actor text;
begin
  v_claims := auth.jwt();
  v_actor := lower(btrim(coalesce(v_claims->>'email','')));
  if auth.uid() is null or v_claims->>'role'<>'authenticated' or v_actor='' then
    raise exception 'Se requiere una sesión autenticada para transferir existencias.' using errcode='42501';
  end if;
  if not exists(select 1 from public.app_permisos a
    where lower(a.correo)=v_actor and a.puede_editar is true) then
    raise exception 'Tu cuenta no tiene permiso para editar inventario.' using errcode='42501';
  end if;
  return stock_internal.transferir(p_transferencia_id,p_producto_origen_id,p_producto_destino_id,
    p_ubicacion_origen_id,p_ubicacion_destino_id,p_cantidad,p_lote_id,p_motivo,v_actor);
end
$function$;
revoke all on function public.stock_transferir(uuid,bigint,bigint,uuid,uuid,numeric,text,bigint) from public,anon,authenticated,service_role;
grant execute on function public.stock_transferir(uuid,bigint,bigint,uuid,uuid,numeric,text,bigint) to authenticated;
