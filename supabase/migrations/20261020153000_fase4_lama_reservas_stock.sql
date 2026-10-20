begin;

-- Fase 4: fuente explícita, disponibilidad y reservas para productos que Lama
-- vende de forma directa. Las recetas y sus componentes siguen fuera de este
-- contrato y se resolverán en Fase 5.
do $preflight$
begin
  if to_regclass('public.cuentas') is null
     or to_regclass('public.cuenta_items') is null
     or to_regclass('public.comandas') is null
     or to_regclass('public.producto_area_asignacion') is null
     or to_regclass('stock_internal.movimientos') is null
     or to_regclass('stock_internal.existencias') is null
     or to_regprocedure('authz_internal.exigir_capacidad_b3_2a(text)') is null then
    raise exception 'Fase 4 abortada: faltan objetos instalados de Lama, configuración por área o ledger.';
  end if;
  if to_regclass('stock_internal.lama_reservas') is not null then
    raise exception 'Fase 4 abortada: el motor de reservas ya existe; revisar la instalación antes de continuar.';
  end if;
  if exists(select 1 from stock_internal.existencias where cantidad<0) then
    raise exception 'Fase 4 abortada: existe un saldo negativo previo que requiere conciliación.';
  end if;
end
$preflight$;

create function authz_internal.exigir_lama(p_gobierno boolean default false)
returns uuid
language plpgsql stable security definer set search_path=''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_raiz boolean;
  v_lama boolean;
  v_ajustes boolean;
begin
  if v_uid is null then
    raise exception 'Inicia sesión para usar Mesas.' using errcode='28000';
  end if;
  select exists(select 1 from authz_internal.propietario_raiz r
    where r.singleton and r.auth_uid=v_uid) into v_raiz;
  if v_raiz then return v_uid; end if;
  select coalesce(p.puede_lama,false),coalesce(p.puede_ajustes,false)
    into v_lama,v_ajustes
    from public.app_permisos p where p.auth_uid=v_uid;
  if not coalesce(v_lama,false) then
    raise exception 'Tu cuenta no tiene acceso a Mesas.' using errcode='42501';
  end if;
  if p_gobierno and not coalesce(v_ajustes,false) then
    raise exception 'Tu cuenta no puede configurar fuentes de inventario para Mesas.' using errcode='42501';
  end if;
  return v_uid;
end
$function$;
revoke all on function authz_internal.exigir_lama(boolean) from public,anon,authenticated,service_role;

create table stock_internal.lama_fuentes_directas(
  id uuid primary key default gen_random_uuid(),
  sede text not null default 'plaza' check(sede='plaza'),
  fudo_product_id text not null,
  asignacion_id uuid not null references public.producto_area_asignacion(id) on delete restrict,
  activa boolean not null default true,
  creado_at timestamptz not null default now(),
  creado_por uuid not null references auth.users(id) on delete restrict,
  actualizado_at timestamptz not null default now(),
  actualizado_por uuid not null references auth.users(id) on delete restrict,
  constraint lama_fuentes_directas_sede_producto_uk unique(sede,fudo_product_id)
);
comment on table stock_internal.lama_fuentes_directas is
  'Enlace explícito del artículo vendido por Lama con una configuración producto-área principal. No almacena cantidades.';

create table stock_internal.lama_fuentes_directas_auditoria(
  id bigint generated always as identity primary key,
  fuente_id uuid not null,
  accion text not null check(accion in ('crear','actualizar')),
  estado_anterior jsonb,
  estado_nuevo jsonb not null,
  actor_auth_uid uuid not null references auth.users(id) on delete restrict,
  creado_at timestamptz not null default now()
);

