-- Dónde se ejecuta: solo Supabase Llamita Plus (iuryhsjucblmebdogewa).
-- Bloque Hermes: B2.3, corte coordinado de central y plaza.
-- Ejecución: una sola vez mediante Supabase apply_migration, después de revisar
-- el corte y los conteos de apertura. La migración toma locks antes de conciliar.
-- Qué cambia: crea un libro privado e inmutable, abre saldos de central/plaza,
-- proyecta el total compatible y bloquea escritores antiguos y modos reales.
-- Qué no cambia: cantidades comerciales, lotes, movimientos, repartos, recetas,
-- permisos, Fudo remoto y datos de angamos o la clave histórica bodega.
-- Resultado esperado: central -> Bodega central; plaza -> Sin asignar.

create schema if not exists stock_internal;
revoke all on schema stock_internal from public, anon, authenticated, service_role;

create table if not exists stock_internal.ubicaciones (
  id uuid primary key default gen_random_uuid(),
  sede text not null check (sede in ('central','plaza')),
  codigo text not null,
  nombre text not null,
  area_id uuid null references public.areas_operativas(id) on delete restrict,
  activa boolean not null default true,
  created_at timestamptz not null default now(),
  unique (sede, codigo),
  unique (id, sede)
);

insert into stock_internal.ubicaciones (sede,codigo,nombre,area_id) values
 ('central','bodega_central','Bodega central',null),
 ('plaza','sin_asignar','Sin asignar',null),
 ('plaza','cocina_fria','Cocina fría',(select id from public.areas_operativas where sede='plaza' and codigo='cocina_fria')),
 ('plaza','cocina_caliente','Cocina caliente',(select id from public.areas_operativas where sede='plaza' and codigo='cocina_caliente')),
 ('plaza','barra','Barra',(select id from public.areas_operativas where sede='plaza' and codigo='barra')),
 ('plaza','cafeteria','Cafetería',(select id from public.areas_operativas where sede='plaza' and codigo='cafeteria'))
on conflict (sede,codigo) do update set nombre=excluded.nombre, area_id=excluded.area_id;

do $check_areas$
begin
  if exists (select 1 from stock_internal.ubicaciones where sede='plaza'
      and codigo in ('cocina_fria','cocina_caliente','barra','cafeteria') and area_id is null) then
    raise exception 'B2.3 detenido: falta una de las cuatro áreas confirmadas de plaza.';
  end if;
  if exists (select 1 from stock_internal.ubicaciones where sede not in ('central','plaza')) then
    raise exception 'B2.3 detenido: ubicación fuera de alcance.';
  end if;
end $check_areas$;

create table if not exists stock_internal.aperturas (
  id uuid primary key default gen_random_uuid(),
  clave text not null unique,
  origen text not null check (origen='migracion_b2_3'),
  ejecutada_at timestamptz not null default now(),
  ejecutada_por text not null default 'sistema:migracion_b2_3',
  conteos_antes jsonb not null,
  conteos_despues jsonb null,
  referencia text not null
);

create table if not exists stock_internal.movimientos (
  id bigint generated always as identity primary key,
  producto_id bigint not null references public.productos(id) on delete restrict,
  sede text not null check (sede in ('central','plaza')),
  ubicacion_id uuid not null,
  lote_id bigint null,
  cantidad numeric not null check (cantidad <> 0),
  tipo text not null check (tipo in ('entrada','salida','transferencia','merma','ajuste','apertura_migracion')),
  ocurrido_at timestamptz not null default now(),
  actor text not null,
  referencia text not null,
  transferencia_id uuid null,
  clave_idempotencia text not null unique,
  metadata jsonb not null default '{}'::jsonb,
  foreign key (ubicacion_id,sede) references stock_internal.ubicaciones(id,sede) on delete restrict
);
create index if not exists stock_movimientos_producto_ubicacion_idx
  on stock_internal.movimientos(producto_id,ubicacion_id,lote_id);
create index if not exists stock_movimientos_transferencia_idx
  on stock_internal.movimientos(transferencia_id) where transferencia_id is not null;

