import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const html=readFileSync(new URL('../index.html',import.meta.url),'utf8');
const sql=readFileSync(new URL('../supabase/migrations/20261020153000_fase4_lama_reservas_stock.sql',import.meta.url),'utf8');

assert.match(sql,/create table stock_internal\.lama_fuentes_directas\(/i,'fuente explícita de producto directo');
assert.match(sql,/asignacion_id uuid not null references public\.producto_area_asignacion/i,'reutiliza configuración producto-área');
assert.match(sql,/create table stock_internal\.lama_reservas\(/i,'reservas privadas y auditables');
assert.match(sql,/estado in \('reservada','consumida','liberada','error'\)/i,'ciclo de estado explícito');
assert.match(sql,/cuenta_item_id bigint not null references public\.cuenta_items/i,'reserva vinculada a línea');
assert.match(sql,/ubicacion_id uuid not null/i,'fuente física congelada');
assert.match(sql,/create function public\.lama_fuentes_directas_listar\(/i,'lectura protegida de disponibilidad');
assert.match(sql,/greatest\(coalesce\(ex\.saldo,0\)-coalesce\(rr\.reservado,0\),0\)/i,'disponibilidad = físico menos reservas');
assert.match(sql,/create or replace function public\.cuenta_confirmar/i,'confirmación integrada y atómica');
assert.match(sql,/No hay stock disponible suficiente/i,'saldo insuficiente se rechaza en backend');
assert.match(sql,/Este producto no tiene un área de inventario definida para venta/i,'sin fuente se rechaza claramente');
assert.match(sql,/create trigger cuentas_consumir_reservas_lama/i,'cualquier ruta de cierre consume por transición');
assert.match(sql,/exception when others[\s\S]*lama_alertas/i,'el cierre comercial deja alerta ante falla técnica');
assert.match(sql,/lama:consumo:/i,'consumo idempotente');
assert.match(sql,/lama:reversa:/i,'anulación consumida compensa una vez');
assert.match(sql,/for v_fila in[\s\S]*order by vencimiento,e\.lote_id nulls last/i,'consumo FIFO por vencimiento y lote');
assert.match(sql,/revoke all on function public\.cuenta_confirmar[\s\S]*grant execute[\s\S]*to authenticated/i,'confirmación no ejecutable por anónimo');
assert.doesNotMatch(sql,/update\s+public\.productos\s+set\s+stock_actual/i,'no escribe proyección directamente');
assert.doesNotMatch(sql,/(insert into|update|delete from)\s+public\.(recetas|receta_items|fudo_movimientos|cuenta_pagos|lama_caja_movimientos)/i,'no toca recetas, Fudo, pagos ni caja');

assert.match(html,/lama_fuentes_directas_listar/,'la carta consume disponibilidad protegida');
assert.match(html,/Sin área de inventario para venta/,'la carta muestra falta de fuente');
assert.match(html,/id="aj-lama-stock"/,'Ajustes permite configurar la fuente explícita');
assert.match(html,/lama_fuente_directa_guardar/,'la configuración usa RPC, no DML');
assert.match(html,/const hayLama = !!\(PERMISOS\.puede_lama && SEDE && SEDE !== 'central'\)/,'modo demostración no oculta Mesas autorizado');
assert.match(html,/if\(\(tab==='lama'\|\|tab==='arqueo'\|\|tab==='movcaja'\)[\s\S]*PERMISOS\.puede_lama/,'ruta directa conserva permiso Lama');
assert.match(html,/DEMO_VISTAS = new Set\(\[[^\]]*'lama'/,'Mesas es navegable en demostración autorizada');
assert.doesNotMatch(html,/body\.demo-activo \.tab\[data-tab="lama"\]/,'CSS no vuelve a ocultar Mesas');
assert.match(html,/id="lama-stock-banner"/,'alerta de cierre pendiente visible');

console.log('Fase 4: reservas, disponibilidad, cierre tolerante y acceso móvil verificados.');
