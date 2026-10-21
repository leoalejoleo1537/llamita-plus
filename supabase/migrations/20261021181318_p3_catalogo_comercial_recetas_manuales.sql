begin;

-- P3 crea un catálogo comercial neutral. No reutiliza recetas/fudo_productos
-- ni conecta todavía el consumo de Lama (P4).
create table catalogo_internal.productos_venta(
  id uuid primary key default gen_random_uuid(),
  nombre text not null check(length(btrim(nombre)) between 1 and 160),
  precio_venta numeric(18,6) not null default 0
    check(precio_venta>=0 and precio_venta<1000000000000),
  estado text not null default 'borrador' check(estado in ('borrador','listo','archivado')),
  revision bigint not null default 1 check(revision>0),
  creado_at timestamptz not null default now(),
  creado_por uuid not null references auth.users(id) on delete restrict,
  actualizado_at timestamptz not null default now(),
  actualizado_por uuid not null references auth.users(id) on delete restrict,
  archivado_at timestamptz,
  archivado_por uuid references auth.users(id) on delete restrict,
  constraint productos_venta_archivo_ck check(
    (estado='archivado' and archivado_at is not null and archivado_por is not null)
    or (estado<>'archivado' and archivado_at is null and archivado_por is null)
  )
);
comment on table catalogo_internal.productos_venta is
  'Identidad comercial neutral creada manualmente. No es un insumo, producto Fudo ni producto Lama.';
create unique index productos_venta_nombre_activo_uk
  on catalogo_internal.productos_venta(catalogo_internal.nombre_clave(nombre))
  where estado<>'archivado';
create index productos_venta_estado_nombre_idx
  on catalogo_internal.productos_venta(estado,nombre);

create table catalogo_internal.recetas_venta(
  id uuid primary key default gen_random_uuid(),
  producto_venta_id uuid not null references catalogo_internal.productos_venta(id) on delete restrict,
  version integer not null check(version>0),
  estado text not null check(estado in ('borrador','lista')),
  vigente boolean not null default true,
  creado_at timestamptz not null default now(),
  creado_por uuid not null references auth.users(id) on delete restrict,
  constraint recetas_venta_producto_version_uk unique(producto_venta_id,version)
);
comment on table catalogo_internal.recetas_venta is
  'Versiones manuales de recetas neutrales. Las versiones anteriores permanecen como auditoría.';
create unique index recetas_venta_vigente_uk
  on catalogo_internal.recetas_venta(producto_venta_id) where vigente;
create index recetas_venta_producto_idx
  on catalogo_internal.recetas_venta(producto_venta_id,version desc);

create table catalogo_internal.receta_venta_componentes(
  receta_id uuid not null references catalogo_internal.recetas_venta(id) on delete restrict,
  orden integer not null check(orden>0),
  asignacion_id uuid not null references public.producto_area_asignacion(id) on delete restrict,
  cantidad numeric(18,6) not null check(cantidad>0 and cantidad<1000000000000),
  creado_at timestamptz not null default now(),
  creado_por uuid not null references auth.users(id) on delete restrict,
  primary key(receta_id,orden),
  constraint receta_venta_componente_unico_uk unique(receta_id,asignacion_id)
);
comment on table catalogo_internal.receta_venta_componentes is
  'Una línea manual apunta a la configuración producto-área activa que será su origen explícito.';
create index receta_venta_componentes_asignacion_idx
  on catalogo_internal.receta_venta_componentes(asignacion_id);

-- Reservada para P5/P6: P3 no crea enlaces ni usa un POS como identidad.
create table catalogo_internal.producto_venta_pos_enlaces(
  id uuid primary key default gen_random_uuid(),
  producto_venta_id uuid not null references catalogo_internal.productos_venta(id) on delete restrict,
  proveedor text not null check(proveedor in ('lama','fudo','otro')),
  cuenta_externa text not null,
  producto_externo_id text not null,
  activo boolean not null default true,
  creado_at timestamptz not null default now(),
  creado_por uuid not null references auth.users(id) on delete restrict,
  actualizado_at timestamptz not null default now(),
  actualizado_por uuid not null references auth.users(id) on delete restrict,
  constraint producto_venta_pos_externo_uk unique(proveedor,cuenta_externa,producto_externo_id),
  constraint producto_venta_pos_producto_uk unique(producto_venta_id,proveedor,cuenta_externa)
);
comment on table catalogo_internal.producto_venta_pos_enlaces is
  'Vínculo POS explícito futuro. P3 crea la estructura vacía y no publica ni enlaza nada.';

