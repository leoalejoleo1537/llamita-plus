--  DÓNDE VA:  Supabase -> SQL Editor -> New query   (proyecto llamita-plus)
--  ES:        3 bloques cortos, uno por uno.
--  TARDA:     instantáneo.
--  QUÉ HACE:  crea la COLA DE IMPRESIÓN. La app deja el papel escrito acá; el
--             programita del computador del local lo saca y lo imprime.
--             NO imprime nada por sí solo — sin el puente instalado, esta
--             tabla simplemente junta papeles y no molesta a nadie.
--  QUÉ VER:   bloque 3 -> `lama_impresiones` diciendo "sí" en la columna
--             `en_vivo`. Sin eso el puente no se entera de nada.
--
--  POR QUÉ UNA COLA Y NO UNA CONEXIÓN DIRECTA (§2.3, medido en el local el
--  2026-09-01): el navegador NO puede tomar la impresora — Windows se queda
--  con ella y no la suelta. Y si el garzón imprime desde el teléfono, una
--  página en https tampoco puede llamar a una dirección de la red local.
--  La salida es que el puente no reciba nada: que se suscriba y saque lo que
--  aparezca. Sin conexión entrante no hay contenido mixto, ni firewall, ni IP
--  que averiguar, y funciona desde cualquier teléfono.


-- ================================================================
-- BLOQUE 1 — LA TABLA
-- QUÉ VER: "Success. No rows returned".
-- ================================================================
create table if not exists public.lama_impresiones (
  id         bigserial primary key,
  sede       text    not null,
  -- comanda = lo que va a prepararse · precuenta = el papel del cliente
  -- anulacion = el aviso de que algo YA COMANDADO se cayó
  tipo       text    not null,
  contenido  text    not null,
  estado     text    not null default 'pendiente',
  quien      text,
  cuenta_id  bigint,
  creada_at  timestamptz not null default now(),
  impresa_at timestamptz,
  error      text,
  constraint lama_impresiones_tipo_ok
    check (tipo in ('comanda','precuenta','anulacion','prueba')),
  constraint lama_impresiones_estado_ok
    check (estado in ('pendiente','impresa','error'))
);
create index if not exists lama_impresiones_cola_idx
  on public.lama_impresiones (sede, estado, creada_at);

alter table public.lama_impresiones enable row level security;
drop policy if exists "lama_impresiones all" on public.lama_impresiones;
create policy "lama_impresiones all" on public.lama_impresiones
  for all to anon, authenticated using (true) with check (true);
grant all on public.lama_impresiones to anon, authenticated;
grant usage, select on sequence public.lama_impresiones_id_seq to anon, authenticated;


-- ================================================================
-- BLOQUE 2 — ENCENDER EL TIMBRE PARA ESTA TABLA
-- QUÉ VER: "Success". Si dice que ya está en la publicación, también está bien.
--
-- Sin esto el puente tendría que preguntar cada pocos segundos si hay algo
-- —gastando cuota y llegando tarde—. Con esto, Supabase le avisa.
-- ================================================================
alter publication supabase_realtime add table public.lama_impresiones;


-- ================================================================
-- BLOQUE 3 — COMPROBAR
-- QUÉ VER: una fila, `lama_impresiones`, con `en_vivo` = sí.
-- ================================================================
select 'lama_impresiones' as tabla,
       case when exists (
         select 1 from pg_publication_tables
          where pubname = 'supabase_realtime'
            and schemaname = 'public'
            and tablename = 'lama_impresiones') then 'sí' else 'NO' end as en_vivo;
