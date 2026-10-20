begin;

do $guard$
begin
  if to_regclass('stock_internal.lama_reservas') is null then
    raise exception 'Rollback Fase 4 abortado: el motor no está instalado.';
  end if;
  if exists(select 1 from stock_internal.lama_reservas)
     or exists(select 1 from stock_internal.lama_fuentes_directas)
     or exists(select 1 from stock_internal.lama_alertas) then
    raise exception 'Rollback Fase 4 abortado: ya existen fuentes, reservas o alertas auditables. Requiere plan de continuidad, no borrado.';
  end if;
end
$guard$;

drop trigger if exists cuentas_consumir_reservas_lama on public.cuentas;
drop trigger if exists cuentas_validar_cierre_lama on public.cuentas;
drop trigger if exists cuenta_items_mover_reserva on public.cuenta_items;
drop trigger if exists cuenta_items_proteger_reserva on public.cuenta_items;

revoke all on function public.comanda_anular(bigint,text,text,text) from public,anon,authenticated,service_role;
revoke all on function public.lama_stock_alertas_listar() from public,anon,authenticated,service_role;
revoke all on function public.lama_fuente_directa_guardar(text,uuid) from public,anon,authenticated,service_role;
revoke all on function public.lama_fuentes_directas_listar() from public,anon,authenticated,service_role;
revoke all on function public.lama_fuentes_candidatas_listar() from public,anon,authenticated,service_role;
drop function public.comanda_anular(bigint,text,text,text);
drop function public.lama_stock_alertas_listar();
drop function public.lama_fuente_directa_guardar(text,uuid);
drop function public.lama_fuentes_directas_listar();
drop function public.lama_fuentes_candidatas_listar();

drop function stock_internal.consumir_al_cerrar_lama();
drop function stock_internal.validar_cierre_lama();
drop function stock_internal.consumir_cuenta_lama(bigint,text);
drop function stock_internal.liberar_reserva_lama(bigint,text);
drop function stock_internal.consumir_reserva_lama(uuid,text);
drop function stock_internal.mover_reserva_con_linea();
drop function stock_internal.proteger_linea_lama_reservada();
drop function stock_internal.impedir_mutacion_lama_auditoria();
drop function stock_internal.auditar_lama_fuente();

drop table stock_internal.lama_reserva_movimientos;
drop table stock_internal.lama_alertas;
drop table stock_internal.lama_reservas;
drop table stock_internal.lama_fuentes_directas_auditoria;
drop table stock_internal.lama_fuentes_directas;
drop function authz_internal.exigir_lama(boolean);

-- Restauración exacta de los dos contratos Lama sustituidos por Fase 4.
create or replace function public.cuenta_confirmar(p_cuenta_id bigint,p_quien text default null)
returns public.comandas
language plpgsql security definer set search_path='public'
as $function$
declare
  v_cuenta public.cuentas;
  v_comanda public.comandas;
  v_numero integer;
  v_contenido jsonb;
begin
  select * into v_cuenta from public.cuentas where id=p_cuenta_id for update;
  if not found then raise exception 'Esa cuenta ya no existe.'; end if;
  if v_cuenta.estado='cerrada' then raise exception 'La cuenta ya está cerrada.'; end if;
  select jsonb_agg(jsonb_build_object('nombre',nombre,'cantidad',cantidad,
    'precio',precio,'comentario',comentario) order by id) into v_contenido
    from public.cuenta_items where cuenta_id=p_cuenta_id and estado='nuevo';
  if v_contenido is null then raise exception 'No hay nada nuevo que mandar a la cocina.'; end if;
  select coalesce(max(numero),0)+1 into v_numero from public.comandas where cuenta_id=p_cuenta_id;
  insert into public.comandas(sede,cuenta_id,numero,quien,contenido)
    values(v_cuenta.sede,p_cuenta_id,v_numero,p_quien,v_contenido) returning * into v_comanda;
  update public.cuenta_items set estado='confirmado',comanda_id=v_comanda.id
    where cuenta_id=p_cuenta_id and estado='nuevo';
  perform public.cuenta_recalcular(p_cuenta_id);
  return v_comanda;
end
$function$;

create or replace function public.item_anular(
  p_item_id bigint,p_motivo text,p_comentario text default null,p_quien text default null
)
returns public.cuenta_items
language plpgsql security definer set search_path='public'
as $function$
declare
  v_item public.cuenta_items;
  v_cuenta public.cuentas;
  v_pide boolean;
  v_bloqueado boolean;
begin
  select * into v_item from public.cuenta_items where id=p_item_id for update;
  if not found then raise exception 'Ese producto ya no existe en la cuenta.'; end if;
  if v_item.anulado_at is not null then return v_item; end if;
  if v_item.estado<>'confirmado' then raise exception 'Ese producto todavía no salió a la cocina: se quita, no se anula.'; end if;
  select * into v_cuenta from public.cuentas where id=v_item.cuenta_id;
  select exists(select 1 from public.lama_arqueos a where a.sede=v_cuenta.sede
    and a.estado='cerrada' and v_cuenta.cerrada_at is not null
    and v_cuenta.cerrada_at>=a.abierto_at and v_cuenta.cerrada_at<=a.cerrado_at)
    into v_bloqueado;
  if v_bloqueado then
    raise exception 'Esa venta ya quedó dentro de un arqueo cerrado: no se puede anular. Corregilo con un movimiento de ajuste en la caja del turno siguiente.';
  end if;
  select pide_comentario into v_pide from public.lama_motivos_anulacion
    where codigo=p_motivo and activo;
  if not found then raise exception 'Ese motivo de anulación no existe o está apagado.'; end if;
  if v_pide and coalesce(btrim(p_comentario),'')='' then
    raise exception 'Ese motivo necesita que se escriba el detalle.';
  end if;
  update public.cuenta_items set anulado_at=now(),anulado_por=p_quien,
    anulado_motivo=p_motivo,anulado_comentario=nullif(btrim(p_comentario),'')
    where id=p_item_id returning * into v_item;
  perform public.cuenta_recalcular(v_item.cuenta_id);
  return v_item;
end
$function$;

grant execute on function public.cuenta_confirmar(bigint,text) to public,anon,authenticated,service_role;
grant execute on function public.item_anular(bigint,text,text,text) to public,anon,authenticated,service_role;

commit;