create table catalogo_internal.producto_venta_operaciones(
  referencia uuid primary key,
  actor uuid not null references auth.users(id) on delete restrict,
  solicitud jsonb not null,
  resultado jsonb not null,
  creado_at timestamptz not null default now()
);
create index producto_venta_operaciones_actor_idx
  on catalogo_internal.producto_venta_operaciones(actor,creado_at desc);

alter table catalogo_internal.productos_venta enable row level security;
alter table catalogo_internal.productos_venta force row level security;
alter table catalogo_internal.recetas_venta enable row level security;
alter table catalogo_internal.recetas_venta force row level security;
alter table catalogo_internal.receta_venta_componentes enable row level security;
alter table catalogo_internal.receta_venta_componentes force row level security;
alter table catalogo_internal.producto_venta_pos_enlaces enable row level security;
alter table catalogo_internal.producto_venta_pos_enlaces force row level security;
alter table catalogo_internal.producto_venta_operaciones enable row level security;
alter table catalogo_internal.producto_venta_operaciones force row level security;

create policy productos_venta_cerrado on catalogo_internal.productos_venta using(false) with check(false);
create policy recetas_venta_cerrado on catalogo_internal.recetas_venta using(false) with check(false);
create policy receta_componentes_cerrado on catalogo_internal.receta_venta_componentes using(false) with check(false);
create policy producto_venta_pos_cerrado on catalogo_internal.producto_venta_pos_enlaces using(false) with check(false);
create policy producto_venta_operaciones_cerrado on catalogo_internal.producto_venta_operaciones using(false) with check(false);
revoke all on table catalogo_internal.productos_venta from public,anon,authenticated,service_role;
revoke all on table catalogo_internal.recetas_venta from public,anon,authenticated,service_role;
revoke all on table catalogo_internal.receta_venta_componentes from public,anon,authenticated,service_role;
revoke all on table catalogo_internal.producto_venta_pos_enlaces from public,anon,authenticated,service_role;
revoke all on table catalogo_internal.producto_venta_operaciones from public,anon,authenticated,service_role;

create trigger producto_venta_operaciones_inmutables
before update or delete on catalogo_internal.producto_venta_operaciones
for each row execute function catalogo_internal.inmutable();
create trigger receta_venta_componentes_inmutables
before update or delete on catalogo_internal.receta_venta_componentes
for each row execute function catalogo_internal.inmutable();

create function public.panel_ventas_listar(
  p_consulta text default '',p_producto_venta_id uuid default null
) returns jsonb
language plpgsql stable security definer set search_path=''
as $function$
begin
  perform authz_internal.exigir_capacidad_b3_2a('lectura');
  return jsonb_build_object('productos',coalesce((
    select jsonb_agg(to_jsonb(x) order by x.nombre,x.id) from (
      select pv.id,pv.nombre,pv.precio_venta,pv.estado,pv.revision,
        pv.creado_at,pv.actualizado_at,rv.id receta_id,rv.version receta_version,
        coalesce((select count(*) from catalogo_internal.receta_venta_componentes rc
          where rc.receta_id=rv.id),0) ingredientes,
        case when p_producto_venta_id is not null then coalesce((
          select jsonb_agg(jsonb_build_object(
            'orden',rc.orden,'cantidad',rc.cantidad,'asignacion_id',pa.id,
            'producto_id',p.id,'producto',p.producto,'unidad',p.unidad,
            'maestro_id',e.producto_bodega_id,'area_id',a.id,'area',a.nombre,
            'seccion_id',s.id,'seccion',s.nombre
          ) order by rc.orden)
          from catalogo_internal.receta_venta_componentes rc
          join public.producto_area_asignacion pa on pa.id=rc.asignacion_id
          join public.productos p on p.id=pa.producto_id
          join public.producto_enlace e on e.producto_sede_id=p.id and e.sede='plaza'
          join public.areas_operativas a on a.id=pa.area_id
          left join public.area_secciones s on s.id=pa.seccion_id
          where rc.receta_id=rv.id
        ),'[]'::jsonb) else '[]'::jsonb end componentes
      from catalogo_internal.productos_venta pv
      left join catalogo_internal.recetas_venta rv
        on rv.producto_venta_id=pv.id and rv.vigente
      where pv.estado<>'archivado'
        and (p_producto_venta_id is null or pv.id=p_producto_venta_id)
        and (p_producto_venta_id is not null or
          catalogo_internal.nombre_clave(pv.nombre) like
          '%'||catalogo_internal.nombre_clave(coalesce(p_consulta,''))||'%')
      order by pv.nombre,pv.id limit 100
    ) x
  ),'[]'::jsonb));
end
$function$;

