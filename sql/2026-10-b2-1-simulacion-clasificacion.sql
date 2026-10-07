-- Informe SELECT-only, una fila por producto de plaza.
-- area_propuesta y regla son heurísticas de simulación: no se escriben en tablas.
-- stock_proyectado es el stock_actual completo asignado a un único destino.
with normalizados as (
  select p.id, p.producto, p.rubro, p.tipo,
         coalesce(p.stock_actual,0)::numeric as stock_actual,
         lower(coalesce(p.producto,'')) as nombre,
         lower(concat_ws(' ',p.producto,p.rubro,p.tipo)) as texto
  from public.productos p
  where p.sede = 'plaza'
), clasificados as (
  select id, producto, rubro, tipo, stock_actual,
    case
      when nombre ~ '(\+|[0-9]+ .*(masitas|jugos|combo))'
        or nombre ~ '(caja|bandeja|papel|envase|bolsa)'
        then 'Sin asignar'
      when nombre ~ '(helado|(^| )ice( |$)|^leche condensada|^manjar( |$)|^salsa (de )?(chocolate|manjar)|^syrup |^jarabe )'
        or ((lower(coalesce(tipo,'')) = 'insumos' or lower(coalesce(rubro,'')) = 'mueble de mezclas')
          and nombre ~ '(manjar|condensada|cacao|chocolate|syrup|jarabe)')
        then 'Cocina fría'
      when nombre ~ '(gaseosa|coca[- ]?cola|sprite|fanta|pepsi|7 ?up|bilz|(^| )pap( |$)|kem|schweppes|bebida en lata)'
        then 'Barra'
      when nombre ~ '(cafe|café|espresso|capuccino|cappuccino|latte|(^| )te( |$)|té|leche entera|leche común|leche fresca|leche blanca|torta|cheesecake)'
        or lower(coalesce(tipo,'')) = 'tortas'
        then 'Cafetería'
      when nombre ~ '(pan |^pan$|pizza|sandwich|sándwich|panini)'
        or lower(coalesce(tipo,'')) = 'sándwiches'
        or lower(coalesce(rubro,'')) = 'sándwiches'
        then 'Cocina caliente'
      else 'Sin asignar'
    end as area_propuesta,
    case
      when nombre ~ '(\+|[0-9]+ .*(masitas|jugos|combo))'
        then 'producto combinado; requiere decisión'
      when nombre ~ '(caja|bandeja|papel|envase|bolsa)'
        then 'insumo/embalaje sin área operativa inequívoca'
      when nombre ~ '(helado|(^| )ice( |$)|^leche condensada|^manjar( |$)|^salsa (de )?(chocolate|manjar)|^syrup |^jarabe )'
        or ((lower(coalesce(tipo,'')) = 'insumos' or lower(coalesce(rubro,'')) = 'mueble de mezclas')
          and nombre ~ '(manjar|condensada|cacao|chocolate|syrup|jarabe)')
        then 'helado/ice o ingrediente dulce identificable'
      when nombre ~ '(gaseosa|coca[- ]?cola|sprite|fanta|pepsi|7 ?up|bilz|(^| )pap( |$)|kem|schweppes|bebida en lata)'
        then 'gaseosa identificable por nombre'
      when nombre ~ '(cafe|café|espresso|capuccino|cappuccino|latte|(^| )te( |$)|té|leche entera|leche común|leche fresca|leche blanca|torta|cheesecake)'
        or lower(coalesce(tipo,'')) = 'tortas'
        then 'café, té, leche común o torta identificable'
      when nombre ~ '(pan |^pan$|pizza|sandwich|sándwich|panini)'
        or lower(coalesce(tipo,'')) = 'sándwiches'
        or lower(coalesce(rubro,'')) = 'sándwiches'
        then 'pan, pizza o sándwich identificable'
      else 'sin coincidencia inequívoca; requiere revisión'
    end as regla
  from normalizados
)
select id, producto, rubro, tipo, stock_actual,
       area_propuesta, regla, stock_actual as stock_proyectado
from clasificados
order by area_propuesta, producto, id;