create table stock_internal.lama_reservas(
  id uuid primary key default gen_random_uuid(),
  sede text not null check(sede='plaza'),
  cuenta_origen_id bigint not null references public.cuentas(id) on delete restrict,
  cuenta_id bigint not null references public.cuentas(id) on delete restrict,
  cuenta_item_id bigint not null references public.cuenta_items(id) on delete restrict,
  comanda_id bigint not null references public.comandas(id) on delete restrict,
  fudo_product_id text not null,
  producto_id bigint not null references public.productos(id) on delete restrict,
  area_id uuid not null references public.areas_operativas(id) on delete restrict,
  ubicacion_id uuid not null,
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
  constraint lama_reservas_item_uk unique(cuenta_item_id),
  constraint lama_reservas_ubicacion_sede_fk foreign key(ubicacion_id,sede)
    references stock_internal.ubicaciones(id,sede) on delete restrict
);
comment on table stock_internal.lama_reservas is
  'Reserva auditable de una línea directa de Lama. Su fuente queda congelada al confirmar la comanda.';

create table stock_internal.lama_reserva_movimientos(
  reserva_id uuid not null references stock_internal.lama_reservas(id) on delete restrict,
  movimiento_id bigint not null references stock_internal.movimientos(id) on delete restrict,
  tipo text not null check(tipo in ('consumo','reversa')),
  creado_at timestamptz not null default now(),
  primary key(reserva_id,movimiento_id),
  constraint lama_reserva_movimiento_uk unique(movimiento_id)
);

create table stock_internal.lama_alertas(
  id uuid primary key default gen_random_uuid(),
  sede text not null check(sede='plaza'),
  cuenta_id bigint not null references public.cuentas(id) on delete restrict,
  codigo text not null,
  detalle text not null,
  estado text not null default 'pendiente' check(estado in ('pendiente','resuelta')),
  clave_idempotencia text not null unique,
  actor text,
  creado_at timestamptz not null default now(),
  resuelta_at timestamptz,
  resuelta_por uuid references auth.users(id) on delete restrict
);
comment on table stock_internal.lama_alertas is
  'Alertas recuperables cuando el cierre comercial termina pero el consumo de inventario falla.';

create index lama_fuentes_asignacion_idx on stock_internal.lama_fuentes_directas(asignacion_id) where activa;
create index lama_reservas_disponibilidad_idx
  on stock_internal.lama_reservas(producto_id,ubicacion_id,estado);
create index lama_reservas_cuenta_idx on stock_internal.lama_reservas(cuenta_id,estado);
create index lama_reservas_comanda_idx on stock_internal.lama_reservas(comanda_id);
create index lama_alertas_pendientes_idx on stock_internal.lama_alertas(sede,creado_at) where estado='pendiente';

alter table stock_internal.lama_fuentes_directas enable row level security;
alter table stock_internal.lama_fuentes_directas force row level security;
alter table stock_internal.lama_fuentes_directas_auditoria enable row level security;
alter table stock_internal.lama_fuentes_directas_auditoria force row level security;
alter table stock_internal.lama_reservas enable row level security;
alter table stock_internal.lama_reservas force row level security;
alter table stock_internal.lama_reserva_movimientos enable row level security;
alter table stock_internal.lama_reserva_movimientos force row level security;
alter table stock_internal.lama_alertas enable row level security;
alter table stock_internal.lama_alertas force row level security;

create policy lama_fuentes_deny_all on stock_internal.lama_fuentes_directas using(false) with check(false);
create policy lama_fuentes_aud_deny_all on stock_internal.lama_fuentes_directas_auditoria using(false) with check(false);
create policy lama_reservas_deny_all on stock_internal.lama_reservas using(false) with check(false);
create policy lama_reserva_movs_deny_all on stock_internal.lama_reserva_movimientos using(false) with check(false);
create policy lama_alertas_deny_all on stock_internal.lama_alertas using(false) with check(false);
revoke all on table stock_internal.lama_fuentes_directas from public,anon,authenticated,service_role;
revoke all on table stock_internal.lama_fuentes_directas_auditoria from public,anon,authenticated,service_role;
revoke all on table stock_internal.lama_reservas from public,anon,authenticated,service_role;
revoke all on table stock_internal.lama_reserva_movimientos from public,anon,authenticated,service_role;
revoke all on table stock_internal.lama_alertas from public,anon,authenticated,service_role;

