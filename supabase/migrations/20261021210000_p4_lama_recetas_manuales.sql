begin;

-- P4 conecta el catálogo comercial neutral de P3 con Mesas. El motor directo
-- de Fase 4 queda como compatibilidad explícita; una línea nunca usa ambos.
do $preflight$
begin
  if to_regclass('catalogo_internal.productos_venta') is null
     or to_regclass('catalogo_internal.recetas_venta') is null
     or to_regclass('catalogo_internal.receta_venta_componentes') is null
     or to_regclass('stock_internal.lama_reservas') is null
     or to_regclass('public.cuenta_items') is null then
    raise exception 'P4 abortado: faltan P3, Fase 4 o las tablas de Mesas.';
  end if;
  if to_regclass('stock_internal.lama_receta_reservas') is not null then
    raise exception 'P4 ya parece instalado; revisa las migraciones antes de continuar.';
  end if;
  if (select origen from stock_internal.origen_pos where sede='plaza') <> 'ninguno' then
    raise exception 'P4 requiere origen_pos=ninguno durante esta fase.';
  end if;
end
$preflight$;

alter table public.cuenta_items
  add column producto_venta_id uuid
    references catalogo_internal.productos_venta(id) on delete restrict;
create index cuenta_items_producto_venta_idx
  on public.cuenta_items(producto_venta_id) where producto_venta_id is not null;

create table stock_internal.lama_receta_reservas(
  id uuid primary key default gen_random_uuid(),
  sede text not null check(sede='plaza'),
  cuenta_origen_id bigint not null references public.cuentas(id) on delete restrict,
  cuenta_id bigint not null references public.cuentas(id) on delete restrict,
  cuenta_item_id bigint not null references public.cuenta_items(id) on delete restrict,
  comanda_id bigint not null references public.comandas(id) on delete restrict,
  producto_venta_id uuid not null references catalogo_internal.productos_venta(id) on delete restrict,
  receta_id uuid not null references catalogo_internal.recetas_venta(id) on delete restrict,
  receta_version integer not null check(receta_version>0),
  componente_orden integer not null check(componente_orden>0),
  asignacion_id uuid not null references public.producto_area_asignacion(id) on delete restrict,
  producto_id bigint not null references public.productos(id) on delete restrict,
  area_id uuid not null references public.areas_operativas(id) on delete restrict,
  ubicacion_id uuid not null,
  cantidad_unitaria numeric not null check(cantidad_unitaria>0),
  unidades_venta numeric not null check(unidades_venta>0),
  cantidad numeric not null check(cantidad>0),
  estado text not null default 'reservada'
    check(estado in ('reservada','consumida','liberada','error')),
  clave_idempotencia text not null unique,
  reservada_at timestamptz not null default now(),
  reservada_por uuid not null references auth.users(id) on delete restrict,
  consumida_at timestamptz,
  consumida_por uuid references auth.users(id) on delete restrict,
  liberada_at timestamptz,
  liberada_por uuid references auth.users(id) on delete restrict,
  error_at timestamptz,
  error_codigo text,
  error_detalle text,
  actualizado_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  constraint lama_receta_reserva_item_componente_uk unique(cuenta_item_id,componente_orden),
  constraint lama_receta_reserva_ubicacion_sede_fk foreign key(ubicacion_id,sede)
    references stock_internal.ubicaciones(id,sede) on delete restrict
);
comment on table stock_internal.lama_receta_reservas is
  'Snapshot inmutable por componente de una receta manual P3 reservada por Mesas.';

create table stock_internal.lama_receta_reserva_movimientos(
  reserva_id uuid not null references stock_internal.lama_receta_reservas(id) on delete restrict,
  movimiento_id bigint not null references stock_internal.movimientos(id) on delete restrict,
  tipo text not null check(tipo in ('consumo','reversa')),
  creado_at timestamptz not null default now(),
  primary key(reserva_id,movimiento_id),
  constraint lama_receta_movimiento_uk unique(movimiento_id)
);

create index lama_receta_reservas_disponibilidad_idx
  on stock_internal.lama_receta_reservas(producto_id,ubicacion_id,estado);
create index lama_receta_reservas_cuenta_idx
  on stock_internal.lama_receta_reservas(cuenta_id,estado);
create index lama_receta_reservas_comanda_idx
  on stock_internal.lama_receta_reservas(comanda_id);
create index lama_receta_reservas_producto_venta_idx
  on stock_internal.lama_receta_reservas(producto_venta_id,receta_id);

alter table stock_internal.lama_receta_reservas enable row level security;
alter table stock_internal.lama_receta_reservas force row level security;
alter table stock_internal.lama_receta_reserva_movimientos enable row level security;
alter table stock_internal.lama_receta_reserva_movimientos force row level security;
create policy lama_receta_reservas_deny_all
  on stock_internal.lama_receta_reservas using(false) with check(false);
