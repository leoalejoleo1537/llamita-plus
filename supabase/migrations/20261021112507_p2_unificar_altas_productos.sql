begin;

-- P2 conserva el motor P1 y añade el retorno a Recetas: una
-- representación enlazada en Local 1, sin saldo y todavía Sin asignar.
create or replace function public.panel_producto_guardar(
  p_referencia uuid,p_maestro_id bigint,p_revision bigint,p_datos jsonb
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid; v_prev catalogo_internal.operaciones; v_m public.productos; v_local bigint;
  v_nombre text; v_unidad text; v_rubro text; v_costo numeric; v_pendiente boolean;
  v_areas jsonb; v_area jsonb; v_solicitud jsonb; v_resultado jsonb; v_anterior jsonb;
  v_id uuid; v_n integer; v_crear_local boolean; v_local_creado boolean:=false;
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
  v_crear_local:=coalesce((p_datos->>'crear_representacion')::boolean,false);
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
      values(v_nombre,v_rubro,'central',0,'SÍ','panel_p2',v_unidad,v_costo,v_pendiente,true,1) returning * into v_m;
  else
    update public.productos set producto=v_nombre,unidad=v_unidad,costo_compra=v_costo,costo_pendiente=v_pendiente,
      panel_gestionado=true,catalogo_revision=catalogo_revision+1,updated_at=now()
      where id=v_m.id returning * into v_m;
  end if;
  perform 1 from public.productos p join public.producto_enlace e on e.producto_sede_id=p.id
    where e.producto_bodega_id=v_m.id and e.sede='plaza' order by p.id for update of p;
  update public.productos p set producto=v_m.producto,unidad=v_m.unidad,costo_compra=v_m.costo_compra,costo_pendiente=v_m.costo_pendiente
    from public.producto_enlace e where e.producto_sede_id=p.id and e.producto_bodega_id=v_m.id and e.sede='plaza';

  v_local:=nullif(p_datos->>'representacion_id','')::bigint;
  if jsonb_array_length(v_areas)>0 or v_crear_local then
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
          values(v_m.producto,v_m.rubro,'plaza',0,'SÍ','panel_p2',v_m.unidad,v_m.costo_compra,v_m.costo_pendiente) returning id into v_local;
        insert into public.producto_enlace(producto_bodega_id,producto_sede_id,sede,factor,creado_por)
          values(v_m.id,v_local,'plaza',1,v_actor::text);
        v_local_creado:=true;
      end if;
    end if;
    if v_local_creado and jsonb_array_length(v_areas)=0 then
      v_id:=stock_internal.guardar_preferencia_producto(v_local,null,v_actor);
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

-- Ya no queda una alta visible fuera del Panel. Las lecturas legacy se
-- conservan por compatibilidad, pero sus escritores dejan de ser invocables
-- por navegador.
revoke execute on function public.crear_producto_enlazado(text,text,numeric,numeric,boolean,jsonb,text) from public,anon,authenticated;
revoke execute on function public.producto_plaza_crear(text,text,double precision,double precision,boolean,text,text,uuid,text,text) from public,anon,authenticated;
revoke execute on function public.producto_plaza_crear_configurado(text,text,double precision,double precision,boolean,text,text,uuid,uuid,text,text) from public,anon,authenticated;
revoke execute on function public.bodega_producto_area_agregar(bigint,bigint,boolean,uuid,uuid,numeric,numeric,boolean,boolean) from public,anon,authenticated;

-- El navegador solo puede crear productos mediante el SECURITY DEFINER P1/P2.
drop policy if exists "app puede insertar productos" on public.productos;
drop policy if exists "auth insert productos" on public.productos;
revoke insert on public.productos from public,anon,authenticated;

revoke all on function public.panel_producto_guardar(uuid,bigint,bigint,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.panel_producto_guardar(uuid,bigint,bigint,jsonb) to authenticated;

comment on function public.panel_producto_guardar(uuid,bigint,bigint,jsonb) is
'P2: única alta humana de insumos; crea/reutiliza maestro central, representación plaza opcional y configuraciones sin mover stock.';

commit;
