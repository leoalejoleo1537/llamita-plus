begin;

-- Fase 2: documento privado Bodega -> área. Preparar no mueve stock;
-- confirmar recepción aplica transferencia + ajuste de excedente en una sola
-- transacción. Las tablas públicas de reparto legacy permanecen bloqueadas.
do $preflight$
begin
  if to_regclass('stock_internal.movimientos') is null
     or to_regclass('stock_internal.existencias') is null
     or to_regclass('stock_internal.ajustes_manuales') is null
     or to_regclass('stock_internal.lote_continuidad') is null
     or to_regprocedure('stock_internal.transferir_aplicar(uuid,bigint,bigint,uuid,uuid,numeric,bigint,text,text)') is null
     or to_regprocedure('public.stock_ajuste_guardar(uuid,bigint,uuid,jsonb,text)') is null
     or to_regprocedure('authz_internal.exigir_capacidad_b3_2a(text)') is null then
    raise exception 'Fase 2 abortada: faltan el ledger, Fase 1, B2.4 o la autorización instalada.';
  end if;
  if exists(select 1 from stock_internal.existencias where cantidad<0) then
    raise exception 'Fase 2 abortada: existe una existencia negativa previa.';
  end if;
end
$preflight$;

create table stock_internal.repartos_area(
  id uuid primary key,
  sede text not null default 'plaza' check(sede='plaza'),
  area_id uuid not null references public.areas_operativas(id) on delete restrict,
  ubicacion_destino_id uuid not null,
  nombre text null check(nombre is null or length(btrim(nombre)) between 1 and 80),
  estado text not null default 'enviado' check(estado in ('enviado','recibido')),
  solicitud jsonb not null check(jsonb_typeof(solicitud)='object'),
  creado_por_uid uuid not null references auth.users(id) on delete restrict,
  creado_por text not null,
  creado_at timestamptz not null default now(),
  recepcion_referencia uuid unique,
  recepcion_solicitud jsonb,
  resultado jsonb,
  recibido_por_uid uuid references auth.users(id) on delete restrict,
  recibido_por text,
  recibido_at timestamptz,
  constraint repartos_area_ubicacion_fk foreign key(ubicacion_destino_id,sede)
    references stock_internal.ubicaciones(id,sede) on delete restrict,
  constraint repartos_area_recepcion_completa check(
    (estado='enviado' and recepcion_referencia is null and recepcion_solicitud is null
      and resultado is null and recibido_por_uid is null and recibido_por is null and recibido_at is null)
    or
    (estado='recibido' and recepcion_referencia is not null and recepcion_solicitud is not null
      and resultado is not null and recibido_por_uid is not null and recibido_por is not null and recibido_at is not null)
  )
);

create table stock_internal.repartos_area_items(
  id uuid primary key default gen_random_uuid(),
  reparto_id uuid not null references stock_internal.repartos_area(id) on delete restrict,
  producto_bodega_id bigint not null references public.productos(id) on delete restrict,
  producto_plaza_id bigint not null references public.productos(id) on delete restrict,
  producto_nombre text not null,
  lote_id bigint references public.producto_lotes(id) on delete restrict,
  vencimiento date,
  cantidad_preparada numeric not null check(cantidad_preparada>0),
  estado text not null default 'pendiente' check(estado in ('pendiente','recibido')),
  cantidad_recibida numeric check(cantidad_recibida>=0),
  cantidad_transferida numeric check(cantidad_transferida>=0),
  cantidad_ajustada numeric check(cantidad_ajustada>=0),
  diferencia numeric,
  transferencia_id uuid not null default gen_random_uuid(),
  ajuste_referencia_planeada uuid not null default gen_random_uuid(),
  ajuste_referencia uuid references stock_internal.ajustes_manuales(referencia) on delete restrict,
  recibido_por_uid uuid references auth.users(id) on delete restrict,
  recibido_at timestamptz,
  resultado jsonb,
  constraint repartos_area_items_resultado check(
    (estado='pendiente' and cantidad_recibida is null and cantidad_transferida is null
      and cantidad_ajustada is null and diferencia is null and ajuste_referencia is null
      and recibido_por_uid is null and recibido_at is null and resultado is null)
    or
    (estado='recibido' and cantidad_recibida is not null and cantidad_transferida is not null
      and cantidad_ajustada is not null and diferencia is not null
      and recibido_por_uid is not null and recibido_at is not null and resultado is not null)
  )
);
create unique index repartos_area_item_bucket_uidx
  on stock_internal.repartos_area_items(reparto_id,producto_bodega_id,coalesce(lote_id,0));