create policy lama_receta_movimientos_deny_all
  on stock_internal.lama_receta_reserva_movimientos using(false) with check(false);
revoke all on table stock_internal.lama_receta_reservas
  from public,anon,authenticated,service_role;
revoke all on table stock_internal.lama_receta_reserva_movimientos
  from public,anon,authenticated,service_role;

create function stock_internal.lama_reservado_en(p_producto_id bigint,p_ubicacion_id uuid)
returns numeric
language sql stable security definer set search_path=''
as $function$
  select coalesce((select sum(r.cantidad) from stock_internal.lama_reservas r
    where r.producto_id=p_producto_id and r.ubicacion_id=p_ubicacion_id
      and r.estado in ('reservada','error')),0)
    + coalesce((select sum(r.cantidad) from stock_internal.lama_receta_reservas r
    where r.producto_id=p_producto_id and r.ubicacion_id=p_ubicacion_id
      and r.estado in ('reservada','error')),0)
$function$;
revoke all on function stock_internal.lama_reservado_en(bigint,uuid)
  from public,anon,authenticated,service_role;

create function public.lama_productos_venta_listar()
returns table(
  producto_venta_id uuid,nombre text,precio numeric,estado text,receta_id uuid,
  receta_version integer,ingredientes integer,disponible numeric,areas text,
  receta_valida boolean,vendible boolean,motivo text
)
language plpgsql stable security definer set search_path=''
as $function$
begin
  perform authz_internal.exigir_lama(false);
  return query
  select pv.id,pv.nombre,pv.precio_venta,pv.estado,rv.id,rv.version,
    coalesce(x.ingredientes,0),coalesce(x.disponible,0),coalesce(x.areas,''),
    (pv.estado='listo' and rv.id is not null and rv.estado='lista'
      and coalesce(x.ingredientes,0)>0 and coalesce(x.origenes_validos,false)) receta_valida,
    (pv.estado='listo' and rv.id is not null and rv.estado='lista'
      and coalesce(x.ingredientes,0)>0 and coalesce(x.origenes_validos,false)
      and coalesce(x.disponible,0)>=1) vendible,
    case
      when pv.estado='borrador' then 'Borrador · completa y marca la receta como lista'
      when rv.id is null or rv.estado<>'lista' then 'Falta una receta manual vigente y lista'
      when coalesce(x.ingredientes,0)=0 then 'La receta no tiene ingredientes'
      when not coalesce(x.origenes_validos,false) then 'Un ingrediente no tiene un origen de área activo'
      when coalesce(x.disponible,0)<1 then 'Stock insuficiente para una unidad'
      else null end
  from catalogo_internal.productos_venta pv
  left join catalogo_internal.recetas_venta rv
    on rv.producto_venta_id=pv.id and rv.vigente and rv.estado='lista'
  left join lateral(
    select count(*)::integer ingredientes,
      bool_and(pa.id is not null and pa.estado='asignado' and pa.archivado_at is null
        and a.id is not null and a.estado='activa' and u.id is not null and u.activa) origenes_validos,
      min(greatest(coalesce(ex.saldo,0)
        - stock_internal.lama_reservado_en(pa.producto_id,u.id),0)/c.cantidad) disponible,
      string_agg(distinct a.nombre,', ' order by a.nombre) areas
    from catalogo_internal.receta_venta_componentes c
    left join public.producto_area_asignacion pa on pa.id=c.asignacion_id and pa.sede='plaza'
    left join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza'
    left join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza'
    left join lateral(select coalesce(sum(e.cantidad),0) saldo
      from stock_internal.existencias e
      where e.producto_id=pa.producto_id and e.ubicacion_id=u.id) ex on true
    where c.receta_id=rv.id
  ) x on true
  where pv.estado<>'archivado'
  order by case pv.estado when 'listo' then 0 else 1 end,pv.nombre,pv.id;
end
$function$;

create function public.cuenta_producto_venta_agregar(
  p_cuenta_id bigint,p_producto_venta_id uuid,p_cantidad numeric default 1,
  p_comentario text default null,p_quien text default null
)
returns public.cuenta_items
language plpgsql security definer set search_path=''
as $function$
declare
  v_cuenta public.cuentas;v_producto catalogo_internal.productos_venta;
  v_receta catalogo_internal.recetas_venta;v_item public.cuenta_items;
  v_com text:=nullif(btrim(coalesce(p_comentario,'')),'');
