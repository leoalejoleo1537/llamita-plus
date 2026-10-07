/* Prueba de la resolución del catálogo y el bloqueo de la sede archivada.
   node pruebas/sedes-seguras.mjs */
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import assert from 'node:assert/strict';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const html = readFileSync(join(root, 'index.html'), 'utf8');
const start = html.indexOf('const SEDES = {');
const end = html.indexOf('const TITULOS =', start);
assert(start >= 0 && end > start, 'existe el catálogo y su guard de sede');
const catalogCode = html.slice(start, end);
const buttons = ['plaza', 'angamos', 'central'].map(s => ({
  dataset: { sede:s }, hidden:false, textContent:s,
}));
const documentStub = {querySelectorAll:() => buttons};
const rows = [
  {codigo:'plaza',nombre_visible:'Local 1',tipo:'local',estado:'activa'},
  {codigo:'angamos',nombre_visible:'Local 2',tipo:'local',estado:'archivada'},
  {codigo:'central',nombre_visible:'Bodega',tipo:'logistica',estado:'activa'},
  {codigo:'bodega',nombre_visible:'Bodega histórica',tipo:'historica',estado:'archivada'},
];
const sbStub = {from:table => {
  assert.equal(table,'sede_registro','se consulta el registro de sedes');
  return {select:async columns => {
    assert.equal(columns,'codigo,nombre_visible,tipo,estado');
    return {data:rows,error:null};
  }};
}};
const catalog = new Function('sb','document',`${catalogCode}; return {SEDES, sedeActiva, cargarRegistroSedes};`)(sbStub,documentStub);

assert.equal(catalog.sedeActiva('plaza'), true, 'Local 1 sigue habilitado');
assert.equal(catalog.sedeActiva('central'), true, 'Bodega central sigue habilitada');
assert.equal(catalog.sedeActiva('angamos'), false, 'Local 2 está bloqueada por defecto');
assert.equal(catalog.sedeActiva('bodega'), false, 'la clave histórica no se ofrece');
assert.equal(catalog.SEDES.central.label, 'Bodega', 'central conserva el nombre operativo');
assert.equal(catalog.SEDES.central.excel, 'central', 'Bodega operativa tiene su propia clave de exportación');
assert.equal(catalog.SEDES.bodega.excel, 'bodega', 'la clave histórica se conserva separada');
await catalog.cargarRegistroSedes();
assert.equal(buttons.find(b=>b.dataset.sede==='plaza').hidden,false,'Local 1 aparece');
assert.equal(buttons.find(b=>b.dataset.sede==='central').hidden,false,'Bodega aparece');
assert.equal(buttons.find(b=>b.dataset.sede==='angamos').hidden,true,'Local 2 archivada queda oculta');

const selector = html.match(/<button class="gate-btn" data-sede="angamos"[^>]*>/)?.[0] || '';
assert.match(selector, /\bhidden\b/, 'Local 2 inicia oculta antes de leer el catálogo');
assert.match(html, /function pickSede\(s\)\{\s*if\(!sedeActiva\(s\)\)\{[\s\S]*?return;\s*\}\s*SEDE = s;/,
  'la ruta directa valida estado antes de asignar la sede');
const pickStart = html.indexOf('function pickSede(s){');
const pickEnd = html.indexOf('function showGate(){', pickStart);
const pickSource = html.slice(pickStart, pickEnd).replace(/\n\}\s*$/, '\n}');
let gateShown = false;
const tryArchived = new Function('sedeActiva', 'showGate',
  `let SEDE=null; ${pickSource}; pickSede('angamos'); return SEDE;`);
assert.equal(tryArchived(catalog.sedeActiva, () => { gateShown = true; }), null,
  'una llamada directa a pickSede no establece Angamos');
assert.equal(gateShown, false, 'desde el selector no se abre una ruta de sede');
assert.match(html, /function pickTab\(tab\)\{\s*if\(!SEDE\)return;\s*if\(!sedeActiva\(SEDE\)\)\{ showGate\(\); return; \}/,
  'la navegación vuelve al selector si la sede abierta deja de estar activa');
assert.match(html, /const SEDES_ENLACE = \['plaza'\];/,
  'los nuevos repartos solo ofrecen Local 1');
assert.match(html, /if\(!sedeActiva\(sede\)\)\{\s*aviso\('Local 2 está archivada\./,
  'Bodega no permite preparar envíos nuevos hacia Local 2');

console.log('✓ catálogo, selector, guard de rutas y destino de Bodega verificados');