create unique index repartos_area_items_transferencia_uidx
  on stock_internal.repartos_area_items(transferencia_id);
create unique index repartos_area_items_ajuste_plan_uidx
  on stock_internal.repartos_area_items(ajuste_referencia_planeada);
create index repartos_area_destino_estado_idx
  on stock_internal.repartos_area(area_id,estado,creado_at desc);
create index repartos_area_items_reparto_idx
  on stock_internal.repartos_area_items(reparto_id);

alter table stock_internal.repartos_area enable row level security;
alter table stock_internal.repartos_area force row level security;
alter table stock_internal.repartos_area_items enable row level security;
alter table stock_internal.repartos_area_items force row level security;
create policy repartos_area_deny_all on stock_internal.repartos_area using(false) with check(false);
create policy repartos_area_items_deny_all on stock_internal.repartos_area_items using(false) with check(false);
revoke all on table stock_internal.repartos_area,stock_internal.repartos_area_items
  from public,anon,authenticated,service_role;

comment on table stock_internal.repartos_area is
  'Documento privado Bodega -> área. El envío documental no mueve existencias; la recepción cierra y aplica el ledger atómicamente.';
comment on table stock_internal.repartos_area_items is
  'Líneas inmutables de preparación y resultado final de recepción por lote o bucket sin lote.';

-- Un lote conocido puede llegar como excedente aunque el ledger de Bodega no
-- tenga saldo para transferirlo. En ese caso la continuidad nace de la
-- recepción auditada, no de una transferencia ficticia de cantidad cero.
alter table stock_internal.lote_continuidad
  add column reparto_area_item_id uuid references stock_internal.repartos_area_items(id) on delete restrict;
alter table stock_internal.lote_continuidad alter column transferencia_id drop not null;
alter table stock_internal.lote_continuidad
  add constraint lote_continuidad_origen_check
  check(num_nonnulls(transferencia_id,reparto_area_item_id)=1);
create index stock_lote_continuidad_reparto_item_idx
  on stock_internal.lote_continuidad(reparto_area_item_id)
  where reparto_area_item_id is not null;

create function stock_internal.proteger_reparto_area()
returns trigger language plpgsql set search_path=''
as $function$
begin
  if tg_op='DELETE' then
    raise exception 'Los repartos por área son inmutables; no se eliminan.' using errcode='42501';
  end if;
  if tg_table_name='repartos_area' then
    if old.estado='recibido'
       or new.id is distinct from old.id or new.sede is distinct from old.sede or new.area_id is distinct from old.area_id
       or new.ubicacion_destino_id is distinct from old.ubicacion_destino_id
       or new.nombre is distinct from old.nombre or new.solicitud<>old.solicitud
       or new.creado_por_uid is distinct from old.creado_por_uid or new.creado_por is distinct from old.creado_por
       or new.creado_at is distinct from old.creado_at or new.estado is distinct from 'recibido' then
      raise exception 'El reparto enviado es inmutable; solo puede confirmarse una vez.' using errcode='42501';
    end if;
  else
    if old.estado='recibido'
       or new.id is distinct from old.id or new.reparto_id is distinct from old.reparto_id
       or new.producto_bodega_id is distinct from old.producto_bodega_id
       or new.producto_plaza_id is distinct from old.producto_plaza_id
       or new.producto_nombre is distinct from old.producto_nombre
       or new.lote_id is distinct from old.lote_id
       or new.vencimiento is distinct from old.vencimiento
       or new.cantidad_preparada is distinct from old.cantidad_preparada
       or new.transferencia_id is distinct from old.transferencia_id
       or new.ajuste_referencia_planeada is distinct from old.ajuste_referencia_planeada
       or new.estado is distinct from 'recibido' then
      raise exception 'La línea preparada es inmutable; solo puede recibirse una vez.' using errcode='42501';
    end if;
  end if;
  return new;