begin
  perform authz_internal.exigir_lama(false);
  if coalesce(p_cantidad,0)<=0 then
    raise exception 'La cantidad tiene que ser mayor que cero.' using errcode='22023';
  end if;
  select * into v_cuenta from public.cuentas where id=p_cuenta_id for update;
  if not found then raise exception 'Esa cuenta ya no existe.' using errcode='22023'; end if;
  if v_cuenta.estado='cerrada' then raise exception 'La cuenta ya está cerrada.' using errcode='23514'; end if;
  if v_cuenta.sede<>'plaza' then raise exception 'Los productos de venta P3 están habilitados solo en Local 1.' using errcode='42501'; end if;
  select * into v_producto from catalogo_internal.productos_venta
    where id=p_producto_venta_id and estado='listo' for share;
  if not found then raise exception 'El producto de venta está en borrador o no existe.' using errcode='23514'; end if;
  select * into v_receta from catalogo_internal.recetas_venta
    where producto_venta_id=v_producto.id and vigente and estado='lista' for share;
  if not found or not exists(select 1 from catalogo_internal.receta_venta_componentes c where c.receta_id=v_receta.id) then
    raise exception 'Este producto no tiene una receta manual válida.' using errcode='23514';
  end if;
  if exists(
    select 1 from catalogo_internal.receta_venta_componentes c
    left join public.producto_area_asignacion pa on pa.id=c.asignacion_id
      and pa.sede='plaza' and pa.estado='asignado' and pa.archivado_at is null
    left join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza' and a.estado='activa'
    left join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza' and u.activa
    where c.receta_id=v_receta.id and (pa.id is null or a.id is null or u.id is null)
  ) then
    raise exception 'Un ingrediente de la receta no tiene un área de inventario activa.' using errcode='23514';
  end if;
  select * into v_item from public.cuenta_items
    where cuenta_id=p_cuenta_id and estado='nuevo' and producto_venta_id=v_producto.id
      and coalesce(comentario,'')=coalesce(v_com,'')
    order by id limit 1 for update;
  if found then
    update public.cuenta_items set cantidad=cantidad+p_cantidad
      where id=v_item.id returning * into v_item;
  else
    insert into public.cuenta_items(
      cuenta_id,producto_venta_id,fudo_product_id,nombre,cantidad,precio,comentario,agregado_por
    ) values(
      p_cuenta_id,v_producto.id,null,v_producto.nombre,p_cantidad,v_producto.precio_venta,v_com,p_quien
    ) returning * into v_item;
  end if;
  perform public.cuenta_recalcular(p_cuenta_id);
  return v_item;
end
$function$;

create function stock_internal.consumir_reserva_receta_lama(p_reserva_id uuid,p_actor text)
returns void
language plpgsql security definer set search_path=''
as $function$
declare
  v_r stock_internal.lama_receta_reservas;v_fila record;v_falta numeric;
  v_tomar numeric;v_mov bigint;v_uid uuid;
begin
  select * into v_r from stock_internal.lama_receta_reservas where id=p_reserva_id for update;
  if not found then raise exception 'La reserva de receta ya no existe.' using errcode='22023'; end if;
  if v_r.estado='consumida' then return; end if;
  if v_r.estado<>'reservada' then
    raise exception 'La reserva de receta no está disponible para consumo (%).',v_r.estado using errcode='23514';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('stock-location:'||v_r.producto_id::text||':'||v_r.ubicacion_id::text,0));
  perform 1 from public.productos p where p.id=v_r.producto_id and p.sede='plaza' for update;
  if coalesce((select sum(e.cantidad) from stock_internal.existencias e
      where e.producto_id=v_r.producto_id and e.ubicacion_id=v_r.ubicacion_id),0)<v_r.cantidad then
    raise exception 'El saldo físico cambió después de reservar; el cierre requiere conciliación.' using errcode='23514';
  end if;
  v_falta:=v_r.cantidad;
  for v_fila in
    select e.lote_id,e.cantidad,
      coalesce((select min(x.vencimiento) from (
        select l.vencimiento from public.producto_lotes l
          where l.id=e.lote_id and l.producto_id=e.producto_id
        union all
        select lc.vencimiento from stock_internal.lote_continuidad lc
          where lc.lote_canonico_id=e.lote_id and lc.producto_id=e.producto_id and lc.sede='plaza'
      ) x),date '9999-12-31') vencimiento
    from stock_internal.existencias e
    where e.producto_id=v_r.producto_id and e.ubicacion_id=v_r.ubicacion_id and e.cantidad>0
    order by vencimiento,e.lote_id nulls last
  loop
    exit when v_falta<=0;
    v_tomar:=least(v_falta,v_fila.cantidad);
    insert into stock_internal.movimientos(
      producto_id,sede,ubicacion_id,lote_id,cantidad,tipo,actor,referencia,clave_idempotencia,metadata
    ) values(
      v_r.producto_id,'plaza',v_r.ubicacion_id,v_fila.lote_id,-v_tomar,'salida',p_actor,
      'Venta Lama receta manual cuenta '||v_r.cuenta_id,
      'lama:receta:consumo:'||v_r.id||':'||coalesce(v_fila.lote_id::text,'sin_lote'),
      jsonb_build_object('origen','lama_receta_manual','reserva_id',v_r.id,
        'producto_venta_id',v_r.producto_venta_id,'receta_id',v_r.receta_id,
        'receta_version',v_r.receta_version,'componente_orden',v_r.componente_orden,
        'cuenta_id',v_r.cuenta_id,'cuenta_item_id',v_r.cuenta_item_id,
        'comanda_id',v_r.comanda_id,'area_id',v_r.area_id)
    ) returning id into v_mov;
    insert into stock_internal.lama_receta_reserva_movimientos(reserva_id,movimiento_id,tipo)
      values(v_r.id,v_mov,'consumo');
    v_falta:=v_falta-v_tomar;
  end loop;
  if v_falta>0 then raise exception 'No fue posible asignar el consumo completo por lote.' using errcode='23514'; end if;
  v_uid:=coalesce(auth.uid(),v_r.reservada_por);
  update stock_internal.lama_receta_reservas set estado='consumida',consumida_at=now(),
    consumida_por=v_uid,actualizado_at=now() where id=v_r.id;