create function stock_internal.auditar_lama_fuente()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  insert into stock_internal.lama_fuentes_directas_auditoria(
    fuente_id,accion,estado_anterior,estado_nuevo,actor_auth_uid
  ) values(
    new.id,case when tg_op='INSERT' then 'crear' else 'actualizar' end,
    case when tg_op='UPDATE' then to_jsonb(old) else null end,to_jsonb(new),new.actualizado_por
  );
  return new;
end
$function$;
revoke all on function stock_internal.auditar_lama_fuente() from public,anon,authenticated,service_role;
create trigger lama_fuente_auditoria
after insert or update on stock_internal.lama_fuentes_directas
for each row execute function stock_internal.auditar_lama_fuente();

create function stock_internal.impedir_mutacion_lama_auditoria()
returns trigger language plpgsql set search_path=''
as $function$
begin
  raise exception 'La auditoría de fuentes Lama es inmutable.' using errcode='42501';
end
$function$;
revoke all on function stock_internal.impedir_mutacion_lama_auditoria() from public,anon,authenticated,service_role;
create trigger lama_fuentes_auditoria_inmutable
before update or delete on stock_internal.lama_fuentes_directas_auditoria
for each row execute function stock_internal.impedir_mutacion_lama_auditoria();

create function public.lama_fuentes_candidatas_listar()
returns table(
  asignacion_id uuid,producto_id bigint,producto text,area_id uuid,area text,
  ubicacion_id uuid,saldo_fisico numeric,reservado numeric,disponible numeric
)
language plpgsql stable security definer set search_path=''
as $function$
begin
  perform authz_internal.exigir_lama(true);
  return query
  select pa.id,p.id,p.producto,a.id,a.nombre,u.id,
    coalesce(ex.saldo,0),coalesce(rr.reservado,0),
    greatest(coalesce(ex.saldo,0)-coalesce(rr.reservado,0),0)
  from public.producto_area_asignacion pa
  join public.productos p on p.id=pa.producto_id and p.sede='plaza'
  join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza' and a.estado='activa'
  join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza' and u.activa
  left join lateral(select coalesce(sum(e.cantidad),0) saldo
    from stock_internal.existencias e where e.producto_id=p.id and e.ubicacion_id=u.id) ex on true
  left join lateral(select coalesce(sum(r.cantidad),0) reservado
    from stock_internal.lama_reservas r where r.producto_id=p.id and r.ubicacion_id=u.id
      and r.estado in ('reservada','error')) rr on true
  where pa.sede='plaza' and pa.estado='asignado' and pa.archivado_at is null and pa.es_principal
  order by p.producto,a.orden,a.nombre;
end
$function$;

create function public.lama_fuentes_directas_listar()
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
  select fp.fudo_product_id,fp.nombre,fp.precio,fd.asignacion_id,
    p.id,p.producto,a.id,a.nombre,u.id,
    coalesce(ex.saldo,0),coalesce(rr.reservado,0),
    greatest(coalesce(ex.saldo,0)-coalesce(rr.reservado,0),0),
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
  left join lateral(select coalesce(sum(e.cantidad),0) saldo
    from stock_internal.existencias e where e.producto_id=p.id and e.ubicacion_id=u.id) ex on true
  left join lateral(select coalesce(sum(r.cantidad),0) reservado
    from stock_internal.lama_reservas r where r.producto_id=p.id and r.ubicacion_id=u.id
      and r.estado in ('reservada','error')) rr on true
  where fp.sede='plaza' and coalesce(fp.activo,true)
  order by fp.nombre,fp.fudo_product_id;
end
$function$;

create function public.lama_fuente_directa_guardar(
  p_fudo_product_id text,p_asignacion_id uuid
)
returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare
  v_uid uuid;
  v_fuente stock_internal.lama_fuentes_directas;
  v_pa record;