end
$function$;
revoke all on function stock_internal.proteger_reparto_area() from public,anon,authenticated,service_role;
create trigger repartos_area_inmutables before update or delete on stock_internal.repartos_area
for each row execute function stock_internal.proteger_reparto_area();
create trigger repartos_area_items_inmutables before update or delete on stock_internal.repartos_area_items
for each row execute function stock_internal.proteger_reparto_area();

create function stock_internal.saldo_transferible_bodega(
  p_producto_id bigint,p_ubicacion_id uuid,p_lote_id bigint
) returns numeric
language plpgsql stable security definer set search_path=''
as $function$
declare v_saldo numeric; v_pendiente numeric;
begin
  if p_lote_id is null then
    select coalesce(sum(m.cantidad),0) into v_saldo
      from stock_internal.movimientos m
      where m.producto_id=p_producto_id and m.ubicacion_id=p_ubicacion_id and m.lote_id is null;
    select coalesce(sum(l.cantidad),0) into v_pendiente
      from public.producto_lotes l
      where l.producto_id=p_producto_id and l.cantidad>0
        and not exists(select 1 from stock_internal.movimientos m
          where m.producto_id=p_producto_id and m.ubicacion_id=p_ubicacion_id and m.lote_id=l.id);
    return greatest(v_saldo-v_pendiente,0);
  end if;
  select coalesce(sum(m.cantidad),0) into v_saldo
    from stock_internal.movimientos m
    where m.producto_id=p_producto_id and m.ubicacion_id=p_ubicacion_id and m.lote_id=p_lote_id;
  if not exists(select 1 from stock_internal.movimientos m
      where m.producto_id=p_producto_id and m.ubicacion_id=p_ubicacion_id and m.lote_id=p_lote_id) then
    select coalesce(l.cantidad,0) into v_pendiente from public.producto_lotes l
      where l.id=p_lote_id and l.producto_id=p_producto_id;
  end if;
  return greatest(coalesce(v_saldo,0)+coalesce(v_pendiente,0),0);
end
$function$;
revoke all on function stock_internal.saldo_transferible_bodega(bigint,uuid,bigint)
  from public,anon,authenticated,service_role;