end
$function$;
revoke all on function stock_internal.consumir_reserva_receta_lama(uuid,text)
  from public,anon,authenticated,service_role;

create function stock_internal.liberar_reservas_receta_lama(p_item_id bigint,p_actor text)
returns void
language plpgsql security definer set search_path=''
as $function$
declare v_r stock_internal.lama_receta_reservas;v_fila record;v_mov bigint;v_uid uuid;
begin
  for v_r in select * from stock_internal.lama_receta_reservas
    where cuenta_item_id=p_item_id and estado<>'liberada' order by componente_orden for update
  loop
    v_uid:=coalesce(auth.uid(),v_r.reservada_por);
    if v_r.estado='consumida' then
      perform pg_advisory_xact_lock(hashtextextended('stock-location:'||v_r.producto_id::text||':'||v_r.ubicacion_id::text,0));
      perform 1 from public.productos p where p.id=v_r.producto_id and p.sede='plaza' for update;
      for v_fila in
        select m.id,m.lote_id,m.cantidad from stock_internal.lama_receta_reserva_movimientos rm
        join stock_internal.movimientos m on m.id=rm.movimiento_id
        where rm.reserva_id=v_r.id and rm.tipo='consumo' order by m.id
      loop
        insert into stock_internal.movimientos(
          producto_id,sede,ubicacion_id,lote_id,cantidad,tipo,actor,referencia,clave_idempotencia,metadata
        ) values(
          v_r.producto_id,'plaza',v_r.ubicacion_id,v_fila.lote_id,-v_fila.cantidad,'entrada',p_actor,
          'Reversa anulación Lama receta cuenta '||v_r.cuenta_id,
          'lama:receta:reversa:'||v_r.id||':'||v_fila.id,
          jsonb_build_object('origen','lama_receta_manual_reversa','reserva_id',v_r.id,
            'movimiento_consumo_id',v_fila.id,'producto_venta_id',v_r.producto_venta_id,
            'receta_id',v_r.receta_id,'cuenta_item_id',v_r.cuenta_item_id)
        ) returning id into v_mov;
        insert into stock_internal.lama_receta_reserva_movimientos(reserva_id,movimiento_id,tipo)
          values(v_r.id,v_mov,'reversa');
      end loop;
    end if;
    update stock_internal.lama_receta_reservas set estado='liberada',liberada_at=now(),
      liberada_por=v_uid,actualizado_at=now() where id=v_r.id;
  end loop;
end
$function$;
revoke all on function stock_internal.liberar_reservas_receta_lama(bigint,text)
  from public,anon,authenticated,service_role;

create or replace function stock_internal.proteger_linea_lama_reservada()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  if (exists(select 1 from stock_internal.lama_reservas r
        where r.cuenta_item_id=old.id and r.estado in ('reservada','consumida','error'))
      or exists(select 1 from stock_internal.lama_receta_reservas r
        where r.cuenta_item_id=old.id and r.estado in ('reservada','consumida','error')))
     and (new.cantidad is distinct from old.cantidad
       or new.fudo_product_id is distinct from old.fudo_product_id
       or new.producto_venta_id is distinct from old.producto_venta_id) then
    raise exception 'La línea ya está confirmada: anúlala y agrega una nueva cantidad.' using errcode='23514';
  end if;
  return new;
end
$function$;

drop trigger cuenta_items_proteger_reserva on public.cuenta_items;
create trigger cuenta_items_proteger_reserva
before update of cantidad,fudo_product_id,producto_venta_id on public.cuenta_items
for each row execute function stock_internal.proteger_linea_lama_reservada();

