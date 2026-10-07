-- DÓNDE VA: Supabase MCP → proyecto Llamita Plus → aplicar migración
-- ES:       estructura aditiva; no contiene saldos ni asignaciones de productos
-- QUÉ CREA: áreas operativas y vínculo preparatorio producto-sede-área
-- QUÉ NO HACE: no modifica productos, stock, lotes ni datos operativos

create table public.areas_operativas (
  id uuid primary key default gen_random_uuid(),
  sede text not null references public.sede_registro(codigo) on update restrict on delete restrict,
  codigo text not null,
  nombre text not null check (length(btrim(nombre)) > 0),
  estado text not null default 'activa' check (estado in ('activa','archivada')),
  orden integer not null default 0,
  creado_at timestamptz not null default now(),
  actualizado_at timestamptz not null default now(),
  constraint areas_operativas_codigo_formato check (codigo ~ '^[a-z][a-z0-9_]*$'),
  constraint areas_operativas_codigo_reservado check (codigo <> 'sin_asignar'),
  constraint areas_operativas_sede_codigo_uk unique (sede,codigo),
  constraint areas_operativas_sede_nombre_uk unique (sede,nombre)
);

comment on table public.areas_operativas is
  'Catálogo de áreas físicas de inventario por sede. No almacena existencias.';
comment on column public.areas_operativas.codigo is
  'Clave estable del área dentro de su sede; el nombre visible puede cambiar.';
comment on column public.areas_operativas.sede is
  'Código de sede existente en sede_registro. B2.1 solo inicializa plaza.';

create table public.producto_area_asignacion (
  id uuid primary key default gen_random_uuid(),
  sede text not null references public.sede_registro(codigo) on update restrict on delete restrict,
  producto_id bigint not null references public.productos(id) on update restrict on delete restrict,
  area_id uuid references public.areas_operativas(id) on update restrict on delete restrict,
  estado text not null default 'sin_asignar'
    check (estado in ('asignado','sin_asignar')),
  origen text not null default 'manual'
    check (origen in ('manual','regla_confirmada')),
  regla text,
  creado_at timestamptz not null default now(),
  actualizado_at timestamptz not null default now(),
  constraint producto_area_estado_area_ck check (
    (estado = 'sin_asignar' and area_id is null)
    or (estado = 'asignado' and area_id is not null)
  ),
  constraint producto_area_regla_ck check (
    origen <> 'regla_confirmada' or nullif(btrim(regla),'') is not null
  )
);

comment on table public.producto_area_asignacion is
  'Relación preparatoria sin cantidad, con una única asignación por producto/sede. El stock sigue en productos.stock_actual.';
comment on column public.producto_area_asignacion.estado is
  'sin_asignar es un estado sin área física; no crea una quinta área ni un saldo.';
comment on column public.producto_area_asignacion.regla is
  'Procedencia textual de una regla confirmada; las simulaciones no se guardan aquí.';

-- Una asignación única por producto/sede evita atribuir el stock completo
-- a más de un área. El reparto cuantitativo requiere un modelo posterior.
create unique index producto_area_producto_sede_uk
  on public.producto_area_asignacion(sede,producto_id);
create index producto_area_sede_area_idx
  on public.producto_area_asignacion(sede,area_id);

create or replace function public.areas_operativas_guardar()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if new.sede is distinct from old.sede or new.codigo is distinct from old.codigo then
    raise exception 'La sede y el código del área son identificadores estables';
  end if;
  new.actualizado_at := now();
  return new;
end;
$$;

create or replace function public.producto_area_validar_contexto()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
declare
  v_producto_sede text;
  v_area_sede text;
begin
  select p.sede into v_producto_sede
  from public.productos as p
  where p.id = new.producto_id;
  if not found or v_producto_sede is distinct from new.sede then
    raise check_violation using message = 'La sede de la asignación debe coincidir con la sede del producto';
  end if;

  if new.area_id is not null then
    select a.sede into v_area_sede
    from public.areas_operativas as a
    where a.id = new.area_id;
    if not found or v_area_sede is distinct from new.sede then
      raise check_violation using message = 'El área y el producto deben pertenecer a la misma sede';
    end if;
  end if;

  new.actualizado_at := now();
  return new;
end;
$$;

revoke all on function public.areas_operativas_guardar() from public, anon, authenticated, service_role;
revoke all on function public.producto_area_validar_contexto() from public, anon, authenticated, service_role;

create trigger areas_operativas_guardar_trg
before update on public.areas_operativas
for each row execute function public.areas_operativas_guardar();
create trigger producto_area_validar_contexto_trg
before insert or update on public.producto_area_asignacion
for each row execute function public.producto_area_validar_contexto();

alter table public.areas_operativas enable row level security;
alter table public.producto_area_asignacion enable row level security;
revoke all privileges on table public.areas_operativas from public, anon, authenticated, service_role;
revoke all privileges on table public.producto_area_asignacion from public, anon, authenticated, service_role;

insert into public.areas_operativas (sede,codigo,nombre,orden) values
  ('plaza','cocina_fria','Cocina fría',1),
  ('plaza','cocina_caliente','Cocina caliente',2),
  ('plaza','barra','Barra',3),
  ('plaza','cafeteria','Cafetería',4);
