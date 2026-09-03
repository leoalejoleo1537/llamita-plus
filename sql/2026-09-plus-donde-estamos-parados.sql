--  DÓNDE VA:  Supabase -> SQL Editor -> New query
--  ES:        2 bloques, uno por uno (el editor solo muestra el resultado del último)
--  TARDA:     instantáneo los dos
--  QUÉ HACE:  NO escribe nada. Solo mira y cuenta. Es una radiografía.
--  QUÉ VER:   bloque 1 -> la columna "en_vivo"; bloque 2 -> la columna "ve_lama"


-- ================================================================
-- POR QUÉ EXISTE ESTE ARCHIVO
--
-- La base de Llamita Plus nació de un respaldo del proyecto viejo. Un
-- respaldo trae las tablas, los datos y las funciones — pero hay cosas
-- que NO viaja: entre ellas, la lista de qué tablas se transmiten "en
-- vivo" a los teléfonos.
--
-- La imagen: el respaldo copió la casa entera, con los muebles adentro.
-- Lo que no copió fue el CABLE DEL TIMBRE. Todo está donde debe estar,
-- pero cuando alguien toca la puerta, adentro no suena nada.
--
-- Eso importa porque Llamita Lama vive de ese timbre: dos garzones sobre
-- la misma mesa tienen que verse. Si el cable no está, el segundo no ve
-- lo que agregó el primero y el cliente recibe el pedido dos veces.
--
-- Este archivo NO arregla nada. Pregunta. Con la respuesta se decide qué
-- arreglar, que es la regla de la casa: el estado de la base se consulta,
-- no se supone.
-- ================================================================


-- ================================================================
-- BLOQUE 1 — ¿Qué tablas están "en vivo"?
--
-- Cada fila es una tabla que la app escucha. "sí" = el timbre está
-- conectado. "NO" = esa tabla no avisa a nadie cuando cambia.
--
-- Las cuatro primeras son de Llamita Stock (el inventario); las cuatro
-- últimas son de Llamita Lama (las mesas).
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
        ('mesas',          'Lama · el plano del salón'),
        ('cuentas',        'Lama · el color de la mesa y su total'),
        ('cuenta_items',   'Lama · los productos de la mesa'),
        ('comandas',       'Lama · los papeles que salieron a la cocina')
     ) as t(tabla, para_que)
left join pg_publication_tables p
       on p.pubname    = 'supabase_realtime'
      and p.schemaname = 'public'
      and p.tablename  = t.tabla
order by en_vivo, t.tabla;


-- ================================================================
-- BLOQUE 2 — ¿Quién puede ver el área de ventas?
--
-- Llamita Lama está escondida a propósito: solo la ve quien tenga
-- `puede_lama`. Como la base salió del respaldo, acá adentro están los
-- correos del equipo de Café del Desierto.
--
-- QUÉ MIRAR: que TU correo (con el que entraste a la app) aparezca en
-- esta lista con "ve_lama = sí". Si no aparece, o dice NO, la pestaña
-- Mesas no existe para vos y no hay nada que mirar.
--
-- ⚠️ Si tu correo NO está en la lista: no lo agregues todavía, avisame.
-- Es una fila nueva y conviene escribirla bien la primera vez.
-- ================================================================
select
  correo,
  nombre,
  case when puede_lama    then 'sí' else 'NO' end as ve_lama,
  case when puede_ajustes then 'sí' else 'NO' end as entra_a_ajustes
from public.app_permisos
order by puede_lama desc, correo;