create table if not exists stock_internal.transferencias (
  id uuid primary key,
  producto_origen_id bigint not null references public.productos(id) on delete restrict,
  producto_destino_id bigint not null references public.productos(id) on delete restrict,
  ubicacion_origen_id uuid not null references stock_internal.ubicaciones(id) on delete restrict,
  ubicacion_destino_id uuid not null references stock_internal.ubicaciones(id) on delete restrict,
  lote_id bigint null,
  cantidad numeric not null check (cantidad > 0),
  referencia text not null unique,
  clave_idempotencia text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists stock_internal.permiso_proyeccion (
  backend_pid integer not null,
  txid bigint not null,
  producto_id bigint not null,
  primary key (backend_pid,txid,producto_id)
);

alter table stock_internal.ubicaciones enable row level security;
alter table stock_internal.aperturas enable row level security;
alter table stock_internal.movimientos enable row level security;
alter table stock_internal.transferencias enable row level security;
alter table stock_internal.permiso_proyeccion enable row level security;
revoke all on all tables in schema stock_internal from public, anon, authenticated, service_role;
revoke all on all sequences in schema stock_internal from public, anon, authenticated, service_role;
alter default privileges in schema stock_internal revoke all on tables from public, anon, authenticated, service_role;
alter default privileges in schema stock_internal revoke all on sequences from public, anon, authenticated, service_role;

create or replace view stock_internal.existencias
with (security_invoker=true) as
select producto_id,sede,ubicacion_id,lote_id,sum(cantidad)::numeric as cantidad
from stock_internal.movimientos
group by producto_id,sede,ubicacion_id,lote_id;
revoke all on stock_internal.existencias from public, anon, authenticated, service_role;

create or replace function stock_internal.refrescar_proyeccion(p_producto_id bigint)
returns void language plpgsql security definer set search_path=''
as $function$
declare v_total numeric;
begin
  select coalesce(sum(m.cantidad),0) into v_total
  from stock_internal.movimientos m where m.producto_id=p_producto_id;
  insert into stock_internal.permiso_proyeccion(backend_pid,txid,producto_id)
  values(pg_backend_pid(),txid_current(),p_producto_id) on conflict do nothing;
  update public.productos set stock_actual=v_total::double precision where id=p_producto_id;
  delete from stock_internal.permiso_proyeccion
   where backend_pid=pg_backend_pid() and txid=txid_current() and producto_id=p_producto_id;
end $function$;

create or replace function stock_internal.trg_refrescar_proyeccion()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  perform stock_internal.refrescar_proyeccion(new.producto_id);
  return new;
end $function$;

create or replace function stock_internal.trg_proteger_stock_maestro()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_permitido boolean;
begin
  if tg_op='DELETE' then
    if old.sede in ('central','plaza') then
      raise exception 'Stock por ubicación: no se puede borrar un producto de una sede migrada.';
    end if;
    return old;
  elsif tg_op='INSERT' then
    if new.sede in ('central','plaza') then
      if coalesce(new.stock_actual,0)<>0 then
        raise exception 'Stock por ubicación: registre existencias mediante el libro, no al crear el producto.';
      end if;
      new.stock_actual:=0;
    end if;
    return new;
  end if;

  if old.sede is distinct from new.sede and (old.sede in ('central','plaza') or new.sede in ('central','plaza')) then
    raise exception 'Stock por ubicación: no se puede mover un producto entre una sede migrada y otra sede.';
  end if;
  if old.sede in ('central','plaza') and new.stock_actual is distinct from old.stock_actual then
    select exists(select 1 from stock_internal.permiso_proyeccion x
      where x.backend_pid=pg_backend_pid() and x.txid=txid_current() and x.producto_id=old.id)
      into v_permitido;
    if not v_permitido then
      raise exception 'Stock por ubicación: el saldo de Bodega/Local 1 se consulta desde el libro y no se edita directamente.';
    end if;
  end if;
  return new;
end $function$;

create or replace function stock_internal.trg_proteger_lotes_migrados()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_sede text;
begin
  if tg_op<>'INSERT' then
    select sede into v_sede from public.productos where id=old.producto_id;
    if v_sede in ('central','plaza') then
      raise exception 'Stock por ubicación: los lotes de Bodega/Local 1 están congelados hasta habilitar operaciones del libro.';
    end if;
  end if;
  if tg_op<>'DELETE' then
    select sede into v_sede from public.productos where id=new.producto_id;
    if v_sede in ('central','plaza') then
      raise exception 'Stock por ubicación: los lotes de Bodega/Local 1 están congelados hasta habilitar operaciones del libro.';
    end if;
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end $function$;

create or replace function stock_internal.trg_bloquear_modo_real()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  if new.sede in ('central','plaza') and lower(new.modo)='real' then
    raise exception 'Stock por ubicación: el modo real de Fudo/Lama sigue bloqueado para Bodega y Local 1.';
  end if;
  return new;
end $function$;

create or replace function stock_internal.trg_bloquear_fudo_aplicado()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  if new.sede in ('central','plaza') and new.aplicado then
    raise exception 'Stock por ubicación: Fudo no puede aplicar descuentos al saldo antiguo de Bodega/Local 1.';
  end if;
  return new;
end $function$;

create or replace function stock_internal.trg_bloquear_fusion_migrada()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  if exists(select 1 from public.productos p where p.id in (new.queda_id,new.se_va_id) and p.sede in ('central','plaza')) then
    raise exception 'Stock por ubicación: las fusiones están pausadas para productos de Bodega y Local 1.';
  end if;
  return new;
end $function$;

create or replace function stock_internal.trg_bloquear_restauracion_migrada()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  if new.sede in ('central','plaza') then
    raise exception 'Stock por ubicación: restaurar respaldos está pausado para Bodega y Local 1.';
  end if;
  return new;
end $function$;

create or replace function stock_internal.trg_bloquear_movimiento_legacy()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  if new.sede in ('central','plaza') then
    raise exception 'Stock por ubicación: los movimientos antiguos están pausados para Bodega y Local 1.';
  end if;
  return new;
end $function$;

create or replace function stock_internal.trg_bloquear_reparto_legacy()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_sede text; v_reparto_id bigint;
begin
  if tg_table_name='repartos' then
    v_sede:=case when tg_op='DELETE' then old.sede else new.sede end;
    if v_sede in ('central','plaza') then
      raise exception 'Stock por ubicación: los repartos antiguos están pausados para Bodega y Local 1.';
    end if;
    if tg_op='DELETE' then return old; end if;
    return new;
  end if;
  v_reparto_id:=case when tg_op='DELETE' then old.reparto_id else new.reparto_id end;
  select sede into v_sede from public.repartos where id=v_reparto_id;
  if v_sede in ('central','plaza') then
    raise exception 'Stock por ubicación: las líneas de reparto antiguo están pausadas para Bodega y Local 1.';
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end $function$;

create or replace function stock_internal.trg_inmutable()
returns trigger language plpgsql set search_path=''
as $function$
begin raise exception 'El libro de existencias es inmutable; registre un movimiento compensatorio.'; end
$function$;

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

revoke all on all functions in schema stock_internal from public, anon, authenticated, service_role;
revoke all on function stock_internal.refrescar_proyeccion(bigint) from public, anon, authenticated, service_role;
revoke all on function stock_internal.transferir(uuid,bigint,bigint,uuid,uuid,numeric,bigint) from public, anon, authenticated, service_role;
revoke all on function public.sync_stock_desde_lotes() from public, anon, authenticated, service_role;

drop trigger if exists trg_stock_ledger_immutable on stock_internal.movimientos;
create trigger trg_stock_ledger_immutable before update or delete on stock_internal.movimientos
for each row execute function stock_internal.trg_inmutable();
drop trigger if exists trg_stock_transfer_immutable on stock_internal.transferencias;
create trigger trg_stock_transfer_immutable before update or delete on stock_internal.transferencias
for each row execute function stock_internal.trg_inmutable();
drop trigger if exists trg_stock_proteger_maestro on public.productos;
create trigger trg_stock_proteger_maestro before insert or update or delete on public.productos
for each row execute function stock_internal.trg_proteger_stock_maestro();
drop trigger if exists trg_stock_proteger_lotes on public.producto_lotes;
create trigger trg_stock_proteger_lotes before insert or update or delete on public.producto_lotes
for each row execute function stock_internal.trg_proteger_lotes_migrados();
drop trigger if exists trg_stock_bloquear_fudo_real on public.fudo_sync;
create trigger trg_stock_bloquear_fudo_real before insert or update on public.fudo_sync
for each row execute function stock_internal.trg_bloquear_modo_real();
drop trigger if exists trg_stock_bloquear_lama_real on public.lama_stock_config;
create trigger trg_stock_bloquear_lama_real before insert or update on public.lama_stock_config
for each row execute function stock_internal.trg_bloquear_modo_real();
drop trigger if exists trg_stock_bloquear_fudo_aplicado on public.fudo_movimientos;
create trigger trg_stock_bloquear_fudo_aplicado before insert or update on public.fudo_movimientos
for each row execute function stock_internal.trg_bloquear_fudo_aplicado();
drop trigger if exists trg_stock_bloquear_fusion on public.fusiones;
create trigger trg_stock_bloquear_fusion before insert or update on public.fusiones
for each row execute function stock_internal.trg_bloquear_fusion_migrada();
drop trigger if exists trg_stock_bloquear_restauracion on public.restauraciones;
create trigger trg_stock_bloquear_restauracion before insert or update on public.restauraciones
for each row execute function stock_internal.trg_bloquear_restauracion_migrada();
drop trigger if exists trg_stock_bloquear_movimiento_legacy on public.movimientos;
create trigger trg_stock_bloquear_movimiento_legacy before insert on public.movimientos
for each row execute function stock_internal.trg_bloquear_movimiento_legacy();
drop trigger if exists trg_stock_bloquear_repartos on public.repartos;
create trigger trg_stock_bloquear_repartos before insert or update or delete on public.repartos
for each row execute function stock_internal.trg_bloquear_reparto_legacy();
drop trigger if exists trg_stock_bloquear_reparto_items on public.reparto_items;
create trigger trg_stock_bloquear_reparto_items before insert or update or delete on public.reparto_items
for each row execute function stock_internal.trg_bloquear_reparto_legacy();

-- La política permisiva histórica daba DML completo a anon/authenticated.
-- Se conserva lectura y escritura legacy solo para sedes aún no migradas.
drop policy if exists "producto_lotes all" on public.producto_lotes;
drop policy if exists "producto_lotes lectura legacy" on public.producto_lotes;
drop policy if exists "producto_lotes alta sedes no migradas" on public.producto_lotes;
drop policy if exists "producto_lotes edicion sedes no migradas" on public.producto_lotes;
drop policy if exists "producto_lotes baja sedes no migradas" on public.producto_lotes;
create policy "producto_lotes lectura legacy" on public.producto_lotes for select to anon,authenticated using (true);
create policy "producto_lotes alta sedes no migradas" on public.producto_lotes for insert to anon,authenticated
  with check (exists(select 1 from public.productos p where p.id=producto_id and p.sede not in ('central','plaza')));
create policy "producto_lotes edicion sedes no migradas" on public.producto_lotes for update to anon,authenticated
  using (exists(select 1 from public.productos p where p.id=producto_id and p.sede not in ('central','plaza')))
  with check (exists(select 1 from public.productos p where p.id=producto_id and p.sede not in ('central','plaza')));
create policy "producto_lotes baja sedes no migradas" on public.producto_lotes for delete to anon,authenticated
  using (exists(select 1 from public.productos p where p.id=producto_id and p.sede not in ('central','plaza')));
revoke truncate, trigger, references on public.productos,public.producto_lotes from public,anon,authenticated,service_role;

-- El sync histórico sigue calculando lotes en sedes antiguas; en central/plaza
-- queda convertido en no-op porque esas cantidades viven en el libro.
create or replace function public.sync_stock_desde_lotes()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_pid bigint; v_sede text;
begin
  v_pid:=coalesce(new.producto_id,old.producto_id);
  select sede into v_sede from public.productos where id=v_pid;
  if v_sede in ('central','plaza') then return null; end if;
  update public.productos p set stock_actual=coalesce((select sum(l.cantidad) from public.producto_lotes l where l.producto_id=v_pid),0),updated_at=now()
  where p.id=v_pid;
  return null;
end
$function$;

-- Las sedes migradas no pueden pasar a sincronización real de inventario.
do $precheck$
begin
  if exists(select 1 from public.fudo_sync where sede in ('central','plaza') and lower(modo)='real') then
    raise exception 'B2.3 detenido: Fudo ya está en modo real para central/plaza.';
  end if;
  if exists(select 1 from public.lama_stock_config where sede in ('central','plaza') and lower(modo)='real') then
    raise exception 'B2.3 detenido: Lama-Stock real está activo para central/plaza.';
  end if;
end $precheck$;

lock table public.productos in share row exclusive mode;
lock table public.producto_lotes in share row exclusive mode;

do $opening$
declare
  v_apertura uuid; v_counts jsonb; v_bodega uuid; v_sin_asignar uuid;
  v_bad bigint;
begin
  select id into v_apertura from stock_internal.aperturas where clave='b2_3_apertura_2026_10';
  if v_apertura is not null then return; end if;

  select id into v_bodega from stock_internal.ubicaciones where sede='central' and codigo='bodega_central';
  select id into v_sin_asignar from stock_internal.ubicaciones where sede='plaza' and codigo='sin_asignar';
  select jsonb_build_object(
    'productos', (select count(*) from public.productos),
    'stock_global', (select coalesce(sum(stock_actual),0) from public.productos),
    'productos_central', (select count(*) from public.productos where sede='central'),
    'stock_central', (select coalesce(sum(stock_actual),0) from public.productos where sede='central'),
    'productos_plaza', (select count(*) from public.productos where sede='plaza'),
    'stock_plaza', (select coalesce(sum(stock_actual),0) from public.productos where sede='plaza'),
    'lotes', (select count(*) from public.producto_lotes),
    'cantidad_lotes', (select coalesce(sum(cantidad),0) from public.producto_lotes),
    'movimientos', (select count(*) from public.movimientos),
    'repartos', (select count(*) from public.repartos),
    'recetas', (select count(*) from public.recetas),
    'receta_items', (select count(*) from public.receta_items),
    'permisos', (select count(*) from public.app_permisos)
  ) into v_counts;
  insert into stock_internal.aperturas(clave,origen,conteos_antes,referencia)
    values('b2_3_apertura_2026_10','migracion_b2_3',v_counts,'B2.3 corte coordinado 2026-10') returning id into v_apertura;

  select count(*) into v_bad from public.productos p where p.sede in ('central','plaza')
   and coalesce((select sum(l.cantidad) from public.producto_lotes l where l.producto_id=p.id),0)>coalesce(p.stock_actual,0)+0.000001;
  if v_bad>0 then raise exception 'B2.3 detenido: hay % productos con lotes sobre el saldo maestro.',v_bad; end if;

  insert into stock_internal.movimientos(producto_id,sede,ubicacion_id,lote_id,cantidad,tipo,actor,referencia,clave_idempotencia,metadata)
  select p.id,p.sede,case p.sede when 'central' then v_bodega else v_sin_asignar end,
    l.id,l.cantidad,'apertura_migracion','sistema:migracion_b2_3','B2.3 corte coordinado 2026-10',
    'apertura:lote:'||p.sede||':'||p.id||':'||l.id,
    jsonb_build_object('vencimiento',l.vencimiento,'lote_created_at',l.created_at,'procedencia','producto_lotes')
  from public.productos p join public.producto_lotes l on l.producto_id=p.id
  where p.sede in ('central','plaza') and l.cantidad>0;

  insert into stock_internal.movimientos(producto_id,sede,ubicacion_id,lote_id,cantidad,tipo,actor,referencia,clave_idempotencia,metadata)
  select p.id,p.sede,case p.sede when 'central' then v_bodega else v_sin_asignar end,
    null,(coalesce(p.stock_actual,0)-coalesce((select sum(l.cantidad) from public.producto_lotes l where l.producto_id=p.id),0))::numeric,
    'apertura_migracion','sistema:migracion_b2_3','B2.3 corte coordinado 2026-10',
    'apertura:residual:'||p.sede||':'||p.id,jsonb_build_object('procedencia','productos.stock_actual menos lotes')
  from public.productos p where p.sede in ('central','plaza')
    and coalesce(p.stock_actual,0)-coalesce((select sum(l.cantidad) from public.producto_lotes l where l.producto_id=p.id),0)>0;

  if exists(select 1 from public.productos p where p.sede in ('central','plaza')
      and abs(coalesce(p.stock_actual,0)-(select coalesce(sum(m.cantidad),0) from stock_internal.movimientos m where m.producto_id=p.id))>0.000001) then
    raise exception 'B2.3 detenido: la conciliación por producto no coincide.';
  end if;

  -- No se reescribe productos.stock_actual durante la apertura: la conciliación
  -- exacta ya demostró que coincide. Así tampoco se disparan triggers laterales
  -- sobre otros campos del producto por una actualización sin cambio de saldo.
  update stock_internal.aperturas set conteos_despues=jsonb_build_object(
    'productos',(select count(*) from public.productos),
    'stock_global',(select coalesce(sum(stock_actual),0) from public.productos),
    'productos_central',(select count(*) from public.productos where sede='central'),
    'stock_central',(select coalesce(sum(stock_actual),0) from public.productos where sede='central'),
    'productos_plaza',(select count(*) from public.productos where sede='plaza'),
    'stock_plaza',(select coalesce(sum(stock_actual),0) from public.productos where sede='plaza'),
    'lotes',(select count(*) from public.producto_lotes),
    'cantidad_lotes',(select coalesce(sum(cantidad),0) from public.producto_lotes),
    'movimientos',(select count(*) from public.movimientos),
    'repartos',(select count(*) from public.repartos),
    'recetas',(select count(*) from public.recetas),
    'receta_items',(select count(*) from public.receta_items),
    'permisos',(select count(*) from public.app_permisos)
  ) where id=v_apertura;
end $opening$;

drop trigger if exists trg_stock_ledger_projection on stock_internal.movimientos;
create trigger trg_stock_ledger_projection after insert on stock_internal.movimientos
for each row execute function stock_internal.trg_refrescar_proyeccion();

comment on schema stock_internal is 'Libro privado de existencias por ubicación para B2.3; no expuesto al Data API.';