begin
  v_uid:=authz_internal.exigir_lama(true);
  if not exists(select 1 from public.fudo_productos fp
    where fp.sede='plaza' and fp.fudo_product_id=p_fudo_product_id and coalesce(fp.activo,true)) then
    raise exception 'El producto de Mesas no existe o está inactivo.' using errcode='22023';
  end if;
  if p_asignacion_id is null then
    update stock_internal.lama_fuentes_directas set activa=false,
      actualizado_at=now(),actualizado_por=v_uid
      where sede='plaza' and fudo_product_id=p_fudo_product_id
      returning * into v_fuente;
    if not found then
      return jsonb_build_object('fudo_product_id',p_fudo_product_id,
        'asignacion_id',null,'activa',false,'repetido',true);
    end if;
    return jsonb_build_object('fudo_product_id',v_fuente.fudo_product_id,
      'asignacion_id',null,'activa',false,'actualizado_at',v_fuente.actualizado_at);
  else
    select pa.id,pa.producto_id,pa.area_id,u.id ubicacion_id
      into v_pa
      from public.producto_area_asignacion pa
      join public.productos p on p.id=pa.producto_id and p.sede='plaza'
      join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza' and a.estado='activa'
      join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza' and u.activa
      where pa.id=p_asignacion_id and pa.sede='plaza' and pa.estado='asignado'
        and pa.archivado_at is null and pa.es_principal;
    if not found then
      raise exception 'Selecciona una configuración principal activa de Local 1.' using errcode='22023';
    end if;
  end if;
  insert into stock_internal.lama_fuentes_directas(
    sede,fudo_product_id,asignacion_id,activa,creado_por,actualizado_por
  ) values('plaza',p_fudo_product_id,p_asignacion_id, true,v_uid,v_uid)
  on conflict(sede,fudo_product_id) do update set
    asignacion_id=excluded.asignacion_id,activa=true,actualizado_at=now(),actualizado_por=v_uid
  returning * into v_fuente;
  return jsonb_build_object('fudo_product_id',v_fuente.fudo_product_id,
    'asignacion_id',case when v_fuente.activa then v_fuente.asignacion_id else null end,
    'activa',v_fuente.activa,'actualizado_at',v_fuente.actualizado_at);
end
$function$;

create function public.lama_stock_alertas_listar()
returns jsonb
language plpgsql stable security definer set search_path=''
as $function$
begin
  perform authz_internal.exigir_lama(false);
  return coalesce((select jsonb_agg(jsonb_build_object(
    'id',a.id,'cuenta_id',a.cuenta_id,'codigo',a.codigo,'detalle',a.detalle,'creado_at',a.creado_at
  ) order by a.creado_at desc) from stock_internal.lama_alertas a
    where a.sede='plaza' and a.estado='pendiente'),'[]'::jsonb);
end
$function$;

-- Una reserva congelada no permite cambiar silenciosamente el producto o la
-- cantidad. Comentarios, pagos parciales y el movimiento de mesa conservan su
-- funcionamiento; mover líneas actualiza la cuenta que terminará consumiendo.
create function stock_internal.proteger_linea_lama_reservada()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  if exists(select 1 from stock_internal.lama_reservas r
      where r.cuenta_item_id=old.id and r.estado in ('reservada','consumida','error'))
     and (new.cantidad is distinct from old.cantidad
          or new.fudo_product_id is distinct from old.fudo_product_id) then
    raise exception 'La línea ya está confirmada: anúlala y agrega una nueva cantidad.' using errcode='23514';
  end if;
  return new;
end
$function$;
revoke all on function stock_internal.proteger_linea_lama_reservada() from public,anon,authenticated,service_role;
create trigger cuenta_items_proteger_reserva
before update of cantidad,fudo_product_id on public.cuenta_items
for each row execute function stock_internal.proteger_linea_lama_reservada();

create function stock_internal.mover_reserva_con_linea()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  if new.cuenta_id is distinct from old.cuenta_id then
    update stock_internal.lama_reservas set cuenta_id=new.cuenta_id,actualizado_at=now()
      where cuenta_item_id=new.id and estado in ('reservada','error');
  end if;
  return new;
end
$function$;
revoke all on function stock_internal.mover_reserva_con_linea() from public,anon,authenticated,service_role;
create trigger cuenta_items_mover_reserva
after update of cuenta_id on public.cuenta_items
for each row execute function stock_internal.mover_reserva_con_linea();