create function public.reparto_area_catalogo_buscar(p_area_id uuid,p_consulta text)
returns jsonb
language plpgsql stable security definer set search_path=''
as $function$
declare v_q text; v_ubicacion_bodega uuid; v_result jsonb;
begin
  perform authz_internal.exigir_capacidad_b3_2a('editar');
  v_q:=btrim(regexp_replace(translate(lower(coalesce(p_consulta,'')),'áéíóúüñ','aeiouun'),'[^a-z0-9]+',' ','g'));
  if length(v_q)<2 or length(v_q)>80 then
    raise exception 'Escribe al menos dos caracteres para buscar en Bodega.' using errcode='22023';
  end if;
  if not exists(select 1 from public.areas_operativas a join stock_internal.ubicaciones u
      on u.area_id=a.id and u.sede='plaza' and u.activa
      where a.id=p_area_id and a.sede='plaza' and a.estado='activa') then
    raise exception 'El área de destino no existe o está archivada.' using errcode='22023';
  end if;
  select u.id into v_ubicacion_bodega from stock_internal.ubicaciones u
    where u.sede='central' and u.codigo='bodega_central' and u.activa;

  with candidatos as (
    select b.id bodega_id,b.producto,b.unidad,b.rubro,b.tipo,p.id plaza_id,
      translate(lower(b.producto),'áéíóúüñ','aeiouun') nombre_norm
    from public.productos b
    join public.producto_enlace e on e.producto_bodega_id=b.id and e.sede='plaza' and e.factor=1
    join public.productos p on p.id=e.producto_sede_id and p.sede='plaza' and p.activo='SÍ'
    where b.sede='central' and b.activo='SÍ'
      and (b.id::text=v_q or translate(lower(b.producto),'áéíóúüñ','aeiouun') like '%'||v_q||'%')
    order by case when b.id::text=v_q then 0 when translate(lower(b.producto),'áéíóúüñ','aeiouun')=v_q then 1 else 2 end,b.producto,p.id
    limit 40
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'producto_bodega_id',c.bodega_id,'producto_plaza_id',c.plaza_id,
    'producto',c.producto,'unidad',c.unidad,'rubro',c.rubro,'tipo',c.tipo,
    'configurado_en_area',exists(select 1 from public.producto_area_asignacion pa
      where pa.producto_id=c.plaza_id and pa.sede='plaza' and pa.area_id=p_area_id
        and pa.estado='asignado' and pa.archivado_at is null),
    'saldo_bodega',coalesce((select sum(e.cantidad) from stock_internal.existencias e
      where e.producto_id=c.bodega_id and e.ubicacion_id=v_ubicacion_bodega),0),
    'buckets',(
      with lote_ids_raw as (
        select l.id lote_id,l.vencimiento from public.producto_lotes l where l.producto_id=c.bodega_id
        union all
        select lc.lote_canonico_id,lc.vencimiento from stock_internal.lote_continuidad lc
          where lc.producto_id=c.bodega_id and lc.sede='central'
      ), lote_ids as (
        select lote_id,min(vencimiento) vencimiento from lote_ids_raw group by lote_id
      ), lineas as (
        select li.lote_id,li.vencimiento,
          stock_internal.saldo_transferible_bodega(c.bodega_id,v_ubicacion_bodega,li.lote_id) cantidad
        from lote_ids li
      )
      select coalesce(jsonb_agg(jsonb_build_object('clave',l.lote_id::text,'lote_id',l.lote_id,
        'vencimiento',l.vencimiento,'etiqueta','Lote '||l.lote_id||case when l.vencimiento is null then ' · vencimiento no informado' else ' · vence '||to_char(l.vencimiento,'DD/MM/YYYY') end,
        'cantidad',l.cantidad) order by l.vencimiento nulls last,l.lote_id),'[]'::jsonb)
        || jsonb_build_array(jsonb_build_object('clave','sin_lote','lote_id',null,'vencimiento',null,
          'etiqueta','Sin lote / vencimiento no informado',
          'cantidad',stock_internal.saldo_transferible_bodega(c.bodega_id,v_ubicacion_bodega,null)))
      from lineas l
    )
  ) order by c.producto,c.plaza_id),'[]'::jsonb) into v_result from candidatos c;
  return v_result;
end
$function$;

