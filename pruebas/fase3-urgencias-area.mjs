import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const html=readFileSync(new URL('../index.html',import.meta.url),'utf8');
const sql=readFileSync(new URL('../supabase/migrations/20261020102356_fase3_urgencias_producto_area.sql',import.meta.url),'utf8');

assert.match(sql,/alter table public\.producto_area_asignacion[\s\S]*add column urgente boolean not null default false/i,'la urgencia vive en la configuración producto-área');
assert.match(sql,/urgente_desde timestamptz/i,'fecha de activación');
assert.match(sql,/urgente_por uuid references auth\.users/i,'actor de activación');
assert.match(sql,/create function public\.producto_area_urgencia_guardar\(/i,'RPC protegida para marcar y quitar');
assert.match(sql,/create function public\.producto_area_urgencias_listar\(/i,'RPC protegida de lectura para Bodega');
assert.match(sql,/security definer set search_path=''/gi,'search_path seguro');
assert.match(sql,/authz_internal\.exigir_capacidad_b3_2a\('editar'\)/i,'exige usuario operativo con edición');
assert.match(sql,/authz_internal\.exigir_capacidad_b3_2a\('lectura'\)/i,'exige sesión autorizada para leer');
assert.match(sql,/revoke all on function public\.producto_area_urgencia_guardar[\s\S]*from public,anon,authenticated,service_role/i,'sin ejecución heredada');
assert.match(sql,/grant execute on function public\.producto_area_urgencia_guardar[\s\S]*to authenticated/i,'solo authenticated invoca el contrato');
assert.doesNotMatch(sql,/(?:insert\s+into|update|delete\s+from)\s+stock_internal\.(?:movimientos|existencias|transferencias)/i,'la migración no escribe el ledger');
assert.doesNotMatch(sql,/update\s+public\.productos\s+set\s+stock_actual/i,'no toca la proyección');

assert.match(html,/id="m-urgente-nota"/,'nota opcional en la ficha del área');
assert.match(html,/producto_area_urgencia_guardar/,'la ficha usa la RPC protegida');
assert.match(html,/urgente_area/,'la prioridad se aplica por área, no globalmente');
assert.match(html,/sort\(\(a,b\)=>\(Number\(!!b\.urgente_area\)-Number\(!!a\.urgente_area\)\)/,'urgentes primero en el inventario del área');
assert.match(html,/id="f3-urgentes"/,'Bodega incorpora la lista de urgencias');
assert.match(html,/Urgentes por área/,'la lista se agrupa por destino');
assert.match(html,/F2_CARRITO_AREA/,'el carrito conserva un único destino');
assert.match(html,/producto_bodega_id\)===Number\(urgente\.producto_bodega_id\)/,'Bodega usa el enlace explícito');

const inicio=html.indexOf('/* ---------------- Fase 2 · reparto Bodega -> área');
const fin=html.indexOf('function areaRepartosActiva',inicio);
assert.ok(inicio>0&&fin>inicio,'bloque de preparación identificable');
const ui=html.slice(inicio,fin);
assert.doesNotMatch(ui,/\.from\(/,'urgencias y preparación no hacen DML directo desde navegador');
assert.doesNotMatch(ui,/stock_actual\s*=|fudo|lama|receta|caja/i,'la urgencia no toca stock, POS, recetas ni caja');

console.log('Fase 3: urgencia por producto-área, prioridad y preparación por destino verificadas.');