create function stock_internal.consumir_reserva_lama(p_reserva_id uuid,p_actor text)
returns void
language plpgsql security definer set search_path=''
as $function$
declare
  v_r stock_internal.lama_reservas;
  v_fila record;
  v_falta numeric;
  v_tomar numeric;
  v_mov bigint;
  v_uid uuid;
begin
  select * into v_r from stock_internal.lama_reservas where id=p_reserva_id for update;
  if not found then raise exception 'La reserva ya no existe.' using errcode='22023'; end if;
  if v_r.estado='consumida' then return; end if;
  if v_r.estado<>'reservada' then
    raise exception 'La reserva no está disponible para consumo (estado %).',v_r.estado using errcode='23514';
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
      'Venta Lama cuenta '||v_r.cuenta_id::text,
      'lama:consumo:'||v_r.id::text||':'||coalesce(v_fila.lote_id::text,'sin_lote'),
      jsonb_build_object('origen','lama_directo','reserva_id',v_r.id,'cuenta_id',v_r.cuenta_id,
        'cuenta_item_id',v_r.cuenta_item_id,'comanda_id',v_r.comanda_id,'area_id',v_r.area_id)
    ) returning id into v_mov;
    insert into stock_internal.lama_reserva_movimientos(reserva_id,movimiento_id,tipo)
      values(v_r.id,v_mov,'consumo');
    v_falta:=v_falta-v_tomar;
  end loop;
  if v_falta>0 then raise exception 'No fue posible asignar el consumo completo por lote.' using errcode='23514'; end if;
  v_uid:=coalesce(auth.uid(),v_r.reservada_por);
  update stock_internal.lama_reservas set estado='consumida',consumida_at=now(),
    consumida_por=v_uid,actualizado_at=now() where id=v_r.id;
end
$function$;
revoke all on function stock_internal.consumir_reserva_lama(uuid,text) from public,anon,authenticated,service_role;

create function stock_internal.liberar_reserva_lama(p_item_id bigint,p_actor text)
returns void
language plpgsql security definer set search_path=''
as $function$
declare
  v_r stock_internal.lama_reservas;
  v_fila record;
  v_mov bigint;
  v_uid uuid;
begin
  select * into v_r from stock_internal.lama_reservas where cuenta_item_id=p_item_id for update;
  if not found or v_r.estado='liberada' then return; end if;
  v_uid:=coalesce(auth.uid(),v_r.reservada_por);
  if v_r.estado='consumida' then
    perform pg_advisory_xact_lock(hashtextextended('stock-location:'||v_r.producto_id::text||':'||v_r.ubicacion_id::text,0));
    perform 1 from public.productos p where p.id=v_r.producto_id and p.sede='plaza' for update;
    for v_fila in
      select m.id,m.lote_id,m.cantidad
      from stock_internal.lama_reserva_movimientos rm
      join stock_internal.movimientos m on m.id=rm.movimiento_id
      where rm.reserva_id=v_r.id and rm.tipo='consumo'
      order by m.id
    loop
      insert into stock_internal.movimientos(
        producto_id,sede,ubicacion_id,lote_id,cantidad,tipo,actor,referencia,clave_idempotencia,metadata
      ) values(
        v_r.producto_id,'plaza',v_r.ubicacion_id,v_fila.lote_id,-v_fila.cantidad,'entrada',p_actor,
        'Reversa anulación Lama cuenta '||v_r.cuenta_id::text,
        'lama:reversa:'||v_r.id::text||':'||v_fila.id::text,
        jsonb_build_object('origen','lama_directo_reversa','reserva_id',v_r.id,
          'movimiento_consumo_id',v_fila.id,'cuenta_item_id',v_r.cuenta_item_id)
      ) returning id into v_mov;
      insert into stock_internal.lama_reserva_movimientos(reserva_id,movimiento_id,tipo)
        values(v_r.id,v_mov,'reversa');
    end loop;
  end if;
  update stock_internal.lama_reservas set estado='liberada',liberada_at=now(),
    liberada_por=v_uid,actualizado_at=now() where id=v_r.id;
