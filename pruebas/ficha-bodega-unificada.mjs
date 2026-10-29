import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname,join} from 'node:path';
import assert from 'node:assert/strict';

const raiz=join(dirname(fileURLToPath(import.meta.url)),'..');
const html=readFileSync(join(raiz,'index.html'),'utf8');
const sql=readFileSync(join(raiz,'supabase/migrations/20261029103000_ficha_bodega_unificada.sql'),'utf8');
const ficha=html.slice(html.indexOf('async function openModal(id)'),html.indexOf('/* ---------------- urgente'));
const guardado=html.slice(html.indexOf("$('m-guardar').addEventListener('click'"),html.indexOf("$('m-ajuste-guardar').addEventListener"));

assert.match(sql,/create table if not exists stock_internal\.producto_bodega_ficha_operaciones/i);
assert.match(sql,/create or replace function public\.producto_bodega_ficha_guardar/i);
assert.match(sql,/public\.stock_ajuste_guardar\(p_referencia,p_producto_id,null,p_conteos/i);
assert.match(sql,/grant execute on function public\.producto_bodega_ficha_guardar[^;]*to authenticated/i);
assert.match(ficha,/m-stock-field'\)\.style\.display=stockCortado\?'none':''/);
assert.match(ficha,/m-limits-fields'\)\.style\.display=\(fichaArea\|\|SEDE==='central'\)\?'flex':'none'/);
assert.match(ficha,/m-ajuste-guardar'\)\.style\.display='none'/);
assert.match(guardado,/if\(SEDE==='central'\)/);
assert.match(guardado,/sb\.rpc\('producto_bodega_ficha_guardar'/);
assert.match(guardado,/p_conteos:cambioConteo\?conteos:null/);
assert.doesNotMatch(guardado.slice(guardado.indexOf("if(SEDE==='central')"),guardado.indexOf("const nombre=")),/saveFields\(/);
console.log('✓ Ficha de Bodega usa un único guardado atómico y el ledger para el conteo.');
