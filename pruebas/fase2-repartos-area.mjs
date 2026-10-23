import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const html=readFileSync(new URL('../index.html',import.meta.url),'utf8');
const sql=readFileSync(new URL('../supabase/migrations/20261020003917_fase2_repartos_recepcion_areas.sql',import.meta.url),'utf8');

assert.match(sql,/create table stock_internal\.repartos_area\(/i,'documento privado de reparto');
assert.match(sql,/create table stock_internal\.repartos_area_items\(/i,'líneas privadas de reparto');
assert.match(sql,/force row level security/gi,'RLS forzada');
assert.match(sql,/revoke all on table stock_internal\.repartos_area,stock_internal\.repartos_area_items[\s\S]*?public,anon,authenticated,service_role/i,'sin DML directo');
assert.match(sql,/create function public\.reparto_area_crear\(/i,'RPC de preparación');
assert.match(sql,/create function public\.reparto_area_recibir\(/i,'RPC de recepción');
assert.match(sql,/stock_internal\.transferir_aplicar\(/,'reutiliza el motor de transferencia');
assert.match(sql,/public\.stock_ajuste_guardar\(/,'excedente usa ajuste auditado');
assert.match(sql,/least\(v_recibida,v_disponible\)/,'Bodega nunca baja más de lo disponible');
assert.match(sql,/v_exceso:=v_recibida-v_transferida/,'el excedente queda explícito');
assert.match(sql,/recepcion_referencia uuid unique/,'recepción idempotente');
assert.match(sql,/pg_advisory_xact_lock/,'bloqueo transaccional');
assert.doesNotMatch(sql,/update\s+public\.productos\s+set\s+stock_actual/i,'no escribe la proyección directamente');
assert.doesNotMatch(sql,/insert\s+into\s+public\.(repartos|reparto_items)/i,'no reactiva reparto legacy');

const inicio=html.indexOf('/* ---------------- Fase 2 · reparto Bodega -> área');
const fin=html.indexOf('/* ---------------- reparto ----------------',inicio);
assert.ok(inicio>0&&fin>inicio,'bloque de interfaz Fase 2 identificable');
const ui=html.slice(inicio,fin);
for(const rpc of ['areas_operativas_listar','reparto_area_catalogo_buscar','reparto_area_crear','repartos_area_listar','reparto_area_recibir'])
  assert.ok(ui.includes(`'${rpc}'`),`la interfaz usa ${rpc}`);
assert.match(html,/id="f2-area"/,'selector dinámico de área en Bodega');
assert.match(html,/id="areaRepartos"/,'bandeja dentro del área');
assert.doesNotMatch(ui,/Solo envíos destinados a/,'la bandeja evita texto redundante del área destino');
assert.match(ui,/data-f2-rechazar=/,'cada producto permite marcar que no llegó');
assert.match(ui,/input\.value='0'/,'rechazar conserva el flujo auditado con cantidad cero');
assert.match(ui,/<details class="f2-history">/,'el historial cerrado permanece plegado');
assert.match(ui,/step="any"/,'preparación y recepción aceptan decimales');
assert.match(ui,/min="0" step="any"/,'recepción permite cero y rechaza negativos');
assert.doesNotMatch(ui,/\.from\(['"](?:repartos|reparto_items|stock_internal)/,'sin DML directo desde navegador');
assert.doesNotMatch(ui,/fudo|lama|receta|caja/i,'el circuito nuevo no llama POS, recetas ni caja');

console.log('Fase 2: preparación documental, recepción por área, ledger, excedente e idempotencia verificados.');