end
$function$;
revoke all on function stock_internal.liberar_reserva_lama(bigint,text) from public,anon,authenticated,service_role;

create function stock_internal.consumir_cuenta_lama(p_cuenta_id bigint,p_actor text)
returns void
language plpgsql security definer set search_path=''
as $function$
declare v_r record;
begin
  if exists(select 1 from public.cuenta_items ci
    where ci.cuenta_id=p_cuenta_id and ci.estado='confirmado' and ci.anulado_at is null
      and not exists(select 1 from stock_internal.lama_reservas r where r.cuenta_item_id=ci.id)) then
    raise exception 'La cuenta contiene líneas confirmadas anteriores al motor de reservas.' using errcode='23514';
  end if;
  for v_r in select r.id from stock_internal.lama_reservas r
    join public.cuenta_items ci on ci.id=r.cuenta_item_id and ci.anulado_at is null
    where r.cuenta_id=p_cuenta_id and r.estado='reservada' order by r.producto_id,r.ubicacion_id,r.id
  loop
    perform stock_internal.consumir_reserva_lama(v_r.id,p_actor);
  end loop;
end
$function$;
revoke all on function stock_internal.consumir_cuenta_lama(bigint,text) from public,anon,authenticated,service_role;

create function stock_internal.validar_cierre_lama()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  if new.sede='plaza' and old.estado is distinct from 'cerrada' and new.estado='cerrada'
     and exists(select 1 from public.cuenta_items ci where ci.cuenta_id=new.id
       and ci.estado='nuevo' and ci.anulado_at is null) then
    raise exception 'Confirma la comanda antes de cerrar la mesa.' using errcode='23514';
  end if;
  return new;
end
$function$;
revoke all on function stock_internal.validar_cierre_lama() from public,anon,authenticated,service_role;
create trigger cuentas_validar_cierre_lama
before update of estado on public.cuentas
for each row execute function stock_internal.validar_cierre_lama();

create function stock_internal.consumir_al_cerrar_lama()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_error text; v_actor text;
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
    begin
      insert into stock_internal.lama_alertas(sede,cuenta_id,codigo,detalle,clave_idempotencia,actor)
      values('plaza',new.id,sqlstate,v_error,'lama:cierre:error:'||new.id::text,v_actor)
      on conflict(clave_idempotencia) do nothing;
    exception when others then
      null;
    end;
  end;
  return new;
end
$function$;
revoke all on function stock_internal.consumir_al_cerrar_lama() from public,anon,authenticated,service_role;
create trigger cuentas_consumir_reservas_lama
after update of estado on public.cuentas
for each row execute function stock_internal.consumir_al_cerrar_lama();

create or replace function public.cuenta_confirmar(p_cuenta_id bigint,p_quien text default null)
returns public.comandas
language plpgsql security definer set search_path=''
as $function$
declare
  v_uid uuid;
  v_actor text;
  v_cuenta public.cuentas;
  v_comanda public.comandas;
  v_contenido jsonb;
  v_numero integer;
  v_item record;
  v_saldo numeric;
  v_reservado numeric;
