-- A3.1 — cimientos del puente Lama → Stock
-- Solo estructura. No conecta cierres, no escribe stock y no inserta configuración.
-- Rollback manual documentado en docs/hermes/08-plan-implementacion-puente-lama-stock.md
begin;

create table public.lama_stock_config (
  sede text primary key,
  modo text not null default 'apagado'
    check (modo in ('apagado','prueba','real')),
  actualizado_por text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.lama_stock_config is
  'Configuración futura del puente Lama-Stock. Ausencia de fila equivale a apagado.';
comment on column public.lama_stock_config.modo is
  'No se habilita ninguna fila en A3.1; el valor efectivo por defecto es apagado.';

create table public.lama_stock_eventos (
  id uuid primary key default gen_random_uuid(),
  source text not null default 'lama'
    check (source = 'lama'),
  sede text not null,
  source_sale_id text not null,
  source_line_id text not null,
  cuenta_id bigint,
  cuenta_item_id bigint,
  producto_id bigint references public.productos(id) on delete restrict,
  provider_product_id text,
  cantidad numeric not null check (cantidad > 0),
  fulfillment text check (fulfillment is null or fulfillment in ('serve','takeaway','other')),
  estado text not null default 'pendiente'
    check (estado in ('pendiente','prueba','aplicado','sin_receta','error','revertido')),
  modo_efectivo text not null default 'apagado'
    check (modo_efectivo in ('apagado','prueba','real')),
  ocurrido_at timestamptz not null,
  observado_at timestamptz not null default now(),
  precio numeric,
  moneda text,
  snapshot_precio jsonb,
  recipe_version_id text,
  snapshot_receta jsonb,
  metadata jsonb not null default '{}'::jsonb,
  error_code text,
  error_detail text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint lama_stock_eventos_origen_linea_uq
    unique (source, sede, source_sale_id, source_line_id)
);

comment on table public.lama_stock_eventos is
  'Eventos de venta Lama preparados para inventario; A3.1 no los captura ni aplica.';
comment on column public.lama_stock_eventos.modo_efectivo is
  'Modo congelado en el evento. A3.1 solo permite el valor efectivo apagado por defecto.';

create table public.lama_stock_aplicaciones (
  id uuid primary key default gen_random_uuid(),
  evento_id uuid not null references public.lama_stock_eventos(id) on delete restrict,
  componente_producto_id bigint references public.productos(id) on delete restrict,
  area_id uuid,
  lote_id bigint,
  cantidad_delta numeric not null check (cantidad_delta <> 0),
  unidad text,
  estado text not null default 'pendiente'
    check (estado in ('pendiente','prueba','aplicado','sin_receta','error','revertido')),
  clave_idempotencia text not null unique,
  reversa_de uuid references public.lama_stock_aplicaciones(id) on delete restrict,
  error_code text,
  error_detail text,
  applied_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint lama_stock_aplicaciones_reversa_no_self
    check (reversa_de is null or reversa_de <> id)
);

comment on table public.lama_stock_aplicaciones is
  'Aplicaciones por ingrediente/lote. A3.1 no modifica saldos ni crea aplicaciones.';
comment on column public.lama_stock_aplicaciones.clave_idempotencia is
  'Clave determinista por origen, sede, venta, línea, componente y receta.';

create index lama_stock_eventos_estado_idx
  on public.lama_stock_eventos (sede, estado, observado_at);
create index lama_stock_eventos_cuenta_idx
  on public.lama_stock_eventos (cuenta_id, cuenta_item_id);
create index lama_stock_aplicaciones_evento_idx
  on public.lama_stock_aplicaciones (evento_id, estado);
create index lama_stock_aplicaciones_componente_idx
  on public.lama_stock_aplicaciones (componente_producto_id, estado);

alter table public.lama_stock_config enable row level security;
alter table public.lama_stock_eventos enable row level security;
alter table public.lama_stock_aplicaciones enable row level security;

revoke all on table public.lama_stock_config from anon, authenticated;
revoke all on table public.lama_stock_eventos from anon, authenticated;
revoke all on table public.lama_stock_aplicaciones from anon, authenticated;

commit;
