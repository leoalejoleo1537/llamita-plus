begin;

-- Fase 1: conteos físicos por saldo final, persistidos como deltas inmutables
-- en el ledger. La tabla de cabecera conserva la solicitud/idempotencia y no
-- es una fuente de cantidades operativas.
do $preflight$
begin
  if to_regclass('stock_internal.movimientos') is null
     or to_regclass('stock_internal.existencias') is null
     or to_regclass('stock_internal.ubicaciones') is null
     or to_regclass('public.producto_lotes') is null
     or to_regprocedure('authz_internal.exigir_capacidad_b3_2a(text)') is null then
    raise exception 'Fase 1 abortada: faltan componentes instalados del ledger, lotes o autorización.';
  end if;
  if not exists(
    select 1 from authz_internal.propietario_raiz
    where singleton and auth_uid='decc9a8d-0ab6-4306-bab5-a62bcaa40338'::uuid
  ) then
    raise exception 'Fase 1 abortada: la identidad raíz S1 no coincide.';
  end if;
  if exists(select 1 from stock_internal.existencias where cantidad<0) then
    raise exception 'Fase 1 abortada: existe una existencia negativa previa que requiere conciliación.';
  end if;
end
$preflight$;

create table stock_internal.ajustes_manuales(
  referencia uuid primary key,
  producto_id bigint not null references public.productos(id) on delete restrict,
  sede text not null check(sede in ('central','plaza')),
  ubicacion_id uuid not null,
  actor_auth_uid uuid not null references auth.users(id) on delete restrict,
  actor text not null,
  motivo text not null check(length(btrim(motivo)) between 1 and 240),
  conteos jsonb not null check(jsonb_typeof(conteos)='object'),
  resultado jsonb not null check(jsonb_typeof(resultado)='object'),
  creado_at timestamptz not null default now(),
  constraint ajustes_manuales_ubicacion_sede_fk
    foreign key(ubicacion_id,sede)
    references stock_internal.ubicaciones(id,sede) on delete restrict
);

alter table stock_internal.ajustes_manuales enable row level security;
alter table stock_internal.ajustes_manuales force row level security;
create policy ajustes_manuales_deny_all on stock_internal.ajustes_manuales
  using(false) with check(false);
revoke all on table stock_internal.ajustes_manuales from public,anon,authenticated,service_role;

comment on table stock_internal.ajustes_manuales is
  'Solicitud y evidencia inmutable de conteo manual; el saldo operativo reside únicamente en stock_internal.movimientos/existencias.';
comment on column stock_internal.ajustes_manuales.conteos is
  'Saldos finales contados por lote_id o por la clave sin_lote; no contiene un saldo operativo paralelo.';

create function stock_internal.impedir_mutacion_ajuste_manual()
returns trigger language plpgsql set search_path=''
as $function$
begin
  raise exception 'El registro del ajuste es inmutable; registre una nueva corrección compensatoria.' using errcode='42501';
end
$function$;
revoke all on function stock_internal.impedir_mutacion_ajuste_manual() from public,anon,authenticated,service_role;
create trigger ajustes_manuales_inmutables
before update or delete on stock_internal.ajustes_manuales
for each row execute function stock_internal.impedir_mutacion_ajuste_manual();

alter table stock_internal.movimientos
  add column ajuste_manual_id uuid,
  add constraint movimientos_ajuste_manual_fk
    foreign key(ajuste_manual_id) references stock_internal.ajustes_manuales(referencia) on delete restrict;
create index movimientos_ajuste_manual_id_idx
  on stock_internal.movimientos(ajuste_manual_id) where ajuste_manual_id is not null;

comment on column stock_internal.movimientos.ajuste_manual_id is
  'Referencia a la captura manual inmutable que originó este delta de tipo ajuste.';

create function public.stock_ajuste_desglose_leer(
  p_producto_id bigint,
  p_ubicacion_id uuid default null
)
returns jsonb
language plpgsql stable security definer set search_path=''
as $function$
declare
  v_sede text;
  v_ubicacion uuid;
  v_codigo text;
  v_area uuid;
  v_activa boolean;
  v_loteado boolean;
  v_lotes jsonb;
  v_total numeric;