create function public.panel_ingredientes_listar(p_consulta text default '')
returns jsonb
language plpgsql stable security definer set search_path=''
as $function$
begin
  perform authz_internal.exigir_capacidad_b3_2a('lectura');
  return jsonb_build_object('ingredientes',coalesce((
    select jsonb_agg(to_jsonb(x) order by x.producto,x.area,x.asignacion_id) from (
      select pa.id asignacion_id,p.id producto_id,m.id maestro_id,
        m.producto,m.unidad,a.id area_id,a.nombre area,
        pa.seccion_id,s.nombre seccion,pa.stock_min,pa.stock_max
      from public.producto_area_asignacion pa
      join public.productos p on p.id=pa.producto_id and p.sede='plaza' and p.activo='SÍ'
      join public.producto_enlace e on e.producto_sede_id=p.id and e.sede='plaza'
      join public.productos m on m.id=e.producto_bodega_id and m.sede='central' and m.activo='SÍ'
      join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza' and a.estado='activa'
      join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza' and u.activa
      left join public.area_secciones s on s.id=pa.seccion_id
      where pa.sede='plaza' and pa.estado='asignado' and pa.archivado_at is null
        and catalogo_internal.nombre_clave(m.producto) like
          '%'||catalogo_internal.nombre_clave(coalesce(p_consulta,''))||'%'
      order by m.producto,a.orden,a.nombre,pa.id limit 300
    ) x
  ),'[]'::jsonb));
end
$function$;