create function public.reparto_area_crear(
  p_referencia uuid,p_area_id uuid,p_nombre text,p_items jsonb
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_uid uuid; v_actor text; v_claims jsonb; v_ubicacion uuid; v_existente stock_internal.repartos_area;
  v_item jsonb; v_bodega bigint; v_plaza bigint; v_lote bigint; v_cantidad numeric; v_vencimiento date;
  v_solicitud jsonb; v_items_normalizados jsonb:='[]'::jsonb; v_producto_nombre text;
begin
  v_uid:=authz_internal.exigir_capacidad_b3_2a('editar'); v_claims:=auth.jwt();
  v_actor:=coalesce(nullif(lower(btrim(v_claims->>'email')),''),v_uid::text);
  if p_referencia is null then raise exception 'La referencia del reparto es obligatoria.' using errcode='22023'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then
    raise exception 'Agrega al menos un producto al reparto.' using errcode='22023';
  end if;
  if p_nombre is not null and length(btrim(p_nombre)) not between 1 and 80 then
    raise exception 'El nombre del reparto debe tener máximo 80 caracteres.' using errcode='22023';
  end if;
  select u.id into v_ubicacion from public.areas_operativas a join stock_internal.ubicaciones u
    on u.area_id=a.id and u.sede='plaza' and u.activa
    where a.id=p_area_id and a.sede='plaza' and a.estado='activa';
  if not found then raise exception 'El área de destino no existe o está archivada.' using errcode='22023'; end if;

  for v_item in select value from jsonb_array_elements(p_items) loop
    begin
      v_bodega:=(v_item->>'producto_bodega_id')::bigint;
      v_plaza:=(v_item->>'producto_plaza_id')::bigint;
      v_lote:=nullif(v_item->>'lote_id','')::bigint;
      v_cantidad:=(v_item->>'cantidad')::numeric;
    exception when others then raise exception 'Una línea del reparto no tiene producto, lote o cantidad válidos.' using errcode='22023'; end;
    if v_cantidad<=0 then raise exception 'La cantidad preparada debe ser mayor que cero.' using errcode='22023'; end if;
    if not exists(select 1 from public.producto_enlace e join public.productos b on b.id=e.producto_bodega_id
      join public.productos p on p.id=e.producto_sede_id
      where e.producto_bodega_id=v_bodega and e.producto_sede_id=v_plaza and e.sede='plaza' and e.factor=1
        and b.sede='central' and b.activo='SÍ' and p.sede='plaza' and p.activo='SÍ') then
      raise exception 'La línea no conserva un enlace explícito Bodega → Local 1.' using errcode='23514';
    end if;
    v_vencimiento:=null;
    if v_lote is not null then
      select l.vencimiento into v_vencimiento from public.producto_lotes l where l.id=v_lote and l.producto_id=v_bodega;
      if not found then
        select c.vencimiento into v_vencimiento from stock_internal.lote_continuidad c
          where c.lote_canonico_id=v_lote and c.producto_id=v_bodega and c.sede='central';
      end if;
      if not found then raise exception 'El lote no pertenece al producto maestro de Bodega.' using errcode='23514'; end if;
    end if;
    if exists(select 1 from jsonb_array_elements(v_items_normalizados) x
      where (x->>'producto_bodega_id')::bigint=v_bodega and nullif(x->>'lote_id','')::bigint is not distinct from v_lote) then
      raise exception 'El mismo producto y lote aparece más de una vez.' using errcode='23505';
    end if;
    v_items_normalizados:=v_items_normalizados||jsonb_build_array(jsonb_build_object(
      'producto_bodega_id',v_bodega,'producto_plaza_id',v_plaza,'lote_id',v_lote,'cantidad',v_cantidad));
  end loop;
  select jsonb_agg(value order by (value->>'producto_bodega_id')::bigint,
    coalesce(nullif(value->>'lote_id','')::bigint,-1)) into v_items_normalizados
  from jsonb_array_elements(v_items_normalizados);
  v_solicitud:=jsonb_build_object('area_id',p_area_id,'nombre',nullif(btrim(coalesce(p_nombre,'')),''),'items',v_items_normalizados);
  perform pg_advisory_xact_lock(hashtextextended('area-delivery-create:'||p_referencia::text,0));
  select * into v_existente from stock_internal.repartos_area r where r.id=p_referencia;
  if found then
    if v_existente.solicitud<>v_solicitud then raise exception 'La referencia del reparto ya fue usada con otro contenido.' using errcode='23505'; end if;
    return jsonb_build_object('reparto_id',v_existente.id,'repetido',true,'estado',v_existente.estado);
  end if;
  insert into stock_internal.repartos_area(id,area_id,ubicacion_destino_id,nombre,solicitud,creado_por_uid,creado_por)
    values(p_referencia,p_area_id,v_ubicacion,nullif(btrim(coalesce(p_nombre,'')),''),v_solicitud,v_uid,v_actor);
  for v_item in select value from jsonb_array_elements(v_items_normalizados) loop
    select p.producto into strict v_producto_nombre from public.productos p where p.id=(v_item->>'producto_bodega_id')::bigint;
    insert into stock_internal.repartos_area_items(reparto_id,producto_bodega_id,producto_plaza_id,producto_nombre,lote_id,vencimiento,cantidad_preparada)
    values(p_referencia,(v_item->>'producto_bodega_id')::bigint,(v_item->>'producto_plaza_id')::bigint,
      v_producto_nombre,nullif(v_item->>'lote_id','')::bigint,
      (select coalesce(l.vencimiento,c.vencimiento) from (select 1) z
       left join public.producto_lotes l on l.id=nullif(v_item->>'lote_id','')::bigint
       left join stock_internal.lote_continuidad c on c.lote_canonico_id=nullif(v_item->>'lote_id','')::bigint
         and c.producto_id=(v_item->>'producto_bodega_id')::bigint and c.sede='central' limit 1),
      (v_item->>'cantidad')::numeric);
  end loop;
  return jsonb_build_object('reparto_id',p_referencia,'repetido',false,'estado','enviado','items',jsonb_array_length(v_items_normalizados));
end
$function$;

create function public.repartos_area_listar(p_area_id uuid,p_incluir_cerrados boolean default true)
returns jsonb
language plpgsql stable security definer set search_path=''
as $function$
declare v_result jsonb;
begin
  perform authz_internal.exigir_capacidad_b3_2a('lectura');
  if not exists(select 1 from public.areas_operativas a where a.id=p_area_id and a.sede='plaza' and a.estado='activa') then
    raise exception 'El área no existe o está archivada.' using errcode='22023';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',r.id,'area_id',r.area_id,'area',(select a.nombre from public.areas_operativas a where a.id=r.area_id),
    'nombre',r.nombre,'estado',r.estado,'creado_por',r.creado_por,'creado_at',r.creado_at,
    'recibido_por',r.recibido_por,'recibido_at',r.recibido_at,'resultado',r.resultado,
    'items',(select coalesce(jsonb_agg(jsonb_build_object(
      'id',i.id,'producto',i.producto_nombre,'producto_bodega_id',i.producto_bodega_id,
      'producto_plaza_id',i.producto_plaza_id,'lote_id',i.lote_id,'vencimiento',i.vencimiento,
      'cantidad_preparada',i.cantidad_preparada,'estado',i.estado,
      'cantidad_recibida',i.cantidad_recibida,'cantidad_transferida',i.cantidad_transferida,
      'cantidad_ajustada',i.cantidad_ajustada,'diferencia',i.diferencia,'resultado',i.resultado
    ) order by i.producto_nombre,i.lote_id nulls last),'[]'::jsonb)
      from stock_internal.repartos_area_items i where i.reparto_id=r.id)
  ) order by (r.estado='enviado') desc,r.creado_at desc),'[]'::jsonb) into v_result
  from stock_internal.repartos_area r
  where r.area_id=p_area_id and (p_incluir_cerrados or r.estado='enviado');
  return v_result;