begin
  v_uid:=authz_internal.exigir_lama(false);
  v_actor:=coalesce(nullif(btrim(p_quien),''),nullif(auth.jwt()->>'email',''),v_uid::text);
  select * into v_cuenta from public.cuentas where id=p_cuenta_id for update;
  if not found then raise exception 'Esa cuenta ya no existe.'; end if;
  if v_cuenta.estado='cerrada' then raise exception 'Esa mesa ya está cerrada.'; end if;
  if v_cuenta.sede<>'plaza' then raise exception 'La reserva de inventario está habilitada solo para Local 1.' using errcode='42501'; end if;
  perform 1 from public.cuenta_items ci where ci.cuenta_id=p_cuenta_id and ci.estado='nuevo'
    and ci.anulado_at is null order by ci.id for update;
  if not found then
    select * into v_comanda from public.comandas c where c.cuenta_id=p_cuenta_id order by c.numero desc limit 1;
    if found then return v_comanda; end if;
    raise exception 'No hay productos nuevos para confirmar.';
  end if;
  for v_item in
    select distinct pa.producto_id,u.id ubicacion_id
    from public.cuenta_items ci
    join stock_internal.lama_fuentes_directas fd on fd.sede='plaza'
      and fd.fudo_product_id=ci.fudo_product_id and fd.activa
    join public.producto_area_asignacion pa on pa.id=fd.asignacion_id
    join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza' and a.estado='activa'
    join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza' and u.activa
    where ci.cuenta_id=p_cuenta_id and ci.estado='nuevo' and ci.anulado_at is null
      and pa.sede='plaza' and pa.estado='asignado' and pa.archivado_at is null and pa.es_principal
    order by pa.producto_id,u.id
  loop
    perform pg_advisory_xact_lock(hashtextextended('stock-location:'||v_item.producto_id::text||':'||v_item.ubicacion_id::text,0));
    perform 1 from public.productos p where p.id=v_item.producto_id and p.sede='plaza' for update;
  end loop;
  select coalesce(max(c.numero),0)+1 into v_numero from public.comandas c where c.cuenta_id=p_cuenta_id;
  select jsonb_agg(jsonb_build_object('id',ci.id,'nombre',ci.nombre,'cantidad',ci.cantidad,
      'precio',ci.precio,'comentario',ci.comentario) order by ci.id)
    into v_contenido from public.cuenta_items ci
    where ci.cuenta_id=p_cuenta_id and ci.estado='nuevo' and ci.anulado_at is null;
  insert into public.comandas(sede,cuenta_id,numero,quien,contenido)
    values(v_cuenta.sede,p_cuenta_id,v_numero,p_quien,v_contenido) returning * into v_comanda;
  for v_item in
    select ci.*,pa.producto_id,pa.area_id,u.id ubicacion_id,a.nombre area_nombre
    from public.cuenta_items ci
    left join stock_internal.lama_fuentes_directas fd on fd.sede='plaza'
      and fd.fudo_product_id=ci.fudo_product_id and fd.activa
    left join public.producto_area_asignacion pa on pa.id=fd.asignacion_id
      and pa.sede='plaza' and pa.estado='asignado' and pa.archivado_at is null and pa.es_principal
    left join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza' and a.estado='activa'
    left join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza' and u.activa
    where ci.cuenta_id=p_cuenta_id and ci.estado='nuevo' and ci.anulado_at is null
    order by ci.id
  loop
    if v_item.producto_id is null or v_item.area_id is null or v_item.ubicacion_id is null then
      raise exception 'Este producto no tiene un área de inventario definida para venta: %.',v_item.nombre using errcode='23514';
    end if;
    select coalesce(sum(e.cantidad),0) into v_saldo from stock_internal.existencias e
      where e.producto_id=v_item.producto_id and e.ubicacion_id=v_item.ubicacion_id;
    select coalesce(sum(r.cantidad),0) into v_reservado from stock_internal.lama_reservas r
      where r.producto_id=v_item.producto_id and r.ubicacion_id=v_item.ubicacion_id
        and r.estado in ('reservada','error');
    if v_item.cantidad>greatest(v_saldo-v_reservado,0) then
      raise exception 'No hay stock disponible suficiente para %: disponible %, solicitado %.',
        v_item.nombre,greatest(v_saldo-v_reservado,0),v_item.cantidad using errcode='23514';
    end if;
    insert into stock_internal.lama_reservas(
      sede,cuenta_origen_id,cuenta_id,cuenta_item_id,comanda_id,fudo_product_id,
      producto_id,area_id,ubicacion_id,cantidad,clave_idempotencia,reservada_por,metadata
    ) values(
      'plaza',p_cuenta_id,p_cuenta_id,v_item.id,v_comanda.id,v_item.fudo_product_id,
      v_item.producto_id,v_item.area_id,v_item.ubicacion_id,v_item.cantidad,
      'lama:reserva:item:'||v_item.id::text,v_uid,
      jsonb_build_object('actor',v_actor,'area',v_item.area_nombre,'saldo_al_reservar',v_saldo,
        'reservado_previo',v_reservado)
    );
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
  v_uid uuid;
  v_item public.cuenta_items;
  v_cuenta public.cuentas;
  v_pide boolean;
  v_bloqueado boolean;