begin
  perform authz_internal.exigir_capacidad_b3_2a('lectura');
  select p.sede into v_sede from public.productos p where p.id=p_producto_id and p.sede in ('central','plaza');
  if not found then raise exception 'El producto no existe en una sede habilitada para el ledger.' using errcode='22023'; end if;

  if p_ubicacion_id is null then
    if v_sede<>'central' then raise exception 'Selecciona la ubicación física del producto.' using errcode='22023'; end if;
    select u.id,u.codigo,u.area_id,u.activa into v_ubicacion,v_codigo,v_area,v_activa
      from stock_internal.ubicaciones u where u.sede='central' and u.codigo='bodega_central';
  else
    select u.id,u.codigo,u.area_id,u.activa into v_ubicacion,v_codigo,v_area,v_activa
      from stock_internal.ubicaciones u where u.id=p_ubicacion_id and u.sede=v_sede;
  end if;
  if not found or not coalesce(v_activa,false) then raise exception 'La ubicación no existe o está inactiva.' using errcode='22023'; end if;
  if v_sede='central' and (v_codigo<>'bodega_central' or v_area is not null) then
    raise exception 'Solo se permite la ubicación de Bodega central.' using errcode='42501';
  end if;
  if v_sede='plaza' and v_area is not null and not exists(
    select 1 from public.areas_operativas a where a.id=v_area and a.sede='plaza' and a.estado='activa'
  ) then raise exception 'El área de la ubicación no está activa en Local 1.' using errcode='42501'; end if;
  if v_sede='plaza' and v_area is null and v_codigo<>'sin_asignar' then
    raise exception 'Ubicación de Local 1 no reconocida.' using errcode='42501';
  end if;

  select exists(
    select 1 from public.producto_lotes l where l.producto_id=p_producto_id
    union all select 1 from stock_internal.lote_continuidad c where c.producto_id=p_producto_id and c.sede=v_sede
    union all select 1 from stock_internal.movimientos m where m.producto_id=p_producto_id and m.sede=v_sede and m.lote_id is not null
  ) into v_loteado;

  if v_loteado then
    with ids as (
      select l.id as lote_id from public.producto_lotes l where l.producto_id=p_producto_id
      union select c.lote_canonico_id from stock_internal.lote_continuidad c where c.producto_id=p_producto_id and c.sede=v_sede
      union select m.lote_id from stock_internal.movimientos m where m.producto_id=p_producto_id and m.sede=v_sede and m.lote_id is not null
    ), detalle as (
      select i.lote_id,
        (select count(distinct q.vencimiento) from (
          select l.vencimiento from public.producto_lotes l where l.id=i.lote_id and l.producto_id=p_producto_id
          union all select c.vencimiento from stock_internal.lote_continuidad c
            where c.lote_canonico_id=i.lote_id and c.producto_id=p_producto_id and c.sede=v_sede
        ) q where q.vencimiento is not null) as vencimientos,
        (select min(q.vencimiento) from (
          select l.vencimiento from public.producto_lotes l where l.id=i.lote_id and l.producto_id=p_producto_id
          union all select c.vencimiento from stock_internal.lote_continuidad c
            where c.lote_canonico_id=i.lote_id and c.producto_id=p_producto_id and c.sede=v_sede
        ) q) as vencimiento,
        coalesce((select sum(m.cantidad) from stock_internal.movimientos m
          where m.producto_id=p_producto_id and m.sede=v_sede and m.ubicacion_id=v_ubicacion and m.lote_id=i.lote_id),0) as cantidad
      from ids i
    )
    select coalesce(jsonb_agg(jsonb_build_object(
        'clave',lote_id::text,'lote_id',lote_id,'vencimiento',vencimiento,
        'etiqueta','Lote '||lote_id::text||case when vencimiento is null then ' · vencimiento no informado' else ' · vence '||to_char(vencimiento,'DD/MM/YYYY') end,
        'cantidad',cantidad
      ) order by vencimiento nulls last,lote_id),'[]'::jsonb),
      coalesce(sum(cantidad),0)
      into v_lotes,v_total from detalle;
    if exists(
      select 1 from stock_internal.lote_continuidad c
      where c.producto_id=p_producto_id and c.sede=v_sede
      group by c.lote_canonico_id having count(distinct c.vencimiento)>1
    ) then raise exception 'El lote tiene vencimientos históricos contradictorios; requiere conciliación antes del ajuste.' using errcode='23514'; end if;
    if exists(
      select 1 from public.producto_lotes l join stock_internal.lote_continuidad c
        on c.lote_canonico_id=l.id and c.producto_id=p_producto_id and c.sede=v_sede
      where l.producto_id=p_producto_id and l.vencimiento is not null and c.vencimiento is not null and l.vencimiento<>c.vencimiento
    ) then raise exception 'El lote tiene vencimientos históricos contradictorios; requiere conciliación antes del ajuste.' using errcode='23514'; end if;
    select v_lotes||jsonb_build_array(jsonb_build_object(
      'clave','sin_lote','lote_id',null,'vencimiento',null,
      'etiqueta','Sin lote / vencimiento no informado',
      'cantidad',coalesce(sum(m.cantidad),0)
    )), v_total+coalesce(sum(m.cantidad),0)
      into v_lotes,v_total from stock_internal.movimientos m
      where m.producto_id=p_producto_id and m.sede=v_sede and m.ubicacion_id=v_ubicacion and m.lote_id is null;
  else
    select jsonb_build_array(jsonb_build_object(
      'clave','sin_lote','lote_id',null,'vencimiento',null,
      'etiqueta','Stock físico','cantidad',coalesce(sum(m.cantidad),0)
    )),coalesce(sum(m.cantidad),0)
      into v_lotes,v_total from stock_internal.movimientos m
      where m.producto_id=p_producto_id and m.sede=v_sede and m.ubicacion_id=v_ubicacion and m.lote_id is null;
  end if;

  if exists(select 1 from stock_internal.existencias e where e.producto_id=p_producto_id and e.ubicacion_id=v_ubicacion and e.cantidad<0) then
    raise exception 'La ubicación contiene un saldo de ledger negativo previo; requiere conciliación antes de continuar.' using errcode='23514';
  end if;
  return jsonb_build_object('producto_id',p_producto_id,'sede',v_sede,'ubicacion_id',v_ubicacion,
    'ubicacion_nombre',(select u.nombre from stock_internal.ubicaciones u where u.id=v_ubicacion),
    'tiene_lotes',v_loteado,'saldo_total',coalesce(v_total,0),'lotes',coalesce(v_lotes,'[]'::jsonb));