end
$function$;

create function public.reparto_area_recibir(
  p_reparto_id uuid,p_recepcion_referencia uuid,p_lineas jsonb,p_motivo text default 'Recepción de reparto por área'
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_uid uuid; v_claims jsonb; v_actor text; v_rep stock_internal.repartos_area;
  v_solicitud jsonb; v_lineas_norm jsonb; v_motivo text:=btrim(coalesce(p_motivo,''));
  v_item stock_internal.repartos_area_items; v_linea jsonb; v_recibida numeric; v_disponible numeric;
  v_transferida numeric; v_exceso numeric; v_origen uuid; v_detalle jsonb; v_conteos jsonb; v_bucket jsonb;
  v_ajuste jsonb; v_resultado jsonb; v_resultados jsonb:='[]'::jsonb;
begin
  v_uid:=authz_internal.exigir_capacidad_b3_2a('editar'); v_claims:=auth.jwt();
  v_actor:=coalesce(nullif(lower(btrim(v_claims->>'email')),''),v_uid::text);
  if p_reparto_id is null or p_recepcion_referencia is null then raise exception 'Reparto y referencia de recepción son obligatorios.' using errcode='22023'; end if;
  if p_lineas is null or jsonb_typeof(p_lineas)<>'array' then raise exception 'Indica la cantidad recibida de cada línea.' using errcode='22023'; end if;
  if length(v_motivo) not between 1 and 240 then raise exception 'Escribe un motivo breve para la recepción.' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('area-delivery-receipt:'||p_recepcion_referencia::text,0));
  select * into v_rep from stock_internal.repartos_area r where r.id=p_reparto_id for update;
  if not found then raise exception 'El reparto no existe.' using errcode='22023'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('item_id',(x->>'item_id')::uuid,'cantidad_recibida',(x->>'cantidad_recibida')::numeric)
      order by (x->>'item_id')::uuid),'[]'::jsonb) into v_lineas_norm from jsonb_array_elements(p_lineas) x;
  v_solicitud:=jsonb_build_object('lineas',v_lineas_norm,'motivo',v_motivo);
  if v_rep.estado='recibido' then
    if v_rep.recepcion_referencia=p_recepcion_referencia and v_rep.recepcion_solicitud=v_solicitud then
      return jsonb_set(v_rep.resultado,'{repetido}','true'::jsonb,true);
    end if;
    raise exception 'El reparto ya fue recibido con otra referencia o contenido.' using errcode='23505';
  end if;
  if exists(select 1 from stock_internal.repartos_area r where r.recepcion_referencia=p_recepcion_referencia and r.id<>p_reparto_id) then
    raise exception 'La referencia de recepción ya pertenece a otro reparto.' using errcode='23505';
  end if;
  if jsonb_array_length(v_lineas_norm)<>(select count(*) from stock_internal.repartos_area_items i where i.reparto_id=p_reparto_id)
     or exists(select 1 from jsonb_array_elements(v_lineas_norm) x
       where not exists(select 1 from stock_internal.repartos_area_items i where i.reparto_id=p_reparto_id and i.id=(x->>'item_id')::uuid))
     or exists(select 1 from jsonb_array_elements(v_lineas_norm) x group by x->>'item_id' having count(*)>1) then
    raise exception 'Debes confirmar exactamente una cantidad para cada línea del reparto.' using errcode='22023';
  end if;
  if exists(select 1 from jsonb_array_elements(v_lineas_norm) x where (x->>'cantidad_recibida')::numeric<0) then
    raise exception 'La cantidad recibida no puede ser negativa.' using errcode='22023';
  end if;
  select u.id into v_origen from stock_internal.ubicaciones u
    where u.sede='central' and u.codigo='bodega_central' and u.activa;
  if not found then raise exception 'Bodega central no tiene una ubicación activa.' using errcode='23514'; end if;

  for v_item in select * from stock_internal.repartos_area_items i where i.reparto_id=p_reparto_id order by i.id for update loop
    select value into strict v_linea from jsonb_array_elements(v_lineas_norm) x where (value->>'item_id')::uuid=v_item.id;
    v_recibida:=(v_linea->>'cantidad_recibida')::numeric;
    perform pg_advisory_xact_lock(hashtextextended('stock-location:'||v_item.producto_bodega_id||':'||v_origen,0));
    v_disponible:=stock_internal.saldo_transferible_bodega(v_item.producto_bodega_id,v_origen,v_item.lote_id);
    v_transferida:=least(v_recibida,v_disponible);
    v_exceso:=v_recibida-v_transferida;
    if v_transferida>0 then
      perform stock_internal.transferir_aplicar(v_item.transferencia_id,v_item.producto_bodega_id,v_item.producto_plaza_id,
        v_origen,v_rep.ubicacion_destino_id,v_transferida,v_item.lote_id,
        'Recepción reparto '||p_reparto_id::text,v_actor);
    end if;
    if v_exceso>0 then
      if v_item.lote_id is not null and not exists(select 1 from stock_internal.lote_continuidad c
          where c.lote_canonico_id=v_item.lote_id and c.producto_id=v_item.producto_plaza_id) then
        insert into stock_internal.lote_continuidad(lote_canonico_id,producto_id,sede,vencimiento,establecido_por,transferencia_id,reparto_area_item_id)
          values(v_item.lote_id,v_item.producto_plaza_id,'plaza',v_item.vencimiento,v_actor,null,v_item.id);
      end if;
      v_detalle:=public.stock_ajuste_desglose_leer(v_item.producto_plaza_id,v_rep.ubicacion_destino_id);
      v_conteos:='{}'::jsonb;
      for v_bucket in select value from jsonb_array_elements(v_detalle->'lotes') loop
        v_conteos:=jsonb_set(v_conteos,array[v_bucket->>'clave'],to_jsonb((v_bucket->>'cantidad')::numeric
          +case when v_bucket->>'clave'=coalesce(v_item.lote_id::text,'sin_lote') then v_exceso else 0 end),true);
      end loop;
      if not v_conteos ? coalesce(v_item.lote_id::text,'sin_lote') then
        raise exception 'El lote recibido no pudo incorporarse al desglose auditado.' using errcode='23514';
      end if;
      v_ajuste:=public.stock_ajuste_guardar(v_item.ajuste_referencia_planeada,v_item.producto_plaza_id,
        v_rep.ubicacion_destino_id,v_conteos,'Excedente físico en recepción '||p_reparto_id::text);
    end if;
    v_resultado:=jsonb_build_object('item_id',v_item.id,'producto',v_item.producto_nombre,
      'preparado',v_item.cantidad_preparada,'recibido',v_recibida,'transferido',v_transferida,
      'ajuste_excedente',v_exceso,'diferencia',v_recibida-v_item.cantidad_preparada,
      'lote_id',v_item.lote_id,'vencimiento',v_item.vencimiento);
    update stock_internal.repartos_area_items set estado='recibido',cantidad_recibida=v_recibida,
      cantidad_transferida=v_transferida,cantidad_ajustada=v_exceso,diferencia=v_recibida-cantidad_preparada,
      ajuste_referencia=case when v_exceso>0 then ajuste_referencia_planeada else null end,
      recibido_por_uid=v_uid,recibido_at=now(),resultado=v_resultado where id=v_item.id;
    v_resultados:=v_resultados||jsonb_build_array(v_resultado);
  end loop;
  v_resultado:=jsonb_build_object('reparto_id',p_reparto_id,'area_id',v_rep.area_id,'repetido',false,
    'lineas',v_resultados,'total_preparado',(select sum(i.cantidad_preparada) from stock_internal.repartos_area_items i where i.reparto_id=p_reparto_id),
    'total_recibido',(select sum(i.cantidad_recibida) from stock_internal.repartos_area_items i where i.reparto_id=p_reparto_id),
    'total_transferido',(select sum(i.cantidad_transferida) from stock_internal.repartos_area_items i where i.reparto_id=p_reparto_id),
    'total_ajustado',(select sum(i.cantidad_ajustada) from stock_internal.repartos_area_items i where i.reparto_id=p_reparto_id));
  update stock_internal.repartos_area set estado='recibido',recepcion_referencia=p_recepcion_referencia,
    recepcion_solicitud=v_solicitud,resultado=v_resultado,recibido_por_uid=v_uid,recibido_por=v_actor,recibido_at=now()
    where id=p_reparto_id;
  return v_resultado;
end
$function$;

revoke all on function public.reparto_area_catalogo_buscar(uuid,text) from public,anon,service_role;
revoke all on function public.reparto_area_crear(uuid,uuid,text,jsonb) from public,anon,service_role;
revoke all on function public.repartos_area_listar(uuid,boolean) from public,anon,service_role;
revoke all on function public.reparto_area_recibir(uuid,uuid,jsonb,text) from public,anon,service_role;
grant execute on function public.reparto_area_catalogo_buscar(uuid,text) to authenticated;
grant execute on function public.reparto_area_crear(uuid,uuid,text,jsonb) to authenticated;
grant execute on function public.repartos_area_listar(uuid,boolean) to authenticated;
grant execute on function public.reparto_area_recibir(uuid,uuid,jsonb,text) to authenticated;

comment on function public.reparto_area_crear(uuid,uuid,text,jsonb) is
  'Prepara un reparto Bodega -> área sin mover stock. Solo acepta enlaces explícitos Bodega/Local 1.';
comment on function public.reparto_area_recibir(uuid,uuid,jsonb,text) is
  'Cierra una recepción completa: transfiere hasta el saldo de Bodega y registra el excedente como ajuste auditado.';

commit;
