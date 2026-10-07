create index permisos_auditoria_actor_idx
  on authz_internal.permisos_auditoria(actor_auth_uid);
create index permisos_auditoria_objetivo_idx
  on authz_internal.permisos_auditoria(objetivo_auth_uid);
create index propietario_raiz_creado_por_idx
  on authz_internal.propietario_raiz(creado_por);