end
$function$;

create function public.stock_ajuste_guardar(
  p_referencia uuid,
  p_producto_id bigint,
  p_ubicacion_id uuid,
  p_conteos jsonb,
  p_motivo text
)
returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare
  v_actor_uid uuid;
  v_claims jsonb;
  v_actor text;
  v_sede text;
  v_ubicacion uuid;
  v_codigo text;
  v_area uuid;
  v_activa boolean;
  v_motivo text:=btrim(coalesce(p_motivo,''));
  v_loteado boolean;
  v_expected text[];
  v_actual text[];
  v_key text;
  v_lote_id bigint;
  v_before numeric;
  v_after numeric;
  v_delta numeric;
  v_vencimiento date;
  v_vencs integer;
  v_lines jsonb:='[]'::jsonb;
  v_line jsonb;
  v_existing stock_internal.ajustes_manuales;
  v_result jsonb;
begin
  v_actor_uid:=authz_internal.exigir_capacidad_b3_2a('editar');
  v_claims:=auth.jwt();
  v_actor:=coalesce(nullif(lower(btrim(v_claims->>'email')),''),v_actor_uid::text);
  if p_referencia is null then raise exception 'La referencia del ajuste es obligatoria.' using errcode='22023'; end if;
  if p_producto_id is null then raise exception 'El producto es obligatorio.' using errcode='22023'; end if;
  if length(v_motivo) not between 1 and 240 then raise exception 'Escribe un motivo breve (máximo 240 caracteres).' using errcode='22023'; end if;
  if p_conteos is null or jsonb_typeof(p_conteos)<>'object' or p_conteos='{}'::jsonb then
    raise exception 'Indica el saldo contado para cada lote mostrado.' using errcode='22023';
  end if;

  select p.sede into v_sede from public.productos p where p.id=p_producto_id and p.sede in ('central','plaza');
  if not found then raise exception 'El producto no existe en una sede habilitada para el ledger.' using errcode='22023'; end if;
  if p_ubicacion_id is null then
    if v_sede<>'central' then raise exception 'Selecciona la ubicación física del producto.' using errcode='22023'; end if;
    select u.id,u.codigo,u.area_id,u.activa into v_ubicacion,v_codigo,v_area,v_activa
      from stock_internal.ubicaciones u where u.sede='central' and u.codigo='bodega_central';
  else
    select u.id,u.codigo,u.area_id,u.activa into v_ubicacion,v_codigo,v_area,v_activa
      from stock_internal.ubicaciones u where u.id=p_ubicacion_id and u.sede=v_sede;
  end if;
  if not found or not coalesce(v_activa,false) then raise exception 'La ubicación no existe o está inactiva.' using errcode='22023'; end if;
  if v_sede='central' and (v_codigo<>'bodega_central' or v_area is not null) then raise exception 'Solo se permite ajustar Bodega central.' using errcode='42501'; end if;
  if v_sede='plaza' and v_area is not null and not exists(
    select 1 from public.areas_operativas a where a.id=v_area and a.sede='plaza' and a.estado='activa'
  ) then raise exception 'El área de la ubicación no está activa en Local 1.' using errcode='42501'; end if;
  if v_sede='plaza' and v_area is null and v_codigo<>'sin_asignar' then raise exception 'Ubicación de Local 1 no reconocida.' using errcode='42501'; end if;

  -- Serializa referencias iguales aun si llegan simultáneamente desde dos clientes.
  perform pg_advisory_xact_lock(hashtextextended('stock-adjust-ref:'||p_referencia::text,0));
  select * into v_existing from stock_internal.ajustes_manuales a where a.referencia=p_referencia;
  if found then
    if v_existing.producto_id<>p_producto_id or v_existing.ubicacion_id<>v_ubicacion
       or v_existing.motivo<>v_motivo or v_existing.conteos<>p_conteos then
      raise exception 'Esta referencia ya fue usada con un contenido diferente.' using errcode='23505';
    end if;
    return jsonb_set(v_existing.resultado,'{repetido}','true'::jsonb,true);
  end if;

  -- Comparte el mismo cerrojo producto/ubicación que usa stock_transferir.
  perform pg_advisory_xact_lock(hashtextextended('stock-location:'||p_producto_id::text||':'||v_ubicacion::text,0));
  perform 1 from public.productos p where p.id=p_producto_id and p.sede=v_sede for update;

  select exists(
    select 1 from public.producto_lotes l where l.producto_id=p_producto_id
    union all select 1 from stock_internal.lote_continuidad c where c.producto_id=p_producto_id and c.sede=v_sede
    union all select 1 from stock_internal.movimientos m where m.producto_id=p_producto_id and m.sede=v_sede and m.lote_id is not null
  ) into v_loteado;

  if v_loteado then
    select array_agg(j.k order by j.k collate "C") into v_expected from (
      select 'sin_lote'::text as k
      union select l.id::text from public.producto_lotes l where l.producto_id=p_producto_id
      union select c.lote_canonico_id::text from stock_internal.lote_continuidad c where c.producto_id=p_producto_id and c.sede=v_sede
      union select m.lote_id::text from stock_internal.movimientos m where m.producto_id=p_producto_id and m.sede=v_sede and m.lote_id is not null
    ) j;
  else
    v_expected:=array['sin_lote']::text[];
  end if;
  select array_agg(j.k order by j.k collate "C") into v_actual from jsonb_object_keys(p_conteos) as j(k);
  if v_actual is distinct from v_expected then
    raise exception 'El desglose de lotes cambió. Recarga el producto y vuelve a contar cada línea.' using errcode='22023';
  end if;

  if exists(select 1 from stock_internal.existencias e where e.producto_id=p_producto_id and e.ubicacion_id=v_ubicacion and e.cantidad<0) then
    raise exception 'La ubicación contiene un saldo de ledger negativo previo; requiere conciliación antes de continuar.' using errcode='23514';
  end if;

  foreach v_key in array v_expected loop
    if jsonb_typeof(p_conteos->v_key)<>'number' then raise exception 'Cada cantidad contada debe ser un número.' using errcode='22023'; end if;
    v_after:=(p_conteos->>v_key)::numeric;
    if v_after<0 then raise exception 'El stock contado no puede ser negativo.' using errcode='23514'; end if;
    v_lote_id:=case when v_key='sin_lote' then null else v_key::bigint end;
    if v_lote_id is not null then
      if not exists(
        select 1 from public.producto_lotes l where l.id=v_lote_id and l.producto_id=p_producto_id
        union all select 1 from stock_internal.lote_continuidad c where c.lote_canonico_id=v_lote_id and c.producto_id=p_producto_id and c.sede=v_sede
        union all select 1 from stock_internal.movimientos m where m.producto_id=p_producto_id and m.sede=v_sede and m.lote_id=v_lote_id
      ) then raise exception 'El lote ya no pertenece a este producto.' using errcode='22023'; end if;
      select count(distinct q.vencimiento),min(q.vencimiento) into v_vencs,v_vencimiento from (
        select l.vencimiento from public.producto_lotes l where l.id=v_lote_id and l.producto_id=p_producto_id
        union all select c.vencimiento from stock_internal.lote_continuidad c where c.lote_canonico_id=v_lote_id and c.producto_id=p_producto_id and c.sede=v_sede
      ) q where q.vencimiento is not null;
      if v_vencs>1 then raise exception 'El lote tiene vencimientos contradictorios; requiere conciliación antes del ajuste.' using errcode='23514'; end if;
    else
      v_vencimiento:=null;
    end if;
    select coalesce(sum(m.cantidad),0) into v_before from stock_internal.movimientos m
      where m.producto_id=p_producto_id and m.sede=v_sede and m.ubicacion_id=v_ubicacion and m.lote_id is not distinct from v_lote_id;
    v_delta:=v_after-v_before;
    v_lines:=v_lines||jsonb_build_array(jsonb_build_object(
      'clave',v_key,'lote_id',v_lote_id,'vencimiento',v_vencimiento,
      'etiqueta',case when v_key='sin_lote' and v_loteado then 'Sin lote / vencimiento no informado'
        when v_key='sin_lote' then 'Stock físico'
        else 'Lote '||v_lote_id::text||case when v_vencimiento is null then ' · vencimiento no informado' else ' · vence '||to_char(v_vencimiento,'DD/MM/YYYY') end end,
      'saldo_anterior',v_before,'saldo_contado',v_after,'diferencia',v_delta
    ));
  end loop;

  v_result:=jsonb_build_object('referencia',p_referencia,'producto_id',p_producto_id,'sede',v_sede,
    'ubicacion_id',v_ubicacion,'motivo',v_motivo,'lineas',v_lines,
    'saldo_anterior',coalesce((select sum((x->>'saldo_anterior')::numeric) from jsonb_array_elements(v_lines) x),0),
    'saldo_contado',coalesce((select sum((x->>'saldo_contado')::numeric) from jsonb_array_elements(v_lines) x),0),
    'repetido',false);

  insert into stock_internal.ajustes_manuales(referencia,producto_id,sede,ubicacion_id,actor_auth_uid,actor,motivo,conteos,resultado)
  values(p_referencia,p_producto_id,v_sede,v_ubicacion,v_actor_uid,v_actor,v_motivo,p_conteos,v_result);

  for v_line in select value from jsonb_array_elements(v_lines) loop
    v_delta:=(v_line->>'diferencia')::numeric;
    if v_delta<>0 then
      insert into stock_internal.movimientos(
        producto_id,sede,ubicacion_id,lote_id,cantidad,tipo,actor,referencia,clave_idempotencia,metadata,ajuste_manual_id
      ) values(
        p_producto_id,v_sede,v_ubicacion,nullif(v_line->>'lote_id','')::bigint,v_delta,'ajuste',v_actor,
        'Ajuste manual '||p_referencia::text,
        'ajuste:'||p_referencia::text||':'||(v_line->>'clave'),
        jsonb_build_object('ajuste_manual_id',p_referencia,'motivo',v_motivo,
          'saldo_anterior',(v_line->>'saldo_anterior')::numeric,
          'saldo_contado',(v_line->>'saldo_contado')::numeric,
          'diferencia',v_delta,'vencimiento',v_line->>'vencimiento'),
        p_referencia
      );
    end if;
  end loop;
  return v_result;
end
$function$;

revoke all on function public.stock_ajuste_desglose_leer(bigint,uuid) from public,anon,authenticated,service_role;
grant execute on function public.stock_ajuste_desglose_leer(bigint,uuid) to authenticated;
revoke all on function public.stock_ajuste_guardar(uuid,bigint,uuid,jsonb,text) from public,anon,authenticated,service_role;
grant execute on function public.stock_ajuste_guardar(uuid,bigint,uuid,jsonb,text) to authenticated;

commit;
