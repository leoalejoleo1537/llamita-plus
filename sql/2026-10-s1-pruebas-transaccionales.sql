-- Pruebas S1. No deja cambios: todo ocurre dentro de BEGIN ... ROLLBACK.
begin;

do $test$
declare
  v_raiz constant uuid := 'decc9a8d-0ab6-4306-bab5-a62bcaa40338'::uuid;
  v_operador constant uuid := '6c3f6e47-7a26-40ce-84f6-9fe26925d642'::uuid;
  v_comun constant uuid := '00000000-0000-4000-8000-000000000099'::uuid;
  v_n bigint;
  v_json jsonb;
  v_error text;
begin
  if (select count(*) from authz_internal.propietario_raiz)<>1
     or not exists(select 1 from authz_internal.propietario_raiz where singleton and auth_uid=v_raiz) then
    raise exception 'Falla: identidad raíz o singleton incorrecto.';
  end if;

  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',v_raiz,'role','authenticated','email',(select email from auth.users where id=v_raiz))::text,true);
  execute 'set local role authenticated';
  if not exists(select 1 from public.permisos_mios()
    where es_propietario_raiz and puede_editar and puede_fudo and puede_ajustes and puede_lama) then
    raise exception 'Falla: el propietario no recibe capacidades completas.';
  end if;
  select count(*) into v_n from public.permisos_listar();
  if v_n<>2 then raise exception 'Falla: el propietario no ve las dos cuentas Auth.'; end if;
  select public.permisos_actualizar(v_operador,true,true,false,false,'{}'::text[]) into v_json;
  if coalesce((v_json->>'puede_ajustes')::boolean,true) then
    raise exception 'Falla: la actualización protegida no se aplicó.';
  end if;
  execute 'reset role';
  select count(*) into v_n from authz_internal.permisos_auditoria where objetivo_auth_uid=v_operador;
  if v_n<>1 then raise exception 'Falla: falta la auditoría de la operación raíz.'; end if;
  execute 'set local role authenticated';
  begin
    perform public.permisos_actualizar(v_raiz,false,false,false,false,'{}'::text[]);
    raise exception 'Falla: el propietario pudo degradarse.';
  exception when insufficient_privilege then null;
  end;

  execute 'reset role';
  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',v_operador,'role','authenticated','email',(select email from auth.users where id=v_operador))::text,true);
  execute 'set local role authenticated';
  if (select count(*) from public.app_permisos)<>1 then
    raise exception 'Falla: la política propia expone filas ajenas.';
  end if;
  begin
    perform public.permisos_listar();
    raise exception 'Falla: el administrador operativo pudo listar permisos.';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.permisos_actualizar(v_raiz,true,true,true,true,'{}'::text[]);
    raise exception 'Falla: el administrador operativo pudo administrar permisos.';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.app_permisos set puede_ajustes=true where auth_uid=v_operador;
    raise exception 'Falla: authenticated conservó DML directo.';
  exception when insufficient_privilege then null;
  end;

  -- El chequeo de autorización de stock_transferir debe pasar y fallar recién
  -- en la validación de carga vacía, sin generar movimientos.
  begin
    perform public.stock_transferir(null,null,null,null,null,1,'prueba S1',null);
    raise exception 'Falla: la transferencia vacía fue aceptada.';
  exception when others then
    get stacked diagnostics v_error=message_text;
    if v_error like '%permiso%' or v_error like '%sesión%' then
      raise exception 'Falla: stock_transferir dejó de reconocer al administrador operativo: %',v_error;
    end if;
  end;

  execute 'reset role';
  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',v_comun,'role','authenticated','email','comun@example.invalid')::text,true);
  execute 'set local role authenticated';
  if exists(select 1 from public.permisos_mios()
    where puede_editar or puede_fudo or puede_ajustes or puede_lama or es_propietario_raiz) then
    raise exception 'Falla: el usuario común recibió capacidades.';
  end if;
  if (select count(*) from public.app_permisos)<>0 then
    raise exception 'Falla: el usuario común ve filas de permisos.';
  end if;
  begin
    insert into public.app_permisos(correo) values('elevacion@example.invalid');
    raise exception 'Falla: el usuario común pudo autoelevarse.';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.permisos_actualizar(v_operador,true,true,true,true,'{}'::text[]);
    raise exception 'Falla: el usuario común pudo administrar permisos.';
  exception when insufficient_privilege then null;
  end;

  execute 'reset role';
  execute 'set local role anon';
  begin
    perform count(*) from public.app_permisos;
    raise exception 'Falla: anon conserva lectura.';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.app_permisos set puede_ajustes=true;
    raise exception 'Falla: anon conserva DML.';
  exception when insufficient_privilege then null;
  end;

  execute 'reset role';
  execute 'set local role service_role';
  select count(*) into v_n from public.app_permisos;
  if v_n<>9 then raise exception 'Falla: service_role perdió la lectura requerida por Fudo.'; end if;
  begin
    update public.app_permisos set puede_ajustes=true where auth_uid=v_operador;
    raise exception 'Falla: service_role conserva DML directo.';
  exception when insufficient_privilege then null;
  end;
  execute 'reset role';
end
$test$;

rollback;
