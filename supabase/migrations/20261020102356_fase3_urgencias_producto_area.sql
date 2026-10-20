begin;

-- Fase 3: prioridad manual por producto y área. Es configuración operativa;
-- no contiene cantidades ni escribe el ledger.
do $preflight$
begin
  if to_regclass('public.producto_area_asignacion') is null
     or to_regclass('stock_internal.existencias') is null
     or to_regprocedure('authz_internal.exigir_capacidad_b3_2a(text)') is null
     or to_regprocedure('public.reparto_area_crear(uuid,uuid,text,jsonb)') is null then
    raise exception 'Fase 3 abortada: faltan configuración por área, ledger, autorización o Fase 2.';
  end if;
end
$preflight$;

alter table public.producto_area_asignacion
  add column urgente boolean not null default false,
  add column urgente_nota text,
  add column urgente_desde timestamptz,
  add column urgente_por uuid references auth.users(id) on delete restrict,
  add constraint producto_area_urgencia_nota_ck
    check(urgente_nota is null or length(btrim(urgente_nota)) between 1 and 240),
  add constraint producto_area_urgencia_estado_ck check(
    (urgente and urgente_desde is not null and urgente_por is not null)
    or
    (not urgente and urgente_nota is null and urgente_desde is null and urgente_por is null)
  );

create index producto_area_urgentes_idx
  on public.producto_area_asignacion(area_id,urgente_desde,producto_id)
  where urgente and estado='asignado' and archivado_at is null;

comment on column public.producto_area_asignacion.urgente is
  'Prioridad manual por producto y área. No se calcula desde el saldo ni mueve existencias.';
comment on column public.producto_area_asignacion.urgente_nota is
  'Nota operativa opcional de la urgencia activa.';

create function public.producto_area_urgencia_guardar(
  p_producto_id bigint,
  p_area_id uuid,
  p_urgente boolean,
  p_nota text default null
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare
  v_actor uuid;
  v_fila public.producto_area_asignacion%rowtype;
  v_nota text:=nullif(btrim(coalesce(p_nota,'')),'');
begin
  v_actor:=authz_internal.exigir_capacidad_b3_2a('editar');
  if p_producto_id is null or p_area_id is null or p_urgente is null then
    raise exception 'Producto, área y estado de urgencia son obligatorios.' using errcode='22023';
  end if;
  if v_nota is not null and length(v_nota)>240 then
    raise exception 'La nota de urgencia debe tener máximo 240 caracteres.' using errcode='22023';
  end if;
  select pa.* into v_fila
  from public.producto_area_asignacion pa
  join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza' and a.estado='activa'
  where pa.sede='plaza' and pa.producto_id=p_producto_id and pa.area_id=p_area_id
    and pa.estado='asignado' and pa.archivado_at is null
  for update of pa;
  if not found then
    raise exception 'El producto no está configurado en un área activa de Local 1.' using errcode='22023';
  end if;

  if p_urgente then
    if v_fila.urgente and v_fila.urgente_nota is not distinct from v_nota then
      return jsonb_build_object('configuracion_id',v_fila.id,'producto_id',p_producto_id,
        'area_id',p_area_id,'urgente',true,'nota',v_fila.urgente_nota,
        'desde',v_fila.urgente_desde,'repetido',true);
    end if;
    update public.producto_area_asignacion
    set urgente=true,urgente_nota=v_nota,
        urgente_desde=case when urgente then urgente_desde else now() end,
        urgente_por=case when urgente then urgente_por else v_actor end,
        actualizado_por=v_actor,actualizado_at=now()
    where id=v_fila.id
    returning * into v_fila;
  else
    if not v_fila.urgente then
      return jsonb_build_object('configuracion_id',v_fila.id,'producto_id',p_producto_id,
        'area_id',p_area_id,'urgente',false,'nota',null,'desde',null,'repetido',true);
    end if;
    update public.producto_area_asignacion
    set urgente=false,urgente_nota=null,urgente_desde=null,urgente_por=null,
        actualizado_por=v_actor,actualizado_at=now()
    where id=v_fila.id
    returning * into v_fila;
  end if;

  return jsonb_build_object('configuracion_id',v_fila.id,'producto_id',p_producto_id,
    'area_id',p_area_id,'urgente',v_fila.urgente,'nota',v_fila.urgente_nota,
    'desde',v_fila.urgente_desde,'repetido',false);
end
$function$;

create function public.producto_area_urgencias_listar(p_area_id uuid default null)
returns jsonb
language plpgsql stable security definer set search_path=''
as $function$
declare v_result jsonb;
begin
  perform authz_internal.exigir_capacidad_b3_2a('lectura');
  if p_area_id is not null and not exists(
    select 1 from public.areas_operativas a
    where a.id=p_area_id and a.sede='plaza' and a.estado='activa'
  ) then
    raise exception 'El área no existe o está archivada.' using errcode='22023';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'configuracion_id',pa.id,'area_id',a.id,'area_codigo',a.codigo,'area_nombre',a.nombre,
    'area_orden',a.orden,'producto_id',p.id,'producto',p.producto,'unidad',p.unidad,
    'stock_min',pa.stock_min,'stock_max',pa.stock_max,
    'saldo_area',coalesce(saldo.cantidad,0),'nota',pa.urgente_nota,'desde',pa.urgente_desde,
    'producto_bodega_id',enlace.producto_bodega_id,
    'enlaces_bodega',coalesce(enlace.cantidad_enlaces,0)
  ) order by a.orden,a.nombre,pa.urgente_desde,p.producto),'[]'::jsonb) into v_result
  from public.producto_area_asignacion pa
  join public.areas_operativas a on a.id=pa.area_id and a.sede='plaza' and a.estado='activa'
  join stock_internal.ubicaciones u on u.area_id=a.id and u.sede='plaza' and u.activa
  join public.productos p on p.id=pa.producto_id and p.sede='plaza' and p.activo='SÍ'
  left join lateral(
    select sum(e.cantidad)::numeric cantidad
    from stock_internal.existencias e
    where e.sede='plaza' and e.ubicacion_id=u.id and e.producto_id=p.id
  ) saldo on true
  left join lateral(
    select min(e.producto_bodega_id) producto_bodega_id,
      count(distinct e.producto_bodega_id)::integer cantidad_enlaces
    from public.producto_enlace e
    join public.productos b on b.id=e.producto_bodega_id and b.sede='central' and b.activo='SÍ'
    where e.sede='plaza' and e.producto_sede_id=p.id and e.factor=1
  ) enlace on true
  where pa.sede='plaza' and pa.estado='asignado' and pa.archivado_at is null
    and pa.urgente and (p_area_id is null or pa.area_id=p_area_id);
  return v_result;
end
$function$;

revoke all on function public.producto_area_urgencia_guardar(bigint,uuid,boolean,text)
  from public,anon,authenticated,service_role;
revoke all on function public.producto_area_urgencias_listar(uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.producto_area_urgencia_guardar(bigint,uuid,boolean,text) to authenticated;
grant execute on function public.producto_area_urgencias_listar(uuid) to authenticated;

commit;
