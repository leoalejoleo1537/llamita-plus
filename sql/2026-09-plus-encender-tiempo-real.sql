--  DÓNDE VA:  Supabase -> SQL Editor -> New query
--  ES:        2 bloques, uno por uno (el 2 comprueba lo que hizo el 1)
--  TARDA:     instantáneo los dos
--  QUÉ HACE:  enciende el "tiempo real" de seis tablas. No toca ni un dato.
--  QUÉ VER:   en el bloque 2, las seis tienen que decir "sí"


-- ================================================================
-- QUÉ ES ESTO, EN CRIOLLO
--
-- La base de Llamita Plus nació de un respaldo. El respaldo copió la casa
-- entera con los muebles adentro — pero NO copió el cable del timbre.
--
-- El "timbre" es esto: la lista de tablas que le avisan a los teléfonos
-- cuando algo cambia. Sin él, todo está en su sitio y funciona… pero nadie
-- se entera de nada hasta que recarga la página.
--
-- HOY, MEDIDO: las ocho tablas dieron NO. O sea que ahora mismo, en tu app:
--   · el stock NO cambia solo en la lista cuando alguien vende
--   · las fechas de los sándwiches NO se actualizan solas
--   · un reparto que llega NO avisa
--   · y dos teléfonos sobre la MISMA mesa no se ven entre ellos
--
-- Ese último es el que más importa para Lama: si el segundo garzón no ve lo
-- que agregó el primero, el cliente recibe el pedido dos veces.
-- ================================================================


-- ================================================================
-- BLOQUE 1 — Encender el timbre
--
-- Seis líneas, una por tabla. Se pegan las seis juntas y se aprieta Run.
--
-- ⚠️ SI ALGUNA DA ERROR diciendo que "ya es miembro", no pasa nada malo:
-- significa que esa ya estaba encendida. Sacá esa línea y volvé a correr el
-- resto. (No debería pasar: las ocho dieron NO cuando lo medimos.)
-- ================================================================
alter publication supabase_realtime add table public.productos;
alter publication supabase_realtime add table public.producto_lotes;
alter publication supabase_realtime add table public.repartos;
alter publication supabase_realtime add table public.reparto_items;
alter publication supabase_realtime add table public.cuentas;
alter publication supabase_realtime add table public.cuenta_items;


-- ================================================================
-- BLOQUE 2 — Comprobar que quedó encendido
--
-- QUÉ VER: las SEIS tienen que decir "sí" en la columna en_vivo.
--
-- Aparecen también `mesas` y `comandas` diciendo NO, y ESO ESTÁ BIEN:
-- están a propósito apagadas. La app no las escucha —se comprobó, son seis
-- y sólo seis los avisos que pide `index.html`— y una tabla encendida que
-- nadie mira gasta cuota de Supabase a cambio de nada. Si algún día hacen
-- falta, es agregar una línea al bloque 1.
-- ================================================================
select
  t.tabla,
  case when p.tablename is null then 'NO' else 'sí' end as en_vivo,
  t.para_que
from (values
        ('productos',      'Stock · el número de stock cambia solo en la lista'),
        ('producto_lotes', 'Stock · las fechas de los sándwiches'),
        ('repartos',       'Stock · avisa que llegó un reparto'),
        ('reparto_items',  'Stock · las líneas de ese reparto'),
        ('cuentas',        'Lama · el color de la mesa y su total'),
        ('cuenta_items',   'Lama · los productos de la mesa'),
        ('mesas',          'Lama · APAGADA a propósito, nadie la escucha'),
        ('comandas',       'Lama · APAGADA a propósito, nadie la escucha')
     ) as t(tabla, para_que)
left join pg_publication_tables p
       on p.pubname    = 'supabase_realtime'
      and p.schemaname = 'public'
      and p.tablename  = t.tabla
order by en_vivo desc, t.tabla;


-- ================================================================
-- BLOQUE 3 — (opcional) ¿Tus dos cuentas ven el área de ventas?
--
-- La foto que sacaste antes mostraba `leoalejoleo1@gmail.com` con ve_lama en
-- NO, y vos dijiste que ya te habías dado acceso a las dos. Esto lo confirma.
-- NO escribe nada: si alguna dice NO, avisá y te paso la línea.
-- ================================================================
select
  correo,
  case when puede_lama then 'sí' else 'NO' end as ve_lama
from public.app_permisos
where correo in ('leoalejoleo1@gmail.com', 'leoalejoleo12@gmail.com')
order by correo;
