import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname,join} from 'node:path';
import assert from 'node:assert/strict';

const raiz=join(dirname(fileURLToPath(import.meta.url)),'..');
const venta=readFileSync(join(raiz,'panel-productos-venta.js'),'utf8');
const html=readFileSync(join(raiz,'index.html'),'utf8');

assert.match(venta,/data-pv-pendiente=/);
assert.match(venta,/function panelVentaAbrirPendiente/);
assert.match(venta,/MODAL_AREA_ROW=fila;openModal\(Number\(productoId\)\)/);
assert.match(html,/panelVentaIngredientesCargar==='function'&&!\$\('panel-venta-ficha'\)\.hidden/);
console.log('✓ El editor de recetas permite reparar un ingrediente pendiente y refresca sus orígenes.');