begin
  v_uid:=authz_internal.exigir_lama(false);
  select * into v_item from public.cuenta_items where id=p_item_id for update;
  if not found then raise exception 'Ese producto ya no está en la cuenta.'; end if;
  if v_item.anulado_at is not null then
    perform stock_internal.liberar_reserva_lama(v_item.id,coalesce(p_quien,v_uid::text));
    return v_item;
  end if;
  if v_item.estado<>'confirmado' then raise exception 'Lo que todavía no salió se quita, no se anula.'; end if;
  select * into v_cuenta from public.cuentas where id=v_item.cuenta_id;
  select exists(select 1 from public.lama_arqueos a
    where a.sede=v_cuenta.sede and a.estado='cerrada'
      and v_cuenta.cerrada_at is not null
      and v_cuenta.cerrada_at>=a.abierto_at and v_cuenta.cerrada_at<=a.cerrado_at)
    into v_bloqueado;
  if v_bloqueado then
    raise exception 'Ese turno ya se cerró: la venta no se puede modificar.';
  end if;
  select m.pide_comentario into v_pide from public.lama_motivos_anulacion m
    where m.codigo=p_motivo and m.activo;
  if not found then raise exception 'Elige un motivo de anulación válido.'; end if;
  if v_pide and nullif(btrim(coalesce(p_comentario,'')),'') is null then
    raise exception 'Escribe el detalle de la anulación.';
  end if;
  update public.cuenta_items set anulado_at=now(),anulado_por=p_quien,
    anulado_motivo=p_motivo,anulado_comentario=nullif(btrim(coalesce(p_comentario,'')),'')
    where id=p_item_id returning * into v_item;
  perform stock_internal.liberar_reserva_lama(v_item.id,coalesce(p_quien,v_uid::text));
  perform public.cuenta_recalcular(v_item.cuenta_id);
  return v_item;
end
$function$;

create function public.comanda_anular(
  p_comanda_id bigint,p_motivo text,p_comentario text default null,p_quien text default null
)
returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_c public.comandas; v_i record; v_n integer:=0;
begin
  perform authz_internal.exigir_lama(false);
  select * into v_c from public.comandas where id=p_comanda_id for update;
  if not found then raise exception 'La comanda no existe.' using errcode='22023'; end if;
  for v_i in select ci.id from public.cuenta_items ci
    where ci.comanda_id=p_comanda_id and ci.estado='confirmado' and ci.anulado_at is null order by ci.id
  loop
    perform public.item_anular(v_i.id,p_motivo,p_comentario,p_quien);
    v_n:=v_n+1;
  end loop;
  return jsonb_build_object('comanda_id',p_comanda_id,'lineas_anuladas',v_n,'repetido',v_n=0);
end
$function$;

revoke all on function public.lama_fuentes_candidatas_listar() from public,anon,authenticated,service_role;
grant execute on function public.lama_fuentes_candidatas_listar() to authenticated;
revoke all on function public.lama_fuentes_directas_listar() from public,anon,authenticated,service_role;
grant execute on function public.lama_fuentes_directas_listar() to authenticated;
revoke all on function public.lama_fuente_directa_guardar(text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.lama_fuente_directa_guardar(text,uuid) to authenticated;
revoke all on function public.lama_stock_alertas_listar() from public,anon,authenticated,service_role;
grant execute on function public.lama_stock_alertas_listar() to authenticated;
revoke all on function public.cuenta_confirmar(bigint,text) from public,anon,authenticated,service_role;
grant execute on function public.cuenta_confirmar(bigint,text) to authenticated;
revoke all on function public.item_anular(bigint,text,text,text) from public,anon,authenticated,service_role;
grant execute on function public.item_anular(bigint,text,text,text) to authenticated;
revoke all on function public.comanda_anular(bigint,text,text,text) from public,anon,authenticated,service_role;
grant execute on function public.comanda_anular(bigint,text,text,text) to authenticated;

commit;