create function public.panel_venta_guardar(
  p_referencia uuid,p_producto_venta_id uuid,p_revision bigint,p_datos jsonb
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare
  v_actor uuid; v_prev catalogo_internal.producto_venta_operaciones;
  v_producto catalogo_internal.productos_venta; v_nombre text; v_precio numeric;
  v_estado text; v_componentes jsonb; v_linea jsonb; v_solicitud jsonb;
  v_resultado jsonb; v_receta_id uuid; v_version integer; v_orden integer:=0;
  v_asignacion uuid; v_cantidad numeric; v_ingredientes integer;
begin
  v_actor:=authz_internal.exigir_capacidad_b3_2a('editar');
  if p_referencia is null or jsonb_typeof(p_datos) is distinct from 'object' then
    raise exception 'Falta referencia o ficha comercial.' using errcode='22023';
  end if;
  v_solicitud:=jsonb_build_object('producto_venta',p_producto_venta_id,'revision',p_revision,'datos',p_datos);
  perform pg_advisory_xact_lock(hashtextextended('panel-venta-ref:'||p_referencia,0));
  select * into v_prev from catalogo_internal.producto_venta_operaciones where referencia=p_referencia;
  if found then
    if v_prev.actor<>v_actor or v_prev.solicitud<>v_solicitud then
      raise exception 'Referencia usada con otro contenido.' using errcode='22023';
    end if;
    return v_prev.resultado;
  end if;

  v_nombre:=btrim(regexp_replace(coalesce(p_datos->>'nombre',''),'[[:space:]]+',' ','g'));
  v_precio:=coalesce((p_datos->>'precio_venta')::numeric,0);
  v_estado:=coalesce(p_datos->>'estado','borrador');
  v_componentes:=coalesce(p_datos->'componentes','[]'::jsonb);
  if length(v_nombre) not between 1 and 160 or v_precio<0 or v_precio>=1000000000000
     or v_estado not in ('borrador','listo') or jsonb_typeof(v_componentes)<>'array'
     or jsonb_array_length(v_componentes)>100 then
    raise exception 'Revisa nombre, precio, estado e ingredientes.' using errcode='22023';
  end if;
  v_ingredientes:=jsonb_array_length(v_componentes);
  if v_estado='listo' and v_ingredientes=0 then
    raise exception 'Una receta lista necesita al menos un ingrediente con origen explícito.' using errcode='22023';
  end if;
  if (select count(*) from jsonb_array_elements(v_componentes) c)
     <> (select count(distinct c->>'asignacion_id') from jsonb_array_elements(v_componentes) c) then
    raise exception 'La misma configuración de ingrediente está repetida.' using errcode='23505';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('panel-venta-nombre:'||catalogo_internal.nombre_clave(v_nombre),0));
  if exists(select 1 from catalogo_internal.productos_venta pv
      where pv.id is distinct from p_producto_venta_id and pv.estado<>'archivado'
        and catalogo_internal.nombre_clave(pv.nombre)=catalogo_internal.nombre_clave(v_nombre)) then
    raise exception 'Ya existe un producto de venta con ese nombre.' using errcode='23505';
  end if;

  if p_producto_venta_id is null then
    if p_revision is not null then raise exception 'Un alta no tiene revisión previa.' using errcode='22023'; end if;
    insert into catalogo_internal.productos_venta(
      nombre,precio_venta,estado,creado_por,actualizado_por
    ) values(v_nombre,v_precio,v_estado,v_actor,v_actor) returning * into v_producto;
  else
    select * into v_producto from catalogo_internal.productos_venta
      where id=p_producto_venta_id and estado<>'archivado' for update;
    if not found then raise exception 'El producto de venta ya no está disponible.' using errcode='22023'; end if;
    if p_revision is distinct from v_producto.revision then
      raise exception 'La ficha cambió. Vuelve a abrirla antes de guardar.' using errcode='40001';
    end if;
    update catalogo_internal.productos_venta
      set nombre=v_nombre,precio_venta=v_precio,estado=v_estado,
          revision=revision+1,actualizado_at=now(),actualizado_por=v_actor
      where id=v_producto.id returning * into v_producto;
  end if;

  -- Cada guardado crea una versión; nunca altera componentes ya auditados.
  update catalogo_internal.recetas_venta set vigente=false
    where producto_venta_id=v_producto.id and vigente;
  if v_ingredientes>0 then
    select coalesce(max(version),0)+1 into v_version
      from catalogo_internal.recetas_venta where producto_venta_id=v_producto.id;
    insert into catalogo_internal.recetas_venta(
      producto_venta_id,version,estado,vigente,creado_por
    ) values(v_producto.id,v_version,case when v_estado='listo' then 'lista' else 'borrador' end,true,v_actor)
    returning id into v_receta_id;

    for v_linea in select value from jsonb_array_elements(v_componentes) loop
      v_orden:=v_orden+1;
      begin
        v_asignacion:=(v_linea->>'asignacion_id')::uuid;
        v_cantidad:=(v_linea->>'cantidad')::numeric;
      exception when invalid_text_representation or numeric_value_out_of_range then
        raise exception 'Ingrediente % inválido.',v_orden using errcode='22023';
      end;
      if v_asignacion is null or v_cantidad is null or v_cantidad<=0 or v_cantidad>=1000000000000 then
        raise exception 'Cada ingrediente necesita cantidad positiva y origen explícito.' using errcode='22023';
      end if;
      if not exists(
        select 1
        from public.producto_area_asignacion pa
        join public.productos p on p.id=pa.producto_id and p.sede='plaza' and p.activo='SÍ'
        join public.producto_enlace e on e.producto_sede_id=p.id and e.sede='plaza'
        join public.productos m on m.id=e.producto_bodega_id and m.sede='central' and m.activo='SÍ'
        join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza' and a.estado='activa'
        join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza' and u.activa
        left join public.area_secciones s on s.id=pa.seccion_id
        where pa.id=v_asignacion and pa.sede='plaza' and pa.estado='asignado'
          and pa.archivado_at is null and (pa.seccion_id is null or s.estado='activa')
      ) then
        raise exception 'El ingrediente % no tiene una configuración producto-área activa.',v_orden using errcode='22023';
      end if;
      insert into catalogo_internal.receta_venta_componentes(
        receta_id,orden,asignacion_id,cantidad,creado_por
      ) values(v_receta_id,v_orden,v_asignacion,v_cantidad,v_actor);
    end loop;
  end if;

  v_resultado:=jsonb_build_object(
    'producto_venta_id',v_producto.id,'revision',v_producto.revision,
    'estado',v_producto.estado,'receta_id',v_receta_id,
    'receta_version',v_version,'ingredientes',v_ingredientes,
    'stock_movido',false,'reserva_creada',false,'enlace_pos_creado',false
  );
  insert into catalogo_internal.producto_venta_operaciones(referencia,actor,solicitud,resultado)
    values(p_referencia,v_actor,v_solicitud,v_resultado);
  return v_resultado;
end
$function$;

revoke all on function public.panel_ventas_listar(text,uuid) from public,anon,authenticated,service_role;
revoke all on function public.panel_ingredientes_listar(text) from public,anon,authenticated,service_role;
revoke all on function public.panel_venta_guardar(uuid,uuid,bigint,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.panel_ventas_listar(text,uuid) to authenticated;
grant execute on function public.panel_ingredientes_listar(text) to authenticated;
grant execute on function public.panel_venta_guardar(uuid,uuid,bigint,jsonb) to authenticated;

comment on function public.panel_venta_guardar(uuid,uuid,bigint,jsonb) is
  'P3: guarda identidad comercial y versión manual de receta con origen producto-área explícito; no mueve stock ni conecta POS.';

commit;