create or replace function stock_internal.mover_reserva_con_linea()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  if new.cuenta_id is distinct from old.cuenta_id then
    update stock_internal.lama_reservas set cuenta_id=new.cuenta_id,actualizado_at=now()
      where cuenta_item_id=new.id and estado in ('reservada','error');
    update stock_internal.lama_receta_reservas set cuenta_id=new.cuenta_id,actualizado_at=now()
      where cuenta_item_id=new.id and estado in ('reservada','error');
  end if;
  return new;
end
$function$;

create or replace function stock_internal.consumir_cuenta_lama(p_cuenta_id bigint,p_actor text)
returns void
language plpgsql security definer set search_path=''
as $function$
declare v_r record;
begin
  if exists(select 1 from public.cuenta_items ci
    where ci.cuenta_id=p_cuenta_id and ci.estado='confirmado' and ci.anulado_at is null
      and ((ci.producto_venta_id is not null and not exists(
              select 1 from stock_internal.lama_receta_reservas r where r.cuenta_item_id=ci.id))
        or (ci.producto_venta_id is null and not exists(
              select 1 from stock_internal.lama_reservas r where r.cuenta_item_id=ci.id)))) then
    raise exception 'La cuenta contiene líneas confirmadas sin una reserva de inventario completa.' using errcode='23514';
  end if;
  for v_r in select r.id from stock_internal.lama_reservas r
    join public.cuenta_items ci on ci.id=r.cuenta_item_id and ci.anulado_at is null
    where r.cuenta_id=p_cuenta_id and r.estado='reservada'
    order by r.producto_id,r.ubicacion_id,r.id
  loop
    perform stock_internal.consumir_reserva_lama(v_r.id,p_actor);
  end loop;
  for v_r in select r.id from stock_internal.lama_receta_reservas r
    join public.cuenta_items ci on ci.id=r.cuenta_item_id and ci.anulado_at is null
    where r.cuenta_id=p_cuenta_id and r.estado='reservada'
    order by r.producto_id,r.ubicacion_id,r.id
  loop
    perform stock_internal.consumir_reserva_receta_lama(v_r.id,p_actor);
  end loop;
end
$function$;

create or replace function stock_internal.consumir_al_cerrar_lama()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_error text;v_actor text;
begin
  if new.sede<>'plaza' or old.estado='cerrada' or new.estado<>'cerrada' then return new; end if;
  v_actor:=coalesce(new.cerrada_por,auth.uid()::text,'sistema:lama');
  begin
    perform stock_internal.consumir_cuenta_lama(new.id,v_actor);
  exception when others then
    v_error:=sqlerrm;
    update stock_internal.lama_reservas set estado='error',error_at=now(),
      error_codigo=sqlstate,error_detalle=v_error,actualizado_at=now()
      where cuenta_id=new.id and estado='reservada';
    update stock_internal.lama_receta_reservas set estado='error',error_at=now(),
      error_codigo=sqlstate,error_detalle=v_error,actualizado_at=now()
      where cuenta_id=new.id and estado='reservada';
    begin
      insert into stock_internal.lama_alertas(sede,cuenta_id,codigo,detalle,clave_idempotencia,actor)
      values('plaza',new.id,sqlstate,v_error,'lama:cierre:error:'||new.id,v_actor)
      on conflict(clave_idempotencia) do nothing;
    exception when others then null;
    end;
  end;
  return new;
end
$function$;

create or replace function public.cuenta_confirmar(p_cuenta_id bigint,p_quien text default null)
returns public.comandas
language plpgsql security definer set search_path=''
as $function$
declare
  v_uid uuid;v_actor text;v_cuenta public.cuentas;v_comanda public.comandas;
  v_contenido jsonb;v_numero integer;v_item record;v_comp record;
  v_receta catalogo_internal.recetas_venta;v_saldo numeric;v_reservado numeric;v_necesario numeric;
