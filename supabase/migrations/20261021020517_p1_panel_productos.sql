begin;

create schema catalogo_internal;
revoke all on schema catalogo_internal from public,anon,authenticated,service_role;

alter table public.productos
  add column costo_compra numeric(18,6) not null default 0 check(costo_compra>=0 and costo_compra<1000000000000),
  add column costo_pendiente boolean not null default true,
  add column panel_gestionado boolean not null default false,
  add column catalogo_revision bigint not null default 0;
comment on column public.productos.costo_compra is 'Costo por unidad declarada. Autoridad: maestro central; proyección atómica a plaza. No convierte cantidades.';

create function catalogo_internal.nombre_clave(p_nombre text) returns text
language sql immutable set search_path='' as $$
  select translate(lower(btrim(regexp_replace(p_nombre,'[[:space:]]+',' ','g'))),'áéíóúüñ','aeiouun')
$$;
revoke all on function catalogo_internal.nombre_clave(text) from public,anon,authenticated,service_role;

-- No se fusionan históricos. La restricción cubre altas/renombres activos.
create unique index productos_central_nombre_activo_uk on public.productos
  (catalogo_internal.nombre_clave(producto)) where sede='central' and activo='SÍ';

create table catalogo_internal.operaciones(
  referencia uuid primary key,
  actor uuid not null references auth.users(id) on delete restrict,
  solicitud jsonb not null,
  resultado jsonb not null,
  anterior jsonb,
  creado_at timestamptz not null default now()
);
create index catalogo_operaciones_actor_idx on catalogo_internal.operaciones(actor);
create table catalogo_internal.permiso_escritura(
  backend_pid integer not null, txid bigint not null,
  primary key(backend_pid,txid)
);
alter table catalogo_internal.operaciones enable row level security;
alter table catalogo_internal.operaciones force row level security;
alter table catalogo_internal.permiso_escritura enable row level security;
alter table catalogo_internal.permiso_escritura force row level security;
create policy cerrado on catalogo_internal.operaciones using(false) with check(false);
create policy cerrado on catalogo_internal.permiso_escritura using(false) with check(false);
revoke all on all tables in schema catalogo_internal from public,anon,authenticated,service_role;

create function catalogo_internal.inmutable() returns trigger
language plpgsql set search_path='' as $$
begin raise exception 'La auditoría del catálogo es inmutable.'; end $$;
create trigger catalogo_operaciones_inmutables before update or delete on catalogo_internal.operaciones
for each row execute function catalogo_internal.inmutable();

create function catalogo_internal.proteger_producto() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_protegido boolean; v_cambio boolean;
begin
  if tg_op='INSERT' then
    v_cambio:=new.panel_gestionado or new.costo_compra<>0 or not new.costo_pendiente or new.catalogo_revision<>0;
  else
    v_protegido:=old.panel_gestionado or exists(
      select 1 from public.producto_enlace e join public.productos m on m.id=e.producto_bodega_id
      where e.producto_sede_id=old.id and e.sede='plaza' and m.panel_gestionado);
    v_cambio:=new.panel_gestionado is distinct from old.panel_gestionado
      or new.costo_compra is distinct from old.costo_compra
      or new.costo_pendiente is distinct from old.costo_pendiente
      or new.catalogo_revision is distinct from old.catalogo_revision
      or (v_protegido and (new.producto is distinct from old.producto or new.unidad is distinct from old.unidad));
  end if;
  if v_cambio and not exists(select 1 from catalogo_internal.permiso_escritura
      where backend_pid=pg_backend_pid() and txid=txid_current()) then
    raise exception 'Edita nombre, unidad y costo una sola vez en Panel de productos.' using errcode='42501';
  end if;
  return new;
end $$;
create trigger catalogo_proteger_producto before insert or update on public.productos
for each row execute function catalogo_internal.proteger_producto();

