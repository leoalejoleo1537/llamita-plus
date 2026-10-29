-- La ficha de Bodega guarda límites, datos descriptivos y el conteo opcional
-- en una única transacción. El conteo sigue entrando exclusivamente al ledger.

create table if not exists stock_internal.producto_bodega_ficha_operaciones(
  referencia uuid primary key,
  actor uuid not null references auth.users(id) on delete restrict,
  solicitud jsonb not null,
  resultado jsonb not null,
  creado_at timestamptz not null default now()
);
alter table stock_internal.producto_bodega_ficha_operaciones enable row level security;
revoke all on stock_internal.producto_bodega_ficha_operaciones from public, anon, authenticated, service_role;
create index if not exists producto_bodega_ficha_operaciones_actor_idx
  on stock_internal.producto_bodega_ficha_operaciones(actor, creado_at desc);

create or replace function public.producto_bodega_ficha_guardar(
  p_referencia uuid,
  p_producto_id bigint,
  p_stock_min numeric,
  p_stock_max numeric,
  p_rubro text,
  p_tipo text,
  p_perecedero boolean,
  p_conteos jsonb default null,
  p_motivo text default 'Conteo/corrección manual desde ficha'
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare
  v_actor uuid;
  v_previa stock_internal.producto_bodega_ficha_operaciones;
  v_solicitud jsonb;
  v_ajuste jsonb;
  v_resultado jsonb;
  v_rubro text:=btrim(regexp_replace(coalesce(p_rubro,''),'[[:space:]]+',' ','g'));
  v_tipo text:=nullif(btrim(regexp_replace(coalesce(p_tipo,''),'[[:space:]]+',' ','g')),'');
begin
  v_actor:=authz_internal.exigir_capacidad_b3_2a('editar');
  if p_referencia is null or p_producto_id is null then
    raise exception 'La referencia y el producto son obligatorios.' using errcode='22023';
  end if;
  if length(v_rubro) not between 1 and 120 or coalesce(length(v_tipo),0)>120 then
    raise exception 'Revisa la clasificación y el tipo del producto.' using errcode='22023';
  end if;
  if p_stock_min is not null and p_stock_min<0
     or p_stock_max is not null and p_stock_max<0
     or p_stock_min is not null and p_stock_max is not null and p_stock_max<p_stock_min then
    raise exception 'Revisa el stock mínimo y máximo de Bodega.' using errcode='22023';
  end if;
  v_solicitud:=jsonb_build_object(
    'producto',p_producto_id,'min',p_stock_min,'max',p_stock_max,
    'rubro',v_rubro,'tipo',v_tipo,'perecedero',coalesce(p_perecedero,false),
    'conteos',p_conteos,'motivo',p_motivo
  );
  perform pg_advisory_xact_lock(hashtextextended('ficha-bodega:'||p_referencia::text,0));
  select * into v_previa from stock_internal.producto_bodega_ficha_operaciones where referencia=p_referencia;
  if found then
    if v_previa.actor<>v_actor or v_previa.solicitud<>v_solicitud then
      raise exception 'La referencia ya fue usada con otro contenido.' using errcode='23505';
    end if;
    return jsonb_set(v_previa.resultado,'{repetido}','true'::jsonb,true);
  end if;
  perform 1 from public.productos
    where id=p_producto_id and sede='central' and activo='SÍ' for update;
  if not found then raise exception 'El producto no existe o no pertenece a Bodega.' using errcode='22023'; end if;
  update public.productos set
    stock_min=p_stock_min::double precision, stock_max=p_stock_max::double precision,
    rubro=v_rubro, tipo=v_tipo, perecedero=coalesce(p_perecedero,false), updated_at=now()
    where id=p_producto_id;
  if p_conteos is not null then
    v_ajuste:=public.stock_ajuste_guardar(p_referencia,p_producto_id,null,p_conteos,
      coalesce(nullif(btrim(p_motivo),''),'Conteo/corrección manual desde ficha'));
  end if;
  v_resultado:=jsonb_build_object('producto_id',p_producto_id,'ajuste',v_ajuste,'repetido',false);
  insert into stock_internal.producto_bodega_ficha_operaciones(referencia,actor,solicitud,resultado)
    values(p_referencia,v_actor,v_solicitud,v_resultado);
  return v_resultado;
end
$function$;

revoke all on function public.producto_bodega_ficha_guardar(uuid,bigint,numeric,numeric,text,text,boolean,jsonb,text)
  from public, anon, authenticated, service_role;
grant execute on function public.producto_bodega_ficha_guardar(uuid,bigint,numeric,numeric,text,text,boolean,jsonb,text)
  to authenticated;
