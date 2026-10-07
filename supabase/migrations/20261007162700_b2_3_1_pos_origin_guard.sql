-- B2.3.1 — origen POS exclusivo por sede.
-- Proyecto autorizado: Llamita Plus iuryhsjucblmebdogewa.
-- No activa Fudo/Lama real; plaza parte en ninguno y central no admite POS.

create table stock_internal.origen_pos (
  sede text primary key references public.sede_registro(codigo) on update restrict on delete restrict,
  origen text not null check (
    (sede = 'plaza' and origen in ('fudo','lama','toteat','ninguno','prueba'))
    or (sede in ('central','angamos','bodega') and origen = 'ninguno')
  ),
  actualizado_at timestamptz not null default now(),
  actualizado_por text not null default 'sistema:migracion_b2_3_1'
);

comment on table stock_internal.origen_pos is
  'Una sola fuente POS de inventario por sede. Privada; cambiarla requiere operación administrativa de backend aún no implementada.';

insert into stock_internal.origen_pos(sede,origen) values
  ('central','ninguno'),
  ('plaza','ninguno'),
  ('angamos','ninguno'),
  ('bodega','ninguno')
on conflict (sede) do nothing;

alter table stock_internal.origen_pos enable row level security;
revoke all on stock_internal.origen_pos from public,anon,authenticated,service_role;
drop policy if exists stock_interno_solo_privado_origen_pos on stock_internal.origen_pos;
create policy stock_interno_solo_privado_origen_pos on stock_internal.origen_pos
  as restrictive for all to public using (false) with check (false);

create or replace function stock_internal.origen_pos_es(p_sede text,p_origen text)
returns boolean
language sql stable security definer set search_path=''
as $function$
  select coalesce((select c.origen=p_origen
                     from stock_internal.origen_pos c
                    where c.sede=p_sede),false)
     and p_origen in ('fudo','lama','toteat')
$function$;
revoke all on function stock_internal.origen_pos_es(text,text) from public,anon,authenticated,service_role;

create or replace function public.stock_pos_origen_permitido(p_sede text,p_origen text)
returns boolean
language sql stable security definer set search_path=''
as $function$
  select stock_internal.origen_pos_es(p_sede,p_origen)
$function$;
revoke all on function public.stock_pos_origen_permitido(text,text) from public,anon,authenticated;
grant execute on function public.stock_pos_origen_permitido(text,text) to service_role;

create or replace function stock_internal.trg_validar_origen_fudo()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  if not stock_internal.origen_pos_es(new.sede,'fudo') then
    raise exception 'Origen POS no autorizado: Fudo no es el POS activo de la sede %.',new.sede
      using errcode='42501';
  end if;
  return new;
end
$function$;
revoke all on function stock_internal.trg_validar_origen_fudo() from public,anon,authenticated,service_role;
drop trigger if exists trg_pos_origen_fudo on public.fudo_movimientos;
create trigger trg_pos_origen_fudo
before insert or update of sede,aplicado on public.fudo_movimientos
for each row execute function stock_internal.trg_validar_origen_fudo();

create or replace function stock_internal.trg_validar_origen_lama_config()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  if lower(new.modo)='real' and not stock_internal.origen_pos_es(new.sede,'lama') then
    raise exception 'Origen POS no autorizado: Lama solo puede usar modo real cuando es el POS activo de la sede %.',new.sede
      using errcode='42501';
  end if;
  return new;
end
$function$;
revoke all on function stock_internal.trg_validar_origen_lama_config() from public,anon,authenticated,service_role;
drop trigger if exists trg_pos_origen_00_lama_config on public.lama_stock_config;
create trigger trg_pos_origen_00_lama_config
before insert or update of sede,modo on public.lama_stock_config
for each row execute function stock_internal.trg_validar_origen_lama_config();

create or replace function stock_internal.trg_validar_origen_lama_aplicacion()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare v_sede text; v_modo text;
begin
  if new.estado in ('pendiente','aplicado') then
    select e.sede,e.modo_efectivo into v_sede,v_modo
      from public.lama_stock_eventos e where e.id=new.evento_id;
    if v_modo='real' and not stock_internal.origen_pos_es(v_sede,'lama') then
      raise exception 'Origen POS no autorizado: Lama no puede aplicar inventario real en la sede %.',v_sede
        using errcode='42501';
    end if;
  end if;
  return new;
end
$function$;
revoke all on function stock_internal.trg_validar_origen_lama_aplicacion() from public,anon,authenticated,service_role;
drop trigger if exists trg_pos_origen_lama_aplicacion on public.lama_stock_aplicaciones;
create trigger trg_pos_origen_lama_aplicacion
before insert or update of estado on public.lama_stock_aplicaciones
for each row execute function stock_internal.trg_validar_origen_lama_aplicacion();

-- Mantener las implementaciones instaladas; insertar una guarda con fail-closed
-- en sus definiciones actuales y abortar si el código instalado difiere.
do $guard_fudo$
declare v_oid oid; v_def text; v_needle text; v_replacement text;
begin
  v_oid := to_regprocedure('public.fudo_procesar_item(text,text,text,text,text,numeric,text,timestamp with time zone)');
  if v_oid is null then raise exception 'B2.3.1 detenido: no existe la firma instalada de fudo_procesar_item.'; end if;
  v_def := replace(pg_get_functiondef(v_oid),E'\r','');
  v_needle := $needle$begin
  v_tipo := upper(coalesce(p_sale_type,'EAT-IN'));$needle$;
  v_replacement := $replacement$begin
  if not stock_internal.origen_pos_es(p_sede,'fudo') then
    raise exception 'Origen POS no autorizado: Fudo no es el POS activo de la sede %.',p_sede
      using errcode='42501';
  end if;
  v_tipo := upper(coalesce(p_sale_type,'EAT-IN'));$replacement$;
  if strpos(v_def,v_needle)=0 then raise exception 'B2.3.1 detenido: fudo_procesar_item cambió; revisar pg_get_functiondef.'; end if;
  execute replace(v_def,v_needle,v_replacement);
end
$guard_fudo$;

revoke all on function public.fudo_procesar_item(text,text,text,text,text,numeric,text,timestamp with time zone) from public,anon,authenticated;
grant execute on function public.fudo_procesar_item(text,text,text,text,text,numeric,text,timestamp with time zone) to service_role;

do $guard_lama$
declare v_oid oid; v_def text; v_needle text; v_replacement text;
begin
  v_oid := to_regprocedure('public.lama_stock_aplicar_evento(uuid)');
  if v_oid is null then raise exception 'B2.3.1 detenido: no existe la firma instalada de lama_stock_aplicar_evento.'; end if;
  v_def := replace(pg_get_functiondef(v_oid),E'\r','');
  v_needle := $needle$  if v_event.modo_efectivo = 'apagado' then
    return 0;
  end if;

  begin
    for v_item in$needle$;
  v_replacement := $replacement$  if v_event.modo_efectivo = 'apagado' then
    return 0;
  end if;

  begin
    if v_event.modo_efectivo='real'
       and not stock_internal.origen_pos_es(v_event.sede,'lama') then
      raise exception 'Origen POS no autorizado: Lama no es el POS activo de la sede %.',v_event.sede
        using errcode='42501';
    end if;

    for v_item in$replacement$;
  if strpos(v_def,v_needle)=0 then raise exception 'B2.3.1 detenido: lama_stock_aplicar_evento cambió; revisar pg_get_functiondef.'; end if;
  execute replace(v_def,v_needle,v_replacement);
end
$guard_lama$;