-- B1 sigue pudiendo enlazar: cualquier representación posterior hereda el maestro.
create function catalogo_internal.enlace_coherente() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_m public.productos; v_permiso boolean;
begin
  if tg_op in ('UPDATE','DELETE') and exists(select 1 from public.productos m
      where m.id=old.producto_bodega_id and m.panel_gestionado and old.sede='plaza') then
    raise exception 'El vínculo de este insumo está gobernado por Panel de productos.' using errcode='42501';
  end if;
  if tg_op='DELETE' then return old; end if;
  if new.sede<>'plaza' then return new; end if;
  select * into v_m from public.productos where id=new.producto_bodega_id for update;
  if not v_m.panel_gestionado then return new; end if;
  perform authz_internal.exigir_capacidad_b3_2a('editar');
  if new.factor<>1 or not exists(select 1 from public.productos where id=new.producto_sede_id and sede='plaza') then
    raise exception 'El Panel requiere representación Local 1 y la misma unidad (factor 1).' using errcode='22023';
  end if;
  insert into catalogo_internal.permiso_escritura values(pg_backend_pid(),txid_current()) on conflict do nothing;
  v_permiso:=found;
  update public.productos set producto=v_m.producto,unidad=v_m.unidad,
    costo_compra=v_m.costo_compra,costo_pendiente=v_m.costo_pendiente
    where id=new.producto_sede_id;
  if v_permiso then delete from catalogo_internal.permiso_escritura where backend_pid=pg_backend_pid() and txid=txid_current(); end if;
  return new;
end $$;
create trigger catalogo_enlace_coherente before insert or update or delete on public.producto_enlace
for each row execute function catalogo_internal.enlace_coherente();

create function public.panel_productos_listar(p_consulta text default '',p_maestro_id bigint default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  perform authz_internal.exigir_capacidad_b3_2a('editar');
  return jsonb_build_object('productos',coalesce((select jsonb_agg(to_jsonb(x)) from (
    select m.id,m.producto,m.unidad,m.rubro,m.costo_compra,m.costo_pendiente,m.panel_gestionado,m.catalogo_revision,
      coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'producto',p.producto,'unidad',p.unidad,'factor',e.factor,'activo',p.activo)
        order by p.id) from public.producto_enlace e join public.productos p on p.id=e.producto_sede_id
        where e.producto_bodega_id=m.id and e.sede='plaza'),'[]'::jsonb) representaciones,
      coalesce((select jsonb_agg(jsonb_build_object('producto_id',pa.producto_id,'area_id',pa.area_id,
        'area_nombre',a.nombre,'seccion_id',pa.seccion_id,'stock_min',pa.stock_min,'stock_max',pa.stock_max,'es_principal',pa.es_principal))
        from public.producto_enlace e join public.producto_area_asignacion pa on pa.producto_id=e.producto_sede_id and pa.estado='asignado'
        join public.areas_operativas a on a.id=pa.area_id
        where e.producto_bodega_id=m.id and e.sede='plaza'),'[]'::jsonb) configuraciones
    from public.productos m where m.sede='central' and m.activo='SÍ'
      and (p_maestro_id is null or m.id=p_maestro_id)
      and (p_maestro_id is not null or catalogo_internal.nombre_clave(m.producto) like '%'||catalogo_internal.nombre_clave(coalesce(p_consulta,''))||'%')
    order by m.producto,m.id limit 100
  ) x),'[]'::jsonb),
  'grupos',coalesce((select jsonb_agg(rubro order by rubro) from (select distinct rubro from public.productos
    where sede='central' and nullif(btrim(rubro),'') is not null) g),'[]'::jsonb));
end $$;