begin
  v_uid:=authz_internal.exigir_lama(false);
  v_actor:=coalesce(nullif(btrim(p_quien),''),nullif(auth.jwt()->>'email',''),v_uid::text);
  select * into v_cuenta from public.cuentas where id=p_cuenta_id for update;
  if not found then raise exception 'Esa cuenta ya no existe.' using errcode='22023'; end if;
  if v_cuenta.estado='cerrada' then raise exception 'Esa mesa ya está cerrada.' using errcode='23514'; end if;
  if v_cuenta.sede<>'plaza' then raise exception 'La reserva de inventario está habilitada solo para Local 1.' using errcode='42501'; end if;
  perform 1 from public.cuenta_items ci where ci.cuenta_id=p_cuenta_id and ci.estado='nuevo'
    and ci.anulado_at is null order by ci.id for update;
  if not found then
    select * into v_comanda from public.comandas c where c.cuenta_id=p_cuenta_id order by c.numero desc limit 1;
    if found then return v_comanda; end if;
    raise exception 'No hay productos nuevos para confirmar.' using errcode='22023';
  end if;

  -- Orden global y estable de candados: evita carreras entre mesas y recetas multiárea.
  for v_comp in
    select distinct q.producto_id,q.ubicacion_id from (
      select pa.producto_id,u.id ubicacion_id
      from public.cuenta_items ci
      join catalogo_internal.productos_venta pv on pv.id=ci.producto_venta_id and pv.estado='listo'
      join catalogo_internal.recetas_venta rv on rv.producto_venta_id=pv.id and rv.vigente and rv.estado='lista'
      join catalogo_internal.receta_venta_componentes rc on rc.receta_id=rv.id
      join public.producto_area_asignacion pa on pa.id=rc.asignacion_id and pa.sede='plaza'
      join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza'
      join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza'
      where ci.cuenta_id=p_cuenta_id and ci.estado='nuevo' and ci.anulado_at is null
      union all
      select pa.producto_id,u.id
      from public.cuenta_items ci
      join stock_internal.lama_fuentes_directas fd on fd.sede='plaza'
        and fd.fudo_product_id=ci.fudo_product_id and fd.activa
      join public.producto_area_asignacion pa on pa.id=fd.asignacion_id
      join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza'
      join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza'
      where ci.cuenta_id=p_cuenta_id and ci.estado='nuevo' and ci.anulado_at is null
        and ci.producto_venta_id is null
    ) q order by q.producto_id,q.ubicacion_id
  loop
    perform pg_advisory_xact_lock(hashtextextended('stock-location:'||v_comp.producto_id||':'||v_comp.ubicacion_id,0));
    perform 1 from public.productos p where p.id=v_comp.producto_id and p.sede='plaza' for update;
  end loop;

  select coalesce(max(c.numero),0)+1 into v_numero from public.comandas c where c.cuenta_id=p_cuenta_id;
  select jsonb_agg(jsonb_build_object('id',ci.id,'nombre',ci.nombre,'cantidad',ci.cantidad,
      'precio',ci.precio,'comentario',ci.comentario,'producto_venta_id',ci.producto_venta_id)
      order by ci.id) into v_contenido
    from public.cuenta_items ci where ci.cuenta_id=p_cuenta_id and ci.estado='nuevo' and ci.anulado_at is null;
  insert into public.comandas(sede,cuenta_id,numero,quien,contenido)
    values(v_cuenta.sede,p_cuenta_id,v_numero,p_quien,v_contenido) returning * into v_comanda;

  for v_item in select ci.* from public.cuenta_items ci
    where ci.cuenta_id=p_cuenta_id and ci.estado='nuevo' and ci.anulado_at is null order by ci.id
  loop
    if v_item.producto_venta_id is not null then
      if v_item.fudo_product_id is not null then
        raise exception 'La línea % mezcla catálogo neutral y compatibilidad directa.',v_item.nombre using errcode='23514';
      end if;
      select rv.* into v_receta from catalogo_internal.productos_venta pv
      join catalogo_internal.recetas_venta rv on rv.producto_venta_id=pv.id
        and rv.vigente and rv.estado='lista'
      where pv.id=v_item.producto_venta_id and pv.estado='listo' for share of pv,rv;
      if not found then
        raise exception 'El producto % no tiene una receta manual válida y lista.',v_item.nombre using errcode='23514';
      end if;
      if not exists(select 1 from catalogo_internal.receta_venta_componentes c where c.receta_id=v_receta.id) then
        raise exception 'La receta de % no tiene ingredientes.',v_item.nombre using errcode='23514';
      end if;
      for v_comp in
        select c.orden,c.cantidad cantidad_unitaria,c.asignacion_id,pa.producto_id,pa.area_id,
          u.id ubicacion_id,a.nombre area_nombre
        from catalogo_internal.receta_venta_componentes c
        left join public.producto_area_asignacion pa on pa.id=c.asignacion_id
          and pa.sede='plaza' and pa.estado='asignado' and pa.archivado_at is null
        left join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza' and a.estado='activa'
        left join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza' and u.activa
        where c.receta_id=v_receta.id order by c.orden
      loop
        if v_comp.producto_id is null or v_comp.area_id is null or v_comp.ubicacion_id is null then
          raise exception 'Un ingrediente de % no tiene un área de inventario activa.',v_item.nombre using errcode='23514';
        end if;
        v_necesario:=v_comp.cantidad_unitaria*v_item.cantidad;
        select coalesce(sum(e.cantidad),0) into v_saldo from stock_internal.existencias e
          where e.producto_id=v_comp.producto_id and e.ubicacion_id=v_comp.ubicacion_id;
        v_reservado:=stock_internal.lama_reservado_en(v_comp.producto_id,v_comp.ubicacion_id);
        if v_necesario>greatest(v_saldo-v_reservado,0) then
          raise exception 'Stock insuficiente para %: ingrediente % en %, disponible %, necesario %.',
            v_item.nombre,v_comp.producto_id,v_comp.area_nombre,
            greatest(v_saldo-v_reservado,0),v_necesario using errcode='23514';
        end if;
        insert into stock_internal.lama_receta_reservas(
          sede,cuenta_origen_id,cuenta_id,cuenta_item_id,comanda_id,producto_venta_id,
          receta_id,receta_version,componente_orden,asignacion_id,producto_id,area_id,
          ubicacion_id,cantidad_unitaria,unidades_venta,cantidad,clave_idempotencia,
          reservada_por,metadata
        ) values(
          'plaza',p_cuenta_id,p_cuenta_id,v_item.id,v_comanda.id,v_item.producto_venta_id,
          v_receta.id,v_receta.version,v_comp.orden,v_comp.asignacion_id,v_comp.producto_id,
          v_comp.area_id,v_comp.ubicacion_id,v_comp.cantidad_unitaria,v_item.cantidad,v_necesario,
          'lama:receta:reserva:item:'||v_item.id||':componente:'||v_comp.orden,v_uid,
          jsonb_build_object('motor','receta_manual','actor',v_actor,'area',v_comp.area_nombre,
            'saldo_al_reservar',v_saldo,'reservado_previo',v_reservado)
        );
      end loop;
    else
      -- Compatibilidad explícita Fase 4: solo para líneas históricas directas.
      select ci.*,pa.producto_id,pa.area_id,u.id ubicacion_id,a.nombre area_nombre
        into v_comp from public.cuenta_items ci
        left join stock_internal.lama_fuentes_directas fd on fd.sede='plaza'
          and fd.fudo_product_id=ci.fudo_product_id and fd.activa
        left join public.producto_area_asignacion pa on pa.id=fd.asignacion_id
          and pa.sede='plaza' and pa.estado='asignado' and pa.archivado_at is null and pa.es_principal
        left join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza' and a.estado='activa'
        left join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza' and u.activa
        where ci.id=v_item.id;
      if v_item.fudo_product_id is null or v_comp.producto_id is null or v_comp.area_id is null or v_comp.ubicacion_id is null then
        raise exception 'Este producto de compatibilidad no tiene un área de inventario definida para venta: %.',v_item.nombre using errcode='23514';
      end if;
      select coalesce(sum(e.cantidad),0) into v_saldo from stock_internal.existencias e
        where e.producto_id=v_comp.producto_id and e.ubicacion_id=v_comp.ubicacion_id;
      v_reservado:=stock_internal.lama_reservado_en(v_comp.producto_id,v_comp.ubicacion_id);
      if v_item.cantidad>greatest(v_saldo-v_reservado,0) then
        raise exception 'No hay stock disponible suficiente para %: disponible %, solicitado %.',
          v_item.nombre,greatest(v_saldo-v_reservado,0),v_item.cantidad using errcode='23514';
      end if;
      insert into stock_internal.lama_reservas(
        sede,cuenta_origen_id,cuenta_id,cuenta_item_id,comanda_id,fudo_product_id,
        producto_id,area_id,ubicacion_id,cantidad,clave_idempotencia,reservada_por,metadata
      ) values(
        'plaza',p_cuenta_id,p_cuenta_id,v_item.id,v_comanda.id,v_item.fudo_product_id,
        v_comp.producto_id,v_comp.area_id,v_comp.ubicacion_id,v_item.cantidad,
        'lama:reserva:item:'||v_item.id,v_uid,
        jsonb_build_object('motor','directo_compatibilidad','actor',v_actor,
          'area',v_comp.area_nombre,'saldo_al_reservar',v_saldo,'reservado_previo',v_reservado)
      );
    end if;
  end loop;
  update public.cuenta_items set estado='confirmado',comanda_id=v_comanda.id
    where cuenta_id=p_cuenta_id and estado='nuevo' and anulado_at is null;
  perform public.cuenta_recalcular(p_cuenta_id);
  return v_comanda;
