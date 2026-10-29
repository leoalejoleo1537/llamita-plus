import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname,join} from 'node:path';
import assert from 'node:assert/strict';

const raiz=join(dirname(fileURLToPath(import.meta.url)),'..');
const html=readFileSync(join(raiz,'index.html'),'utf8');
const sql=readFileSync(join(raiz,'supabase/migrations/20261029111000_configurar_producto_area_reparto.sql'),'utf8');
const reparto=html.slice(html.indexOf('/* ---------------- Fase 2'),html.indexOf('function areaRepartosActiva'));

assert.match(sql,/create or replace function public\.panel_producto_area_configurar/i);
assert.match(sql,/stock_internal\.guardar_configuracion_producto/i);
assert.match(sql,/stock_movido',false/i);
assert.match(sql,/grant execute on function public\.panel_producto_area_configurar[^;]*to authenticated/i);
assert.match(html,/id="overlay-f2-config"/);
assert.match(reparto,/data-f2-add="\$\{i\}"\>\$\{p\.ruta\?'Agregar':'Configurar primero'\}/);
assert.match(reparto,/if\(!p\.ruta\)\{f2AbrirConfiguracion\(p\);return;\}/);
assert.match(reparto,/sb\.rpc\('panel_producto_area_configurar'/);
assert.match(reparto,/await f2Buscar\(\)/);
assert.doesNotMatch(reparto,/data-f2-add="\$\{i\}" \$\{p\.ruta\?'':'disabled'\}/);
console.log('✓ Configurar primero abre una ruta funcional y vuelve al reparto sin mover stock.');
