import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const sql=readFileSync(new URL('../supabase/migrations/20261021210000_p4_lama_recetas_manuales.sql',import.meta.url),'utf8');
const app=readFileSync(new URL('../index.html',import.meta.url),'utf8');

assert.match(sql,/create table stock_internal\.lama_receta_reservas\(/i,
  'P4 conserva un snapshot privado por componente');
assert.match(sql,/producto_venta_id uuid not null references catalogo_internal\.productos_venta/i,
  'la reserva usa identidad comercial neutral');
assert.match(sql,/receta_id uuid not null references catalogo_internal\.recetas_venta/i,
  'la reserva congela la receta manual');
assert.match(sql,/constraint lama_receta_reserva_item_componente_uk unique\(cuenta_item_id,componente_orden\)/i,
  'una línea no duplica el mismo componente');
assert.match(sql,/create or replace function public\.cuenta_confirmar/i,
  'confirmar integra reservas de receta');
assert.match(sql,/v_necesario:=v_comp\.cantidad_unitaria\*v_item\.cantidad/i,
  'cantidad vendida multiplica cada ingrediente');
assert.match(sql,/stock_internal\.lama_reservado_en/i,
  'disponibilidad considera reservas directas y de receta');
assert.match(sql,/lama_receta_manual_reversa/i,
  'anulación posterior compensa el consumo');
assert.match(sql,/origen_pos where sede='plaza'\) <> 'ninguno'/i,
  'P4 conserva origen POS ninguno');
assert.match(sql,/revoke all on function public\.lama_productos_venta_listar\(\)[\s\S]*grant execute[\s\S]*to authenticated/i,
  'RPC de catálogo no queda abierta a anon');
assert.doesNotMatch(sql,/\b(insert|update|delete)\s+(into\s+)?public\.(recetas|receta_items|fudo_productos|fudo_movimientos)/i,
  'P4 no escribe recetas o Fudo heredados');
assert.doesNotMatch(sql,/stock_transferir|stock_internal\.transferir/i,
  'P4 no altera el motor de repartos');

assert.match(app,/sb\.rpc\('lama_productos_venta_listar'\)/,
  'Mesas carga el catálogo neutral');
assert.match(app,/cuenta_producto_venta_agregar/,
  'Mesas agrega identidad neutral mediante RPC');
assert.match(app,/Receta manual ·/,
  'la interfaz identifica el motor neutral');
assert.match(app,/Compatibilidad directa ·/,
  'el circuito anterior queda etiquetado explícitamente');
assert.match(app,/p\.vendible\?'':' disabled'/,
  'borradores e inválidos no se pueden agregar');
assert.match(app,/stock_disponible:0,stock_area:null,receta_valida:false,vendible:false/,
  'si P4 no responde, la carta heredada falla cerrada y no vende sin verificar stock');

console.log('✓ P4: catálogo neutral, receta multiárea, reservas, reversa y compatibilidad explícita');