end
$function$;

create or replace function public.item_anular(
  p_item_id bigint,p_motivo text,p_comentario text default null,p_quien text default null
)
returns public.cuenta_items
language plpgsql security definer set search_path=''
as $function$
declare
  v_uid uuid;v_item public.cuenta_items;v_cuenta public.cuentas;v_pide boolean;v_bloqueado boolean;
begin
  v_uid:=authz_internal.exigir_lama(false);
  select * into v_item from public.cuenta_items where id=p_item_id for update;
  if not found then raise exception 'Ese producto ya no está en la cuenta.' using errcode='22023'; end if;
  if v_item.anulado_at is not null then
    perform stock_internal.liberar_reserva_lama(v_item.id,coalesce(p_quien,v_uid::text));
    perform stock_internal.liberar_reservas_receta_lama(v_item.id,coalesce(p_quien,v_uid::text));
    return v_item;
  end if;
  if v_item.estado<>'confirmado' then raise exception 'Lo que todavía no salió se quita, no se anula.' using errcode='23514'; end if;
  select * into v_cuenta from public.cuentas where id=v_item.cuenta_id;
  select exists(select 1 from public.lama_arqueos a where a.sede=v_cuenta.sede and a.estado='cerrada'
    and v_cuenta.cerrada_at is not null and v_cuenta.cerrada_at>=a.abierto_at
    and v_cuenta.cerrada_at<=a.cerrado_at) into v_bloqueado;
  if v_bloqueado then raise exception 'Ese turno ya se cerró: la venta no se puede modificar.' using errcode='23514'; end if;
  select m.pide_comentario into v_pide from public.lama_motivos_anulacion m
    where m.codigo=p_motivo and m.activo;
  if not found then raise exception 'Elige un motivo de anulación válido.' using errcode='22023'; end if;
  if v_pide and nullif(btrim(coalesce(p_comentario,'')),'') is null then
    raise exception 'Escribe el detalle de la anulación.' using errcode='22023';
  end if;
  update public.cuenta_items set anulado_at=now(),anulado_por=p_quien,
    anulado_motivo=p_motivo,anulado_comentario=nullif(btrim(coalesce(p_comentario,'')),'')
    where id=p_item_id returning * into v_item;
  perform stock_internal.liberar_reserva_lama(v_item.id,coalesce(p_quien,v_uid::text));
  perform stock_internal.liberar_reservas_receta_lama(v_item.id,coalesce(p_quien,v_uid::text));
  perform public.cuenta_recalcular(v_item.cuenta_id);
  return v_item;