create function public.panel_producto_guardar(
  p_referencia uuid,p_maestro_id bigint,p_revision bigint,p_datos jsonb
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid; v_prev catalogo_internal.operaciones; v_m public.productos; v_local bigint;
  v_nombre text; v_unidad text; v_rubro text; v_costo numeric; v_pendiente boolean;
  v_areas jsonb; v_area jsonb; v_solicitud jsonb; v_resultado jsonb; v_anterior jsonb;
  v_id uuid; v_n integer;
begin
  v_actor:=authz_internal.exigir_capacidad_b3_2a('editar');
  if p_referencia is null or jsonb_typeof(p_datos) is distinct from 'object' then raise exception 'Falta referencia o ficha.' using errcode='22023'; end if;
  v_solicitud:=jsonb_build_object('maestro',p_maestro_id,'revision',p_revision,'datos',p_datos);
  perform pg_advisory_xact_lock(hashtextextended('panel-ref:'||p_referencia,0));
  select * into v_prev from catalogo_internal.operaciones where referencia=p_referencia;
  if found then
    if v_prev.actor<>v_actor or v_prev.solicitud<>v_solicitud then raise exception 'Referencia usada con otro contenido.' using errcode='22023'; end if;
    return v_prev.resultado;
  end if;
  v_nombre:=btrim(regexp_replace(coalesce(p_datos->>'nombre',''),'[[:space:]]+',' ','g'));
  v_unidad:=nullif(btrim(p_datos->>'unidad'),'');
  v_rubro:=nullif(btrim(p_datos->>'rubro'),'');
  v_costo:=coalesce((p_datos->>'costo_compra')::numeric,0);
  v_pendiente:=coalesce((p_datos->>'costo_pendiente')::boolean,true);
  v_areas:=coalesce(p_datos->'areas','[]'::jsonb);
  if length(v_nombre) not between 1 and 160 or coalesce(length(v_unidad),0)>40 or v_rubro is null
    or v_costo<0 or v_costo>=1000000000000 or (v_pendiente and v_costo<>0)
    or jsonb_typeof(v_areas)<>'array' then raise exception 'Revisa nombre, unidad, grupo y costo (pendiente = cero).' using errcode='22023'; end if;
  if jsonb_array_length(v_areas)>100 then raise exception 'Demasiadas áreas.' using errcode='22023'; end if;
  if (select count(*) from jsonb_array_elements(v_areas))<>(select count(distinct x->>'area_id') from jsonb_array_elements(v_areas) x)
     or (select count(*) from jsonb_array_elements(v_areas) x where coalesce((x->>'es_principal')::boolean,false))>1 then
    raise exception 'Áreas repetidas o más de un área principal.' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('panel-nombre:'||catalogo_internal.nombre_clave(v_nombre),0));
  if exists(select 1 from public.productos where sede='central' and id is distinct from p_maestro_id
      and catalogo_internal.nombre_clave(producto)=catalogo_internal.nombre_clave(v_nombre)) then
    raise exception 'Ya existe ese insumo en Bodega (puede estar archivado). Selecciónalo; no se creó otro.' using errcode='23505';
  end if;
  if p_maestro_id is not null then
    select * into v_m from public.productos where id=p_maestro_id and sede='central' and activo='SÍ' for update;
    if not found then raise exception 'El maestro ya no está disponible.' using errcode='22023'; end if;
    if p_revision is distinct from v_m.catalogo_revision then raise exception 'La ficha cambió. Vuelve a abrirla antes de guardar.' using errcode='40001'; end if;
    v_anterior:=to_jsonb(v_m);
    if exists(select 1 from public.producto_enlace e join public.productos p on p.id=e.producto_sede_id
      where e.producto_bodega_id=v_m.id and e.sede='plaza' and (e.factor<>1 or p.sede<>'plaza')) then
      raise exception 'Este maestro tiene un enlace con conversión o sede incoherente. Requiere revisión; no se cambió nada.' using errcode='22023';
    end if;
  elsif p_revision is not null then raise exception 'Un alta no tiene revisión previa.' using errcode='22023'; end if;

  insert into catalogo_internal.permiso_escritura values(pg_backend_pid(),txid_current());
  if p_maestro_id is null then
    insert into public.productos(producto,rubro,sede,stock_actual,activo,origen,unidad,costo_compra,costo_pendiente,panel_gestionado,catalogo_revision)
      values(v_nombre,v_rubro,'central',0,'SÍ','panel_p1',v_unidad,v_costo,v_pendiente,true,1) returning * into v_m;
  else
    update public.productos set producto=v_nombre,unidad=v_unidad,costo_compra=v_costo,costo_pendiente=v_pendiente,
      panel_gestionado=true,catalogo_revision=catalogo_revision+1,updated_at=now()
      where id=v_m.id returning * into v_m;
  end if;
  -- Orden estable; se propagan atributos, nunca cantidades ni identidad.
  perform 1 from public.productos p join public.producto_enlace e on e.producto_sede_id=p.id
    where e.producto_bodega_id=v_m.id and e.sede='plaza' order by p.id for update of p;
  update public.productos p set producto=v_m.producto,unidad=v_m.unidad,costo_compra=v_m.costo_compra,costo_pendiente=v_m.costo_pendiente
    from public.producto_enlace e where e.producto_sede_id=p.id and e.producto_bodega_id=v_m.id and e.sede='plaza';

  v_local:=nullif(p_datos->>'representacion_id','')::bigint;
  if jsonb_array_length(v_areas)>0 then
    if v_local is not null and not exists(select 1 from public.producto_enlace e join public.productos p on p.id=e.producto_sede_id
        where e.producto_bodega_id=v_m.id and e.producto_sede_id=v_local and e.sede='plaza' and p.sede='plaza' and p.activo='SÍ') then
      raise exception 'Selecciona una representación enlazada a este maestro.' using errcode='22023';
    end if;
    if v_local is null then
      select count(*),min(e.producto_sede_id) into v_n,v_local from public.producto_enlace e
        join public.productos p on p.id=e.producto_sede_id and p.sede='plaza' and p.activo='SÍ'
        where e.producto_bodega_id=v_m.id and e.sede='plaza';
      if v_n>1 then raise exception 'Hay varias representaciones: elige explícitamente una.' using errcode='22023'; end if;
      if v_n=0 then
        if exists(select 1 from public.producto_enlace where producto_bodega_id=v_m.id and sede='plaza') then
          raise exception 'La representación está archivada. Requiere revisión antes de crear otra.' using errcode='22023';
        end if;
        if exists(select 1 from public.productos p where p.sede='plaza'
            and catalogo_internal.nombre_clave(p.producto)=catalogo_internal.nombre_clave(v_m.producto)) then
          raise exception 'Existe una ficha Local 1 del mismo nombre sin enlace explícito. Revisa el vínculo antes de crear otra.' using errcode='23505';
        end if;
        insert into public.productos(producto,rubro,sede,stock_actual,activo,origen,unidad,costo_compra,costo_pendiente)
          values(v_m.producto,v_m.rubro,'plaza',0,'SÍ','panel_p1',v_m.unidad,v_m.costo_compra,v_m.costo_pendiente) returning id into v_local;
        insert into public.producto_enlace(producto_bodega_id,producto_sede_id,sede,factor,creado_por)
          values(v_m.id,v_local,'plaza',1,v_actor::text);
      end if;
    end if;
    for v_area in select value from jsonb_array_elements(v_areas) order by value->>'area_id' loop
      if exists(select 1 from public.producto_enlace e join public.producto_area_asignacion pa on pa.producto_id=e.producto_sede_id
          where e.sede='plaza' and e.producto_bodega_id=v_m.id and pa.area_id=(v_area->>'area_id')::uuid
            and pa.estado='asignado' and pa.producto_id<>v_local) then
        raise exception 'Otra representación del maestro ya está configurada en esa área.' using errcode='23505';
      end if;
      v_id:=stock_internal.guardar_configuracion_producto(v_local,(v_area->>'area_id')::uuid,
        nullif(v_area->>'seccion_id','')::uuid,(v_area->>'stock_min')::numeric,(v_area->>'stock_max')::numeric,
        coalesce((v_area->>'es_principal')::boolean,false),v_actor);
    end loop;
  end if;
  v_resultado:=jsonb_build_object('maestro_id',v_m.id,'representacion_id',v_local,'revision',v_m.catalogo_revision,'stock_movido',false);
  insert into catalogo_internal.operaciones(referencia,actor,solicitud,resultado,anterior)
    values(p_referencia,v_actor,v_solicitud,v_resultado,v_anterior);
  delete from catalogo_internal.permiso_escritura where backend_pid=pg_backend_pid() and txid=txid_current();
  return v_resultado;
end $$;

revoke all on all functions in schema catalogo_internal from public,anon,authenticated,service_role;
revoke all on function public.panel_productos_listar(text,bigint),public.panel_producto_guardar(uuid,bigint,bigint,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.panel_productos_listar(text,bigint),public.panel_producto_guardar(uuid,bigint,bigint,jsonb) to authenticated;
commit;
