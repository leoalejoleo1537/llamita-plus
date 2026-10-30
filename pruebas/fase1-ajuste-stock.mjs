import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
const modalProducto = html.slice(html.indexOf('<!-- ================= MODAL PRODUCTO ================= -->'),html.indexOf('<!-- ================= MODAL NUEVO PRODUCTO ================= -->'));
const migration = readFileSync(new URL('../supabase/migrations/20261020000825_fase1_ajustes_manual_ledger.sql', import.meta.url), 'utf8');
const rollback = readFileSync(new URL('../sql/2026-10-fase1-ajustes-manuales.rollback.sql', import.meta.url), 'utf8');
const sqlTest = readFileSync(new URL('../sql/2026-10-fase1-pruebas-ajuste-manual.sql', import.meta.url), 'utf8');

assert.match(migration, /create function public\.stock_ajuste_guardar/i);
assert.match(migration, /create function public\.stock_ajuste_desglose_leer/i);
assert.match(migration, /security definer set search_path=''/i);
assert.match(migration, /authz_internal\.exigir_capacidad_b3_2a\('editar'\)/i);
assert.match(migration, /pg_advisory_xact_lock\(hashtextextended\('stock-location:'/i);
assert.match(migration, /sin lote \/ vencimiento no informado/i);
assert.match(migration, /ajuste_manual_id/);
assert.doesNotMatch(migration, /update\s+public\.productos\s+set\s+stock_actual/i);
assert.doesNotMatch(migration, /\bl\.cantidad\b/i);
assert.match(migration, /grant execute on function public\.stock_ajuste_guardar[^;]*to authenticated/i);
assert.match(html, /id="m-ajuste-panel"/);
assert.match(html, /id="m-ajuste-motivo"[^>]*value="Conteo\/corrección manual"/);
assert.match(html, /step="any" inputmode="decimal"/);
assert.match(html, /stock_ajuste_desglose_leer/);
assert.match(html, /stock_ajuste_guardar/);
assert.match(html, /Saldo físico actual:/);
assert.match(html, /data-ajuste-clave/);
assert.match(modalProducto, /id="m-acciones-rapidas"/);
assert.doesNotMatch(modalProducto, /La cantidad pertenece al ledger/);
assert.doesNotMatch(modalProducto, /Clasificación histórica/);
assert.doesNotMatch(modalProducto, /Ubicación física actual/);
assert.match(rollback, /Rollback técnico detenido: existen ajustes/);
assert.match(sqlTest, /begin;[\s\S]*rollback;\s*$/i);
assert.match(sqlTest, /positive|positivo/i);
assert.match(sqlTest, /idempotente/i);
assert.match(sqlTest, /proyección productos\.stock_actual/i);

console.log('Fase 1: contrato de ajuste, UI, seguridad e idempotencia estática verificados.');
