--  DÓNDE VA:  Supabase -> SQL Editor -> New query   (proyecto llamita-plus)
--  ES:        6 bloques cortos, UNO POR UNO. El editor solo muestra el último
--             resultado, así que pegarlos juntos pierde los primeros.
--  TARDA:     instantáneo cada uno.
--  QUÉ HACE:  el plano de mesas deja de ser una lista plana y pasa a tener
--             PÁGINAS y SECCIONES, que se editan desde la app. Crea una tabla
--             nueva y tres columnas en `mesas`. NO borra ninguna mesa.
--  QUÉ VER:   está escrito arriba de cada bloque. El bloque 1 tiene que dar
--             CERO filas — si da alguna, PARÁ y avisá.
--
--  De la maqueta aprobada: docs/propuesta-lama-mesas.html


-- ================================================================
-- BLOQUE 1 — ANTES DE TOCAR NADA
-- QUÉ VER: la primera consulta tiene que dar CERO FILAS.
--
-- POR QUÉ. Hoy la base exige que el número sea único POR SALÓN, y vamos a
-- pasarlo a único POR SEDE (la mesa 12 es la 12 en todo Mall Plaza). Si hoy
-- existieran dos mesas con el mismo número en salones distintos, el cambio
-- fallaría a mitad. Preferimos verlo antes.
-- ================================================================
select sede, numero, count(*) as cuantas
  from public.mesas
 group by sede, numero
having count(*) > 1;


-- ================================================================
-- BLOQUE 1b — (mirá esto también, es la foto de lo que hay hoy)
-- QUÉ VER: cuántas mesas tiene cada sede y en qué salón están.
-- ================================================================
select sede, salon, count(*) as mesas,
       min(numero) as desde, max(numero) as hasta
  from public.mesas
 group by sede, salon
 order by sede, salon;


-- ================================================================
-- BLOQUE 2 — LA TABLA NUEVA Y LAS COLUMNAS
-- QUÉ VER: "Success. No rows returned".
--
-- `lama_areas` guarda los dos niveles con un solo diseño: una fila SIN padre
-- es una PÁGINA (los botones de arriba); una fila CON padre es una SECCIÓN
-- dentro de esa página. Un solo lugar, una sola forma de leerlo.
-- ================================================================
create table if not exists public.lama_areas (
  id         bigserial primary key,
  sede       text    not null,
  nombre     text    not null,
  padre_id   bigint  references public.lama_areas(id) on delete restrict,
  color      text    not null default 'a',
  orden      integer not null default 0,
  activa     boolean not null default true,
  created_at timestamptz not null default now()
);

-- Dos secciones con el mismo nombre en la misma página es una trampa: nadie
-- sabría cuál es cuál. `coalesce(padre_id,0)` es para que las páginas también
-- se comparen entre sí — con NULL a secas, Postgres las considera distintas
-- siempre y dejaría crear dos "Mostrador".
create unique index if not exists lama_areas_nombre_unico
  on public.lama_areas (sede, coalesce(padre_id, 0), lower(nombre));
create index if not exists lama_areas_sede_idx
  on public.lama_areas (sede, padre_id, orden);

alter table public.lama_areas enable row level security;
drop policy if exists "lama_areas all" on public.lama_areas;
create policy "lama_areas all" on public.lama_areas
  for all to anon, authenticated using (true) with check (true);
grant all on public.lama_areas to anon, authenticated;
grant usage, select on sequence public.lama_areas_id_seq to anon, authenticated;

-- La mesa ahora vive en una sección, y tiene forma y tamaño propios.
-- `salon` NO se toca: se queda quieta hasta comprobar que todo anda. Sacarla
-- ahora sería quemar el puente de vuelta.
alter table public.mesas add column if not exists area_id bigint
  references public.lama_areas(id) on delete restrict;
alter table public.mesas add column if not exists forma text not null default 'cuadrada';
alter table public.mesas add column if not exists tam   text not null default 'normal';

alter table public.mesas drop constraint if exists mesas_forma_ok;
alter table public.mesas add  constraint mesas_forma_ok
  check (forma in ('cuadrada','redonda','larga'));
alter table public.mesas drop constraint if exists mesas_tam_ok;
alter table public.mesas add  constraint mesas_tam_ok
  check (tam in ('chica','normal','grande'));


-- ================================================================
-- BLOQUE 3 — REPARTIR LAS MESAS DE HOY
-- QUÉ VER: "Success". Ninguna mesa se borra ni cambia de número.
--
-- Cada sede estrena una página "Salón", y adentro una sección por cada salón
-- que ya existía. Después las movés vos desde la app, que es para lo que
-- sirve el modo edición.
-- ================================================================
insert into public.lama_areas (sede, nombre, padre_id, orden, color)
select distinct m.sede, 'Salón', null, 0, 'a'
  from public.mesas m
 where not exists (select 1 from public.lama_areas a
                    where a.sede = m.sede and a.padre_id is null);

insert into public.lama_areas (sede, nombre, padre_id, orden, color)
select p.sede, m.salon, p.id, 0, 'a'
  from (select distinct sede, salon from public.mesas) m
  join public.lama_areas p on p.sede = m.sede and p.padre_id is null
 where not exists (select 1 from public.lama_areas s
                    where s.sede = m.sede and s.padre_id = p.id
                      and lower(s.nombre) = lower(m.salon));

update public.mesas m
   set area_id = s.id
  from public.lama_areas s
  join public.lama_areas p on p.id = s.padre_id
 where p.padre_id is null
   and s.sede = m.sede
   and lower(s.nombre) = lower(m.salon)
   and m.area_id is null;


-- ================================================================
-- BLOQUE 4 — EL NÚMERO PASA A SER ÚNICO POR SEDE
-- QUÉ VER: "Success". Si acá diera error, es que el bloque 1 no dio cero:
-- pará y avisá en vez de forzarlo.
-- ================================================================
alter table public.mesas drop constraint if exists mesas_una_por_salon;
create unique index if not exists mesas_numero_por_sede
  on public.mesas (sede, numero);


-- ================================================================
-- BLOQUE 5 — COMPROBAR QUE QUEDÓ
-- QUÉ VER: una fila por sección, con sus mesas adentro.
-- ================================================================
select
  p.sede,
  p.nombre  as pagina,
  s.nombre  as seccion,
  (select count(*) from public.mesas m where m.area_id = s.id) as mesas
from public.lama_areas s
join public.lama_areas p on p.id = s.padre_id
order by p.sede, p.orden, s.orden, s.nombre;


-- ================================================================
-- BLOQUE 5b — Y QUE NINGUNA MESA QUEDARA HUÉRFANA
-- QUÉ VER: sin_area = 0. Si da otra cosa, avisá antes de seguir.
-- (Va aparte porque el editor muestra SOLO el resultado del último select:
--  dos consultas en un mismo Run pierden la primera.)
-- ================================================================
select count(*) as sin_area from public.mesas where area_id is null;
