--  DÓNDE VA:  Supabase MCP → proyecto llamita-plus → aplicar migración
--  ES:        una migración versionada
--  TARDA:     segundos
--  QUÉ HACE:  crea el catálogo público de sedes, de solo lectura para la app
--  QUÉ VER:   Local 1/plaza y Bodega/central activas; Local 2/angamos y
--             bodega histórica archivadas. No toca tablas operativas.

create table public.sede_registro (
  codigo text primary key,
  nombre_visible text not null check (length(btrim(nombre_visible)) > 0),
  tipo text not null check (tipo in ('local', 'logistica', 'historica')),
  estado text not null check (estado in ('activa', 'archivada')),
  creado_at timestamptz not null default now(),
  actualizado_at timestamptz not null default now(),
  constraint sede_registro_codigo_formato
    check (codigo ~ '^[a-z][a-z0-9_]*$'),
  constraint sede_registro_central_protegida
    check (codigo <> 'central' or (tipo = 'logistica' and estado = 'activa')),
  constraint sede_registro_bodega_historica_protegida
    check (codigo <> 'bodega' or (tipo = 'historica' and estado = 'archivada'))
);

comment on table public.sede_registro is
  'Registro de sedes/nodos visibles. codigo es estable; el cliente solo puede leer.';
comment on column public.sede_registro.codigo is
  'Clave interna estable utilizada por las tablas operativas existentes.';
comment on column public.sede_registro.nombre_visible is
  'Nombre editable para interfaces; no reemplaza la clave interna.';
comment on column public.sede_registro.tipo is
  'local, logistica o historica. central permanece como nodo logístico.';
comment on column public.sede_registro.estado is
  'activa o archivada; archivar no borra ni modifica datos operativos.';

create or replace function public.sede_registro_codigo_inmutable()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if new.codigo is distinct from old.codigo then
    raise exception 'El código interno de una sede es estable y no se puede cambiar';
  end if;
  return new;
end;
$$;

revoke all on function public.sede_registro_codigo_inmutable() from public, anon, authenticated;

create trigger sede_registro_no_cambiar_codigo
before update of codigo on public.sede_registro
for each row execute function public.sede_registro_codigo_inmutable();

alter table public.sede_registro enable row level security;
revoke all privileges on table public.sede_registro from public, anon, authenticated;
grant select on table public.sede_registro to anon, authenticated;
create policy sede_registro_lectura_catalogo
  on public.sede_registro
  for select to anon, authenticated
  using (true);

insert into public.sede_registro (codigo, nombre_visible, tipo, estado) values
  ('plaza',   'Local 1',          'local',      'activa'),
  ('angamos', 'Local 2',          'local',      'archivada'),
  ('central', 'Bodega',           'logistica',  'activa'),
  ('bodega',  'Bodega histórica', 'historica',  'archivada');