end
$function$;

-- La disponibilidad del motor directo debe descontar también reservas de recetas.
create or replace function public.lama_fuentes_directas_listar()
returns table(
  fudo_product_id text,nombre text,precio numeric,asignacion_id uuid,
  producto_id bigint,producto text,area_id uuid,area text,ubicacion_id uuid,
  saldo_fisico numeric,reservado numeric,disponible numeric,estado_fuente text
)
language plpgsql stable security definer set search_path=''
as $function$
begin
  perform authz_internal.exigir_lama(false);
  return query
  select fp.fudo_product_id,fp.nombre,fp.precio,fd.asignacion_id,p.id,p.producto,a.id,a.nombre,u.id,
    coalesce(ex.saldo,0),stock_internal.lama_reservado_en(p.id,u.id),
    greatest(coalesce(ex.saldo,0)-stock_internal.lama_reservado_en(p.id,u.id),0),
    case when fd.id is null or not fd.activa then 'sin_fuente'
      when pa.id is null or pa.estado<>'asignado' or pa.archivado_at is not null or not pa.es_principal
        or a.id is null or a.estado<>'activa' or u.id is null or not u.activa then 'fuente_inactiva'
      else 'configurada' end
  from public.fudo_productos fp
  left join stock_internal.lama_fuentes_directas fd
    on fd.sede=fp.sede and fd.fudo_product_id=fp.fudo_product_id and fd.activa
  left join public.producto_area_asignacion pa on pa.id=fd.asignacion_id
  left join public.productos p on p.id=pa.producto_id and p.sede='plaza'
  left join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza'
  left join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza'
  left join lateral(select coalesce(sum(e.cantidad),0) saldo from stock_internal.existencias e
    where e.producto_id=p.id and e.ubicacion_id=u.id) ex on true
  where fp.sede='plaza' and coalesce(fp.activo,true)
  order by fp.nombre,fp.fudo_product_id;
end
$function$;

revoke all on function public.lama_productos_venta_listar()
  from public,anon,authenticated,service_role;
grant execute on function public.lama_productos_venta_listar() to authenticated;
revoke all on function public.cuenta_producto_venta_agregar(bigint,uuid,numeric,text,text)
  from public,anon,authenticated,service_role;
grant execute on function public.cuenta_producto_venta_agregar(bigint,uuid,numeric,text,text) to authenticated;
revoke all on function public.cuenta_confirmar(bigint,text)
  from public,anon,authenticated,service_role;
grant execute on function public.cuenta_confirmar(bigint,text) to authenticated;
revoke all on function public.item_anular(bigint,text,text,text)
  from public,anon,authenticated,service_role;
grant execute on function public.item_anular(bigint,text,text,text) to authenticated;
revoke all on function public.lama_fuentes_directas_listar()
  from public,anon,authenticated,service_role;
grant execute on function public.lama_fuentes_directas_listar() to authenticated;

commit;
